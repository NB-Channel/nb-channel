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

        /* ---------- 2. 边界像素 + 连通域 ----------
           先把「自己是实心、四邻有一个是空」的像素挑出来当边界。
           然后【在边界掩码上】做连通域 —— 外轮廓和内孔的边界
           在这个掩码里本来就是分开的两组像素，所以「B」里面的洞
           会各自成为一组，不会再被漏掉。
           （之前在实心掩码上分组，「B」内外连着算一个域，
              Moore 追踪只走外圈，里面的孔就丢了。） */
        var isEdge = new Uint8Array(W * H);
        var edgeCount = 0;
        for (var y1 = 0; y1 < H; y1++) {
            for (var x1 = 0; x1 < W; x1++) {
                var ii = y1 * W + x1;
                if (!solid[ii]) continue;
                var l = x1 > 0 ? solid[ii - 1] : 0;
                var r = x1 < W - 1 ? solid[ii + 1] : 0;
                var u = y1 > 0 ? solid[ii - W] : 0;
                var d = y1 < H - 1 ? solid[ii + W] : 0;
                if (!l || !r || !u || !d) { isEdge[ii] = 1; edgeCount++; }
            }
        }
        if (edgeCount < 12) return null;

        var label = new Int32Array(W * H).fill(-1);
        var comps = [];
        var stack = [];
        for (var p0 = 0; p0 < W * H; p0++) {
            if (!isEdge[p0] || label[p0] >= 0) continue;
            var id = comps.length;
            var cells = [];
            stack.length = 0;
            stack.push(p0);
            label[p0] = id;
            /* 八邻域连通：边界可能是斜着连的 */
            while (stack.length) {
                var q = stack.pop();
                cells.push(q);
                var qx = q % W, qy = (q - qx) / W;
                for (var dx = -1; dx <= 1; dx++) {
                    for (var dy = -1; dy <= 1; dy++) {
                        if (!dx && !dy) continue;
                        var nx = qx + dx, ny = qy + dy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                        var rr = ny * W + nx;
                        if (isEdge[rr] && label[rr] < 0) { label[rr] = id; stack.push(rr); }
                    }
                }
            }
            /* 阈值从 24 降到 8 —— 字里的小笔画（比如「首」里那根横线）
               本来就不大，滤太狠会丢掉。 */
            if (cells.length >= 8) comps.push({ cells: cells, id: id });
        }
        if (!comps.length) return null;

        /* ---------- 3. 每组内部最近邻串链 ----------
           用空间网格加速：把点按格子分桶，找邻居时只查周围几格，
           否则每组几千个点做 O(n²) 会卡住。 */
        function chain(cells) {
            var n = cells.length;
            if (n < 4) return null;

            var GX = 8;                                  /* 格子边长 */
            var grid = {};
            for (var i = 0; i < n; i++) {
                var px = cells[i] % W, py = (cells[i] / W) | 0;
                var key = ((px / GX) | 0) + ',' + ((py / GX) | 0);
                (grid[key] || (grid[key] = [])).push(i);
            }
            var pts = new Array(n);
            for (var j = 0; j < n; j++) {
                pts[j] = [cells[j] % W, (cells[j] / W) | 0];
            }

            var used = new Uint8Array(n);
            /* 起点取最左上的点，稳定 */
            var start = 0;
            for (var k = 1; k < n; k++) {
                if (pts[k][1] < pts[start][1] ||
                    (pts[k][1] === pts[start][1] && pts[k][0] < pts[start][0])) start = k;
            }
            var order = [start];
            used[start] = 1;
            var cur = start;

            for (var step = 1; step < n; step++) {
                var cx = pts[cur][0], cy = pts[cur][1];
                var best = -1, bestD = Infinity;
                /* 一圈一圈往外找，找到就停 */
                for (var ring = 1; ring <= 10 && best < 0; ring++) {
                    var gx0 = ((cx - GX * ring) / GX) | 0;
                    var gx1 = ((cx + GX * ring) / GX) | 0;
                    var gy0 = ((cy - GX * ring) / GX) | 0;
                    var gy1 = ((cy + GX * ring) / GX) | 0;
                    for (var gx = gx0; gx <= gx1; gx++) {
                        for (var gy = gy0; gy <= gy1; gy++) {
                            /* 只看这一圈，里面的上一轮已经查过 */
                            if (ring > 1 && gx > gx0 && gx < gx1 && gy > gy0 && gy < gy1) continue;
                            var bucket = grid[gx + ',' + gy];
                            if (!bucket) continue;
                            for (var t = 0; t < bucket.length; t++) {
                                var m = bucket[t];
                                if (used[m]) continue;
                                var ddx = pts[m][0] - cx, ddy = pts[m][1] - cy;
                                var dd = ddx * ddx + ddy * ddy;
                                if (dd < bestD) { bestD = dd; best = m; }
                            }
                        }
                    }
                }
                if (best < 0) break;
                used[best] = 1;
                order.push(best);
                cur = best;
            }
            if (order.length < 4) return null;
            return order.map(function (o) { return pts[o]; });
        }

        var groups = [];
        comps.forEach(function (cp) {
            var pts = chain(cp.cells);
            if (!pts || pts.length < 4) return;
            var mx = 0, my = 0;
            pts.forEach(function (p) { mx += p[0]; my += p[1]; });
            mx /= pts.length; my /= pts.length;
            groups.push({ pts: pts, mx: mx, my: my, n: cp.cells.length });
        });
        if (!groups.length) return null;

        /* 小的排前面、大的排后面？不 —— 按从左到右排，
           这样笔画顺序跟写字方向大体一致。 */
        groups.sort(function (p, q) { return p.mx - q.mx; });

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
        '  grid-template-columns:repeat(auto-fill,minmax(178px,1fr));',
        '  max-height:340px;overflow-y:auto;padding-right:4px;}',
        '  border-radius:4px;}',
        '  background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);',
        '  font-size:.68rem;color:#9fb6d4;}',
        '  background:rgba(255,255,255,.16);position:relative;transition:background .2s;}',
        '  border-radius:50%;background:#8fa8c8;transition:transform .2s,background .2s;}',
        '.nb-ft-tip{margin-top:14px;font-size:.72rem;line-height:1.9;color:#7f93b0;}',
        '@media(max-width:820px){.nb-ft-stage canvas{height:320px;}}',
        /* 代码面板的语法高亮配色。
           代码本身由 tech-showcase.js 渲染，但样式是全局的，
           在这里注入 head 一样生效。 */
        '.nb-cm{color:#6b7f99 !important;font-style:italic;}',
        '.nb-st{color:#8fd97a !important;}',
        '.nb-nu{color:#f0a35e !important;}',
        '.nb-kw{color:#c98bdb !important;font-weight:600;}',
        '.nb-fn{color:#5fc9f8 !important;}'
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
                '<button class="nb-ft-btn" data-act="play">开始</button>' +
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
                    'min-width:44px;text-align:right">5000</b>' +
                  '<input type="range" min="10" max="10000" step="10" value="5000" data-gears ' +
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
                            '<div class="nb-ft-tip">' +
                '<b>每个齿轮 = 一个频率分量</b>：半径是它的振幅，齿数是它的频率' +
                '（转一圈咬合几次）。所有齿轮首尾串起来，最后一个的笔尖就画出你输的字。' +
                '按振幅从大到小排 —— 前面的定大体形状，后面的补细节。' +
                '<br><br>' +
                '<b>采样点</b>决定最多能分出多少个频率分量（FFT 的要求，所以取 2 的幂，' +
                '1024 ~ 65536）；<b>齿轮数</b>是实际用多少个来画。两个都用下面的滑块调，' +
                '默认 32768 点 + 5000 个齿轮，单字和整词都够清楚。' +
                '<br><br>' +
                '字里那些互不相连的笔画块之间要「跳跃」，跳跃的能量会摊到所有频率上，' +
                '所以齿轮越多细节越全 —— 采样点不够时，多出来的分量是插值凑的，' +
                '调高齿轮数也看不出变化。' +
                '<br><br>' +
                '绘制时区域之间会自动断开，不会拉出多余的直线。' +
                '计算用 FFT（快速傅里叶变换），32768 个采样点只要十几毫秒。' +
              '</div>' +
            '</div>';

        var cv = host.querySelector('canvas');
        var ctx = cv.getContext('2d');
        var hudEl = host.querySelector('[data-hud]');
        /* 齿轮调节面板已去掉，这里不再需要 gearsEl */
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
            /* 默认暂停：打开就是一张空白画布，只显示齿轮的初始位置，
               看不到字。点「开始」才开始一笔一笔描出来。 */
            playing: false,
            showGear: true,
            showPath: true,
            text: 'NB频道',
            comps: [],       /* 选中的分量 */
            pts: null,
            t: 0,
            path: [],
            W: 0, H: 0,
            fftMs: 0,          /* 上次 FFT 耗时，HUD 里显示 */
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
        var GEARM = { cur: 5000, min: 10, max: 10000 };

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
            /* 挂到 state 上 —— 原来这是个局部变量，
               HUD 在 draw() 里读它读不到，一直报 ld is not defined */
            state.fftMs = (window.performance || Date).now() - t0;
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

            /* 轨迹清空、时间归零 —— 画布保持空白，
               只显示齿轮的初始位置，等用户点「开始」再画。 */
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
            /* 采样次数跟着齿轮数走：齿轮多的时候每轮开销是
               「采样次数 × 齿轮数」，都拉满就是两千万次，初次渲染会卡。
               包围盒只要轮廓大致准就够，1024 次足矣。 */
            var S = state.comps.length > 800 ? 1024
                  : state.comps.length > 200 ? 2048 : 4096;
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

            /* 注意：这里【不要】清 state.path。
               原来在这清，结果 pretun 因为 ResizeObserver 之类的原因被
               反复调用时，轨迹每帧都被清掉，永远攒不起来 ——
               表现就是屏幕上只剩笔尖附近一丁点。
               清空交给 rebuild()，它只在换图案/换齿轮数时跑。 */
        }

        /* ---------- 画一帧 ---------- */
        function draw() {
            var W = state.W, H = state.H;
            if (!W || !H) return;

            /* 完全不透明清屏。
               原来这里用 rgba(8,13,24,.34) 做拖尾，结果轨迹每个点大约
               10 帧后就淡没了 —— 60fps 下才 0.17 秒，而一圈是 9 秒，
               屏幕上永远只有最后一小段，图形拼不完整。
               轨迹本来就每帧从 state.path 重描，不需要靠残留维持。 */
            ctx.fillStyle = '#080d18';
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
                ' · FFT ' + Math.round(state.fftMs) + 'ms';
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

        /* 「重置」也顺手把播放停掉，回到空白状态 */
        var _resetBtn = host.querySelector('[data-act="reset"]');
        if (_resetBtn) {
            _resetBtn.addEventListener('click', function () {
                var pb = host.querySelector('[data-act="play"]');
                state.playing = false;
                if (pb) { pb.textContent = '开始'; pb.classList.remove('on'); }
            });
        }
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
