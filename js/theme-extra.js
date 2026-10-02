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
        '}',

        /* ---------- 墨韵 · 水墨山水 + 两竿竹 ---------- */
        '.nb-ink{position:relative;padding:34px 30px;border-radius:12px;',
        '  background:linear-gradient(170deg,#faf7f0,#f4f0e6 60%,#efe9dd);',
        '  border:1px solid rgba(28,26,23,.14);overflow:hidden;}',
        '.nb-ink-inner{display:grid;grid-template-columns:1fr 230px;gap:28px;align-items:center;}',
        '.nb-ink svg{display:block;}',
        /* 每一笔都是独立 path。默认【已经画好】，只有 .nb-ink-go 时才从零描一遍 ——
           这样即使动画没触发，画也在，不会白板。 */
        '.nb-ink .st{fill:none !important;stroke:#1c1a17;stroke-linecap:round;',
        '  stroke-linejoin:round;stroke-width:2.6;stroke-dasharray:var(--len,0);',
        '  stroke-dashoffset:0;}',
        '.nb-ink .st.thin{stroke-width:1.5;opacity:.7;}',
        '.nb-ink .st.mid{stroke-width:2.6;}',
        '.nb-ink .st.thick{stroke-width:5;}',
        '.nb-ink .wash{opacity:.14;}',
        /* 播动画时先藏起来再描 */
        '.nb-ink-go .st{stroke-dashoffset:var(--len,0);',
        '  animation:nbInk .95s cubic-bezier(.45,.05,.3,1) forwards;}',
        '@keyframes nbInk{to{stroke-dashoffset:0;}}',
        '.nb-ink-seal{opacity:1;transform:rotate(-9deg);transform-origin:50% 50%;}',
        '.nb-ink-go .nb-ink-seal{opacity:0;transform:scale(1.6) rotate(-16deg);',
        '  animation:nbSeal2 .4s cubic-bezier(.2,1.7,.4,1) 2.3s forwards;}',
        '@keyframes nbSeal2{to{opacity:1;transform:scale(1) rotate(-9deg);}}',
        '.nb-ink-side{text-align:right;}',
        '.nb-ink-side .t{font-size:1.25rem;font-weight:800;letter-spacing:6px;color:#1c1a17;}',
        '.nb-ink-side .d{margin-top:12px;font-size:.76rem;letter-spacing:1.5px;',
        '  color:#6b6459;line-height:2.1;}',
        '.nb-ink-btns{margin-top:18px;display:flex;gap:8px;justify-content:flex-end;}',
        '.nb-ink-btn{padding:7px 15px;border-radius:2px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1.5px;background:#8c2f23;color:#faf7f0;border:none;}',
        '.nb-ink-btn:hover{background:#6d241a;}',
        '@media(max-width:860px){',
        '  .nb-ink-inner{grid-template-columns:1fr;}',
        '  .nb-ink-side{text-align:center;}',
        '  .nb-ink-btns{justify-content:center;}',
        '}',
        '@media(prefers-reduced-motion:reduce){',
        '  .nb-ink .st{stroke-dashoffset:0;animation:none;}',
        '  .nb-ink-seal{opacity:1;transform:rotate(-9deg);animation:none;}',
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
       墨韵 · 水墨山水 + 两竿竹
       一笔一笔描出来：远山三重轮廓 → 山脚淡墨 → 竹竿竹节 → 竹枝 → 竹叶，
       最后落款盖印。全部是 SVG path，靠 dasharray 从无到有。
       （汉字轮廓需要字体文件，这里不硬凑，改成画水墨。）
       ============================================================ */
    var INK = {
        mount: function (box) {
            /* 每条 d 是一笔，dl 是它开始的秒数，按顺序递增，读起来像在运笔 */
            var STROKES = [
                /* 远山：三重轮廓，越远越淡 */
                { d: 'M10 168 C58 108 96 96 138 152 C160 180 176 186 196 174', c: 'thin', dl: 0.00 },
                { d: 'M52 168 C92 126 122 118 152 158', c: 'thin', dl: 0.22 },
                { d: 'M118 170 C158 122 196 112 240 150 C266 174 288 180 312 168', c: 'mid', dl: 0.44 },
                { d: 'M176 172 C206 142 238 136 268 160', c: 'thin', dl: 0.62 },
                /* 山脚一抹淡墨 */
                { d: 'M24 178 C86 172 150 176 214 176 C264 176 296 178 330 172', c: 'thin', dl: 0.80 },
                /* 竹竿两节 */
                { d: 'M352 42 L352 108', c: 'thick', dl: 1.00 },
                { d: 'M352 122 L352 186', c: 'thick', dl: 1.16 },
                /* 竹节 */
                { d: 'M344 112 L360 112', c: 'mid', dl: 1.32 },
                { d: 'M344 190 L360 190', c: 'mid', dl: 1.40 },
                /* 竹枝 */
                { d: 'M352 78 C374 70 384 58 390 44', c: 'mid', dl: 1.52 },
                { d: 'M352 132 C376 132 388 140 396 152', c: 'mid', dl: 1.66 },
                { d: 'M352 58 C332 46 322 34 318 20', c: 'mid', dl: 1.78 },
                /* 竹叶，一叶一笔 */
                { d: 'M390 44 C404 34 416 32 428 36', c: 'mid', dl: 1.90 },
                { d: 'M390 44 C400 58 404 70 402 84', c: 'mid', dl: 1.98 },
                { d: 'M396 152 C412 156 424 166 430 180', c: 'mid', dl: 2.06 },
                { d: 'M396 152 C410 142 422 138 436 138', c: 'thin', dl: 2.14 },
                { d: 'M318 20 C306 12 296 10 284 12', c: 'mid', dl: 2.22 },
                { d: 'M318 20 C314 6 312 -6 314 -16', c: 'mid', dl: 2.28 },
                { d: 'M352 78 C340 88 332 100 330 112', c: 'thin', dl: 2.34 },
                { d: 'M352 132 C344 122 334 116 322 114', c: 'thin', dl: 2.40 }
            ];

            var WASH =
                '<g class="wash">' +
                  '<ellipse cx="150" cy="180" rx="132" ry="12" fill="#1c1a17" opacity=".07"/>' +
                  '<ellipse cx="354" cy="196" rx="26" ry="6" fill="#1c1a17" opacity=".1"/>' +
                '</g>';

            var paths = STROKES.map(function (o, i) {
                return '<path class="st ' + o.c + '" fill="none" d="' + o.d + '" data-i="' + i + '" ' +
                       'style="animation-delay:' + o.dl.toFixed(2) + 's"/>';
            }).join('');

            var SEAL =
                '<svg class="nb-ink-seal" width="72" height="72" viewBox="0 0 72 72" ' +
                  'style="position:absolute;right:34px;bottom:30px">' +
                  '<rect x="2" y="2" width="68" height="68" rx="4" fill="#8c2f23"/>' +
                  '<rect x="8" y="8" width="56" height="56" rx="2" fill="none" ' +
                    'stroke="#faf7f0" stroke-width="2.4"/>' +
                  '<g fill="#faf7f0" font-family="ui-monospace,Consolas,monospace" ' +
                    'font-size="20" font-weight="800" text-anchor="middle">' +
                    '<text x="24" y="32">N</text>' +
                    '<text x="48" y="32">B</text>' +
                    '<text x="24" y="56">\u9891</text>' +
                    '<text x="48" y="56">\u9053</text>' +
                  '</g>' +
                '</svg>';

            box.innerHTML =
                '<div class="nb-ink" data-root>' +
                  '<div class="nb-ink-inner">' +
                    '<div><svg width="440" height="210" viewBox="0 0 440 210" ' +
                      'style="max-width:100%;height:auto">' +
                      WASH + '<g>' + paths + '</g>' +
                    '</svg></div>' +
                    '<div class="nb-ink-side">' +
                      '<div class="t">\u58A8\u97F5</div>' +
                      '<div class="d">\u8FDC\u5C71 \u00B7 \u4E24\u7AF9 \u00B7 \u4E00\u65B9\u5370<br>' +
                        '\u4E00\u7B14\u4E00\u753B\u63CF\u51FA\u6765\u7684</div>' +
                      '<div class="nb-ink-btns">' +
                        '<button class="nb-ink-btn" data-again>\u91CD\u753B</button>' +
                      '</div>' +
                    '</div>' +
                  '</div>' + SEAL +
                '</div>';

            var root = box.querySelector('[data-root]');

            function prep() {
                root.querySelectorAll('.st').forEach(function (p) {
                    var len = p.getTotalLength ? p.getTotalLength() : 400;
                    p.style.setProperty('--len', len.toFixed(1));
                });
            }
            function play() {
                root.classList.remove('nb-ink-go');
                void root.offsetWidth;              /* 强制重排，动画重头播 */
                prep();
                root.classList.add('nb-ink-go');
            }
            box.querySelector('[data-again]').addEventListener('click', play);
            prep();

            var io = null;
            if ('IntersectionObserver' in window) {
                io = new IntersectionObserver(function (es) {
                    es.forEach(function (e) { if (e.isIntersecting) { play(); io.disconnect(); } });
                }, { threshold: 0.2 });
                io.observe(root);
            } else { play(); }

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
            head: '\uD83D\uDD8C\uFE0F \u6C34\u58A8\u5C71\u6C34 <i>\u00B7 \u9010\u7B14\u63CF\u51FA</i>',
            mount: function (box) { return INK.mount(box); }
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
