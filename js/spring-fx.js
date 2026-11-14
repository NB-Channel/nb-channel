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

    /* ---------- ② 烟花（贴图 + 拖影，尽量省） ---------- */
    function fireworks() {
        var hero = document.querySelector('.hero') || document.querySelector('.vhero');
        if (!hero) return;
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        var cv = document.createElement('canvas');
        cv.className = 'spring-fireworks';
        hero.insertBefore(cv, hero.firstChild);

        var ctx = cv.getContext('2d', { alpha: true, desynchronized: true });
        var W = 0, H = 0;
        var rockets = [], sparks = [];
        var nextAt = 0, visible = true, running = true;
        var slowFrames = 0;

        var COLORS = ['#ffd166', '#ffb347', '#fff0c2', '#ff6b5e'];

        /* 预渲染光点贴图：每帧只 drawImage，不再逐颗 arc+fill */
        var SPRITES = {};
        function sprite(color) {
            if (SPRITES[color]) return SPRITES[color];
            var S = 32, c = document.createElement('canvas');
            c.width = c.height = S;
            var g = c.getContext('2d');
            var rg = g.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
            rg.addColorStop(0, '#ffffff');
            rg.addColorStop(0.25, color);
            rg.addColorStop(0.65, color);
            rg.addColorStop(1, 'rgba(0,0,0,0)');
            g.fillStyle = rg;
            g.beginPath(); g.arc(S / 2, S / 2, S / 2, 0, 6.2832); g.fill();
            SPRITES[color] = c;
            return c;
        }
        COLORS.forEach(sprite);

        function resize() {
            var r = hero.getBoundingClientRect();
            W = r.width; H = r.height;
            cv.width = Math.floor(W);
            cv.height = Math.floor(H);
            cv.style.width = W + 'px';
            cv.style.height = H + 'px';
        }
        resize();
        window.addEventListener('resize', resize, { passive: true });

        if ('IntersectionObserver' in window) {
            new IntersectionObserver(function (es) { visible = es[0].isIntersecting; },
                                     { threshold: 0 }).observe(hero);
        }
        document.addEventListener('visibilitychange', function () {
            running = !document.hidden;
        }, { passive: true });

        function launch() {
            rockets.push({
                x: W * (0.18 + Math.random() * 0.64),
                y: H * 0.92,
                vx: (Math.random() - 0.5) * 0.5,
                vy: -(5.4 + Math.random() * 1.0),
                targetY: H * (0.18 + Math.random() * 0.22),
                c: COLORS[(Math.random() * COLORS.length) | 0]
            });
        }

        function burst(x, y, c) {
            var n = 34 + ((Math.random() * 14) | 0);
            for (var i = 0; i < n; i++) {
                var a = (Math.PI * 2 * i) / n + Math.random() * 0.06;
                var sp = 1.5 + Math.random() * 2.1;
                sparks.push({
                    x: x, y: y,
                    vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
                    life: 62 + ((Math.random() * 34) | 0), age: 0,
                    c: (i % 6 === 0) ? '#fff3c4' : c,
                    r: 2.2 + Math.random() * 1.6
                });
            }
            if (sparks.length > 220) sparks.splice(0, sparks.length - 220);
        }

        var last = 0;
        function frame(t) {
            requestAnimationFrame(frame);
            if (!visible || !running || !W || !H) { last = 0; return; }

            /* 自适应：连续两帧超过 26ms 就停一拍，保住流畅 */
            if (last) {
                var dt = t - last;
                if (dt > 26) slowFrames++; else slowFrames = Math.max(0, slowFrames - 1);
            }
            last = t;
            if (slowFrames >= 2) { slowFrames = 0; return; }

            if (!nextAt) nextAt = t + 700;
            if (t > nextAt && rockets.length === 0) {
                launch();
                nextAt = t + 2400 + Math.random() * 2400;
            }

            /* 用「擦掉一点」代替 clearRect：顺手得到拖影 */
            ctx.globalCompositeOperation = 'destination-out';
            ctx.fillStyle = 'rgba(0,0,0,.35)';
            ctx.fillRect(0, 0, W, H);
            ctx.globalCompositeOperation = 'lighter';

            for (var i = rockets.length - 1; i >= 0; i--) {
                var r = rockets[i], px = r.x, py = r.y;
                r.x += r.vx; r.y += r.vy; r.vy += 0.032;

                ctx.strokeStyle = r.c;
                ctx.lineWidth = 2.4;
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(r.x, r.y); ctx.stroke();

                var s1 = sprite('#fff6dc');
                ctx.drawImage(s1, r.x - 4, r.y - 4, 8, 8);

                if (r.y <= r.targetY || r.vy >= -0.35) {
                    burst(r.x, r.y, r.c);
                    rockets.splice(i, 1);
                }
            }

            for (var k = sparks.length - 1; k >= 0; k--) {
                var p = sparks[k];
                p.age++;
                p.x += p.vx; p.y += p.vy;
                p.vy += 0.032;
                p.vx *= 0.9915; p.vy *= 0.9915;
                var f = 1 - p.age / p.life;
                if (f <= 0) { sparks.splice(k, 1); continue; }

                var sp = sprite(p.c);
                var sz = p.r * (1 + f * 1.6);
                ctx.globalAlpha = Math.max(0.05, f);
                ctx.drawImage(sp, p.x - sz, p.y - sz, sz * 2, sz * 2);
            }

            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = 'source-over';
        }
        requestAnimationFrame(frame);
    }


    /* ---------- ③ 首页专属小装饰：倒福 + 上沿剪纸 ---------- */
    function addHeroDeco() {
        var hero = document.querySelector('.hero');
        if (!hero || hero.querySelector('.spring-fu')) return;

        var fu = document.createElement('div');
        fu.className = 'spring-fu';
        fu.textContent = '福';
        hero.appendChild(fu);

        var trim = document.createElement('div');
        trim.className = 'spring-trim';
        hero.insertBefore(trim, hero.firstChild);
    }

    function boot() {
        try { addCouplets(); } catch (e) {}
        try { addHeroDeco(); } catch (e) {}
        try { fireworks(); } catch (e) {}
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
    setTimeout(boot, 900);
})();
