package top.nbchannel.app;

import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

/**
 * 实时消息提醒(前台服务)
 *
 * 为什么需要它:Android 系统的 JobScheduler / WorkManager 周期任务**最小间隔就是 15 分钟**,
 * 想要更快只能让服务常驻 —— 代价是通知栏挂一条常驻通知(系统强制要求,不能隐藏)。
 * 这条通知带「停止实时提醒」按钮,用户不想要随时可以关掉。
 *
 * 工作方式:每 30 秒查一次未读数,有新消息就弹提醒(秒级~30 秒延迟)。
 * 兜底:即使这个服务被系统或用户杀掉,NotifyJobService 仍会每 15 分钟查一次。
 */
public class NotifyForegroundService extends Service {

    private static final long INTERVAL_MS = 30 * 1000L;   // 30 秒一轮
    private static final int ONGOING_ID = 1001;

    private Handler handler;
    private Runnable ticker;
    private boolean running = false;
    private int lastShown = -1;

    @Override
    public void onCreate() {
        super.onCreate();
        handler = new Handler(Looper.getMainLooper());
        NotifyHelper.createChannels(this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // 用户点了通知里的「停止实时提醒」
        if (intent != null && "STOP".equals(intent.getAction())) {
            running = false;
            try {
                stopForeground(true);
            } catch (Throwable ignored) {
            }
            stopSelf();
            return START_NOT_STICKY;
        }

        try {
            startForeground(ONGOING_ID, NotifyHelper.buildOngoing(this, "每 30 秒检查一次新消息"));
        } catch (Throwable ignored) {
        }

        if (!running) {
            running = true;
            startLoop();
        }
        return START_STICKY;
    }

    private void startLoop() {
        ticker = new Runnable() {
            @Override
            public void run() {
                new Thread(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            int total = NotifyHelper.fetchUnread(NotifyForegroundService.this);
                            NotifyHelper.maybeNotify(NotifyForegroundService.this, total);
                            if (total >= 0) updateOngoing(total);
                        } catch (Throwable ignored) {
                        }
                    }
                }).start();
                if (running) handler.postDelayed(this, INTERVAL_MS);
            }
        };
        handler.post(ticker);
    }

    /** 常驻通知里的文字跟着未读数变,数字没变就不刷新(避免刷屏) */
    private void updateOngoing(int total) {
        if (total == lastShown) return;
        lastShown = total;
        try {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) {
                nm.notify(ONGOING_ID, NotifyHelper.buildOngoing(this,
                        total > 0 ? ("有 " + total + " 条未读") : "暂无新消息"));
            }
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void onDestroy() {
        running = false;
        try {
            if (handler != null && ticker != null) handler.removeCallbacks(ticker);
        } catch (Throwable ignored) {
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
