package top.nbchannel.app;

import android.app.AlertDialog;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * 原生底部导航（10 项，横向可滑动）
 *
 * 为什么用代码建 UI：
 *   Capacitor 的页面布局是它自己生成的（android/app/src/main/res/layout），
 *   我们不去改它，只在 Activity 的根 ViewGroup 上叠一层底部栏 —— 这样
 *   Capacitor 升级也不会把我们的改动冲掉。
 *
 * 视觉：
 *   底部栏 = 深色半透明玻璃（#0f172a 88%）+ 顶部 1px 高光线 + 上方柔和投影
 *   ⚠️ Android 12+ 才能做「真模糊」，10/11 只能用半透明拟态，这是系统限制。
 *
 * 交互：
 *   点击 → 在当前域名的 Beta 目录下打开对应页面
 *   扫一扫 → 调用网页里已有的 window.NBQr.scan()（复用 MainActivity 的原生扫码）
 *   更多 → 毛玻璃面板列出其余页面
 */
public class BottomNav {

    /** 当前选中项的下标（用于高亮） */
    private static int selected = 0;
    private static String lastUrl = "";
    private static boolean installed = false;

    // 10 个入口：图标、文字、Beta 路径（null 表示特殊动作）
    private static final String[][] ITEMS = {
            {"🏠", "首页",     "Beta/index-Beta.html"},
            {"💬", "评论区",    "Beta/comments-Beta.html"},
            {"🤖", "AI助手",    "Beta/ai-Beta.html"},
            {"📰", "NB报刊社",  "Beta/newspaper-Beta.html"},
            {"📈", "虚拟股票",  "Beta/stock-Beta.html"},
            {"🏦", "NB银行",    "Beta/bank-Beta.html"},
            {"🌦️", "天气瞎报",  "Beta/weather-Beta.html"},
            {"👤", "个人中心",  "Beta/profile-Beta.html"},
            {"📷", "扫一扫",    null},
            {"🌙", "主题",     "THEME"},
            {"⋯",  "更多",     "MORE"},
    };

    // 「更多」面板：分组标题 + 路径
    private static final String[][] MORE = {
            {"📖 内容", ""},
            {"视频",         "Beta/videos-Beta.html"},
            {"作品分享",     "Beta/product_share-Beta.html"},
            {"关于",         "Beta/about-Beta.html"},
            {"更新日志",     "Beta/changelog-Beta.html"},
            {"用户守则",     "Beta/rules-Beta.html"},
            {"💰 NB 经济", ""},
            {"NB商店",       "Beta/shop-Beta.html"},
            {"背包",         "Beta/backpack-Beta.html"},
            {"称号",         "Beta/titles-Beta.html"},
            {"成就",         "Beta/achievements-Beta.html"},
            {"注册公司",     "Beta/register_company-Beta.html"},
            {"彩票记录",     "Beta/lottery_records-Beta.html"},
            {"👥 社区", ""},
            {"好友",         "Beta/chat-Beta.html"},
            {"消息",         "Beta/messages-Beta.html"},
            {"小黑屋",       "Beta/ban-Beta.html"},
            {"🔬 工具", ""},
            {"化学工具",     "Beta/tools-Beta.html"},
            {"模型价格",     "Beta/pricing-Beta.html"},
            {"APP 下载",     "Beta/APP-Beta.html"},
    };

    /** dp → px（不依赖 MainActivity 的私有方法） */
    private static int dp(MainActivity a, int v) {
        return (int) (v * a.getResources().getDisplayMetrics().density + 0.5f);
    }

    public static void install(MainActivity act, WebView wv) {
        if (installed) return;
        installed = true;

        ViewGroup root = act.findViewById(android.R.id.content);
        if (root == null || wv == null) return;

        // ---- 底部栏容器（叠在 WebView 上方，贴底） ----
        HorizontalScrollView scroll = new HorizontalScrollView(act);
        scroll.setHorizontalScrollBarEnabled(false);
        scroll.setClipToPadding(false);

        LinearLayout bar = new LinearLayout(act);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);

