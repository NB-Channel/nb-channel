/* ============================================================
   🧧 春节主题 · 动态装饰（只在 theme="spring" 时加载）
   ------------------------------------------------------------
   1. 页面左右两副对联（各挂一只灯笼）
   2. hero 烟花：升空 → 炸开；性能优先（无 shadowBlur、限量、看不见就停）
   ============================================================ */
(function () {
    'use strict';

    if (document.documentElement.getAttribute('theme') !== 'spring') return;

    /* 想换对联文字，改这几行 */
    var COUPLET = {
        right: '烧杯试管辞旧岁',
        left:  '股市银行贺新春',
        top:   'NB 大吉'
    };

    /* ---------- ① 对联 + 灯笼 ---------- */
    function addCouplets() {
        if (document.querySelector('.spring-couplets')) return;
        if (!document.querySelector('.hero')) return;      /* 只在首页挂 */

        var box = document.createElement('div');
        box.className = 'spring-couplets';

        function side(side, text) {
            var d = document.createElement('div');
            d.className = 'spring-strip ' + side;

            var l = document.createElement('div');
            l.className = 'spring-lantern';
            l.innerHTML = '<i class="cord"></i><i class="cap top"></i>' +
                          '<i class="body"></i><i class="cap bottom"></i>' +
                          '<i class="tassel"></i>';
            d.appendChild(l);

            var t = document.createElement('span');
            t.className = 'txt';
            t.textContent = text;
            d.appendChild(t);
            box.appendChild(d);
        }
        side('right', COUPLET.right);
        side('left', COUPLET.left);

        var top = document.createElement('div');
        top.className = 'spring-banner';
        top.textContent = COUPLET.top;
        box.appendChild(top);

        document.body.appendChild(box);   /* 挂 body：hero 有 transform，fixed 会失效 */
    }

    /* ---------- ② 烟花（省性能版） ---------- */
    function fireworks() {
        var hero = document.querySelector('.hero') || document.querySelector('.vhero');
        if (!hero) return;
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        var cv = document.createElement('canvas');
        cv.className = 'spring-fireworks';
        hero.insertBefore(cv, hero.firstChild);

        var ctx = cv.getContext('2d', { alpha: true });
        var W = 0, H = 0, DPR = 1;
        var rockets = [], sparks = [];
        var nextAt = 0;
        var visible = true;
        var running = true;

        var COLORS = ['#ffd166', '#ffb347', '#fff0c2', '#ff6b5e'];

        function resize() {
            var r = hero.getBoundingClientRect();
            W = r.width; H = r.height;
            cv.width = Math.floor(W * DPR);
            cv.height = Math.floor(H * DPR);
            cv.style.width = W + 'px';
            cv.style.height = H + 'px';
            ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
        }
        resize();
        window.addEventListener('resize', resize, { passive: true });

        /* 看不见就停：省电、省 GPU */
        if ('IntersectionObserver' in window) {
            new IntersectionObserver(function (es) {
                visible = es[0].isIntersecting;
            }, { threshold: 0 }).observe(hero);
        }
        document.addEventListener('visibilitychange', function () {
            running = !document.hidden;
        }, { passive: true });

        function launch() {
            rockets.push({
                x: W * (0.18 + Math.random() * 0.64),
                y: H * 0.92,
                vx: (Math.random() - 0.5) * 0.6,
                vy: -(7.2 + Math.random() * 1.2),
                targetY: H * (0.18 + Math.random() * 0.22),
                c: COLORS[(Math.random() * COLORS.length) | 0]
            });
        }

        function burst(x, y, c) {
            var n = 46 + ((Math.random() * 22) | 0);
            for (var i = 0; i < n; i++) {
                var a = (Math.PI * 2 * i) / n + Math.random() * 0.08;
                var sp = 2.2 + Math.random() * 3.4;
                sparks.push({
                    x: x, y: y,
                    vx: Math.cos(a) * sp,
                    vy: Math.sin(a) * sp,
                    life: 46 + ((Math.random() * 26) | 0),
                    age: 0,
                    c: (i % 5 === 0) ? '#fff3c4' : c,
                    r: 1.6 + Math.random() * 1.4
                });
            }
            if (sparks.length > 520) sparks.splice(0, sparks.length - 520);
        }

        function frame(t) {
            requestAnimationFrame(frame);
            if (!visible || !running || !W || !H) return;

            if (!nextAt) nextAt = t + 600;
            if (t > nextAt && rockets.length === 0) {
                launch();
                nextAt = t + 2200 + Math.random() * 2200;
            }

            ctx.clearRect(0, 0, W, H);
            ctx.globalCompositeOperation = 'lighter';

            for (var i = rockets.length - 1; i >= 0; i--) {
                var r = rockets[i];
                var px = r.x, py = r.y;
                r.x += r.vx; r.y += r.vy; r.vy += 0.05;

                ctx.globalAlpha = 1;
                ctx.strokeStyle = r.c;
                ctx.lineWidth = 2.5;
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(r.x, r.y); ctx.stroke();

                ctx.globalAlpha = 0.9;
                ctx.fillStyle = '#fff6dc';
                ctx.beginPath(); ctx.arc(r.x, r.y + 3, 2.2, 0, 6.2832); ctx.fill();

                if (r.y <= r.targetY || r.vy >= -0.6) {
                    burst(r.x, r.y, r.c);
                    rockets.splice(i, 1);
                }
            }

            for (var k = sparks.length - 1; k >= 0; k--) {
                var p = sparks[k];
                p.age++;
                p.x += p.vx; p.y += p.vy;
                p.vy += 0.05;
                p.vx *= 0.985; p.vy *= 0.985;
                var f = 1 - p.age / p.life;
                if (f <= 0) { sparks.splice(k, 1); continue; }

                ctx.globalAlpha = f;
                ctx.fillStyle = p.c;
                ctx.beginPath(); ctx.arc(p.x, p.y, p.r * (0.5 + f), 0, 6.2832); ctx.fill();
            }

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
