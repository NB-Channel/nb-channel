package top.nbchannel.app;

import android.app.AlertDialog;
import android.app.DownloadManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.DownloadListener;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.getcapacitor.BridgeActivity;

/**
 * NB频道 APP 主 Activity
 *
 * 官方模板之外做的事:
 *  1) 接管网页下载(APK 等)→ 系统下载管理器 + 下载完自动弹安装
 *  2) 返回手势/返回键:先关网页里的弹窗抽屉 → 再网页后退 → 最后二次确认才退出
 *  3) 加载看门狗:页面没加载好就一直显示开屏图;超时则显示「加载失败 + 重试」
 *  4) 消息通知:把网页里的登录态同步到本地,由 JobScheduler 定期查未读并提醒
 *
 * 注意:本 APP 用 server.url 加载线上网站,Capacitor 的 JS 桥接不会注入远程页面,
 *      所以这些能力全部放在原生侧实现,前端无需也无法调用。
 *      代码只用 Android 标准 API(不碰 Capacitor 内部类),避免版本升级后编译不过。
 */
public class MainActivity extends BridgeActivity {

    private static final String ENTRY_URL = "https://github.nb-channel.top/Beta/index-Beta.html";
    private static final int LOAD_TIMEOUT_SECONDS = 25;   // 超过这么久还没加载好就报错
    private static final long EXIT_CONFIRM_MS = 2000;     // 首页返回的二次确认窗口

    private DownloadManager downloadManager;
    private long lastDownloadId = -1L;
    private BroadcastReceiver downloadReceiver;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private boolean pageReady = false;
    private int waitedSeconds = 0;
    private long lastBackTime = 0L;
    private View errorView = null;
    private boolean gotoMessagesOnReady = false;   // 从通知点进来时,加载完直接去消息中心

    private static final String MESSAGES_URL =
            "https://github.nb-channel.top/Beta/messages-Beta.html";