        GradientDrawable glass = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xE60F172A, 0xF20F172A});
        bar.setBackground(glass);
        bar.setPadding(dp(act, 4), dp(act, 6), dp(act, 4), dp(act, 6));

        final TextView[] emojiViews = new TextView[ITEMS.length];
        final TextView[] labelViews = new TextView[ITEMS.length];

        for (int i = 0; i < ITEMS.length; i++) {
            final int idx = i;
            LinearLayout cell = new LinearLayout(act);
            cell.setOrientation(LinearLayout.VERTICAL);
            cell.setGravity(Gravity.CENTER);
            LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(
                    dp(act, 62), ViewGroup.LayoutParams.WRAP_CONTENT);
            cell.setLayoutParams(cp);
            cell.setPadding(0, dp(act, 4), 0, dp(act, 4));

            TextView em = new TextView(act);
            em.setText(ITEMS[i][0]);
            em.setTextSize(TypedValue.COMPLEX_UNIT_SP, 19);
            em.setGravity(Gravity.CENTER);
            emojiViews[i] = em;

            TextView lb = new TextView(act);
            lb.setText(ITEMS[i][1]);
            lb.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
            lb.setGravity(Gravity.CENTER);
            lb.setTextColor(0xFF8B93A1);
            lb.setPadding(0, dp(act, 2), 0, 0);
            labelViews[i] = lb;

            cell.addView(em);
            cell.addView(lb);
            cell.setOnClickListener(v -> onTap(act, wv, idx, emojiViews, labelViews));
            bar.addView(cell);
        }

        scroll.addView(bar);

        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.gravity = Gravity.BOTTOM;
        root.addView(scroll, lp);

        // ---- WebView 底部留出导航栏高度，避免内容被挡住 ----
        wv.setPadding(0, 0, 0, dp(act, 56));

        // ---- 高亮跟随当前页面 ----
        final Handler h = new Handler(Looper.getMainLooper());
        Runnable tick = new Runnable() {
            @Override public void run() {
                try {
                    String url = wv.getUrl();
                    if (url != null && !url.equals(lastUrl)) {
                        lastUrl = url;
                        injectHideNav(wv);
                    }
                    if (url != null) {
                        for (int i = 0; i < ITEMS.length; i++) {
                            String path = ITEMS[i][2];
                            if (path == null || "MORE".equals(path)) continue;
                            String key = path.substring(path.lastIndexOf('/') + 1);
                            highlight(emojiViews, labelViews, i, url.contains(key));
                        }
                    }
                } catch (Exception ignored) {}
                h.postDelayed(this, 1200);
            }
        };
        h.post(tick);

        highlight(emojiViews, labelViews, 0, true);
    }

    private static void highlight(TextView[] em, TextView[] lb, int idx, boolean on) {
        if (on) {
            selected = idx;
            em[idx].setAlpha(1f);
            lb[idx].setTextColor(0xFF3988F6);
            lb[idx].setTypeface(null, Typeface.BOLD);
        } else {
            em[idx].setAlpha(0.72f);
            lb[idx].setTextColor(0xFF8B93A1);
            lb[idx].setTypeface(null, Typeface.NORMAL);
        }
    }

    private static void onTap(MainActivity act, WebView wv, int idx,
                              TextView[] em, TextView[] lb) {
        String path = ITEMS[idx][2];
        if (path == null) {
            // 扫一扫：调用网页里已有的原生扫码桥
            try {
                wv.evaluateJavascript(
                        "(function(){try{if(window.NBQr&&window.NBQr.scan){window.NBQr.scan();}" +
                        "else{alert('当前页面没有扫码能力，去首页或作品分享页试试');}}catch(e){}})()", null);
            } catch (Exception ignored) {}
            return;
        }
        if ("THEME".equals(path)) {
            // 切换网站主题：改 localStorage 的 theme + 切 body.dark-mode
            try {
                wv.evaluateJavascript(
                        "(function(){try{var d=document.body.classList.toggle('dark-mode');" +
                        "localStorage.setItem('theme', d?'dark':'light');}catch(e){}})()", null);
            } catch (Exception ignored) {}
            return;
        }
        if ("MORE".equals(path)) {
            highlight(em, lb, idx, true);
            showMore(act, wv);
            return;
        }
        String base = origin(wv.getUrl());
        wv.loadUrl(base + "/" + path);
        for (int i = 0; i < ITEMS.length; i++) highlight(em, lb, i, i == idx);
    }

    /** 从当前地址里取 https://host —— 用户选哪个镜像就跟着哪个 */
    private static String origin(String url) {
        try {
            if (url != null && url.startsWith("http")) {
                int s = url.indexOf("://") + 3;
                int e = url.indexOf('/', s);
                if (e > s) return url.substring(0, e);
            }
        } catch (Exception ignored) {}
        return "https://nb-channel.top";
    }

    private static void showMore(MainActivity act, WebView wv) {
        String[] labels = new String[MORE.length];
        for (int i = 0; i < MORE.length; i++) labels[i] = MORE[i][0];

        AlertDialog.Builder b = new AlertDialog.Builder(act);
        b.setTitle("更多功能");
        b.setItems(labels, (d, which) -> {
            String path = MORE[which][1];
            if (path == null || path.isEmpty()) return;   // 分组标题，点了不做事
            wv.loadUrl(origin(wv.getUrl()) + "/" + path);
        });
        b.setNegativeButton("关闭", null);
        AlertDialog dlg = b.create();
        dlg.show();
        // 对话框也用深色玻璃风，跟底部栏统一
        try {
            dlg.getWindow().setBackgroundDrawable(new GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    new int[]{0xF20F172A, 0xF20F172A}));
        } catch (Exception ignored) {}
    }

    /** 隐藏网页自带的顶部导航（用自己的底部栏代替） */
    private static void injectHideNav(WebView wv) {
        String js =
            "(function(){try{" +
            "if(document.getElementById('nbapp-hide-nav'))return;" +
            "var st=document.createElement('style');st.id='nbapp-hide-nav';" +
            "st.textContent='" +
            ".top-nav,.nav-menu,.quick-nav,.nav-container,.nav-links,.nav-actions," +
            ".dash-nav,.mobile-nav,.nav-bar{display:none!important}" +
            "body{padding-top:0!important}" +
            "';" +
            "document.head.appendChild(st);" +
            "}catch(e){}})()";
        try { wv.evaluateJavascript(js, null); } catch (Exception ignored) {}
    }

}
