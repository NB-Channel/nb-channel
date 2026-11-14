/* ============================================================
   🧧 春节主题 · 动态装饰（只在 theme="spring" 时加载）
   ------------------------------------------------------------
   做两件事：
     1. 首页 hero 里，把右侧 LOGO 视频用一副对联框起来
     2. hero 背景加缓慢绽放的烟花（canvas，纯前端）
   没有图片资源，全部代码生成；prefers-reduced-motion 时自动关闭烟花。
   ============================================================ */
(function () {
    'use strict';

    var THEME = 'spring';
    if (document.documentElement.getAttribute('theme') !== THEME) return;

    /* 对联文字：想改就改这里 */
    var COUPLET = {
        left:  '爱理科 爱作死',
        right: '过新年 过好年',
        top:   'NB 新春'
    };

    /* ---------- ① 对联框住 LOGO 视频 ---------- */
    function wrapVideo() {
        var video = document.querySelector('.hero-video') ||
                    document.querySelector('.vhero-video') ||
                    document.querySelector('.hero video');
        if (!video || video.parentNode.classList.contains('spring-wrap')) return;

        var wrap = document.createElement('div');
        wrap.className = 'spring-wrap';
        video.parentNode.insertBefore(wrap, video);
        wrap.appendChild(video);

        function scroll(side, text) {
            var d = document.createElement('div');
            d.className = 'spring-couplet ' + side;
            d.textContent = text;
            wrap.appendChild(d);
        }
        /* 上联在右、下联在左（传统贴法） */
        scroll('right', COUPLET.left);
        scroll('left', COUPLET.right);

        var top = document.createElement('div');
        top.className = 'spring-couplet top';
        top.textContent = COUPLET.top;
        wrap.appendChild(top);
    }

    /* ---------- ② 烟花 ---------- */
    function fireworks() {
        var hero = document.querySelector('.hero') || document.querySelector('.vhero');
        if (!hero) return;
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        var cv = document.createElement('canvas');
        cv.className = 'spring-fireworks';
        hero.insertBefore(cv, hero.firstChild);

        var ctx = cv.getContext('2d');
        var W = 0, H = 0, DPR = Math.min(window.devicePixelRatio || 1, 2);
        var parts = [];
        var last = 0;
        var COLORS = ['#ffd166', '#ff8a5c', '#fff3d6', '#ff5e6c', '#ffb347'];

        function resize() {
            var r = hero.getBoundingClientRect();
            W = r.width; H = r.height;
            cv.width = W * DPR; cv.height = H * DPR;
            cv.style.width = W + 'px'; cv.style.height = H + 'px';
            ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
        }
        resize();
        window.addEventListener('resize', resize);

        function burst(x, y) {
            var n = 46 + Math.floor(Math.random() * 26);
            var c1 = COLORS[Math.floor(Math.random() * COLORS.length)];
            var c2 = COLORS[Math.floor(Math.random() * COLORS.length)];
            for (var i = 0; i < n; i++) {
                var a = (Math.PI * 2 * i) / n + Math.random() * 0.12;
                var sp = 1.6 + Math.random() * 2.8;
                parts.push({
                    x: x, y: y,
                    vx: Math.cos(a) * sp,
                    vy: Math.sin(a) * sp,
                    life: 52 + Math.random() * 34,
                    age: 0,
                    c: Math.random() < 0.5 ? c1 : c2,
                    r: 1.1 + Math.random() * 1.2
                });
            }
        }

        var running = true;
        document.addEventListener('visibilitychange', function () {
            running = !document.hidden;
        });

        function frame(t) {
            requestAnimationFrame(frame);
            if (!running) return;
            if (W === 0 || H === 0) return;

            /* 每 2.6~5 秒放一朵 */
            if (!last || t - last > 2600 + Math.random() * 2400) {
                last = t;
                burst(W * (0.15 + Math.random() * 0.7), H * (0.08 + Math.random() * 0.3));
            }

            ctx.clearRect(0, 0, W, H);
            ctx.globalCompositeOperation = 'lighter';

            for (var i = parts.length - 1; i >= 0; i--) {
                var p = parts[i];
                p.age++;
                p.x += p.vx;
                p.y += p.vy;
                p.vy += 0.028;
                p.vx *= 0.992;
                var k = 1 - p.age / p.life;
                if (k <= 0) { parts.splice(i, 1); continue; }
                ctx.globalAlpha = Math.max(0, k * 0.85);
                ctx.fillStyle = p.c;
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r * (0.4 + k * 0.8), 0, Math.PI * 2);
                ctx.fill();
            }
            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = 'source-over';
        }
        requestAnimationFrame(frame);
    }

    function boot() {
        try { wrapVideo(); } catch (e) {}
        try { fireworks(); } catch (e) {}
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
    /* 视频可能是后渲染的，补一次 */
    setTimeout(boot, 800);
})();
