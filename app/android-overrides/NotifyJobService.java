package top.nbchannel.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.job.JobParameters;
import android.app.job.JobService;
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
 * 后台消息提醒(由 JobScheduler 每 15 分钟触发一次)
 *
 * 为什么不走 FCM:国内没有 Google 服务,推送基本收不到。
 * 这里改成系统自带的 JobScheduler 定期查一次未读数,有新消息就发本地通知,
 * 好处是完全不依赖第三方推送、不需要额外依赖库;代价是提醒有延迟(最长约 15 分钟)。
 *
 * 登录态来自 MainActivity 在页面加载完成后同步过来的 SharedPreferences(uid + token)。
 */
public class NotifyJobService extends JobService {

    private static final String SB_RPC =
            "https://pbaafgjkwdbwcmsikcmg.supabase.co/rest/v1/rpc/get_unread_counts";
    private static final String SB_KEY =
            "sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg";
    private static final String CHANNEL_ID = "nbchannel";
    private static final int NOTIFY_ID = 2001;

    @Override
    public boolean onStartJob(final JobParameters params) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    checkUnread();
                } catch (Throwable ignored) {
                }
                jobFinished(params, false);
            }
        }).start();
        return true;   // 有后台线程在跑
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        return false;   // 不重试
    }

    private void checkUnread() throws Exception {
        SharedPreferences sp = getSharedPreferences("nb", Context.MODE_PRIVATE);
        String uid = sp.getString("uid", "");
        String token = sp.getString("token", "");
        if (uid == null || uid.isEmpty() || token == null || token.isEmpty()) return;

        HttpURLConnection conn = null;
        try {
            URL url = new URL(SB_RPC);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(15000);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("apikey", SB_KEY);
            conn.setRequestProperty("Authorization", "Bearer " + SB_KEY);

            String body = "{\"p_user_id\":\"" + uid + "\",\"p_session\":\"" + token + "\"}";
            OutputStream os = conn.getOutputStream();
            os.write(body.getBytes("UTF-8"));
            os.flush();
            os.close();

            if (conn.getResponseCode() != 200) return;

            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
            reader.close();

            int total = sumCounts(sb.toString());
            int last = sp.getInt("last_unread", -1);
            // 只有"变多了"才提醒,避免同一条消息反复打扰;归零时也要记下来
            if (total > 0 && total > last) {
                showNotification(total);
            }
            sp.edit().putInt("last_unread", total).apply();
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    /** 接口返回形如 [{"type":"reply","count":2},...],这里把所有 count 加起来 */
    private int sumCounts(String json) {
        int sum = 0;
        int idx = 0;
        while (true) {
            int i = json.indexOf("\"count\":", idx);
            if (i < 0) break;
            int j = i + 8;
            int k = j;
            while (k < json.length() && (Character.isDigit(json.charAt(k)) || json.charAt(k) == ' ')) k++;
            try {
                sum += Integer.parseInt(json.substring(j, k).trim());
            } catch (Throwable ignored) {
            }
            idx = Math.max(k, j + 1);
        }
        return sum;
    }

    private void showNotification(int total) {
        try {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return;

            if (Build.VERSION.SDK_INT >= 26) {
                NotificationChannel ch = new NotificationChannel(
                        CHANNEL_ID, "NB频道消息", NotificationManager.IMPORTANCE_DEFAULT);
                ch.setDescription("评论回复、@提及等提醒");
                nm.createNotificationChannel(ch);
            }

            Intent intent = new Intent(this, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
            PendingIntent pi = PendingIntent.getActivity(this, 0, intent, flags);

            Notification.Builder b;
            if (Build.VERSION.SDK_INT >= 26) {
                b = new Notification.Builder(this, CHANNEL_ID);
            } else {
                b = new Notification.Builder(this);
            }
            b.setSmallIcon(android.R.drawable.stat_notify_chat)
             .setContentTitle("NB频道")
             .setContentText("你有 " + total + " 条新消息")
             .setAutoCancel(true)
             .setContentIntent(pi);

            nm.notify(NOTIFY_ID, b.build());
        } catch (Throwable ignored) {
        }
    }
}
