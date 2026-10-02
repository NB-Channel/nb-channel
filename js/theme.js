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

    /* ---------- 节日正日子（公历）----------
       农历节日每年换算出来的公历日期不一样，这里列最近几年。
       表里没有的年份 → 该节日不出现（宁可不显示，也不要显示错）。 */
    var FESTIVAL = {
        spring: {                    // 春节（正月初一）
            2027: [2, 6],
            2028: [1, 26],
            2029: [2, 13],
            2030: [2, 3]
        },
        midautumn: {                 // 中秋（八月十五）
            2026: [9, 25],
            2027: [9, 15],
            2028: [10, 3],
            2029: [9, 22]
        }
    };

    /* 每个节日提前 / 延后几天出现 */
    var SPAN = { spring: 10, midautumn: 5 };

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
        { id: 'spring',    name: '春节',      icon: '\uD83E\uDDE8',
          desc: '正红剪纸 + 灯笼，过年前后出现',
          festival: 'spring' },
        { id: 'midautumn', name: '中秋',      icon: '\uD83E\uDD5E',
          desc: '月白桂黄 + 玉兔，中秋前后出现',
          festival: 'midautumn' }
    ];

    var BY_ID = {};
    THEMES.forEach(function (t) { BY_ID[t.id] = t; });

    /* ---------- 日期判定 ---------- */
    function sameDay(d, m, day) {
        return (d.getMonth() + 1) === m && d.getDate() === day;
    }
    /* 以 (m, day) 为中心，前后各 span 天，看 now 在不在里头 */
    function inSpan(now, m, day, span) {
        var center = new Date(now.getFullYear(), m - 1, day);
        center.setHours(0, 0, 0, 0);
        var t = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var diff = Math.round((t - center) / 86400000);
        return Math.abs(diff) <= span;
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
            var table = FESTIVAL[t.festival] || {};
            var md = table[d.getFullYear()];
            if (!md) return false;                       // 这一年没登记
            return inSpan(d, md[0], md[1], SPAN[t.festival] || 3);
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
            /* 调试用：?theme=midautumn&preview=1
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
        /* 用户没选过 → 一律用「默认」。
           节日主题只是「那几天在选项里出现」，不会自动套上。 */
        var real = 'default';
        if (choice && choice !== 'default' && BY_ID[choice] && available(choice)) {
            real = choice;
        }
        if (real === 'default') {
            el.removeAttribute(ATTR);
        } else {
            el.setAttribute(ATTR, real);
            /* 页面上原本用 html.dark 表示深色模式，它的选择器权重
               （html.dark body）比我们的（html[theme=x] body）高一级，
               会把主题的底色压住。所以切到任何非默认主题时把 dark 摘掉，
               由主题自己决定深浅。 */
            el.classList.remove('dark');
        }
        el.setAttribute('data-theme-resolved', real);
    }

    /* ---------- 对外接口 ---------- */
    var API = {
        KEY: KEY,
        get: readChoice,
        resolved: readChoice,
        set: function (choice) {
            var real = (choice && BY_ID[choice] && available(choice)) ? choice : 'default';
            try { localStorage.setItem(KEY, real); } catch (e) {}
            apply(real);
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
    window.NBTheme = API;
})();
