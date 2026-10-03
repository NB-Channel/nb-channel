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
        target = target || 32768;

        /* ---------- 1. 把字画出来 ---------- */
        /* 画布要够大 —— 边界像素越多，能支撑的采样点就越多。
           跟着采样点数走：轮廓像素不够时，多出来的点只能靠插值凑，
           FFT 出来的高频是假的。 */
        var pw = Math.min(4000, Math.max(1200, Math.round(Math.sqrt(target) * 15)));
        var probe = document.createElement('canvas');
        probe.width = pw;
        probe.height = Math.round(pw * 0.34);
        var pc = probe.getContext('2d');
        var FONT = 'system-ui,-apple-system,"Microsoft YaHei",sans-serif';
        var size = Math.round(probe.height * 0.72);
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

        /* 重采样。用线性插值而不是直接取整 —— 目标点数比轮廓点多的时候，
           直接取整会产生大量重复点，FFT 出来的高频是假的。 */
        var out = [];
        var m = rel.length;
        for (var k2 = 0; k2 < target; k2++) {
            var fp = k2 * m / target;
            var i0 = Math.floor(fp) % m;
            var i1 = (i0 + 1) % m;
            var fr = fp - Math.floor(fp);
            out.push([
                rel[i0][0] + (rel[i1][0] - rel[i0][0]) * fr,
                rel[i0][1] + (rel[i1][1] - rel[i0][1]) * fr
            ]);
        }
        return out;
    }

    /* ============================================================
       2. 离散傅里叶变换
          返回按振幅从大到小排好的分量：
          { freq, amp, phase, re, im }
       ============================================================ */
    /* 快速傅里叶变换（迭代版 radix-2 Cooley-Tukey）。
       朴素 DFT 是 O(N²)，8192 个点要 6700 万次运算，慢得不能看；
       FFT 是 O(N log N)，同样的点数只要十几万次。

       输入复数序列（实部 re、虚部 im，长度必须是 2 的幂），
       就地变换。约定和之前一致：结果要除以 N 做归一化。 */
    function fft(re, im) {
        var n = re.length;

        /* 位反转置换 */
        for (var i = 1, j = 0; i < n; i++) {
            var bit = n >> 1;
            for (; j & bit; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) {
                var tr = re[i]; re[i] = re[j]; re[j] = tr;
                var ti = im[i]; im[i] = im[j]; im[j] = ti;
            }
        }

        /* 蝶形运算 */
        for (var len = 2; len <= n; len <<= 1) {
            var half = len >> 1;
            var ang = -2 * Math.PI / len;
            var wr = Math.cos(ang), wi = Math.sin(ang);
            for (var st = 0; st < n; st += len) {
                var cr = 1, ci = 0;
                for (var k = 0; k < half; k++) {
                    var p = st + k, q = p + half;
                    var xr = re[q] * cr - im[q] * ci;
                    var xi = re[q] * ci + im[q] * cr;
                    re[q] = re[p] - xr; im[q] = im[p] - xi;
                    re[p] += xr;        im[p] += xi;
                    var ncr = cr * wr - ci * wi;
                    ci = cr * wi + ci * wr;
                    cr = ncr;
                }
            }
        }
    }

    /* 返回按振幅从大到小排好的分量：{ freq, amp, phase, re, im } */
    function dft(pts) {
        var N = pts.length;
        var re = new Float64Array(N);
        var im = new Float64Array(N);
        for (var i = 0; i < N; i++) { re[i] = pts[i][0]; im[i] = pts[i][1]; }

        fft(re, im);

        var out = [];
        var half = N >> 1;
        for (var f = 0; f < N; f++) {
            /* FFT 输出里，索引大于 N/2 的部分对应负频率 */
            var freq = f <= half ? f : f - N;
            var r = re[f] / N, m = im[f] / N;
            out.push({
                freq: freq,
                re: r,
                im: m,
                amp: Math.hypot(r, m),
                phase: Math.atan2(m, r)
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
                '<span style="display:flex;align-items:center;gap:8px;font-size:.72rem;' +
                  'color:#7f93b0;letter-spacing:1px;margin-left:auto;flex-wrap:wrap">' +
                  '采样点 <b data-sn style="color:#00e5ff;font-family:ui-monospace,monospace;' +
                    'min-width:50px;text-align:right">32768</b>' +
                  '<input type="range" min="10" max="16" step="1" value="15" data-samp ' +
                    'style="width:110px;accent-color:#00e5ff" title="2 的幂：1024 ~ 65536">' +
                  '<span style="opacity:.45">│</span>' +
                  '齿轮数 <b data-gn style="color:#00e5ff;font-family:ui-monospace,monospace;' +
                    'min-width:42px;text-align:right">50</b>' +
                  '<input type="range" min="10" max="10000" step="10" value="50" data-gears ' +
                    'style="width:140px;accent-color:#00e5ff">' +
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
                '跳跃的能量摊在所有频率上，得把齿轮拉到 300 以上才收得住' +
                '（最多 1000，再多画面变化就不明显了）。' +
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
            W: 0, H: 0,
            /* 绘制变换：把模型坐标映射到画布。prerun 量完包围盒后填好，
               一次到位，不用迭代改振幅。 */
            xf: { s: 1, cx: 0, cy: 0 }
        };

        var DPR = Math.min(window.devicePixelRatio || 1, 2);
        /* 齿轮数量可调。
           单个字母（一条闭合曲线）50 个就画得很准；
           多个字母/汉字是多个互不相连的区域，区域之间要"跳跃"，
           跳跃的能量摊在所有频率上，得几百个分量才收得住。
           所以做成滑块，默认 50，最多 400。 */
        /* 齿轮上限。采样点 32768（2 的幂，FFT 要求），
           能分出 32768 个独立频率，所以 10000 这个上限是真的能填满的。
           32768 点 FFT 约 16ms，拖动滑块也不会卡。 */
        var GEARM = { cur: 50, min: 10, max: 10000 };

        /* 采样点数（重采样目标）。必须是 2 的幂 —— FFT 的要求。
           范围 1024 ~ 65536，默认 32768。
           齿轮数不能超过采样点的一半（奈奎斯特），下面做了联动。 */
        var SAMPLEN = { cur: 32768, min: 1024, max: 65536 };

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
            var pts = pointsFromText(state.text || 'NB频道', SAMPLEN.cur);
            if (!pts) { hudEl.textContent = '取不到轮廓，换点内容试试'; return; }
            state.pts = pts;
            var t0 = (window.performance || Date).now();
            var all = dft(pts);
            var ld = (window.performance || Date).now() - t0;
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
                /* 松手后按新的包围盒重新适配一次，别让图形跑出画布 */
                sl.addEventListener('change', function () {
                    state.path = [];
                    resetSteps();
                    prerun();
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

        /* prerun：真的跑一圈，把每个时刻的笔尖位置记下来，
           量【这些点】的包围盒（不是"所有齿轮各自能达到的最远处"——
           那个范围大得多，会让字被算得很小）。
           量完清空轨迹，动画照样从头画。 */
        function prerun() {
            var W = state.W || 900, H = state.H || 440;
            var S = 4096;   /* 采样密一点，包围盒量的才准 */
            var minX = Infinity, maxX = -Infinity;
            var minY = Infinity, maxY = -Infinity;

            for (var n = 0; n < S; n++) {
                var t = n / S * 2 * Math.PI;
                var x = 0, y = 0;
                /* 沿齿轮链累加 —— 这才是笔尖真正的位置 */
                for (var i = 0; i < state.comps.length; i++) {
                    var c = state.comps[i];
                    if (!c.on) continue;
                    var ang = c.phase + c.freq * t;
                    x += c.amp * c.scale * Math.cos(ang);
                    y += c.amp * c.scale * Math.sin(ang);
                }
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
            }

            if (isFinite(minX) && maxX > minX && maxY > minY) {
                var PAD = 0.92;
                var sc = Math.min((W * PAD) / (maxX - minX), (H * PAD) / (maxY - minY));
                if (!isFinite(sc) || sc <= 0) sc = 1;
                state.xf = {
                    s: sc,
                    cx: (minX + maxX) / 2,
                    cy: (minY + maxY) / 2
                };
            } else {
                state.xf = { s: 1, cx: 0, cy: 0 };
            }

            window.__ftXf = {
                s: state.xf.s, cx: state.xf.cx, cy: state.xf.cy,
                W: W, H: H,
                modelW: maxX - minX, modelH: maxY - minY,
                nComp: state.comps.length
            };

            /* 清空轨迹、时间归零 —— 让动画从头画 */
            state.path = [];
            state.t = 0;
            resetSteps();
        }

        /* ---------- 画一帧 ---------- */
        function draw() {
            var W = state.W, H = state.H;
            if (!W || !H) return;

            ctx.fillStyle = 'rgba(8,13,24,.34)';        /* 拖尾 */
            ctx.fillRect(0, 0, W, H);

            var comps = state.comps.filter(function (c) { return c.on; });
            if (!comps.length) return;

            /* 模型坐标 → 画布坐标 */
            var xf = state.xf;
            function toScreen(mx, my) {
                return [W / 2 + (mx - xf.cx) * xf.s,
                        H / 2 + (my - xf.cy) * xf.s];
            }
            var x = 0, y = 0;      /* 模型坐标，从原点起算 */

            /* 齿轮 */
            if (state.showGear) {
                /* 全局最要紧的一处：
                   笔尖位置必须把【所有】齿轮都累加进去 —— 那只是几十万次
                   乘加，很便宜，而且细节全靠那些小半径的高频分量；
                   真正贵的是画圈和画齿，那个才限制数量。

                   之前两者写在同一个循环里被 drawN 一起卡住，
                   于是 10000 个齿轮只有前 220 个起作用，细节全丢。 */
                var drawN = Math.min(comps.length, 220);   /* 只管画不画圈 */
                var drawTeeth = comps.length <= 120;

                for (var i = 0; i < comps.length; i++) {
                    var c = comps[i];
                    var r = c.amp * c.scale;
                    var ang = c.phase + c.freq * state.t;
                    var nx = x + r * Math.cos(ang);
                    var ny = y + r * Math.sin(ang);
                    var showThis = i < drawN;

                    if (showThis) {

                    /* 转到屏幕坐标再画 */
                    var sp = toScreen(x, y);
                    var sr = r * xf.s;

                    ctx.beginPath();
                    ctx.arc(sp[0], sp[1], sr, 0, Math.PI * 2);
                    ctx.strokeStyle = 'rgba(0,229,255,' + Math.max(0.03, 0.3 - i * 0.0022) + ')';
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    /* 齿：齿数就是这个分量的频率 —— 沿圆周点 n 个短齿 */
                    /* 齿数等于频率，但一个小圆上画几十个齿会糊成一片，
                       所以齿数封顶 48，而且半径小于 12 干脆不画齿。 */
                    var teeth = Math.min(Math.abs(c.freq), 48);
                    if (drawTeeth && teeth >= 2 && sr > 12) {
                        var tl = Math.min(7, sr * 0.22);
                        ctx.strokeStyle = 'rgba(0,229,255,' + Math.max(0.07, 0.45 - i * 0.008) + ')';
                        ctx.lineWidth = 1.2;
                        ctx.beginPath();
                        for (var k = 0; k < teeth; k++) {
                            var ta = ang + k * 2 * Math.PI / teeth;
                            var ca = Math.cos(ta), sa = Math.sin(ta);
                            ctx.moveTo(sp[0] + ca * (sr - tl), sp[1] + sa * (sr - tl));
                            ctx.lineTo(sp[0] + ca * (sr + tl * 0.35), sp[1] + sa * (sr + tl * 0.35));
                        }
                        ctx.stroke();
                    }

                    /* 半径连线 */
                    var np = toScreen(nx, ny);
                    ctx.beginPath();
                    ctx.moveTo(sp[0], sp[1]);
                    ctx.lineTo(np[0], np[1]);
                    ctx.strokeStyle = 'rgba(127,230,255,.5)';
                    ctx.lineWidth = 1;
                    ctx.stroke();
                    }   /* if (showThis) */

                    /* 模型坐标推进 —— 画不画圈都要推进 */
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

            /* 笔尖（转到屏幕坐标） */
            var tp = toScreen(x, y);
            x = tp[0]; y = tp[1];
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
            if (state.path.length > 4000) state.path.shift();

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
                '<br>采样点 <b>' + (state.pts ? state.pts.length : 0) + '</b>' +
                ' · FFT ' + Math.round(ld) + 'ms';
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
        var sampSlider = host.querySelector('[data-samp]');
        var snEl = host.querySelector('[data-sn]');
        var sampDeb = null;

        /* 采样点滑块：滑的是 2 的幂的指数（10 → 1024，16 → 65536）。
           改了要重新取轮廓 + 重算 FFT，比较重，防抖给长一点。 */
        sampSlider.addEventListener('input', function () {
            SAMPLEN.cur = Math.pow(2, parseInt(sampSlider.value, 10));
            snEl.textContent = SAMPLEN.cur;
            /* 奈奎斯特：齿轮数不能超过采样点的一半 */
            var cap = Math.floor(SAMPLEN.cur / 2);
            gearSlider.max = Math.min(GEARM.max, cap);
            if (GEARM.cur > cap) {
                GEARM.cur = cap;
                gearSlider.value = cap;
                gnEl.textContent = cap;
            }
            clearTimeout(sampDeb);
            sampDeb = setTimeout(function () {
                state.path = [];
                rebuild();
            }, 650);
        });
        var gearDeb = null;
        gearSlider.addEventListener('input', function () {
            GEARM.cur = parseInt(gearSlider.value, 10);
            gnEl.textContent = GEARM.cur;
            /* 拖动时别每一像素都重算 DFT —— 那有 480 个点 × 几百个频率，很重 */
            clearTimeout(gearDeb);
            gearDeb = setTimeout(function () {
                state.path = [];
                rebuild();
            }, 420);
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

        /* ---------- 启动 ----------
           注意：这个模块挂在展示区的 tab 里，如果当前不是这个 tab，
           容器是 display:none，getBoundingClientRect 量出来是 0×0，
           画布尺寸就是 0，什么都画不出来（站长说的「刚打开不显示，
           切走再切回来才有」就是这个）。
           所以用 ResizeObserver 盯着，一出现真实尺寸就重建。 */
        textEl.value = state.text;

        var booted = false;
        function boot() {
            var r = cv.getBoundingClientRect();
            if (r.width < 40 || r.height < 40) return false;   /* 还没尺寸 */
            resize();
            rebuild();
            if (!raf) raf = requestAnimationFrame(loop);
            booted = true;
            return true;
        }

        setTimeout(boot, 60);

        if (window.ResizeObserver) {
            var ro = new ResizeObserver(function () {
                /* 尺寸变了就重来一次：从隐藏变可见、或者窗口缩放都走这里 */
                var r = cv.getBoundingClientRect();
                if (r.width < 40 || r.height < 40) return;
                if (!booted) { boot(); return; }
                if (Math.abs(r.width - state.W) > 2 || Math.abs(r.height - state.H) > 2) {
                    clearTimeout(window.__ftR2);
                    window.__ftR2 = setTimeout(function () {
                        resize();
                        rebuild();
                    }, 160);
                }
            });
            ro.observe(cv);
        } else {
            /* 老浏览器退回到轮询 */
            var tries = 0;
            var iv = setInterval(function () {
                if (boot() || ++tries > 40) clearInterval(iv);
            }, 200);
        }

        /* 再兜一层：有些情况下 ResizeObserver 也不会触发
           （比如容器一直是 0 高），那就每隔一会儿试一次，试到有尺寸为止。 */
        var late = 0;
        var lateIv = setInterval(function () {
            if (booted || ++late > 60) { clearInterval(lateIv); return; }
            boot();
        }, 250);

        return function () {
            if (raf) cancelAnimationFrame(raf);
        };
    }

    window.NBFourier = { mount: mount, pointsFromText: pointsFromText, dft: dft };
})();
