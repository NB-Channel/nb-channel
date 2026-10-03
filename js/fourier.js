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

        /* 先用一个临时 canvas 画出文字，量一下实际占多大 */
        var probe = document.createElement('canvas');
        probe.width = 900;
        probe.height = 320;
        var pc = probe.getContext('2d');
        var size = 220;
        pc.fillStyle = '#000';
        pc.textAlign = 'center';
        pc.textBaseline = 'middle';
        pc.font = '900 ' + size + 'px system-ui,-apple-system,"Microsoft YaHei",sans-serif';
        var w = pc.measureText(text).width;
        /* 太长就缩字号，保证能放进画布 */
        if (w > probe.width - 60) {
            size = Math.floor(size * (probe.width - 60) / w);
            pc.font = '900 ' + size + 'px system-ui,-apple-system,"Microsoft YaHei",sans-serif';
            w = pc.measureText(text).width;
        }
        pc.clearRect(0, 0, probe.width, probe.height);
        pc.fillStyle = '#000';
        pc.fillText(text, probe.width / 2, probe.height / 2);

        var img = pc.getImageData(0, 0, probe.width, probe.height).data;
        var W = probe.width, H = probe.height;

        /* 把有墨的像素记下来，同时算重心 */
        var solid = new Uint8Array(W * H);
        var cx = 0, cy = 0, n = 0;
        for (var y = 0; y < H; y++) {
            for (var x = 0; x < W; x++) {
                if (img[(y * W + x) * 4 + 3] > 128) {
                    solid[y * W + x] = 1;
                    cx += x; cy += y; n++;
                }
            }
        }
        if (!n) return null;
        cx /= n; cy /= n;

        /* 只留边界像素：四邻里有一个是空的，就算边界 */
        var edge = [];
        for (var y2 = 1; y2 < H - 1; y2++) {
            for (var x2 = 1; x2 < W - 1; x2++) {
                var i2 = y2 * W + x2;
                if (!solid[i2]) continue;
                if (!solid[i2 - 1] || !solid[i2 + 1] ||
                    !solid[i2 - W] || !solid[i2 + W]) {
                    edge.push([x2 - cx, y2 - cy]);      /* 以重心为原点 */
                }
            }
        }
        if (edge.length < 8) return null;

        /* 最近邻串成一条链，从离重心最远的点起步（那样起点稳定） */
        var start = 0, far = -1;
        for (var i = 0; i < edge.length; i++) {
            var d = edge[i][0] * edge[i][0] + edge[i][1] * edge[i][1];
            if (d > far) { far = d; start = i; }
        }
        var used = new Uint8Array(edge.length);
        var order = [start];
        used[start] = 1;
        var cur = start;
        var GRID = 24;                              /* 分桶加速找邻居 */
        for (var step = 1; step < edge.length; step++) {
            var best = -1, bestD = Infinity;
            var bx = edge[cur][0], by = edge[cur][1];
            for (var j = 0; j < edge.length; j++) {
                if (used[j]) continue;
                var dx = edge[j][0] - bx, dy = edge[j][1] - by;
                var dd = dx * dx + dy * dy;
                if (dd < bestD) { bestD = dd; best = j; }
                /* 足够近就收，省时间 */
                if (bestD < GRID) break;
            }
            if (best < 0) break;
            used[best] = 1;
            order.push(best);
            cur = best;
        }

        /* 均匀重采样到 target 个点 */
        var pts = [];
        var m = order.length;
        for (var k = 0; k < target; k++) {
            var p = edge[order[Math.floor(k * m / target) % m]];
            pts.push([p[0], p[1]]);
        }
        return pts;
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
        '.nb-ft-gears{margin-top:18px;display:grid;gap:8px;',
        '  grid-template-columns:repeat(auto-fill,minmax(232px,1fr));}',
        '.nb-ft-gear{display:flex;align-items:center;gap:9px;padding:9px 11px;border-radius:9px;',
        '  background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);',
        '  font-size:.72rem;color:#9fb6d4;}',
        '.nb-ft-gear.on{border-color:rgba(0,229,255,.42);background:rgba(0,229,255,.08);}',
        '.nb-ft-gear .sw{width:30px;height:17px;border-radius:9px;cursor:pointer;flex:0 0 auto;',
        '  background:rgba(255,255,255,.16);position:relative;transition:background .2s;}',
        '.nb-ft-gear .sw::after{content:"";position:absolute;top:2px;left:2px;width:13px;height:13px;',
        '  border-radius:50%;background:#8fa8c8;transition:transform .2s,background .2s;}',
        '.nb-ft-gear.on .sw{background:rgba(0,229,255,.45);}',
        '.nb-ft-gear.on .sw::after{transform:translateX(13px);background:#00e5ff;}',
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
              '</div>' +
              '<div class="nb-ft-tools">' +
                '<span style="font-size:.72rem;color:#7f93b0;letter-spacing:1px">预设</span>' +
                '<button class="nb-ft-preset" data-preset="NB频道">NB频道</button>' +
                '<button class="nb-ft-preset" data-preset="NB-CHANNEL">NB-CHANNEL</button>' +
                '<button class="nb-ft-preset" data-preset="NoBook">NoBook</button>' +
                '<button class="nb-ft-preset" data-preset="π">π</button>' +
                '<button class="nb-ft-preset" data-preset="∞">∞</button>' +
              '</div>' +
              '<div class="nb-ft-gears" data-gears></div>' +
              '<div class="nb-ft-tip">' +
                '每个齿轮 = 一个频率分量：<b>半径</b>是它的振幅，<b>齿数</b>是它的频率' +
                '（转一圈咬合几次）。所有齿轮首尾串起来，最外那个的笔尖就画出你输的字。' +
                '最多取 10 个齿轮，按振幅从大到小排 —— 前面的定大体形状，后面的补细节。' +
              '</div>' +
            '</div>';

        var cv = host.querySelector('canvas');
        var ctx = cv.getContext('2d');
        var hudEl = host.querySelector('[data-hud]');
        var gearsEl = host.querySelector('[data-gears]');
        var textEl = host.querySelector('[data-text]');

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
        var MAXG = 10;       /* 最多 10 个齿轮 */

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
            var picked = all.slice(0, MAXG);

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

            /* 生成齿轮调节面板 */
            gearsEl.innerHTML = '';
            state.comps.forEach(function (c) {
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
            prerun();
        }

        /* 不开动画，纯算一遍把 path 填满 */
        function prerun() {
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
                state.path.push([x, y]);
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
                    ctx.strokeStyle = 'rgba(0,229,255,' + (0.34 - i * 0.026) + ')';
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    /* 齿：齿数就是这个分量的频率 —— 沿圆周点 n 个短齿 */
                    var teeth = Math.min(Math.abs(c.freq), 48);
                    if (teeth >= 2 && r > 6) {
                        var tl = Math.min(7, r * 0.22);
                        ctx.strokeStyle = 'rgba(0,229,255,' + (0.5 - i * 0.04) + ')';
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
            state.path.push([x, y]);
            if (state.path.length > 1400) state.path.shift();

            if (state.showPath && state.path.length > 1) {
                ctx.beginPath();
                ctx.moveTo(state.path[0][0], state.path[0][1]);
                for (var p = 1; p < state.path.length; p++) {
                    ctx.lineTo(state.path[p][0], state.path[p][1]);
                }
                ctx.strokeStyle = 'rgba(255,216,94,.85)';
                ctx.lineWidth = 1.6;
                ctx.stroke();
            }

            hudEl.innerHTML =
                '齿轮 <b>' + comps.length + '</b> / ' + state.comps.length +
                '<br>齿数 <b>' + comps.map(function (c) {
                    /* freq = 0 是直流分量（整体平移），没有齿，单列出来 */
                    return c.freq === 0 ? '直流' : Math.abs(c.freq);
                }).join(' · ') + '</b>' +
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
