package top.nbchannel.app;

import android.app.job.JobParameters;
import android.app.job.JobService;

/**
 * 兜底消息提醒(JobScheduler 每 15 分钟一次)
 *
 * 系统的周期任务最小间隔就是 15 分钟,所以它只负责兜底:
 * 实时服务(NotifyForegroundService)活着时由它负责提醒(每 30 秒);
 * 一旦实时服务被系统省电策略或用户杀掉,就由这个任务继续保证不漏消息。
 * 查未读与弹通知的逻辑都在 NotifyHelper 里,两个服务共用。
 */
public class NotifyJobService extends JobService {

    @Override
    public boolean onStartJob(final JobParameters params) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    NotifyHelper.maybeNotify(NotifyJobService.this, NotifyHelper.fetchUnread(NotifyJobService.this));
                } catch (Throwable ignored) {
                }
                jobFinished(params, false);
            }
        }).start();
        return true;
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        return false;
    }
}
