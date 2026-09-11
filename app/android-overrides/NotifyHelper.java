package top.nbchannel.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * 消息提醒的公共逻辑:查未读 + 发通知。
 * 被两个地方复用:
 *   · NotifyForegroundService —— APP 常驻时每 30 秒查一次(准实时)
 *   · NotifyJobService        —— 系统兜底任务,每 15 分钟查一次
 */
public class NotifyHelper {

    public static final String CHANNEL_MSG = "nbchannel";
    public static final String CHANNEL_ONGOING = "nbchannel_ongoing";
    public static final int NOTIFY_ID = 2001;

    private static final String SB_RPC =
            "https://pbaafgjkwdbwcmsikcmg.supabase.co/rest/v1/rpc/get_unread_counts";
    private static final String SB_KEY =
            "sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg";

    /** 建通知渠道(Android 8+ 必须先建渠道才能发通知) */
    public static void createChannels(Context ctx) {
        if (Build.VERSION.SDK_INT < 26) return;
        try {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return;
            NotificationChannel msg = new NotificationChannel(
                    CHANNEL_MSG, "NB频道消息", NotificationManager.IMPORTANCE_DEFAULT);
            msg.setDescription("评论回复、@提及等提醒");
            nm.createNotificationChannel(msg);

            NotificationChannel ongoing = new NotificationChannel(
                    CHANNEL_ONGOING, "实时提醒服务", NotificationManager.IMPORTANCE_MIN);
            ongoing.setDescription("保持实时消息提醒所需的后台服务");
            ongoing.setShowBadge(false);
            nm.createNotificationChannel(ongoing);
        } catch (Throwable ignored) {
        }
    }

    /** 查当前未读总数;失败返回 -1 */
    public static int fetchUnread(Context ctx) {
        SharedPreferences sp = ctx.getSharedPreferences("nb", Context.MODE_PRIVATE);
        String uid = sp.getString("uid", "");
        String token = sp.getString("token", "");
        if (uid == null || uid.isEmpty() || token == null || token.isEmpty()) return -1;

        HttpURLConnection conn = null;
        try {
            URL url = new URL(SB_RPC);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setConnectTimeout(12000);
            conn.setReadTimeout(12000);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("apikey", SB_KEY);
            conn.setRequestProperty("Authorization", "Bearer " + SB_KEY);

            String body = "{\"p_user_id\":\"" + uid + "\",\"p_session\":\"" + token + "\"}";
            OutputStream os = conn.getOutputStream();
            os.write(body.getBytes("UTF-8"));
            os.flush();
            os.close();

            if (conn.getResponseCode() != 200) return -1;

            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
            reader.close();
            return sumCounts(sb.toString());
        } catch (Throwable t) {
            return -1;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    /** 接口返回形如 [{"type":"reply","count":2},...],把所有 count 加起来 */
    private static int sumCounts(String json) {
        int sum = 0, idx = 0;
        while (true) {
            int i = json.indexOf("\"count\":", idx);
            if (i < 0) break;
            int j = i + 8, k = j;
            while (k < json.length() && (Character.isDigit(json.charAt(k)) || json.charAt(k) == ' ')) k++;
            try {
                sum += Integer.parseInt(json.substring(j, k).trim());
            } catch (Throwable ignored) {
            }
            idx = Math.max(k, j + 1);
        }
        return sum;
    }

    /** 未读变多了才弹提醒,避免反复打扰 */
    public static void maybeNotify(Context ctx, int total) {
        if (total < 0) return;
        SharedPreferences sp = ctx.getSharedPreferences("nb", Context.MODE_PRIVATE);
        int last = sp.getInt("last_unread", -1);
        if (total > 0 && total > last) notifyNew(ctx, total);
        sp.edit().putInt("last_unread", total).apply();
    }

    public static void notifyNew(Context ctx, int total) {
        try {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return;
            createChannels(ctx);

            Intent intent = new Intent(ctx, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
            PendingIntent pi = PendingIntent.getActivity(ctx, 0, intent, flags);

            Notification.Builder b;
            if (Build.VERSION.SDK_INT >= 26) b = new Notification.Builder(ctx, CHANNEL_MSG);
            else b = new Notification.Builder(ctx);

            b.setSmallIcon(android.R.drawable.stat_notify_chat)
             .setContentTitle("NB频道")
             .setContentText("你有 " + total + " 条新消息")
             .setAutoCancel(true)
             .setContentIntent(pi);

            nm.notify(NOTIFY_ID, b.build());
        } catch (Throwable ignored) {
        }
    }

    /** 常驻通知(前台服务必须显示一个,用户可以点「停止」关掉实时提醒) */
    public static Notification buildOngoing(Context ctx, String text) {
        createChannels(ctx);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;

        PendingIntent open = PendingIntent.getActivity(ctx, 1,
                new Intent(ctx, MainActivity.class)
                        .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP), flags);
        PendingIntent stop = PendingIntent.getService(ctx, 2,
                new Intent(ctx, NotifyForegroundService.class).setAction("STOP"), flags);

        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= 26) b = new Notification.Builder(ctx, CHANNEL_ONGOING);
        else b = new Notification.Builder(ctx);

        b.setSmallIcon(android.R.drawable.stat_notify_chat)
         .setContentTitle("NB频道 · 消息提醒已开启")
         .setContentText(text)
         .setOngoing(true)
         .setShowWhen(false)
         .setContentIntent(open)
         .addAction(new Notification.Action.Builder(null, "停止实时提醒", stop).build());

        if (Build.VERSION.SDK_INT >= 26) b.setChannelId(CHANNEL_ONGOING);
        return b.build();
    }
}
