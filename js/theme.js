/* ============================================================
   NB频道 · 主题引擎
   在 <head> 里同步加载（不加 defer），保证渲染前就定好 class，
   不会出现「先看到默认配色、闪一下才变色」。

   用法：<script src="../js/theme.js"></script>
   ============================================================ */
(function () {
    'use strict';

    var KEY = 'nb_theme';                 // default | national | tech
    var ATTR = 'theme';                   // 加在 <html> 上的属性名

    /* ---------- 国庆主题的限时窗口 ----------
       每年 10 月 1 日 00:00 ~ 10 月 7 日 23:59（按访问者本地时间）。
       窗口内：默认启用国庆主题，用户可以自己换掉。
       窗口外：选项隐藏；如果本地存的是 national，自动回落默认。 */
    function inNationalWindow(now) {
        var d = now || new Date();
        var m = d.getMonth() + 1;
        var day = d.getDate();
        return m === 10 && day >= 1 && day <= 7;
    }

    /* ---------- 读取用户选择 ---------- */
    function readChoice() {
        var v = null;
        /* URL 参数优先：?theme=tech / ?theme=national / ?theme=default
           用途一是方便调试，二是可以让别人分享「某个主题下的这一页」。 */
        try {
            var m = /[?&]theme=([a-z]+)/i.exec(location.search);
            if (m) {
                var q = m[1].toLowerCase();
                if (q === 'national' && inNationalWindow()) return 'national';
                if (q === 'tech') return 'tech';
                if (q === 'default') return 'default';
            }
        } catch (e) {}
        try { v = localStorage.getItem(KEY); } catch (e) { v = null; }
        if (v === 'national' && !inNationalWindow()) v = null;   // 过期了
        if (v !== 'national' && v !== 'tech' && v !== 'default') v = null;
        return v;
    }

    /* ---------- 应用到 <html> ---------- */
    function apply(choice) {
        var el = document.documentElement;
        var real = choice;
        if (!real) real = inNationalWindow() ? 'national' : 'default';
        if (real === 'default') el.removeAttribute(ATTR);
        else el.setAttribute(ATTR, real);
        el.setAttribute('data-theme-resolved', real);
    }

    /* ---------- 对外接口 ---------- */
    var API = {
        KEY: KEY,
        // 用户显式选择的（可能是 null，表示"跟随默认"）
        get: readChoice,
        // 此刻实际生效的
        resolved: function () {
            var c = readChoice();
            if (c) return c;
            return inNationalWindow() ? 'national' : 'default';
        },
        // 用户主动切换：传 'default' 表示回到默认
        set: function (choice) {
            try {
                if (choice === 'default' || !choice) localStorage.setItem(KEY, 'default');
                else localStorage.setItem(KEY, choice);
            } catch (e) {}
            apply(choice);
            try {
                window.dispatchEvent(new CustomEvent('nb-theme-change', {
                    detail: { theme: API.resolved() }
                }));
            } catch (e) {}
        },
        // 国庆主题现在能不能选
        nationalAvailable: inNationalWindow,

        // 可选主题的完整列表（给设置界面用）
        list: function () {
            var arr = [
                { id: 'default', name: '默认', icon: '🎨',
                  desc: 'NB频道原本的蓝白配色' },
                { id: 'tech', name: '科技', icon: '🚀',
                  desc: '深空蓝 + 霓虹光效，配理科站的气质' }
            ];
            if (inNationalWindow()) {
                arr.splice(1, 0, { id: 'national', name: '国庆', icon: '🇨🇳',
                  desc: '红金配色，限时 10 月 1 日 ~ 7 日' });
            }
            return arr;
        }
    };

    apply(readChoice());
    window.NBTheme = API;
})();
