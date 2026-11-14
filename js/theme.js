/* ============================================================
   NB频道 · 主题引擎
   在 <head> 里同步加载（不加 defer），保证渲染前就定好属性，
   不会出现「先看到默认配色、闪一下才变色」。

   主题分两类：
     · 常驻（always）—— 随时都能选
     · 节日（window）—— 只在指定日期窗口里出现在选项里

   节日里春节、中秋是农历，每年公历日期都不同，
   所以用 FESTIVAL 表把最近几年的正日子写死，前后各放几天。
   用法：<script src="../js/theme.js"></script>
   ============================================================ */
(function () {
    'use strict';

    var KEY = 'nb_theme';        // 存用户选的主题 id
    var ATTR = 'theme';          // 加在 <html> 上的属性名

    /* ============================================================
       农历 → 春节（正月初一）日期
       用 1900~2100 的农历数据表算，不联网、不查 API。
       表里一年一个 16 进制数：
     低 4 位   = 闰哪个月（0 表示没闰月）
     中间 12 位 = 12 个月的大小月（1=大月 30 天，0=小月 29 天）
     高 4 位   = 闰月的天数（1=30 天，0=29 天）
       ============================================================ */
    var LunarSpringFestival = (function () {
    'use strict';

    var lunarInfo = [
        0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
        0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
        0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
        0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
        0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
        0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
        0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
        0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
        0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
        0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x05ac0, 0x0ab60, 0x096d5, 0x092e0,
        0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
        0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
        0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
        0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
        0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
        0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
        0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
        0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
        0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
        0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
        0x0d520
    ];

    /* 农历 y 年总共多少天 */
    function yearDays(y) {
        var i, sum = 348;
        for (i = 0x8000; i > 0x8; i >>= 1) sum += (lunarInfo[y - 1900] & i) ? 1 : 0;
        return sum + leapDays(y);
    }
    /* 闰月月份，0 = 无闰 */
    function leapMonth(y) { return lunarInfo[y - 1900] & 0xf; }
    /* 闰月天数，0 = 无 */
    function leapDays(y) {
        if (leapMonth(y)) return (lunarInfo[y - 1900] & 0x10000) ? 30 : 29;
        return 0;
    }

    /* 1900 正月初一 = 1900-01-31 */
    var BASE = Date.UTC(1900, 0, 31);

    /* 返回某年春节（正月初一）的本地 0 点 Date */
    function get(year) {
        if (year < 1901 || year > 2100) return null;
        var offset = 0;
        for (var y = 1900; y < year; y++) offset += yearDays(y);
        var d = new Date(BASE + offset * 86400000);
        return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    }

    return { get: get };
    })();


    /* ---------- 节日正日子（公历）----------
       农历节日每年换算出来的公历日期不一样，这里列最近几年。
       表里没有的年份 → 该节日不出现（宁可不显示，也不要显示错）。 */
    var FESTIVAL = {
        /* 春节（正月初一）的公立日期 */
    };

    /* 每个节日提前 / 延后几天出现 */
    var SPAN = { spring: { before: 1, after: 14 } };   // 除夕 ~ 正月十五

    /* ---------- 主题清单 ----------
       window: 节日主题的正日子来源（FESTIVAL 的键名）
       没有 window 的就是常驻主题 */
    var THEMES = [
        { id: 'default',   name: '默认',      icon: '\uD83C\uDFA8',
          desc: 'NB频道原本的蓝白配色' },
        { id: 'tech',      name: '科技',      icon: '\uD83D\uDE80',
          desc: '深空蓝 + 霓虹光效，配理科站的气质' },
        { id: 'cyber',     name: '赛博朋克',  icon: '\uD83C\uDF03',
          desc: '霓虹紫粉 + 雨夜，故障艺术标题' },
        { id: 'ink',       name: '墨韵',      icon: '\uD83D\uDD8C\uFE0F',
          desc: '宣纸米白 + 焦墨，安静、省电' },
        { id: 'pixel',     name: '像素',      icon: '\uD83D\uDC7E',
          desc: '8-bit 有限色板，回到红白机年代' },
        { id: 'eyecare',   name: '护眼',      icon: '\uD83C\uDF19',
          desc: '低对比暖灰，去光效，夜里看不累' },
        { id: 'national',  name: '国庆',      icon: '\uD83C\uDDE8\uD83C\uDDF3',
          desc: '红金配色，限时 10 月 1 日 ~ 7 日',
          fixed: [10, 1, 7] },
        { id: 'spring',    name: '春节',      icon: '\uD83E\uDDE7',
          desc: '朱红 + 鎏金，限时：除夕到正月十五',
          festival: 'spring' },
    ];

    var BY_ID = {};
    THEMES.forEach(function (t) { BY_ID[t.id] = t; });

    /* ---------- 日期判定 ---------- */
    function sameDay(d, m, day) {
        return (d.getMonth() + 1) === m && d.getDate() === day;
    }
    /* 离正日几天（负数=之前，正数=之后） */
    function dayDiff(now, m, day) {
        var center = new Date(now.getFullYear(), m - 1, day);
        center.setHours(0, 0, 0, 0);
        var t = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        return Math.round((t - center) / 86400000);
    }
    function inSpan(now, m, day, span) {
        return Math.abs(dayDiff(now, m, day)) <= span;
    }
    /* 不对称窗口：前两天 ~ 后两周（春节：除夕 ~ 十五） */
    function inWindow(now, m, day, w) {
        var d = dayDiff(now, m, day);
        return d >= -(w.before || 0) && d <= (w.after || 0);
    }

    /* 这个主题此刻可不可选 */
    function available(id, now) {
        var t = BY_ID[id];
        if (!t) return false;
        var d = now || new Date();

        if (t.fixed) {                                   // 国庆：固定公历区间
            var m = d.getMonth() + 1, day = d.getDate();
            var a = t.fixed[0] * 100 + t.fixed[1];
            var b = t.fixed[0] * 100 + t.fixed[2];
            var cur = m * 100 + day;
            return cur >= a && cur <= b;
        }
        if (t.festival) {                                // 春节 / 中秋：查表
            var md = null;
            if (t.festival === 'spring') {
                var ny = LunarSpringFestival.get(d.getFullYear());
                if (!ny) return false;
                md = [ny.getMonth() + 1, ny.getDate()];
            } else {
                var table = FESTIVAL[t.festival] || {};
                md = table[d.getFullYear()];
            }
            if (!md) return false;                       // 这一年没登记
            var sp = SPAN[t.festival];
            if (sp && typeof sp === 'object') return inWindow(d, md[0], md[1], sp);
            return inSpan(d, md[0], md[1], sp || 3);
        }
        return true;                                     // 常驻
    }

    /* ---------- 读取用户选择 ---------- */
    function readChoice() {
        var v = null;
        /* URL 参数优先：?theme=cyber / ?theme=ink / ?theme=default …
           用途一是方便调试，二是可以让别人分享「某个主题下的这一页」。 */
        try {
            var m = /[?&]theme=([a-z]+)/i.exec(location.search);
            /* 调试用：?theme=xxx&preview=1
               可以无视节日的日期窗口直接预览，方便平时调样式。
               普通访客不带这个参数，看到的仍然是正常的窗口限制。 */
            var preview = /[?&]preview=1/i.test(location.search);
            if (m) {
                var q = m[1].toLowerCase();
                if (BY_ID[q] && (preview || available(q))) return q;
                if (q === 'default') return 'default';
            }
        } catch (e) {}
        try { v = localStorage.getItem(KEY); } catch (e) { v = null; }
        if (!v || v === 'default') return 'default';
        if (!BY_ID[v]) return 'default';
        /* 节日主题过期了 → 回到默认 */
        if (!available(v)) return 'default';
        return v;
    }

    /* ---------- 应用到 <html> ---------- */
    function apply(choice) {
        var el = document.documentElement;
        /* ?preview=1 时跳过日期窗口限制（调样式用） */
        var _pv = false;
        try {
            _pv = /[?&]preview=1/i.test(location.search);
            if (/[?&]dark=1/i.test(location.search)) document.documentElement.classList.add('dark');
        } catch (e) {}
        /* 用户没选过 → 一律用「默认」。
           节日主题只是「那几天在选项里出现」，不会自动套上。 */
        var real = 'default';
        if (choice && choice !== 'default' && BY_ID[choice] && (_pv || available(choice))) {
            real = choice;
        }
        /* 先记下当前是不是深色模式，再摘掉 dark 类。
           摘掉是因为它的选择器权重（html.dark body）会压住主题底色；
           但深色这个状态本身要留下来 —— 浅色主题（墨韵、护眼）靠它
           切到自己的深色变体（themes.css 里的 html[theme=x][data-dark]）。 */
        var wasDark = el.classList.contains('dark') ||
            (window.matchMedia &&
             window.matchMedia('(prefers-color-scheme: dark)').matches);

        if (real === 'default') {
            el.removeAttribute(ATTR);
        } else {
            el.setAttribute(ATTR, real);
            /* ⚠️ 以前这里会 remove('dark')：结果用户刚开的夜间模式
               一刷新就被主题引擎关掉，灯笼也不会亮。
               现在保留 dark 类，暗色交给各主题自己的 .dark / [data-dark] 规则。 */
        }
        if (wasDark) el.setAttribute('data-dark', '1');
        else el.removeAttribute('data-dark');
        el.setAttribute('data-theme-resolved', real);
    }

    /* 系统深色偏好变化时也跟着更新 data-dark，
       这样用户改系统设置不用刷新页面 */
    try {
        var mq = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)');
        if (mq && mq.addEventListener) {
            mq.addEventListener('change', function () { apply(readChoice()); });
        }
    } catch (e) {}


    /* ---------- 春节主题的动态装饰（对联 + 烟花）----------
       只在主题真正生效时加载 js/spring-fx.js，别的主题零开销。 */
    var SELF = document.currentScript;
    function fxBase() {
        try {
            if (SELF && SELF.src) return SELF.src.replace(/theme\.js.*$/, '');
        } catch (e) {}
        return (/\/Beta\//.test(location.pathname) ? '../js/' : 'js/');
    }
    function loadFx() {
        if (window.__nbSpringFxLoaded) return;
        window.__nbSpringFxLoaded = true;
        try {
            var el = document.createElement('script');
            el.src = fxBase() + 'spring-fx.js?v=6';
            el.defer = true;
            document.head.appendChild(el);
        } catch (e) {}
    }
    function unloadFx() {
        try {
            document.querySelectorAll('.spring-couplets').forEach(function (n) { n.remove(); });
            var cv = document.querySelector('.spring-fireworks');
            if (cv) cv.remove();
            document.querySelectorAll('.spring-wrap').forEach(function (w) {
                var v = w.querySelector('video, .hero-video');
                if (v) w.parentNode.insertBefore(v, w);
                w.remove();
            });
        } catch (e) {}
    }
    function syncFx() {
        if (document.documentElement.getAttribute('theme') === 'spring') loadFx();
        else unloadFx();
    }


    /* 站点自己的夜间按钮只切 html.dark，不会重跑 apply()，
       这里盯一下 class，把状态同步到 data-dark（春节的暗色规则靠它） */
    try {
        new MutationObserver(function () {
            var el = document.documentElement;
            var dark = el.classList.contains('dark');
            if (dark) el.setAttribute('data-dark', '1');
            else el.removeAttribute('data-dark');
        }).observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
    } catch (e) {}

    /* ---------- 对外接口 ---------- */
    var API = {
        KEY: KEY,
        get: readChoice,
        resolved: readChoice,
        set: function (choice) {
            var real = (choice && BY_ID[choice] && available(choice)) ? choice : 'default';
            try { localStorage.setItem(KEY, real); } catch (e) {}
            apply(real);
            syncFx();
            try {
                window.dispatchEvent(new CustomEvent('nb-theme-change', {
                    detail: { theme: real }
                }));
            } catch (e) {}
        },
        /* 兼容旧调用 */
        nationalAvailable: function (now) { return available('national', now); },
        available: available,
        /* 可选主题列表（只列此刻能选的） */
        list: function (now) {
            return THEMES.filter(function (t) { return available(t.id, now); })
                         .map(function (t) {
                             return { id: t.id, name: t.name, icon: t.icon, desc: t.desc };
                         });
        },
        /* 全部主题（含此刻不可选的），调试用 */
        all: function () {
            return THEMES.map(function (t) {
                return { id: t.id, name: t.name, icon: t.icon, desc: t.desc,
                         on: available(t.id) };
            });
        }
    };

    apply(readChoice());
    syncFx();
    window.NBTheme = API;
})();
