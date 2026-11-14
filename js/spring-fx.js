/* ============================================================
   🧧 春节主题 · 动态 + 可互动装饰（只在 theme="spring" 时加载）
   ------------------------------------------------------------
   可互动：
     1. 点 hero 任意空白处 → 那里放一朵烟花
     2. 点灯笼 → 灯笼晃一下 + 它旁边炸一朵
     3. 点「福」字 → 翻正/翻倒 + 飘几个红包下来
   自动的：
     4. 对联贴在屏幕两侧，灯笼轻轻摆
     5. 烟花自己隔几秒放一朵（滚出屏幕就停）
   ============================================================ */
(function () {
    'use strict';

    if (document.documentElement.getAttribute('theme') !== 'spring') return;

    var COUPLET = {
        right: '烧杯试管辞旧岁',
        left:  '股市银行贺新春',
        top:   'NB 大吉'
    };

    /* ==================== 烟花引擎 ==================== */
    var FW = (function () {
        var hero = document.querySelector('.hero') || document.querySelector('.vhero');
        if (!hero) return null;
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return null;

        var cv = document.createElement('canvas');
        cv.className = 'spring-fireworks';
        hero.insertBefore(cv, hero.firstChild);

        var ctx = cv.getContext('2d', { alpha: true, desynchronized: true });
        var W = 0, H = 0;
        var rockets = [], sparks = [];
        var nextAt = 0, visible = true, running = true, last = 0, slow = 0;
        var COLORS = ['#ffd166', '#ffb347', '#fff0c2', '#ff6b5e'];

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
            cv.width = Math.floor(W); cv.height = Math.floor(H);
            cv.style.width = W + 'px'; cv.style.height = H + 'px';
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

        function burst(x, y, c, n) {
            n = n || (34 + ((Math.random() * 14) | 0));
            c = c || COLORS[(Math.random() * COLORS.length) | 0];
            for (var i = 0; i < n; i++) {
                var a = (Math.PI * 2 * i) / n + Math.random() * 0.06;
                var sp = 1.5 + Math.random() * 2.2;
                sparks.push({
                    x: x, y: y,
                    vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
                    life: 62 + ((Math.random() * 34) | 0), age: 0,
                    c: (i % 6 === 0) ? '#fff3c4' : c,
                    r: 2.0 + Math.random() * 1.4
                });
            }
            if (sparks.length > 320) sparks.splice(0, sparks.length - 320);
        }

        function launch(x) {
            rockets.push({
                x: (x == null) ? W * (0.18 + Math.random() * 0.64) : x,
                y: H * 0.92,
                vx: (Math.random() - 0.5) * 0.4,
                vy: -(5.4 + Math.random() * 1.0),
                targetY: H * (0.18 + Math.random() * 0.22),
                c: COLORS[(Math.random() * COLORS.length) | 0]
            });
        }

        function frame(t) {
            requestAnimationFrame(frame);
            if (!visible || !running || !W || !H) { last = 0; return; }

            if (last) {
                var dt = t - last;
                if (dt > 26) slow++; else slow = Math.max(0, slow - 1);
            }
            last = t;
            if (slow >= 2) { slow = 0; return; }

            if (!nextAt) nextAt = t + 900;
            if (t > nextAt && rockets.length === 0) {
                launch();
                nextAt = t + 2600 + Math.random() * 2400;
            }

            ctx.globalCompositeOperation = 'destination-out';
            ctx.fillStyle = 'rgba(0,0,0,.35)';
            ctx.fillRect(0, 0, W, H);
            ctx.globalCompositeOperation = 'lighter';

            for (var i = rockets.length - 1; i >= 0; i--) {
                var r = rockets[i], px = r.x, py = r.y;
                r.x += r.vx; r.y += r.vy; r.vy += 0.032;

                ctx.strokeStyle = r.c; ctx.lineWidth = 2.4;
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(r.x, r.y); ctx.stroke();
                ctx.globalAlpha = 0.9;
                ctx.drawImage(sprite('#fff6dc'), r.x - 4, r.y - 4, 8, 8);
                ctx.globalAlpha = 1;

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
                var sp = sprite(p.c), sz = p.r * (1 + f * 1.6);
                ctx.globalAlpha = Math.max(0.05, f);
                ctx.drawImage(sp, p.x - sz, p.y - sz, sz * 2, sz * 2);
            }

            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = 'source-over';
        }
        requestAnimationFrame(frame);

        /* 对外：在页面坐标 (clientX, clientY) 处炸一朵 */
        function burstAtClient(clientX, clientY) {
            var r = hero.getBoundingClientRect();
            var x = clientX - r.left, y = clientY - r.top;
            if (x < 0 || y < 0 || x > W || y > H) return;
            burst(x, y, null, 46);
        }

        return { burstAtClient: burstAtClient, launch: launch, hero: hero };
    })();

    /* ==================== 对联 + 灯笼 + 倒福 ==================== */
    function addCouplets() {
        if (document.querySelector('.spring-couplets')) return;
        if (!document.querySelector('.hero')) return;

        var box = document.createElement('div');
        box.className = 'spring-couplets';

        function side(side, text) {
            var d = document.createElement('div');
            d.className = 'spring-strip ' + side;

            var l = document.createElement('div');
            l.className = 'spring-lantern';
            l.title = '点我放烟花';
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

        document.body.appendChild(box);

        /* 点灯笼 → 晃一下 + 旁边炸一朵 */
        box.querySelectorAll('.spring-lantern').forEach(function (l) {
            l.addEventListener('click', function (e) {
                e.stopPropagation();
                l.classList.remove('pop');
                void l.offsetWidth;
                l.classList.add('pop');
                if (FW) {
                    var r = l.getBoundingClientRect();
                    FW.burstAtClient(r.left + r.width / 2, r.top + r.height / 2);
                    FW.burstAtClient(r.left + r.width / 2, r.top + r.height * 1.6);
                }
            });
        });
    }

    function addHeroDeco() {
        var hero = document.querySelector('.hero');
        if (!hero || hero.querySelector('.spring-fu')) return;

        var fu = document.createElement('div');
        fu.className = 'spring-fu';
        fu.textContent = '福';
        fu.title = '点我：福到';
        hero.appendChild(fu);

        /* 点福 → 正倒翻转 + 飘红包 */
        fu.addEventListener('click', function (e) {
            e.stopPropagation();
            fu.classList.toggle('up');
            if (FW) {
                var r = fu.getBoundingClientRect();
                FW.burstAtClient(r.left + r.width / 2, r.top + r.height / 2);
            }
            dropRedPackets(fu);
        });

        var trim = document.createElement('div');
        trim.className = 'spring-trim';
        hero.insertBefore(trim, hero.firstChild);

        /* 点 hero 空白 → 就地点一朵（点在视频/文字上不算） */
        if (FW) {
            hero.addEventListener('click', function (e) {
                if (e.target.closest('a, button, video, .hero-video, .spring-fu, .spring-lantern')) return;
                FW.burstAtClient(e.clientX, e.clientY);
            });
        }
    }

    /* 红包雨：从福字位置掉几枚，自己消失 */
    function dropRedPackets(anchor) {
        var r = anchor.getBoundingClientRect();
        for (var i = 0; i < 7; i++) {
            (function (i) {
                var el = document.createElement('div');
                el.className = 'spring-packet';
                el.textContent = '🧧';
                el.style.left = (r.left + r.width / 2 + (Math.random() - 0.5) * 120) + 'px';
                el.style.top = (r.top + 10) + 'px';
                el.style.animationDelay = (i * 90) + 'ms';
                document.body.appendChild(el);
                setTimeout(function () { el.remove(); }, 2200 + i * 90);
            })(i);
        }
    }

    function boot() {
        try { addCouplets(); } catch (e) {}
        try { addHeroDeco(); } catch (e) {}
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
    setTimeout(boot, 900);
})();
