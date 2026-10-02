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

        /* ---------- 🌃 赛博朋克 · 霓虹灯牌生成器 ---------- */
        '.nb-neon{padding:34px 32px 40px;border-radius:12px;',
        '  background:linear-gradient(170deg,#180a2c,#0e0519 60%,#150826);',
        '  border:1px solid rgba(255,46,166,.28);',
        '  box-shadow:inset 0 0 44px -24px rgba(255,46,166,.8);}',
        '.nb-neon-stage{position:relative;display:flex;align-items:center;justify-content:center;',
        '  min-height:180px;padding:26px 18px;border-radius:8px;',
        '  background:radial-gradient(620px 270px at 50% 50%,rgba(255,46,166,.1),transparent 70%),#0b0518;',
        '  border:1px solid rgba(255,46,166,.18);overflow:hidden;}',
        '.nb-neon-stage::before{content:"";position:absolute;inset:0;pointer-events:none;',
        '  background-image:repeating-linear-gradient(0deg,rgba(255,255,255,.022) 0 1px,transparent 1px 26px),',
        '  repeating-linear-gradient(90deg,rgba(255,255,255,.022) 0 1px,transparent 1px 52px);}',
        '.nb-neon-text{position:relative;font-weight:800;letter-spacing:.08em;text-align:center;',
        '  font-family:ui-monospace,Consolas,"Courier New",monospace;',
        '  white-space:pre-wrap;word-break:break-word;line-height:1.3;transition:color .2s;}',
        '.nb-neon-text.on{color:#fff;text-shadow:0 0 4px #fff,0 0 11px var(--nc),',
        '  0 0 22px var(--nc),0 0 42px var(--nc),0 0 76px var(--nc);}',
        '.nb-neon-text.off{color:#5b4a6b;text-shadow:none;}',
        '.nb-neon-text.flicker.on{animation:nbFlick 4.2s steps(1,end) infinite;}',
        '@keyframes nbFlick{0%,86%,100%{opacity:1;}87%{opacity:.35;}88%{opacity:1;}',
        '  91%{opacity:.5;}92%{opacity:1;}95%{opacity:.2;}96%{opacity:1;}}',
        '.nb-neon-ctl{display:grid;grid-template-columns:1fr auto;gap:22px;align-items:end;',
        '  margin-top:22px;}',
        '.nb-neon-field{display:flex;flex-direction:column;gap:7px;}',
        '.nb-neon-field label{font-size:.68rem;letter-spacing:2px;color:#8a6aa8;}',
        '.nb-neon-field input[type=text]{padding:10px 13px;border-radius:3px;',
        '  background:rgba(23,10,43,.85);border:1px solid rgba(255,46,166,.35);',
        '  color:#f6e9ff;font-family:inherit;font-size:.9rem;outline:none;}',
        '.nb-neon-field input[type=text]:focus{border-color:#ff2ea6;}',
        '.nb-neon-sw{display:flex;gap:7px;}',
        '.nb-neon-sw button{width:26px;height:26px;border-radius:50%;cursor:pointer;',
        '  border:2px solid rgba(255,255,255,.18);padding:0;}',
        '.nb-neon-sw button.on{border-color:#fff;transform:scale(1.13);}',
        '.nb-neon-row{display:flex;gap:18px;align-items:center;flex-wrap:wrap;margin-top:18px;}',
        '.nb-neon-size{display:flex;align-items:center;gap:9px;font-size:.68rem;color:#8a6aa8;}',
        '.nb-neon-size input{width:118px;accent-color:#ff2ea6;}',
        '.nb-neon-btns{display:flex;gap:8px;margin-top:20px;flex-wrap:wrap;}',
        '.nb-neon-btn{padding:8px 15px;border-radius:3px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1.5px;background:rgba(255,46,166,.16);',
        '  color:#ff8ecb;border:1px solid rgba(255,46,166,.45);}',
        '.nb-neon-btn:hover{background:rgba(255,46,166,.32);}',
        '.nb-neon-btn.on{background:#ff2ea6;color:#fff2fc;border-color:#ff77a8;}',
        '.nb-neon-hint{margin-top:14px;font-size:.7rem;letter-spacing:1px;color:#7a5c94;}',
        '@media(max-width:820px){.nb-neon-ctl{grid-template-columns:1fr;}}',
        '@media(prefers-reduced-motion:reduce){.nb-neon-text.flicker.on{animation:none;}}',
        /* ---------- 🌙 护眼 · 20-20-20 计时器 ---------- */
        '.nb-eye{padding:36px 34px 40px;border-radius:12px;background:#dad3c4;',
        '  border:1px solid rgba(58,54,48,.16);}',
        '.nb-eye-main{display:grid;grid-template-columns:200px 1fr;gap:40px;align-items:center;}',
        '.nb-eye-ring{position:relative;width:200px;height:200px;}',
        '.nb-eye-ring svg{display:block;transform:rotate(-90deg);}',
        '.nb-eye-ring .track{fill:none;stroke:rgba(58,54,48,.14);stroke-width:11;}',
        '.nb-eye-ring .bar{fill:none;stroke:#6b5a3e;stroke-width:11;stroke-linecap:round;',
        '  transition:stroke-dashoffset .9s linear,stroke .4s;}',
        '.nb-eye-ring.rest .bar{stroke:#7a8a55;}',
        '.nb-eye-face{position:absolute;inset:0;display:flex;flex-direction:column;',
        '  align-items:center;justify-content:center;text-align:center;}',
        '.nb-eye-time{font-size:2.5rem;font-weight:200;letter-spacing:2px;color:#3a3630;',
        '  font-variant-numeric:tabular-nums;line-height:1;}',
        '.nb-eye-phase{margin-top:9px;font-size:.72rem;letter-spacing:3px;color:#7a7266;}',
        '.nb-eye-info .row{display:flex;justify-content:space-between;gap:24px;',
        '  padding:10px 0;border-bottom:1px solid rgba(58,54,48,.12);font-size:.82rem;}',
        '.nb-eye-info .row:last-child{border-bottom:none;}',
        '.nb-eye-info .k{color:#7a7266;letter-spacing:1px;}',
        '.nb-eye-info .v{color:#3a3630;font-weight:700;font-variant-numeric:tabular-nums;}',
        '.nb-eye-big{padding:14px 18px;border-radius:6px;margin-bottom:16px;',
        '  background:rgba(122,138,85,.16);border-left:3px solid #7a8a55;',
        '  font-size:.9rem;line-height:1.85;color:#3f4a2c;font-weight:600;}',
        '.nb-eye-big.work{background:rgba(107,90,62,.12);border-left-color:#6b5a3e;',
        '  color:#524c43;font-weight:400;}',
        '.nb-eye-btns{display:flex;gap:8px;margin-top:18px;flex-wrap:wrap;}',
        '.nb-eye-btn{padding:8px 15px;border-radius:2px;cursor:pointer;font-family:inherit;',
        '  font-size:.72rem;letter-spacing:1px;background:#6b5a3e;color:#e0d9cb;border:none;}',
        '.nb-eye-btn:hover{background:#544730;}',
        '.nb-eye-btn.ghost{background:transparent;color:#6b5a3e;',
        '  border:1px solid rgba(107,90,62,.45);}',
        '.nb-eye-btn.ghost:hover{background:rgba(107,90,62,.14);}',
        '.nb-eye-tip{margin-top:16px;font-size:.76rem;line-height:1.95;color:#6b6459;}',
        '.nb-eye-tip b{color:#524c43;}',
        '@media(max-width:860px){.nb-eye-main{grid-template-columns:1fr;justify-items:center;}}',



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
        '.nb-ink .gl-halo{fill:none;stroke:#3a3228;stroke-width:11;opacity:.24;',
        '  stroke-linejoin:round;}',
        '.nb-ink .gl-halo2{fill:none;stroke:#5a4d3c;stroke-width:20;opacity:.15;',
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

            /* ---------- 毛边噪声 ----------
               三层不同频率的正弦叠加，近似分形噪声。
               单频会抖成规则锯齿（假），三层叠加才像纸纤维的毛边。 */
            function fiber(s, seed) {
                return Math.sin(s * 0.27 + seed * 1.7) * 0.50
                     + Math.sin(s * 0.71 + seed * 3.1) * 0.31
                     + Math.sin(s * 1.83 + seed * 5.3) * 0.19;
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
                step = step || Math.max(0.9, L / 110);   /* 采密一点，毛边才有细节 */

                var left = [], right = [], s;
                var seed = outline._seed = (outline._seed || 0) + 1;
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

                    /* 毛边：起笔和收笔处收敛，中段最明显 ——
                       真实毛笔的锋尖是干净的，毛边在中段腹部。 */
                    var amp = Math.sin(Math.PI * Math.pow(t, 0.75));
                    var n = fiber(s * 0.42, seed);

                    hw *= 1 + n * 0.09 * amp;                   /* 宽度抖 ±9% */

                    /* 点位也轻微游走，边缘就不是光滑曲线了 */
                    var jitter = fiber(s * 0.31 + 40, seed + 11) * w * 0.05 * amp;
                    var px = p.x + nx * jitter;
                    var py = p.y + ny * jitter;

                    left.push([px + nx * hw, py + ny * hw]);
                    right.push([px - nx * hw, py - ny * hw]);
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
       赛博朋克 · 霓虹灯牌生成器
       输入文字实时做成霓虹招牌，可换色、调字号、开关闪烁。
       （原本这里是个只会抖的标题，不算内容，换掉。）
       ============================================================ */
    var NEON = {
        mount: function (box) {
            var COLORS = [
                { c: '#ff2ea6', n: '\u54C1\u7EA2' },
                { c: '#00e5ff', n: '\u9752\u84DD' },
                { c: '#a855f7', n: '\u7D2B' },
                { c: '#39ff88', n: '\u7EFF' },
                { c: '#ffb020', n: '\u7425\u73C0' }
            ];
            var KEY = 'nb_neon_text';
            var txt = 'NB \u9891\u9053';
            try { txt = localStorage.getItem(KEY) || txt; } catch (e) {}

            box.innerHTML =
                '<div class="nb-neon">' +
                  '<div class="nb-neon-stage">' +
                    '<div class="nb-neon-text on" data-txt></div>' +
                  '</div>' +
                  '<div class="nb-neon-ctl">' +
                    '<div class="nb-neon-field">' +
                      '<label>\u706F\u724C\u6587\u5B57</label>' +
                      '<input type="text" maxlength="24" data-input>' +
                    '</div>' +
                    '<div class="nb-neon-field">' +
                      '<label>\u706F\u7BA1\u989C\u8272</label>' +
                      '<div class="nb-neon-sw" data-sw></div>' +
                    '</div>' +
                  '</div>' +
                  '<div class="nb-neon-row">' +
                    '<div class="nb-neon-size">\u5B57\u53F7' +
                      '<input type="range" min="26" max="86" value="54" data-size></div>' +
                  '</div>' +
                  '<div class="nb-neon-btns">' +
                    '<button class="nb-neon-btn on" data-act="power">\u5F00\u706F</button>' +
                    '<button class="nb-neon-btn on" data-act="flicker">\u63A5\u89E6\u4E0D\u826F</button>' +
                    '<button class="nb-neon-btn" data-act="rand">\u968F\u673A\u4E00\u53E5</button>' +
                  '</div>' +
                  '<div class="nb-neon-hint">\u6539\u5B57\u3001\u6362\u8272\u3001\u62D6\u6ED1\u5757 \u00B7 \u5168\u90E8\u5B9E\u65F6\u751F\u6548</div>' +
                '</div>';

            var textEl = box.querySelector('[data-txt]');
            var inputEl = box.querySelector('[data-input]');
            var swEl = box.querySelector('[data-sw]');
            var sizeEl = box.querySelector('[data-size]');
            var powerBtn = box.querySelector('[data-act="power"]');
            var flickBtn = box.querySelector('[data-act="flicker"]');

            var color = COLORS[0].c, on = true, flicker = true;

            COLORS.forEach(function (o, i) {
                var b = document.createElement('button');
                b.type = 'button';
                b.style.background = o.c;
                b.title = o.n;
                if (i === 0) b.classList.add('on');
                b.addEventListener('click', function () {
                    color = o.c;
                    swEl.querySelectorAll('button').forEach(function (x) {
                        x.classList.toggle('on', x === b);
                    });
                    paint();
                });
                swEl.appendChild(b);
            });

            var LINES = ['NB \u9891\u9053', '\u70ED\u7231\u7406\u79D1', '\u4E0E\u4F5C\u6B7B\u540C\u884C',
                'NOBOOK', 'NB-CHANNEL', '\u865A\u62DF\u516C\u53F8', '\u540C\u5B66\u4EEC\u597D',
                '\u4ECA\u665A\u4E0D\u7761', '\u5168\u90E8\u4E0A\u5CB8', '1 + 1 = 2'];

            function paint() {
                textEl.textContent = inputEl.value || ' ';
                textEl.style.fontSize = sizeEl.value + 'px';
                textEl.style.setProperty('--nc', color);
                textEl.classList.toggle('on', on);
                textEl.classList.toggle('off', !on);
                textEl.classList.toggle('flicker', flicker && on);
            }

            inputEl.value = txt;
            inputEl.addEventListener('input', function () {
                paint();
                try { localStorage.setItem(KEY, inputEl.value); } catch (e) {}
            });
            sizeEl.addEventListener('input', paint);
            powerBtn.addEventListener('click', function () {
                on = !on;
                powerBtn.classList.toggle('on', on);
                powerBtn.textContent = on ? '\u5F00\u706F' : '\u5DF2\u5173\u706F';
                paint();
            });
            flickBtn.addEventListener('click', function () {
                flicker = !flicker;
                flickBtn.classList.toggle('on', flicker);
                flickBtn.textContent = flicker ? '\u63A5\u89E6\u4E0D\u826F' : '\u4E0D\u95EA';
                paint();
            });
            box.querySelector('[data-act="rand"]').addEventListener('click', function () {
                inputEl.value = LINES[(Math.random() * LINES.length) | 0];
                try { localStorage.setItem(KEY, inputEl.value); } catch (e) {}
                paint();
            });

            paint();
            return function () {};
        }
    };


    /* ============================================================
       护眼 · 20-20-20 计时器
       看屏幕 20 分钟 → 抬头看 6 米外 20 秒，眼科公认的做法。
       圆形进度环 + 到点切换 + 冷知识轮播。
       ============================================================ */
    var EYE = {
        mount: function (box) {
            var WORK_KEY = 'nb_eye_work';
            var work = 20;
            try {
                var w0 = parseInt(localStorage.getItem(WORK_KEY) || '', 10);
                if (w0 >= 10 && w0 <= 60) work = w0;
            } catch (e) {}

            var REST = 20;
            var R = 88, CIRC = 2 * Math.PI * R;

            box.innerHTML =
                '<div class="nb-eye">' +
                  '<div class="nb-eye-main">' +
                    '<div class="nb-eye-ring" data-ring>' +
                      '<svg width="200" height="200" viewBox="0 0 200 200">' +
                        '<circle class="track" cx="100" cy="100" r="' + R + '"/>' +
                        '<circle class="bar" cx="100" cy="100" r="' + R + '" ' +
                          'stroke-dasharray="' + CIRC.toFixed(1) + '" stroke-dashoffset="0"/>' +
                      '</svg>' +
                      '<div class="nb-eye-face">' +
                        '<div class="nb-eye-time" data-time>20:00</div>' +
                        '<div class="nb-eye-phase" data-phase>\u770B\u5C4F\u5E55</div>' +
                      '</div>' +
                    '</div>' +
                    '<div class="nb-eye-info">' +
                      '<div class="nb-eye-big work" data-big></div>' +
                      '<div class="row"><span class="k">\u672C\u8F6E\u5269\u4F59</span>' +
                        '<span class="v" data-left>20:00</span></div>' +
                      '<div class="row"><span class="k">\u5DF2\u4F11\u606F</span>' +
                        '<span class="v" data-done>0 \u6B21</span></div>' +
                      '<div class="row"><span class="k">\u5DE5\u4F5C\u65F6\u957F</span>' +
                        '<span class="v" data-work>20 \u5206\u949F</span></div>' +
                      '<div class="nb-eye-btns">' +
                        '<button class="nb-eye-btn" data-act="toggle">\u6682\u505C</button>' +
                        '<button class="nb-eye-btn ghost" data-act="skip">\u7ACB\u5373\u4F11\u606F</button>' +
                        '<button class="nb-eye-btn ghost" data-w="10">10\u5206</button>' +
                        '<button class="nb-eye-btn ghost" data-w="20">20\u5206</button>' +
                        '<button class="nb-eye-btn ghost" data-w="40">40\u5206</button>' +
                        '<button class="nb-eye-btn ghost" data-act="reset">\u91CD\u7F6E</button>' +
                      '</div>' +
                      '<div class="nb-eye-tip" data-tip></div>' +
                    '</div>' +
                  '</div>' +
                '</div>';

            var ringEl = box.querySelector('[data-ring]');
            var barEl = box.querySelector('.bar');
            var timeEl = box.querySelector('[data-time]');
            var phaseEl = box.querySelector('[data-phase]');
            var leftEl = box.querySelector('[data-left]');
            var doneEl = box.querySelector('[data-done]');
            var workEl = box.querySelector('[data-work]');
            var bigEl = box.querySelector('[data-big]');
            var tipEl = box.querySelector('[data-tip]');
            var toggleBtn = box.querySelector('[data-act="toggle"]');

            var TIPS = [
                '\u773C\u775B\u770B\u8FDC\u5904\u65F6\u776B\u72B6\u808C\u4F1A\u653E\u677E\uff0c\u770B\u8FD1\u5904\u65F6' +
                '\u4E00\u76F4\u7EF7\u7740 \u2014\u2014 \u8FD9\u5C31\u662F 20-20-20 \u7684\u9053\u7406\u3002',
                '\u5E72\u773C\u7684\u4E3B\u56E0\u4E0D\u662F\u770B\u5C4F\u5E55\uff0c\u662F\u76EF\u7740\u5C4F\u5E55\u65F6' +
                '\u7728\u773C\u6B21\u6570\u4F1A\u51CF\u5230\u4E00\u534A\u4EE5\u4E0B\u3002',
                '\u5C4F\u5E55\u6BD4\u73AF\u5883\u4EAE\u5F88\u591A\u65F6\u773C\u775B\u6700\u7D2F\uff0c' +
                '\u5F00\u706F\u6BD4\u8C03\u6697\u5C4F\u5E55\u7BA1\u7528\u3002',
                '\u8DDD\u79BB\u5C4F\u5E55 50\u201470 \u5398\u7C73\uff08\u4E00\u81C2\u957F\uff09' +
                '\u6BD4\u4EC0\u4E48\u62A4\u773C\u8BBE\u7F6E\u90FD\u6709\u6548\u3002',
                '\u6697\u73AF\u5883\u4E0B\u9AD8\u5BF9\u6BD4\u7684\u767D\u5E95\u9875\u9762\u6700\u523A\u773C \u2014\u2014 ' +
                '\u8FD9\u4E2A\u4E3B\u9898\u5C31\u662F\u4E3A\u8FD9\u4E2A\u505A\u7684\u3002'
            ];
            var tipIdx = 0;

            var phase = 'work';
            var left = work * 60;
            var done = 0;
            var paused = false;
            var timer = null, tipTimer = null;

            function fmt(sec) {
                var m = Math.floor(sec / 60), s = sec % 60;
                return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
            }
            function paint() {
                var total = (phase === 'rest') ? REST : work * 60;
                var ratio = total > 0 ? Math.max(0, left) / total : 0;
                barEl.style.strokeDashoffset = (CIRC * (1 - ratio)).toFixed(1);
                ringEl.classList.toggle('rest', phase === 'rest');

                timeEl.textContent = fmt(Math.max(0, left));
                leftEl.textContent = fmt(Math.max(0, left));

                if (phase === 'rest') {
                    phaseEl.textContent = '\u4F11\u606F\u4E2D';
                    bigEl.className = 'nb-eye-big';
                    bigEl.textContent = '\u62AC\u5934\u770B 6 \u7C73\u5916 \u00B7 ' +
                        '\u770B\u7A97\u5916\u3001\u770B\u5929\u82B1\u677F\u3001\u770B\u8FDC\u5904\u7684\u6811';
                    timeEl.style.color = '#3f4a2c';
                } else {
                    phaseEl.textContent = paused ? '\u5DF2\u6682\u505C' : '\u770B\u5C4F\u5E55';
                    bigEl.className = 'nb-eye-big work';
                    bigEl.textContent = '\u6BCF ' + work + ' \u5206\u949F\u62AC\u5934\u770B 6 \u7C73\u5916 20 \u79D2 \u00B7 ' +
                        '\u773C\u775B\u6BD4\u7AD9\u91CC\u4EFB\u4F55\u4E1C\u897F\u90FD\u91CD\u8981';
                    timeEl.style.color = '#3a3630';
                }
                doneEl.textContent = done + ' \u6B21';
                workEl.textContent = work + ' \u5206\u949F';
                toggleBtn.textContent = paused ? '\u7EE7\u7EED' : '\u6682\u505C';
            }
            function tick() {
                if (paused) return;
                left--;
                if (left <= 0) {
                    if (phase === 'work') {
                        phase = 'rest';
                        left = REST;
                        /* 顺便闪一下标签页标题，切到别的页也能注意到 */
                        try {
                            var old = document.title;
                            document.title = '\u23F0 \u8BE5\u4F11\u606F\u4E86 \u00B7 ' + old;
                            setTimeout(function () { document.title = old; }, 20000);
                        } catch (e) {}
                    } else {
                        phase = 'work';
                        left = work * 60;
                        done++;
                        tipIdx = (tipIdx + 1) % TIPS.length;
                        tipEl.innerHTML = '<b>\u51B7\u77E5\u8BC6</b> \u00B7 ' + TIPS[tipIdx];
                    }
                }
                paint();
            }

            box.querySelector('[data-act="toggle"]').addEventListener('click', function () {
                paused = !paused; paint();
            });
            box.querySelector('[data-act="skip"]').addEventListener('click', function () {
                phase = 'rest'; left = REST; paused = false; paint();
            });
            box.querySelector('[data-act="reset"]').addEventListener('click', function () {
                phase = 'work'; left = work * 60; paused = false; paint();
            });
            box.querySelectorAll('[data-w]').forEach(function (b) {
                b.addEventListener('click', function () {
                    work = parseInt(b.dataset.w, 10);
                    try { localStorage.setItem(WORK_KEY, String(work)); } catch (e) {}
                    phase = 'work'; left = work * 60; paused = false; paint();
                });
            });

            tipEl.innerHTML = '<b>\u51B7\u77E5\u8BC6</b> \u00B7 ' + TIPS[0];
            tipTimer = setInterval(function () {
                tipIdx = (tipIdx + 1) % TIPS.length;
                tipEl.innerHTML = '<b>\u51B7\u77E5\u8BC6</b> \u00B7 ' + TIPS[tipIdx];
            }, 26000);

            paint();
            timer = setInterval(tick, 1000);
            return function () {
                if (timer) clearInterval(timer);
                if (tipTimer) clearInterval(tipTimer);
            };
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
            head: '\uD83C\uDF03 \u9713\u8679\u706F\u724C <i>\u00B7 \u6539\u5B57\u6362\u8272\u5B9E\u65F6\u770B</i>',
            mount: function (box) { return NEON.mount(box); }
        },
        ink: {
            head: '\uD83D\uDD8C\uFE0F \u6C34\u58A8\u5C71\u6C34 <i>\u00B7 \u9010\u7B14\u63CF\u51FA</i>',
            mount: function (box) { return INK.mount(box); }
        },
        eyecare: {
            head: '\uD83C\uDF19 \u4F5C\u606F\u63D0\u9192 <i>\u00B7 \u770B\u4E45\u4E86\u8BE5\u6B47歇</i>',
            mount: function (box) { return EYE.mount(box); }
        },
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
