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


        /* ---------- 🌙 护眼 · 作息提醒 ---------- */
        '.nb-eye{display:grid;grid-template-columns:auto 1fr;gap:40px;align-items:center;',
        '  padding:38px 36px;border-radius:12px;background:#dad3c4;',
        '  border:1px solid rgba(58,54,48,.16);}',
        '.nb-eye-clock{font-size:3.4rem;font-weight:200;letter-spacing:4px;color:#3a3630;',
        '  font-variant-numeric:tabular-nums;line-height:1;}',
        '.nb-eye-date{margin-top:10px;font-size:.78rem;letter-spacing:2px;color:#7a7266;}',
        '.nb-eye-info .row{display:flex;justify-content:space-between;gap:26px;',
        '  padding:11px 0;border-bottom:1px solid rgba(58,54,48,.12);font-size:.82rem;}',
        '.nb-eye-info .row:last-child{border-bottom:none;}',
        '.nb-eye-info .k{color:#7a7266;letter-spacing:1px;}',
        '.nb-eye-info .v{color:#3a3630;font-weight:700;font-variant-numeric:tabular-nums;}',
        '.nb-eye-tip{margin-top:18px;padding:14px 18px;border-radius:6px;',
        '  background:rgba(107,90,62,.12);border-left:3px solid #6b5a3e;',
        '  font-size:.82rem;line-height:1.9;color:#524c43;}',
        '.nb-eye-tip.warn{background:rgba(140,47,35,.12);border-left-color:#8c2f23;}',
        '.nb-eye-btns{margin-top:16px;display:flex;gap:8px;}',
        '.nb-eye-btn{padding:7px 15px;border-radius:2px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1px;background:#6b5a3e;color:#e0d9cb;border:none;}',
        '.nb-eye-btn:hover{background:#544730;}',
        '@media(max-width:860px){',
        '  .nb-eye{grid-template-columns:1fr;gap:24px;}',
        '}',

        '@media(prefers-reduced-motion:reduce){',
        '  .nb-glx-t::before,.nb-glx-t::after,.nb-glx-scan{animation:none;opacity:0;}',
        '}',

        /* ---------- 墨韵 · 毛笔写的 NB-CHANNEL ---------- */
        '.nb-ink{position:relative;padding:40px 34px 54px;border-radius:12px;',
        '  background:linear-gradient(170deg,#faf7f0,#f4f0e6 60%,#efe9dd);',
        '  border:1px solid rgba(28,26,23,.14);overflow:hidden;}',
        '.nb-ink-inner{display:grid;grid-template-columns:1fr 190px;gap:28px;align-items:center;}',
        '.nb-ink svg{display:block;max-width:100%;height:auto;}',
        /* 每一笔是一条【填充轮廓】（不是等宽描边），所以自带粗细变化。
           默认已经写好，只有 .nb-ink-go 时才从零"长"出来。 */
        '.nb-ink .gl{fill:#1c1a17;stroke:none;}',
        /* 晕：同一个轮廓往外扩一圈，低透明度，用 SVG 的 stroke 模拟洇边 */
        '.nb-ink .gl-halo{fill:none;stroke:#3a3228;stroke-width:7;opacity:.14;',
        '  stroke-linejoin:round;}',
        '.nb-ink .gl-halo2{fill:none;stroke:#5a4d3c;stroke-width:13;opacity:.07;',
        '  stroke-linejoin:round;}',
        '.nb-ink-go .gl,.nb-ink-go .gl-halo,.nb-ink-go .gl-halo2{',
        '  clip-path:inset(0 100% 0 0);animation:nbInkW .62s cubic-bezier(.4,.05,.3,1) forwards;}',
        '@keyframes nbInkW{to{clip-path:inset(0 0 0 0);}}',
        '.nb-ink-seal{opacity:1;transform:rotate(-8deg);transform-origin:50% 50%;}',
        '.nb-ink-go .nb-ink-seal{opacity:0;transform:scale(1.7) rotate(-18deg);',
        '  animation:nbSeal2 .38s cubic-bezier(.2,1.7,.4,1) 2.8s forwards;}',
        '@keyframes nbSeal2{to{opacity:1;transform:scale(1) rotate(-8deg);}}',
        '.nb-ink-side{text-align:right;}',
        '.nb-ink-side .t{font-size:1.2rem;font-weight:800;letter-spacing:6px;color:#1c1a17;}',
        '.nb-ink-side .d{margin-top:12px;font-size:.74rem;letter-spacing:1.5px;',
        '  color:#6b6459;line-height:2.1;}',
        '.nb-ink-btns{margin-top:18px;display:flex;gap:8px;justify-content:flex-end;}',
        '.nb-ink-btn{padding:7px 15px;border-radius:2px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1.5px;background:#8c2f23;color:#faf7f0;border:none;}',
        '.nb-ink-btn:hover{background:#6d241a;}',
        '.nb-ink-cap{margin-top:14px;font-size:.7rem;letter-spacing:4px;color:#8b8375;}',
        '@media(max-width:860px){',
        '  .nb-ink-inner{grid-template-columns:1fr;}',
        '  .nb-ink-side{text-align:center;}',
        '  .nb-ink-btns{justify-content:center;}',
        '}',
        '@media(prefers-reduced-motion:reduce){',
        '  .nb-ink .gl,.nb-ink .gl-halo,.nb-ink .gl-halo2{clip-path:none;animation:none;}',
        '  .nb-ink-seal{opacity:1;transform:rotate(-8deg);animation:none;}',
        '}',

        '@media(max-width:820px){.nb-moon{grid-template-columns:1fr;justify-items:center;text-align:center;}}',

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
       墨韵 · 毛笔写的 NB-CHANNEL
       每一笔给一条【中心线】+ 宽度曲线，运行时沿中心线采样，
       按法线往两侧撑开，合成一条闭合轮廓再填充。
       这样起笔顿、行笔饱满、收笔出锋，才是毛笔而不是马克笔。
       ============================================================ */
    var INK = {
        mount: function (box) {
            var NS = 'http://www.w3.org/2000/svg';

            /* 中心线 + 参数
               d    : 中心线路径
               w    : 最粗处（半宽，单位是 SVG 坐标）
               taper: 收笔系数，越小锋越尖
               dl   : 落笔延迟（秒） */
            var G = [
                /* N */
                { d: 'M32 152 L32 44',  w: 7.2, taper: .3, dl: 0.00 },
                { d: 'M34 46 L88 152',  w: 6.2, taper: .5, dl: 0.16 },
                { d: 'M88 150 L88 42',  w: 7.0, taper: .3, dl: 0.32 },
                /* B */
                { d: 'M122 152 L122 42', w: 7.2, taper: .3, dl: 0.48 },
                { d: 'M124 44 C176 40 184 76 148 96', w: 5.4, taper: .45, dl: 0.64 },
                { d: 'M148 96 C192 100 194 148 122 152', w: 5.6, taper: .5, dl: 0.80 },
                /* 连字符 */
                { d: 'M204 100 L254 100', w: 4.6, taper: .85, dl: 0.96 },
                /* C */
                { d: 'M326 54 C308 32 268 36 268 96 C268 156 308 160 326 138',
                  w: 5.8, taper: .55, dl: 1.10 },
                /* H */
                { d: 'M354 152 L354 42', w: 7.2, taper: .3, dl: 1.26 },
                { d: 'M356 98 L410 98',  w: 5.4, taper: .85, dl: 1.42 },
                { d: 'M410 152 L410 42', w: 7.2, taper: .3, dl: 1.58 },
                /* A */
                { d: 'M434 152 L468 42', w: 6.6, taper: .45, dl: 1.74 },
                { d: 'M468 42 L502 152', w: 6.6, taper: .45, dl: 1.90 },
                { d: 'M446 114 L490 114', w: 5.0, taper: .8, dl: 2.06 },
                /* N */
                { d: 'M528 152 L528 44', w: 7.0, taper: .3, dl: 2.22 },
                { d: 'M530 46 L584 152', w: 6.2, taper: .5, dl: 2.38 },
                { d: 'M584 150 L584 42', w: 7.0, taper: .3, dl: 2.54 },
                /* N */
                { d: 'M612 152 L612 44', w: 7.0, taper: .3, dl: 2.70 },
                { d: 'M614 46 L668 152', w: 6.2, taper: .5, dl: 2.86 },
                { d: 'M668 150 L668 42', w: 7.0, taper: .3, dl: 3.02 },
                /* E */
                { d: 'M700 152 L700 42', w: 7.0, taper: .3, dl: 3.18 },
                { d: 'M702 44 L750 44',  w: 5.0, taper: .8, dl: 3.30 },
                { d: 'M702 98 L742 98',  w: 4.8, taper: .8, dl: 3.42 },
                { d: 'M702 150 L750 150', w: 5.0, taper: .8, dl: 3.54 },
                /* L */
                { d: 'M778 44 L778 152', w: 7.0, taper: .3, dl: 3.66 },
                { d: 'M780 152 L826 152', w: 5.2, taper: .8, dl: 3.82 }
            ];

            /* ---------- 宽度曲线 ----------
               t: 0→1
               起笔 0.30→1.0（顿笔）  中段 1.0→0.72  收笔 →taper（出锋） */
            function widthAt(t, w, taper) {
                var k;
                if (t < 0.10) k = 0.30 + (t / 0.10) * 0.70;          /* 起笔顿 */
                else if (t < 0.55) k = 1.0 - ((t - 0.10) / 0.45) * 0.28;
                else k = 0.72 - ((t - 0.55) / 0.45) * (0.72 - taper);
                /* 一点点抖动，别太像印刷体 */
                k *= 1 + (Math.sin(t * 37.1) * 0.035);
                return Math.max(0.35, k) * w;
            }

            /* 沿中心线采样，撑出闭合轮廓 */
            function outline(d, w, taper, step) {
                var probe = document.createElementNS(NS, 'path');
                probe.setAttribute('d', d);
                var hide = document.createElementNS(NS, 'g');
                hide.setAttribute('visibility', 'hidden');
                hide.appendChild(probe);
                box.appendChild(hide);

                var L = probe.getTotalLength ? probe.getTotalLength() : 120;
                step = step || Math.max(1.6, L / 60);

                var left = [], right = [], s;
                for (s = 0; s <= L; s += step) {
                    var t = s / L;
                    var p = probe.getPointAtLength(s);
                    /* 切线用邻近点差分算，比 getTangentAtLength 兼容性好 */
                    var s2 = Math.min(L, s + 1.2);
                    var p2 = probe.getPointAtLength(s2);
                    var dx = p2.x - p.x, dy = p2.y - p.y;
                    var len = Math.hypot(dx, dy) || 1;
                    var nx = -dy / len, ny = dx / len;          /* 法线 */
                    var hw = widthAt(t, w, taper);
                    left.push([p.x + nx * hw, p.y + ny * hw]);
                    right.push([p.x - nx * hw, p.y - ny * hw]);
                }
                box.removeChild(hide);

                var pts = left.concat(right.reverse());
                var out = 'M' + pts[0][0].toFixed(2) + ' ' + pts[0][1].toFixed(2);
                for (var i = 1; i < pts.length; i++) {
                    out += 'L' + pts[i][0].toFixed(2) + ' ' + pts[i][1].toFixed(2);
                }
                return out + 'Z';
            }

            /* ---------- 组装 ---------- */
            var svg = document.createElementNS(NS, 'svg');
            svg.setAttribute('width', '856');
            svg.setAttribute('height', '200');
            svg.setAttribute('viewBox', '0 0 856 200');
            svg.style.maxWidth = '100%';
            svg.style.height = 'auto';

            var layerHalo2 = document.createElementNS(NS, 'g');   /* 最外圈洇 */
            var layerHalo = document.createElementNS(NS, 'g');    /* 次外圈 */
            var layerMain = document.createElementNS(NS, 'g');    /* 笔锋本体 */
            svg.appendChild(layerHalo2);
            svg.appendChild(layerHalo);
            svg.appendChild(layerMain);

            G.forEach(function (o) {
                var dOut = outline(o.d, o.w, o.taper);
                var delay = o.dl.toFixed(2) + 's';

                [['gl-halo2', layerHalo2], ['gl-halo', layerHalo], ['gl', layerMain]]
                .forEach(function (pair) {
                    var el = document.createElementNS(NS, 'path');
                    el.setAttribute('class', pair[0]);
                    el.setAttribute('d', dOut);
                    el.style.animationDelay = delay;
                    /* 晕圈用原始中心线描边（比填充轮廓更像洇开的边） */
                    if (pair[0] !== 'gl') {
                        el.setAttribute('d', o.d);
                        el.setAttribute('fill', 'none');
                    }
                    pair[1].appendChild(el);
                });
            });

            var wrap = document.createElement('div');
            wrap.innerHTML =
                '<div class="nb-ink" data-root>' +
                  '<div class="nb-ink-inner">' +
                    '<div data-svgslot></div>' +
                    '<div class="nb-ink-side">' +
                      '<div class="t">\u58A8\u97F5</div>' +
                      '<div class="d">\u6BDB\u7B14\u4E66\u5199<br>\u8D77\u7B14\u987F \u00B7 \u6536\u7B14\u950B</div>' +
                      '<div class="nb-ink-btns">' +
                        '<button class="nb-ink-btn" data-again>\u91CD\u5199</button>' +
                      '</div>' +
                    '</div>' +
                  '</div>' +
                  '<div class="nb-ink-cap">\u4E00\u7B14\u4E00\u753B \u00B7 \u5171 ' +
                    G.length + ' \u7B14</div>' +
                '</div>';
            box.innerHTML = '';
            box.appendChild(wrap);
            var root = box.querySelector('[data-root]');
            root.querySelector('[data-svgslot]').appendChild(svg);

            /* 印章 */
            var sealHost = document.createElement('div');
            sealHost.style.cssText = 'position:absolute;right:34px;bottom:32px';
            sealHost.innerHTML =
                '<svg class="nb-ink-seal" width="70" height="70" viewBox="0 0 70 70">' +
                  '<rect x="2" y="2" width="66" height="66" rx="4" fill="#8c2f23"/>' +
                  '<rect x="8" y="8" width="54" height="54" rx="2" fill="none" ' +
                    'stroke="#faf7f0" stroke-width="2.2"/>' +
                  '<g fill="#faf7f0" font-family="ui-monospace,Consolas,monospace" ' +
                    'font-size="19" font-weight="800" text-anchor="middle">' +
                    '<text x="23" y="31">N</text><text x="47" y="31">B</text>' +
                    '<text x="23" y="55">\u9891</text><text x="47" y="55">\u9053</text>' +
                  '</g>' +
                '</svg>';
            root.appendChild(sealHost);

            function play() {
                root.classList.remove('nb-ink-go');
                void root.offsetWidth;
                root.classList.add('nb-ink-go');
            }
            box.querySelector('[data-again]').addEventListener('click', play);

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
        eyecare: {
            head: '\uD83C\uDF19 \u4F5C\u606F\u63D0\u9192 <i>\u00B7 \u770B\u4E45\u4E86\u8BE5\u6B47歇</i>',
            mount: function (box) { return EYE.mount(box); }
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
