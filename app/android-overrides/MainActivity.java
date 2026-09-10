package top.nbchannel.app;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.webkit.DownloadListener;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

/**
 * NB频道 APP 主 Activity
 *
 * 做了两件官方模板没有的事:
 *  1) 拦截网页里的下载请求(APK 等),交给系统下载管理器,下完自动弹出安装界面
 *     —— WebView 本身没有下载管理器,不处理的话点击 APK 链接会"毫无反应"
 *  2) 下载完成后用 FileProvider URI 调系统安装器(Android 7+ 要求 content:// 而非 file://)
 *
 * 注意:本 APP 用 server.url 加载线上网站,Capacitor 的 JS 桥接不会注入远程页面,
 *      所以这些能力必须放在原生侧实现,前端无需也无法调用。
 */
public class MainActivity extends BridgeActivity {

    private DownloadManager downloadManager;
    private long lastDownloadId = -1L;
    private BroadcastReceiver downloadReceiver;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        downloadManager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);

        // ---- 1) 让 WebView 支持下载(Apk/压缩包/任意文件) ----
        WebView webView = getBridge().getWebView();
        if (webView != null) {
            webView.setDownloadListener(new DownloadListener() {
                @Override
                public void onDownloadStart(String url, String userAgent, String contentDisposition,
                                            String mimeType, long contentLength) {
                    startDownload(url, userAgent, contentDisposition, mimeType);
                }
            });
        }

        // ---- 2) 下载完成后自动弹安装界面 ----
        downloadReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L);
                if (id != lastDownloadId) return;
                Uri uri = downloadManager.getUriForDownloadedFile(id);
                if (uri != null) {
                    installApk(uri);
                }
            }
        };
        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
        registerReceiver(downloadReceiver, filter);
    }

    /** 用系统下载管理器把文件下到公共下载目录(通知栏可见进度) */
    private void startDownload(String url, String userAgent, String contentDisposition, String mimeType) {
        try {
            String fileName = guessFileName(url, contentDisposition);
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            request.setTitle(fileName);
            request.setDescription("NB频道 · 正在下载");
            request.setMimeType(mimeType);
            request.addRequestHeader("User-Agent", userAgent);
            request.setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
            lastDownloadId = downloadManager.enqueue(request);
        } catch (Exception e) {
            // 下载失败时退回系统浏览器处理,至少不会"点了没反应"
            try {
                Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
            } catch (Exception ignored) {
            }
        }
    }

    /** 调系统安装器。Android 8+ 需要用户授权"安装未知应用",系统会自己弹确认框 */
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

    /** 从 URL / Content-Disposition 里猜一个像样的文件名 */
    private String guessFileName(String url, String contentDisposition) {
        String name = "NBChannel-download";
        try {
            if (contentDisposition != null) {
                int i = contentDisposition.indexOf("filename=");
                if (i >= 0) {
                    name = contentDisposition.substring(i + 9).replace("\"", "").trim();
                }
            }
            if (name.equals("NBChannel-download")) {
                String path = Uri.parse(url).getLastPathSegment();
                if (path != null && path.length() > 0) name = path;
            }
        } catch (Exception ignored) {
        }
        if (!name.toLowerCase().endsWith(".apk") && url.toLowerCase().contains(".apk")) {
            name = name + ".apk";
        }
        return name;
    }

    @Override
    public void onDestroy() {
        try {
            if (downloadReceiver != null) unregisterReceiver(downloadReceiver);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }
}
