/* NB频道 · 国庆主题：Python 海龟绘图 · 画五星红旗（含六条释义引线）
   画布 600x370；国旗放大到 380x253；Hero 下半部分一行：国旗动画在左、代码面板在右。
   代码面板默认折叠（宽度与左列国旗一致），可展开、可一键复制。
   时间轴：旗面 -> 大星 -> 四颗小星（同步）-> 六条引线逐条。跑完静止。*/
(function () {
    'use strict';
    var SVG = "<svg class=\"nb-tf-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 560 560\" width=\"560\" height=\"560\" role=\"img\" aria-label=\"Python 海龟绘图画出五星红旗，并标注各部分含义\"><rect class=\"nb-tf-fill\" x=\"56.0\" y=\"130.0\" width=\"448.0\" height=\"298.7\" fill=\"#de2910\" rx=\"4\"/><polygon class=\"nb-tf-star\" points=\"130.67,159.88 140.72,190.84 173.27,190.84 146.94,209.97 157.00,240.93 130.67,221.80 104.33,240.93 114.39,209.97 88.06,190.84 120.61,190.84\" style=\"animation-delay:3.08s\"/><polygon class=\"nb-tf-star\" points=\"192.53,167.57 199.65,159.38 194.07,150.08 204.05,154.32 211.18,146.14 210.22,156.95 220.21,161.19 209.64,163.63 208.68,174.44 203.10,165.13\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"220.42,191.86 230.16,187.08 228.62,176.34 236.18,184.13 245.92,179.35 240.85,188.94 248.40,196.73 237.71,194.87 232.64,204.46 231.11,193.72\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"220.84,230.45 231.68,230.06 234.66,219.63 238.39,229.82 249.23,229.43 240.68,236.12 244.41,246.31 235.40,240.25 226.86,246.94 229.84,236.51\" style=\"animation-delay:5.28s\"/><polygon class=\"nb-tf-star\" points=\"193.67,255.09 203.82,258.92 210.60,250.44 210.10,261.28 220.25,265.11 209.79,267.98 209.28,278.82 203.32,269.75 192.86,272.62 199.64,264.15\" style=\"animation-delay:5.28s\"/><g class=\"nb-tf-stroke\"><line x1=\"56.00\" y1=\"428.68\" x2=\"504.00\" y2=\"428.68\" style=\"--len:448.00;animation-delay:0.00s\"/><line x1=\"504.00\" y1=\"428.68\" x2=\"504.00\" y2=\"130.02\" style=\"--len:298.67;animation-delay:0.22s\"/><line x1=\"504.00\" y1=\"130.02\" x2=\"56.00\" y2=\"130.02\" style=\"--len:448.00;animation-delay:0.44s\"/><line x1=\"56.00\" y1=\"130.02\" x2=\"56.00\" y2=\"428.68\" style=\"--len:298.67;animation-delay:0.66s\"/><line x1=\"130.67\" y1=\"159.88\" x2=\"140.72\" y2=\"190.84\" style=\"--len:32.55;animation-delay:0.88s\"/><line x1=\"140.72\" y1=\"190.84\" x2=\"173.27\" y2=\"190.84\" style=\"--len:32.55;animation-delay:1.10s\"/><line x1=\"173.27\" y1=\"190.84\" x2=\"146.94\" y2=\"209.97\" style=\"--len:32.55;animation-delay:1.32s\"/><line x1=\"146.94\" y1=\"209.97\" x2=\"157.00\" y2=\"240.93\" style=\"--len:32.55;animation-delay:1.54s\"/><line x1=\"157.00\" y1=\"240.93\" x2=\"130.67\" y2=\"221.80\" style=\"--len:32.55;animation-delay:1.76s\"/><line x1=\"130.67\" y1=\"221.80\" x2=\"104.33\" y2=\"240.93\" style=\"--len:32.55;animation-delay:1.98s\"/><line x1=\"104.33\" y1=\"240.93\" x2=\"114.39\" y2=\"209.97\" style=\"--len:32.55;animation-delay:2.20s\"/><line x1=\"114.39\" y1=\"209.97\" x2=\"88.06\" y2=\"190.84\" style=\"--len:32.55;animation-delay:2.42s\"/><line x1=\"88.06\" y1=\"190.84\" x2=\"120.61\" y2=\"190.84\" style=\"--len:32.55;animation-delay:2.64s\"/><line x1=\"120.61\" y1=\"190.84\" x2=\"130.67\" y2=\"159.88\" style=\"--len:32.55;animation-delay:2.86s\"/><line x1=\"192.53\" y1=\"167.57\" x2=\"199.65\" y2=\"159.38\" style=\"--len:10.85;animation-delay:3.08s\"/><line x1=\"199.65\" y1=\"159.38\" x2=\"194.07\" y2=\"150.08\" style=\"--len:10.85;animation-delay:3.30s\"/><line x1=\"194.07\" y1=\"150.08\" x2=\"204.05\" y2=\"154.32\" style=\"--len:10.85;animation-delay:3.52s\"/><line x1=\"204.05\" y1=\"154.32\" x2=\"211.18\" y2=\"146.14\" style=\"--len:10.85;animation-delay:3.74s\"/><line x1=\"211.18\" y1=\"146.14\" x2=\"210.22\" y2=\"156.95\" style=\"--len:10.85;animation-delay:3.96s\"/><line x1=\"210.22\" y1=\"156.95\" x2=\"220.21\" y2=\"161.19\" style=\"--len:10.85;animation-delay:4.18s\"/><line x1=\"220.21\" y1=\"161.19\" x2=\"209.64\" y2=\"163.63\" style=\"--len:10.85;animation-delay:4.40s\"/><line x1=\"209.64\" y1=\"163.63\" x2=\"208.68\" y2=\"174.44\" style=\"--len:10.85;animation-delay:4.62s\"/><line x1=\"208.68\" y1=\"174.44\" x2=\"203.10\" y2=\"165.13\" style=\"--len:10.85;animation-delay:4.84s\"/><line x1=\"203.10\" y1=\"165.13\" x2=\"192.53\" y2=\"167.57\" style=\"--len:10.85;animation-delay:5.06s\"/><line x1=\"220.42\" y1=\"191.86\" x2=\"230.16\" y2=\"187.08\" style=\"--len:10.85;animation-delay:3.08s\"/><line x1=\"230.16\" y1=\"187.08\" x2=\"228.62\" y2=\"176.34\" style=\"--len:10.85;animation-delay:3.30s\"/><line x1=\"228.62\" y1=\"176.34\" x2=\"236.18\" y2=\"184.13\" style=\"--len:10.85;animation-delay:3.52s\"/><line x1=\"236.18\" y1=\"184.13\" x2=\"245.92\" y2=\"179.35\" style=\"--len:10.85;animation-delay:3.74s\"/><line x1=\"245.92\" y1=\"179.35\" x2=\"240.85\" y2=\"188.94\" style=\"--len:10.85;animation-delay:3.96s\"/><line x1=\"240.85\" y1=\"188.94\" x2=\"248.40\" y2=\"196.73\" style=\"--len:10.85;animation-delay:4.18s\"/><line x1=\"248.40\" y1=\"196.73\" x2=\"237.71\" y2=\"194.87\" style=\"--len:10.85;animation-delay:4.40s\"/><line x1=\"237.71\" y1=\"194.87\" x2=\"232.64\" y2=\"204.46\" style=\"--len:10.85;animation-delay:4.62s\"/><line x1=\"232.64\" y1=\"204.46\" x2=\"231.11\" y2=\"193.72\" style=\"--len:10.85;animation-delay:4.84s\"/><line x1=\"231.11\" y1=\"193.72\" x2=\"220.42\" y2=\"191.86\" style=\"--len:10.85;animation-delay:5.06s\"/><line x1=\"220.84\" y1=\"230.45\" x2=\"231.68\" y2=\"230.06\" style=\"--len:10.85;animation-delay:3.08s\"/><line x1=\"231.68\" y1=\"230.06\" x2=\"234.66\" y2=\"219.63\" style=\"--len:10.85;animation-delay:3.30s\"/><line x1=\"234.66\" y1=\"219.63\" x2=\"238.39\" y2=\"229.82\" style=\"--len:10.85;animation-delay:3.52s\"/><line x1=\"238.39\" y1=\"229.82\" x2=\"249.23\" y2=\"229.43\" style=\"--len:10.85;animation-delay:3.74s\"/><line x1=\"249.23\" y1=\"229.43\" x2=\"240.68\" y2=\"236.12\" style=\"--len:10.85;animation-delay:3.96s\"/><line x1=\"240.68\" y1=\"236.12\" x2=\"244.41\" y2=\"246.31\" style=\"--len:10.85;animation-delay:4.18s\"/><line x1=\"244.41\" y1=\"246.31\" x2=\"235.40\" y2=\"240.25\" style=\"--len:10.85;animation-delay:4.40s\"/><line x1=\"235.40\" y1=\"240.25\" x2=\"226.86\" y2=\"246.94\" style=\"--len:10.85;animation-delay:4.62s\"/><line x1=\"226.86\" y1=\"246.94\" x2=\"229.84\" y2=\"236.51\" style=\"--len:10.85;animation-delay:4.84s\"/><line x1=\"229.84\" y1=\"236.51\" x2=\"220.84\" y2=\"230.45\" style=\"--len:10.85;animation-delay:5.06s\"/><line x1=\"193.67\" y1=\"255.09\" x2=\"203.82\" y2=\"258.92\" style=\"--len:10.85;animation-delay:3.08s\"/><line x1=\"203.82\" y1=\"258.92\" x2=\"210.60\" y2=\"250.44\" style=\"--len:10.85;animation-delay:3.30s\"/><line x1=\"210.60\" y1=\"250.44\" x2=\"210.10\" y2=\"261.28\" style=\"--len:10.85;animation-delay:3.52s\"/><line x1=\"210.10\" y1=\"261.28\" x2=\"220.25\" y2=\"265.11\" style=\"--len:10.85;animation-delay:3.74s\"/><line x1=\"220.25\" y1=\"265.11\" x2=\"209.79\" y2=\"267.98\" style=\"--len:10.85;animation-delay:3.96s\"/><line x1=\"209.79\" y1=\"267.98\" x2=\"209.28\" y2=\"278.82\" style=\"--len:10.85;animation-delay:4.18s\"/><line x1=\"209.28\" y1=\"278.82\" x2=\"203.32\" y2=\"269.75\" style=\"--len:10.85;animation-delay:4.40s\"/><line x1=\"203.32\" y1=\"269.75\" x2=\"192.86\" y2=\"272.62\" style=\"--len:10.85;animation-delay:4.62s\"/><line x1=\"192.86\" y1=\"272.62\" x2=\"199.64\" y2=\"264.15\" style=\"--len:10.85;animation-delay:4.84s\"/><line x1=\"199.64\" y1=\"264.15\" x2=\"193.67\" y2=\"255.09\" style=\"--len:10.85;animation-delay:5.06s\"/></g><g class=\"nb-tf-pen\"><circle cx=\"504.00\" cy=\"428.68\" r=\"2.2\" style=\"animation-delay:0.22s\"/><circle cx=\"504.00\" cy=\"130.02\" r=\"2.2\" style=\"animation-delay:0.44s\"/><circle cx=\"56.00\" cy=\"130.02\" r=\"2.2\" style=\"animation-delay:0.66s\"/><circle cx=\"56.00\" cy=\"428.68\" r=\"2.2\" style=\"animation-delay:0.88s\"/><circle cx=\"140.72\" cy=\"190.84\" r=\"2.2\" style=\"animation-delay:1.10s\"/><circle cx=\"173.27\" cy=\"190.84\" r=\"2.2\" style=\"animation-delay:1.32s\"/><circle cx=\"146.94\" cy=\"209.97\" r=\"2.2\" style=\"animation-delay:1.54s\"/><circle cx=\"157.00\" cy=\"240.93\" r=\"2.2\" style=\"animation-delay:1.76s\"/><circle cx=\"130.67\" cy=\"221.80\" r=\"2.2\" style=\"animation-delay:1.98s\"/><circle cx=\"104.33\" cy=\"240.93\" r=\"2.2\" style=\"animation-delay:2.20s\"/><circle cx=\"114.39\" cy=\"209.97\" r=\"2.2\" style=\"animation-delay:2.42s\"/><circle cx=\"88.06\" cy=\"190.84\" r=\"2.2\" style=\"animation-delay:2.64s\"/><circle cx=\"120.61\" cy=\"190.84\" r=\"2.2\" style=\"animation-delay:2.86s\"/><circle cx=\"130.67\" cy=\"159.88\" r=\"2.2\" style=\"animation-delay:3.08s\"/><circle cx=\"199.65\" cy=\"159.38\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"194.07\" cy=\"150.08\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"204.05\" cy=\"154.32\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"211.18\" cy=\"146.14\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"210.22\" cy=\"156.95\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"220.21\" cy=\"161.19\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"209.64\" cy=\"163.63\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"208.68\" cy=\"174.44\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"203.10\" cy=\"165.13\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"192.53\" cy=\"167.57\" r=\"2.2\" style=\"animation-delay:5.28s\"/><circle cx=\"230.16\" cy=\"187.08\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"228.62\" cy=\"176.34\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"236.18\" cy=\"184.13\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"245.92\" cy=\"179.35\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"240.85\" cy=\"188.94\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"248.40\" cy=\"196.73\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"237.71\" cy=\"194.87\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"232.64\" cy=\"204.46\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"231.11\" cy=\"193.72\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"220.42\" cy=\"191.86\" r=\"2.2\" style=\"animation-delay:5.28s\"/><circle cx=\"231.68\" cy=\"230.06\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"234.66\" cy=\"219.63\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"238.39\" cy=\"229.82\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"249.23\" cy=\"229.43\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"240.68\" cy=\"236.12\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"244.41\" cy=\"246.31\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"235.40\" cy=\"240.25\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"226.86\" cy=\"246.94\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"229.84\" cy=\"236.51\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"220.84\" cy=\"230.45\" r=\"2.2\" style=\"animation-delay:5.28s\"/><circle cx=\"203.82\" cy=\"258.92\" r=\"2.2\" style=\"animation-delay:3.30s\"/><circle cx=\"210.60\" cy=\"250.44\" r=\"2.2\" style=\"animation-delay:3.52s\"/><circle cx=\"210.10\" cy=\"261.28\" r=\"2.2\" style=\"animation-delay:3.74s\"/><circle cx=\"220.25\" cy=\"265.11\" r=\"2.2\" style=\"animation-delay:3.96s\"/><circle cx=\"209.79\" cy=\"267.98\" r=\"2.2\" style=\"animation-delay:4.18s\"/><circle cx=\"209.28\" cy=\"278.82\" r=\"2.2\" style=\"animation-delay:4.40s\"/><circle cx=\"203.32\" cy=\"269.75\" r=\"2.2\" style=\"animation-delay:4.62s\"/><circle cx=\"192.86\" cy=\"272.62\" r=\"2.2\" style=\"animation-delay:4.84s\"/><circle cx=\"199.64\" cy=\"264.15\" r=\"2.2\" style=\"animation-delay:5.06s\"/><circle cx=\"193.67\" cy=\"255.09\" r=\"2.2\" style=\"animation-delay:5.28s\"/></g><g class=\"nb-tf-leads\"><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"84.7,160.7 84.7,84.0 40.0,84.0\" style=\"--len:121.3;animation-delay:5.43s\"/><circle class=\"nb-tf-dot\" cx=\"84.7\" cy=\"160.7\" r=\"2.4\" style=\"animation-delay:5.43s\"/><text class=\"nb-tf-label\" x=\"48.0\" y=\"77.0\" text-anchor=\"start\" style=\"animation-delay:5.59s\">大星：中国共产党</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"215.3,144.9 215.3,46.0 196.0,46.0\" style=\"--len:118.2;animation-delay:5.65s\"/><circle class=\"nb-tf-dot\" cx=\"215.3\" cy=\"144.9\" r=\"2.4\" style=\"animation-delay:5.65s\"/><text class=\"nb-tf-label\" x=\"204.0\" y=\"39.0\" text-anchor=\"start\" style=\"animation-delay:5.81s\">第一颗小星：工人阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"250.2,179.8 250.2,12.0 196.0,12.0\" style=\"--len:221.9;animation-delay:5.87s\"/><circle class=\"nb-tf-dot\" cx=\"250.2\" cy=\"179.8\" r=\"2.4\" style=\"animation-delay:5.87s\"/><text class=\"nb-tf-label\" x=\"204.0\" y=\"5.0\" text-anchor=\"start\" style=\"animation-delay:6.03s\">第二颗小星：农民阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"250.2,244.6 250.2,486.0 196.0,486.0\" style=\"--len:295.6;animation-delay:6.09s\"/><circle class=\"nb-tf-dot\" cx=\"250.2\" cy=\"244.6\" r=\"2.4\" style=\"animation-delay:6.09s\"/><text class=\"nb-tf-label\" x=\"204.0\" y=\"479.0\" text-anchor=\"start\" style=\"animation-delay:6.25s\">第三颗小星：城市小资产阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"215.3,279.4 215.3,524.0 196.0,524.0\" style=\"--len:263.9;animation-delay:6.31s\"/><circle class=\"nb-tf-dot\" cx=\"215.3\" cy=\"279.4\" r=\"2.4\" style=\"animation-delay:6.31s\"/><text class=\"nb-tf-label\" x=\"204.0\" y=\"517.0\" text-anchor=\"start\" style=\"animation-delay:6.47s\">第四颗小星：民族资产阶级</text><polyline class=\"nb-tf-lead\" fill=\"none\" points=\"210.0,432.7 210.0,552.0 40.0,552.0\" style=\"--len:289.3;animation-delay:6.53s\"/><circle class=\"nb-tf-dot\" cx=\"210.0\" cy=\"432.7\" r=\"2.4\" style=\"animation-delay:6.53s\"/><text class=\"nb-tf-label\" x=\"48.0\" y=\"545.0\" text-anchor=\"start\" style=\"animation-delay:6.69s\">红色旗面：象征革命</text></g></svg>";
    var CSS = ".nb-tf-row{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:stretch;}\n.nb-tf-left{min-width:0;align-self:start;}\n.nb-tf-right{min-width:0;max-width:100%;display:flex;flex-direction:column;}\n.nb-tf-bar{display:flex;align-items:center;gap:7px;margin-bottom:10px;font-size:.76rem;letter-spacing:1.2px;color:rgba(255,226,170,.75);}\n.nb-tf-bar i{font-style:normal;opacity:.6;}\n.nb-tf-svg{display:block;width:100%;height:auto;border-radius:6px;shape-rendering:geometricPrecision;box-shadow:0 20px 50px -30px rgba(0,0,0,.7);}\n.nb-tf-codewrap{flex:1;display:flex;flex-direction:column;min-height:0;border-radius:12px;background:#1e1e1e;border:1px solid rgba(255,210,74,.2);overflow:hidden;}\n.nb-tf-codehead{display:flex;align-items:center;gap:8px;padding:11px 14px;font-size:.76rem;letter-spacing:1px;color:rgba(255,226,170,.8);flex:0 0 auto;}\n.nb-tf-codehead .sp{flex:1;min-width:0;}\n.nb-tf-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(255,210,74,.12);border:1px solid rgba(255,210,74,.3);color:#ffd24a;transition:.2s;}\n.nb-tf-mini:hover{background:rgba(255,210,74,.22);}\n.nb-tf-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}\n.nb-tf-code{flex:1;min-height:0;margin:0;padding:0 14px 16px;max-width:100%;box-sizing:border-box;font:11.5px/1.85 ui-monospace,Consolas,'Courier New',monospace;color:#d4d4d4;white-space:pre;overflow:hidden;-webkit-mask-image:linear-gradient(to bottom,#000 0,#000 60%,rgba(0,0,0,.45) 84%,transparent 100%);mask-image:linear-gradient(to bottom,#000 0,#000 60%,rgba(0,0,0,.45) 84%,transparent 100%);}\n.nb-tf-code b{color:#569cd6;font-weight:400;}\n.nb-tf-code i{color:#ce9178;font-style:normal;}\n.nb-tf-code u{color:#b5cea8;text-decoration:none;}\n.nb-tf-code s{color:#dcdcaa;text-decoration:none;}\n.nb-tf-code m{color:#4ec9b0;}\n.nb-tf-code em{color:#6a9955;font-style:normal;}\n.nb-tf-codewrap.open{flex:0 0 auto;}.nb-tf-codewrap.open .nb-tf-code{overflow:auto;-webkit-mask-image:none;mask-image:none;}\n.nb-tf-fill{opacity:0;animation:nbTfFill .7s ease forwards;animation-delay:0.88s;}\n@keyframes nbTfFill{to{opacity:1;}}\n.nb-tf-star{fill:#ffde00;stroke:none;opacity:0;animation:nbTfStar .45s ease forwards;}\n@keyframes nbTfStar{to{opacity:1;}}\n.nb-tf-stroke line{stroke:#ffd400;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfDraw 0.22s linear forwards;}\n@keyframes nbTfDraw{to{stroke-dashoffset:0;}}\n.nb-tf-pen circle{fill:#fff6d8;opacity:0;animation:nbTfPen .45s ease forwards;}\n@keyframes nbTfPen{0%{opacity:1;r:3.2;}100%{opacity:0;r:1.2;}}\n.nb-tf-lead{fill:none;stroke:rgba(255,210,74,.72);stroke-width:1.1;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTfLead .26s linear forwards;}\n@keyframes nbTfLead{to{stroke-dashoffset:0;}}\n.nb-tf-dot{fill:#ffd24a;stroke:none;opacity:0;animation:nbTfDot .3s ease forwards;}\n@keyframes nbTfDot{to{opacity:1;}}\n.nb-tf-label{fill:#ffd24a;font:11.5px -apple-system,'Segoe UI','Microsoft YaHei',sans-serif;letter-spacing:.4px;opacity:0;paint-order:stroke;stroke:rgba(60,8,12,.85);stroke-width:2.4px;stroke-linejoin:round;animation:nbTfLabel .45s ease forwards;}\n@keyframes nbTfLabel{to{opacity:1;}}\n@media(max-width:900px){.nb-tf-row{grid-template-columns:1fr;gap:22px;margin-top:44px;}.nb-tf-code{font-size:10px;}}\n@media(prefers-reduced-motion:reduce){.nb-tf-stroke line,.nb-tf-lead{animation:none;stroke-dashoffset:0;}.nb-tf-fill,.nb-tf-star,.nb-tf-dot,.nb-tf-label{animation:none;opacity:1;}.nb-tf-pen circle{display:none;}}";
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
                var flagH = colW * (560 / 560);          // 国旗渲染高度
                var headH = head.offsetHeight || 44;
                var avail = flagH - headH - 16;          // 减去 padding
                var lineH = 11.5 * 1.85;
                var n = Math.max(4, Math.floor(avail / lineH) - 1);   // 留一行给省略提示
                var arr = CODE.split('\n');
                pre.innerHTML = arr.slice(0, n).join('\n') +
                    '\n<em># …… 共 ' + arr.length + ' 行，点「展开」看完整代码</em>';
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
                pre.innerHTML = on ? CODE : CODE_SHORT;
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
