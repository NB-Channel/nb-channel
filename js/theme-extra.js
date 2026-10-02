/* ============================================================
   NB频道 · 主题专属内容
   ------------------------------------------------------------
   只在【首页】挂载（约定：主题独有内容不铺到别的页面）。
   按当前 <html theme="..."> 渲染对应模块：

     pixel      👾 贪吃蛇（键盘 / 触屏都能玩）
     cyber      🌃 故障艺术标题 + 扫描线
     ink        🖌️ 毛笔逐笔写字（第二批）
     midautumn  🥮 月相盈亏 + 玉兔（第二批）
     spring     🧨 点鞭炮（第三批）
     eyecare    🌙 作息提醒（第三批）

   切主题时通过 nb-theme-change 事件整体重挂。
   ============================================================ */
(function () {
    'use strict';

    var HOST_ID = 'nbExtra';
    var CSS_ID = 'nbExtraCss';

    /* ============================================================
       公共样式
       ============================================================ */
    var CSS = [
        /* 外层容器：和科技展示区一样，占 Hero 下方一整行 */
        '#nbExtra{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;}',
        '.nb-ex-head{display:flex;align-items:center;gap:10px;margin-bottom:12px;flex-wrap:wrap;}',
        '.nb-ex-head .sp{flex:1;min-width:0;font-size:.76rem;letter-spacing:1.2px;}',
        '.nb-ex-card{border-radius:12px;overflow:hidden;}',

        /* ---------- 👾 贪吃蛇 ---------- */
        '.nb-snk{display:grid;grid-template-columns:auto 200px;gap:22px;align-items:start;}',
        '.nb-snk canvas{display:block;border-radius:0;image-rendering:pixelated;background:#13141f;}',
        '.nb-snk-side{font-family:ui-monospace,Consolas,monospace;font-size:.78rem;line-height:1.9;}',
        '.nb-snk-side .k{color:#8b8fa3;}',
        '.nb-snk-side b{color:#ffec27;font-size:1.5rem;display:block;letter-spacing:1px;}',
        '.nb-snk-side .hi{color:#ff77a8;}',
        '.nb-snk-btns{display:flex;gap:8px;margin-top:14px;flex-wrap:wrap;}',
        '.nb-snk-spd{display:flex;gap:6px;margin-top:16px;flex-wrap:wrap;}',
        '.nb-snk-spd button{padding:6px 11px;border-radius:0;cursor:pointer;font-family:inherit;',
        '  font-size:.7rem;letter-spacing:1px;background:#24263a;color:#8b8fa3;',
        '  border:3px solid #3a3f5c;transition:none;}',
        '.nb-snk-spd button:hover{color:#ffec27;}',
        '.nb-snk-spd button.on{background:#29adff;border-color:#8bd4ff;color:#04121a;}',
        '.nb-snk-spd .lb{width:100%;color:#8b8fa3;font-size:.7rem;margin-bottom:2px;}',
        '.nb-snk-btn{padding:8px 14px;border-radius:0;cursor:pointer;font-family:inherit;',
        '  font-size:.74rem;letter-spacing:1px;background:#ff004d;color:#fff1e8;',
        '  border:3px solid #ff77a8;box-shadow:3px 3px 0 rgba(0,0,0,.5);transition:none;}',
        '.nb-snk-btn:hover{background:#ff77a8;}',
        '.nb-snk-btn.alt{background:#29adff;border-color:#8bd4ff;color:#04121a;}',
        '.nb-snk-pad{display:none;grid-template-columns:repeat(3,58px);gap:6px;margin-top:14px;}',
        '.nb-snk-pad button{width:58px;height:58px;font-size:1.2rem;border-radius:0;',
        '  background:#24263a;color:#ffec27;border:3px solid #3a3f5c;cursor:pointer;}',
        '.nb-snk-pad button:active{background:#ff004d;color:#fff1e8;}',
        '@media(max-width:820px){',
        '  .nb-snk{grid-template-columns:1fr;}',
        '  .nb-snk-pad{display:grid;}',
        '}',

        /* ---------- 🌃 故障艺术标题 ---------- */
        '.nb-glx{position:relative;padding:54px 34px;border-radius:12px;',
        '  background:linear-gradient(170deg,#180a2c,#0e0519 60%,#150826);',
        '  border:1px solid rgba(255,46,166,.28);',
        '  box-shadow:inset 0 0 40px -22px rgba(255,46,166,.8);overflow:hidden;}',
        '.nb-glx-t{position:relative;font-size:clamp(2rem,5.4vw,3.6rem);font-weight:800;',
        '  letter-spacing:4px;color:#fff2fc;line-height:1.25;text-align:center;margin:0;}',
        '.nb-glx-t::before,.nb-glx-t::after{content:attr(data-t);position:absolute;',
        '  left:0;right:0;top:0;pointer-events:none;}',
        '.nb-glx-t::before{color:#ff2ea6;animation:nbGlxA 3.1s steps(1,end) infinite;}',
        '.nb-glx-t::after {color:#00e5ff;animation:nbGlxB 2.7s steps(1,end) infinite;}',
        '@keyframes nbGlxA{',
        '  0%,88%,100%{transform:translate(0);opacity:0;}',
        '  90%{transform:translate(-4px,2px);opacity:.9;}',
        '  93%{transform:translate(3px,-2px);opacity:.75;}',
        '  96%{transform:translate(-2px,0);opacity:.85;}',
        '}',
        '@keyframes nbGlxB{',
        '  0%,84%,100%{transform:translate(0);opacity:0;}',
        '  86%{transform:translate(5px,-1px);opacity:.8;}',
        '  89%{transform:translate(-3px,2px);opacity:.7;}',
        '  94%{transform:translate(2px,1px);opacity:.75;}',
        '}',
        '.nb-glx-sub{margin:26px 0 0;text-align:center;font-size:.9rem;',
        '  letter-spacing:2px;color:rgba(214,186,232,.7);}',
        '.nb-glx-tags{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:26px;}',
        '.nb-glx-tag{padding:6px 14px;font-size:.72rem;letter-spacing:1.5px;',
        '  border:1px solid rgba(255,46,166,.4);color:#ff8ecb;border-radius:2px;}',
        '.nb-glx-scan{position:absolute;left:0;right:0;height:100px;pointer-events:none;',
        '  background:linear-gradient(to bottom,transparent,rgba(0,229,255,.1) 45%,',
        '  rgba(255,46,166,.16) 55%,transparent);',
        '  animation:nbGlxScan 6.5s linear infinite;}',
        '@keyframes nbGlxScan{0%{top:-110px;}100%{top:100%;}}',
        '.nb-glx-lines{position:absolute;inset:0;pointer-events:none;opacity:.5;',
        '  background:repeating-linear-gradient(0deg,rgba(255,255,255,.045) 0 1px,transparent 1px 3px);}',

        '@media(prefers-reduced-motion:reduce){',
        '  .nb-glx-t::before,.nb-glx-t::after,.nb-glx-scan{animation:none;opacity:0;}',
        '}'        ,

        /* ---------- 🥮 月相 + 玉兔 ---------- */
        '.nb-moon{display:grid;grid-template-columns:auto 1fr;gap:38px;align-items:center;',
        '  padding:40px 34px;border-radius:12px;',
        '  background:linear-gradient(170deg,#0b1329,#131f3d 55%,#1a2a4d);',
        '  border:1px solid rgba(255,231,150,.22);',
        '  box-shadow:inset 0 0 44px -24px rgba(255,231,150,.7);}',
        '.nb-moon-stage{position:relative;width:190px;height:190px;flex:0 0 auto;}',
        '.nb-moon svg{display:block;overflow:visible;}',
        '.nb-moon-info .name{font-size:1.5rem;font-weight:800;letter-spacing:3px;color:#faf5e4;}',
        '.nb-moon-info .pct{font-size:2.2rem;font-weight:800;color:#ffe796;letter-spacing:1px;',
        '  margin:8px 0 4px;font-variant-numeric:tabular-nums;}',
        '.nb-moon-info .sub{font-size:.82rem;letter-spacing:1px;color:rgba(232,226,200,.66);line-height:2;}',
        '.nb-moon-info .age{margin-top:16px;font-size:.78rem;color:rgba(232,226,200,.5);}',
        '@media(max-width:820px){.nb-moon{grid-template-columns:1fr;justify-items:center;text-align:center;}}',

        /* ---------- 🖌️ 毛笔写字 ---------- */
        '.nb-brush{position:relative;padding:46px 34px;border-radius:12px;',
        '  background:#faf7f0;border:1px solid rgba(28,26,23,.14);}',
        '.nb-brush-inner{display:grid;grid-template-columns:1fr auto;gap:34px;align-items:center;}',
        '.nb-brush svg{display:block;overflow:visible;}',
        '.nb-brush .stroke{fill:none;stroke:#1c1a17;stroke-width:11;stroke-linecap:round;',
        '  stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);}',
        '.nb-brush-go .stroke{animation:nbBrush 1.05s cubic-bezier(.5,.05,.35,1) forwards;}',
        '@keyframes nbBrush{to{stroke-dashoffset:0;}}',
        '.nb-brush-seal{width:96px;height:96px;flex:0 0 auto;opacity:0;transform:scale(1.5) rotate(-14deg);}',
        '.nb-brush-go .nb-brush-seal{animation:nbSeal .42s cubic-bezier(.2,1.6,.4,1) .95s forwards;}',
        '@keyframes nbSeal{to{opacity:1;transform:scale(1) rotate(-8deg);}}',
        '.nb-brush-side{text-align:right;}',
        '.nb-brush-side .t{font-size:1.05rem;font-weight:800;letter-spacing:4px;color:#1c1a17;}',
        '.nb-brush-side .d{margin-top:10px;font-size:.78rem;letter-spacing:1.5px;color:#6b6459;line-height:2;}',
        '.nb-brush-btns{margin-top:18px;display:flex;gap:8px;justify-content:flex-end;}',
        '.nb-brush-btn{padding:7px 14px;border-radius:2px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1.5px;background:#8c2f23;color:#faf7f0;border:none;}',
        '.nb-brush-btn:hover{background:#6d241a;}',
        '@media(max-width:820px){',
        '  .nb-brush-inner{grid-template-columns:1fr;}',
        '  .nb-brush-side{text-align:center;}',
        '  .nb-brush-btns{justify-content:center;}',
        '}',
        '@media(prefers-reduced-motion:reduce){',
        '  .nb-brush .stroke{stroke-dashoffset:0;animation:none;}',
        '  .nb-brush-seal{opacity:1;transform:scale(1) rotate(-8deg);animation:none;}',
        '}'
    ].join('\n');

    /* ============================================================
       👾 贪吃蛇
       ============================================================ */
    var SNAKE = {
        COLS: 22,
        ROWS: 18,
        CELL: 22,          /* 逻辑格子边长的 CSS 像素 */

        mount: function (box) {
            var self = this;
            var W = this.COLS * this.CELL;
            var H = this.ROWS * this.CELL;

            /* 难度：数值是一步多少毫秒，越大越慢 */
            var SPEEDS = {
                easy:   { ms: 200, name: '\u6162\u901F' },
                normal: { ms: 150, name: '\u666E\u901A' },
                fast:   { ms: 105, name: '\u5FEB\u901F' },
                insane: { ms: 70,  name: '\u75AF\u72C2' }
            };
            var SPD_KEY = 'nb_snake_speed';

            box.innerHTML =
                '<div class="nb-snk">' +
                  '<div><canvas width="' + W + '" height="' + H + '"></canvas>' +
                    '<div class="nb-snk-pad">' +
                      '<span></span><button data-d="U">\u25B2</button><span></span>' +
                      '<button data-d="L">\u25C0</button>' +
                      '<button data-d="D">\u25BC</button>' +
                      '<button data-d="R">\u25B6</button>' +
                    '</div>' +
                  '</div>' +
                  '<div class="nb-snk-side">' +
                    '<span class="k">\u5F97\u5206</span><b data-score>0</b>' +
                    '<span class="k">\u6700\u9AD8</span> <span class="hi" data-best>0</span><br>' +
                    '<span class="k">\u72B6\u6001</span> <span data-state>\u5F85\u5F00\u59CB</span>' +
                    '<div class="nb-snk-btns">' +
                      '<button class="nb-snk-btn" data-act="start">\u5F00\u59CB</button>' +
                      '<button class="nb-snk-btn alt" data-act="pause">\u6682\u505C</button>' +
                    '</div>' +
                    '<div class="nb-snk-spd" data-spd>' +
                      '<span class="lb">\u96BE\u5EA6</span>' +
                    '</div>' +
                    '<div style="margin-top:12px;color:#8b8fa3">' +
                      '\u65B9\u5411\u952E / WASD \u63A7\u5236<br>' +
                      '\u624B\u673A\u4E0A\u7528\u4E0B\u9762\u7684\u65B9\u5411\u952E'
                    + '</div>' +
                  '</div>' +
                '</div>';

            var cv = box.querySelector('canvas');
            var ctx = cv.getContext('2d');
            var scoreEl = box.querySelector('[data-score]');
            var bestEl = box.querySelector('[data-best]');
            var stateEl = box.querySelector('[data-state]');

            /* ---------- 难度 ---------- */
            var spdBar = box.querySelector('[data-spd]');
            var speed = 'easy';                 /* 默认慢速，站长说原来太快 */
            try {
                var sv = localStorage.getItem(SPD_KEY);
                if (sv && SPEEDS[sv]) speed = sv;
            } catch (e) {}

            Object.keys(SPEEDS).forEach(function (k) {
                var b = document.createElement('button');
                b.type = 'button';
                b.dataset.spd = k;
                b.textContent = SPEEDS[k].name;
                if (k === speed) b.classList.add('on');
                b.addEventListener('click', function () {
                    speed = k;
                    try { localStorage.setItem(SPD_KEY, k); } catch (e) {}
                    spdBar.querySelectorAll('button').forEach(function (x) {
                        x.classList.toggle('on', x.dataset.spd === k);
                    });
                    /* 正在跑就按新速度重开定时器，立即生效 */
                    if (running) {
                        if (timer) clearInterval(timer);
                        timer = setInterval(step, SPEEDS[speed].ms);
                    }
                });
                spdBar.appendChild(b);
            });

            var KEY = 'nb_snake_best';
            var best = 0;
            try { best = parseInt(localStorage.getItem(KEY) || '0', 10) || 0; } catch (e) {}
            bestEl.textContent = best;

            var snake, dir, nextDir, food, score, timer = null, running = false, over = false;

            function reset() {
                snake = [{ x: 5, y: 9 }, { x: 4, y: 9 }, { x: 3, y: 9 }];
                dir = { x: 1, y: 0 };
                nextDir = dir;
                score = 0;
                over = false;
                scoreEl.textContent = '0';
                dropFood();
            }
            function dropFood() {
                var free = [];
                for (var y = 0; y < self.ROWS; y++) {
                    for (var x = 0; x < self.COLS; x++) {
                        var hit = false;
                        for (var i = 0; i < snake.length; i++) {
                            if (snake[i].x === x && snake[i].y === y) { hit = true; break; }
                        }
                        if (!hit) free.push({ x: x, y: y });
                    }
                }
                food = free.length ? free[Math.floor(Math.random() * free.length)] : null;
            }
            function step() {
                if (!running || over) return;
                dir = nextDir;
                var head = { x: snake[0].x + dir.x, y: snake[0].y + dir.y };

                /* 撞墙或撞自己 */
                if (head.x < 0 || head.y < 0 || head.x >= self.COLS || head.y >= self.ROWS) return die();
                for (var i = 0; i < snake.length - 1; i++) {
                    if (snake[i].x === head.x && snake[i].y === head.y) return die();
                }

                snake.unshift(head);
                if (food && head.x === food.x && head.y === food.y) {
                    score += 10;
                    scoreEl.textContent = score;
                    if (score > best) {
                        best = score;
                        bestEl.textContent = best;
                        try { localStorage.setItem(KEY, String(best)); } catch (e) {}
                    }
                    dropFood();
                } else {
                    snake.pop();
                }
                draw();
            }
            function die() {
                over = true;
                running = false;
                stateEl.textContent = '\u7ED3\u675F\u4E86';
                if (timer) { clearInterval(timer); timer = null; }
                draw();
            }
            function draw() {
                /* 棋盘底 */
                ctx.fillStyle = '#13141f';
                ctx.fillRect(0, 0, W, H);
                ctx.fillStyle = '#181a28';
                for (var y = 0; y < self.ROWS; y++) {
                    for (var x = 0; x < self.COLS; x++) {
                        if ((x + y) % 2 === 0) {
                            ctx.fillRect(x * self.CELL, y * self.CELL, self.CELL, self.CELL);
                        }
                    }
                }
                /* 食物 */
                if (food) {
                    ctx.fillStyle = '#ff004d';
                    var p = 3;
                    ctx.fillRect(food.x * self.CELL + p, food.y * self.CELL + p,
                                 self.CELL - p * 2, self.CELL - p * 2);
                    ctx.fillStyle = '#ff77a8';
                    ctx.fillRect(food.x * self.CELL + p + 3, food.y * self.CELL + p + 3, 4, 4);
                }
                /* 蛇身 */
                for (var i = snake.length - 1; i >= 0; i--) {
                    var s = snake[i];
                    ctx.fillStyle = i === 0 ? '#ffec27' : '#29adff';
                    ctx.fillRect(s.x * self.CELL + 1, s.y * self.CELL + 1,
                                 self.CELL - 2, self.CELL - 2);
                    if (i === 0) {
                        ctx.fillStyle = '#04121a';
                        ctx.fillRect(s.x * self.CELL + 6, s.y * self.CELL + 6, 4, 4);
                        ctx.fillRect(s.x * self.CELL + 13, s.y * self.CELL + 6, 4, 4);
                    }
                }
                if (over) {
                    ctx.fillStyle = 'rgba(19,20,31,.78)';
                    ctx.fillRect(0, 0, W, H);
                    ctx.fillStyle = '#ffec27';
                    ctx.font = 'bold 22px ui-monospace,monospace';
                    ctx.textAlign = 'center';
                    ctx.fillText('\u7ED3\u675F  ' + score + ' \u5206', W / 2, H / 2 - 8);
                    ctx.fillStyle = '#8b8fa3';
                    ctx.font = '13px ui-monospace,monospace';
                    ctx.fillText('\u70B9\u300C\u5F00\u59CB\u300D\u91CD\u6765', W / 2, H / 2 + 20);
                }
            }
            function start() {
                if (running) return;
                if (over || !snake) reset();
                running = true;
                stateEl.textContent = '\u8FDB\u884C\u4E2D';
                if (timer) clearInterval(timer);
                timer = setInterval(step, SPEEDS[speed].ms);   /* 按当前难度跑 */
                draw();
            }
            function pause() {
                if (!running) return;
                running = false;
                stateEl.textContent = '\u5DF2\u6682\u505C';
                if (timer) { clearInterval(timer); timer = null; }
            }
            function turn(d) {
                var map = { U: { x: 0, y: -1 }, D: { x: 0, y: 1 }, L: { x: -1, y: 0 }, R: { x: 1, y: 0 } };
                var nd = map[d];
                if (!nd) return;
                /* 不能 180° 掉头 */
                if (nd.x === -dir.x && nd.y === -dir.y) return;
                nextDir = nd;
                if (!running && !over) start();
            }

            box.querySelectorAll('.nb-snk-pad button').forEach(function (b) {
                b.addEventListener('click', function () { turn(b.dataset.d); });
            });
            box.querySelector('[data-act="start"]').addEventListener('click', start);
            box.querySelector('[data-act="pause"]').addEventListener('click', pause);

            /* 键盘：只在鼠标悬停在这块区域时才抢方向键，免得影响页面滚动 */
            var hot = false;
            box.addEventListener('mouseenter', function () { hot = true; });
            box.addEventListener('mouseleave', function () { hot = false; });
            function onKey(e) {
                if (!hot) return;
                var k = e.key.toLowerCase();
                var d = null;
                if (k === 'arrowup' || k === 'w') d = 'U';
                else if (k === 'arrowdown' || k === 's') d = 'D';
                else if (k === 'arrowleft' || k === 'a') d = 'L';
                else if (k === 'arrowright' || k === 'd') d = 'R';
                if (d) { e.preventDefault(); turn(d); }
            }
            document.addEventListener('keydown', onKey);

            /* 触屏滑动 */
            var tx = 0, ty = 0;
            cv.addEventListener('touchstart', function (e) {
                var t = e.touches[0]; tx = t.clientX; ty = t.clientY;
            }, { passive: true });
            cv.addEventListener('touchend', function (e) {
                var t = e.changedTouches[0];
                var dx = t.clientX - tx, dy = t.clientY - ty;
                if (Math.abs(dx) < 18 && Math.abs(dy) < 18) return;
                turn(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'R' : 'L') : (dy > 0 ? 'D' : 'U'));
            }, { passive: true });

            reset();
            draw();

            /* 卸载时清掉定时器和键盘监听 */
            return function () {
                if (timer) clearInterval(timer);
                document.removeEventListener('keydown', onKey);
            };
        }
    };

    /* ============================================================
       🌃 故障艺术标题
       ============================================================ */
    var GLITCH = {
        mount: function (box) {
            box.innerHTML =
                '<div class="nb-glx">' +
                  '<div class="nb-glx-lines"></div>' +
                  '<div class="nb-glx-scan"></div>' +
                  '<h2 class="nb-glx-t" data-t="NOBOOK CHANNEL">NOBOOK CHANNEL</h2>' +
                  '<p class="nb-glx-sub">\u70ED\u7231\u7406\u79D1 \u00B7 \u4E0E\u4F5C\u6B7B\u540C\u884C \u00B7 \u865A\u62DF\u516C\u53F8</p>' +
                  '<div class="nb-glx-tags">' +
                    '<span class="nb-glx-tag">EST. 2026</span>' +
                    '<span class="nb-glx-tag">\u5316\u5B66 \u00B7 \u7269\u7406</span>' +
                    '<span class="nb-glx-tag">NB\u5E01\u7ECF\u6D4E</span>' +
                    '<span class="nb-glx-tag">\u53CB\u5546\u751F\u6001</span>' +
                  '</div>' +
                '</div>';
            return function () {};
        }
    };

/* ============================================================
       🥮 中秋 · 真实月相 + 玉兔
       ============================================================ */
    var MOON = {
        mount: function (box) {
            /* 朔望月 29.53059 天。取一个已知新月时刻做基准：
               2026-09-11 12:27 UTC（这次是实测过的朔） */
            var SYNODIC = 29.530588853;
            var BASE = Date.UTC(2026, 8, 11, 12, 27);

            function phaseOf(now) {
                var days = (now.getTime() - BASE) / 86400000;
                var p = (days / SYNODIC) % 1;
                if (p < 0) p += 1;
                return p;                       /* 0 = 朔，0.5 = 望 */
            }
            function moonName(p) {
                if (p < 0.03 || p > 0.97) return '\u65B0\u6708';
                if (p < 0.22) return '\u6BDB\u6708';
                if (p < 0.28) return '\u4E0A\u5F26\u6708';
                if (p < 0.47) return '\u76C8\u51F8\u6708';
                if (p < 0.53) return '\u6EE1\u6708';
                if (p < 0.72) return '\u4E8F\u51F8\u6708';
                if (p < 0.78) return '\u4E0B\u5F26\u6708';
                return '\u6B8B\u6708';
            }
            /* 照亮比例：用余弦近似，够看就行 */
            function litRatio(p) { return (1 - Math.cos(2 * Math.PI * p)) / 2; }

            /* 画月相：一个圆，用一个椭圆做明暗界线把它切成月牙 */
            function moonSVG(p) {
                var R = 78, C = 95;
                var k = litRatio(p);
                /* 明暗界线椭圆的短半轴：0 时是满圆（朔是暗的，这里反过来算） */
                var rx = Math.abs(R * (1 - 2 * k));
                var waxing = p < 0.5;               /* 上半月右边亮 */
                var litRight = waxing ? k > 0 : k < 0.5 ? true : false;
                /* 亮面在哪边：上半月右侧、下半月左侧 */
                var side = waxing ? 1 : -1;
                /* 满月时不用切 */
                var d;
                if (k > 0.995) {
                    d = 'M ' + (C - R) + ' ' + C +
                        ' a ' + R + ' ' + R + ' 0 1 0 ' + (2 * R) + ' 0' +
                        ' a ' + R + ' ' + R + ' 0 1 0 ' + (-2 * R) + ' 0';
                } else if (k < 0.005) {
                    d = '';
                } else {
                    /* 半圆（右或左）+ 椭圆弧回来 */
                    var sweepOuter = side > 0 ? 1 : 0;
                    var sweepInner = (rx > 0.5 && k > 0.5) ? sweepOuter : (1 - sweepOuter);
                    var sweepInner2 = k > 0.5 ? sweepOuter : (1 - sweepOuter);
                    d = 'M ' + C + ' ' + (C - R) +
                        ' A ' + R + ' ' + R + ' 0 0 ' + sweepOuter + ' ' + C + ' ' + (C + R) +
                        ' A ' + rx.toFixed(2) + ' ' + R + ' 0 0 ' + sweepInner2 + ' ' + C + ' ' + (C - R) +
                        ' Z';
                }
                return '' +
                    '<svg width="190" height="190" viewBox="0 0 190 190">' +
                      '<defs>' +
                        '<radialGradient id="nbMoonGlow" cx="50%" cy="50%" r="50%">' +
                          '<stop offset="60%" stop-color="#ffe796" stop-opacity=".22"/>' +
                          '<stop offset="100%" stop-color="#ffe796" stop-opacity="0"/>' +
                        '</radialGradient>' +
                        '<radialGradient id="nbMoonLit" cx="38%" cy="34%" r="72%">' +
                          '<stop offset="0%" stop-color="#fffbe8"/>' +
                          '<stop offset="100%" stop-color="#e8cf8a"/>' +
                        '</radialGradient>' +
                      '</defs>' +
                      '<circle cx="95" cy="95" r="92" fill="url(#nbMoonGlow)"/>' +
                      '<circle cx="95" cy="95" r="' + R + '" fill="#1b2743"/>' +
                      (d ? '<path d="' + d + '" fill="url(#nbMoonLit)"/>' : '') +
                      /* 环形山的暗斑，让月亮不那么平 */
                      (k > 0.15 ? '<g opacity="' + (0.1 + k * 0.16).toFixed(2) + '">' +
                        '<circle cx="76" cy="72" r="13" fill="#8a7a52"/>' +
                        '<circle cx="112" cy="102" r="9" fill="#8a7a52"/>' +
                        '<circle cx="88" cy="120" r="7" fill="#8a7a52"/>' +
                      '</g>' : '') +
                    '</svg>';
            }

            /* 玉兔：简笔，两只耳朵一支捣药杵 */
            function rabbitSVG() {
                return '' +
                '<svg width="86" height="96" viewBox="0 0 86 96">' +
                  '<g fill="none" stroke="#f2ecd8" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">' +
                    /* 耳朵 */
                    '<path d="M32 34 C28 16 34 8 38 12 C42 16 40 26 39 34"/>' +
                    '<path d="M48 34 C50 16 56 10 59 15 C62 20 55 28 53 35"/>' +
                    /* 头 */
                    '<ellipse cx="43" cy="45" rx="17" ry="15"/>' +
                    /* 眼 */
                    '<circle cx="37" cy="43" r="1.8" fill="#f2ecd8"/>' +
                    '<circle cx="49" cy="43" r="1.8" fill="#f2ecd8"/>' +
                    /* 身 */
                    '<path d="M30 58 C22 62 20 74 28 80 C36 86 52 86 60 80 C68 74 64 62 56 58"/>' +
                    /* 捣药杵 */
                    '<path d="M62 30 L74 66" stroke="#ffe796"/>' +
                    '<ellipse cx="72" cy="70" rx="9" ry="6" fill="#ffe796" stroke="#ffe796"/>' +
                  '</g>' +
                '</svg>';
            }

            box.innerHTML =
                '<div class="nb-moon">' +
                  '<div class="nb-moon-stage" data-stage></div>' +
                  '<div class="nb-moon-info">' +
                    '<div class="name" data-name>\u6708\u76F8</div>' +
                    '<div class="pct" data-pct>--%</div>' +
                    '<div class="sub">\u6309\u5F53\u5929\u65E5\u671F\u7B97\u51FA\u7684\u771F\u5B9E\u6708\u76F8<br>' +
                      '\u5851\u671B\u6708 29.53 \u5929\u4E00\u8F6E</div>' +
                    '<div class="age" data-age></div>' +
                  '</div>' +
                '</div>';

            var stage = box.querySelector('[data-stage]');
            var nameEl = box.querySelector('[data-name]');
            var pctEl = box.querySelector('[data-pct]');
            var ageEl = box.querySelector('[data-age]');

            function render() {
                var p = phaseOf(new Date());
                var k = litRatio(p);
                stage.innerHTML = moonSVG(p) + rabbitSVG();
                nameEl.textContent = moonName(p);
                pctEl.textContent = Math.round(k * 100) + '%';
                ageEl.textContent = '\u6708\u9F84 ' + (p * SYNODIC).toFixed(1) + ' \u5929';
            }
            render();
            var t = setInterval(render, 60000);      /* 每分钟刷新一次 */
            return function () { clearInterval(t); };
        }
    };

/* ============================================================
       🖌️ 墨韵 · 毛笔逐笔写「NB」+ 落款印章
       笔画用 SVG 路径手写，靠 stroke-dasharray 一笔一笔描出来。
       ============================================================ */
    var BRUSH = {
        mount: function (box) {
            /* 「N」三笔，「B」两笔 —— 每笔一条 path */
            var STROKES = [
                /* N */
                'M40 210 L40 40',
                'M40 40 L110 210',
                'M110 210 L110 40',
                /* B */
                'M160 40 L160 210',
                'M160 40 C232 34 246 74 208 110 C252 128 250 196 160 210'
            ];
            var paths = STROKES.map(function (d, i) {
                return '<path class="stroke" d="' + d + '" data-i="' + i + '" ' +
                       'style="animation-delay:' + (i * 0.42).toFixed(2) + 's"/>';
            }).join('');

            /* 印章：方框 + 「NB」两个篆意小字 */
            var SEAL =
                '<svg class="nb-brush-seal" viewBox="0 0 96 96">' +
                  '<rect x="3" y="3" width="90" height="90" rx="6" fill="#8c2f23"/>' +
                  '<rect x="10" y="10" width="76" height="76" rx="3" ' +
                    'fill="none" stroke="#faf7f0" stroke-width="3"/>' +
                  '<g fill="#faf7f0" font-family="ui-monospace,monospace" ' +
                    'font-size="30" font-weight="800" text-anchor="middle">' +
                    '<text x="30" y="42">N</text>' +
                    '<text x="66" y="42">B</text>' +
                    '<text x="30" y="76">\u9891</text>' +
                    '<text x="66" y="76">\u9053</text>' +
                  '</g>' +
                '</svg>';

            box.innerHTML =
                '<div class="nb-brush" data-root>' +
                  '<div class="nb-brush-inner">' +
                    '<div><svg width="300" height="250" viewBox="0 0 300 250">' +
                      '<g>' + paths + '</g>' +
                    '</svg></div>' +
                    '<div class="nb-brush-side">' +
                      SEAL +
                      '<div class="t">\u58A8\u97F5</div>' +
                      '<div class="d">\u5BA3\u7EB8\u7126\u58A8 \u00B7 \u4E00\u7B14\u4E00\u753B<br>' +
                        '\u70B9\u300C\u91CD\u5199\u300D\u518D\u770B\u4E00\u904D</div>' +
                      '<div class="nb-brush-btns">' +
                        '<button class="nb-brush-btn" data-again>\u91CD\u5199</button>' +
                      '</div>' +
                    '</div>' +
                  '</div>' +
                '</div>';

            var root = box.querySelector('[data-root]');

            /* 算每笔的长度写进 --len，动画才知道要描多长 */
            function prep() {
                root.querySelectorAll('.stroke').forEach(function (p) {
                    var len = p.getTotalLength ? p.getTotalLength() : 300;
                    p.style.setProperty('--len', len.toFixed(1));
                    p.style.strokeDasharray = len.toFixed(1);
                    p.style.strokeDashoffset = len.toFixed(1);
                });
            }
            function play() {
                root.classList.remove('nb-brush-go');
                void root.offsetWidth;          /* 强制重排，让动画重头播 */
                prep();
                root.classList.add('nb-brush-go');
            }
            box.querySelector('[data-again]').addEventListener('click', play);
            prep();
            /* 进视口再播，免得加载时已经演完了 */
            var io = null;
            if ('IntersectionObserver' in window) {
                io = new IntersectionObserver(function (es) {
                    es.forEach(function (e) { if (e.isIntersecting) { play(); io.disconnect(); } });
                }, { threshold: 0.25 });
                io.observe(root);
            } else {
                play();
            }
            return function () { if (io) io.disconnect(); };
        }
    };

    /* ============================================================
       模块表 + 挂载
       ============================================================ */
    var MODULES = {
        pixel: {
            head: '\uD83D\uDC7E \u50CF\u7D20\u6E38\u620F <i>\u00B7 \u8D2A\u5403\u86C7</i>',
            mount: function (box) { return SNAKE.mount(box); }
        },
        cyber: {
            head: '\uD83C\uDF03 \u6545\u969C\u827A\u672F <i>\u00B7 \u6807\u9898\u5B57</i>',
            mount: function (box) { return GLITCH.mount(box); }
        },
        ink: {
            head: '\uD83D\uDD8C\uFE0F \u6BDB\u7B14\u5199\u5B57 <i>\u00B7 \u9010\u7B14\u63CF\u51FA</i>',
            mount: function (box) { return BRUSH.mount(box); }
        },
        midautumn: {
            head: '\uD83E\uDD5E \u6708\u76F8\u76C8\u4E8F <i>\u00B7 \u6309\u5F53\u5929\u65E5\u671F\u7B97</i>',
            mount: function (box) { return MOON.mount(box); }
        }
    };

    var cleanup = null;

    function mount() {
        var theme = document.documentElement.getAttribute('theme') || 'default';
        var mod = MODULES[theme];
        var old = document.getElementById(HOST_ID);

        if (cleanup) { try { cleanup(); } catch (e) {} cleanup = null; }
        if (old && old.parentNode) old.parentNode.removeChild(old);
        if (!mod) return;

        /* 只在首页：首页有 .hero-inner，其它页面是 .vhero-inner */
        var inner = document.querySelector('.hero-inner');
        if (!inner) return;

        if (!document.getElementById(CSS_ID)) {
            var st = document.createElement('style');
            st.id = CSS_ID;
            st.textContent = CSS;
            document.head.appendChild(st);
        }

        var wrap = document.createElement('div');
        wrap.id = HOST_ID;

        var head = document.createElement('div');
        head.className = 'nb-ex-head';
        var sp = document.createElement('span');
        sp.className = 'sp';
        sp.innerHTML = mod.head;
        head.appendChild(sp);

        var card = document.createElement('div');
        card.className = 'nb-ex-card';

        wrap.appendChild(head);
        wrap.appendChild(card);

        var hero = document.querySelector('.hero');
        var scroll = hero ? hero.querySelector('.hero-scroll') : null;
        if (scroll && scroll.parentNode === hero) hero.insertBefore(wrap, scroll);
        else inner.parentNode.insertBefore(wrap, inner.nextSibling);

        cleanup = mod.mount(card) || null;
    }

    function boot() {
        mount();
        window.addEventListener('nb-theme-change', mount);
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})();
