/* NB频道 · 国庆主题：Python 海龟绘图 · 画五星红旗（含六条释义引线）
   画布 720x420；国旗放大到 380x253；Hero 下半部分一行：国旗动画在左、代码面板在右。
   代码面板默认折叠（宽度与左列国旗一致），可展开、可一键复制。
   时间轴：旗面 -> 大星 -> 四颗小星（同步）-> 六条引线逐条。跑完静止。*/
(function () {
    'use strict';
    var SVG = "<svg class=\"nb-tf-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 720 420\" width=\"720\" height=\"420\" role=\"img\" aria-label=\"Python 海龟绘图画出五星红旗，并标注各部分含义\"><rect width=\"720\" height=\"420\" fill=\"#0b1220\" rx=\"12\"/><rect class=\"nb-tf-fill\" x=\"128.0\" y=\"70.0\" width=\"380.0\" height=\"253.3\" fill=\"#de2910\" rx=\"5\"/><polygon class=\"nb-tf-star\" points=\"191.33,95.33 199.86,121.59 227.47,121.59 205.14,137.82 213.67,164.08 191.33,147.85 169.00,164.08 177.53,137.82 155.19,121.59 182.80,121.59\" style=\"animation-delay:3.08s\"/><polygon class=\"nb-tf-star\" points=\"243.81,101.85 249.85,94.91 245.11,87.02 253.58,90.62 259.62,83.68 258.82,92.84 267.28,96.45 258.32,98.51 257.51,107.68 252.77,99.79\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"267.46,122.46 275.72,118.40 274.42,109.29 280.83,115.90 289.09,111.85 284.79,119.98 291.20,126.59 282.13,125.01 277.83,133.15 276.53,124.04\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"267.82,155.19 277.02,154.86 279.55,146.01 282.70,154.65 291.90,154.32 284.65,160.00 287.81,168.64 280.17,163.50 272.93,169.17 275.46,160.33\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"244.78,176.09 253.39,179.33 259.14,172.15 258.71,181.34 267.32,184.59 258.44,187.02 258.02,196.22 252.96,188.53 244.08,190.96 249.83,183.78\" style=\"animation-delay:5.28s\"/><g class=\"nb-tf-stroke\"><line x1=\"128.00\" y1=\"323.33\" x2=\"508.00\" y2=\"323.33\" style=\"--len:380.00;animation-delay:0.00s\"/><line x1=\"508.00\" y1=\"323.33\" x2=\"508.00\" y2=\"70.00\" style=\"--len:253.33;animation-delay:0.22s\"/><line x1=\"508.00\" y1=\"70.00\" x2=\"128.00\" y2=\"70.00\" style=\"--len:380.00;animation-delay:0.44s\"/><line x1=\"128.00\" y1=\"70.00\" x2=\"128.00\" y2=\"323.33\" style=\"--len:253.33;animation-delay:0.66s\"/><line x1=\"191.33\" y1=\"95.33\" x2=\"199.86\" y2=\"121.59\" style=\"--len:27.61;animation-delay:0.88s\"/><line x1=\"199.86\" y1=\"121.59\" x2=\"227.47\" y2=\"121.59\" style=\"--len:27.61;animation-delay:1.10s\"/><line x1=\"227.47\" y1=\"121.59\" x2=\"205.14\" y2=\"137.82\" style=\"--len:27.61;animation-delay:1.32s\"/><line x1=\"205.14\" y1=\"137.82\" x2=\"213.67\" y2=\"164.08\" style=\"--len:27.61;animation-delay:1.54s\"/><line x1=\"213.67\" y1=\"164.08\" x2=\"191.33\" y2=\"147.85\" style=\"--len:27.61;animation-delay:1.76s\"/><line x1=\"191.33\" y1=\"147.85\" x2=\"169.00\" y2=\"164.08\" style=\"--len:27.61;animation-delay:1.98s\"/><line x1=\"169.00\" y1=\"164.08\" x2=\"177.53\" y2=\"137.82\" style=\"--len:27.61;animation-delay:2.20s\"/><line x1=\"177.53\" y1=\"137.82\" x2=\"155.19\" y2=\"121.59\" style=\"--len:27.61;animation-delay:2.42s\"/><line x1=\"155.19\" y1=\"121.59\" x2=\"182.80\" y2=\"121.59\" style=\"--len:27.61;animation-delay:2.64s\"/><line x1=\"182.80\" y1=\"121.59\" x2=\"191.33\" y2=\"95.33\" style=\"--len:27.61;animation-delay:2.86s\"/><line x1=\"243.81\" y1=\"101.85\" x2=\"249.85\" y2=\"94.91\" style=\"--len:9.20;animation-delay:3.08s\"/><line x1=\"249.85\" y1=\"94.91\" x2=\"245.11\" y2=\"87.02\" style=\"--len:9.20;animation-delay:3.30s\"/><line x1=\"245.11\" y1=\"87.02\" x2=\"253.58\" y2=\"90.62\" style=\"--len:9.20;animation-delay:3.52s\"/><line x1=\"253.58\" y1=\"90.62\" x2=\"259.62\" y2=\"83.68\" style=\"--len:9.20;animation-delay:3.74s\"/><line x1=\"259.62\" y1=\"83.68\" x2=\"258.82\" y2=\"92.84\" style=\"--len:9.20;animation-delay:3.96s\"/><line x1=\"258.82\" y1=\"92.84\" x2=\"267.28\" y2=\"96.45\" style=\"--len:9.20;animation-delay:4.18s\"/><line x1=\"267.28\" y1=\"96.45\" x2=\"258.32\" y2=\"98.51\" style=\"--len:9.20;animation-delay:4.40s\"/><line x1=\"258.32\" y1=\"98.51\" x2=\"257.51\" y2=\"107.68\" style=\"--len:9.20;animation-delay:4.62s\"/><line x1=\"257.51\" y1=\"107.68\" x2=\"252.77\" y2=\"99.79\" style=\"--len:9.20;animation-delay:4.84s\"/><line x1=\"252.77\" y1=\"99.79\" x2=\"243.81\" y2=\"101.85\" style=\"--len:9.20;animation-delay:5.06s\"/><line x1=\"267.46\" y1=\"122.46\" x2=\"275.72\" y2=\"118.40\" style=\"--len:9.20;animation-delay:3.08s\"/><line x1=\"275.72\" y1=\"118.40\" x2=\"274.42\" y2=\"109.29\" style=\"--len:9.20;animation-delay:3.30s\"/><line x1=\"274.42\" y1=\"109.29\" x2=\"280.83\" y2=\"115.90\" style=\"--len:9.20;animation-delay:3.52s\"/><line x1=\"280.83\" y1=\"115.90\" x2=\"289.09\" y2=\"111.85\" style=\"--len:9.20;animation-delay:3.74s\"/><line x1=\"289.09\" y1=\"111.85\" x2=\"284.79\" y2=\"119.98\" style=\"--len:9.20;animation-delay:3.96s\"/><line x1=\"284.79\" y1=\"119.98\" x2=\"291.20\" y2=\"126.59\" style=\"--len:9.20;animation-delay:4.18s\"/><line x1=\"291.20\" y1=\"126.59\" x2=\"282.13\" y2=\"125.01\" style=\"--len:9.20;animation-delay:4.40s\"/><line x1=\"282.13\" y1=\"125.01\" x2=\"277.83\" y2=\"133.15\" style=\"--len:9.20;animation-delay:4.62s\"/><line x1=\"277.83\" y1=\"133.15\" x2=\"276.53\" y2=\"124.04\" style=\"--len:9.20;animation-delay:4.84s\"/><line x1=\"276.53\" y1=\"124.04\" x2=\"267.46\" y2=\"122.46\" style=\"--len:9.20;animation-delay:5.06s\"/><line x1=\"267.82\" y1=\"155.19\" x2=\"277.02\" y2=\"154.86\" style=\"--len:9.20;animation-delay:3.08s\"/><line x1=\"277.02\" y1=\"154.86\" x2=\"279.55\" y2=\"146.01\" style=\"--len:9.20;animation-delay:3.30s\"/><line x1=\"279.55\" y1=\"146.01\" x2=\"282.70\" y2=\"154.65\" style=\"--len:9.20;animation-delay:3.52s\"/><line x1=\"282.70\" y1=\"154.65\" x2=\"291.90\" y2=\"154.32\" style=\"--len:9.20;animation-delay:3.74s\"/><line x1=\"291.90\" y1=\"154.32\" x2=\"284.65\" y2=\"160.00\" style=\"--len:9.20;animation-delay:3.96s\"/><line x1=\"284.65\" y1=\"160.00\" x2=\"287.81\" y2=\"168.64\" style=\"--len:9.20;animation-delay:4.18s\"/><line x1=\"287.81\" y1=\"168.64\" x2=\"280.17\" y2=\"163.50\" style=\"--len:9.20;animation-delay:4.40s\"/><line x1=\"280.17\" y1=\"163.50\" x2=\"272.93\" y2=\"169.17\" style=\"--len:9.20;animation-delay:4.62s\"/><line x1=\"272.93\" y1=\"169.17\" x2=\"275.46\" y2=\"160.33\" style=\"--len:9.20;animation-delay:4.84s\"/><line x1=\"275.46\" y1=\"160.33\" x2=\"267.82\" y2=\"155.19\" style=\"--len:9.20;animation-delay:5.06s\"/><line x1=\"244.78\" y1=\"176.09\" x2=\"253.39\" y2=\"179.33\" style=\"--len:9.20;animation-delay:3.08s\"/><line x1=\"253.39\" y1=\"179.33\" x2=\"259.14\" y2=\"172.15\" style=\"--len:9.20;animation-delay:3.30s\"/><line x1=\"259.14\" y1=\"172.15\" x2=\"258.71\" y2=\"181.34\" style=\"--len:9.20;animation-delay:3.52s\"/><line x1=\"258.71\" y1=\"181.34\" x2=\"267.32\" y2=\"184.59\" style=\"--len:9.20;animation-delay:3.74s\"/><line x1=\"267.32\" y1=\"184.59\" x2=\"258.44\" y2=\"187.02\" style=\"--len:9.20;animation-delay:3.96s\"/><line x1=\"258.44\" y1=\"187.02\" x2=\"258.02\" y2=\"196.22\" style=\"--len:9.20;animation-delay:4.18s\"/><line x1=\"258.02\" y1=\"196.22\" x2=\"252.96\" y2=\"188.53\" style=\"--len:9.20;animation-delay:4.40s\"/><line x1=\"252.96\" y1=\"188.53\" x2=\"244.08\" y2=\"190.96\" style=\"--len:9.20;animation-delay:4.62s\"/><line x1=\"244.08\" y1=\"190.96\" x2=\"249.83\" y2=\"183.78\" style=\"--len:9.20;animation-delay:4.84s\"/><line x1=\"249.83\" y1=\"183.78\" x2=\"244.78\" y2=\"176.09\" style=\"--len:9.20;animation-delay:5.06s\"/></g><g class=\"nb-tf-pen\"><circle cx=\"508.00\" cy=\"323.33\" r=\"2.6\" style=\"animation-delay:0.22s\"/><circle cx=\"508.00\" cy=\"70.00\" r=\"2.6\" style=\"animation-delay:0.44s\"/><circle cx=\"128.00\" cy=\"70.00\" r=\"2.6\" style=\"animation-delay:0.66s\"/><circle cx=\"128.00\" cy=\"323.33\" r=\"2.6\" style=\"animation-delay:0.88s\"/><circle cx=\"199.86\" cy=\"121.59\" r=\"2.6\" style=\"animation-delay:1.10s\"/><circle cx=\"227.47\" cy=\"121.59\" r=\"2.6\" style=\"animation-delay:1.32s\"/><circle cx=\"205.14\" cy=\"137.82\" r=\"2.6\" style=\"animation-delay:1.54s\"/><circle cx=\"213.67\" cy=\"164.08\" r=\"2.6\" style=\"animation-delay:1.76s\"/><circle cx=\"191.33\" cy=\"147.85\" r=\"2.6\" style=\"animation-delay:1.98s\"/><circle cx=\"169.00\" cy=\"164.08\" r=\"2.6\" style=\"animation-delay:2.20s\"/><circle cx=\"177.53\" cy=\"137.82\" r=\"2.6\" style=\"animation-delay:2.42s\"/><circle cx=\"155.19\" cy=\"121.59\" r=\"2.6\" style=\"animation-delay:2.64s\"/><circle cx=\"182.80\" cy=\"121.59\" r=\"2.6\" style=\"animation-delay:2.86s\"/><circle cx=\"191.33\" cy=\"95.33\" r=\"2.6\" style=\"animation-delay:3.08s\"/><circle cx=\"249.85\" cy=\"94.91\" r=\"2.6\" style=\"animation-delay:3.30s\"/><circle cx=\"245.11\" cy=\"87.02\" r=\"2.6\" style=\"animation-delay:3.52s\"/><circle cx=\"253.58\" cy=\"90.62\" r=\"2.6\" style=\"animation-delay:3.74s\"/><circle cx=\"259.62\" cy=\"83.68\" r=\"2.6\" style=\"animation-delay:3.96s\"/><circle cx=\"258.82\" cy=\"92.84\" r=\"2.6\" style=\"animation-delay:4.18s\"/><circle cx=\"267.28\" cy=\"96.45\" r=\"2.6\" style=\"animation-delay:4.40s\"/><circle cx=\"258.32\" cy=\"98.51\" r=\"2.6\" style=\"animation-delay:4.62s\"/><circle cx=\"257.51\" cy=\"107.68\" r=\"2.6\" style=\"animation-delay:4.84s\"/><circle cx=\"252.77\" cy=\"99.79\" r=\"2.6\" style=\"animation-delay:5.06s\"/><circle cx=\"243.81\" cy=\"101.85\" r=\"2.6\" style=\"animation-delay:5.28s\"/><circle cx=\"275.72\" cy=\"118.40\" r=\"2.6\" style=\"animation-delay:3.30s\"/><circle cx=\"274.42\" cy=\"109.29\" r=\"2.6\" style=\"animation-delay:3.52s\"/><circle cx=\"280.83\" cy=\"115.90\" r=\"2.6\" style=\"animation-delay:3.74s\"/><circle cx=\"289.09\" cy=\"111.85\" r=\"2.6\" style=\"animation-delay:3.96s\"/><circle cx=\"284.79\" cy=\"119.98\" r=\"2.6\" style=\"animation-delay:4.18s\"/><circle cx=\"291.20\" cy=\"126.59\" r=\"2.6\" style=\"animation-delay:4.40s\"/><circle cx=\"282.13\" cy=\"125.01\" r=\"2.6\" style=\"animation-delay:4.62s\"/><circle cx=\"277.83\" cy=\"133.15\" r=\"2.6\" style=\"animation-delay:4.84s\"/><circle cx=\"276.53\" cy=\"124.04\" r=\"2.6\" style=\"animation-delay:5.06s\"/><circle cx=\"267.46\" cy=\"122.46\" r=\"2.6\" style=\"animation-delay:5.28s\"/><circle cx=\"277.02\" cy=\"154.86\" r=\"2.6\" style=\"animation-delay:3.30s\"/><circle cx=\"279.55\" cy=\"146.01\" r=\"2.6\" style=\"animation-delay:3.52s\"/><circle cx=\"282.70\" cy=\"154.65\" r=\"2.6\" style=\"animation-delay:3.74s\"/><circle cx=\"291.90\" cy=\"154.32\" r=\"2.6\" style=\"animation-delay:3.96s\"/><circle cx=\"284.65\" cy=\"160.00\" r=\"2.6\" style=\"animation-delay:4.18s\"/><circle cx=\"287.81\" cy=\"168.64\" r=\"2.6\" style=\"animation-delay:4.40s\"/><circle cx=\"280.17\" cy=\"163.50\" r=\"2.6\" style=\"animation-delay:4.62s\"/><circle cx=\"272.93\" cy=\"169.17\" r=\"2.6\" style=\"animation-delay:4.84s\"/><circle cx=\"275.46\" cy=\"160.33\" r=\"2.6\" style=\"animation-delay:5.06s\"/><circle cx=\"267.82\" cy=\"155.19\" r=\"2.6\" style=\"animation-delay:5.28s\"/><circle cx=\"253.39\" cy=\"179.33\" r=\"2.6\" style=\"animation-delay:3.30s\"/><circle cx=\"259.14\" cy=\"172.15\" r=\"2.6\" style=\"animation-delay:3.52s\"/><circle cx=\"258.71\" cy=\"181.34\" r=\"2.6\" style=\"animation-delay:3.74s\"/><circle cx=\"267.32\" cy=\"184.59\" r=\"2.6\" style=\"animation-delay:3.96s\"/><circle cx=\"258.44\" cy=\"187.02\" r=\"2.6\" style=\"animation-delay:4.18s\"/><circle cx=\"258.02\" cy=\"196.22\" r=\"2.6\" style=\"animation-delay:4.40s\"/><circle cx=\"252.96\" cy=\"188.53\" r=\"2.6\" style=\"animation-delay:4.62s\"/><circle cx=\"244.08\" cy=\"190.96\" r=\"2.6\" style=\"animation-delay:4.84s\"/><circle cx=\"249.83\" cy=\"183.78\" r=\"2.6\" style=\"animation-delay:5.06s\"/><circle cx=\"244.78\" cy=\"176.09\" r=\"2.6\" style=\"animation-delay:5.28s\"/></g><g class=\"nb-tf-leads\"><polyline class=\"nb-tf-lead\" points=\"153.3,111.3 78.0,58.0 10.0,58.0\" style=\"--len:160.3;animation-delay:5.43s\"/><circle class=\"nb-tf-dot\" cx=\"153.3\" cy=\"111.3\" r=\"2.8\" style=\"animation-delay:5.43s\"/><text class=\"nb-tf-label\" x=\"10.0\" y=\"48.0\" text-anchor=\"start\" style=\"animation-delay:5.59s\">中国共产党</text><polyline class=\"nb-tf-lead\" points=\"266.7,85.3 556.0,40.0 600.0,40.0\" style=\"--len:336.9;animation-delay:5.67s\"/><circle class=\"nb-tf-dot\" cx=\"266.7\" cy=\"85.3\" r=\"2.8\" style=\"animation-delay:5.67s\"/><text class=\"nb-tf-label\" x=\"600.0\" y=\"30.0\" text-anchor=\"start\" style=\"animation-delay:5.83s\">工人阶级</text><polyline class=\"nb-tf-lead\" points=\"293.0,121.7 566.0,104.0 600.0,104.0\" style=\"--len:307.6;animation-delay:5.91s\"/><circle class=\"nb-tf-dot\" cx=\"293.0\" cy=\"121.7\" r=\"2.8\" style=\"animation-delay:5.91s\"/><text class=\"nb-tf-label\" x=\"600.0\" y=\"94.0\" text-anchor=\"start\" style=\"animation-delay:6.07s\">农民阶级</text><polyline class=\"nb-tf-lead\" points=\"293.0,157.7 566.0,168.0 600.0,168.0\" style=\"--len:307.2;animation-delay:6.15s\"/><circle class=\"nb-tf-dot\" cx=\"293.0\" cy=\"157.7\" r=\"2.8\" style=\"animation-delay:6.15s\"/><text class=\"nb-tf-label\" x=\"600.0\" y=\"158.0\" text-anchor=\"start\" style=\"animation-delay:6.31s\">城市小资产阶级</text><polyline class=\"nb-tf-lead\" points=\"266.7,194.0 556.0,234.0 600.0,234.0\" style=\"--len:336.1;animation-delay:6.39s\"/><circle class=\"nb-tf-dot\" cx=\"266.7\" cy=\"194.0\" r=\"2.8\" style=\"animation-delay:6.39s\"/><text class=\"nb-tf-label\" x=\"600.0\" y=\"224.0\" text-anchor=\"start\" style=\"animation-delay:6.55s\">民族资产阶级</text><polyline class=\"nb-tf-lead\" points=\"318.0,330.3 318.0,372.0 414.0,372.0\" style=\"--len:137.7;animation-delay:6.63s\"/><circle class=\"nb-tf-dot\" cx=\"318.0\" cy=\"330.3\" r=\"2.8\" style=\"animation-delay:6.63s\"/><text class=\"nb-tf-label\" x=\"414.0\" y=\"400.0\" text-anchor=\"middle\" style=\"animation-delay:6.79s\">红色旗面 · 象征革命</text></g></svg>";
    var CSS = ".nb-tf-row{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:stretch;}\n.nb-tf-left{min-width:0;align-self:start;}\n.nb-tf-right{min-width:0;display:flex;flex-direction:column;}\n.nb-tf-codewrap{flex:1;display:flex;flex-direction:column;min-height:0;border-radius:12px;background:rgba(0,0,0,.3);border:1px solid rgba(255,210,74,.2);overflow:hidden;}\n.nb-tf-codehead{display:flex;align-items:center;gap:8px;padding:11px 14px;font-size:.76rem;letter-spacing:1px;color:rgba(255,226,170,.8);flex:0 0 auto;}\n.nb-tf-codehead .sp{flex:1;min-width:0;}\n.nb-tf-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(255,210,74,.12);border:1px solid rgba(255,210,74,.3);color:#ffd24a;transition:.2s;}\n.nb-tf-mini:hover{background:rgba(255,210,74,.22);}\n.nb-tf-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}\n.nb-tf-code{flex:1;min-height:0;margin:0;padding:0 14px 14px;font:11.5px/1.85 ui-monospace,Consolas,'Courier New',monospace;color:rgba(255,232,200,.66);white-space:pre;overflow:hidden;-webkit-mask-image:linear-gradient(to bottom,#000 0,#000 52%,rgba(0,0,0,.35) 78%,transparent 100%);mask-image:linear-gradient(to bottom,#000 0,#000 52%,rgba(0,0,0,.35) 78%,transparent 100%);}\n.nb-tf-codewrap.open .nb-tf-code{overflow:auto;-webkit-mask-image:none;mask-image:none;}\n  display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:start;}\n.nb-tf-bar{display:flex;align-items:center;gap:7px;margin-bottom:10px;\n  font-size:.76rem;letter-spacing:1.2px;color:rgba(255,226,170,.75);}\n.nb-tf-bar i{font-style:normal;opacity:.6;}\n.nb-tf-svg{display:block;width:100%;height:auto;border-radius:12px;\n  box-shadow:0 34px 80px -44px rgba(0,0,0,.95),0 0 0 1px rgba(255,210,74,.2);}\n  border:1px solid rgba(255,210,74,.2);\n  font:11.5px/1.85 ui-monospace,Consolas,\"Courier New\",monospace;\n  color:rgba(255,232,200,.66);white-space:pre;overflow-x:auto;}\n.nb-tf-code b{color:#ffd24a;font-weight:600;}\n.nb-tf-code em{color:rgba(255,232,200,.4);font-style:normal;}\n.nb-tf-fill{opacity:0;animation:nbTfFill .7s ease forwards;animation-delay:0.88s;}\n@keyframes nbTfFill{to{opacity:1;}}\n.nb-tf-star{fill:#ffde00;opacity:0;animation:nbTfStar .45s ease forwards;}\n@keyframes nbTfStar{to{opacity:1;}}\n.nb-tf-stroke line{stroke:#ffd400;stroke-width:1.7;stroke-linecap:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfDraw 0.22s linear forwards;}\n@keyframes nbTfDraw{to{stroke-dashoffset:0;}}\n.nb-tf-pen circle{fill:#fff6d8;opacity:0;animation:nbTfPen .5s ease forwards;}\n@keyframes nbTfPen{0%{opacity:1;r:3.4;}100%{opacity:0;r:1.4;}}\n.nb-tf-lead{stroke:rgba(255,210,74,.72);stroke-width:1.1;stroke-linecap:round;\n  stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfLead .26s linear forwards;}\n@keyframes nbTfLead{to{stroke-dashoffset:0;}}\n.nb-tf-dot{fill:#ffd24a;opacity:0;animation:nbTfDot .3s ease forwards;}\n@keyframes nbTfDot{to{opacity:1;}}\n.nb-tf-label{fill:#ffd24a;font:12.5px/1 -apple-system,\"Segoe UI\",\"Microsoft YaHei\",sans-serif;\n  letter-spacing:.5px;opacity:0;animation:nbTfLabel .45s ease forwards;}\n@keyframes nbTfLabel{to{opacity:1;}}\n@media(max-width:900px){.nb-tf-row{grid-template-columns:1fr;gap:22px;margin-top:44px;}.nb-tf-code{font-size:10px;}}\n@media(prefers-reduced-motion:reduce){\n  .nb-tf-stroke line,.nb-tf-lead{animation:none;stroke-dashoffset:0;}\n  .nb-tf-fill,.nb-tf-star,.nb-tf-dot,.nb-tf-label{animation:none;opacity:1;}\n  .nb-tf-pen circle{display:none;}\n}\n.nb-tf-codehead .sp{flex:1;min-width:0;}\n.nb-tf-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(255,210,74,.12);border:1px solid rgba(255,210,74,.3);color:#ffd24a;transition:.2s;}\n.nb-tf-mini:hover{background:rgba(255,210,74,.22);}\n.nb-tf-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}";
    var CODE = "<b>import</b> turtle <b>as</b> t, math\n\n<em># 旗面：turtle 原点在画布中心，从 (-150,-100) 起画 300x200</em>\nt.penup(); t.goto(-150, -100); t.pendown()\nt.color(<em>\"#de2910\"</em>, <em>\"#de2910\"</em>); t.begin_fill()\n<b>for</b> _ <b>in</b> range(2):\n    t.forward(300); t.left(90)\n    t.forward(200); t.left(90)\nt.end_fill()\n\n<b>def</b> star(cx, cy, R, rot=0):\n    <em>\"\"\"以(cx,cy)为中心、R为外接圆半径，画实心五角星\"\"\"</em>\n    pts = []\n    <b>for</b> i <b>in</b> range(5):\n        a = math.radians(rot + i * 144 - 90)\n        pts.append((cx + R*math.cos(a), cy + R*math.sin(a)))\n    t.penup(); t.goto(pts[0]); t.pendown()\n    t.color(<em>\"#ffde00\"</em>, <em>\"#ffde00\"</em>)\n    t.begin_fill()\n    <b>for</b> p <b>in</b> pts[1:]: t.goto(p)\n    t.goto(pts[0])\n    t.end_fill()\n\nstar(-100, 50, 30)                 <em># 大星：中国共产党</em>\nSMALL = [(-50,80), (-30,60), (-30,30), (-50,10)]\n<em># 四颗小星依次为：工人、农民、城市小资产阶级、民族资产阶级</em>\n<b>for</b> cx, cy <b>in</b> SMALL:\n    rot = math.degrees(math.atan2(-100-cx, 50-cy))\n    star(cx, cy, 10, rot)          <em># 各有一角指向大星</em>\nt.done()";
    var PLAIN = "import turtle as t, math\n\n# 旗面：turtle 原点在画布中心，从 (-150,-100) 起画 300x200\nt.penup(); t.goto(-150, -100); t.pendown()\nt.color(\"#de2910\", \"#de2910\"); t.begin_fill()\nfor _ in range(2):\n    t.forward(300); t.left(90)\n    t.forward(200); t.left(90)\nt.end_fill()\n\ndef star(cx, cy, R, rot=0):\n    \"\"\"以(cx,cy)为中心、R为外接圆半径，画实心五角星\"\"\"\n    pts = []\n    for i in range(5):\n        a = math.radians(rot + i * 144 - 90)\n        pts.append((cx + R*math.cos(a), cy + R*math.sin(a)))\n    t.penup(); t.goto(pts[0]); t.pendown()\n    t.color(\"#ffde00\", \"#ffde00\")\n    t.begin_fill()\n    for p in pts[1:]: t.goto(p)\n    t.goto(pts[0])\n    t.end_fill()\n\nstar(-100, 50, 30)                 # 大星：中国共产党\nSMALL = [(-50,80), (-30,60), (-30,30), (-50,10)]\n# 四颗小星依次为：工人、农民、城市小资产阶级、民族资产阶级\nfor cx, cy in SMALL:\n    rot = math.degrees(math.atan2(-100-cx, 50-cy))\n    star(cx, cy, 10, rot)          # 各有一角指向大星\nt.done()";

    function mount() {
        try {
            if (document.documentElement.getAttribute('theme') !== 'national') return;
            if (document.getElementById('nbTurtleRow')) return;
            var inner = document.querySelector('.hero-inner');
            var hero = document.querySelector('.hero');
            if (!inner || !hero) return;

            if (!document.getElementById('nbTurtleFlagCss')) {
                var st = document.createElement('style');
                st.id = 'nbTurtleFlagCss';
                st.textContent = CSS;
                document.head.appendChild(st);
            }

            var row = document.createElement('div');
            row.id = 'nbTurtleRow';
            row.className = 'nb-tf-row';

            /* ---- 左：国旗动画 ---- */
            var left = document.createElement('div');
            left.className = 'nb-tf-left';
            var bar = document.createElement('div');
            bar.className = 'nb-tf-bar';
            bar.innerHTML = '\uD83D\uDC22 Python \u6D77\u9F9F\u7ED8\u56FE <i>\u00B7 \u753B\u4E94\u661F\u7EA2\u65D7</i>';
            var svgWrap = document.createElement('div');
            svgWrap.innerHTML = SVG;
            left.appendChild(bar);
            left.appendChild(svgWrap.firstChild);

            /* ---- 右：可折叠的代码面板 ---- */
            var right = document.createElement('div');
            right.className = 'nb-tf-right';

            var wrap = document.createElement('div');
            wrap.className = 'nb-tf-codewrap';

            var head = document.createElement('div');
            head.className = 'nb-tf-codehead';
            var title = document.createElement('span');
            title.className = 'sp';
            title.textContent = '\uD83D\uDCCB Python \u6E90\u7801';
            var copyBtn = document.createElement('button');
            copyBtn.type = 'button';
            copyBtn.className = 'nb-tf-mini';
            copyBtn.textContent = '\u590D\u5236';
            var toggleBtn = document.createElement('button');
            toggleBtn.type = 'button';
            toggleBtn.className = 'nb-tf-mini';
            toggleBtn.textContent = '\u5C55\u5F00 \u25BE';
            head.appendChild(title);
            head.appendChild(copyBtn);
            head.appendChild(toggleBtn);

            var pre = document.createElement('pre');
            pre.className = 'nb-tf-code';
            pre.innerHTML = CODE;

            wrap.appendChild(head);
            wrap.appendChild(pre);
            right.appendChild(wrap);

            toggleBtn.onclick = function () {
                var on = wrap.classList.toggle('open');
                toggleBtn.textContent = on ? '\u6536\u8D77 \u25B4' : '\u5C55\u5F00 \u25BE';
            };

            copyBtn.onclick = function () {
                function done() {
                    copyBtn.textContent = '\u5DF2\u590D\u5236 \u2713';
                    copyBtn.classList.add('done');
                    setTimeout(function () {
                        copyBtn.textContent = '\u590D\u5236';
                        copyBtn.classList.remove('done');
                    }, 1600);
                }
                function fallback() {
                    try {
                        var ta = document.createElement('textarea');
                        ta.value = PLAIN;
                        ta.style.cssText = 'position:fixed;left:-9999px;top:0;';
                        document.body.appendChild(ta);
                        ta.select();
                        document.execCommand('copy');
                        document.body.removeChild(ta);
                        done();
                    } catch (e2) { copyBtn.textContent = '\u590D\u5236\u5931\u8D25'; }
                }
                try {
                    if (navigator.clipboard && navigator.clipboard.writeText) {
                        navigator.clipboard.writeText(PLAIN).then(done, fallback);
                    } else { fallback(); }
                } catch (e) { fallback(); }
            };

            row.appendChild(left);
            row.appendChild(right);

            var scroll = hero.querySelector('.hero-scroll');
            if (scroll && scroll.parentNode === hero) hero.insertBefore(row, scroll);
            else inner.parentNode.insertBefore(row, inner.nextSibling);
        } catch (e) {}
    }

    function unmount() {
        var el = document.getElementById('nbTurtleRow');
        if (el && el.parentNode) el.parentNode.removeChild(el);
    }

    function boot() {
        mount();
        window.addEventListener('nb-theme-change', function () { unmount(); mount(); });
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})();
