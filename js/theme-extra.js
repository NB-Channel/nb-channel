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

        /* ---------- 🧨 春节 · 点鞭炮 ---------- */
        '.nb-fw{position:relative;border-radius:12px;overflow:hidden;',
        '  background:linear-gradient(175deg,#6d0a0e,#8c0f13 55%,#a3161b);',
        '  border:1px solid rgba(255,216,94,.28);cursor:crosshair;}',
        '.nb-fw canvas{display:block;width:100%;height:340px;}',
        '.nb-fw-hint{position:absolute;left:0;right:0;bottom:16px;text-align:center;',
        '  font-size:.76rem;letter-spacing:2px;color:rgba(255,238,210,.7);pointer-events:none;}',
        '.nb-fw-top{position:absolute;left:20px;top:16px;display:flex;gap:22px;',
        '  font-size:.76rem;letter-spacing:1px;color:rgba(255,238,210,.8);pointer-events:none;}',
        '.nb-fw-top b{color:#ffd85e;font-size:1.1rem;}',
        '.nb-fw-side{position:absolute;right:20px;top:16px;display:flex;gap:8px;}',
        '.nb-fw-btn{padding:6px 13px;border-radius:2px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1px;background:rgba(255,216,94,.16);',
        '  color:#ffe9a8;border:1px solid rgba(255,216,94,.4);}',
        '.nb-fw-btn:hover{background:rgba(255,216,94,.3);}',

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

        /* ---------- 墨韵 · 手写体 NB-CHANNEL ---------- */
        '.nb-ink{position:relative;padding:40px 34px 52px;border-radius:12px;',
        '  background:linear-gradient(170deg,#faf7f0,#f4f0e6 60%,#efe9dd);',
        '  border:1px solid rgba(28,26,23,.14);overflow:hidden;}',
        '.nb-ink-inner{display:grid;grid-template-columns:1fr 200px;gap:30px;align-items:center;}',
        '.nb-ink svg{display:block;max-width:100%;height:auto;}',
        /* 每一笔一条 path。默认【已经写好】，只有 .nb-ink-go 时才从零描一遍 ——
           这样动画万一没触发，字也在，不会白板。 */
        '.nb-ink .st{fill:none !important;stroke:#1c1a17;stroke-linecap:round;',
        '  stroke-linejoin:round;stroke-width:7;stroke-dasharray:var(--len,0);',
        '  stroke-dashoffset:0;}',
        '.nb-ink .st.thin{stroke-width:5;opacity:.82;}',
        '.nb-ink .st.mid{stroke-width:7;}',
        '.nb-ink .st.thick{stroke-width:9;}',
        /* 晕染层：同一个 d 加粗 + 高斯模糊，垫在笔锋下面，像是洇开的墨 */
        '.nb-ink .bl{fill:none !important;stroke:#3a3228;stroke-linecap:round;',
        '  stroke-linejoin:round;stroke-dasharray:var(--len,0);stroke-dashoffset:0;',
        '  filter:url(#nbInkBleed);opacity:.26;}',
        '.nb-ink .bl.w-thin{stroke-width:11;}',
        '.nb-ink .bl.w-mid{stroke-width:15;}',
        '.nb-ink .bl.w-thick{stroke-width:20;}',
        '.nb-ink-go .st,.nb-ink-go .bl{stroke-dashoffset:var(--len,0);',
        '  animation:nbInk .72s cubic-bezier(.45,.05,.3,1) forwards;}',
        '@keyframes nbInk{to{stroke-dashoffset:0;}}',
        /* 印章：默认就盖着，播动画时从放大状态落定 */
        '.nb-ink-seal{opacity:1;transform:rotate(-8deg);transform-origin:50% 50%;}',
        '.nb-ink-go .nb-ink-seal{opacity:0;transform:scale(1.7) rotate(-18deg);',
        '  animation:nbSeal2 .38s cubic-bezier(.2,1.7,.4,1) 2.6s forwards;}',
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
        '  .nb-ink .st,.nb-ink .bl{stroke-dashoffset:0;animation:none;}',
        '  .nb-ink-seal{opacity:1;transform:rotate(-8deg);animation:none;}',
        '}',

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
       墨韵 · 手写体 NB-CHANNEL
       每个字母 2~4 笔，全部手写成单线路径，按笔顺逐笔描出来，
       最后落款盖印。和主题名「墨韵」最搭的一套。
       ============================================================ */
    var INK = {
        mount: function (box) {
            /* 手写体布局：基线 y=150，字高 44~112，字宽约 56，字距 20。
               每笔 = { d, w(粗细), dl(延迟秒) }                      */
            var G = [];   /* 收集所有笔画 */
            function push(d, w, dl) { G.push({ d: d, w: w, dl: dl }); }

            /* ---- N ---- */
            push('M30 150 L30 40', 'thick', 0.00);
            push('M30 40 L86 150', 'mid',   0.13);
            push('M86 150 L86 40', 'thick', 0.26);

            /* ---- B ---- */
            push('M118 150 L118 40', 'thick', 0.39);
            push('M118 40 C176 34 186 72 150 94', 'mid', 0.52);
            push('M150 94 C196 98 198 146 118 150', 'mid', 0.65);

            /* ---- 连字符 ---- */
            push('M206 100 L256 100', 'thin', 0.78);

            /* ---- C ---- */
            push('M328 52 C310 30 268 34 268 95 C268 156 310 160 328 138', 'mid', 0.91);

            /* ---- H ---- */
            push('M354 150 L354 40', 'thick', 1.04);
            push('M354 96 L410 96', 'mid',   1.17);
            push('M410 150 L410 40', 'thick', 1.30);

            /* ---- A ---- */
            push('M434 150 L468 40', 'thick', 1.43);
            push('M468 40 L502 150', 'thick', 1.56);
            push('M446 112 L490 112', 'mid',  1.69);

            /* ---- N ---- */
            push('M528 150 L528 40', 'thick', 1.82);
            push('M528 40 L584 150', 'mid',   1.95);
            push('M584 150 L584 40', 'thick', 2.08);

            /* ---- N ---- */
            push('M612 150 L612 40', 'thick', 2.21);
            push('M612 40 L668 150', 'mid',   2.34);
            push('M668 150 L668 40', 'thick', 2.47);

            /* ---- E ---- */
            push('M700 150 L700 40', 'thick', 2.60);
            push('M700 40 L750 40', 'mid',   2.70);
            push('M700 96 L742 96', 'mid',   2.80);
            push('M700 150 L750 150', 'mid', 2.90);

            /* ---- L ---- */
            push('M778 40 L778 150', 'thick', 3.02);
            push('M778 150 L826 150', 'mid',  3.14);

            /* 每一笔生成两条 path：bl 是晕染层（粗 + 模糊），st 是笔锋层 */
            var bleed = G.map(function (o, i) {
                return '<path class="bl w-' + o.w + '" fill="none" d="' + o.d + '" ' +
                       'style="animation-delay:' + o.dl.toFixed(2) + 's"/>';
            }).join('');
            var paths = G.map(function (o, i) {
                return '<path class="st ' + o.w + '" fill="none" d="' + o.d + '" ' +
                       'data-i="' + i + '" style="animation-delay:' + o.dl.toFixed(2) + 's"/>';
            }).join('');

            /* 晕染滤镜：两次高斯模糊叠一点位移，边缘才像洇开而不是单纯糊 */
            var DEFS =
                '<defs>' +
                  '<filter id="nbInkBleed" x="-25%" y="-25%" width="150%" height="150%">' +
                    '<feGaussianBlur in="SourceGraphic" stdDeviation="3.6" result="b1"/>' +
                    '<feGaussianBlur in="SourceGraphic" stdDeviation="1.4" result="b2"/>' +
                    '<feMerge>' +
                      '<feMergeNode in="b1"/>' +
                      '<feMergeNode in="b1"/>' +
                      '<feMergeNode in="b2"/>' +
                    '</feMerge>' +
                  '</filter>' +
                '</defs>';

            var SEAL =
                '<svg class="nb-ink-seal" width="70" height="70" viewBox="0 0 70 70">' +
                  '<rect x="2" y="2" width="66" height="66" rx="4" fill="#8c2f23"/>' +
                  '<rect x="8" y="8" width="54" height="54" rx="2" fill="none" ' +
                    'stroke="#faf7f0" stroke-width="2.2"/>' +
                  '<g fill="#faf7f0" font-family="ui-monospace,Consolas,monospace" ' +
                    'font-size="19" font-weight="800" text-anchor="middle">' +
                    '<text x="23" y="31">N</text>' +
                    '<text x="47" y="31">B</text>' +
                    '<text x="23" y="55">\u9891</text>' +
                    '<text x="47" y="55">\u9053</text>' +
                  '</g>' +
                '</svg>';

            box.innerHTML =
                '<div class="nb-ink" data-root>' +
                  '<div class="nb-ink-inner">' +
                    '<div>' +
                      '<svg width="856" height="200" viewBox="0 0 856 200">' +
                        DEFS +
                        '<g>' + bleed + '</g>' +      /* 先洇开的墨 */
                        '<g>' + paths + '</g>' +      /* 再落下的笔锋 */
                      '</svg>' +
                      '<div class="nb-ink-cap">\u4E00\u7B14\u4E00\u753B \u00B7 \u5171 ' +
                        G.length + ' \u7B14</div>' +
                    '</div>' +
                    '<div class="nb-ink-side">' +
                      '<div class="t">\u58A8\u97F5</div>' +
                      '<div class="d">\u624B\u5199\u4F53<br>\u9010\u7B14\u63CF\u51FA</div>' +
                      '<div class="nb-ink-btns">' +
                        '<button class="nb-ink-btn" data-again>\u91CD\u5199</button>' +
                      '</div>' +
                    '</div>' +
                  '</div>' +
                  '<div style="position:absolute;right:34px;bottom:30px">' + SEAL + '</div>' +
                '</div>';

            var root = box.querySelector('[data-root]');

            function prep() {
                root.querySelectorAll('.st, .bl').forEach(function (p) {
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
       🧨 春节 · 点鞭炮
       画布上点哪儿炸哪儿；每隔一会儿天上掉红包，点中加分。
       ============================================================ */
    var FIRE = {
        mount: function (box) {
            box.innerHTML =
                '<div class="nb-fw" data-root>' +
                  '<canvas></canvas>' +
                  '<div class="nb-fw-top">' +
                    '<span>\u70B9\u71C3 <b data-boom>0</b></span>' +
                    '<span>\u7EA2\u5305 <b data-pkt>0</b></span>' +
                  '</div>' +
                  '<div class="nb-fw-side">' +
                    '<button class="nb-fw-btn" data-act="auto">\u81EA\u52A8\u653E</button>' +
                    '<button class="nb-fw-btn" data-act="clear">\u6E05\u7A7A</button>' +
                  '</div>' +
                  '<div class="nb-fw-hint">\u70B9\u4E00\u4E0B\u5C31\u653E\u4E00\u4E2A \u00B7 \u7EA2\u5305\u6389\u4E0B\u6765\u4E5F\u80FD\u70B9</div>' +
                '</div>';

            var root = box.querySelector('[data-root]');
            var cv = box.querySelector('canvas');
            var ctx = cv.getContext('2d');
            var boomEl = box.querySelector('[data-boom]');
            var pktEl = box.querySelector('[data-pkt]');

            var W = 0, H = 340, DPR = Math.min(window.devicePixelRatio || 1, 2);
            function resize() {
                W = root.clientWidth || 900;
                cv.width = W * DPR;
                cv.height = H * DPR;
                ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
            }

            var parts = [];      /* 火花 */
            var pkts = [];       /* 红包 */
            var booms = 0, caught = 0, auto = false, raf = null, last = 0;

            var COLORS = ['#ffd85e', '#ff9a3c', '#ff5c3c', '#fff4e0', '#ffe9a8'];

            function burst(x, y, n) {
                n = n || 46;
                for (var i = 0; i < n; i++) {
                    var a = Math.random() * Math.PI * 2;
                    var sp = 1.4 + Math.random() * 4.2;
                    parts.push({
                        x: x, y: y,
                        vx: Math.cos(a) * sp,
                        vy: Math.sin(a) * sp - 0.6,
                        life: 1, decay: 0.012 + Math.random() * 0.018,
                        r: 1.2 + Math.random() * 2.4,
                        c: COLORS[(Math.random() * COLORS.length) | 0]
                    });
                }
                booms++;
                boomEl.textContent = booms;
            }
            function dropPkt() {
                pkts.push({
                    x: 40 + Math.random() * Math.max(40, W - 80),
                    y: -40, vy: 0.7 + Math.random() * 0.9,
                    sway: Math.random() * Math.PI * 2, r: 15, life: 1
                });
            }
            function drawPkt(p) {
                ctx.save();
                ctx.translate(p.x, p.y);
                ctx.rotate(Math.sin(p.sway) * 0.18);
                /* 红包：红底金边 */
                ctx.fillStyle = '#c9182a';
                ctx.fillRect(-p.r, -p.r * 1.28, p.r * 2, p.r * 2.56);
                ctx.strokeStyle = '#ffd85e';
                ctx.lineWidth = 2;
                ctx.strokeRect(-p.r, -p.r * 1.28, p.r * 2, p.r * 2.56);
                /* 金元宝 */
                ctx.fillStyle = '#ffd85e';
                ctx.beginPath();
                ctx.arc(0, 0, p.r * 0.46, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();
            }

            function frame(t) {
                raf = requestAnimationFrame(frame);
                if (!last) last = t;
                var dt = Math.min(2.4, (t - last) / 16.7);
                last = t;

                /* 底：夜空般的深红，带一点金色光晕 */
                var g = ctx.createRadialGradient(W * .5, H * .9, 20, W * .5, H * .9, H * 1.3);
                g.addColorStop(0, 'rgba(255,216,94,.09)');
                g.addColorStop(1, 'rgba(0,0,0,0)');
                ctx.fillStyle = '#5e0d14';
                ctx.fillRect(0, 0, W, H);
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, W, H);

                /* 自动放 */
                if (auto && Math.random() < 0.035) {
                    burst(60 + Math.random() * (W - 120), 70 + Math.random() * (H - 180), 40);
                }
                /* 掉红包 */
                if (Math.random() < 0.0075) dropPkt();

                /* 火花 */
                for (var i = parts.length - 1; i >= 0; i--) {
                    var p = parts[i];
                    p.x += p.vx * dt; p.y += p.vy * dt;
                    p.vy += 0.075 * dt; p.vx *= 0.988;
                    p.life -= p.decay * dt;
                    if (p.life <= 0) { parts.splice(i, 1); continue; }
                    ctx.globalAlpha = Math.max(0, p.life);
                    ctx.fillStyle = p.c;
                    ctx.beginPath();
                    ctx.arc(p.x, p.y, p.r * p.life, 0, Math.PI * 2);
                    ctx.fill();
                }
                ctx.globalAlpha = 1;

                /* 红包 */
                for (var k = pkts.length - 1; k >= 0; k--) {
                    var q = pkts[k];
                    q.y += q.vy * dt;
                    q.sway += 0.03 * dt;
                    drawPkt(q);
                    if (q.y > H + 50) pkts.splice(k, 1);
                }
            }

            function hit(x, y) {
                /* 先看点没点中红包 */
                for (var i = pkts.length - 1; i >= 0; i--) {
                    var q = pkts[i];
                    if (Math.abs(x - q.x) < q.r + 8 && Math.abs(y - q.y) < q.r * 1.4 + 8) {
                        burst(q.x, q.y, 60);
                        pkts.splice(i, 1);
                        caught++;
                        pktEl.textContent = caught;
                        return;
                    }
                }
                burst(x, y);
            }

            cv.addEventListener('pointerdown', function (e) {
                var r = cv.getBoundingClientRect();
                hit(e.clientX - r.left, e.clientY - r.top);
            });
            box.querySelector('[data-act="auto"]').addEventListener('click', function () {
                auto = !auto;
                this.textContent = auto ? '\u505C\u4E0B' : '\u81EA\u52A8\u653E';
            });
            box.querySelector('[data-act="clear"]').addEventListener('click', function () {
                parts.length = 0; pkts.length = 0;
                booms = 0; caught = 0;
                boomEl.textContent = '0'; pktEl.textContent = '0';
            });

            resize();
            window.addEventListener('resize', resize);
            raf = requestAnimationFrame(frame);
            /* 开场先放一个，让人知道能点 */
            setTimeout(function () { burst(W * 0.5, H * 0.42, 54); }, 320);

            return function () {
                if (raf) cancelAnimationFrame(raf);
                window.removeEventListener('resize', resize);
            };
        }
    };

    /* ============================================================
       🌙 护眼 · 作息提醒
       不是装饰，是真提醒：显示当前时间、你已看了多久，
       到点给一句该歇歇了。用 performance 计时，切走不算。
       ============================================================ */
    var EYE = {
        mount: function (box) {
            var START = Date.now();
            var LIMIT_KEY = 'nb_eye_limit';
            var limit = 45;                       /* 默认 45 分钟提醒一次 */
            try {
                var lv = parseInt(localStorage.getItem(LIMIT_KEY) || '', 10);
                if (lv >= 15 && lv <= 180) limit = lv;
            } catch (e) {}

            box.innerHTML =
                '<div class="nb-eye">' +
                  '<div>' +
                    '<div class="nb-eye-clock" data-clock>--:--</div>' +
                    '<div class="nb-eye-date" data-date></div>' +
                  '</div>' +
                  '<div class="nb-eye-info">' +
                    '<div class="row"><span class="k">\u5DF2\u770B</span>' +
                      '<span class="v" data-watch>0 \u5206\u949F</span></div>' +
                    '<div class="row"><span class="k">\u63D0\u9192\u95F4\u9694</span>' +
                      '<span class="v" data-limit>' + limit + ' \u5206\u949F</span></div>' +
                    '<div class="row"><span class="k">\u5EFA\u8BAE</span>' +
                      '<span class="v" data-advice>\u6B63\u5E38</span></div>' +
                    '<div class="nb-eye-tip" data-tip></div>' +
                    '<div class="nb-eye-btns">' +
                      '<button class="nb-eye-btn" data-act="15">15\u5206</button>' +
                      '<button class="nb-eye-btn" data-act="45">45\u5206</button>' +
                      '<button class="nb-eye-btn" data-act="90">90\u5206</button>' +
                      '<button class="nb-eye-btn" data-act="reset">\u91CD\u8BA1</button>' +
                    '</div>' +
                  '</div>' +
                '</div>';

            var clockEl = box.querySelector('[data-clock]');
            var dateEl = box.querySelector('[data-date]');
            var watchEl = box.querySelector('[data-watch]');
            var limitEl = box.querySelector('[data-limit]');
            var adviceEl = box.querySelector('[data-advice]');
            var tipEl = box.querySelector('[data-tip]');

            var WEEK = ['\u65E5', '\u4E00', '\u4E8C', '\u4E09', '\u56DB', '\u4E94', '\u516D'];

            function two(n) { return (n < 10 ? '0' : '') + n; }

            function render() {
                var d = new Date();
                clockEl.textContent = two(d.getHours()) + ':' + two(d.getMinutes()) +
                                      ':' + two(d.getSeconds());
                dateEl.textContent = d.getFullYear() + ' \u5E74 ' + (d.getMonth() + 1) + ' \u6708 ' +
                                     d.getDate() + ' \u65E5 \u00B7 \u5468' + WEEK[d.getDay()];

                var mins = Math.floor((Date.now() - START) / 60000);
                watchEl.textContent = mins + ' \u5206\u949F';

                var h = d.getHours();
                var late = (h >= 23 || h < 6);
                var over = mins >= limit;

                if (over) {
                    adviceEl.textContent = '\u8BE5\u6B47\u4E86';
                    tipEl.className = 'nb-eye-tip warn';
                    tipEl.textContent = '\u4F60\u5DF2\u7ECF\u770B\u4E86 ' + mins +
                        ' \u5206\u949F\u3002\u8D77\u8EAB\u8D70\u4E24\u6B65\u3001\u770B\u770B\u7A97\u5916\u8FDC\u5904\u5427 \u2014\u2014 ' +
                        '\u773C\u775B\u6BD4\u7AD9\u91CC\u7684\u4EFB\u4F55\u4E1C\u897F\u90FD\u91CD\u8981\u3002';
                } else if (late) {
                    adviceEl.textContent = '\u8BE5\u7761\u4E86';
                    tipEl.className = 'nb-eye-tip warn';
                    tipEl.textContent = '\u8FD9\u4E2A\u70B9\u8FD8\u5728\u5237\u7AD9\u2026\u2026' +
                        '\u660E\u5929\u7684\u4F60\u4F1A\u611F\u8C22\u73B0\u5728\u53BB\u7761\u7684\u4F60\u3002';
                } else {
                    adviceEl.textContent = '\u6B63\u5E38';
                    tipEl.className = 'nb-eye-tip';
                    tipEl.textContent = '\u8FD9\u4E2A\u4E3B\u9898\u628A\u5BF9\u6BD4\u5EA6\u538B\u5230\u4E86\u6700\u4F4E\u3001' +
                        '\u5173\u6389\u4E86\u53D1\u5149\u548C\u6E10\u53D8\uff0c\u665A\u4E0A\u770B\u4E0D\u523A\u773C\u3002' +
                        '\u6BCF ' + limit + ' \u5206\u949F\u63D0\u9192\u4E00\u6B21\u3002';
                }
            }

            box.querySelectorAll('[data-act]').forEach(function (b) {
                b.addEventListener('click', function () {
                    var a = b.dataset.act;
                    if (a === 'reset') { START = Date.now(); }
                    else {
                        limit = parseInt(a, 10);
                        limitEl.textContent = limit + ' \u5206\u949F';
                        try { localStorage.setItem(LIMIT_KEY, String(limit)); } catch (e) {}
                    }
                    render();
                });
            });

            render();
            var t = setInterval(render, 1000);
            return function () { clearInterval(t); };
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
        spring: {
            head: '\uD83E\uDDE8 \u70B9\u97AD\u70AE <i>\u00B7 \u70B9\u54EA\u513F\u70B8\u54EA\u513F</i>',
            mount: function (box) { return FIRE.mount(box); }
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