    // 关闭网页里的弹窗/抽屉;返回 true 表示"这次返回已经被消费掉了"
    private static final String CLOSE_OVERLAY_JS =
        "(function(){try{var closed=false;" +
        "var ms=document.querySelectorAll('.custom-modal');" +
        "for(var i=0;i<ms.length;i++){if(getComputedStyle(ms[i]).display!=='none'){ms[i].style.display='none';closed=true;}}" +
        "var d=document.querySelector('.drawer.open');" +
        "if(d){d.classList.remove('open');var mk=document.getElementById('drawerMask');if(mk)mk.style.display='none';closed=true;}" +
        "var nm=document.querySelector('.nav-more.open');if(nm){nm.classList.remove('open');closed=true;}" +
        "var pk=document.querySelectorAll('.pk-ov');for(var j=0;j<pk.length;j++){pk[j].remove();closed=true;}" +
        "var ov=document.querySelectorAll('.modal-overlay');for(var k=0;k<ov.length;k++){ov[k].remove();closed=true;}" +
        "return closed;}catch(e){return false;}})()";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        downloadManager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
        handleGotoIntent(getIntent());
        setupDownload();
        setupLongPressImage();
        setupNotifications();
        startWatchdog();
    }

    // ==================== 1) 下载接管 ====================
    private void setupDownload() {
        try {
            WebView webView = getBridge().getWebView();
            if (webView == null) return;
            webView.setDownloadListener(new DownloadListener() {
                @Override
                public void onDownloadStart(String url, String userAgent, String contentDisposition,
                                            String mimeType, long contentLength) {
                    startDownload(url, userAgent, contentDisposition, mimeType);
                }
            });
        } catch (Exception ignored) {
        }
        downloadReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L);
                if (id != lastDownloadId) return;
                try {
                    Uri uri = downloadManager.getUriForDownloadedFile(id);
                    if (uri != null) installApk(uri);
                } catch (Exception ignored) {
                }
            }
        };
        try {
            registerReceiver(downloadReceiver, new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));
        } catch (Exception ignored) {
        }
    }

    private void startDownload(String url, String userAgent, String contentDisposition, String mimeType) {
        try {
            String fileName = guessFileName(url, contentDisposition);
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            request.setTitle(fileName);
            request.setDescription("NB频道 · 正在下载");
            request.setMimeType(mimeType);
            request.addRequestHeader("User-Agent", userAgent);
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
            lastDownloadId = downloadManager.enqueue(request);
        } catch (Exception e) {
            try {
                Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
            } catch (Exception ignored) {
            }
        }
    }

    private void installApk(Uri apkUri) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception ignored) {
        }
    }

    private String guessFileName(String url, String contentDisposition) {
        String name = "NBChannel-download";
        try {
            if (contentDisposition != null) {
                int i = contentDisposition.indexOf("filename=");
                if (i >= 0) name = contentDisposition.substring(i + 9).replace("\"", "").trim();
            }
            if (name.equals("NBChannel-download")) {
                String path = Uri.parse(url).getLastPathSegment();
                if (path != null && path.length() > 0) name = path;
            }
        } catch (Exception ignored) {
        }
        if (!name.toLowerCase().endsWith(".apk") && url.toLowerCase().contains(".apk")) name = name + ".apk";
        return name;
    }

    // ==================== 1.5) 长按图片:保存到相册 ====================
    private void setupLongPressImage() {
        try {
            WebView webView = getBridge().getWebView();
            if (webView == null) return;
            webView.setOnLongClickListener(new View.OnLongClickListener() {
                @Override
                public boolean onLongClick(View v) {
                    try {
                        WebView.HitTestResult result = webView.getHitTestResult();
                        if (result == null) return false;
                        int type = result.getType();
                        // 只有真的长按在图片上才接管,其它情况返回 false 保留文本选择等默认行为
                        if (type == WebView.HitTestResult.IMAGE_TYPE
                                || type == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE) {
                            String url = result.getExtra();
                            if (url != null && url.length() > 0) {
                                showImageMenu(url);
                                return true;
                            }
                        }
                    } catch (Throwable ignored) {
                    }
                    return false;
                }
            });
        } catch (Throwable ignored) {
        }
    }

    private void showImageMenu(final String url) {
        try {
            new AlertDialog.Builder(this)
                .setTitle("图片")
                .setItems(new String[]{"保存到相册", "复制图片链接"},
                    new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                            if (which == 0) saveImageToGallery(url);
                            else copyToClipboard(url);
                        }
                    })
                .setNegativeButton("取消", null)
                .show();
        } catch (Throwable ignored) {
        }
    }

    private void saveImageToGallery(String url) {
        try {
            String ext = ".png";
            String lower = url.toLowerCase();
            if (lower.contains(".jpg") || lower.contains(".jpeg")) ext = ".jpg";
            else if (lower.contains(".gif")) ext = ".gif";
            else if (lower.contains(".webp")) ext = ".webp";
            String name = "NBChannel_" + System.currentTimeMillis() + ext;

            DownloadManager.Request req = new DownloadManager.Request(Uri.parse(url));
            req.setTitle(name);
            req.setDescription("NB频道 · 保存图片");
            req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            req.setDestinationInExternalPublicDir(Environment.DIRECTORY_PICTURES, "NB频道/" + name);
            downloadManager.enqueue(req);
            Toast.makeText(this, "正在保存到相册(图片/相册 里的 NB频道 文件夹)", Toast.LENGTH_LONG).show();
        } catch (Throwable t) {
            Toast.makeText(this, "保存失败,可尝试长按后选「复制图片链接」", Toast.LENGTH_SHORT).show();
        }
    }

    private void copyToClipboard(String text) {
        try {
            android.content.ClipboardManager cm =
                    (android.content.ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (cm != null) {
                cm.setPrimaryClip(android.content.ClipData.newPlainText("NB频道图片链接", text));
                Toast.makeText(this, "链接已复制", Toast.LENGTH_SHORT).show();
            }
        } catch (Throwable ignored) {
        }
    }

    // ==================== 1.6) 从通知进来时直接跳消息中心 ====================
    private void handleGotoIntent(Intent intent) {
        try {
            if (intent != null && "messages".equals(intent.getStringExtra("nb_goto"))) {
                gotoMessagesOnReady = true;
            }
        } catch (Throwable ignored) {
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleGotoIntent(intent);
        if (pageReady) openMessages();   // APP 已经开着,直接切过去
    }

    private void openMessages() {
        gotoMessagesOnReady = false;
        try {
            WebView wv = getBridge().getWebView();
            if (wv != null) wv.loadUrl(MESSAGES_URL);
        } catch (Throwable ignored) {
        }
    }

    // ==================== 1.7) 引导加入电池优化白名单 ====================
    // 国产 ROM 的后台清理会杀掉实时提醒服务,加入白名单能显著改善
    private void askBatteryOptimization() {
        try {
            if (Build.VERSION.SDK_INT < 23) return;
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (pm == null) return;
            if (pm.isIgnoringBatteryOptimizations(getPackageName())) return;  // 已在白名单

            SharedPreferences sp = getSharedPreferences("nb", Context.MODE_PRIVATE);
            if (sp.getBoolean("asked_battery_opt", false)) return;            // 只问一次
            sp.edit().putBoolean("asked_battery_opt", true).apply();

            new AlertDialog.Builder(this)
                .setTitle("让消息提醒更可靠")
                .setMessage("部分手机的省电策略会清掉后台,导致新消息提醒收不到。\n\n"
                          + "建议把「NB频道」加入电池优化白名单 —— 点「去设置」后在系统弹窗里选「允许」即可。")
                .setPositiveButton("去设置", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface d, int w) {
                        try {
                            Intent i = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                            i.setData(Uri.parse("package:" + getPackageName()));
                            startActivity(i);
                        } catch (Throwable t) {
                            try {
                                startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));
                            } catch (Throwable ignored) {
                            }
                        }
                    }
                })
                .setNegativeButton("以后再说", null)
                .show();
        } catch (Throwable ignored) {
        }
    }

    // ==================== 2) 加载看门狗(开屏保持 + 失败页) ====================
    private void startWatchdog() {
        pageReady = false;
        waitedSeconds = 0;
        ui.postDelayed(watchdog, 1200);
    }

    private final Runnable watchdog = new Runnable() {
        @Override
        public void run() {
            if (pageReady) return;
            WebView wv = null;
            try {
                if (getBridge() != null) wv = getBridge().getWebView();
            } catch (Exception ignored) {
            }
            int progress = -1;
            try {
                if (wv != null) progress = wv.getProgress();
            } catch (Exception ignored) {
            }
            if (progress >= 100) {
                onPageReady();
                return;
            }
            waitedSeconds++;
            if (waitedSeconds >= LOAD_TIMEOUT_SECONDS) {
                showErrorView(progress <= 0 ? "网络好像没连上" : "页面加载太慢了");
                return;
            }
            ui.postDelayed(this, 1000);
        }
    };

    private void onPageReady() {
        pageReady = true;
        hideErrorView();
        hideSplash();
        syncLoginState();
        if (gotoMessagesOnReady) {
            // 从通知点进来的:等页面稳定一下再切到消息中心
            ui.postDelayed(new Runnable() {
                @Override
                public void run() {
                    openMessages();
                }
            }, 400);
        }
        // 首次启动时引导加入电池优化白名单(延迟几秒,别打断开屏体验)
        ui.postDelayed(new Runnable() {
            @Override
            public void run() {
                askBatteryOptimization();
            }
        }, 4000);
    }

    private void hideSplash() {
        try {
            int id = getResources().getIdentifier("splash", "id", getPackageName());
            if (id != 0) {
                View v = findViewById(id);
                if (v != null) {
                    v.setVisibility(View.GONE);
                    return;
                }
            }
            ViewGroup root = findViewById(android.R.id.content);
            if (root != null) hideFirstImageView(root);
        } catch (Exception ignored) {
        }
    }

    private boolean hideFirstImageView(ViewGroup group) {
        for (int i = 0; i < group.getChildCount(); i++) {
            View child = group.getChildAt(i);
            if (child instanceof ImageView) {
                child.setVisibility(View.GONE);
                return true;
            }
            if (child instanceof ViewGroup && hideFirstImageView((ViewGroup) child)) return true;
        }
        return false;
    }

    private void showErrorView(String reason) {
        if (errorView != null) return;
        try {
            LinearLayout box = new LinearLayout(this);
            box.setOrientation(LinearLayout.VERTICAL);
            box.setGravity(Gravity.CENTER);
            box.setBackgroundColor(Color.parseColor("#0f172a"));
            int pad = dp(28);

            TextView icon = new TextView(this);
            icon.setText("📡");
            icon.setTextSize(52);
            icon.setGravity(Gravity.CENTER);

            TextView title = new TextView(this);
            title.setText("页面加载失败");
            title.setTextColor(Color.WHITE);
            title.setTextSize(19);
            title.setGravity(Gravity.CENTER);
            title.setPadding(0, dp(14), 0, dp(8));

            TextView desc = new TextView(this);
            desc.setText(reason + "\n请检查网络连接后重试");
            desc.setTextColor(Color.parseColor("#94a3b8"));
            desc.setTextSize(13.5f);
            desc.setGravity(Gravity.CENTER);
            desc.setLineSpacing(dp(4), 1f);

            Button retry = new Button(this);
            retry.setText("重新加载");
            retry.setTextSize(15);
            retry.setTextColor(Color.WHITE);
            GradientDrawable bg = new GradientDrawable();
            bg.setColor(Color.parseColor("#3b82f6"));
            bg.setCornerRadius(dp(24));
            retry.setBackground(bg);
            LinearLayout.LayoutParams rp = new LinearLayout.LayoutParams(dp(160), dp(46));
            rp.topMargin = dp(22);
            retry.setLayoutParams(rp);
            retry.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    hideErrorView();
                    retryLoad();
                }
            });

            box.addView(icon);
            box.addView(title);
            box.addView(desc);
            box.addView(retry);
            box.setPadding(pad, pad, pad, pad);

            addContentView(box, new ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            errorView = box;
        } catch (Exception ignored) {
        }
    }

    private void hideErrorView() {
        try {
            if (errorView != null) {
                ViewGroup parent = (ViewGroup) errorView.getParent();
                if (parent != null) parent.removeView(errorView);
                errorView = null;
            }
        } catch (Exception ignored) {
        }
    }

    private void retryLoad() {
        try {
            WebView wv = getBridge().getWebView();
            pageReady = false;
            waitedSeconds = 0;
            if (wv != null) wv.loadUrl(ENTRY_URL);
            ui.postDelayed(watchdog, 1200);
        } catch (Exception ignored) {
        }
    }

    private int dp(int v) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics());
    }

    // ==================== 3) 返回手势 ====================
    @Override
    public void onBackPressed() {
        WebView wv = null;
        try {
            if (getBridge() != null) wv = getBridge().getWebView();
        } catch (Exception ignored) {
        }
        if (wv == null) {
            super.onBackPressed();
            return;
        }
        // 有错误页时,返回先关错误页
        if (errorView != null) {
            hideErrorView();
            return;
        }
        // 先问网页:有没有开着的弹窗/抽屉?有就关掉,这次返回到此为止
        try {
            wv.evaluateJavascript(CLOSE_OVERLAY_JS, value -> {
                boolean closed = value != null && value.contains("true");
                if (closed) return;
                goBackOrExit();
            });
        } catch (Exception e) {
            goBackOrExit();
        }
    }

    private void goBackOrExit() {
        WebView wv = null;
        try {
            if (getBridge() != null) wv = getBridge().getWebView();
        } catch (Exception ignored) {
        }
        if (wv != null && wv.canGoBack()) {
            wv.goBack();
            return;
        }
        // 已经在首页:两秒内再返回一次才真的退出,避免误触
        long now = System.currentTimeMillis();
        if (now - lastBackTime < EXIT_CONFIRM_MS) {
            finish();
        } else {
            lastBackTime = now;
            try {
                Toast.makeText(this, "再滑一次退出 NB频道", Toast.LENGTH_SHORT).show();
            } catch (Exception ignored) {
            }
        }
    }

    // ==================== 4) 消息通知 ====================
    private void setupNotifications() {
        try {
            NotifyHelper.createChannels(this);
        } catch (Throwable ignored) {
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 1001);
            }
        } catch (Exception ignored) {
        }
        // 兜底:系统周期任务,最短 15 分钟一次
        scheduleNotifyJob();
        // 准实时:前台服务每 30 秒查一次(通知栏会有常驻通知,带「停止」按钮)
        startRealtimeNotify();
    }

    private void startRealtimeNotify() {
        try {
            Intent intent = new Intent(this, NotifyForegroundService.class);
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent);
            else startService(intent);
        } catch (Throwable ignored) {
        }
    }

    private void scheduleNotifyJob() {
        try {
            JobScheduler js = (JobScheduler) getSystemService(Context.JOB_SCHEDULER_SERVICE);
            if (js == null) return;
            JobInfo job = new JobInfo.Builder(1001, new ComponentName(this, NotifyJobService.class))
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPeriodic(15 * 60 * 1000L)
                    .build();
            js.schedule(job);
        } catch (Exception ignored) {
        }
    }

    /** 把网页里的登录态(localStorage)同步到本地,供后台通知任务使用 */
    private void syncLoginState() {
        try {
            WebView wv = getBridge().getWebView();
            if (wv == null) return;
            String js = "(function(){try{var u=localStorage.getItem('nb_user')||'';"
                    + "var s=localStorage.getItem('nb_session')||'';var id='';"
                    + "try{id=(JSON.parse(u)||{}).id||'';}catch(e){}"
                    + "return id+'|'+s;}catch(e){return '|';}})()";
            wv.evaluateJavascript(js, value -> {
                try {
                    if (value == null || value.length() < 3) return;
                    String v = value;
                    if (v.startsWith("\"") && v.endsWith("\"")) v = v.substring(1, v.length() - 1);
                    v = v.replace("\\\"", "\"").replace("\\\\", "\\");
                    int bar = v.indexOf('|');
                    if (bar <= 0) return;
                    String uid = v.substring(0, bar).trim();
                    String token = v.substring(bar + 1).trim();
                    if (uid.isEmpty() || token.isEmpty()) return;
                    SharedPreferences sp = getSharedPreferences("nb", Context.MODE_PRIVATE);
                    sp.edit().putString("uid", uid).putString("token", token).apply();
                } catch (Exception ignored) {
                }
            });
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onDestroy() {
        try {
            ui.removeCallbacks(watchdog);
        } catch (Exception ignored) {
        }
        try {
            if (downloadReceiver != null) unregisterReceiver(downloadReceiver);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }
}
