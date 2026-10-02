/* NB频道 · 国庆主题：Python 海龟绘图 · 画五星红旗（含六条释义引线）
   画布 600x370；国旗放大到 380x253；Hero 下半部分一行：国旗动画在左、代码面板在右。
   代码面板默认折叠（宽度与左列国旗一致），可展开、可一键复制。
   时间轴：旗面 -> 大星 -> 四颗小星（同步）-> 六条引线逐条。跑完静止。*/
(function () {
    'use strict';
    var SVG = "<svg class=\"nb-tf-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 600 370\" width=\"600\" height=\"370\" role=\"img\" aria-label=\"Python 海龟绘图画出五星红旗，并标注各部分含义\"><rect width=\"600\" height=\"370\" fill=\"#0b1220\" rx=\"12\"/><rect class=\"nb-tf-fill\" x=\"100.0\" y=\"56.0\" width=\"400.0\" height=\"266.7\" fill=\"#de2910\" rx=\"5\"/><polygon class=\"nb-tf-star\" points=\"166.67,82.68 175.65,110.32 204.71,110.32 181.20,127.40 190.18,155.04 166.67,137.96 143.16,155.04 152.14,127.40 128.62,110.32 157.69,110.32\" style=\"animation-delay:3.08s\"/><polygon class=\"nb-tf-star\" points=\"221.90,89.54 228.26,82.24 223.28,73.93 232.19,77.72 238.55,70.41 237.70,80.06 246.62,83.85 237.17,86.03 236.32,95.68 231.34,87.37\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"246.80,111.24 255.50,106.97 254.13,97.38 260.87,104.33 269.57,100.07 265.04,108.63 271.79,115.58 262.24,113.92 257.71,122.49 256.34,112.90\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"247.18,145.69 256.86,145.34 259.52,136.03 262.84,145.13 272.52,144.78 264.90,150.75 268.22,159.85 260.18,154.44 252.55,160.41 255.22,151.10\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"222.92,167.69 231.99,171.11 238.04,163.54 237.59,173.22 246.65,176.64 237.31,179.20 236.86,188.87 231.54,180.78 222.19,183.34 228.25,175.78\" style=\"animation-delay:5.28s\"/><g class=\"nb-tf-stroke\"><line x1=\"100.00\" y1=\"322.68\" x2=\"500.00\" y2=\"322.68\" style=\"--len:400.00;animation-delay:0.00s\"/><line x1=\"500.00\" y1=\"322.68\" x2=\"500.00\" y2=\"56.02\" style=\"--len:266.67;animation-delay:0.22s\"/><line x1=\"500.00\" y1=\"56.02\" x2=\"100.00\" y2=\"56.02\" style=\"--len:400.00;animation-delay:0.44s\"/><line x1=\"100.00\" y1=\"56.02\" x2=\"100.00\" y2=\"322.68\" style=\"--len:266.67;animation-delay:0.66s\"/><line x1=\"166.67\" y1=\"82.68\" x2=\"175.65\" y2=\"110.32\" style=\"--len:29.06;animation-delay:0.88s\"/><line x1=\"175.65\" y1=\"110.32\" x2=\"204.71\" y2=\"110.32\" style=\"--len:29.06;animation-delay:1.10s\"/><line x1=\"204.71\" y1=\"110.32\" x2=\"181.20\" y2=\"127.40\" style=\"--len:29.06;animation-delay:1.32s\"/><line x1=\"181.20\" y1=\"127.40\" x2=\"190.18\" y2=\"155.04\" style=\"--len:29.06;animation-delay:1.54s\"/><line x1=\"190.18\" y1=\"155.04\" x2=\"166.67\" y2=\"137.96\" style=\"--len:29.06;animation-delay:1.76s\"/><line x1=\"166.67\" y1=\"137.96\" x2=\"143.16\" y2=\"155.04\" style=\"--len:29.06;animation-delay:1.98s\"/><line x1=\"143.16\" y1=\"155.04\" x2=\"152.14\" y2=\"127.40\" style=\"--len:29.06;animation-delay:2.20s\"/><line x1=\"152.14\" y1=\"127.40\" x2=\"128.62\" y2=\"110.32\" style=\"--len:29.06;animation-delay:2.42s\"/><line x1=\"128.62\" y1=\"110.32\" x2=\"157.69\" y2=\"110.32\" style=\"--len:29.06;animation-delay:2.64s\"/><line x1=\"157.69\" y1=\"110.32\" x2=\"166.67\" y2=\"82.68\" style=\"--len:29.06;animation-delay:2.86s\"/><line x1=\"221.90\" y1=\"89.54\" x2=\"228.26\" y2=\"82.24\" style=\"--len:9.69;animation-delay:3.08s\"/><line x1=\"228.26\" y1=\"82.24\" x2=\"223.28\" y2=\"73.93\" style=\"--len:9.69;animation-delay:3.30s\"/><line x1=\"223.28\" y1=\"73.93\" x2=\"232.19\" y2=\"77.72\" style=\"--len:9.69;animation-delay:3.52s\"/><line x1=\"232.19\" y1=\"77.72\" x2=\"238.55\" y2=\"70.41\" style=\"--len:9.69;animation-delay:3.74s\"/><line x1=\"238.55\" y1=\"70.41\" x2=\"237.70\" y2=\"80.06\" style=\"--len:9.69;animation-delay:3.96s\"/><line x1=\"237.70\" y1=\"80.06\" x2=\"246.62\" y2=\"83.85\" style=\"--len:9.69;animation-delay:4.18s\"/><line x1=\"246.62\" y1=\"83.85\" x2=\"237.17\" y2=\"86.03\" style=\"--len:9.69;animation-delay:4.40s\"/><line x1=\"237.17\" y1=\"86.03\" x2=\"236.32\" y2=\"95.68\" style=\"--len:9.69;animation-delay:4.62s\"/><line x1=\"236.32\" y1=\"95.68\" x2=\"231.34\" y2=\"87.37\" style=\"--len:9.69;animation-delay:4.84s\"/><line x1=\"231.34\" y1=\"87.37\" x2=\"221.90\" y2=\"89.54\" style=\"--len:9.69;animation-delay:5.06s\"/><line x1=\"246.80\" y1=\"111.24\" x2=\"255.50\" y2=\"106.97\" style=\"--len:9.69;animation-delay:3.08s\"/><line x1=\"255.50\" y1=\"106.97\" x2=\"254.13\" y2=\"97.38\" style=\"--len:9.69;animation-delay:3.30s\"/><line x1=\"254.13\" y1=\"97.38\" x2=\"260.87\" y2=\"104.33\" style=\"--len:9.69;animation-delay:3.52s\"/><line x1=\"260.87\" y1=\"104.33\" x2=\"269.57\" y2=\"100.07\" style=\"--len:9.69;animation-delay:3.74s\"/><line x1=\"269.57\" y1=\"100.07\" x2=\"265.04\" y2=\"108.63\" style=\"--len:9.69;animation-delay:3.96s\"/><line x1=\"265.04\" y1=\"108.63\" x2=\"271.79\" y2=\"115.58\" style=\"--len:9.69;animation-delay:4.18s\"/><line x1=\"271.79\" y1=\"115.58\" x2=\"262.24\" y2=\"113.92\" style=\"--len:9.69;animation-delay:4.40s\"/><line x1=\"262.24\" y1=\"113.92\" x2=\"257.71\" y2=\"122.49\" style=\"--len:9.69;animation-delay:4.62s\"/><line x1=\"257.71\" y1=\"122.49\" x2=\"256.34\" y2=\"112.90\" style=\"--len:9.69;animation-delay:4.84s\"/><line x1=\"256.34\" y1=\"112.90\" x2=\"246.80\" y2=\"111.24\" style=\"--len:9.69;animation-delay:5.06s\"/><line x1=\"247.18\" y1=\"145.69\" x2=\"256.86\" y2=\"145.34\" style=\"--len:9.69;animation-delay:3.08s\"/><line x1=\"256.86\" y1=\"145.34\" x2=\"259.52\" y2=\"136.03\" style=\"--len:9.69;animation-delay:3.30s\"/><line x1=\"259.52\" y1=\"136.03\" x2=\"262.84\" y2=\"145.13\" style=\"--len:9.69;animation-delay:3.52s\"/><line x1=\"262.84\" y1=\"145.13\" x2=\"272.52\" y2=\"144.78\" style=\"--len:9.69;animation-delay:3.74s\"/><line x1=\"272.52\" y1=\"144.78\" x2=\"264.90\" y2=\"150.75\" style=\"--len:9.69;animation-delay:3.96s\"/><line x1=\"264.90\" y1=\"150.75\" x2=\"268.22\" y2=\"159.85\" style=\"--len:9.69;animation-delay:4.18s\"/><line x1=\"268.22\" y1=\"159.85\" x2=\"260.18\" y2=\"154.44\" style=\"--len:9.69;animation-delay:4.40s\"/><line x1=\"260.18\" y1=\"154.44\" x2=\"252.55\" y2=\"160.41\" style=\"--len:9.69;animation-delay:4.62s\"/><line x1=\"252.55\" y1=\"160.41\" x2=\"255.22\" y2=\"151.10\" style=\"--len:9.69;animation-delay:4.84s\"/><line x1=\"255.22\" y1=\"151.10\" x2=\"247.18\" y2=\"145.69\" style=\"--len:9.69;animation-delay:5.06s\"/><line x1=\"222.92\" y1=\"167.69\" x2=\"231.99\" y2=\"171.11\" style=\"--len:9.69;animation-delay:3.08s\"/><line x1=\"231.99\" y1=\"171.11\" x2=\"238.04\" y2=\"163.54\" style=\"--len:9.69;animation-delay:3.30s\"/><line x1=\"238.04\" y1=\"163.54\" x2=\"237.59\" y2=\"173.22\" style=\"--len:9.69;animation-delay:3.52s\"/><line x1=\"237.59\" y1=\"173.22\" x2=\"246.65\" y2=\"176.64\" style=\"--len:9.69;animation-delay:3.74s\"/><line x1=\"246.65\" y1=\"176.64\" x2=\"237.31\" y2=\"179.20\" style=\"--len:9.69;animation-delay:3.96s\"/><line x1=\"237.31\" y1=\"179.20\" x2=\"236.86\" y2=\"188.87\" style=\"--len:9.69;animation-delay:4.18s\"/><line x1=\"236.86\" y1=\"188.87\" x2=\"231.54\" y2=\"180.78\" style=\"--len:9.69;animation-delay:4.40s\"/><line x1=\"231.54\" y1=\"180.78\" x2=\"222.19\" y2=\"183.34\" style=\"--len:9.69;animation-delay:4.62s\"/><line x1=\"222.19\" y1=\"183.34\" x2=\"228.25\" y2=\"175.78\" style=\"--len:9.69;animation-delay:4.84s\"/><line x1=\"228.25\" y1=\"175.78\" x2=\"222.92\" y2=\"167.69\" style=\"--len:9.69;animation-delay:5.06s\"/></g><g class=\"nb-tf-pen\"><circle cx=\"500.00\" cy=\"322.68\" r=\"2.4\" style=\"animation-delay:0.22s\"/><circle cx=\"500.00\" cy=\"56.02\" r=\"2.4\" style=\"animation-delay:0.44s\"/><circle cx=\"100.00\" cy=\"56.02\" r=\"2.4\" style=\"animation-delay:0.66s\"/><circle cx=\"100.00\" cy=\"322.68\" r=\"2.4\" style=\"animation-delay:0.88s\"/><circle cx=\"175.65\" cy=\"110.32\" r=\"2.4\" style=\"animation-delay:1.10s\"/><circle cx=\"204.71\" cy=\"110.32\" r=\"2.4\" style=\"animation-delay:1.32s\"/><circle cx=\"181.20\" cy=\"127.40\" r=\"2.4\" style=\"animation-delay:1.54s\"/><circle cx=\"190.18\" cy=\"155.04\" r=\"2.4\" style=\"animation-delay:1.76s\"/><circle cx=\"166.67\" cy=\"137.96\" r=\"2.4\" style=\"animation-delay:1.98s\"/><circle cx=\"143.16\" cy=\"155.04\" r=\"2.4\" style=\"animation-delay:2.20s\"/><circle cx=\"152.14\" cy=\"127.40\" r=\"2.4\" style=\"animation-delay:2.42s\"/><circle cx=\"128.62\" cy=\"110.32\" r=\"2.4\" style=\"animation-delay:2.64s\"/><circle cx=\"157.69\" cy=\"110.32\" r=\"2.4\" style=\"animation-delay:2.86s\"/><circle cx=\"166.67\" cy=\"82.68\" r=\"2.4\" style=\"animation-delay:3.08s\"/><circle cx=\"228.26\" cy=\"82.24\" r=\"2.4\" style=\"animation-delay:3.30s\"/><circle cx=\"223.28\" cy=\"73.93\" r=\"2.4\" style=\"animation-delay:3.52s\"/><circle cx=\"232.19\" cy=\"77.72\" r=\"2.4\" style=\"animation-delay:3.74s\"/><circle cx=\"238.55\" cy=\"70.41\" r=\"2.4\" style=\"animation-delay:3.96s\"/><circle cx=\"237.70\" cy=\"80.06\" r=\"2.4\" style=\"animation-delay:4.18s\"/><circle cx=\"246.62\" cy=\"83.85\" r=\"2.4\" style=\"animation-delay:4.40s\"/><circle cx=\"237.17\" cy=\"86.03\" r=\"2.4\" style=\"animation-delay:4.62s\"/><circle cx=\"236.32\" cy=\"95.68\" r=\"2.4\" style=\"animation-delay:4.84s\"/><circle cx=\"231.34\" cy=\"87.37\" r=\"2.4\" style=\"animation-delay:5.06s\"/><circle cx=\"221.90\" cy=\"89.54\" r=\"2.4\" style=\"animation-delay:5.28s\"/><circle cx=\"255.50\" cy=\"106.97\" r=\"2.4\" style=\"animation-delay:3.30s\"/><circle cx=\"254.13\" cy=\"97.38\" r=\"2.4\" style=\"animation-delay:3.52s\"/><circle cx=\"260.87\" cy=\"104.33\" r=\"2.4\" style=\"animation-delay:3.74s\"/><circle cx=\"269.57\" cy=\"100.07\" r=\"2.4\" style=\"animation-delay:3.96s\"/><circle cx=\"265.04\" cy=\"108.63\" r=\"2.4\" style=\"animation-delay:4.18s\"/><circle cx=\"271.79\" cy=\"115.58\" r=\"2.4\" style=\"animation-delay:4.40s\"/><circle cx=\"262.24\" cy=\"113.92\" r=\"2.4\" style=\"animation-delay:4.62s\"/><circle cx=\"257.71\" cy=\"122.49\" r=\"2.4\" style=\"animation-delay:4.84s\"/><circle cx=\"256.34\" cy=\"112.90\" r=\"2.4\" style=\"animation-delay:5.06s\"/><circle cx=\"246.80\" cy=\"111.24\" r=\"2.4\" style=\"animation-delay:5.28s\"/><circle cx=\"256.86\" cy=\"145.34\" r=\"2.4\" style=\"animation-delay:3.30s\"/><circle cx=\"259.52\" cy=\"136.03\" r=\"2.4\" style=\"animation-delay:3.52s\"/><circle cx=\"262.84\" cy=\"145.13\" r=\"2.4\" style=\"animation-delay:3.74s\"/><circle cx=\"272.52\" cy=\"144.78\" r=\"2.4\" style=\"animation-delay:3.96s\"/><circle cx=\"264.90\" cy=\"150.75\" r=\"2.4\" style=\"animation-delay:4.18s\"/><circle cx=\"268.22\" cy=\"159.85\" r=\"2.4\" style=\"animation-delay:4.40s\"/><circle cx=\"260.18\" cy=\"154.44\" r=\"2.4\" style=\"animation-delay:4.62s\"/><circle cx=\"252.55\" cy=\"160.41\" r=\"2.4\" style=\"animation-delay:4.84s\"/><circle cx=\"255.22\" cy=\"151.10\" r=\"2.4\" style=\"animation-delay:5.06s\"/><circle cx=\"247.18\" cy=\"145.69\" r=\"2.4\" style=\"animation-delay:5.28s\"/><circle cx=\"231.99\" cy=\"171.11\" r=\"2.4\" style=\"animation-delay:3.30s\"/><circle cx=\"238.04\" cy=\"163.54\" r=\"2.4\" style=\"animation-delay:3.52s\"/><circle cx=\"237.59\" cy=\"173.22\" r=\"2.4\" style=\"animation-delay:3.74s\"/><circle cx=\"246.65\" cy=\"176.64\" r=\"2.4\" style=\"animation-delay:3.96s\"/><circle cx=\"237.31\" cy=\"179.20\" r=\"2.4\" style=\"animation-delay:4.18s\"/><circle cx=\"236.86\" cy=\"188.87\" r=\"2.4\" style=\"animation-delay:4.40s\"/><circle cx=\"231.54\" cy=\"180.78\" r=\"2.4\" style=\"animation-delay:4.62s\"/><circle cx=\"222.19\" cy=\"183.34\" r=\"2.4\" style=\"animation-delay:4.84s\"/><circle cx=\"228.25\" cy=\"175.78\" r=\"2.4\" style=\"animation-delay:5.06s\"/><circle cx=\"222.92\" cy=\"167.69\" r=\"2.4\" style=\"animation-delay:5.28s\"/></g><g class=\"nb-tf-leads\"><polyline class=\"nb-tf-lead\" points=\"118.7,94.7 52.0,44.0 6.0,44.0\" style=\"--len:129.7;animation-delay:5.43s\"/><circle class=\"nb-tf-dot\" cx=\"118.7\" cy=\"94.7\" r=\"2.6\" style=\"animation-delay:5.43s\"/><text class=\"nb-tf-label\" x=\"6.0\" y=\"35.0\" text-anchor=\"start\" style=\"animation-delay:5.59s\">中国共产党</text><polyline class=\"nb-tf-lead\" points=\"247.3,71.7 470.0,34.0 508.0,34.0\" style=\"--len:263.8;animation-delay:5.67s\"/><circle class=\"nb-tf-dot\" cx=\"247.3\" cy=\"71.7\" r=\"2.6\" style=\"animation-delay:5.67s\"/><text class=\"nb-tf-label\" x=\"508.0\" y=\"25.0\" text-anchor=\"start\" style=\"animation-delay:5.83s\">工人阶级</text><polyline class=\"nb-tf-lead\" points=\"275.0,110.3 478.0,92.0 508.0,92.0\" style=\"--len:233.8;animation-delay:5.91s\"/><circle class=\"nb-tf-dot\" cx=\"275.0\" cy=\"110.3\" r=\"2.6\" style=\"animation-delay:5.91s\"/><text class=\"nb-tf-label\" x=\"508.0\" y=\"83.0\" text-anchor=\"start\" style=\"animation-delay:6.07s\">农民阶级</text><polyline class=\"nb-tf-lead\" points=\"275.0,148.3 478.0,150.0 508.0,150.0\" style=\"--len:233.0;animation-delay:6.15s\"/><circle class=\"nb-tf-dot\" cx=\"275.0\" cy=\"148.3\" r=\"2.6\" style=\"animation-delay:6.15s\"/><text class=\"nb-tf-label\" x=\"508.0\" y=\"141.0\" text-anchor=\"start\" style=\"animation-delay:6.31s\">城市小资产阶级</text><polyline class=\"nb-tf-lead\" points=\"247.3,187.0 470.0,208.0 508.0,208.0\" style=\"--len:261.7;animation-delay:6.39s\"/><circle class=\"nb-tf-dot\" cx=\"247.3\" cy=\"187.0\" r=\"2.6\" style=\"animation-delay:6.39s\"/><text class=\"nb-tf-label\" x=\"508.0\" y=\"199.0\" text-anchor=\"start\" style=\"animation-delay:6.55s\">民族资产阶级</text><polyline class=\"nb-tf-lead\" points=\"300.0,329.7 300.0,322.0 382.0,322.0\" style=\"--len:89.7;animation-delay:6.63s\"/><circle class=\"nb-tf-dot\" cx=\"300.0\" cy=\"329.7\" r=\"2.6\" style=\"animation-delay:6.63s\"/><text class=\"nb-tf-label\" x=\"382.0\" y=\"349.0\" text-anchor=\"middle\" style=\"animation-delay:6.79s\">红色旗面 · 象征革命</text></g></svg>";
    var CSS = ".nb-tf-row{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:stretch;}\n.nb-tf-left{min-width:0;align-self:start;}\n.nb-tf-right{min-width:0;display:flex;flex-direction:column;}\n.nb-tf-codewrap{flex:1;display:flex;flex-direction:column;min-height:0;border-radius:12px;background:rgba(0,0,0,.3);border:1px solid rgba(255,210,74,.2);overflow:hidden;}\n.nb-tf-codehead{display:flex;align-items:center;gap:8px;padding:11px 14px;font-size:.76rem;letter-spacing:1px;color:rgba(255,226,170,.8);flex:0 0 auto;}\n.nb-tf-codehead .sp{flex:1;min-width:0;}\n.nb-tf-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(255,210,74,.12);border:1px solid rgba(255,210,74,.3);color:#ffd24a;transition:.2s;}\n.nb-tf-mini:hover{background:rgba(255,210,74,.22);}\n.nb-tf-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}\n.nb-tf-code{flex:1;min-height:0;margin:0;padding:0 14px 14px;font:11.5px/1.85 ui-monospace,Consolas,'Courier New',monospace;color:rgba(255,232,200,.66);white-space:pre;overflow:hidden;-webkit-mask-image:linear-gradient(to bottom,#000 0,#000 52%,rgba(0,0,0,.35) 78%,transparent 100%);mask-image:linear-gradient(to bottom,#000 0,#000 52%,rgba(0,0,0,.35) 78%,transparent 100%);}\n.nb-tf-codewrap.open .nb-tf-code{overflow:auto;-webkit-mask-image:none;mask-image:none;}\n  display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:start;}\n.nb-tf-bar{display:flex;align-items:center;gap:7px;margin-bottom:10px;\n  font-size:.76rem;letter-spacing:1.2px;color:rgba(255,226,170,.75);}\n.nb-tf-bar i{font-style:normal;opacity:.6;}\n.nb-tf-svg{display:block;width:100%;height:auto;border-radius:12px;\n  box-shadow:0 34px 80px -44px rgba(0,0,0,.95),0 0 0 1px rgba(255,210,74,.2);}\n  border:1px solid rgba(255,210,74,.2);\n  font:11.5px/1.85 ui-monospace,Consolas,\"Courier New\",monospace;\n  color:rgba(255,232,200,.66);white-space:pre;overflow-x:auto;}\n.nb-tf-code b{color:#ffd24a;font-weight:600;}\n.nb-tf-code em{color:rgba(255,232,200,.4);font-style:normal;}\n.nb-tf-fill{opacity:0;animation:nbTfFill .7s ease forwards;animation-delay:0.88s;}\n@keyframes nbTfFill{to{opacity:1;}}\n.nb-tf-star{fill:#ffde00;opacity:0;animation:nbTfStar .45s ease forwards;}\n@keyframes nbTfStar{to{opacity:1;}}\n.nb-tf-stroke line{stroke:#ffd400;stroke-width:1.7;stroke-linecap:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfDraw 0.22s linear forwards;}\n@keyframes nbTfDraw{to{stroke-dashoffset:0;}}\n.nb-tf-pen circle{fill:#fff6d8;opacity:0;animation:nbTfPen .5s ease forwards;}\n@keyframes nbTfPen{0%{opacity:1;r:3.4;}100%{opacity:0;r:1.4;}}\n.nb-tf-lead{fill:none;stroke:rgba(255,210,74,.72);stroke-width:1.1;stroke-linecap:round;\n  stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfLead .26s linear forwards;}\n@keyframes nbTfLead{to{stroke-dashoffset:0;}}\n.nb-tf-dot{fill:#ffd24a;stroke:none;opacity:0;animation:nbTfDot .3s ease forwards;}\n@keyframes nbTfDot{to{opacity:1;}}\n.nb-tf-label{fill:#ffd24a;font:12.5px/1 -apple-system,\"Segoe UI\",\"Microsoft YaHei\",sans-serif;\n  letter-spacing:.5px;opacity:0;animation:nbTfLabel .45s ease forwards;}\n@keyframes nbTfLabel{to{opacity:1;}}\n@media(max-width:900px){.nb-tf-row{grid-template-columns:1fr;gap:22px;margin-top:44px;}.nb-tf-code{font-size:10px;}}\n@media(prefers-reduced-motion:reduce){\n  .nb-tf-stroke line,.nb-tf-lead{animation:none;stroke-dashoffset:0;}\n  .nb-tf-fill,.nb-tf-star,.nb-tf-dot,.nb-tf-label{animation:none;opacity:1;}\n  .nb-tf-pen circle{display:none;}\n}\n.nb-tf-codehead .sp{flex:1;min-width:0;}\n.nb-tf-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(255,210,74,.12);border:1px solid rgba(255,210,74,.3);color:#ffd24a;transition:.2s;}\n.nb-tf-mini:hover{background:rgba(255,210,74,.22);}\n.nb-tf-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}";
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
