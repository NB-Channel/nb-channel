/* NB频道 · 国庆主题彩蛋：Python 海龟绘图 · 画五星红旗
   只在国庆主题下、页面有 .hero-copy 时注入。不依赖任何库。
   路径坐标严格照 turtle 语义算出：
     旗面 = t.forward(300); t.left(90)  ×4
     五角星 = t.forward(R); t.right(144) ×5
   四颗小星各有一角指向大星中心。 */
(function () {
    'use strict';
    var SVG = "<svg class=\"nb-tf-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 300 200\" width=\"300\" height=\"200\" role=\"img\" aria-label=\"Python 海龟绘图画出五星红旗的过程\"><rect width=\"300\" height=\"200\" fill=\"#2a0d10\" rx=\"8\"/><rect class=\"nb-tf-fill\" x=\"0\" y=\"0\" width=\"300\" height=\"200\" fill=\"#de2910\" rx=\"8\"/><g class=\"nb-tf-stroke\"><line x1=\"0.00\" y1=\"200.00\" x2=\"300.00\" y2=\"200.00\" style=\"--len:300.00;animation-delay:0.00s\"/><line x1=\"300.00\" y1=\"200.00\" x2=\"300.00\" y2=\"0.00\" style=\"--len:200.00;animation-delay:0.26s\"/><line x1=\"300.00\" y1=\"0.00\" x2=\"0.00\" y2=\"0.00\" style=\"--len:300.00;animation-delay:0.52s\"/><line x1=\"0.00\" y1=\"0.00\" x2=\"0.00\" y2=\"200.00\" style=\"--len:200.00;animation-delay:0.78s\"/><line x1=\"50.00\" y1=\"20.00\" x2=\"50.00\" y2=\"-10.00\" style=\"--len:30.00;animation-delay:1.04s\"/><line x1=\"50.00\" y1=\"-10.00\" x2=\"67.63\" y2=\"14.27\" style=\"--len:30.00;animation-delay:1.30s\"/><line x1=\"67.63\" y1=\"14.27\" x2=\"39.10\" y2=\"5.00\" style=\"--len:30.00;animation-delay:1.56s\"/><line x1=\"39.10\" y1=\"5.00\" x2=\"67.63\" y2=\"-4.27\" style=\"--len:30.00;animation-delay:1.82s\"/><line x1=\"67.63\" y1=\"-4.27\" x2=\"50.00\" y2=\"20.00\" style=\"--len:30.00;animation-delay:2.08s\"/><line x1=\"96.41\" y1=\"170.67\" x2=\"92.82\" y2=\"161.33\" style=\"--len:10.00;animation-delay:2.34s\"/><line x1=\"92.82\" y1=\"161.33\" x2=\"101.21\" y2=\"166.77\" style=\"--len:10.00;animation-delay:2.60s\"/><line x1=\"101.21\" y1=\"166.77\" x2=\"91.22\" y2=\"167.30\" style=\"--len:10.00;animation-delay:2.86s\"/><line x1=\"91.22\" y1=\"167.30\" x2=\"98.99\" y2=\"161.01\" style=\"--len:10.00;animation-delay:3.12s\"/><line x1=\"98.99\" y1=\"161.01\" x2=\"96.41\" y2=\"170.67\" style=\"--len:10.00;animation-delay:3.38s\"/><line x1=\"114.63\" y1=\"151.56\" x2=\"109.26\" y2=\"143.13\" style=\"--len:10.00;animation-delay:3.64s\"/><line x1=\"109.26\" y1=\"143.13\" x2=\"118.56\" y2=\"146.80\" style=\"--len:10.00;animation-delay:3.90s\"/><line x1=\"118.56\" y1=\"146.80\" x2=\"108.88\" y2=\"149.30\" style=\"--len:10.00;animation-delay:4.16s\"/><line x1=\"108.88\" y1=\"149.30\" x2=\"115.25\" y2=\"141.58\" style=\"--len:10.00;animation-delay:4.42s\"/><line x1=\"115.25\" y1=\"141.58\" x2=\"114.63\" y2=\"151.56\" style=\"--len:10.00;animation-delay:4.68s\"/><line x1=\"113.41\" y1=\"122.47\" x2=\"106.83\" y2=\"114.95\" style=\"--len:10.00;animation-delay:4.94s\"/><line x1=\"106.83\" y1=\"114.95\" x2=\"116.58\" y2=\"117.17\" style=\"--len:10.00;animation-delay:5.20s\"/><line x1=\"116.58\" y1=\"117.17\" x2=\"107.39\" y2=\"121.10\" style=\"--len:10.00;animation-delay:5.46s\"/><line x1=\"107.39\" y1=\"121.10\" x2=\"112.51\" y2=\"112.52\" style=\"--len:10.00;animation-delay:5.72s\"/><line x1=\"112.51\" y1=\"112.52\" x2=\"113.41\" y2=\"122.47\" style=\"--len:10.00;animation-delay:5.98s\"/><line x1=\"93.60\" y1=\"102.32\" x2=\"87.20\" y2=\"94.64\" style=\"--len:10.00;animation-delay:6.24s\"/><line x1=\"87.20\" y1=\"94.64\" x2=\"96.89\" y2=\"97.09\" style=\"--len:10.00;animation-delay:6.50s\"/><line x1=\"96.89\" y1=\"97.09\" x2=\"87.61\" y2=\"100.80\" style=\"--len:10.00;animation-delay:6.76s\"/><line x1=\"87.61\" y1=\"100.80\" x2=\"92.93\" y2=\"92.34\" style=\"--len:10.00;animation-delay:7.02s\"/><line x1=\"92.93\" y1=\"92.34\" x2=\"93.60\" y2=\"102.32\" style=\"--len:10.00;animation-delay:7.28s\"/></g><g class=\"nb-tf-pen\"><circle cx=\"300.00\" cy=\"200.00\" r=\"2.8\" style=\"animation-delay:0.26s\"/><circle cx=\"300.00\" cy=\"0.00\" r=\"2.8\" style=\"animation-delay:0.52s\"/><circle cx=\"0.00\" cy=\"0.00\" r=\"2.8\" style=\"animation-delay:0.78s\"/><circle cx=\"0.00\" cy=\"200.00\" r=\"2.8\" style=\"animation-delay:1.04s\"/><circle cx=\"50.00\" cy=\"-10.00\" r=\"2.8\" style=\"animation-delay:1.30s\"/><circle cx=\"67.63\" cy=\"14.27\" r=\"2.8\" style=\"animation-delay:1.56s\"/><circle cx=\"39.10\" cy=\"5.00\" r=\"2.8\" style=\"animation-delay:1.82s\"/><circle cx=\"67.63\" cy=\"-4.27\" r=\"2.8\" style=\"animation-delay:2.08s\"/><circle cx=\"50.00\" cy=\"20.00\" r=\"2.8\" style=\"animation-delay:2.34s\"/><circle cx=\"92.82\" cy=\"161.33\" r=\"2.8\" style=\"animation-delay:2.60s\"/><circle cx=\"101.21\" cy=\"166.77\" r=\"2.8\" style=\"animation-delay:2.86s\"/><circle cx=\"91.22\" cy=\"167.30\" r=\"2.8\" style=\"animation-delay:3.12s\"/><circle cx=\"98.99\" cy=\"161.01\" r=\"2.8\" style=\"animation-delay:3.38s\"/><circle cx=\"96.41\" cy=\"170.67\" r=\"2.8\" style=\"animation-delay:3.64s\"/><circle cx=\"109.26\" cy=\"143.13\" r=\"2.8\" style=\"animation-delay:3.90s\"/><circle cx=\"118.56\" cy=\"146.80\" r=\"2.8\" style=\"animation-delay:4.16s\"/><circle cx=\"108.88\" cy=\"149.30\" r=\"2.8\" style=\"animation-delay:4.42s\"/><circle cx=\"115.25\" cy=\"141.58\" r=\"2.8\" style=\"animation-delay:4.68s\"/><circle cx=\"114.63\" cy=\"151.56\" r=\"2.8\" style=\"animation-delay:4.94s\"/><circle cx=\"106.83\" cy=\"114.95\" r=\"2.8\" style=\"animation-delay:5.20s\"/><circle cx=\"116.58\" cy=\"117.17\" r=\"2.8\" style=\"animation-delay:5.46s\"/><circle cx=\"107.39\" cy=\"121.10\" r=\"2.8\" style=\"animation-delay:5.72s\"/><circle cx=\"112.51\" cy=\"112.52\" r=\"2.8\" style=\"animation-delay:5.98s\"/><circle cx=\"113.41\" cy=\"122.47\" r=\"2.8\" style=\"animation-delay:6.24s\"/><circle cx=\"87.20\" cy=\"94.64\" r=\"2.8\" style=\"animation-delay:6.50s\"/><circle cx=\"96.89\" cy=\"97.09\" r=\"2.8\" style=\"animation-delay:6.76s\"/><circle cx=\"87.61\" cy=\"100.80\" r=\"2.8\" style=\"animation-delay:7.02s\"/><circle cx=\"92.93\" cy=\"92.34\" r=\"2.8\" style=\"animation-delay:7.28s\"/><circle cx=\"93.60\" cy=\"102.32\" r=\"2.8\" style=\"animation-delay:7.54s\"/></g></svg>";
    var CSS = ".nb-tf-wrap{margin-top:34px;display:inline-flex;flex-direction:column;gap:12px;padding:16px 16px 14px;border-radius:16px;background:rgba(0,0,0,.24);border:1px solid rgba(255,210,74,.25);box-shadow:0 24px 60px -30px rgba(0,0,0,.7);}\n.nb-tf-head{font-size:.76rem;letter-spacing:1.2px;color:rgba(255,226,170,.78);}\n.nb-tf-head i{font-style:normal;opacity:.7;}\n.nb-tf-svg{display:block;border-radius:10px;}\n.nb-tf-code{margin:0;font:11px/1.75 ui-monospace,Consolas,\"Courier New\",monospace;color:rgba(255,232,200,.6);white-space:pre;overflow-x:auto;max-width:300px;}\n.nb-tf-code b{color:#ffd24a;font-weight:600;}\n.nb-tf-code em{color:rgba(255,232,200,.42);font-style:normal;}\n.nb-tf-stroke line{stroke:#ffd400;stroke-width:1.7;stroke-linecap:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfDraw 0.26s linear forwards;}\n@keyframes nbTfDraw{to{stroke-dashoffset:0;}}\n.nb-tf-fill{opacity:0;animation:nbTfFill .95s ease forwards;animation-delay:7.54s;}\n@keyframes nbTfFill{to{opacity:1;}}\n.nb-tf-pen circle{fill:#fff6d8;opacity:0;animation:nbTfPen .55s ease forwards;}\n@keyframes nbTfPen{0%{opacity:1;r:3.6;}100%{opacity:0;r:1.4;}}\n.nb-tf-inner{animation:nbTfCycle 9.94s ease-in-out infinite;}\n@keyframes nbTfCycle{0%,86%{opacity:1;}93%,100%{opacity:0;}}\n@media(max-width:900px){.nb-tf-svg{width:246px;height:164px;}.nb-tf-code{max-width:246px;font-size:10px;}}\n@media(prefers-reduced-motion:reduce){.nb-tf-stroke line{animation:none;stroke-dashoffset:0;}.nb-tf-fill{animation:none;opacity:1;}.nb-tf-pen circle{display:none;}.nb-tf-inner{animation:none;}}";
    var CODE = "<b>import</b> turtle <b>as</b> t\nt.color(<em>\"#de2910\"</em>); t.begin_fill()\n<b>for</b> _ <b>in</b> range(2):\n    t.forward(300); t.left(90)\n    t.forward(200); t.left(90)\nt.end_fill()\n\n<b>def</b> star(x, y, r):\n    t.penup(); t.goto(x, y); t.pendown()\n    t.color(<em>\"#ffde00\"</em>); t.begin_fill()\n    <b>for</b> _ <b>in</b> range(5):\n        t.forward(r); t.right(144)\n    t.end_fill()\n\nstar( 50,  50, 30)   <em># 大星</em>\nstar(100,  20, 10)   <em># 小星</em>\nstar(120,  40, 10)\nstar(120,  70, 10)\nstar(100,  90, 10)";

    function mount() {
        try {
            if (document.documentElement.getAttribute('theme') !== 'national') return;
            if (document.getElementById('nbTurtleFlag')) return;
            var copy = document.querySelector('.hero-copy');
            if (!copy) return;

            if (!document.getElementById('nbTurtleFlagCss')) {
                var st = document.createElement('style');
                st.id = 'nbTurtleFlagCss';
                st.textContent = CSS;
                document.head.appendChild(st);
            }

            var wrap = document.createElement('div');
            wrap.id = 'nbTurtleFlag';
            wrap.className = 'nb-tf-wrap';
            var head = document.createElement('div');
            head.className = 'nb-tf-head';
            head.innerHTML = '\uD83D\uDC22 Python \u6D77\u9F9F\u7ED8\u56FE <i>\u00B7 \u753B\u4E94\u661F\u7EA2\u65D7</i>';
            var inner = document.createElement('div');
            inner.className = 'nb-tf-inner';
            inner.innerHTML = SVG;
            var pre = document.createElement('pre');
            pre.className = 'nb-tf-code';
            pre.innerHTML = CODE;
            wrap.appendChild(head);
            wrap.appendChild(inner);
            wrap.appendChild(pre);

            var actions = copy.querySelector('.hero-actions');
            if (actions && actions.parentNode === copy) copy.insertBefore(wrap, actions.nextSibling);
            else copy.appendChild(wrap);
        } catch (e) {}
    }

    function unmount() {
        var el = document.getElementById('nbTurtleFlag');
        if (el && el.parentNode) el.parentNode.removeChild(el);
    }

    function boot() {
        mount();
        window.addEventListener('nb-theme-change', function () { unmount(); mount(); });
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})();
