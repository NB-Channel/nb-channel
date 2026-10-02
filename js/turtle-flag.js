/* NB频道 · 国庆主题：Python 海龟绘图 · 画五星红旗（含六条释义引线）
   画布 600x370；国旗放大到 380x253；Hero 下半部分一行：国旗动画在左、代码面板在右。
   代码面板默认折叠（宽度与左列国旗一致），可展开、可一键复制。
   时间轴：旗面 -> 大星 -> 四颗小星（同步）-> 六条引线逐条。跑完静止。*/
(function () {
    'use strict';
    var SVG = "<svg class=\"nb-tf-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 760 420\" width=\"760\" height=\"420\" role=\"img\" aria-label=\"Python 海龟绘图画出五星红旗，并标注各部分含义\"><rect class=\"nb-tf-fill\" x=\"124.0\" y=\"40.0\" width=\"512.0\" height=\"341.3\" fill=\"#de2910\" rx=\"4\"/><polygon class=\"nb-tf-star\" points=\"209.33,74.12 220.83,109.49 258.03,109.49 227.93,131.36 239.43,166.74 209.33,144.87 179.24,166.74 190.73,131.36 160.64,109.49 197.84,109.49\" style=\"animation-delay:3.08s\"/><polygon class=\"nb-tf-star\" points=\"280.03,82.90 288.17,73.54 281.79,62.91 293.20,67.76 301.35,58.41 300.26,70.76 311.67,75.61 299.58,78.40 298.50,90.75 292.12,80.12\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"311.90,110.66 323.04,105.20 321.28,92.93 329.92,101.83 341.05,96.37 335.25,107.33 343.89,116.23 331.67,114.10 325.87,125.06 324.12,112.79\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"312.39,154.76 324.78,154.32 328.19,142.39 332.44,154.04 344.83,153.60 335.07,161.24 339.32,172.89 329.03,165.96 319.27,173.61 322.68,161.69\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"281.34,182.92 292.94,187.30 300.69,177.61 300.11,190.00 311.71,194.38 299.76,197.66 299.18,210.04 292.37,199.68 280.41,202.96 288.15,193.28\" style=\"animation-delay:5.28s\"/><g class=\"nb-tf-stroke\"><line x1=\"124.00\" y1=\"381.32\" x2=\"636.00\" y2=\"381.32\" style=\"--len:512.00;animation-delay:0.00s,1.03s\"/><line x1=\"636.00\" y1=\"381.32\" x2=\"636.00\" y2=\"39.98\" style=\"--len:341.33;animation-delay:0.22s,1.03s\"/><line x1=\"636.00\" y1=\"39.98\" x2=\"124.00\" y2=\"39.98\" style=\"--len:512.00;animation-delay:0.44s,1.03s\"/><line x1=\"124.00\" y1=\"39.98\" x2=\"124.00\" y2=\"381.32\" style=\"--len:341.33;animation-delay:0.66s,1.03s\"/><line x1=\"209.33\" y1=\"74.12\" x2=\"220.83\" y2=\"109.49\" style=\"--len:37.20;animation-delay:0.88s,3.23s\"/><line x1=\"220.83\" y1=\"109.49\" x2=\"258.03\" y2=\"109.49\" style=\"--len:37.20;animation-delay:1.10s,3.23s\"/><line x1=\"258.03\" y1=\"109.49\" x2=\"227.93\" y2=\"131.36\" style=\"--len:37.20;animation-delay:1.32s,3.23s\"/><line x1=\"227.93\" y1=\"131.36\" x2=\"239.43\" y2=\"166.74\" style=\"--len:37.20;animation-delay:1.54s,3.23s\"/><line x1=\"239.43\" y1=\"166.74\" x2=\"209.33\" y2=\"144.87\" style=\"--len:37.20;animation-delay:1.76s,3.23s\"/><line x1=\"209.33\" y1=\"144.87\" x2=\"179.24\" y2=\"166.74\" style=\"--len:37.20;animation-delay:1.98s,3.23s\"/><line x1=\"179.24\" y1=\"166.74\" x2=\"190.73\" y2=\"131.36\" style=\"--len:37.20;animation-delay:2.20s,3.23s\"/><line x1=\"190.73\" y1=\"131.36\" x2=\"160.64\" y2=\"109.49\" style=\"--len:37.20;animation-delay:2.42s,3.23s\"/><line x1=\"160.64\" y1=\"109.49\" x2=\"197.84\" y2=\"109.49\" style=\"--len:37.20;animation-delay:2.64s,3.23s\"/><line x1=\"197.84\" y1=\"109.49\" x2=\"209.33\" y2=\"74.12\" style=\"--len:37.20;animation-delay:2.86s,3.23s\"/><line x1=\"280.03\" y1=\"82.90\" x2=\"288.17\" y2=\"73.54\" style=\"--len:12.40;animation-delay:3.08s,5.43s\"/><line x1=\"288.17\" y1=\"73.54\" x2=\"281.79\" y2=\"62.91\" style=\"--len:12.40;animation-delay:3.30s,5.43s\"/><line x1=\"281.79\" y1=\"62.91\" x2=\"293.20\" y2=\"67.76\" style=\"--len:12.40;animation-delay:3.52s,5.43s\"/><line x1=\"293.20\" y1=\"67.76\" x2=\"301.35\" y2=\"58.41\" style=\"--len:12.40;animation-delay:3.74s,5.43s\"/><line x1=\"301.35\" y1=\"58.41\" x2=\"300.26\" y2=\"70.76\" style=\"--len:12.40;animation-delay:3.96s,5.43s\"/><line x1=\"300.26\" y1=\"70.76\" x2=\"311.67\" y2=\"75.61\" style=\"--len:12.40;animation-delay:4.18s,5.43s\"/><line x1=\"311.67\" y1=\"75.61\" x2=\"299.58\" y2=\"78.40\" style=\"--len:12.40;animation-delay:4.40s,5.43s\"/><line x1=\"299.58\" y1=\"78.40\" x2=\"298.50\" y2=\"90.75\" style=\"--len:12.40;animation-delay:4.62s,5.43s\"/><line x1=\"298.50\" y1=\"90.75\" x2=\"292.12\" y2=\"80.12\" style=\"--len:12.40;animation-delay:4.84s,5.43s\"/><line x1=\"292.12\" y1=\"80.12\" x2=\"280.03\" y2=\"82.90\" style=\"--len:12.40;animation-delay:5.06s,5.43s\"/><line x1=\"311.90\" y1=\"110.66\" x2=\"323.04\" y2=\"105.20\" style=\"--len:12.40;animation-delay:3.08s,5.43s\"/><line x1=\"323.04\" y1=\"105.20\" x2=\"321.28\" y2=\"92.93\" style=\"--len:12.40;animation-delay:3.30s,5.43s\"/><line x1=\"321.28\" y1=\"92.93\" x2=\"329.92\" y2=\"101.83\" style=\"--len:12.40;animation-delay:3.52s,5.43s\"/><line x1=\"329.92\" y1=\"101.83\" x2=\"341.05\" y2=\"96.37\" style=\"--len:12.40;animation-delay:3.74s,5.43s\"/><line x1=\"341.05\" y1=\"96.37\" x2=\"335.25\" y2=\"107.33\" style=\"--len:12.40;animation-delay:3.96s,5.43s\"/><line x1=\"335.25\" y1=\"107.33\" x2=\"343.89\" y2=\"116.23\" style=\"--len:12.40;animation-delay:4.18s,5.43s\"/><line x1=\"343.89\" y1=\"116.23\" x2=\"331.67\" y2=\"114.10\" style=\"--len:12.40;animation-delay:4.40s,5.43s\"/><line x1=\"331.67\" y1=\"114.10\" x2=\"325.87\" y2=\"125.06\" style=\"--len:12.40;animation-delay:4.62s,5.43s\"/><line x1=\"325.87\" y1=\"125.06\" x2=\"324.12\" y2=\"112.79\" style=\"--len:12.40;animation-delay:4.84s,5.43s\"/><line x1=\"324.12\" y1=\"112.79\" x2=\"311.90\" y2=\"110.66\" style=\"--len:12.40;animation-delay:5.06s,5.43s\"/><line x1=\"312.39\" y1=\"154.76\" x2=\"324.78\" y2=\"154.32\" style=\"--len:12.40;animation-delay:3.08s,5.43s\"/><line x1=\"324.78\" y1=\"154.32\" x2=\"328.19\" y2=\"142.39\" style=\"--len:12.40;animation-delay:3.30s,5.43s\"/><line x1=\"328.19\" y1=\"142.39\" x2=\"332.44\" y2=\"154.04\" style=\"--len:12.40;animation-delay:3.52s,5.43s\"/><line x1=\"332.44\" y1=\"154.04\" x2=\"344.83\" y2=\"153.60\" style=\"--len:12.40;animation-delay:3.74s,5.43s\"/><line x1=\"344.83\" y1=\"153.60\" x2=\"335.07\" y2=\"161.24\" style=\"--len:12.40;animation-delay:3.96s,5.43s\"/><line x1=\"335.07\" y1=\"161.24\" x2=\"339.32\" y2=\"172.89\" style=\"--len:12.40;animation-delay:4.18s,5.43s\"/><line x1=\"339.32\" y1=\"172.89\" x2=\"329.03\" y2=\"165.96\" style=\"--len:12.40;animation-delay:4.40s,5.43s\"/><line x1=\"329.03\" y1=\"165.96\" x2=\"319.27\" y2=\"173.61\" style=\"--len:12.40;animation-delay:4.62s,5.43s\"/><line x1=\"319.27\" y1=\"173.61\" x2=\"322.68\" y2=\"161.69\" style=\"--len:12.40;animation-delay:4.84s,5.43s\"/><line x1=\"322.68\" y1=\"161.69\" x2=\"312.39\" y2=\"154.76\" style=\"--len:12.40;animation-delay:5.06s,5.43s\"/><line x1=\"281.34\" y1=\"182.92\" x2=\"292.94\" y2=\"187.30\" style=\"--len:12.40;animation-delay:3.08s,5.43s\"/><line x1=\"292.94\" y1=\"187.30\" x2=\"300.69\" y2=\"177.61\" style=\"--len:12.40;animation-delay:3.30s,5.43s\"/><line x1=\"300.69\" y1=\"177.61\" x2=\"300.11\" y2=\"190.00\" style=\"--len:12.40;animation-delay:3.52s,5.43s\"/><line x1=\"300.11\" y1=\"190.00\" x2=\"311.71\" y2=\"194.38\" style=\"--len:12.40;animation-delay:3.74s,5.43s\"/><line x1=\"311.71\" y1=\"194.38\" x2=\"299.76\" y2=\"197.66\" style=\"--len:12.40;animation-delay:3.96s,5.43s\"/><line x1=\"299.76\" y1=\"197.66\" x2=\"299.18\" y2=\"210.04\" style=\"--len:12.40;animation-delay:4.18s,5.43s\"/><line x1=\"299.18\" y1=\"210.04\" x2=\"292.37\" y2=\"199.68\" style=\"--len:12.40;animation-delay:4.40s,5.43s\"/><line x1=\"292.37\" y1=\"199.68\" x2=\"280.41\" y2=\"202.96\" style=\"--len:12.40;animation-delay:4.62s,5.43s\"/><line x1=\"280.41\" y1=\"202.96\" x2=\"288.15\" y2=\"193.28\" style=\"--len:12.40;animation-delay:4.84s,5.43s\"/><line x1=\"288.15\" y1=\"193.28\" x2=\"281.34\" y2=\"182.92\" style=\"--len:12.40;animation-delay:5.06s,5.43s\"/></g><g class=\"nb-tf-pen\"><circle cx=\"636.00\" cy=\"381.32\" r=\"2.2\" style=\"animation-delay:0.22s\"/><circle cx=\"636.00\" cy=\"39.98\" r=\"2.2\" style=\"animation-delay:0.44s\"/><circle cx=\"124.00\" cy=\"39.98\" r=\"2.2\" style=\"animation-delay:0.66s\"/><circle cx=\"124.00\" cy=\"381.32\" r=\"2.2\" style=\"animation-delay:0.88s\"/><circle cx=\"220.83\" cy=\"109.49\" r=\"2.2\" style=\"animation-delay:1.10s\"/><circle cx=\"258.03\" cy=\"109.49\" r=\"2.2\" style=\"animation-delay:1.32s\"/><circle cx=\"227.93\" cy=\"131.36\" r=\"2.2\" style=\"animation-delay:1.54s\"/><circle cx=\"239.43\" cy=\"166.74\" r=\"2.2\" style=\"animation-delay:1.76s\"/><circle cx=\"209.33\" cy=\"144.87\" r=\"2.2\" style=\"animation-delay:1.98s\"/><circle cx=\"179.24\" cy=\"166.74\" r=\"2.2\" style=\"animation-delay:2.20s\"/><circle cx=\"190.73\" cy=\"131.36\" r=\"2.2\" style=\"animation-delay:2.42s\"/><circle cx=\"160.64\" cy=\"109.49\" r=\"2.2\" style=\"animation-delay:2.64s\"/><circle cx=\"197.84\" cy=\"109.49\" r=\"2.2\" style=\"animation-delay:2.86s\"/><circle cx=\"209.33\" cy=\"74.12\" r=\"2.2\" style=\"animation-delay:3.08s\"/><circle cx=\"288.17\" cy=\"73.54\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"281.79\" cy=\"62.91\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"293.20\" cy=\"67.76\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"301.35\" cy=\"58.41\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"300.26\" cy=\"70.76\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"311.67\" cy=\"75.61\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"299.58\" cy=\"78.40\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"298.50\" cy=\"90.75\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"292.12\" cy=\"80.12\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"280.03\" cy=\"82.90\" r=\"2.2\" style=\"animation-delay:5.28s\"/><circle cx=\"323.04\" cy=\"105.20\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"321.28\" cy=\"92.93\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"329.92\" cy=\"101.83\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"341.05\" cy=\"96.37\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"335.25\" cy=\"107.33\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"343.89\" cy=\"116.23\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"331.67\" cy=\"114.10\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"325.87\" cy=\"125.06\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"324.12\" cy=\"112.79\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"311.90\" cy=\"110.66\" r=\"2.2\" style=\"animation-delay:5.28s\"/><circle cx=\"324.78\" cy=\"154.32\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"328.19\" cy=\"142.39\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"332.44\" cy=\"154.04\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"344.83\" cy=\"153.60\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"335.07\" cy=\"161.24\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"339.32\" cy=\"172.89\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"329.03\" cy=\"165.96\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"319.27\" cy=\"173.61\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"322.68\" cy=\"161.69\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"312.39\" cy=\"154.76\" r=\"2.2\" style=\"animation-delay:5.28s\"/><circle cx=\"292.94\" cy=\"187.30\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"300.69\" cy=\"177.61\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"300.11\" cy=\"190.00\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"311.71\" cy=\"194.38\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"299.76\" cy=\"197.66\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"299.18\" cy=\"210.04\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"292.37\" cy=\"199.68\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"280.41\" cy=\"202.96\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"288.15\" cy=\"193.28\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"281.34\" cy=\"182.92\" r=\"2.2\" style=\"animation-delay:5.28s\"/></g><g class=\"nb-tf-leads\"><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"157.3,125.3 60.0,108.0 8.0,108.0\" style=\"--len:150.9;animation-delay:5.63s\"/><circle class=\"nb-tf-dot\" cx=\"157.3\" cy=\"125.3\" r=\"2.4\" style=\"animation-delay:5.63s\"/><text class=\"nb-tf-label\" x=\"17.0\" y=\"112.0\" text-anchor=\"start\" style=\"animation-delay:5.79s\">大星：中国共产党</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"310.7,64.1 556.0,62.0 566.0,62.0\" style=\"--len:255.3;animation-delay:5.85s\"/><circle class=\"nb-tf-dot\" cx=\"310.7\" cy=\"64.1\" r=\"2.4\" style=\"animation-delay:5.85s\"/><text class=\"nb-tf-label\" x=\"575.0\" y=\"66.0\" text-anchor=\"start\" style=\"animation-delay:6.01s\">第一颗小星：工人阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"346.8,108.2 588.0,132.0 598.0,132.0\" style=\"--len:252.4;animation-delay:6.07s\"/><circle class=\"nb-tf-dot\" cx=\"346.8\" cy=\"108.2\" r=\"2.4\" style=\"animation-delay:6.07s\"/><text class=\"nb-tf-label\" x=\"607.0\" y=\"136.0\" text-anchor=\"start\" style=\"animation-delay:6.23s\">第二颗小星：农民阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"346.8,159.4 588.0,214.0 598.0,214.0\" style=\"--len:257.3;animation-delay:6.29s\"/><circle class=\"nb-tf-dot\" cx=\"346.8\" cy=\"159.4\" r=\"2.4\" style=\"animation-delay:6.29s\"/><text class=\"nb-tf-label\" x=\"607.0\" y=\"218.0\" text-anchor=\"start\" style=\"animation-delay:6.45s\">第三颗小星：城市小资产阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"310.7,203.6 556.0,292.0 566.0,292.0\" style=\"--len:270.8;animation-delay:6.51s\"/><circle class=\"nb-tf-dot\" cx=\"310.7\" cy=\"203.6\" r=\"2.4\" style=\"animation-delay:6.51s\"/><text class=\"nb-tf-label\" x=\"575.0\" y=\"296.0\" text-anchor=\"start\" style=\"animation-delay:6.67s\">第四颗小星：民族资产阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"260.0,386.3 260.0,392.0 260.0,400.0\" style=\"--len:13.7;animation-delay:6.73s\"/><circle class=\"nb-tf-dot\" cx=\"260.0\" cy=\"386.3\" r=\"2.4\" style=\"animation-delay:6.73s\"/><text class=\"nb-tf-label\" x=\"269.0\" y=\"404.0\" text-anchor=\"middle\" style=\"animation-delay:6.89s\">红色旗面：象征革命</text></g></svg>";
    var CSS = ".nb-tf-row{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:stretch;}\n.nb-tf-left{min-width:0;align-self:start;}\n.nb-tf-right{min-width:0;max-width:100%;display:flex;flex-direction:column;}\n.nb-tf-bar{display:flex;align-items:center;gap:7px;margin-bottom:10px;font-size:.76rem;letter-spacing:1.2px;color:rgba(255,226,170,.75);}\n.nb-tf-bar i{font-style:normal;opacity:.6;}\n.nb-tf-svg{display:block;width:100%;height:auto;border-radius:6px;shape-rendering:geometricPrecision;box-shadow:0 20px 50px -30px rgba(0,0,0,.7);}\n.nb-tf-codewrap{flex:1;display:flex;flex-direction:column;min-height:0;border-radius:12px;background:#1e1e1e;border:1px solid rgba(255,210,74,.2);overflow:hidden;}\n.nb-tf-codehead{display:flex;align-items:center;gap:8px;padding:11px 14px;font-size:.76rem;letter-spacing:1px;color:rgba(255,226,170,.8);flex:0 0 auto;}\n.nb-tf-codehead .sp{flex:1;min-width:0;}\n.nb-tf-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(255,210,74,.12);border:1px solid rgba(255,210,74,.3);color:#ffd24a;transition:.2s;}\n.nb-tf-mini:hover{background:rgba(255,210,74,.22);}\n.nb-tf-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}\n.nb-tf-code{flex:1;min-height:0;margin:0;padding:0 14px 16px;max-width:100%;box-sizing:border-box;font:11.5px/1.85 ui-monospace,Consolas,'Courier New',monospace;color:#d4d4d4;white-space:pre;overflow:hidden;-webkit-mask-image:linear-gradient(to bottom,#000 0,#000 60%,rgba(0,0,0,.45) 84%,transparent 100%);mask-image:linear-gradient(to bottom,#000 0,#000 60%,rgba(0,0,0,.45) 84%,transparent 100%);}\n.nb-tf-code b{color:#569cd6;font-weight:400;}\n.nb-tf-code i{color:#ce9178;font-style:normal;}\n.nb-tf-code u{color:#b5cea8;text-decoration:none;}\n.nb-tf-code s{color:#dcdcaa;text-decoration:none;}\n.nb-tf-code m{color:#4ec9b0;}\n.nb-tf-code em{color:#6a9955;font-style:normal;}\n.nb-tf-codewrap.open{flex:0 0 auto;}.nb-tf-codewrap.open .nb-tf-code{overflow:auto;-webkit-mask-image:none;mask-image:none;}\n.nb-tf-fill{opacity:0;animation:nbTfFill .7s ease forwards;animation-delay:0.88s;}\n@keyframes nbTfFill{to{opacity:1;}}\n.nb-tf-star{fill:#ffde00;stroke:none;opacity:0;animation:nbTfStar .45s ease forwards;}\n@keyframes nbTfStar{to{opacity:1;}}\n.nb-tf-stroke line{stroke:#ffd400;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfDraw .22s linear forwards, nbTfFade .6s ease forwards;}\n@keyframes nbTfDraw{to{stroke-dashoffset:0;}}\n@keyframes nbTfFade{to{opacity:0;}}\n.nb-tf-pen circle{fill:#fff6d8;opacity:0;animation:nbTfPen .45s ease forwards;}\n@keyframes nbTfPen{0%{opacity:1;r:3.2;}100%{opacity:0;r:1.2;}}\n.nb-tf-lead{fill:none;stroke:rgba(255,210,74,.72);stroke-width:1.1;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfLead .26s linear forwards;}\n@keyframes nbTfLead{to{stroke-dashoffset:0;}}\n.nb-tf-dot{fill:#ffd24a;stroke:none;opacity:0;animation:nbTfDot .3s ease forwards;}\n@keyframes nbTfDot{to{opacity:1;}}\n.nb-tf-label{fill:#ffd24a;font:11.5px -apple-system,'Segoe UI','Microsoft YaHei',sans-serif;letter-spacing:.4px;opacity:0;paint-order:stroke;stroke:rgba(60,8,12,.85);stroke-width:2.4px;stroke-linejoin:round;animation:nbTfLabel .45s ease forwards;}\n@keyframes nbTfLabel{to{opacity:1;}}\n@media(max-width:900px){.nb-tf-row{grid-template-columns:1fr;gap:22px;margin-top:44px;}.nb-tf-code{font-size:10px;}}\n@media(prefers-reduced-motion:reduce){.nb-tf-stroke line,.nb-tf-lead{animation:none;stroke-dashoffset:0;}.nb-tf-fill,.nb-tf-star,.nb-tf-dot,.nb-tf-label{animation:none;opacity:1;}.nb-tf-pen circle{display:none;}}";
    var CODE = "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>, <m>math</b>\n\n<em># 窗口 600x400，隐藏海龟，中速绘制</b>\n<m>t</b>.<s>setup</b>(<u>600</b>, <u>400</b>)\n<m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>3</b>)\n\n<em># 旗面：原点在画布中心，从 (-150,-100) 起画 300x200</b>\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(<u>-150</b>, <u>-100</b>); <m>t</b>.<s>pendown</b>()\n<m>t</b>.<s>color</b>(<i>\"#de2910\"</b>, <i>\"#de2910\"</b>); <m>t</b>.<s>begin_fill</b>()\n<b>for</b> _ <b>in</b> <s>range</b>(<u>2</b>):\n    <m>t</b>.<s>forward</b>(<u>300</b>); <m>t</b>.<s>left</b>(<u>90</b>)\n    <m>t</b>.<s>forward</b>(<u>200</b>); <m>t</b>.<s>left</b>(<u>90</b>)\n<m>t</b>.<s>end_fill</b>()\n\n<b>def</b> <s>star</b>(cx, cy, R, rot=<u>0</b>):\n    <i>\"\"\"画实心五角星：(cx,cy) 中心，R 外接圆半径，rot=0 时一角朝上。</b>\n\n    <i>    走 10 个顶点（外顶点与内顶点交替），不是 5 个。</b>\n    <i>    用 5 个外顶点隔点连线会自相交，turtle 的填充是 even-odd 规则，</b>\n    <i>    中心会被判定成外部，填出来中间是空的。\"\"\"</b>\n    r = R * <m>math</b>.<s>sin</b>(<m>math</b>.<s>radians</b>(<u>18</b>)) / <m>math</b>.<s>sin</b>(<m>math</b>.<s>radians</b>(<u>54</b>))\n    pts = []\n    <b>for</b> i <b>in</b> <s>range</b>(<u>5</b>):\n        a1 = <m>math</b>.<s>radians</b>(rot + i*<u>72</b> + <u>90</b>)\n        pts.<s>append</b>((cx + R*<m>math</b>.<s>cos</b>(a1), cy + R*<m>math</b>.<s>sin</b>(a1)))\n        a2 = <m>math</b>.<s>radians</b>(rot + i*<u>72</b> + <u>36</b> + <u>90</b>)\n        pts.<s>append</b>((cx + r*<m>math</b>.<s>cos</b>(a2), cy + r*<m>math</b>.<s>sin</b>(a2)))\n    <m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(pts[<u>0</b>]); <m>t</b>.<s>pendown</b>()\n    <m>t</b>.<s>color</b>(<i>\"#ffde00\"</b>, <i>\"#ffde00\"</b>)\n    <m>t</b>.<s>begin_fill</b>()\n    <b>for</b> p <b>in</b> pts[<u>1</b>:]: <m>t</b>.<s>goto</b>(p)\n    <m>t</b>.<s>goto</b>(pts[<u>0</b>])\n    <m>t</b>.<s>end_fill</b>()\n\n<s>star</b>(<u>-100</b>, <u>50</b>, <u>30</b>)            <em># 大星：一角朝正上</b>\nSMALL = [(<u>-50</b>,<u>80</b>), (<u>-30</b>,<u>60</b>), (<u>-30</b>,<u>30</b>), (<u>-50</b>,<u>10</b>)]\n<em># 四颗小星依次为：工人、农民、城市小资产阶级、民族资产阶级</b>\n<b>for</b> cx, cy <b>in</b> SMALL:\n<em>    # atan2(dy,dx) 是数学角，减 90 换算成「相对正上」</b>\n    rot = <m>math</b>.<s>degrees</b>(<m>math</b>.<s>atan2</b>(<u>50</b>-cy, <u>-100</b>-cx)) - <u>90</b>\n    <s>star</b>(cx, cy, <u>10</b>, rot)          <em># 各有一角指向大星</b>\n<m>t</b>.<s>done</b>()";
    var CODE_SHORT = "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>, <m>math</b>\n\n<em># 窗口 600x400，隐藏海龟，中速绘制</b>\n<m>t</b>.<s>setup</b>(<u>600</b>, <u>400</b>)\n<m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>3</b>)\n\n<em># 旗面：原点在画布中心，从 (-150,-100) 起画 300x200</b>\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(<u>-150</b>, <u>-100</b>); <m>t</b>.<s>pendown</b>()\n<m>t</b>.<s>color</b>(<i>\"#de2910\"</b>, <i>\"#de2910\"</b>); <m>t</b>.<s>begin_fill</b>()\n<em># …… 共 42 行，点「展开」看完整代码</em>";
    var PLAIN = "import turtle as t, math\n\n# 窗口 600x400，隐藏海龟，中速绘制\nt.setup(600, 400)\nt.hideturtle(); t.speed(3)\n\n# 旗面：原点在画布中心，从 (-150,-100) 起画 300x200\nt.penup(); t.goto(-150, -100); t.pendown()\nt.color(\"#de2910\", \"#de2910\"); t.begin_fill()\nfor _ in range(2):\n    t.forward(300); t.left(90)\n    t.forward(200); t.left(90)\nt.end_fill()\n\ndef star(cx, cy, R, rot=0):\n    \"\"\"画实心五角星：(cx,cy) 中心，R 外接圆半径，rot=0 时一角朝上。\n\n        走 10 个顶点（外顶点与内顶点交替），不是 5 个。\n        用 5 个外顶点隔点连线会自相交，turtle 的填充是 even-odd 规则，\n        中心会被判定成外部，填出来中间是空的。\"\"\"\n    r = R * math.sin(math.radians(18)) / math.sin(math.radians(54))\n    pts = []\n    for i in range(5):\n        a1 = math.radians(rot + i*72 + 90)\n        pts.append((cx + R*math.cos(a1), cy + R*math.sin(a1)))\n        a2 = math.radians(rot + i*72 + 36 + 90)\n        pts.append((cx + r*math.cos(a2), cy + r*math.sin(a2)))\n    t.penup(); t.goto(pts[0]); t.pendown()\n    t.color(\"#ffde00\", \"#ffde00\")\n    t.begin_fill()\n    for p in pts[1:]: t.goto(p)\n    t.goto(pts[0])\n    t.end_fill()\n\nstar(-100, 50, 30)            # 大星：一角朝正上\nSMALL = [(-50,80), (-30,60), (-30,30), (-50,10)]\n# 四颗小星依次为：工人、农民、城市小资产阶级、民族资产阶级\nfor cx, cy in SMALL:\n    # atan2(dy,dx) 是数学角，减 90 换算成「相对正上」\n    rot = math.degrees(math.atan2(50-cy, -100-cx)) - 90\n    star(cx, cy, 10, rot)          # 各有一角指向大星\nt.done()";
    var PLAIN_SHORT = "import turtle as t, math\n\n# 窗口 600x400，隐藏海龟，中速绘制\nt.setup(600, 400)\nt.hideturtle(); t.speed(3)\n\n# 旗面：原点在画布中心，从 (-150,-100) 起画 300x200\nt.penup(); t.goto(-150, -100); t.pendown()\nt.color(\"#de2910\", \"#de2910\"); t.begin_fill()\n# …… 共 42 行";

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
            /* 收起时显示几行 = 国旗高度能装下几行。
               国旗是 SVG，宽度撑满左列后高度 = 列宽 * (460/560)，
               减去标题栏和 padding，剩下的高度除以行高就是行数。 */
            function fitLines() {
                var colW = left.clientWidth || 520;
                var flagH = colW * (420 / 760);          // 国旗渲染高度
                var headH = head.offsetHeight || 44;
                var avail = flagH - headH - 16;          // 减去 padding
                var lineH = 11.5 * 1.85;
                var n = Math.max(4, Math.floor(avail / lineH) - 1);   // 留一行给省略提示
                var arr = CODE.split('\n');
                pre.innerHTML = arr.slice(0, n).join('\n') +
                    '\n<em># …… 共 ' + arr.length + ' 行，点「展开」看完整代码</em>';
                return n;
            }
            fitLines();
            window.addEventListener('resize', function () {
                if (!wrap.classList.contains('open')) fitLines();
            });

            wrap.appendChild(head);
            wrap.appendChild(pre);
            right.appendChild(wrap);

            toggleBtn.onclick = function () {
                var on = wrap.classList.toggle('open');
                /* 展开/收起时直接换内容 —— 收起是真的把后面的代码删掉，
                   不是用遮罩盖住。 */
                if (on) pre.innerHTML = CODE; else fitLines();
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
