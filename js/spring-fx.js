/* ============================================================
   🧧 春节主题 · 动态装饰（只在 theme="spring" 时加载）
   ------------------------------------------------------------
   1. 首页 hero 两侧贴一副传统对联（七言），顶部横批
   2. hero 上放烟花：先升空拖尾，到顶再炸开
   没有图片资源，全部代码生成；prefers-reduced-motion 时不放烟花。
   ============================================================ */
(function () {
    'use strict';

    if (document.documentElement.getAttribute('theme') !== 'spring') return;

    /* 想换对联文字，改这三行 */
    var COUPLET = {
        right: '天增岁月人增寿',
        left:  '春满乾坤福满门',
        top:   '新春大吉'
    };

    /* ---------- ① 对联 ---------- */
    function addCouplets() {
        var hero = document.querySelector('.hero');
        if (!hero || hero.querySelector('.spring-couplets')) return;

        var box = document.createElement('div');
        box.className = 'spring-couplets';

        function strip(side, text) {
            var d = document.createElement('div');
            d.className = 'spring-strip ' + side;
            d.textContent = text;
            box.appendChild(d);
        }
        strip('right', COUPLET.right);
        strip('left', COUPLET.left);

        var top = document.createElement('div');
        top.className = 'spring-banner';
        top.textContent = COUPLET.top;
        box.appendChild(top);

        document.body.appendChild(box);   /* 挂 body：hero 上的 transform 会让 fixed 失效 */
    }

    /* ---------- ② 烟花：升空 → 炸开 ---------- */
    function fireworks() {
        var hero = document.querySelector('.hero') || document.querySelector('.vhero');
        if (!hero) return;
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        var cv = document.createElement('canvas');
        cv.className = 'spring-fireworks';
        hero.insertBefore(cv, hero.firstChild);

        var ctx = cv.getContext('2d');
        var W = 0, H = 0, DPR = Math.min(window.devicePixelRatio || 1, 2);
        var rockets = [];
        var sparks = [];
        var nextAt = 0;
        var running = true;

        var COLORS = ['#ffd166', '#ffb347', '#fff0c2', '#ff6b5e', '#ffe08a'];

        function resize() {
            var r = hero.getBoundingClientRect();
            W = r.width; H = r.height;
            cv.width = W * DPR; cv.height = H * DPR;
            cv.style.width = W + 'px'; cv.style.height = H + 'px';
            ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
        }
        resize();
        window.addEventListener('resize', resize);
        document.addEventListener('visibilitychange', function () { running = !document.hidden; });

        function launch() {
            var x = W * (0.12 + Math.random() * 0.76);
            rockets.push({
                x: x,
                y: H * 0.92,
                vy: -(6.2 + Math.random() * 1.6),
                vx: (Math.random() - 0.5) * 0.9,
                targetY: H * (0.16 + Math.random() * 0.26),
                color: COLORS[Math.floor(Math.random() * COLORS.length)]
            });
        }

        function burst(x, y, color) {
            var n = 90 + Math.floor(Math.random() * 50);
            var accent = COLORS[Math.floor(Math.random() * COLORS.length)];
            for (var i = 0; i < n; i++) {
                var a = (Math.PI * 2 * i) / n + Math.random() * 0.1;
                var sp = 2.0 + Math.random() * 4.2;
                sparks.push({
                    x: x, y: y,
                    vx: Math.cos(a) * sp,
                    vy: Math.sin(a) * sp,
                    life: 60 + Math.random() * 45,
                    age: 0,
                    c: (i % 3 === 0) ? accent : color,
                    r: 1.4 + Math.random() * 1.6
                });
            }
        }

        function frame(t) {
            requestAnimationFrame(frame);
            if (!running || !W || !H) return;

            if (!nextAt) nextAt = t + 500;
            if (t > nextAt && rockets.length < 3) {
                launch();
                nextAt = t + 1400 + Math.random() * 1900;
            }

            ctx.clearRect(0, 0, W, H);
            ctx.globalCompositeOperation = 'lighter';

            /* 火箭：拖尾 + 上升 */
            for (var i = rockets.length - 1; i >= 0; i--) {
                var r = rockets[i];
                var px = r.x, py = r.y;
                r.x += r.vx;
                r.y += r.vy;
                r.vy += 0.055;                       /* 减速，到顶自然停 */

                ctx.globalAlpha = 1;
                ctx.strokeStyle = r.color;
                ctx.lineWidth = 3;
                ctx.shadowBlur = 12;
                ctx.shadowColor = r.color;
                ctx.beginPath();
                ctx.moveTo(px, py);
                ctx.lineTo(r.x, r.y);
                ctx.stroke();

                /* 尾焰 */
                ctx.globalAlpha = 0.85;
                ctx.fillStyle = '#fff6dc';
                ctx.beginPath();
                ctx.arc(r.x, r.y + 4, 2.4, 0, Math.PI * 2);
                ctx.fill();

                if (r.y <= r.targetY || r.vy >= -0.4) {
                    burst(r.x, r.y, r.color);
                    rockets.splice(i, 1);
                }
            }

            /* 火花 */
            for (var k = sparks.length - 1; k >= 0; k--) {
                var p = sparks[k];
                p.age++;
                p.x += p.vx;
                p.y += p.vy;
                p.vy += 0.045;
                p.vx *= 0.988;
                p.vy *= 0.988;
                var f = 1 - p.age / p.life;
                if (f <= 0) { sparks.splice(k, 1); continue; }

                ctx.shadowBlur = 10;
                ctx.shadowColor = p.c;
                ctx.globalAlpha = Math.max(0, f * 1.0);
                ctx.fillStyle = p.c;
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r * (0.5 + f * 0.9), 0, Math.PI * 2);
                ctx.fill();

                /* 亮芯 */
                ctx.globalAlpha = Math.max(0, f * 0.9);
                ctx.fillStyle = '#fffbe8';
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r * 0.42 * f, 0, Math.PI * 2);
                ctx.fill();
            }

            ctx.shadowBlur = 0;
            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = 'source-over';
        }
        requestAnimationFrame(frame);
    }

    function boot() {
        try { addCouplets(); } catch (e) {}
        try { fireworks(); } catch (e) {}
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
    setTimeout(boot, 900);
})();
