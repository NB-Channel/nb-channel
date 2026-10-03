/* ============================================================
   NB频道 · 傅里叶齿轮绘图
   ------------------------------------------------------------
   原理：把任意一条闭合曲线看成一串复数点，做离散傅里叶变换（DFT），
        就得到一组旋转向量。每个向量（叫它本轮 / epicycle）以固定
        角速度转，首尾相接串起来，最后一个的笔尖就画出原曲线。

        在本例里，每个向量画成一个齿轮：
            半径 = 该频率分量的振幅
            齿数 = 该分量的频率（转一圈咬合几次）

   文字怎么变成点：
        用 canvas 把字画出来，扫像素找轮廓点，再用最近邻把它们串成
        一条闭合路径。这样中文英文都能取，不依赖字体轮廓数据。

   对外接口：
        NBFourier.mount(container)   渲染到容器里，返回卸载函数
   ============================================================ */
(function () {
    'use strict';

    var CSS_ID = 'nbFtCss';

    /* ============================================================
       1. 从文字取轮廓点
       ============================================================ */
    function pointsFromText(text, target) {
        target = target || 480;

        /* ---------- 1. 把字画出来 ---------- */
        var probe = document.createElement('canvas');
        probe.width = 900;
        probe.height = 320;
        var pc = probe.getContext('2d');
        var FONT = 'system-ui,-apple-system,"Microsoft YaHei",sans-serif';
        var size = 220;
        pc.font = '900 ' + size + 'px ' + FONT;
        pc.textAlign = 'center';
        pc.textBaseline = 'middle';
        var w = pc.measureText(text).width;
        if (w > probe.width - 60) {
            size = Math.floor(size * (probe.width - 60) / w);
        }
        pc.clearRect(0, 0, probe.width, probe.height);
        pc.font = '900 ' + size + 'px ' + FONT;
        pc.fillStyle = '#000';
        pc.fillText(text, probe.width / 2, probe.height / 2);

        var W = probe.width, H = probe.height;
        var img = pc.getImageData(0, 0, W, H).data;
        var solid = new Uint8Array(W * H);
        for (var i = 0; i < W * H; i++) {
            if (img[i * 4 + 3] > 128) solid[i] = 1;
        }

        /* ---------- 2. 连通域：把实心像素分组 ---------- */
        var label = new Int32Array(W * H).fill(-1);
        var comps = [];
        var stack = [];
        for (var p0 = 0; p0 < W * H; p0++) {
            if (!solid[p0] || label[p0] >= 0) continue;
            var id = comps.length;
            var cells = [];
            stack.length = 0;
            stack.push(p0);
            label[p0] = id;
            while (stack.length) {
                var q = stack.pop();
                cells.push(q);
                var qx = q % W, qy = (q - qx) / W;
                /* 四邻足够，八邻会把斜对角连成一片 */
                for (var d = 0; d < 4; d++) {
                    var nx = qx + (d === 0 ? 1 : d === 1 ? -1 : 0);
                    var ny = qy + (d === 2 ? 1 : d === 3 ? -1 : 0);
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    var r = ny * W + nx;
                    if (solid[r] && label[r] < 0) { label[r] = id; stack.push(r); }
                }
            }
            /* 太小的当作噪点扔掉 */
            if (cells.length >= 24) comps.push(cells);
            else comps.forEach(function () {});
        }
        if (!comps.length) return null;

        /* ---------- 3. 每个连通域单独描外轮廓 ----------
           Moore 邻域追踪：从最左上的像素起步，沿边界顺时针走一圈。 */
        function traceContour(cells, labelId) {
            /* 找起始点：该域里最上面那一行、最左边的像素 */
            var start = cells[0];
            cells.forEach(function (c) {
                var cy = (c / W) | 0, sy = (start / W) | 0;
                if (cy < sy || (cy === sy && c < start)) start = c;
            });

            var dirs = [[1, 0], [1, 1], [0, 1], [-1, 1],
                        [-1, 0], [-1, -1], [0, -1], [1, -1]];
            var pts = [];
            var cx = start % W, cy = (start / W) | 0;
            var sx = cx, sy = cy;
            var dir = 6;                     /* 从"上"开始找 */
            var guard = 0, maxSteps = cells.length * 8 + 400;

            do {
                pts.push([cx, cy]);
                var found = false;
                /* 从上一方向的下一个开始，顺时针找一个属于本域的像素 */
                for (var k = 0; k < 8; k++) {
                    var nd = (dir + 6 + k) % 8;   /* 回退一格再顺时针扫 */
                    var nx = cx + dirs[nd][0], ny = cy + dirs[nd][1];
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    if (label[ny * W + nx] === labelId) {
                        dir = nd;
                        cx = nx; cy = ny;
                        found = true;
                        break;
                    }
                }
                if (!found) break;
                if (++guard > maxSteps) break;
            } while (!(cx === sx && cy === sy) || pts.length < 4);

            return pts;
        }

        /* 各域的轮廓 + 重心，按 x 排序（从左到右） */
        var groups = [];
        comps.forEach(function (cells) {
            var pts = traceContour(cells, label[cells[0]]);
            if (pts.length < 12) return;
            var mx = 0, my = 0;
            pts.forEach(function (p) { mx += p[0]; my += p[1]; });
            mx /= pts.length; my /= pts.length;
            groups.push({ pts: pts, mx: mx, my: my, n: cells.length });
        });
        if (!groups.length) return null;

        groups.sort(function (a, b) { return a.mx - b.mx; });

        /* ---------- 4. 拼成一条序列并均匀重采样 ----------
           域与域之间必然有跳跃，但跳跃次数现在【等于域数】，
           不再像最近邻串链那样在区域之间反复乱跳。 */
        var all = [];
        groups.forEach(function (g) { all = all.concat(g.pts); });

        /* 去掉整体重心偏移，再缩放居中 */
        var cxAll = 0, cyAll = 0;
        all.forEach(function (p) { cxAll += p[0]; cyAll += p[1]; });
        cxAll /= all.length; cyAll /= all.length;
        var rel = all.map(function (p) { return [p[0] - cxAll, p[1] - cyAll]; });

        var out = [];
        var m = rel.length;
        for (var k2 = 0; k2 < target; k2++) {
            out.push(rel[Math.floor(k2 * m / target) % m]);
        }
        return out;
    }

    /* ============================================================
       2. 离散傅里叶变换
          返回按振幅从大到小排好的分量：
          { freq, amp, phase, re, im }
       ============================================================ */
    function dft(pts) {
        var N = pts.length;
        var out = [];
        /* 频率范围 -N/2 ~ N/2，正负都要（负频率表示反向旋转） */
        for (var f = -Math.floor(N / 2); f <= Math.floor(N / 2); f++) {
            var re = 0, im = 0;
            for (var i = 0; i < N; i++) {
                var t = 2 * Math.PI * f * i / N;
                var c = Math.cos(t), s = Math.sin(t);
                re += pts[i][0] * c + pts[i][1] * s;
                im += -pts[i][0] * s + pts[i][1] * c;
            }
            re /= N; im /= N;
            out.push({
                freq: f,
                re: re,
                im: im,
                amp: Math.hypot(re, im),
                phase: Math.atan2(im, re)
            });
        }
        out.sort(function (a, b) { return b.amp - a.amp; });
        return out;
    }

    /* ============================================================
       3. 样式
       ============================================================ */
    var CSS = [
        '.nb-ft{position:relative;}',
        '.nb-ft-stage{position:relative;border-radius:12px;overflow:hidden;',
        '  background:radial-gradient(720px 420px at 50% 45%,rgba(0,229,255,.07),transparent 70%),#080d18;',
        '  border:1px solid rgba(0,229,255,.18);}',
        '.nb-ft-stage canvas{display:block;width:100%;height:440px;}',
        '.nb-ft-hud{position:absolute;left:14px;top:12px;font-size:.7rem;letter-spacing:1px;',
        '  color:rgba(160,200,240,.66);line-height:1.9;pointer-events:none;',
        '  font-family:ui-monospace,Consolas,monospace;}',
        '.nb-ft-hud b{color:#00e5ff;}',
        '.nb-ft-tools{margin-top:16px;display:flex;gap:10px;flex-wrap:wrap;align-items:center;}',
        '.nb-ft-tools input[type=text]{padding:9px 13px;border-radius:8px;min-width:190px;',
        '  background:rgba(0,0,0,.32);border:1px solid rgba(0,229,255,.28);',
        '  color:#dff3ff;font-family:inherit;font-size:.86rem;outline:none;}',
        '.nb-ft-tools input[type=text]:focus{border-color:#00e5ff;}',
        '.nb-ft-btn{padding:9px 15px;border-radius:8px;cursor:pointer;font-family:inherit;',
        '  font-size:.76rem;letter-spacing:1px;background:rgba(0,229,255,.14);',
        '  color:#7fe6ff;border:1px solid rgba(0,229,255,.36);}',
        '.nb-ft-btn:hover{background:rgba(0,229,255,.28);}',
        '.nb-ft-btn.on{background:#00e5ff;color:#04121a;border-color:#7fe6ff;}',
        '.nb-ft-preset{padding:7px 13px;border-radius:20px;cursor:pointer;font-size:.74rem;',
        '  background:rgba(255,255,255,.06);color:#9fb6d4;',
        '  border:1px solid rgba(255,255,255,.14);}',
        '.nb-ft-preset:hover{background:rgba(0,229,255,.16);color:#dff3ff;}',
        /* 50 个齿轮，网格排密一点，不然面板拉得老长 */
        '.nb-ft-gears{margin-top:18px;display:grid;gap:6px;',
        '  grid-template-columns:repeat(auto-fill,minmax(178px,1fr));',
        '  max-height:340px;overflow-y:auto;padding-right:4px;}',
        '.nb-ft-gears::-webkit-scrollbar{width:8px;}',
        '.nb-ft-gears::-webkit-scrollbar-thumb{background:rgba(0,229,255,.3);',
        '  border-radius:4px;}',
        '.nb-ft-gears::-webkit-scrollbar-track{background:rgba(255,255,255,.05);}',
        '.nb-ft-gear{display:flex;align-items:center;gap:7px;padding:6px 9px;border-radius:8px;',
        '  background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);',
        '  font-size:.68rem;color:#9fb6d4;}',
        '.nb-ft-gear.on{border-color:rgba(0,229,255,.42);background:rgba(0,229,255,.08);}',
        '.nb-ft-gear .sw{width:26px;height:15px;border-radius:8px;cursor:pointer;flex:0 0 auto;',
        '  background:rgba(255,255,255,.16);position:relative;transition:background .2s;}',
        '.nb-ft-gear .sw::after{content:"";position:absolute;top:2px;left:2px;width:11px;height:11px;',
        '  border-radius:50%;background:#8fa8c8;transition:transform .2s,background .2s;}',
        '.nb-ft-gear.on .sw{background:rgba(0,229,255,.45);}',
        '.nb-ft-gear.on .sw::after{transform:translateX(11px);background:#00e5ff;}',
        '.nb-ft-gear .lb{flex:1;min-width:0;line-height:1.5;}',
        '.nb-ft-gear .lb b{color:#dff3ff;font-family:ui-monospace,monospace;}',
        '.nb-ft-gear .lb i{font-style:normal;color:#7fe6ff;}',
        '.nb-ft-gear input[type=range]{width:100%;accent-color:#00e5ff;margin-top:3px;}',
        '.nb-ft-tip{margin-top:14px;font-size:.72rem;line-height:1.9;color:#7f93b0;}',
        '@media(max-width:820px){.nb-ft-stage canvas{height:320px;}}'
    ].join('\n');

    /* ============================================================
       4. 主体
       ============================================================ */
    function mount(host) {
        if (!document.getElementById(CSS_ID)) {
            var st = document.createElement('style');
            st.id = CSS_ID;
            st.textContent = CSS;
            document.head.appendChild(st);
        }

        host.innerHTML =
            '<div class="nb-ft">' +
              '<div class="nb-ft-stage">' +
                '<canvas></canvas>' +
                '<div class="nb-ft-hud" data-hud></div>' +
              '</div>' +
              '<div class="nb-ft-tools">' +
                '<input type="text" maxlength="14" data-text placeholder="输入文字，中英文都行">' +
                '<button class="nb-ft-btn on" data-act="play">暂停</button>' +
                '<button class="nb-ft-btn on" data-act="showgear">显示齿轮</button>' +
                '<button class="nb-ft-btn on" data-act="showpath">显示轨迹</button>' +
                '<span style="display:flex;align-items:center;gap:9px;font-size:.72rem;' +
                  'color:#7f93b0;letter-spacing:1px;margin-left:auto">' +
                  '齿轮数 <b data-gn style="color:#00e5ff;font-family:ui-monospace,monospace;' +
                    'min-width:30px;text-align:right">50</b>' +
                  '<input type="range" min="10" max="400" step="5" value="50" data-gears ' +
                    'style="width:170px;accent-color:#00e5ff">' +
                '</span>' +
              '</div>' +
              '<div class="nb-ft-tools">' +
                '<span style="font-size:.72rem;color:#7f93b0;letter-spacing:1px">预设</span>' +
                '<button class="nb-ft-preset" data-preset="N">N</button>' +
                '<button class="nb-ft-preset" data-preset="B">B</button>' +
                '<button class="nb-ft-preset" data-preset="π">π</button>' +
                '<button class="nb-ft-preset" data-preset="∞">∞</button>' +
                '<button class="nb-ft-preset" data-preset="★">★</button>' +
                '<button class="nb-ft-preset" data-preset="NB频道">NB频道</button>' +
                '<button class="nb-ft-preset" data-preset="NB-CHANNEL">NB-CHANNEL</button>' +
              '</div>' +
              '<div class="nb-ft-gears" data-gears></div>' +
              '<div class="nb-ft-tip">' +
                '每个齿轮 = 一个频率分量：<b>半径</b>是它的振幅，<b>齿数</b>是它的频率' +
                '（转一圈咬合几次）。所有齿轮首尾串起来，最外那个的笔尖就画出你输的字。' +
                '齿轮按振幅从大到小排 —— 前面的定大体形状，后面的补细节。' +
                '<b>单个字母</b>（N、B、π）50 个就够；' +
                '<b>整个单词或汉字</b>是多个互不相连的笔画块，块与块之间要跳跃，' +
                '跳跃的能量摊在所有频率上，得把齿轮拉到 200~400 才收得住。' +
                '画的时候区域之间会自动断开，不会拉出多余的直线。' +
              '</div>' +
            '</div>';

        var cv = host.querySelector('canvas');
        var ctx = cv.getContext('2d');
        var hudEl = host.querySelector('[data-hud]');
        var gearsEl = host.querySelector('[data-gears]');
        var textEl = host.querySelector('[data-text]');

        /* 自适应断笔：维护最近若干步的平均步长，
           只有明显超出（5 倍）才认为是区域之间的跳跃。
           固定像素阈值不行 —— 300 个齿轮时笔尖跑得飞快，
           正常笔画的距离也会超过阈值，把字切碎。 */
        var stepAvg = { sum: 0, n: 0, buf: [] };
        function isJump(d) {
            var K = 24;
            if (stepAvg.buf.length >= 8) {
                var avg = stepAvg.sum / stepAvg.n;
                if (avg > 0.5 && d > avg * 5) return true;
            }
            stepAvg.buf.push(d);
            stepAvg.sum += d;
            stepAvg.n++;
            if (stepAvg.buf.length > K) {
                stepAvg.sum -= stepAvg.buf.shift();
                stepAvg.n--;
            }
            return false;
        }
        function resetSteps() { stepAvg = { sum: 0, n: 0, buf: [] }; }

        var state = {
            playing: true,
            showGear: true,
            showPath: true,
            text: 'NB频道',
            comps: [],       /* 选中的分量 */
            pts: null,
            t: 0,
            path: [],
            W: 0, H: 0
        };

        var DPR = Math.min(window.devicePixelRatio || 1, 2);
        /* 齿轮数量可调。
           单个字母（一条闭合曲线）50 个就画得很准；
           多个字母/汉字是多个互不相连的区域，区域之间要"跳跃"，
           跳跃的能量摊在所有频率上，得几百个分量才收得住。
           所以做成滑块，默认 50，最多 400。 */
        var GEARM = { cur: 50, min: 10, max: 400 };

        /* ---------- 尺寸 ---------- */
        function resize() {
            var r = cv.getBoundingClientRect();
            state.W = r.width;
            state.H = r.height || 440;
            cv.width = state.W * DPR;
            cv.height = state.H * DPR;
            ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
        }

        /* ---------- 重建 ---------- */
        var seed = 20261003;
        function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }

        function rebuild() {
            var pts = pointsFromText(state.text || 'NB频道', 480);
            if (!pts) { hudEl.textContent = '取不到轮廓，换点内容试试'; return; }
            state.pts = pts;
            var all = dft(pts);
            /* 取振幅最大的前 10 个（跳过 freq=0 之外的直流项也别丢，它定中心） */
            var picked = all.slice(0, GEARM.cur);

            /* 缩放系数：让整体铺满画布 */
            var maxAmp = 0;
            picked.forEach(function (c) { maxAmp = Math.max(maxAmp, c.amp); });
            var minDim = Math.min(state.W || 900, state.H || 440);
            var k = (minDim * 0.34) / (maxAmp || 1);

            state.comps = picked.map(function (c, i) {
                return {
                    freq: c.freq,
                    amp: c.amp * k,
                    phase: c.phase,
                    /* 用户可调的半径系数，默认 1 */
                    scale: 1,
                    on: true,
                    idx: i
                };
            });

            /* 生成齿轮调节面板。几百个齿轮全渲染会卡，
               所以只列前 60 个，剩下的在 HUD 里报个数。 */
            gearsEl.innerHTML = '';
            var SHOWMAX = 60;
            var shown = state.comps.slice(0, SHOWMAX);
            if (state.comps.length > SHOWMAX) {
                var note = document.createElement('div');
                note.style.cssText = 'grid-column:1/-1;font-size:.7rem;color:#7f93b0;' +
                    'padding:6px 2px;line-height:1.7';
                note.textContent = '只列出振幅最大的前 ' + SHOWMAX + ' 个，' +
                    '另外 ' + (state.comps.length - SHOWMAX) + ' 个也在参与绘制（影响很小）';
                gearsEl.appendChild(note);
            }
            shown.forEach(function (c) {
                var row = document.createElement('div');
                row.className = 'nb-ft-gear on';
                row.innerHTML =
                    '<span class="sw"></span>' +
                    '<span class="lb">' +
                      (c.freq === 0
                        ? '直流 <b>0</b><i>（重心平移）</i>'
                        : '齿数 <b>' + Math.abs(c.freq) + '</b>' +
                          (c.freq < 0 ? '<i>（反转）</i>' : '')) +
                      ' · 半径 <i data-amp>' + Math.round(c.amp) + '</i>' +
                      '<input type="range" min="0" max="200" value="100" data-s>' +
                    '</span>';
                row.querySelector('.sw').addEventListener('click', function () {
                    c.on = !c.on;
                    row.classList.toggle('on', c.on);
                });
                var sl = row.querySelector('[data-s]');
                sl.addEventListener('input', function () {
                    c.scale = parseInt(sl.value, 10) / 100;
                    row.querySelector('[data-amp]').textContent = Math.round(c.amp * c.scale);
                });
                gearsEl.appendChild(row);
            });

            /* 先空转一圈把轨迹攒出来，否则刚切过来画布是空的，
               要盯着看 9 秒才出现字 */
            state.path = [];
            state.t = 0;
            resetSteps();
            prerun();
        }

        /* 不开动画，纯算一遍把 path 填满 */
        function prerun() {
            resetSteps();
            var steps = 420;
            for (var n = 0; n < steps; n++) {
                state.t = n / steps * 2 * Math.PI;
                var x = (state.W || 900) / 2, y = (state.H || 440) / 2;
                state.comps.forEach(function (c) {
                    if (!c.on) return;
                    var a = c.phase + c.freq * state.t;
                    x += c.amp * c.scale * Math.cos(a);
                    y += c.amp * c.scale * Math.sin(a);
                });
                var jp = false;
                if (state.path.length) {
                    var lp = state.path[state.path.length - 1];
                    jp = isJump(Math.hypot(x - lp[0], y - lp[1]));
                }
                state.path.push([x, y, jp]);
            }
            state.t = 0;
        }

        /* ---------- 画一帧 ---------- */
        function draw() {
            var W = state.W, H = state.H;
            if (!W || !H) return;

            ctx.fillStyle = 'rgba(8,13,24,.34)';        /* 拖尾 */
            ctx.fillRect(0, 0, W, H);

            var comps = state.comps.filter(function (c) { return c.on; });
            if (!comps.length) return;

            var cx = W / 2, cy = H / 2;
            var x = cx, y = cy;

            /* 齿轮 */
            if (state.showGear) {
                for (var i = 0; i < comps.length; i++) {
                    var c = comps[i];
                    var r = c.amp * c.scale;
                    var ang = c.phase + c.freq * state.t;
                    var nx = x + r * Math.cos(ang);
                    var ny = y + r * Math.sin(ang);

                    /* 圈 */
                    ctx.beginPath();
                    ctx.arc(x, y, r, 0, Math.PI * 2);
                    ctx.strokeStyle = 'rgba(0,229,255,' + Math.max(0.035, 0.3 - i * 0.004) + ')';
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    /* 齿：齿数就是这个分量的频率 —— 沿圆周点 n 个短齿 */
                    /* 齿数等于频率，但一个小圆上画几十个齿会糊成一片，
                       所以齿数封顶 48，而且半径小于 12 干脆不画齿。 */
                    var teeth = Math.min(Math.abs(c.freq), 48);
                    if (teeth >= 2 && r > 12) {
                        var tl = Math.min(7, r * 0.22);
                        ctx.strokeStyle = 'rgba(0,229,255,' + Math.max(0.07, 0.45 - i * 0.008) + ')';
                        ctx.lineWidth = 1.2;
                        ctx.beginPath();
                        for (var k = 0; k < teeth; k++) {
                            var ta = ang + k * 2 * Math.PI / teeth;
                            var ca = Math.cos(ta), sa = Math.sin(ta);
                            ctx.moveTo(x + ca * (r - tl), y + sa * (r - tl));
                            ctx.lineTo(x + ca * (r + tl * 0.35), y + sa * (r + tl * 0.35));
                        }
                        ctx.stroke();
                    }

                    /* 半径连线 */
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                    ctx.lineTo(nx, ny);
                    ctx.strokeStyle = 'rgba(127,230,255,.5)';
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    x = nx; y = ny;
                }
            } else {
                for (var j = 0; j < comps.length; j++) {
                    var c2 = comps[j];
                    var a2 = c2.phase + c2.freq * state.t;
                    x += c2.amp * c2.scale * Math.cos(a2);
                    y += c2.amp * c2.scale * Math.sin(a2);
                }
            }

            /* 笔尖 */
            ctx.beginPath();
            ctx.arc(x, y, 4, 0, Math.PI * 2);
            ctx.fillStyle = '#ffd85e';
            ctx.fill();

            /* 轨迹 */
            /* 记轨迹。相邻两点距离突然变大 = 笔尖在区域之间跳，
               标个 jump，画的时候断开，不然会拉出一条横贯的直线。 */
            var jmp = false;
            if (state.path.length) {
                var lastP = state.path[state.path.length - 1];
                jmp = isJump(Math.hypot(x - lastP[0], y - lastP[1]));
            }
            state.path.push([x, y, jmp]);
            if (state.path.length > 2600) state.path.shift();

            if (state.showPath && state.path.length > 1) {
                ctx.beginPath();
                ctx.moveTo(state.path[0][0], state.path[0][1]);
                for (var p = 1; p < state.path.length; p++) {
                    var q2 = state.path[p];
                    if (q2[2]) ctx.moveTo(q2[0], q2[1]);   /* 断点：另起一笔 */
                    else ctx.lineTo(q2[0], q2[1]);
                }
                ctx.strokeStyle = 'rgba(255,216,94,.9)';
                ctx.lineWidth = 1.7;
                ctx.lineJoin = 'round';
                ctx.stroke();
            }

            hudEl.innerHTML =
                '齿轮 <b>' + comps.length + '</b> / ' + state.comps.length +
                '<br>齿数 <b>' + (function () {
                    /* freq = 0 是直流分量（整体平移），没有齿，单列出来。
                       50 个齿轮的话这一串会撑爆，只列前 12 个。 */
                    var arr = comps.map(function (c) {
                        return c.freq === 0 ? '直流' : Math.abs(c.freq);
                    });
                    var head = arr.slice(0, 12).join(' · ');
                    return arr.length > 12 ? head + ' … (共 ' + arr.length + ' 个)'
                                           : head;
                })() + '</b>' +
                '<br>采样点 <b>' + (state.pts ? state.pts.length : 0) + '</b>';
        }

        /* ---------- 主循环 ---------- */
        var raf = null, last = 0;
        function loop(ts) {
            raf = requestAnimationFrame(loop);
            if (!last) last = ts;
            var dt = Math.min(64, ts - last);
            last = ts;
            if (state.playing) {
                /* 一圈大概 9 秒 */
                state.t += dt / 1000 * (2 * Math.PI / 9);
            }
            draw();
        }

        /* ---------- 交互 ---------- */
        host.querySelector('[data-act="play"]').addEventListener('click', function () {
            state.playing = !state.playing;
            this.textContent = state.playing ? '暂停' : '继续';
            this.classList.toggle('on', state.playing);
        });
        host.querySelector('[data-act="showgear"]').addEventListener('click', function () {
            state.showGear = !state.showGear;
            this.classList.toggle('on', state.showGear);
            state.path = [];
        });
        host.querySelector('[data-act="showpath"]').addEventListener('click', function () {
            state.showPath = !state.showPath;
            this.classList.toggle('on', state.showPath);
        });
        host.querySelectorAll('[data-preset]').forEach(function (b) {
            b.addEventListener('click', function () {
                textEl.value = b.dataset.preset;
                state.text = b.dataset.preset;
                resize();
                rebuild();
            });
        });
        var gearSlider = host.querySelector('[data-gears]');
        var gnEl = host.querySelector('[data-gn]');
        var gearDeb = null;
        gearSlider.addEventListener('input', function () {
            GEARM.cur = parseInt(gearSlider.value, 10);
            gnEl.textContent = GEARM.cur;
            /* 拖动时别每一像素都重算 DFT —— 那有 480 个点 × 几百个频率，很重 */
            clearTimeout(gearDeb);
            gearDeb = setTimeout(function () {
                state.path = [];
                rebuild();
            }, 260);
        });

        var deb = null;
        textEl.addEventListener('input', function () {
            clearTimeout(deb);
            deb = setTimeout(function () {
                state.text = textEl.value.slice(0, 14) || 'NB频道';
                resize();
                rebuild();
            }, 420);
        });
        window.addEventListener('resize', function () {
            clearTimeout(window.__ftR);
            window.__ftR = setTimeout(function () { resize(); rebuild(); }, 220);
        });

        /* ---------- 启动 ---------- */
        textEl.value = state.text;
        /* 等布局稳定再量尺寸 */
        setTimeout(function () {
            resize();
            rebuild();
            if (!raf) raf = requestAnimationFrame(loop);
        }, 60);

        return function () {
            if (raf) cancelAnimationFrame(raf);
        };
    }

    window.NBFourier = { mount: mount, pointsFromText: pointsFromText, dft: dft };
})();
