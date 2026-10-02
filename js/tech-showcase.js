/* NB频道 · 科技主题展示区
   只在 theme=tech 时挂载。左侧动画 + 右侧对应源码，顶部 Tab 切换内容。
   第一个内容：Python 海龟画谢尔宾斯基三角（深度 4 → 81 个三角形）。*/
(function () {
    'use strict';
    var CSS = ".nb-ts-row{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:start;}\n.nb-ts-left{min-width:0;align-self:start;}\n.nb-ts-right{min-width:0;max-width:100%;display:flex;flex-direction:column;}\n.nb-ts-bar{display:flex;align-items:center;gap:10px;margin-bottom:12px;flex-wrap:wrap;}\n.nb-ts-bar .sp{flex:1;min-width:0;font-size:.76rem;letter-spacing:1.2px;color:rgba(150,220,255,.8);}\n.nb-ts-tabs{display:flex;gap:6px;flex-wrap:wrap;}\n.nb-ts-tab{padding:5px 11px;border-radius:8px;cursor:pointer;font-family:inherit;font-size:.72rem;letter-spacing:.5px;background:rgba(0,229,255,.08);border:1px solid rgba(0,229,255,.22);color:rgba(180,230,255,.85);transition:.2s;}\n.nb-ts-tab:hover{background:rgba(0,229,255,.18);}\n.nb-ts-tab.on{background:rgba(0,229,255,.22);border-color:rgba(0,229,255,.6);color:#eaf9ff;box-shadow:0 0 18px -6px rgba(0,229,255,.7);}\n.nb-ts-svg{display:block;width:100%;height:auto;border-radius:12px;shape-rendering:geometricPrecision;box-shadow:0 20px 50px -30px rgba(0,0,0,.8);}\n.nb-ts-codewrap{display:flex;flex-direction:column;border-radius:12px;background:#1e1e1e;border:1px solid rgba(0,229,255,.2);overflow:hidden;}\n.nb-ts-codehead{display:flex;align-items:center;gap:8px;padding:11px 14px;font-size:.76rem;letter-spacing:1px;color:rgba(180,230,255,.8);}\n.nb-ts-codehead .sp{flex:1;min-width:0;}\n.nb-ts-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(0,229,255,.1);border:1px solid rgba(0,229,255,.3);color:#7fe3ff;transition:.2s;}\n.nb-ts-mini:hover{background:rgba(0,229,255,.2);}\n.nb-ts-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}\n.nb-ts-code{margin:0;padding:0 14px 16px;max-width:100%;box-sizing:border-box;font:11.5px/1.85 ui-monospace,Consolas,'Courier New',monospace;color:#d4d4d4;white-space:pre;overflow:hidden;-webkit-mask-image:linear-gradient(to bottom,#000 0,#000 70%,rgba(0,0,0,.4) 88%,transparent 100%);mask-image:linear-gradient(to bottom,#000 0,#000 70%,rgba(0,0,0,.4) 88%,transparent 100%);}\n.nb-ts-code b{color:#569cd6;font-weight:400;}\n.nb-ts-code i{color:#ce9178;font-style:normal;}\n.nb-ts-code u{color:#b5cea8;text-decoration:none;}\n.nb-ts-code s{color:#dcdcaa;text-decoration:none;}\n.nb-ts-code m{color:#4ec9b0;}\n.nb-ts-code em{color:#6a9955;font-style:normal;}\n.nb-ts-codewrap.open .nb-ts-code{overflow:auto;-webkit-mask-image:none;mask-image:none;}\n.nb-ts-poly polygon{fill:rgba(0,229,255,.14);stroke:#00e5ff;stroke-width:1.4;stroke-linejoin:round;opacity:0;animation:nbTsPop .5s cubic-bezier(.16,1,.3,1) forwards;}\n@keyframes nbTsPop{from{opacity:0;transform:scale(.6);transform-origin:center;}to{opacity:1;transform:scale(1);}}\n@media(max-width:900px){.nb-ts-row{grid-template-columns:1fr;gap:22px;margin-top:44px;}.nb-ts-code{font-size:10px;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-poly polygon{animation:none;opacity:1;}}\n.nb-ts-path{fill:none;stroke:#00e5ff;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw 2.6s linear forwards;filter:drop-shadow(0 0 5px rgba(0,229,255,.55));}\n@keyframes nbTsDraw{to{stroke-dashoffset:0;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-path{animation:none;stroke-dashoffset:0;}}\n.nb-ts-tline{opacity:0;animation:nbTsLine .28s ease forwards;}\n@keyframes nbTsLine{to{opacity:1;}}\n.nb-ts-caret{animation:nbTsCaret 1.05s steps(1,end) infinite;}\n@keyframes nbTsCaret{0%,49%{opacity:1;}50%,100%{opacity:0;}}\n.nb-ts-chart{fill:none;stroke:#00e5ff;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw 2.2s cubic-bezier(.4,0,.2,1) forwards;filter:drop-shadow(0 0 6px rgba(0,229,255,.6));}\n.nb-ts-area{opacity:0;animation:nbTsFadeIn 1.6s ease .8s forwards;}\n@keyframes nbTsFadeIn{to{opacity:1;}}\n.nb-ts-pt{fill:#7fe3ff;stroke:#060a14;stroke-width:1.4;opacity:0;animation:nbTsPop2 .4s ease forwards;}\n@keyframes nbTsPop2{to{opacity:1;}}\n.nb-ts-pulse{animation:nbTsPulse 1.9s ease-in-out infinite;}\n@keyframes nbTsPulse{0%,100%{opacity:.55;}50%{opacity:1;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-tline,.nb-ts-area,.nb-ts-pt{animation:none;opacity:1;}.nb-ts-chart{animation:none;stroke-dashoffset:0;}.nb-ts-pulse{animation:none;}}\n.nb-ts-sq path{fill:none;stroke:rgba(0,229,255,.34);stroke-width:1;stroke-dasharray:5 4;opacity:0;animation:nbTsSqIn .5s ease forwards;}\n@keyframes nbTsSqIn{to{opacity:1;}}\n.nb-ts-num text{fill:rgba(0,229,255,.42);font:600 11.5px ui-monospace,Consolas,monospace;text-anchor:middle;opacity:0;animation:nbTsSqIn .5s ease forwards;}\n.nb-ts-spiral path{fill:none;stroke:#00e5ff;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw 1.1s linear forwards;filter:drop-shadow(0 0 6px rgba(0,229,255,.55));}\n@media(prefers-reduced-motion:reduce){.nb-ts-sq path,.nb-ts-num text{animation:none;opacity:1;}.nb-ts-spiral path{animation:none;stroke-dashoffset:0;}}\n.nb-ts-term{display:flex;flex-direction:column;height:100%;min-height:330px;border-radius:12px;background:#080d18;border:1px solid rgba(0,229,255,.22);overflow:hidden;box-shadow:0 20px 50px -30px rgba(0,0,0,.8);}\n.nb-ts-term-bar{display:flex;align-items:center;gap:7px;padding:9px 12px;background:rgba(0,229,255,.055);border-bottom:1px solid rgba(0,229,255,.14);flex:0 0 auto;}\n.nb-ts-term-bar i{width:11px;height:11px;border-radius:50%;display:block;}\n.nb-ts-term-bar .t{margin-left:8px;font:11.5px ui-monospace,Consolas,monospace;color:rgba(150,220,255,.5);}\n.nb-ts-term-body{flex:1;min-height:0;overflow-y:auto;padding:12px 14px;font:12.5px/1.72 ui-monospace,Consolas,'Courier New',monospace;color:rgba(205,228,250,.88);}\n.nb-ts-term-body::-webkit-scrollbar{width:8px;}\n.nb-ts-term-body::-webkit-scrollbar-thumb{background:rgba(0,229,255,.28);border-radius:8px;}\n.nb-ts-tl{white-space:pre-wrap;word-break:break-word;}\n.nb-ts-tl.cmd{color:#7fe3ff;}\n.nb-ts-tl.err{color:#ff8a8a;}\n.nb-ts-tl.dim{color:rgba(150,190,225,.5);}\n.nb-ts-tl.hi{color:#ffd24a;}\n.nb-ts-tl.ok{color:#7ee0a8;}\n.nb-ts-tin{display:flex;align-items:center;gap:0;}\n.nb-ts-tin .ps{color:#7fe3ff;flex:0 0 auto;}\n.nb-ts-tin input{flex:1;min-width:0;background:none;border:none;outline:none;color:#eaf4ff;font:inherit;caret-color:#7fe3ff;padding:0;}\n.nb-ts-thint{padding:7px 14px 10px;font-size:.68rem;letter-spacing:.4px;color:rgba(150,200,235,.42);border-top:1px solid rgba(0,229,255,.09);flex:0 0 auto;}\n.nb-ts-tri-line line{stroke:#00e5ff;stroke-width:1.5;stroke-linecap:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw .022s linear forwards;filter:drop-shadow(0 0 4px rgba(0,229,255,.5));}\n.nb-ts-tri-fill polygon{fill:rgba(0,229,255,.16);stroke:none;opacity:0;animation:nbTsTriFill .3s ease forwards;}\n@keyframes nbTsTriFill{to{opacity:1;}}\n.nb-ts-pen circle{fill:#d8fbff;opacity:0;animation:nbTsPen .42s ease forwards;}\n@keyframes nbTsPen{0%{opacity:1;r:2.6;}100%{opacity:0;r:.8;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-tri-line line{animation:none;stroke-dashoffset:0;}.nb-ts-tri-fill polygon{animation:none;opacity:1;}.nb-ts-pen circle{display:none;}}\n.nb-ts-langs{display:flex;gap:6px;flex-wrap:wrap;padding:0 14px 10px;}\n.nb-ts-lang{padding:4px 10px;border-radius:7px;cursor:pointer;font-family:inherit;font-size:.7rem;letter-spacing:.4px;background:rgba(0,229,255,.07);border:1px solid rgba(0,229,255,.2);color:rgba(180,230,255,.8);transition:.18s;}\n.nb-ts-lang:hover{background:rgba(0,229,255,.16);}\n.nb-ts-lang.on{background:rgba(0,229,255,.22);border-color:rgba(0,229,255,.62);color:#eaf9ff;}";


/* ============================================================
       交互式终端引擎
       ============================================================ */
    var TERM_FILES = {
        'about.txt': '\u4e00\u4e2a\u7531 UP\u4e3b\u300cNB\u641e\u4e8b\u5c40\u300d\u5efa\u7acb\u7684\u865a\u62df\u516c\u53f8\u3002\n\u5316\u5b66\u4e0e\u7269\u7406\u5b9e\u9a8c \u00b7 \u65e5\u5e38\u4f5c\u6b7b \u00b7 NB\u5e01\u865a\u62df\u7ecf\u6d4e',
        'motto.txt': '\u70ed\u7231\u7406\u79d1\uff0c\u4e0e\u4f5c\u6b7b\u540c\u884c',
        'README.md': '# NB\u9891\u9053\n\n\u8fd0\u884c `nb company` \u770b\u516c\u53f8\u6863\u6848\u3002'
    };
    var TERM_MODULES = ['about', 'videos', 'shop', 'bank', 'stock', 'chat', 'tools', 'vote'];
    var TERM_TOP = [
        ['NB\u641e\u4e8b\u5c40', '112,363'],
        ['\u70ed\u7231\u7406\u79d1', '98,204'],
        ['\u4f5c\u6b7b\u5c0f\u961f', '76,551'],
        ['\u5316\u5b66\u8bfe\u4ee3\u8868', '64,930'],
        ['\u7269\u7406\u8bfe\u4ee3\u8868', '58,127']
    ];
    var TERM_FORTUNE = [
        '\u5316\u5b66\u8003\u8bd5\u4e0d\u4f1a\u7684\u5c31\u9009 C\u3002',
        '\u522b\u5fd8\u4e86\u4eca\u5929\u7b7e\u5230\u3002',
        '\u5b9e\u9a8c\u524d\u5148\u770b\u5b89\u5168\u624b\u518c\u3002',
        '\u80fd\u914d\u5e73\u7684\u65b9\u7a0b\u5f0f\uff0c\u4eba\u751f\u4e5f\u4f1a\u914d\u5e73\u3002',
        '\u6027\u80fd\u4f18\u5148\uff1a\u5148\u8dd1\u901a\uff0c\u518d\u8dd1\u5feb\u3002',
        '\u4eca\u5929\u9002\u5408\u5199\u4ee3\u7801\u3002',
        '\u4e70\u80a1\u4e0d\u5982\u4e70\u77e5\u8bc6\u3002'
    ];

    /* 市值等经营数据：以粉丝数为锚，换算成一套自洽的数字 */
    var NB_CO = {
        name: 'NB\u9891\u9053 \u00b7 NoBook Channel',
        founded: '2026-02',
        hq: '\u5730\u7403 \u00b7 \u7f51\u7edc',
        holders: '\u5168\u4f53\u7c89\u4e1d',
        fans: 112363,
        staff: 11,
        friends: 11,
        days: 213
    };

    function fmt(n) {
        return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }
    /* 用粉丝数推市值：粉丝 × 1.86 NB币，再折算成"亿元" */
    function mcap() { return NB_CO.fans * 1.86 / 10000; }
    function price() { return NB_CO.fans / 4552; }

    /* 迷你走势图：把一串数字画成 ▁▂▃▄▅▆▇█ */
    function spark(nums) {
        var blocks = ['\u2581', '\u2582', '\u2583', '\u2584', '\u2585', '\u2586', '\u2587', '\u2588'];
        var mn = Math.min.apply(null, nums), mx = Math.max.apply(null, nums);
        var span = (mx - mn) || 1;
        return nums.map(function (v) {
            var i = Math.round((v - mn) / span * (blocks.length - 1));
            return blocks[i];
        }).join('');
    }

/* ============================================================
       虚拟股票的真实数据（只读）
       直接打 Supabase 的 REST 接口，用页面上同一个 anon key。
       ============================================================ */
    var SB_URL = 'https://pbaafgjkwdbwcmsikcmg.supabase.co';
    var SB_KEY = 'sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg';

    function sbGet(path) {
        return fetch(SB_URL + '/rest/v1/' + path, {
            headers: { apikey: SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
        }).then(function (r) {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        });
    }

    /* 全站公司按市值降序，取前 n 家 */
    function sbCompanies(n) {
        return sbGet('user_companies?select=company_name,market_value,total_shares,verified,' +
                     'verification_status,created_at&order=market_value.desc&limit=' + (n || 10));
    }
    /* 找一家公司（按名字模糊匹配） */
    function sbFindCompany(name) {
        return sbGet('user_companies?select=*&company_name=ilike.*' + encodeURIComponent(name) +
                     '*&order=market_value.desc&limit=1').then(function (a) {
            return (a && a.length) ? a[0] : null;
        });
    }

    /* 数字千分位 */
    function fm(n) {
        return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }
    /* 把大数折成「亿 / 万」 */
    function big(n) {
        if (n >= 1e8) return (n / 1e8).toFixed(2) + ' \u4ebf';
        if (n >= 1e4) return (n / 1e4).toFixed(2) + ' \u4e07';
        return fm(n);
    }
    /* ▁▂▃▄▅▆▇█ 迷你走势 */
    function spark(nums) {
        var b = ['\u2581', '\u2582', '\u2583', '\u2584', '\u2585', '\u2586', '\u2587', '\u2588'];
        var mn = Math.min.apply(null, nums), mx = Math.max.apply(null, nums);
        var sp = (mx - mn) || 1;
        return nums.map(function (v) { return b[Math.round((v - mn) / sp * 7)]; }).join('');
    }

    function termCommands(write, clear) {
        var CMD_ERR = function (name) {
            /* 仿 Windows CMD 的报错 */
            return { cls: 'err', text: "'" + name + "' \u4e0d\u662f\u5185\u90e8\u6216\u5916\u90e8\u547d\u4ee4\uff0c\u4e5f\u4e0d\u662f\u53ef\u8fd0\u884c\u7684\u7a0b\u5e8f\n\u6216\u6279\u5904\u7406\u6587\u4ef6\u3002" };
        };
        var cmds = {
            'help': function () {
                return [
                    '\u2500\u2500 \u57fa\u7840 \u2500\u2500',
                    '  help / ?          \u663e\u793a\u8fd9\u4efd\u5e2e\u52a9',
                    '  whoami            \u6211\u662f\u8c01',
                    '  cat <\u6587\u4ef6>        \u8bfb\u6587\u4ef6',
                    '  ls [modules/]     \u5217\u76ee\u5f55',
                    '  uptime            \u8fd0\u884c\u65f6\u957f',
                    '  date              \u5f53\u524d\u65f6\u95f4',
                    '  echo <\u6587\u5b57>       \u539f\u6837\u56de\u663e',
                    '  history           \u5386\u53f2\u547d\u4ee4',
                    '  clear             \u6e05\u5c4f',
                    '  start <\u9875\u9762>      \u6253\u5f00\u5176\u5b83\u9875\u9762\uff08\u8f93 start \u770b\u5168\u90e8\uff09',
                    '',
                    '\u2500\u2500 \u865a\u62df\u80a1\u7968 \u00b7 \u771f\u5b9e\u6570\u636e \u2500\u2500',
                    '  nb company        \u81ea\u5bb6\u516c\u53f8\u6863\u6848',
                    '  nb mcap           \u5e02\u503c\u4e0e\u5168\u7ad9\u6392\u540d',
                    '  nb rank [n]       \u5e02\u503c\u699c\u524d n \u5bb6',
                    '  nb richest        \u5e02\u503c\u7b2c\u4e00\u662f\u8c01',
                    '  nb verified       \u5df2\u8ba4\u8bc1\u516c\u53f8',
                    '  nb count          \u516c\u53f8\u603b\u6570 / \u603b\u5e02\u503c',
                    '  nb new            \u6700\u8fd1\u6ce8\u518c\u7684\u516c\u53f8',
                    '  nb search <\u8bcd>    \u641c\u516c\u53f8',
                    '  nb market         \u5168\u5e02\u573a\u603b\u5e02\u503c',
                    '  nb history [n]    \u5386\u53f2\u5feb\u7167\u6982\u51b5',
                    '  nb stock [n]      \u8d70\u52bf\u56fe',
                    '  nb friend         \u5e02\u503c\u9760\u524d\u7684\u90bb\u5c45',
                    '',
                    '\u2500\u2500 \u5176\u4ed6 \u2500\u2500',
                    '  fortune           \u968f\u673a\u4e00\u53e5',
                    '  matrix            \u4f60\u61c2\u7684',
                    '  nbcoin            \u4f60\u61c2\u7684',
                    '  exit              \u5173\u95ed\u7ec8\u7aef'
                ].join('\n');
            },
            'whoami': function () { return NB_CO.name; },
            'ls': function (arg) {
                if (arg === 'modules/' || arg === 'modules') return TERM_MODULES.join('  ');
                return 'about.txt  motto.txt  README.md  modules/';
            },
            'cat': function (arg) {
                var f = (arg || '').trim();
                if (!f) return { cls: 'err', text: '\u547d\u4ee4\u8bed\u6cd5\u4e0d\u6b63\u786e\u3002' };
                if (TERM_FILES[f] !== undefined) return TERM_FILES[f];
                return { cls: 'err', text: '\u7cfb\u7edf\u627e\u4e0d\u5230\u6307\u5b9a\u7684\u6587\u4ef6\u3002' };
            },
            'uptime': function () {
                /* 和首页 #siteDays 完全一样的算法：
                   建站日 2026-02-17（本地时区），两边都归零到当天 0 点，
                   取相差的整日数。 */
                var days = 0;
                var el = document.getElementById('siteDays');
                if (el) {
                    var dt = parseInt(el.getAttribute('data-to') || '', 10);
                    if (dt > 0) days = dt;
                    if (!days) {
                        var tv = parseInt((el.textContent || '').replace(/[^\d]/g, ''), 10);
                        if (tv > 0) days = tv;
                    }
                }
                if (!days) {
                    var start = new Date(2026, 1, 17);
                    var now = new Date();
                    start.setHours(0, 0, 0, 0);
                    now.setHours(0, 0, 0, 0);
                    days = Math.round((now - start) / 86400000);
                }
                return [
                    '\u5df2\u8fd0\u884c ' + days + ' \u5929',
                    '\u5efa\u7ad9\u65e5 2026-02-17',
                    '\u4eca\u5929   ' + (function () {
                        var d = new Date();
                        function p(n) { return (n < 10 ? '0' : '') + n; }
                        return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
                    })()
                ].join('\n');
            },
            'date': function () {
                var d = new Date();
                function p(n) { return (n < 10 ? '0' : '') + n; }
                return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
                       ' ' + p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds());
            },
            'fortune': function () {
                return TERM_FORTUNE[Math.floor(Math.random() * TERM_FORTUNE.length)];
            },
            /* start <页面>：在新标签打开 NB 频道的其它页面 */
            'start': function (arg) {
                var PAGES = {
                    'home':    ['index-Beta.html',        '\u9996\u9875'],
                    'about':   ['about-Beta.html',        '\u5173\u4e8e\u6211\u4eec'],
                    'videos':  ['videos-Beta.html',       '\u89c6\u9891'],
                    'shop':    ['shop-Beta.html',         '\u5468\u8fb9\u5546\u57ce'],
                    'bank':    ['bank-Beta.html',         'NB\u94f6\u884c'],
                    'stock':   ['stock-Beta.html',        '\u865a\u62df\u80a1\u7968'],
                    'chat':    ['chat-Beta.html',         '\u597d\u53cb / \u79c1\u4fe1'],
                    'vote':    ['vote-Beta.html',         '\u6295\u7968\u4e2d\u5fc3'],
                    'tools':   ['tools-Beta.html',        '\u5de5\u5177\u7bb1'],
                    'profile': ['profile-Beta.html',      '\u4e2a\u4eba\u4e2d\u5fc3'],
                    'messages':['messages-Beta.html',     '\u6d88\u606f\u4e2d\u5fc3'],
                    'comments':['comments-Beta.html',     '\u8bc4\u8bba\u533a'],
                    'changelog':['changelog-Beta.html',   '\u66f4\u65b0\u65e5\u5fd7'],
                    'achievements':['achievements-Beta.html','\u6210\u5c31'],
                    'backpack':['backpack-Beta.html',     '\u80cc\u5305'],
                    'lottery': ['lottery-Beta.html',      '\u7b7e\u5230\u62bd\u5956'],
                    'titles':  ['titles-Beta.html',       '\u79f0\u53f7'],
                    'feedback':['feedback-Beta.html',     '\u53cd\u9988'],
                    'product': ['product-Beta.html',      '\u6211\u7684\u4ea7\u54c1'],
                    'app':     ['APP-Beta.html',          '\u8f6f\u4ef6/APP']
                };
                var k = (arg || '').trim().toLowerCase().replace(/\.html$/, '');
                if (!k) {
                    var keys = Object.keys(PAGES);
                    var out = ['\u53ef\u4ee5\u6253\u5f00\u7684\u9875\u9762\uff08start <\u540d\u5b57>\uff09'];
                    for (var i = 0; i < keys.length; i += 3) {
                        out.push('  ' + keys.slice(i, i + 3).map(function (x) {
                            return (x + '            ').slice(0, 13) + PAGES[x][1];
                        }).join(''));
                    }
                    return out.join('\n');
                }
                if (!PAGES[k]) {
                    return {cls: 'err', text: '\u627e\u4e0d\u5230\u9875\u9762\uff1a' + k + '\u3002\u8f93\u5165 start \u770b\u5168\u90e8\u3002'};
                }
                try {
                    window.open(PAGES[k][0], '_blank', 'noopener');
                } catch (e2) {}
                return {cls: 'ok', text: '\u6b63\u5728\u6253\u5f00\uff1a' + PAGES[k][1] + '  \u2192 ' + PAGES[k][0]};
            },
            'echo': function (arg) { return arg || ''; },
            'clear': function () { clear(); return null; },
            'sudo': function (arg) {
                if (!arg) {
                    return {cls: 'err', text: '\u6743\u9650\u4e0d\u8db3\uff1a\u4f60\u53ea\u662f\u4e2a\u8bbf\u5ba2\u3002'};
                }
                return {cls: 'err', text: 'sudo: ' + arg + ': command not found'};
            },
            'rm': function (arg) {
                if (/-rf?\s*\/?\s*$/.test(arg) || arg.indexOf('-rf') === 0) {
                    return {cls: 'err', text: '\u6211\u5f88\u60f3\u7167\u505a\uff0c\u4f46\u516c\u53f8\u8fd8\u5f97\u8fd0\u8425\u3002'};
                }
                return {cls: 'err', text: 'rm: \u7f3a\u5c11\u64cd\u4f5c\u6570'};
            },
            'matrix': function () {
                var chars = '01NB\u30A2\u30A4\u30A6\u30A8\u30AA\u30AB\u30AD\u30AF';
                var rows = [];
                for (var r = 0; r < 8; r++) {
                    var line = '';
                    for (var c = 0; c < 46; c++) {
                        line += Math.random() < 0.28
                            ? chars[Math.floor(Math.random() * chars.length)]
                            : ' ';
                    }
                    rows.push(line);
                }
                return {cls: 'ok', text: rows.join('\n') + '\n\u4f60\u5728\u7f51\u7edc\u4e16\u754c\u91cc\u8d8a\u9677\u8d8a\u6df1\u4e86\u3002'};
            },
            'nbcoin': function () {
                return {cls: 'hi', text: '\u62ff\u7740\uff0c\u522b\u8bf4\u662f\u6211\u7ed9\u7684\u3002\uff08\u7eaf\u5c5e\u5f69\u86cb\uff0c\u8d26\u6237\u91cc\u6ca1\u591a\u4e00\u5206\u94b1\uff09'};
            },
            'exit': function () { return { cls: 'dim', text: '\u518d\u89c1\uff0c\u8bb0\u5f97\u56de\u6765\u3002' }; },

            /* ---------- 公司经营 ---------- */
            /* ---------- 公司经营：直连虚拟股票的真实数据 ---------- */
            'nb': function (arg) {
                var a = (arg || '').trim();
                var sub = a.split(/\s+/)[0] || '';
                var rest = a.slice(sub.length).trim();

                /* 公司档案：优先查名字里带 NB 的自家公司 */
                if (sub === 'company' || sub === 'info') {
                    return sbFindCompany('NB').then(function (c) {
                        if (!c) return {cls: 'err', text: '\u6ca1\u67e5\u5230\u516c\u53f8\u8bb0\u5f55\u3002'};
                        var st = c.verification_status === 'approved' ? '\u5df2\u8ba4\u8bc1'
                               : (c.verification_status === 'pending' ? '\u5ba1\u6838\u4e2d' : '\u672a\u8ba4\u8bc1');
                        return [
                            '\u250c\u2500 \u516c\u53f8\u6863\u6848 ' + '\u2500'.repeat(22),
                            '\u2502 \u540d\u79f0    ' + c.company_name,
                            '\u2502 \u5e02\u503c    ' + big(c.market_value) + ' NB',
                            '\u2502 \u72b6\u6001    ' + st,
                            '\u2502 \u6210\u7acb    ' + String(c.created_at || '').slice(0, 10),
                            '\u2514' + '\u2500'.repeat(30)
                        ].join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 市值 + 全站排名 */
                if (sub === 'mcap' || sub === 'market') {
                    return Promise.all([sbFindCompany('NB'), sbCompanies(200)]).then(function (r) {
                        var c = r[0], all = r[1] || [];
                        if (!c) return {cls: 'err', text: '\u6ca1\u67e5\u5230\u516c\u53f8\u8bb0\u5f55\u3002'};
                        var rank = all.findIndex(function (x) { return x.company_name === c.company_name; }) + 1;
                        var total = all.reduce(function (s2, x) { return s2 + (x.market_value || 0); }, 0);
                        var share = total ? (c.market_value / total * 100) : 0;
                        return [
                            '\u5e02\u503c  ' + big(c.market_value) + ' NB',
                            '\u6392\u540d  ' + (rank || '-') + ' / ' + all.length + '  \u5168\u5e02\u573a ' + big(total) + ' NB',
                            '\u5360\u6bd4  ' + share.toFixed(2) + '%'
                        ].join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 市值排行榜 */
                if (sub === 'rank') {
                    var n = parseInt(rest, 10);
                    if (!n || n < 3) n = 10;
                    if (n > 30) n = 30;
                    return sbCompanies(n).then(function (all) {
                        if (!all || !all.length) return {cls: 'err', text: '\u6682\u65e0\u516c\u53f8\u6570\u636e\u3002'};
                        var lines = ['\u5168\u5e02\u573a\u5e02\u503c\u699c\uff08\u524d ' + all.length + '\uff09'];
                        all.forEach(function (c, i) {
                            var tag = c.verified ? ' \u2713' : '';
                            lines.push('  ' + String(i + 1).padStart(2) + '. ' +
                                       c.company_name.slice(0, 16) + tag +
                                       '  ' + big(c.market_value || 0));
                        });
                        return lines.join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 全市场概览 */
                if (sub === 'market') {
                    return sbGet('stock_latest?select=total_value,created_at&order=created_at.desc&limit=1')
                        .then(function (a) {
                            var t = (a && a[0]) ? a[0].total_value : 0;
                            return '\u5168\u5e02\u573a\u603b\u5e02\u503c  ' + big(t) + ' NB\n' +
                                   '\u5feb\u7167\u65f6\u95f4      ' + String((a[0] || {}).created_at || '').slice(0, 19).replace('T', ' ');
                        }).catch(function (e) {
                            return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                        });
                }

                /* 股价走势：用市值历史画 sparkline */
                if (sub === 'stock') {
                    var nn = parseInt(rest, 10);
                    if (!nn || nn < 5) nn = 20;
                    if (nn > 60) nn = 60;
                    return Promise.all([sbFindCompany('NB'),
                                        sbGet('stock_history_full?select=total_value,created_at' +
                                              '&order=created_at.desc&limit=' + nn)])
                        .then(function (r2) {
                            var c = r2[0], hist = (r2[1] || []).slice().reverse();
                            if (!c) return {cls: 'err', text: '\u6ca1\u67e5\u5230\u516c\u53f8\u8bb0\u5f55\u3002'};
                            var out = ['\u5e02\u503c  ' + big(c.market_value) + ' NB'];
                            if (hist.length >= 5) {
                                var vals = hist.map(function (h) { return h.total_value; });
                                var first = vals[0], last = vals[vals.length - 1];
                                var pct = first ? (last - first) / first * 100 : 0;
                                out.push('\u5168\u5e02\u573a\u8fd1 ' + vals.length + ' \u6b21\u5feb\u7167  ' +
                                         (pct >= 0 ? '\u25b2 +' : '\u25bc ') + pct.toFixed(2) + '%');
                                out.push('');
                                out.push('  ' + spark(vals));
                            } else {
                                out.push('\u5386\u53f2\u5feb\u7167\u4e0d\u8db3\uff0c\u591a\u5237\u65b0\u51e0\u6b21\u540e\u518d\u770b\u3002');
                            }
                            return out.join('\n');
                        }).catch(function (e) {
                            return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                        });
                }

                /* 好友：读真实的好友关系（需要登录） */
                if (sub === 'friend' || sub === 'friends') {
                    var u = null, sess = '';
                    try {
                        u = JSON.parse(localStorage.getItem('nb_user') || 'null');
                        sess = localStorage.getItem('nb_session') || '';
                    } catch (e0) {}
                    if (!u || !u.id || !sess) {
                        return {cls: 'err', text: '\u8bf7\u5148\u767b\u5f55\u540e\u518d\u67e5\u597d\u53cb\u3002'};
                    }
                    return fetch(SB_URL + '/rest/v1/rpc/get_friends', {
                        method: 'POST',
                        headers: {
                            apikey: SB_KEY,
                            'Authorization': 'Bearer ' + SB_KEY,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ p_user_id: u.id, p_session: sess })
                    }).then(function (r) {
                        if (!r.ok) throw new Error('HTTP ' + r.status);
                        return r.json();
                    }).then(function (list) {
                        list = list || [];
                        var me = u.nickname || u.username || '\u6211';
                        if (!list.length) {
                            return {cls: 'dim', text: '\u4f60\u8fd8\u6ca1\u6709\u597d\u53cb\u3002\u53bb chat-Beta.html \u52a0\u51e0\u4e2a\u5427\u3002'};
                        }
                        var out = [me + ' \u7684\u597d\u53cb\uff08' + list.length + ' \u4f4d\uff09'];
                        list.forEach(function (f, i) {
                            var nm = f.nickname || f.username || f.name || ('\u7528\u6237' + (f.id || f.user_id || ''));
                            out.push('  ' + String(i + 1).padStart(2) + '. ' + String(nm).slice(0, 18));
                        });
                        return out.join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u597d\u53cb\u5217\u8868\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 已认证的公司 */
                if (sub === 'verified') {
                    return sbGet('user_companies?select=company_name,market_value' +
                                 '&verification_status=eq.approved&order=market_value.desc&limit=12')
                        .then(function (all) {
                            if (!all || !all.length) return {cls: 'dim', text: '\u76ee\u524d\u6ca1\u6709\u5df2\u8ba4\u8bc1\u7684\u516c\u53f8\u3002'};
                            return ['\u5df2\u8ba4\u8bc1\uff08' + all.length + ' \u5bb6\uff09'].concat(
                                all.map(function (c, i) {
                                    return '  ' + String(i + 1).padStart(2) + '. ' +
                                           c.company_name.slice(0, 16) + '  ' + big(c.market_value || 0);
                                })).join('\n');
                        }).catch(function (e) {
                            return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                        });
                }

                /* 全站公司总数 */
                if (sub === 'count') {
                    return sbCompanies(1000).then(function (all) {
                        var n2 = (all || []).length;
                        var vf = (all || []).filter(function (c) { return c.verified; }).length;
                        var tot = (all || []).reduce(function (a, c) { return a + (c.market_value || 0); }, 0);
                        return '\u516c\u53f8\u603b\u6570  ' + n2 + ' \u5bb6\n' +
                               '\u5df2\u8ba4\u8bc1    ' + vf + ' \u5bb6\n' +
                               '\u603b\u5e02\u503c    ' + big(tot) + ' NB';
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 最新注册的公司 */
                if (sub === 'new') {
                    return sbGet('user_companies?select=company_name,market_value,created_at' +
                                 '&order=created_at.desc&limit=8').then(function (all) {
                        if (!all || !all.length) return {cls: 'dim', text: '\u6682\u65e0\u6570\u636e\u3002'};
                        return ['\u6700\u8fd1\u6ce8\u518c'].concat(all.map(function (c) {
                            return '  ' + String(c.created_at || '').slice(0, 10) + '  ' +
                                   c.company_name.slice(0, 16) + '  ' + big(c.market_value || 0);
                        })).join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 搜公司 */
                if (sub === 'search' || sub === 'find') {
                    if (!rest) return {cls: 'err', text: '\u7528\u6cd5\uff1anb search <\u516c\u53f8\u540d>'};
                    return sbGet('user_companies?select=company_name,market_value,verified' +
                                 '&company_name=ilike.*' + encodeURIComponent(rest) +
                                 '*&order=market_value.desc&limit=10').then(function (all) {
                        if (!all || !all.length) return {cls: 'dim', text: '\u6ca1\u627e\u5230\u5339\u914d\u7684\u516c\u53f8\u3002'};
                        return ['\u5339\u914d ' + all.length + ' \u5bb6'].concat(all.map(function (c) {
                            return '  ' + c.company_name.slice(0, 18) + (c.verified ? ' \u2713' : '') +
                                   '  ' + big(c.market_value || 0);
                        })).join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 市值第一 */
                if (sub === 'richest' || sub === 'no1') {
                    return sbCompanies(1).then(function (all) {
                        var c = (all || [])[0];
                        if (!c) return {cls: 'dim', text: '\u6682\u65e0\u6570\u636e\u3002'};
                        return '\u5e02\u503c\u7b2c\u4e00  ' + c.company_name + '\n' +
                               '\u5e02\u503c      ' + big(c.market_value || 0) + ' NB';
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 历史快照条数 */
                if (sub === 'history') {
                    var nn2 = parseInt(rest, 10);
                    if (!nn2 || nn2 < 10) nn2 = 30;
                    if (nn2 > 200) nn2 = 200;
                    return sbGet('stock_history_full?select=total_value,created_at' +
                                 '&order=created_at.desc&limit=' + nn2).then(function (all) {
                        if (!all || !all.length) return {cls: 'dim', text: '\u6682\u65e0\u5386\u53f2\u5feb\u7167\u3002'};
                        var vals = all.map(function (h) { return h.total_value; }).reverse();
                        var first = vals[0], last = vals[vals.length - 1];
                        var pct = first ? (last - first) / first * 100 : 0;
                        return '\u5386\u53f2\u5feb\u7167  ' + all.length + ' \u6761\n' +
                               '\u65f6\u95f4\u8de8\u5ea6  ' + String(all[all.length - 1].created_at || '').slice(0, 16).replace('T', ' ') +
                               ' \u2192 ' + String(all[0].created_at || '').slice(0, 16).replace('T', ' ') + '\n' +
                               '\u603b\u5e02\u503c    ' + big(last) + ' NB  ' +
                               (pct >= 0 ? '\u25b2 +' : '\u25bc ') + pct.toFixed(2) + '%';
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                if (sub === '--help' || sub === '') {
                    return '\u7528\u6cd5\uff1anb <company|mcap|rank|market|stock|friend|fans|coin|motto|badge>';
                }
                return {cls: 'err', text: '\u53c2\u6570\u9519\u8bef\uff1a' + sub + '\u3002\u8f93\u5165 nb --help \u770b\u7528\u6cd5\u3002'};
            }
        };
        /* ? 等同 help，history 由外层注入 */
        cmds['?'] = cmds['help'];
        return cmds;
    }

/* 下载用的 MIME —— 走 text/plain，避开浏览器的脚本拦截 */
    function mimeOf(name) {
        /* 下载统一用 text/plain。
           Chromium 对 text/javascript、text/x-python 这类脚本类型会做安全拦截，
           弹「此类型的文件可能会损害你的设备」，逼用户手动点保留。
           换成 text/plain 就只当普通文本存盘 —— 文件名和内容都不变。 */
        return 'text/plain;charset=utf-8';
    }
    /* 触发下载 */
    function saveText(name, text) {
        try {
            var blob = new Blob([text], { type: mimeOf(name) });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = name;
            a.style.cssText = 'position:fixed;left:-9999px;';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            setTimeout(function () { URL.revokeObjectURL(url); }, 1500);
            return true;
        } catch (e) {
            return false;
        }
    }

    function initTerminal(root) {
        var body = root.querySelector('[data-term]');
        if (!body) return;
        var history = [];
        var hi = -1;
        var cmds = null;

        function el(cls, text) {
            var d = document.createElement('div');
            d.className = 'nb-ts-tl' + (cls ? ' ' + cls : '');
            d.textContent = text;
            body.appendChild(d);
            body.scrollTop = body.scrollHeight;
            return d;
        }
        function clear() { body.innerHTML = ''; }
        function print(out) {
            if (out === null || out === undefined) return;
            if (typeof out === 'string') {
                out.split('\n').forEach(function (l) { el('', l); });
            } else {
                el(out.cls, out.text);
            }
        }
        cmds = termCommands(el, clear);
        cmds['history'] = function () {
            if (!history.length) return '\u6682\u65e0\u5386\u53f2\u547d\u4ee4\u3002';
            return history.map(function (h, i) { return '  ' + (i + 1) + '  ' + h; }).join('\n');
        };

        /* 开场只留一行提示，不预置任何命令和输出 —— 让访客自己敲 */
        var WELCOME = [
            ['dim', '\u8f93\u5165 help \u770b\u5168\u90e8\u547d\u4ee4\uff0c\u6216\u8005\u76f4\u63a5\u6572\u4e00\u6761\u8bd5\u8bd5\u3002']
        ];
        WELCOME.forEach(function (row, i) {
            var d = el(row[0], row[1]);
            d.style.opacity = '0';
            d.style.transition = 'opacity .25s ease';
            setTimeout(function () { d.style.opacity = '1'; }, 110 + i * 105);
        });

        var lineWrap = document.createElement('div');
        lineWrap.className = 'nb-ts-tin';
        var ps = document.createElement('span');
        ps.className = 'ps';
        ps.textContent = '$ ';
        var inp = document.createElement('input');
        inp.type = 'text';
        inp.setAttribute('autocomplete', 'off');
        inp.setAttribute('autocapitalize', 'off');
        inp.setAttribute('spellcheck', 'false');
        inp.setAttribute('aria-label', '\u8f93\u5165\u547d\u4ee4');
        lineWrap.appendChild(ps);
        lineWrap.appendChild(inp);
        body.appendChild(lineWrap);
        setTimeout(function () { try { inp.focus(); } catch (e) {} }, 900);

        body.addEventListener('click', function (e) {
            if (e.target !== inp) { try { inp.focus(); } catch (er) {} }
        });
        function stick() { body.appendChild(lineWrap); body.scrollTop = body.scrollHeight; }

        function run(raw) {
            var text = raw.trim();
            el('cmd', '$ ' + text);
            if (text === 'exit') {
                var r = cmds['exit']();
                el(r.cls, r.text);
                inp.disabled = true;
                ps.textContent = '';
                inp.placeholder = '\u5df2\u5173\u95ed\uff0c\u5207\u5230\u522b\u7684\u6807\u7b7e\u9875\u518d\u56de\u6765\u5c31\u91cd\u542f\u4e86';
                return;
            }
            if (!text) return;
            var sp = text.indexOf(' ');
            var name = sp < 0 ? text : text.slice(0, sp);
            var arg = sp < 0 ? '' : text.slice(sp + 1);
            var fn = cmds[name];
            if (!fn) {
                /* 仿 CMD 的报错 */
                var e = cmds.__err(name);
                el('err', e.text);
                el('dim', '\u8f93\u5165 help \u67e5\u770b\u53ef\u7528\u547d\u4ee4\u3002');
                return;
            }
            var out = fn(arg);
            /* 命令可以返回字符串、{cls,text}，也可以返回 Promise（联网查询） */
            if (out && typeof out.then === 'function') {
                var tip = el('dim', '查询中…');
                out.then(function (r2) {
                    tip.parentNode.removeChild(tip);
                    print(r2);
                }, function (e) {
                    tip.parentNode.removeChild(tip);
                    el('err', '查询失败：' + e);
                });
                return;
            }
            print(out);
        }
        /* 把 CMD 报错挂进命令表 */
        cmds.__err = function (name) {
            return { cls: 'err', text: "'" + name + "' \u4e0d\u662f\u5185\u90e8\u6216\u5916\u90e8\u547d\u4ee4\uff0c\u4e5f\u4e0d\u662f\u53ef\u8fd0\u884c\u7684\u7a0b\u5e8f\n\u6216\u6279\u5904\u7406\u6587\u4ef6\u3002" };
        };

        inp.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') {
                var v = inp.value;
                if (v.trim()) { history.push(v.trim()); }
                hi = history.length;
                inp.value = '';
                run(v);
                stick();
            } else if (e.key === 'ArrowUp') {
                if (!history.length) return;
                hi = Math.max(0, hi - 1);
                inp.value = history[hi] || '';
                e.preventDefault();
            } else if (e.key === 'ArrowDown') {
                if (!history.length) return;
                hi = Math.min(history.length, hi + 1);
                inp.value = history[hi] || '';
                e.preventDefault();
            } else if (e.key === 'Tab') {
                e.preventDefault();
                var v2 = inp.value.trim();
                if (!v2) return;
                var names = Object.keys(cmds).filter(function (n) { return n.indexOf('__') !== 0; });
                var hit = names.filter(function (n) { return n.indexOf(v2) === 0; });
                if (hit.length === 1) inp.value = hit[0];
                else if (hit.length > 1) el('dim', hit.join('  '));
            }
        });
    }

    /* ---------- 内容表：每项 = { id, 标签, 说明, SVG, CODE, PLAIN } ---------- */
    var ITEMS = [
        {
            file: 'sierpinski.py',
            id: 'sierpinski',
            tab: '\uD83D\uDD3A \u8C22\u5C14\u5BBE\u65AF\u57FA',
            name: 'Python \u6D77\u9F9F\u7ED8\u56FE <i>\u00B7 \u8C22\u5C14\u5BBE\u65AF\u57FA\u4E09\u89D2</i>',
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"Python 海龟递归画出谢尔宾斯基三角\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><g class=\"nb-ts-tri-fill\"><polygon points=\"70.00,458.75 101.25,458.75 85.62,432.66\" style=\"animation-delay:0.126s\"/><polygon points=\"101.25,458.75 132.50,458.75 116.88,432.66\" style=\"animation-delay:0.204s\"/><polygon points=\"85.62,432.66 116.88,432.66 101.25,406.56\" style=\"animation-delay:0.282s\"/><polygon points=\"132.50,458.75 163.75,458.75 148.12,432.66\" style=\"animation-delay:0.360s\"/><polygon points=\"163.75,458.75 195.00,458.75 179.38,432.66\" style=\"animation-delay:0.438s\"/><polygon points=\"148.12,432.66 179.38,432.66 163.75,406.56\" style=\"animation-delay:0.516s\"/><polygon points=\"101.25,406.56 132.50,406.56 116.88,380.47\" style=\"animation-delay:0.594s\"/><polygon points=\"132.50,406.56 163.75,406.56 148.12,380.47\" style=\"animation-delay:0.672s\"/><polygon points=\"116.88,380.47 148.12,380.47 132.50,354.38\" style=\"animation-delay:0.750s\"/><polygon points=\"195.00,458.75 226.25,458.75 210.62,432.66\" style=\"animation-delay:0.828s\"/><polygon points=\"226.25,458.75 257.50,458.75 241.88,432.66\" style=\"animation-delay:0.906s\"/><polygon points=\"210.62,432.66 241.88,432.66 226.25,406.56\" style=\"animation-delay:0.984s\"/><polygon points=\"257.50,458.75 288.75,458.75 273.12,432.66\" style=\"animation-delay:1.062s\"/><polygon points=\"288.75,458.75 320.00,458.75 304.38,432.66\" style=\"animation-delay:1.140s\"/><polygon points=\"273.12,432.66 304.38,432.66 288.75,406.56\" style=\"animation-delay:1.218s\"/><polygon points=\"226.25,406.56 257.50,406.56 241.88,380.47\" style=\"animation-delay:1.296s\"/><polygon points=\"257.50,406.56 288.75,406.56 273.12,380.47\" style=\"animation-delay:1.374s\"/><polygon points=\"241.88,380.47 273.12,380.47 257.50,354.38\" style=\"animation-delay:1.452s\"/><polygon points=\"132.50,354.38 163.75,354.38 148.12,328.28\" style=\"animation-delay:1.530s\"/><polygon points=\"163.75,354.38 195.00,354.38 179.38,328.28\" style=\"animation-delay:1.608s\"/><polygon points=\"148.12,328.28 179.38,328.28 163.75,302.19\" style=\"animation-delay:1.686s\"/><polygon points=\"195.00,354.38 226.25,354.38 210.62,328.28\" style=\"animation-delay:1.764s\"/><polygon points=\"226.25,354.38 257.50,354.38 241.88,328.28\" style=\"animation-delay:1.842s\"/><polygon points=\"210.62,328.28 241.88,328.28 226.25,302.19\" style=\"animation-delay:1.920s\"/><polygon points=\"163.75,302.19 195.00,302.19 179.38,276.09\" style=\"animation-delay:1.998s\"/><polygon points=\"195.00,302.19 226.25,302.19 210.62,276.09\" style=\"animation-delay:2.076s\"/><polygon points=\"179.38,276.09 210.62,276.09 195.00,250.00\" style=\"animation-delay:2.154s\"/><polygon points=\"320.00,458.75 351.25,458.75 335.62,432.66\" style=\"animation-delay:2.232s\"/><polygon points=\"351.25,458.75 382.50,458.75 366.88,432.66\" style=\"animation-delay:2.310s\"/><polygon points=\"335.62,432.66 366.88,432.66 351.25,406.56\" style=\"animation-delay:2.388s\"/><polygon points=\"382.50,458.75 413.75,458.75 398.12,432.66\" style=\"animation-delay:2.466s\"/><polygon points=\"413.75,458.75 445.00,458.75 429.38,432.66\" style=\"animation-delay:2.544s\"/><polygon points=\"398.12,432.66 429.38,432.66 413.75,406.56\" style=\"animation-delay:2.622s\"/><polygon points=\"351.25,406.56 382.50,406.56 366.88,380.47\" style=\"animation-delay:2.700s\"/><polygon points=\"382.50,406.56 413.75,406.56 398.12,380.47\" style=\"animation-delay:2.778s\"/><polygon points=\"366.88,380.47 398.12,380.47 382.50,354.38\" style=\"animation-delay:2.856s\"/><polygon points=\"445.00,458.75 476.25,458.75 460.62,432.66\" style=\"animation-delay:2.934s\"/><polygon points=\"476.25,458.75 507.50,458.75 491.88,432.66\" style=\"animation-delay:3.012s\"/><polygon points=\"460.62,432.66 491.88,432.66 476.25,406.56\" style=\"animation-delay:3.090s\"/><polygon points=\"507.50,458.75 538.75,458.75 523.12,432.66\" style=\"animation-delay:3.168s\"/><polygon points=\"538.75,458.75 570.00,458.75 554.38,432.66\" style=\"animation-delay:3.246s\"/><polygon points=\"523.12,432.66 554.38,432.66 538.75,406.56\" style=\"animation-delay:3.324s\"/><polygon points=\"476.25,406.56 507.50,406.56 491.88,380.47\" style=\"animation-delay:3.402s\"/><polygon points=\"507.50,406.56 538.75,406.56 523.12,380.47\" style=\"animation-delay:3.480s\"/><polygon points=\"491.88,380.47 523.12,380.47 507.50,354.38\" style=\"animation-delay:3.558s\"/><polygon points=\"382.50,354.38 413.75,354.38 398.12,328.28\" style=\"animation-delay:3.636s\"/><polygon points=\"413.75,354.38 445.00,354.38 429.38,328.28\" style=\"animation-delay:3.714s\"/><polygon points=\"398.12,328.28 429.38,328.28 413.75,302.19\" style=\"animation-delay:3.792s\"/><polygon points=\"445.00,354.38 476.25,354.38 460.62,328.28\" style=\"animation-delay:3.870s\"/><polygon points=\"476.25,354.38 507.50,354.38 491.88,328.28\" style=\"animation-delay:3.948s\"/><polygon points=\"460.62,328.28 491.88,328.28 476.25,302.19\" style=\"animation-delay:4.026s\"/><polygon points=\"413.75,302.19 445.00,302.19 429.38,276.09\" style=\"animation-delay:4.104s\"/><polygon points=\"445.00,302.19 476.25,302.19 460.62,276.09\" style=\"animation-delay:4.182s\"/><polygon points=\"429.38,276.09 460.62,276.09 445.00,250.00\" style=\"animation-delay:4.260s\"/><polygon points=\"195.00,250.00 226.25,250.00 210.62,223.91\" style=\"animation-delay:4.338s\"/><polygon points=\"226.25,250.00 257.50,250.00 241.88,223.91\" style=\"animation-delay:4.416s\"/><polygon points=\"210.62,223.91 241.88,223.91 226.25,197.81\" style=\"animation-delay:4.494s\"/><polygon points=\"257.50,250.00 288.75,250.00 273.12,223.91\" style=\"animation-delay:4.572s\"/><polygon points=\"288.75,250.00 320.00,250.00 304.38,223.91\" style=\"animation-delay:4.650s\"/><polygon points=\"273.12,223.91 304.38,223.91 288.75,197.81\" style=\"animation-delay:4.728s\"/><polygon points=\"226.25,197.81 257.50,197.81 241.88,171.72\" style=\"animation-delay:4.806s\"/><polygon points=\"257.50,197.81 288.75,197.81 273.12,171.72\" style=\"animation-delay:4.884s\"/><polygon points=\"241.88,171.72 273.12,171.72 257.50,145.62\" style=\"animation-delay:4.962s\"/><polygon points=\"320.00,250.00 351.25,250.00 335.62,223.91\" style=\"animation-delay:5.040s\"/><polygon points=\"351.25,250.00 382.50,250.00 366.88,223.91\" style=\"animation-delay:5.118s\"/><polygon points=\"335.62,223.91 366.88,223.91 351.25,197.81\" style=\"animation-delay:5.196s\"/><polygon points=\"382.50,250.00 413.75,250.00 398.12,223.91\" style=\"animation-delay:5.274s\"/><polygon points=\"413.75,250.00 445.00,250.00 429.38,223.91\" style=\"animation-delay:5.352s\"/><polygon points=\"398.12,223.91 429.38,223.91 413.75,197.81\" style=\"animation-delay:5.430s\"/><polygon points=\"351.25,197.81 382.50,197.81 366.88,171.72\" style=\"animation-delay:5.508s\"/><polygon points=\"382.50,197.81 413.75,197.81 398.12,171.72\" style=\"animation-delay:5.586s\"/><polygon points=\"366.88,171.72 398.12,171.72 382.50,145.62\" style=\"animation-delay:5.664s\"/><polygon points=\"257.50,145.62 288.75,145.62 273.12,119.53\" style=\"animation-delay:5.742s\"/><polygon points=\"288.75,145.62 320.00,145.62 304.38,119.53\" style=\"animation-delay:5.820s\"/><polygon points=\"273.12,119.53 304.38,119.53 288.75,93.44\" style=\"animation-delay:5.898s\"/><polygon points=\"320.00,145.62 351.25,145.62 335.62,119.53\" style=\"animation-delay:5.976s\"/><polygon points=\"351.25,145.62 382.50,145.62 366.88,119.53\" style=\"animation-delay:6.054s\"/><polygon points=\"335.62,119.53 366.88,119.53 351.25,93.44\" style=\"animation-delay:6.132s\"/><polygon points=\"288.75,93.44 320.00,93.44 304.38,67.34\" style=\"animation-delay:6.210s\"/><polygon points=\"320.00,93.44 351.25,93.44 335.62,67.34\" style=\"animation-delay:6.288s\"/><polygon points=\"304.38,67.34 335.62,67.34 320.00,41.25\" style=\"animation-delay:6.366s\"/></g><g class=\"nb-ts-tri-line\"><line x1=\"70.00\" y1=\"458.75\" x2=\"101.25\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.000s\"/><line x1=\"101.25\" y1=\"458.75\" x2=\"85.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.022s\"/><line x1=\"85.62\" y1=\"432.66\" x2=\"70.00\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.044s\"/><line x1=\"101.25\" y1=\"458.75\" x2=\"132.50\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.078s\"/><line x1=\"132.50\" y1=\"458.75\" x2=\"116.88\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.100s\"/><line x1=\"116.88\" y1=\"432.66\" x2=\"101.25\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.122s\"/><line x1=\"85.62\" y1=\"432.66\" x2=\"116.88\" y2=\"432.66\" style=\"--len:31.25;animation-delay:0.156s\"/><line x1=\"116.88\" y1=\"432.66\" x2=\"101.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:0.178s\"/><line x1=\"101.25\" y1=\"406.56\" x2=\"85.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.200s\"/><line x1=\"132.50\" y1=\"458.75\" x2=\"163.75\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.234s\"/><line x1=\"163.75\" y1=\"458.75\" x2=\"148.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.256s\"/><line x1=\"148.12\" y1=\"432.66\" x2=\"132.50\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.278s\"/><line x1=\"163.75\" y1=\"458.75\" x2=\"195.00\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.312s\"/><line x1=\"195.00\" y1=\"458.75\" x2=\"179.38\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.334s\"/><line x1=\"179.38\" y1=\"432.66\" x2=\"163.75\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.356s\"/><line x1=\"148.12\" y1=\"432.66\" x2=\"179.38\" y2=\"432.66\" style=\"--len:31.25;animation-delay:0.390s\"/><line x1=\"179.38\" y1=\"432.66\" x2=\"163.75\" y2=\"406.56\" style=\"--len:30.41;animation-delay:0.412s\"/><line x1=\"163.75\" y1=\"406.56\" x2=\"148.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.434s\"/><line x1=\"101.25\" y1=\"406.56\" x2=\"132.50\" y2=\"406.56\" style=\"--len:31.25;animation-delay:0.468s\"/><line x1=\"132.50\" y1=\"406.56\" x2=\"116.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:0.490s\"/><line x1=\"116.88\" y1=\"380.47\" x2=\"101.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:0.512s\"/><line x1=\"132.50\" y1=\"406.56\" x2=\"163.75\" y2=\"406.56\" style=\"--len:31.25;animation-delay:0.546s\"/><line x1=\"163.75\" y1=\"406.56\" x2=\"148.12\" y2=\"380.47\" style=\"--len:30.41;animation-delay:0.568s\"/><line x1=\"148.12\" y1=\"380.47\" x2=\"132.50\" y2=\"406.56\" style=\"--len:30.41;animation-delay:0.590s\"/><line x1=\"116.88\" y1=\"380.47\" x2=\"148.12\" y2=\"380.47\" style=\"--len:31.25;animation-delay:0.624s\"/><line x1=\"148.12\" y1=\"380.47\" x2=\"132.50\" y2=\"354.38\" style=\"--len:30.41;animation-delay:0.646s\"/><line x1=\"132.50\" y1=\"354.38\" x2=\"116.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:0.668s\"/><line x1=\"195.00\" y1=\"458.75\" x2=\"226.25\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.702s\"/><line x1=\"226.25\" y1=\"458.75\" x2=\"210.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.724s\"/><line x1=\"210.62\" y1=\"432.66\" x2=\"195.00\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.746s\"/><line x1=\"226.25\" y1=\"458.75\" x2=\"257.50\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.780s\"/><line x1=\"257.50\" y1=\"458.75\" x2=\"241.88\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.802s\"/><line x1=\"241.88\" y1=\"432.66\" x2=\"226.25\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.824s\"/><line x1=\"210.62\" y1=\"432.66\" x2=\"241.88\" y2=\"432.66\" style=\"--len:31.25;animation-delay:0.858s\"/><line x1=\"241.88\" y1=\"432.66\" x2=\"226.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:0.880s\"/><line x1=\"226.25\" y1=\"406.56\" x2=\"210.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.902s\"/><line x1=\"257.50\" y1=\"458.75\" x2=\"288.75\" y2=\"458.75\" style=\"--len:31.25;animation-delay:0.936s\"/><line x1=\"288.75\" y1=\"458.75\" x2=\"273.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:0.958s\"/><line x1=\"273.12\" y1=\"432.66\" x2=\"257.50\" y2=\"458.75\" style=\"--len:30.41;animation-delay:0.980s\"/><line x1=\"288.75\" y1=\"458.75\" x2=\"320.00\" y2=\"458.75\" style=\"--len:31.25;animation-delay:1.014s\"/><line x1=\"320.00\" y1=\"458.75\" x2=\"304.38\" y2=\"432.66\" style=\"--len:30.41;animation-delay:1.036s\"/><line x1=\"304.38\" y1=\"432.66\" x2=\"288.75\" y2=\"458.75\" style=\"--len:30.41;animation-delay:1.058s\"/><line x1=\"273.12\" y1=\"432.66\" x2=\"304.38\" y2=\"432.66\" style=\"--len:31.25;animation-delay:1.092s\"/><line x1=\"304.38\" y1=\"432.66\" x2=\"288.75\" y2=\"406.56\" style=\"--len:30.41;animation-delay:1.114s\"/><line x1=\"288.75\" y1=\"406.56\" x2=\"273.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:1.136s\"/><line x1=\"226.25\" y1=\"406.56\" x2=\"257.50\" y2=\"406.56\" style=\"--len:31.25;animation-delay:1.170s\"/><line x1=\"257.50\" y1=\"406.56\" x2=\"241.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:1.192s\"/><line x1=\"241.88\" y1=\"380.47\" x2=\"226.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:1.214s\"/><line x1=\"257.50\" y1=\"406.56\" x2=\"288.75\" y2=\"406.56\" style=\"--len:31.25;animation-delay:1.248s\"/><line x1=\"288.75\" y1=\"406.56\" x2=\"273.12\" y2=\"380.47\" style=\"--len:30.41;animation-delay:1.270s\"/><line x1=\"273.12\" y1=\"380.47\" x2=\"257.50\" y2=\"406.56\" style=\"--len:30.41;animation-delay:1.292s\"/><line x1=\"241.88\" y1=\"380.47\" x2=\"273.12\" y2=\"380.47\" style=\"--len:31.25;animation-delay:1.326s\"/><line x1=\"273.12\" y1=\"380.47\" x2=\"257.50\" y2=\"354.38\" style=\"--len:30.41;animation-delay:1.348s\"/><line x1=\"257.50\" y1=\"354.38\" x2=\"241.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:1.370s\"/><line x1=\"132.50\" y1=\"354.38\" x2=\"163.75\" y2=\"354.38\" style=\"--len:31.25;animation-delay:1.404s\"/><line x1=\"163.75\" y1=\"354.38\" x2=\"148.12\" y2=\"328.28\" style=\"--len:30.41;animation-delay:1.426s\"/><line x1=\"148.12\" y1=\"328.28\" x2=\"132.50\" y2=\"354.38\" style=\"--len:30.41;animation-delay:1.448s\"/><line x1=\"163.75\" y1=\"354.38\" x2=\"195.00\" y2=\"354.38\" style=\"--len:31.25;animation-delay:1.482s\"/><line x1=\"195.00\" y1=\"354.38\" x2=\"179.38\" y2=\"328.28\" style=\"--len:30.41;animation-delay:1.504s\"/><line x1=\"179.38\" y1=\"328.28\" x2=\"163.75\" y2=\"354.38\" style=\"--len:30.41;animation-delay:1.526s\"/><line x1=\"148.12\" y1=\"328.28\" x2=\"179.38\" y2=\"328.28\" style=\"--len:31.25;animation-delay:1.560s\"/><line x1=\"179.38\" y1=\"328.28\" x2=\"163.75\" y2=\"302.19\" style=\"--len:30.41;animation-delay:1.582s\"/><line x1=\"163.75\" y1=\"302.19\" x2=\"148.12\" y2=\"328.28\" style=\"--len:30.41;animation-delay:1.604s\"/><line x1=\"195.00\" y1=\"354.38\" x2=\"226.25\" y2=\"354.38\" style=\"--len:31.25;animation-delay:1.638s\"/><line x1=\"226.25\" y1=\"354.38\" x2=\"210.62\" y2=\"328.28\" style=\"--len:30.41;animation-delay:1.660s\"/><line x1=\"210.62\" y1=\"328.28\" x2=\"195.00\" y2=\"354.38\" style=\"--len:30.41;animation-delay:1.682s\"/><line x1=\"226.25\" y1=\"354.38\" x2=\"257.50\" y2=\"354.38\" style=\"--len:31.25;animation-delay:1.716s\"/><line x1=\"257.50\" y1=\"354.38\" x2=\"241.88\" y2=\"328.28\" style=\"--len:30.41;animation-delay:1.738s\"/><line x1=\"241.88\" y1=\"328.28\" x2=\"226.25\" y2=\"354.38\" style=\"--len:30.41;animation-delay:1.760s\"/><line x1=\"210.62\" y1=\"328.28\" x2=\"241.88\" y2=\"328.28\" style=\"--len:31.25;animation-delay:1.794s\"/><line x1=\"241.88\" y1=\"328.28\" x2=\"226.25\" y2=\"302.19\" style=\"--len:30.41;animation-delay:1.816s\"/><line x1=\"226.25\" y1=\"302.19\" x2=\"210.62\" y2=\"328.28\" style=\"--len:30.41;animation-delay:1.838s\"/><line x1=\"163.75\" y1=\"302.19\" x2=\"195.00\" y2=\"302.19\" style=\"--len:31.25;animation-delay:1.872s\"/><line x1=\"195.00\" y1=\"302.19\" x2=\"179.38\" y2=\"276.09\" style=\"--len:30.41;animation-delay:1.894s\"/><line x1=\"179.38\" y1=\"276.09\" x2=\"163.75\" y2=\"302.19\" style=\"--len:30.41;animation-delay:1.916s\"/><line x1=\"195.00\" y1=\"302.19\" x2=\"226.25\" y2=\"302.19\" style=\"--len:31.25;animation-delay:1.950s\"/><line x1=\"226.25\" y1=\"302.19\" x2=\"210.62\" y2=\"276.09\" style=\"--len:30.41;animation-delay:1.972s\"/><line x1=\"210.62\" y1=\"276.09\" x2=\"195.00\" y2=\"302.19\" style=\"--len:30.41;animation-delay:1.994s\"/><line x1=\"179.38\" y1=\"276.09\" x2=\"210.62\" y2=\"276.09\" style=\"--len:31.25;animation-delay:2.028s\"/><line x1=\"210.62\" y1=\"276.09\" x2=\"195.00\" y2=\"250.00\" style=\"--len:30.41;animation-delay:2.050s\"/><line x1=\"195.00\" y1=\"250.00\" x2=\"179.38\" y2=\"276.09\" style=\"--len:30.41;animation-delay:2.072s\"/><line x1=\"320.00\" y1=\"458.75\" x2=\"351.25\" y2=\"458.75\" style=\"--len:31.25;animation-delay:2.106s\"/><line x1=\"351.25\" y1=\"458.75\" x2=\"335.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.128s\"/><line x1=\"335.62\" y1=\"432.66\" x2=\"320.00\" y2=\"458.75\" style=\"--len:30.41;animation-delay:2.150s\"/><line x1=\"351.25\" y1=\"458.75\" x2=\"382.50\" y2=\"458.75\" style=\"--len:31.25;animation-delay:2.184s\"/><line x1=\"382.50\" y1=\"458.75\" x2=\"366.88\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.206s\"/><line x1=\"366.88\" y1=\"432.66\" x2=\"351.25\" y2=\"458.75\" style=\"--len:30.41;animation-delay:2.228s\"/><line x1=\"335.62\" y1=\"432.66\" x2=\"366.88\" y2=\"432.66\" style=\"--len:31.25;animation-delay:2.262s\"/><line x1=\"366.88\" y1=\"432.66\" x2=\"351.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:2.284s\"/><line x1=\"351.25\" y1=\"406.56\" x2=\"335.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.306s\"/><line x1=\"382.50\" y1=\"458.75\" x2=\"413.75\" y2=\"458.75\" style=\"--len:31.25;animation-delay:2.340s\"/><line x1=\"413.75\" y1=\"458.75\" x2=\"398.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.362s\"/><line x1=\"398.12\" y1=\"432.66\" x2=\"382.50\" y2=\"458.75\" style=\"--len:30.41;animation-delay:2.384s\"/><line x1=\"413.75\" y1=\"458.75\" x2=\"445.00\" y2=\"458.75\" style=\"--len:31.25;animation-delay:2.418s\"/><line x1=\"445.00\" y1=\"458.75\" x2=\"429.38\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.440s\"/><line x1=\"429.38\" y1=\"432.66\" x2=\"413.75\" y2=\"458.75\" style=\"--len:30.41;animation-delay:2.462s\"/><line x1=\"398.12\" y1=\"432.66\" x2=\"429.38\" y2=\"432.66\" style=\"--len:31.25;animation-delay:2.496s\"/><line x1=\"429.38\" y1=\"432.66\" x2=\"413.75\" y2=\"406.56\" style=\"--len:30.41;animation-delay:2.518s\"/><line x1=\"413.75\" y1=\"406.56\" x2=\"398.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.540s\"/><line x1=\"351.25\" y1=\"406.56\" x2=\"382.50\" y2=\"406.56\" style=\"--len:31.25;animation-delay:2.574s\"/><line x1=\"382.50\" y1=\"406.56\" x2=\"366.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:2.596s\"/><line x1=\"366.88\" y1=\"380.47\" x2=\"351.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:2.618s\"/><line x1=\"382.50\" y1=\"406.56\" x2=\"413.75\" y2=\"406.56\" style=\"--len:31.25;animation-delay:2.652s\"/><line x1=\"413.75\" y1=\"406.56\" x2=\"398.12\" y2=\"380.47\" style=\"--len:30.41;animation-delay:2.674s\"/><line x1=\"398.12\" y1=\"380.47\" x2=\"382.50\" y2=\"406.56\" style=\"--len:30.41;animation-delay:2.696s\"/><line x1=\"366.88\" y1=\"380.47\" x2=\"398.12\" y2=\"380.47\" style=\"--len:31.25;animation-delay:2.730s\"/><line x1=\"398.12\" y1=\"380.47\" x2=\"382.50\" y2=\"354.38\" style=\"--len:30.41;animation-delay:2.752s\"/><line x1=\"382.50\" y1=\"354.38\" x2=\"366.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:2.774s\"/><line x1=\"445.00\" y1=\"458.75\" x2=\"476.25\" y2=\"458.75\" style=\"--len:31.25;animation-delay:2.808s\"/><line x1=\"476.25\" y1=\"458.75\" x2=\"460.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.830s\"/><line x1=\"460.62\" y1=\"432.66\" x2=\"445.00\" y2=\"458.75\" style=\"--len:30.41;animation-delay:2.852s\"/><line x1=\"476.25\" y1=\"458.75\" x2=\"507.50\" y2=\"458.75\" style=\"--len:31.25;animation-delay:2.886s\"/><line x1=\"507.50\" y1=\"458.75\" x2=\"491.88\" y2=\"432.66\" style=\"--len:30.41;animation-delay:2.908s\"/><line x1=\"491.88\" y1=\"432.66\" x2=\"476.25\" y2=\"458.75\" style=\"--len:30.41;animation-delay:2.930s\"/><line x1=\"460.62\" y1=\"432.66\" x2=\"491.88\" y2=\"432.66\" style=\"--len:31.25;animation-delay:2.964s\"/><line x1=\"491.88\" y1=\"432.66\" x2=\"476.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:2.986s\"/><line x1=\"476.25\" y1=\"406.56\" x2=\"460.62\" y2=\"432.66\" style=\"--len:30.41;animation-delay:3.008s\"/><line x1=\"507.50\" y1=\"458.75\" x2=\"538.75\" y2=\"458.75\" style=\"--len:31.25;animation-delay:3.042s\"/><line x1=\"538.75\" y1=\"458.75\" x2=\"523.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:3.064s\"/><line x1=\"523.12\" y1=\"432.66\" x2=\"507.50\" y2=\"458.75\" style=\"--len:30.41;animation-delay:3.086s\"/><line x1=\"538.75\" y1=\"458.75\" x2=\"570.00\" y2=\"458.75\" style=\"--len:31.25;animation-delay:3.120s\"/><line x1=\"570.00\" y1=\"458.75\" x2=\"554.38\" y2=\"432.66\" style=\"--len:30.41;animation-delay:3.142s\"/><line x1=\"554.38\" y1=\"432.66\" x2=\"538.75\" y2=\"458.75\" style=\"--len:30.41;animation-delay:3.164s\"/><line x1=\"523.12\" y1=\"432.66\" x2=\"554.38\" y2=\"432.66\" style=\"--len:31.25;animation-delay:3.198s\"/><line x1=\"554.38\" y1=\"432.66\" x2=\"538.75\" y2=\"406.56\" style=\"--len:30.41;animation-delay:3.220s\"/><line x1=\"538.75\" y1=\"406.56\" x2=\"523.12\" y2=\"432.66\" style=\"--len:30.41;animation-delay:3.242s\"/><line x1=\"476.25\" y1=\"406.56\" x2=\"507.50\" y2=\"406.56\" style=\"--len:31.25;animation-delay:3.276s\"/><line x1=\"507.50\" y1=\"406.56\" x2=\"491.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:3.298s\"/><line x1=\"491.88\" y1=\"380.47\" x2=\"476.25\" y2=\"406.56\" style=\"--len:30.41;animation-delay:3.320s\"/><line x1=\"507.50\" y1=\"406.56\" x2=\"538.75\" y2=\"406.56\" style=\"--len:31.25;animation-delay:3.354s\"/><line x1=\"538.75\" y1=\"406.56\" x2=\"523.12\" y2=\"380.47\" style=\"--len:30.41;animation-delay:3.376s\"/><line x1=\"523.12\" y1=\"380.47\" x2=\"507.50\" y2=\"406.56\" style=\"--len:30.41;animation-delay:3.398s\"/><line x1=\"491.88\" y1=\"380.47\" x2=\"523.12\" y2=\"380.47\" style=\"--len:31.25;animation-delay:3.432s\"/><line x1=\"523.12\" y1=\"380.47\" x2=\"507.50\" y2=\"354.38\" style=\"--len:30.41;animation-delay:3.454s\"/><line x1=\"507.50\" y1=\"354.38\" x2=\"491.88\" y2=\"380.47\" style=\"--len:30.41;animation-delay:3.476s\"/><line x1=\"382.50\" y1=\"354.38\" x2=\"413.75\" y2=\"354.38\" style=\"--len:31.25;animation-delay:3.510s\"/><line x1=\"413.75\" y1=\"354.38\" x2=\"398.12\" y2=\"328.28\" style=\"--len:30.41;animation-delay:3.532s\"/><line x1=\"398.12\" y1=\"328.28\" x2=\"382.50\" y2=\"354.38\" style=\"--len:30.41;animation-delay:3.554s\"/><line x1=\"413.75\" y1=\"354.38\" x2=\"445.00\" y2=\"354.38\" style=\"--len:31.25;animation-delay:3.588s\"/><line x1=\"445.00\" y1=\"354.38\" x2=\"429.38\" y2=\"328.28\" style=\"--len:30.41;animation-delay:3.610s\"/><line x1=\"429.38\" y1=\"328.28\" x2=\"413.75\" y2=\"354.38\" style=\"--len:30.41;animation-delay:3.632s\"/><line x1=\"398.12\" y1=\"328.28\" x2=\"429.38\" y2=\"328.28\" style=\"--len:31.25;animation-delay:3.666s\"/><line x1=\"429.38\" y1=\"328.28\" x2=\"413.75\" y2=\"302.19\" style=\"--len:30.41;animation-delay:3.688s\"/><line x1=\"413.75\" y1=\"302.19\" x2=\"398.12\" y2=\"328.28\" style=\"--len:30.41;animation-delay:3.710s\"/><line x1=\"445.00\" y1=\"354.38\" x2=\"476.25\" y2=\"354.38\" style=\"--len:31.25;animation-delay:3.744s\"/><line x1=\"476.25\" y1=\"354.38\" x2=\"460.62\" y2=\"328.28\" style=\"--len:30.41;animation-delay:3.766s\"/><line x1=\"460.62\" y1=\"328.28\" x2=\"445.00\" y2=\"354.38\" style=\"--len:30.41;animation-delay:3.788s\"/><line x1=\"476.25\" y1=\"354.38\" x2=\"507.50\" y2=\"354.38\" style=\"--len:31.25;animation-delay:3.822s\"/><line x1=\"507.50\" y1=\"354.38\" x2=\"491.88\" y2=\"328.28\" style=\"--len:30.41;animation-delay:3.844s\"/><line x1=\"491.88\" y1=\"328.28\" x2=\"476.25\" y2=\"354.38\" style=\"--len:30.41;animation-delay:3.866s\"/><line x1=\"460.62\" y1=\"328.28\" x2=\"491.88\" y2=\"328.28\" style=\"--len:31.25;animation-delay:3.900s\"/><line x1=\"491.88\" y1=\"328.28\" x2=\"476.25\" y2=\"302.19\" style=\"--len:30.41;animation-delay:3.922s\"/><line x1=\"476.25\" y1=\"302.19\" x2=\"460.62\" y2=\"328.28\" style=\"--len:30.41;animation-delay:3.944s\"/><line x1=\"413.75\" y1=\"302.19\" x2=\"445.00\" y2=\"302.19\" style=\"--len:31.25;animation-delay:3.978s\"/><line x1=\"445.00\" y1=\"302.19\" x2=\"429.38\" y2=\"276.09\" style=\"--len:30.41;animation-delay:4.000s\"/><line x1=\"429.38\" y1=\"276.09\" x2=\"413.75\" y2=\"302.19\" style=\"--len:30.41;animation-delay:4.022s\"/><line x1=\"445.00\" y1=\"302.19\" x2=\"476.25\" y2=\"302.19\" style=\"--len:31.25;animation-delay:4.056s\"/><line x1=\"476.25\" y1=\"302.19\" x2=\"460.62\" y2=\"276.09\" style=\"--len:30.41;animation-delay:4.078s\"/><line x1=\"460.62\" y1=\"276.09\" x2=\"445.00\" y2=\"302.19\" style=\"--len:30.41;animation-delay:4.100s\"/><line x1=\"429.38\" y1=\"276.09\" x2=\"460.62\" y2=\"276.09\" style=\"--len:31.25;animation-delay:4.134s\"/><line x1=\"460.62\" y1=\"276.09\" x2=\"445.00\" y2=\"250.00\" style=\"--len:30.41;animation-delay:4.156s\"/><line x1=\"445.00\" y1=\"250.00\" x2=\"429.38\" y2=\"276.09\" style=\"--len:30.41;animation-delay:4.178s\"/><line x1=\"195.00\" y1=\"250.00\" x2=\"226.25\" y2=\"250.00\" style=\"--len:31.25;animation-delay:4.212s\"/><line x1=\"226.25\" y1=\"250.00\" x2=\"210.62\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.234s\"/><line x1=\"210.62\" y1=\"223.91\" x2=\"195.00\" y2=\"250.00\" style=\"--len:30.41;animation-delay:4.256s\"/><line x1=\"226.25\" y1=\"250.00\" x2=\"257.50\" y2=\"250.00\" style=\"--len:31.25;animation-delay:4.290s\"/><line x1=\"257.50\" y1=\"250.00\" x2=\"241.88\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.312s\"/><line x1=\"241.88\" y1=\"223.91\" x2=\"226.25\" y2=\"250.00\" style=\"--len:30.41;animation-delay:4.334s\"/><line x1=\"210.62\" y1=\"223.91\" x2=\"241.88\" y2=\"223.91\" style=\"--len:31.25;animation-delay:4.368s\"/><line x1=\"241.88\" y1=\"223.91\" x2=\"226.25\" y2=\"197.81\" style=\"--len:30.41;animation-delay:4.390s\"/><line x1=\"226.25\" y1=\"197.81\" x2=\"210.62\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.412s\"/><line x1=\"257.50\" y1=\"250.00\" x2=\"288.75\" y2=\"250.00\" style=\"--len:31.25;animation-delay:4.446s\"/><line x1=\"288.75\" y1=\"250.00\" x2=\"273.12\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.468s\"/><line x1=\"273.12\" y1=\"223.91\" x2=\"257.50\" y2=\"250.00\" style=\"--len:30.41;animation-delay:4.490s\"/><line x1=\"288.75\" y1=\"250.00\" x2=\"320.00\" y2=\"250.00\" style=\"--len:31.25;animation-delay:4.524s\"/><line x1=\"320.00\" y1=\"250.00\" x2=\"304.38\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.546s\"/><line x1=\"304.38\" y1=\"223.91\" x2=\"288.75\" y2=\"250.00\" style=\"--len:30.41;animation-delay:4.568s\"/><line x1=\"273.12\" y1=\"223.91\" x2=\"304.38\" y2=\"223.91\" style=\"--len:31.25;animation-delay:4.602s\"/><line x1=\"304.38\" y1=\"223.91\" x2=\"288.75\" y2=\"197.81\" style=\"--len:30.41;animation-delay:4.624s\"/><line x1=\"288.75\" y1=\"197.81\" x2=\"273.12\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.646s\"/><line x1=\"226.25\" y1=\"197.81\" x2=\"257.50\" y2=\"197.81\" style=\"--len:31.25;animation-delay:4.680s\"/><line x1=\"257.50\" y1=\"197.81\" x2=\"241.88\" y2=\"171.72\" style=\"--len:30.41;animation-delay:4.702s\"/><line x1=\"241.88\" y1=\"171.72\" x2=\"226.25\" y2=\"197.81\" style=\"--len:30.41;animation-delay:4.724s\"/><line x1=\"257.50\" y1=\"197.81\" x2=\"288.75\" y2=\"197.81\" style=\"--len:31.25;animation-delay:4.758s\"/><line x1=\"288.75\" y1=\"197.81\" x2=\"273.12\" y2=\"171.72\" style=\"--len:30.41;animation-delay:4.780s\"/><line x1=\"273.12\" y1=\"171.72\" x2=\"257.50\" y2=\"197.81\" style=\"--len:30.41;animation-delay:4.802s\"/><line x1=\"241.88\" y1=\"171.72\" x2=\"273.12\" y2=\"171.72\" style=\"--len:31.25;animation-delay:4.836s\"/><line x1=\"273.12\" y1=\"171.72\" x2=\"257.50\" y2=\"145.62\" style=\"--len:30.41;animation-delay:4.858s\"/><line x1=\"257.50\" y1=\"145.62\" x2=\"241.88\" y2=\"171.72\" style=\"--len:30.41;animation-delay:4.880s\"/><line x1=\"320.00\" y1=\"250.00\" x2=\"351.25\" y2=\"250.00\" style=\"--len:31.25;animation-delay:4.914s\"/><line x1=\"351.25\" y1=\"250.00\" x2=\"335.62\" y2=\"223.91\" style=\"--len:30.41;animation-delay:4.936s\"/><line x1=\"335.62\" y1=\"223.91\" x2=\"320.00\" y2=\"250.00\" style=\"--len:30.41;animation-delay:4.958s\"/><line x1=\"351.25\" y1=\"250.00\" x2=\"382.50\" y2=\"250.00\" style=\"--len:31.25;animation-delay:4.992s\"/><line x1=\"382.50\" y1=\"250.00\" x2=\"366.88\" y2=\"223.91\" style=\"--len:30.41;animation-delay:5.014s\"/><line x1=\"366.88\" y1=\"223.91\" x2=\"351.25\" y2=\"250.00\" style=\"--len:30.41;animation-delay:5.036s\"/><line x1=\"335.62\" y1=\"223.91\" x2=\"366.88\" y2=\"223.91\" style=\"--len:31.25;animation-delay:5.070s\"/><line x1=\"366.88\" y1=\"223.91\" x2=\"351.25\" y2=\"197.81\" style=\"--len:30.41;animation-delay:5.092s\"/><line x1=\"351.25\" y1=\"197.81\" x2=\"335.62\" y2=\"223.91\" style=\"--len:30.41;animation-delay:5.114s\"/><line x1=\"382.50\" y1=\"250.00\" x2=\"413.75\" y2=\"250.00\" style=\"--len:31.25;animation-delay:5.148s\"/><line x1=\"413.75\" y1=\"250.00\" x2=\"398.12\" y2=\"223.91\" style=\"--len:30.41;animation-delay:5.170s\"/><line x1=\"398.12\" y1=\"223.91\" x2=\"382.50\" y2=\"250.00\" style=\"--len:30.41;animation-delay:5.192s\"/><line x1=\"413.75\" y1=\"250.00\" x2=\"445.00\" y2=\"250.00\" style=\"--len:31.25;animation-delay:5.226s\"/><line x1=\"445.00\" y1=\"250.00\" x2=\"429.38\" y2=\"223.91\" style=\"--len:30.41;animation-delay:5.248s\"/><line x1=\"429.38\" y1=\"223.91\" x2=\"413.75\" y2=\"250.00\" style=\"--len:30.41;animation-delay:5.270s\"/><line x1=\"398.12\" y1=\"223.91\" x2=\"429.38\" y2=\"223.91\" style=\"--len:31.25;animation-delay:5.304s\"/><line x1=\"429.38\" y1=\"223.91\" x2=\"413.75\" y2=\"197.81\" style=\"--len:30.41;animation-delay:5.326s\"/><line x1=\"413.75\" y1=\"197.81\" x2=\"398.12\" y2=\"223.91\" style=\"--len:30.41;animation-delay:5.348s\"/><line x1=\"351.25\" y1=\"197.81\" x2=\"382.50\" y2=\"197.81\" style=\"--len:31.25;animation-delay:5.382s\"/><line x1=\"382.50\" y1=\"197.81\" x2=\"366.88\" y2=\"171.72\" style=\"--len:30.41;animation-delay:5.404s\"/><line x1=\"366.88\" y1=\"171.72\" x2=\"351.25\" y2=\"197.81\" style=\"--len:30.41;animation-delay:5.426s\"/><line x1=\"382.50\" y1=\"197.81\" x2=\"413.75\" y2=\"197.81\" style=\"--len:31.25;animation-delay:5.460s\"/><line x1=\"413.75\" y1=\"197.81\" x2=\"398.12\" y2=\"171.72\" style=\"--len:30.41;animation-delay:5.482s\"/><line x1=\"398.12\" y1=\"171.72\" x2=\"382.50\" y2=\"197.81\" style=\"--len:30.41;animation-delay:5.504s\"/><line x1=\"366.88\" y1=\"171.72\" x2=\"398.12\" y2=\"171.72\" style=\"--len:31.25;animation-delay:5.538s\"/><line x1=\"398.12\" y1=\"171.72\" x2=\"382.50\" y2=\"145.62\" style=\"--len:30.41;animation-delay:5.560s\"/><line x1=\"382.50\" y1=\"145.62\" x2=\"366.88\" y2=\"171.72\" style=\"--len:30.41;animation-delay:5.582s\"/><line x1=\"257.50\" y1=\"145.62\" x2=\"288.75\" y2=\"145.62\" style=\"--len:31.25;animation-delay:5.616s\"/><line x1=\"288.75\" y1=\"145.62\" x2=\"273.12\" y2=\"119.53\" style=\"--len:30.41;animation-delay:5.638s\"/><line x1=\"273.12\" y1=\"119.53\" x2=\"257.50\" y2=\"145.62\" style=\"--len:30.41;animation-delay:5.660s\"/><line x1=\"288.75\" y1=\"145.62\" x2=\"320.00\" y2=\"145.62\" style=\"--len:31.25;animation-delay:5.694s\"/><line x1=\"320.00\" y1=\"145.62\" x2=\"304.38\" y2=\"119.53\" style=\"--len:30.41;animation-delay:5.716s\"/><line x1=\"304.38\" y1=\"119.53\" x2=\"288.75\" y2=\"145.62\" style=\"--len:30.41;animation-delay:5.738s\"/><line x1=\"273.12\" y1=\"119.53\" x2=\"304.38\" y2=\"119.53\" style=\"--len:31.25;animation-delay:5.772s\"/><line x1=\"304.38\" y1=\"119.53\" x2=\"288.75\" y2=\"93.44\" style=\"--len:30.41;animation-delay:5.794s\"/><line x1=\"288.75\" y1=\"93.44\" x2=\"273.12\" y2=\"119.53\" style=\"--len:30.41;animation-delay:5.816s\"/><line x1=\"320.00\" y1=\"145.62\" x2=\"351.25\" y2=\"145.62\" style=\"--len:31.25;animation-delay:5.850s\"/><line x1=\"351.25\" y1=\"145.62\" x2=\"335.62\" y2=\"119.53\" style=\"--len:30.41;animation-delay:5.872s\"/><line x1=\"335.62\" y1=\"119.53\" x2=\"320.00\" y2=\"145.62\" style=\"--len:30.41;animation-delay:5.894s\"/><line x1=\"351.25\" y1=\"145.62\" x2=\"382.50\" y2=\"145.62\" style=\"--len:31.25;animation-delay:5.928s\"/><line x1=\"382.50\" y1=\"145.62\" x2=\"366.88\" y2=\"119.53\" style=\"--len:30.41;animation-delay:5.950s\"/><line x1=\"366.88\" y1=\"119.53\" x2=\"351.25\" y2=\"145.62\" style=\"--len:30.41;animation-delay:5.972s\"/><line x1=\"335.62\" y1=\"119.53\" x2=\"366.88\" y2=\"119.53\" style=\"--len:31.25;animation-delay:6.006s\"/><line x1=\"366.88\" y1=\"119.53\" x2=\"351.25\" y2=\"93.44\" style=\"--len:30.41;animation-delay:6.028s\"/><line x1=\"351.25\" y1=\"93.44\" x2=\"335.62\" y2=\"119.53\" style=\"--len:30.41;animation-delay:6.050s\"/><line x1=\"288.75\" y1=\"93.44\" x2=\"320.00\" y2=\"93.44\" style=\"--len:31.25;animation-delay:6.084s\"/><line x1=\"320.00\" y1=\"93.44\" x2=\"304.38\" y2=\"67.34\" style=\"--len:30.41;animation-delay:6.106s\"/><line x1=\"304.38\" y1=\"67.34\" x2=\"288.75\" y2=\"93.44\" style=\"--len:30.41;animation-delay:6.128s\"/><line x1=\"320.00\" y1=\"93.44\" x2=\"351.25\" y2=\"93.44\" style=\"--len:31.25;animation-delay:6.162s\"/><line x1=\"351.25\" y1=\"93.44\" x2=\"335.62\" y2=\"67.34\" style=\"--len:30.41;animation-delay:6.184s\"/><line x1=\"335.62\" y1=\"67.34\" x2=\"320.00\" y2=\"93.44\" style=\"--len:30.41;animation-delay:6.206s\"/><line x1=\"304.38\" y1=\"67.34\" x2=\"335.62\" y2=\"67.34\" style=\"--len:31.25;animation-delay:6.240s\"/><line x1=\"335.62\" y1=\"67.34\" x2=\"320.00\" y2=\"41.25\" style=\"--len:30.41;animation-delay:6.262s\"/><line x1=\"320.00\" y1=\"41.25\" x2=\"304.38\" y2=\"67.34\" style=\"--len:30.41;animation-delay:6.284s\"/></g><g class=\"nb-ts-pen\"><circle cx=\"101.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.022s\"/><circle cx=\"85.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.044s\"/><circle cx=\"70.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.066s\"/><circle cx=\"132.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.100s\"/><circle cx=\"116.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.122s\"/><circle cx=\"101.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.144s\"/><circle cx=\"116.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.178s\"/><circle cx=\"101.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.200s\"/><circle cx=\"85.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.222s\"/><circle cx=\"163.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.256s\"/><circle cx=\"148.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.278s\"/><circle cx=\"132.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.300s\"/><circle cx=\"195.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.334s\"/><circle cx=\"179.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.356s\"/><circle cx=\"163.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.378s\"/><circle cx=\"179.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.412s\"/><circle cx=\"163.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.434s\"/><circle cx=\"148.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.456s\"/><circle cx=\"132.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.490s\"/><circle cx=\"116.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:0.512s\"/><circle cx=\"101.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.534s\"/><circle cx=\"163.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.568s\"/><circle cx=\"148.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:0.590s\"/><circle cx=\"132.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.612s\"/><circle cx=\"148.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:0.646s\"/><circle cx=\"132.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:0.668s\"/><circle cx=\"116.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:0.690s\"/><circle cx=\"226.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.724s\"/><circle cx=\"210.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.746s\"/><circle cx=\"195.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.768s\"/><circle cx=\"257.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.802s\"/><circle cx=\"241.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.824s\"/><circle cx=\"226.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.846s\"/><circle cx=\"241.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.880s\"/><circle cx=\"226.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:0.902s\"/><circle cx=\"210.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.924s\"/><circle cx=\"288.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:0.958s\"/><circle cx=\"273.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:0.980s\"/><circle cx=\"257.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:1.002s\"/><circle cx=\"320.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:1.036s\"/><circle cx=\"304.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:1.058s\"/><circle cx=\"288.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:1.080s\"/><circle cx=\"304.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:1.114s\"/><circle cx=\"288.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:1.136s\"/><circle cx=\"273.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:1.158s\"/><circle cx=\"257.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:1.192s\"/><circle cx=\"241.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:1.214s\"/><circle cx=\"226.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:1.236s\"/><circle cx=\"288.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:1.270s\"/><circle cx=\"273.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:1.292s\"/><circle cx=\"257.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:1.314s\"/><circle cx=\"273.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:1.348s\"/><circle cx=\"257.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.370s\"/><circle cx=\"241.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:1.392s\"/><circle cx=\"163.75\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.426s\"/><circle cx=\"148.12\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.448s\"/><circle cx=\"132.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.470s\"/><circle cx=\"195.00\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.504s\"/><circle cx=\"179.38\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.526s\"/><circle cx=\"163.75\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.548s\"/><circle cx=\"179.38\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.582s\"/><circle cx=\"163.75\" cy=\"302.19\" r=\"2\" style=\"animation-delay:1.604s\"/><circle cx=\"148.12\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.626s\"/><circle cx=\"226.25\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.660s\"/><circle cx=\"210.62\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.682s\"/><circle cx=\"195.00\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.704s\"/><circle cx=\"257.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.738s\"/><circle cx=\"241.88\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.760s\"/><circle cx=\"226.25\" cy=\"354.38\" r=\"2\" style=\"animation-delay:1.782s\"/><circle cx=\"241.88\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.816s\"/><circle cx=\"226.25\" cy=\"302.19\" r=\"2\" style=\"animation-delay:1.838s\"/><circle cx=\"210.62\" cy=\"328.28\" r=\"2\" style=\"animation-delay:1.860s\"/><circle cx=\"195.00\" cy=\"302.19\" r=\"2\" style=\"animation-delay:1.894s\"/><circle cx=\"179.38\" cy=\"276.09\" r=\"2\" style=\"animation-delay:1.916s\"/><circle cx=\"163.75\" cy=\"302.19\" r=\"2\" style=\"animation-delay:1.938s\"/><circle cx=\"226.25\" cy=\"302.19\" r=\"2\" style=\"animation-delay:1.972s\"/><circle cx=\"210.62\" cy=\"276.09\" r=\"2\" style=\"animation-delay:1.994s\"/><circle cx=\"195.00\" cy=\"302.19\" r=\"2\" style=\"animation-delay:2.016s\"/><circle cx=\"210.62\" cy=\"276.09\" r=\"2\" style=\"animation-delay:2.050s\"/><circle cx=\"195.00\" cy=\"250.00\" r=\"2\" style=\"animation-delay:2.072s\"/><circle cx=\"179.38\" cy=\"276.09\" r=\"2\" style=\"animation-delay:2.094s\"/><circle cx=\"351.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.128s\"/><circle cx=\"335.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.150s\"/><circle cx=\"320.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.172s\"/><circle cx=\"382.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.206s\"/><circle cx=\"366.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.228s\"/><circle cx=\"351.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.250s\"/><circle cx=\"366.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.284s\"/><circle cx=\"351.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:2.306s\"/><circle cx=\"335.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.328s\"/><circle cx=\"413.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.362s\"/><circle cx=\"398.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.384s\"/><circle cx=\"382.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.406s\"/><circle cx=\"445.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.440s\"/><circle cx=\"429.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.462s\"/><circle cx=\"413.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.484s\"/><circle cx=\"429.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.518s\"/><circle cx=\"413.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:2.540s\"/><circle cx=\"398.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.562s\"/><circle cx=\"382.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:2.596s\"/><circle cx=\"366.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:2.618s\"/><circle cx=\"351.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:2.640s\"/><circle cx=\"413.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:2.674s\"/><circle cx=\"398.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:2.696s\"/><circle cx=\"382.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:2.718s\"/><circle cx=\"398.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:2.752s\"/><circle cx=\"382.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:2.774s\"/><circle cx=\"366.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:2.796s\"/><circle cx=\"476.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.830s\"/><circle cx=\"460.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.852s\"/><circle cx=\"445.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.874s\"/><circle cx=\"507.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.908s\"/><circle cx=\"491.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.930s\"/><circle cx=\"476.25\" cy=\"458.75\" r=\"2\" style=\"animation-delay:2.952s\"/><circle cx=\"491.88\" cy=\"432.66\" r=\"2\" style=\"animation-delay:2.986s\"/><circle cx=\"476.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:3.008s\"/><circle cx=\"460.62\" cy=\"432.66\" r=\"2\" style=\"animation-delay:3.030s\"/><circle cx=\"538.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:3.064s\"/><circle cx=\"523.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:3.086s\"/><circle cx=\"507.50\" cy=\"458.75\" r=\"2\" style=\"animation-delay:3.108s\"/><circle cx=\"570.00\" cy=\"458.75\" r=\"2\" style=\"animation-delay:3.142s\"/><circle cx=\"554.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:3.164s\"/><circle cx=\"538.75\" cy=\"458.75\" r=\"2\" style=\"animation-delay:3.186s\"/><circle cx=\"554.38\" cy=\"432.66\" r=\"2\" style=\"animation-delay:3.220s\"/><circle cx=\"538.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:3.242s\"/><circle cx=\"523.12\" cy=\"432.66\" r=\"2\" style=\"animation-delay:3.264s\"/><circle cx=\"507.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:3.298s\"/><circle cx=\"491.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:3.320s\"/><circle cx=\"476.25\" cy=\"406.56\" r=\"2\" style=\"animation-delay:3.342s\"/><circle cx=\"538.75\" cy=\"406.56\" r=\"2\" style=\"animation-delay:3.376s\"/><circle cx=\"523.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:3.398s\"/><circle cx=\"507.50\" cy=\"406.56\" r=\"2\" style=\"animation-delay:3.420s\"/><circle cx=\"523.12\" cy=\"380.47\" r=\"2\" style=\"animation-delay:3.454s\"/><circle cx=\"507.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.476s\"/><circle cx=\"491.88\" cy=\"380.47\" r=\"2\" style=\"animation-delay:3.498s\"/><circle cx=\"413.75\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.532s\"/><circle cx=\"398.12\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.554s\"/><circle cx=\"382.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.576s\"/><circle cx=\"445.00\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.610s\"/><circle cx=\"429.38\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.632s\"/><circle cx=\"413.75\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.654s\"/><circle cx=\"429.38\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.688s\"/><circle cx=\"413.75\" cy=\"302.19\" r=\"2\" style=\"animation-delay:3.710s\"/><circle cx=\"398.12\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.732s\"/><circle cx=\"476.25\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.766s\"/><circle cx=\"460.62\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.788s\"/><circle cx=\"445.00\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.810s\"/><circle cx=\"507.50\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.844s\"/><circle cx=\"491.88\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.866s\"/><circle cx=\"476.25\" cy=\"354.38\" r=\"2\" style=\"animation-delay:3.888s\"/><circle cx=\"491.88\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.922s\"/><circle cx=\"476.25\" cy=\"302.19\" r=\"2\" style=\"animation-delay:3.944s\"/><circle cx=\"460.62\" cy=\"328.28\" r=\"2\" style=\"animation-delay:3.966s\"/><circle cx=\"445.00\" cy=\"302.19\" r=\"2\" style=\"animation-delay:4.000s\"/><circle cx=\"429.38\" cy=\"276.09\" r=\"2\" style=\"animation-delay:4.022s\"/><circle cx=\"413.75\" cy=\"302.19\" r=\"2\" style=\"animation-delay:4.044s\"/><circle cx=\"476.25\" cy=\"302.19\" r=\"2\" style=\"animation-delay:4.078s\"/><circle cx=\"460.62\" cy=\"276.09\" r=\"2\" style=\"animation-delay:4.100s\"/><circle cx=\"445.00\" cy=\"302.19\" r=\"2\" style=\"animation-delay:4.122s\"/><circle cx=\"460.62\" cy=\"276.09\" r=\"2\" style=\"animation-delay:4.156s\"/><circle cx=\"445.00\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.178s\"/><circle cx=\"429.38\" cy=\"276.09\" r=\"2\" style=\"animation-delay:4.200s\"/><circle cx=\"226.25\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.234s\"/><circle cx=\"210.62\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.256s\"/><circle cx=\"195.00\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.278s\"/><circle cx=\"257.50\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.312s\"/><circle cx=\"241.88\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.334s\"/><circle cx=\"226.25\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.356s\"/><circle cx=\"241.88\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.390s\"/><circle cx=\"226.25\" cy=\"197.81\" r=\"2\" style=\"animation-delay:4.412s\"/><circle cx=\"210.62\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.434s\"/><circle cx=\"288.75\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.468s\"/><circle cx=\"273.12\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.490s\"/><circle cx=\"257.50\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.512s\"/><circle cx=\"320.00\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.546s\"/><circle cx=\"304.38\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.568s\"/><circle cx=\"288.75\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.590s\"/><circle cx=\"304.38\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.624s\"/><circle cx=\"288.75\" cy=\"197.81\" r=\"2\" style=\"animation-delay:4.646s\"/><circle cx=\"273.12\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.668s\"/><circle cx=\"257.50\" cy=\"197.81\" r=\"2\" style=\"animation-delay:4.702s\"/><circle cx=\"241.88\" cy=\"171.72\" r=\"2\" style=\"animation-delay:4.724s\"/><circle cx=\"226.25\" cy=\"197.81\" r=\"2\" style=\"animation-delay:4.746s\"/><circle cx=\"288.75\" cy=\"197.81\" r=\"2\" style=\"animation-delay:4.780s\"/><circle cx=\"273.12\" cy=\"171.72\" r=\"2\" style=\"animation-delay:4.802s\"/><circle cx=\"257.50\" cy=\"197.81\" r=\"2\" style=\"animation-delay:4.824s\"/><circle cx=\"273.12\" cy=\"171.72\" r=\"2\" style=\"animation-delay:4.858s\"/><circle cx=\"257.50\" cy=\"145.62\" r=\"2\" style=\"animation-delay:4.880s\"/><circle cx=\"241.88\" cy=\"171.72\" r=\"2\" style=\"animation-delay:4.902s\"/><circle cx=\"351.25\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.936s\"/><circle cx=\"335.62\" cy=\"223.91\" r=\"2\" style=\"animation-delay:4.958s\"/><circle cx=\"320.00\" cy=\"250.00\" r=\"2\" style=\"animation-delay:4.980s\"/><circle cx=\"382.50\" cy=\"250.00\" r=\"2\" style=\"animation-delay:5.014s\"/><circle cx=\"366.88\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.036s\"/><circle cx=\"351.25\" cy=\"250.00\" r=\"2\" style=\"animation-delay:5.058s\"/><circle cx=\"366.88\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.092s\"/><circle cx=\"351.25\" cy=\"197.81\" r=\"2\" style=\"animation-delay:5.114s\"/><circle cx=\"335.62\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.136s\"/><circle cx=\"413.75\" cy=\"250.00\" r=\"2\" style=\"animation-delay:5.170s\"/><circle cx=\"398.12\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.192s\"/><circle cx=\"382.50\" cy=\"250.00\" r=\"2\" style=\"animation-delay:5.214s\"/><circle cx=\"445.00\" cy=\"250.00\" r=\"2\" style=\"animation-delay:5.248s\"/><circle cx=\"429.38\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.270s\"/><circle cx=\"413.75\" cy=\"250.00\" r=\"2\" style=\"animation-delay:5.292s\"/><circle cx=\"429.38\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.326s\"/><circle cx=\"413.75\" cy=\"197.81\" r=\"2\" style=\"animation-delay:5.348s\"/><circle cx=\"398.12\" cy=\"223.91\" r=\"2\" style=\"animation-delay:5.370s\"/><circle cx=\"382.50\" cy=\"197.81\" r=\"2\" style=\"animation-delay:5.404s\"/><circle cx=\"366.88\" cy=\"171.72\" r=\"2\" style=\"animation-delay:5.426s\"/><circle cx=\"351.25\" cy=\"197.81\" r=\"2\" style=\"animation-delay:5.448s\"/><circle cx=\"413.75\" cy=\"197.81\" r=\"2\" style=\"animation-delay:5.482s\"/><circle cx=\"398.12\" cy=\"171.72\" r=\"2\" style=\"animation-delay:5.504s\"/><circle cx=\"382.50\" cy=\"197.81\" r=\"2\" style=\"animation-delay:5.526s\"/><circle cx=\"398.12\" cy=\"171.72\" r=\"2\" style=\"animation-delay:5.560s\"/><circle cx=\"382.50\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.582s\"/><circle cx=\"366.88\" cy=\"171.72\" r=\"2\" style=\"animation-delay:5.604s\"/><circle cx=\"288.75\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.638s\"/><circle cx=\"273.12\" cy=\"119.53\" r=\"2\" style=\"animation-delay:5.660s\"/><circle cx=\"257.50\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.682s\"/><circle cx=\"320.00\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.716s\"/><circle cx=\"304.38\" cy=\"119.53\" r=\"2\" style=\"animation-delay:5.738s\"/><circle cx=\"288.75\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.760s\"/><circle cx=\"304.38\" cy=\"119.53\" r=\"2\" style=\"animation-delay:5.794s\"/><circle cx=\"288.75\" cy=\"93.44\" r=\"2\" style=\"animation-delay:5.816s\"/><circle cx=\"273.12\" cy=\"119.53\" r=\"2\" style=\"animation-delay:5.838s\"/><circle cx=\"351.25\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.872s\"/><circle cx=\"335.62\" cy=\"119.53\" r=\"2\" style=\"animation-delay:5.894s\"/><circle cx=\"320.00\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.916s\"/><circle cx=\"382.50\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.950s\"/><circle cx=\"366.88\" cy=\"119.53\" r=\"2\" style=\"animation-delay:5.972s\"/><circle cx=\"351.25\" cy=\"145.62\" r=\"2\" style=\"animation-delay:5.994s\"/><circle cx=\"366.88\" cy=\"119.53\" r=\"2\" style=\"animation-delay:6.028s\"/><circle cx=\"351.25\" cy=\"93.44\" r=\"2\" style=\"animation-delay:6.050s\"/><circle cx=\"335.62\" cy=\"119.53\" r=\"2\" style=\"animation-delay:6.072s\"/><circle cx=\"320.00\" cy=\"93.44\" r=\"2\" style=\"animation-delay:6.106s\"/><circle cx=\"304.38\" cy=\"67.34\" r=\"2\" style=\"animation-delay:6.128s\"/><circle cx=\"288.75\" cy=\"93.44\" r=\"2\" style=\"animation-delay:6.150s\"/><circle cx=\"351.25\" cy=\"93.44\" r=\"2\" style=\"animation-delay:6.184s\"/><circle cx=\"335.62\" cy=\"67.34\" r=\"2\" style=\"animation-delay:6.206s\"/><circle cx=\"320.00\" cy=\"93.44\" r=\"2\" style=\"animation-delay:6.228s\"/><circle cx=\"335.62\" cy=\"67.34\" r=\"2\" style=\"animation-delay:6.262s\"/><circle cx=\"320.00\" cy=\"41.25\" r=\"2\" style=\"animation-delay:6.284s\"/><circle cx=\"304.38\" cy=\"67.34\" r=\"2\" style=\"animation-delay:6.306s\"/></g></svg>",
            code: "<b>import</b> <m>turtle</m> <b>as</b> <m>t</m>\n\n<em># 谢尔宾斯基三角：把三角形一分为四，挖掉中间那块，对三个角递归</em>\n<m>t</m>.<s>setup</s>(<u>600</u>, <u>520</u>); <m>t</m>.<s>hideturtle</s>(); <m>t</m>.<s>speed</s>(<u>0</u>)\n<m>t</m>.<s>color</s>(<i>\"#00e5ff\"</i>, <i>\"#0b2b38\"</i>)\n\n<b>def</b> <s>mid</s>(p, q):\n    <b>return</b> ((p[<u>0</u>]+q[<u>0</u>])/<u>2</u>, (p[<u>1</u>]+q[<u>1</u>])/<u>2</u>)\n\n<b>def</b> <s>sierpinski</s>(pts, depth):\n    <b>if</b> depth == <u>0</u>:\n        <m>t</m>.<s>penup</s>(); <m>t</m>.<s>goto</s>(pts[<u>0</u>]); <m>t</m>.<s>pendown</s>()\n        <m>t</m>.<s>begin_fill</s>()\n        <b>for</b> p <b>in</b> pts[<u>1</u>:]: <m>t</m>.<s>goto</s>(p)\n        <m>t</m>.<s>goto</s>(pts[<u>0</u>])\n        <m>t</m>.<s>end_fill</s>()\n        <b>return</b>\n    a, b, c = pts\n    <s>sierpinski</s>([a, <s>mid</s>(a,b), <s>mid</s>(a,c)], depth-<u>1</u>)\n    <s>sierpinski</s>([<s>mid</s>(a,b), b, <s>mid</s>(b,c)], depth-<u>1</u>)\n    <s>sierpinski</s>([<s>mid</s>(a,c), <s>mid</s>(b,c), c], depth-<u>1</u>)\n\nR = <u>250</u>\n<s>sierpinski</s>([(-R, -R*<u>0.62</u>), (R, -R*<u>0.62</u>), (<u>0</u>, R*<u>1.05</u>)], <u>4</u>)\n<m>t</m>.<s>done</s>()",
            plain: "import turtle as t\n\n# 谢尔宾斯基三角：把三角形一分为四，挖掉中间那块，对三个角递归\nt.setup(600, 520); t.hideturtle(); t.speed(0)\nt.color(\"#00e5ff\", \"#0b2b38\")\n\ndef mid(p, q):\n    return ((p[0]+q[0])/2, (p[1]+q[1])/2)\n\ndef sierpinski(pts, depth):\n    if depth == 0:\n        t.penup(); t.goto(pts[0]); t.pendown()\n        t.begin_fill()\n        for p in pts[1:]: t.goto(p)\n        t.goto(pts[0])\n        t.end_fill()\n        return\n    a, b, c = pts\n    sierpinski([a, mid(a,b), mid(a,c)], depth-1)\n    sierpinski([mid(a,b), b, mid(b,c)], depth-1)\n    sierpinski([mid(a,c), mid(b,c), c], depth-1)\n\nR = 250\nsierpinski([(-R, -R*0.62), (R, -R*0.62), (0, R*1.05)], 4)\nt.done()",
            langs: [{"id": "py", "name": "Python", "file": "sierpinski.py", "code": "<b>import</b> <m>turtle</m> <b>as</b> <m>t</m>\n\n<em># 谢尔宾斯基三角：把三角形一分为四，挖掉中间那块，对三个角递归</em>\n<m>t</m>.<s>setup</s>(<u>600</u>, <u>520</u>); <m>t</m>.<s>hideturtle</s>(); <m>t</m>.<s>speed</s>(<u>0</u>)\n<m>t</m>.<s>color</s>(<i>\"#00e5ff\"</i>, <i>\"#0b2b38\"</i>)\n\n<b>def</b> <s>mid</s>(p, q):\n    <b>return</b> ((p[<u>0</u>]+q[<u>0</u>])/<u>2</u>, (p[<u>1</u>]+q[<u>1</u>])/<u>2</u>)\n\n<b>def</b> <s>sierpinski</s>(pts, depth):\n    <b>if</b> depth == <u>0</u>:\n        <m>t</m>.<s>penup</s>(); <m>t</m>.<s>goto</s>(pts[<u>0</u>]); <m>t</m>.<s>pendown</s>()\n        <m>t</m>.<s>begin_fill</s>()\n        <b>for</b> p <b>in</b> pts[<u>1</u>:]: <m>t</m>.<s>goto</s>(p)\n        <m>t</m>.<s>goto</s>(pts[<u>0</u>])\n        <m>t</m>.<s>end_fill</s>()\n        <b>return</b>\n    a, b, c = pts\n    <s>sierpinski</s>([a, <s>mid</s>(a,b), <s>mid</s>(a,c)], depth-<u>1</u>)\n    <s>sierpinski</s>([<s>mid</s>(a,b), b, <s>mid</s>(b,c)], depth-<u>1</u>)\n    <s>sierpinski</s>([<s>mid</s>(a,c), <s>mid</s>(b,c), c], depth-<u>1</u>)\n\nR = <u>250</u>\n<s>sierpinski</s>([(-R, -R*<u>0.62</u>), (R, -R*<u>0.62</u>), (<u>0</u>, R*<u>1.05</u>)], <u>4</u>)\n<m>t</m>.<s>done</s>()", "plain": "import turtle as t\n\n# 谢尔宾斯基三角：把三角形一分为四，挖掉中间那块，对三个角递归\nt.setup(600, 520); t.hideturtle(); t.speed(0)\nt.color(\"#00e5ff\", \"#0b2b38\")\n\ndef mid(p, q):\n    return ((p[0]+q[0])/2, (p[1]+q[1])/2)\n\ndef sierpinski(pts, depth):\n    if depth == 0:\n        t.penup(); t.goto(pts[0]); t.pendown()\n        t.begin_fill()\n        for p in pts[1:]: t.goto(p)\n        t.goto(pts[0])\n        t.end_fill()\n        return\n    a, b, c = pts\n    sierpinski([a, mid(a,b), mid(a,c)], depth-1)\n    sierpinski([mid(a,b), b, mid(b,c)], depth-1)\n    sierpinski([mid(a,c), mid(b,c), c], depth-1)\n\nR = 250\nsierpinski([(-R, -R*0.62), (R, -R*0.62), (0, R*1.05)], 4)\nt.done()"}, {"id": "js", "name": "JavaScript", "file": "sierpinski.js", "code": "<em>// 谢尔宾斯基三角 · JavaScript + Canvas 2D</em>\n<em>// 直接在浏览器里跑，把这段贴进 &lt;script&gt; 或控制台即可。</em>\n<b>const</b> canvas = document.createElement(<i>'canvas'</i>);\ncanvas.width = 640; canvas.height = 560;\ndocument.body.appendChild(canvas);\n<b>const</b> ctx = canvas.getContext(<i>'2d'</i>);\nctx.fillStyle = <i>'#060a14'</i>;\nctx.fillRect(0, 0, canvas.width, canvas.height);\n\n<b>const</b> R = 250;\n<b>const</b> A = [-R, -R * 0.62];\n<b>const</b> B = [ R, -R * 0.62];\n<b>const</b> C = [ 0,  R * 1.05];\n<b>const</b> shiftY = (A[1] + C[1]) / 2 - 10;\n\n<em>// 世界坐标 -&gt; 画布坐标</em>\n<b>function</b> toCanvas(p) {\n  <b>return</b> [p[0] + canvas.width / 2, canvas.height / 2 - (p[1] - shiftY)];\n}\n<b>function</b> mid(p, q) {\n  <b>return</b> [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];\n}\n\n<em>// 递归：三角形一分为四，挖掉中间那块</em>\n<b>function</b> sierpinski(pts, depth) {\n  <b>if</b> (depth === 0) {\n    <b>const</b> s = pts.map(toCanvas);\n    ctx.beginPath();\n    ctx.moveTo(s[0][0], s[0][1]);\n    ctx.lineTo(s[1][0], s[1][1]);\n    ctx.lineTo(s[2][0], s[2][1]);\n    ctx.closePath();\n    ctx.fillStyle = <i>'rgba(0,229,255,.16)'</i>;\n    ctx.fill();\n    ctx.strokeStyle = <i>'#00e5ff'</i>;\n    ctx.lineWidth = 1.4;\n    ctx.stroke();\n    <b>return</b>;\n  }\n  <b>const</b> [a, b, c] = pts;\n  sierpinski([a, mid(a, b), mid(a, c)], depth - 1);\n  sierpinski([mid(a, b), b, mid(b, c)], depth - 1);\n  sierpinski([mid(a, c), mid(b, c), c], depth - 1);\n}\n\nsierpinski([A, B, C], 4);\n", "plain": "// 谢尔宾斯基三角 · JavaScript + Canvas 2D\n// 直接在浏览器里跑，把这段贴进 <script> 或控制台即可。\nconst canvas = document.createElement('canvas');\ncanvas.width = 640; canvas.height = 560;\ndocument.body.appendChild(canvas);\nconst ctx = canvas.getContext('2d');\nctx.fillStyle = '#060a14';\nctx.fillRect(0, 0, canvas.width, canvas.height);\n\nconst R = 250;\nconst A = [-R, -R * 0.62];\nconst B = [ R, -R * 0.62];\nconst C = [ 0,  R * 1.05];\nconst shiftY = (A[1] + C[1]) / 2 - 10;\n\n// 世界坐标 -> 画布坐标\nfunction toCanvas(p) {\n  return [p[0] + canvas.width / 2, canvas.height / 2 - (p[1] - shiftY)];\n}\nfunction mid(p, q) {\n  return [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];\n}\n\n// 递归：三角形一分为四，挖掉中间那块\nfunction sierpinski(pts, depth) {\n  if (depth === 0) {\n    const s = pts.map(toCanvas);\n    ctx.beginPath();\n    ctx.moveTo(s[0][0], s[0][1]);\n    ctx.lineTo(s[1][0], s[1][1]);\n    ctx.lineTo(s[2][0], s[2][1]);\n    ctx.closePath();\n    ctx.fillStyle = 'rgba(0,229,255,.16)';\n    ctx.fill();\n    ctx.strokeStyle = '#00e5ff';\n    ctx.lineWidth = 1.4;\n    ctx.stroke();\n    return;\n  }\n  const [a, b, c] = pts;\n  sierpinski([a, mid(a, b), mid(a, c)], depth - 1);\n  sierpinski([mid(a, b), b, mid(b, c)], depth - 1);\n  sierpinski([mid(a, c), mid(b, c), c], depth - 1);\n}\n\nsierpinski([A, B, C], 4);\n"}, {"id": "c", "name": "C", "file": "sierpinski.c", "code": "<em>/* 谢尔宾斯基三角 · C 语言，纯控制台用字符画\n   编译： gcc sierpinski.c -o sierpinski\n   运行： ./sierpinski        （Windows 上是 sierpinski.exe）\n*/</em>\n#<b>include</b> &lt;stdio.h&gt;\n\n#<b>define</b> WIDTH  79          <em>/* 一行多少列 */</em>\n#<b>define</b> DEPTH  5           <em>/* 递归层数，越大越细 */</em>\n\n<em>/* 判断 (x, y) 这个点是否落在被挖掉的洞里。\n   规则：谢尔宾斯基三角 = 帕斯卡三角的奇数项，\n   等价于「x 的二进制位是否被 y 完全包含」。 */</em>\n<b>static</b> <b>int</b> in_hole(<b>int</b> x, <b>int</b> y)\n{\n    <b>return</b> (x &amp; y) == y;\n}\n\n<b>int</b> <b>main</b>(<b>void</b>)\n{\n    <b>int</b> rows = 1 &lt;&lt; DEPTH;              <em>/* DEPTH 层 -&gt; 2^DEPTH 行 */</em>\n    <b>int</b> r, i;\n\n    <b>for</b> (r = 0; r &lt; rows; r++) {\n        <em>/* 每行左边补空格，让整体成三角形而不是直角三角形 */</em>\n        <b>for</b> (i = 0; i &lt; rows - r - 1; i++)\n            <b>putchar</b>(' ');\n\n        <b>for</b> (i = 0; i &lt;= r; i++) {\n            <b>if</b> (in_hole(r - i, i))\n                <b>printf</b>(<i>\"  \"</i>);           <em>/* 洞：留空 */</em>\n            <b>else</b>\n                <b>printf</b>(<i>\"##\"</i>);           <em>/* 实体：两个字符，看起来更方 */</em>\n        }\n        <b>putchar</b>('\\n');\n    }\n    <b>return</b> 0;\n}\n", "plain": "/* 谢尔宾斯基三角 · C 语言，纯控制台用字符画\n   编译： gcc sierpinski.c -o sierpinski\n   运行： ./sierpinski        （Windows 上是 sierpinski.exe）\n*/\n#include <stdio.h>\n\n#define WIDTH  79          /* 一行多少列 */\n#define DEPTH  5           /* 递归层数，越大越细 */\n\n/* 判断 (x, y) 这个点是否落在被挖掉的洞里。\n   规则：谢尔宾斯基三角 = 帕斯卡三角的奇数项，\n   等价于「x 的二进制位是否被 y 完全包含」。 */\nstatic int in_hole(int x, int y)\n{\n    return (x & y) == y;\n}\n\nint main(void)\n{\n    int rows = 1 << DEPTH;              /* DEPTH 层 -> 2^DEPTH 行 */\n    int r, i;\n\n    for (r = 0; r < rows; r++) {\n        /* 每行左边补空格，让整体成三角形而不是直角三角形 */\n        for (i = 0; i < rows - r - 1; i++)\n            putchar(' ');\n\n        for (i = 0; i <= r; i++) {\n            if (in_hole(r - i, i))\n                printf(\"  \");           /* 洞：留空 */\n            else\n                printf(\"##\");           /* 实体：两个字符，看起来更方 */\n        }\n        putchar('\\n');\n    }\n    return 0;\n}\n"}]
        }
        ,{
            file: 'koch.py',
            id: "koch",
            tab: "\u2744 \u79D1\u8D6B\u96EA\u82B1",
            name: "Python \u6D77\u9F9F\u7ED8\u56FE <i>\u00B7 \u79D1\u8D6B\u96EA\u82B1</i>",
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"Python 海龟递归画出科赫雪花\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><path class=\"nb-ts-path\" d=\"M320.00,55.00L322.19,58.80L326.58,58.80L324.38,62.59L326.58,66.39L330.96,66.39L333.15,62.59L335.34,66.39L339.73,66.39L337.53,70.19L339.73,73.98L335.34,73.98L333.15,77.78L335.34,81.57L339.73,81.57L337.53,85.37L339.73,89.17L344.11,89.17L346.30,85.37L348.49,89.17L352.88,89.17L355.07,85.37L352.88,81.57L357.26,81.57L359.45,77.78L361.64,81.57L366.03,81.57L363.84,85.37L366.03,89.17L370.41,89.17L372.60,85.37L374.79,89.17L379.18,89.17L376.99,92.96L379.18,96.76L374.79,96.76L372.60,100.56L374.79,104.35L379.18,104.35L376.99,108.15L379.18,111.94L374.79,111.94L372.60,115.74L370.41,111.94L366.03,111.94L363.84,115.74L366.03,119.54L361.64,119.54L359.45,123.33L361.64,127.13L366.03,127.13L363.84,130.93L366.03,134.72L370.41,134.72L372.60,130.93L374.79,134.72L379.18,134.72L376.99,138.52L379.18,142.31L374.79,142.31L372.60,146.11L374.79,149.91L379.18,149.91L376.99,153.70L379.18,157.50L383.56,157.50L385.75,153.70L387.95,157.50L392.33,157.50L394.52,153.70L392.33,149.91L396.71,149.91L398.90,146.11L401.10,149.91L405.48,149.91L403.29,153.70L405.48,157.50L409.86,157.50L412.06,153.70L414.25,157.50L418.63,157.50L420.82,153.70L418.63,149.91L423.01,149.91L425.21,146.11L423.01,142.31L418.63,142.31L420.82,138.52L418.63,134.72L423.01,134.72L425.21,130.93L427.40,134.72L431.78,134.72L433.97,130.93L431.78,127.13L436.17,127.13L438.36,123.33L440.55,127.13L444.93,127.13L442.74,130.93L444.93,134.72L449.32,134.72L451.51,130.93L453.70,134.72L458.08,134.72L455.89,138.52L458.08,142.31L453.70,142.31L451.51,146.11L453.70,149.91L458.08,149.91L455.89,153.70L458.08,157.50L462.47,157.50L464.66,153.70L466.85,157.50L471.23,157.50L473.43,153.70L471.23,149.91L475.62,149.91L477.81,146.11L480.00,149.91L484.38,149.91L482.19,153.70L484.38,157.50L488.77,157.50L490.96,153.70L493.15,157.50L497.54,157.50L495.34,161.30L497.54,165.09L493.15,165.09L490.96,168.89L493.15,172.69L497.54,172.69L495.34,176.48L497.54,180.28L493.15,180.28L490.96,184.07L488.77,180.28L484.38,180.28L482.19,184.07L484.38,187.87L480.00,187.87L477.81,191.67L480.00,195.46L484.38,195.46L482.19,199.26L484.38,203.06L488.77,203.06L490.96,199.26L493.15,203.06L497.54,203.06L495.34,206.85L497.54,210.65L493.15,210.65L490.96,214.44L493.15,218.24L497.54,218.24L495.34,222.04L497.54,225.83L493.15,225.83L490.96,229.63L488.77,225.83L484.38,225.83L482.19,229.63L484.38,233.43L480.00,233.43L477.81,237.22L475.62,233.43L471.23,233.43L473.43,229.63L471.23,225.83L466.85,225.83L464.66,229.63L462.47,225.83L458.08,225.83L455.89,229.63L458.08,233.43L453.70,233.43L451.51,237.22L453.70,241.02L458.08,241.02L455.89,244.81L458.08,248.61L453.70,248.61L451.51,252.41L449.32,248.61L444.93,248.61L442.74,252.41L444.93,256.20L440.55,256.20L438.36,260.00L440.55,263.80L444.93,263.80L442.74,267.59L444.93,271.39L449.32,271.39L451.51,267.59L453.70,271.39L458.08,271.39L455.89,275.19L458.08,278.98L453.70,278.98L451.51,282.78L453.70,286.57L458.08,286.57L455.89,290.37L458.08,294.17L462.47,294.17L464.66,290.37L466.85,294.17L471.23,294.17L473.43,290.37L471.23,286.57L475.62,286.57L477.81,282.78L480.00,286.57L484.38,286.57L482.19,290.37L484.38,294.17L488.77,294.17L490.96,290.37L493.15,294.17L497.54,294.17L495.34,297.96L497.54,301.76L493.15,301.76L490.96,305.56L493.15,309.35L497.54,309.35L495.34,313.15L497.54,316.94L493.15,316.94L490.96,320.74L488.77,316.94L484.38,316.94L482.19,320.74L484.38,324.54L480.00,324.54L477.81,328.33L480.00,332.13L484.38,332.13L482.19,335.93L484.38,339.72L488.77,339.72L490.96,335.93L493.15,339.72L497.54,339.72L495.34,343.52L497.54,347.31L493.15,347.31L490.96,351.11L493.15,354.91L497.54,354.91L495.34,358.70L497.54,362.50L493.15,362.50L490.96,366.30L488.77,362.50L484.38,362.50L482.19,366.30L484.38,370.09L480.00,370.09L477.81,373.89L475.62,370.09L471.23,370.09L473.43,366.30L471.23,362.50L466.85,362.50L464.66,366.30L462.47,362.50L458.08,362.50L455.89,366.30L458.08,370.09L453.70,370.09L451.51,373.89L453.70,377.69L458.08,377.69L455.89,381.48L458.08,385.28L453.70,385.28L451.51,389.07L449.32,385.28L444.93,385.28L442.74,389.07L444.93,392.87L440.55,392.87L438.36,396.67L436.17,392.87L431.78,392.87L433.97,389.07L431.78,385.28L427.40,385.28L425.21,389.07L423.01,385.28L418.63,385.28L420.82,381.48L418.63,377.69L423.01,377.69L425.21,373.89L423.01,370.09L418.63,370.09L420.82,366.30L418.63,362.50L414.25,362.50L412.06,366.30L409.86,362.50L405.48,362.50L403.29,366.30L405.48,370.09L401.10,370.09L398.90,373.89L396.71,370.09L392.33,370.09L394.52,366.30L392.33,362.50L387.95,362.50L385.75,366.30L383.56,362.50L379.18,362.50L376.99,366.30L379.18,370.09L374.79,370.09L372.60,373.89L374.79,377.69L379.18,377.69L376.99,381.48L379.18,385.28L374.79,385.28L372.60,389.07L370.41,385.28L366.03,385.28L363.84,389.07L366.03,392.87L361.64,392.87L359.45,396.67L361.64,400.46L366.03,400.46L363.84,404.26L366.03,408.06L370.41,408.06L372.60,404.26L374.79,408.06L379.18,408.06L376.99,411.85L379.18,415.65L374.79,415.65L372.60,419.44L374.79,423.24L379.18,423.24L376.99,427.04L379.18,430.83L374.79,430.83L372.60,434.63L370.41,430.83L366.03,430.83L363.84,434.63L366.03,438.43L361.64,438.43L359.45,442.22L357.26,438.43L352.88,438.43L355.07,434.63L352.88,430.83L348.49,430.83L346.30,434.63L344.11,430.83L339.73,430.83L337.53,434.63L339.73,438.43L335.34,438.43L333.15,442.22L335.34,446.02L339.73,446.02L337.53,449.81L339.73,453.61L335.34,453.61L333.15,457.41L330.96,453.61L326.58,453.61L324.38,457.41L326.58,461.20L322.19,461.20L320.00,465.00L317.81,461.20L313.42,461.20L315.62,457.41L313.42,453.61L309.04,453.61L306.85,457.41L304.66,453.61L300.27,453.61L302.47,449.81L300.27,446.02L304.66,446.02L306.85,442.22L304.66,438.43L300.27,438.43L302.47,434.63L300.27,430.83L295.89,430.83L293.70,434.63L291.51,430.83L287.12,430.83L284.93,434.63L287.12,438.43L282.74,438.43L280.55,442.22L278.36,438.43L273.97,438.43L276.16,434.63L273.97,430.83L269.59,430.83L267.40,434.63L265.21,430.83L260.82,430.83L263.01,427.04L260.82,423.24L265.21,423.24L267.40,419.44L265.21,415.65L260.82,415.65L263.01,411.85L260.82,408.06L265.21,408.06L267.40,404.26L269.59,408.06L273.97,408.06L276.16,404.26L273.97,400.46L278.36,400.46L280.55,396.67L278.36,392.87L273.97,392.87L276.16,389.07L273.97,385.28L269.59,385.28L267.40,389.07L265.21,385.28L260.82,385.28L263.01,381.48L260.82,377.69L265.21,377.69L267.40,373.89L265.21,370.09L260.82,370.09L263.01,366.30L260.82,362.50L256.44,362.50L254.25,366.30L252.05,362.50L247.67,362.50L245.48,366.30L247.67,370.09L243.29,370.09L241.10,373.89L238.90,370.09L234.52,370.09L236.71,366.30L234.52,362.50L230.14,362.50L227.94,366.30L225.75,362.50L221.37,362.50L219.18,366.30L221.37,370.09L216.99,370.09L214.79,373.89L216.99,377.69L221.37,377.69L219.18,381.48L221.37,385.28L216.99,385.28L214.79,389.07L212.60,385.28L208.22,385.28L206.03,389.07L208.22,392.87L203.83,392.87L201.64,396.67L199.45,392.87L195.07,392.87L197.26,389.07L195.07,385.28L190.68,385.28L188.49,389.07L186.30,385.28L181.92,385.28L184.11,381.48L181.92,377.69L186.30,377.69L188.49,373.89L186.30,370.09L181.92,370.09L184.11,366.30L181.92,362.50L177.53,362.50L175.34,366.30L173.15,362.50L168.77,362.50L166.57,366.30L168.77,370.09L164.38,370.09L162.19,373.89L160.00,370.09L155.62,370.09L157.81,366.30L155.62,362.50L151.23,362.50L149.04,366.30L146.85,362.50L142.46,362.50L144.66,358.70L142.46,354.91L146.85,354.91L149.04,351.11L146.85,347.31L142.46,347.31L144.66,343.52L142.46,339.72L146.85,339.72L149.04,335.93L151.23,339.72L155.62,339.72L157.81,335.93L155.62,332.13L160.00,332.13L162.19,328.33L160.00,324.54L155.62,324.54L157.81,320.74L155.62,316.94L151.23,316.94L149.04,320.74L146.85,316.94L142.46,316.94L144.66,313.15L142.46,309.35L146.85,309.35L149.04,305.56L146.85,301.76L142.46,301.76L144.66,297.96L142.46,294.17L146.85,294.17L149.04,290.37L151.23,294.17L155.62,294.17L157.81,290.37L155.62,286.57L160.00,286.57L162.19,282.78L164.38,286.57L168.77,286.57L166.57,290.37L168.77,294.17L173.15,294.17L175.34,290.37L177.53,294.17L181.92,294.17L184.11,290.37L181.92,286.57L186.30,286.57L188.49,282.78L186.30,278.98L181.92,278.98L184.11,275.19L181.92,271.39L186.30,271.39L188.49,267.59L190.68,271.39L195.07,271.39L197.26,267.59L195.07,263.80L199.45,263.80L201.64,260.00L199.45,256.20L195.07,256.20L197.26,252.41L195.07,248.61L190.68,248.61L188.49,252.41L186.30,248.61L181.92,248.61L184.11,244.81L181.92,241.02L186.30,241.02L188.49,237.22L186.30,233.43L181.92,233.43L184.11,229.63L181.92,225.83L177.53,225.83L175.34,229.63L173.15,225.83L168.77,225.83L166.57,229.63L168.77,233.43L164.38,233.43L162.19,237.22L160.00,233.43L155.62,233.43L157.81,229.63L155.62,225.83L151.23,225.83L149.04,229.63L146.85,225.83L142.46,225.83L144.66,222.04L142.46,218.24L146.85,218.24L149.04,214.44L146.85,210.65L142.46,210.65L144.66,206.85L142.46,203.06L146.85,203.06L149.04,199.26L151.23,203.06L155.62,203.06L157.81,199.26L155.62,195.46L160.00,195.46L162.19,191.67L160.00,187.87L155.62,187.87L157.81,184.07L155.62,180.28L151.23,180.28L149.04,184.07L146.85,180.28L142.46,180.28L144.66,176.48L142.46,172.69L146.85,172.69L149.04,168.89L146.85,165.09L142.46,165.09L144.66,161.30L142.46,157.50L146.85,157.50L149.04,153.70L151.23,157.50L155.62,157.50L157.81,153.70L155.62,149.91L160.00,149.91L162.19,146.11L164.38,149.91L168.77,149.91L166.57,153.70L168.77,157.50L173.15,157.50L175.34,153.70L177.53,157.50L181.92,157.50L184.11,153.70L181.92,149.91L186.30,149.91L188.49,146.11L186.30,142.31L181.92,142.31L184.11,138.52L181.92,134.72L186.30,134.72L188.49,130.93L190.68,134.72L195.07,134.72L197.26,130.93L195.07,127.13L199.45,127.13L201.64,123.33L203.83,127.13L208.22,127.13L206.03,130.93L208.22,134.72L212.60,134.72L214.79,130.93L216.99,134.72L221.37,134.72L219.18,138.52L221.37,142.31L216.99,142.31L214.79,146.11L216.99,149.91L221.37,149.91L219.18,153.70L221.37,157.50L225.75,157.50L227.94,153.70L230.14,157.50L234.52,157.50L236.71,153.70L234.52,149.91L238.90,149.91L241.10,146.11L243.29,149.91L247.67,149.91L245.48,153.70L247.67,157.50L252.05,157.50L254.25,153.70L256.44,157.50L260.82,157.50L263.01,153.70L260.82,149.91L265.21,149.91L267.40,146.11L265.21,142.31L260.82,142.31L263.01,138.52L260.82,134.72L265.21,134.72L267.40,130.93L269.59,134.72L273.97,134.72L276.16,130.93L273.97,127.13L278.36,127.13L280.55,123.33L278.36,119.54L273.97,119.54L276.16,115.74L273.97,111.94L269.59,111.94L267.40,115.74L265.21,111.94L260.82,111.94L263.01,108.15L260.82,104.35L265.21,104.35L267.40,100.56L265.21,96.76L260.82,96.76L263.01,92.96L260.82,89.17L265.21,89.17L267.40,85.37L269.59,89.17L273.97,89.17L276.16,85.37L273.97,81.57L278.36,81.57L280.55,77.78L282.74,81.57L287.12,81.57L284.93,85.37L287.12,89.17L291.51,89.17L293.70,85.37L295.89,89.17L300.27,89.17L302.47,85.37L300.27,81.57L304.66,81.57L306.85,77.78L304.66,73.98L300.27,73.98L302.47,70.19L300.27,66.39L304.66,66.39L306.85,62.59L309.04,66.39L313.42,66.39L315.62,62.59L313.42,58.80L317.81,58.80L320.00,55.00\" style=\"--len:3366.6\"/></svg>",
            code: "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>, <m>math</b>\n\n<em># 科赫雪花：把每条边三等分，中间那段换成凸起的等边三角形，然后递归</b>\n<em># 三条边的凸起必须都【朝外】才是雪花，所以顶点要按逆时针取；</b>\n<em># 顺时针取的话凸起会朝内，画出来是三朵花。</b>\n<m>t</b>.<s>setup</b>(<u>600</b>, <u>520</b>); <m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>0</b>)\n<m>t</b>.<s>color</b>(<i>\"#00e5ff\"</b>); <m>t</b>.<s>pensize</b>(<u>2</b>)\n\n<b>def</b> <s>koch</b>(p, q, depth):\n    <i>\"\"\"把线段 pq 递归细分成科赫曲线，边算边画\"\"\"</b>\n    <b>if</b> depth == <u>0</b>:\n        <m>t</b>.<s>goto</b>(q)\n        <b>return</b>\n    dx, dy = (q[<u>0</b>]-p[<u>0</b>])/<u>3</b>, (q[<u>1</b>]-p[<u>1</b>])/<u>3</b>      <em># 每段长度的向量</b>\n    a = (p[<u>0</b>]+dx, p[<u>1</b>]+dy)                    <em># 第一个三等分点</b>\n    c = (p[<u>0</b>]+<u>2</b>*dx, p[<u>1</b>]+<u>2</b>*dy)              <em># 第二个三等分点</b>\n    ang = <m>math</b>.<s>radians</b>(<u>60</b>)\n    b = (a[<u>0</b>] + dx*<m>math</b>.<s>cos</b>(ang) - dy*<m>math</b>.<s>sin</b>(ang),\n         a[<u>1</b>] + dx*<m>math</b>.<s>sin</b>(ang) + dy*<m>math</b>.<s>cos</b>(ang))  <em># 凸起顶点</b>\n    <s>koch</b>(p, a, depth-<u>1</b>); <s>koch</b>(a, b, depth-<u>1</b>)\n    <s>koch</b>(b, c, depth-<u>1</b>); <s>koch</b>(c, q, depth-<u>1</b>)\n\nR = <u>205</b>\n<em># 逆时针取三个顶点（90° → 210° → 330° 反过来）</b>\nP = [(R*<m>math</b>.<s>cos</b>(<m>math</b>.<s>radians</b>(<u>90</b> - i*<u>120</b>)),\n      R*<m>math</b>.<s>sin</b>(<m>math</b>.<s>radians</b>(<u>90</b> - i*<u>120</b>))) <b>for</b> i <b>in</b> <s>range</b>(<u>3</b>)]\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(P[<u>0</b>]); <m>t</b>.<s>pendown</b>()\n<b>for</b> i <b>in</b> <s>range</b>(<u>3</b>):\n    <s>koch</b>(P[i], P[(i+<u>1</b>)%<u>3</b>], <u>4</b>)\n<m>t</b>.<s>done</b>()",
            plain: "import turtle as t, math\n\n# 科赫雪花：把每条边三等分，中间那段换成凸起的等边三角形，然后递归\n# 三条边的凸起必须都【朝外】才是雪花，所以顶点要按逆时针取；\n# 顺时针取的话凸起会朝内，画出来是三朵花。\nt.setup(600, 520); t.hideturtle(); t.speed(0)\nt.color(\"#00e5ff\"); t.pensize(2)\n\ndef koch(p, q, depth):\n    \"\"\"把线段 pq 递归细分成科赫曲线，边算边画\"\"\"\n    if depth == 0:\n        t.goto(q)\n        return\n    dx, dy = (q[0]-p[0])/3, (q[1]-p[1])/3      # 每段长度的向量\n    a = (p[0]+dx, p[1]+dy)                    # 第一个三等分点\n    c = (p[0]+2*dx, p[1]+2*dy)              # 第二个三等分点\n    ang = math.radians(60)\n    b = (a[0] + dx*math.cos(ang) - dy*math.sin(ang),\n         a[1] + dx*math.sin(ang) + dy*math.cos(ang))  # 凸起顶点\n    koch(p, a, depth-1); koch(a, b, depth-1)\n    koch(b, c, depth-1); koch(c, q, depth-1)\n\nR = 205\n# 逆时针取三个顶点（90° → 210° → 330° 反过来）\nP = [(R*math.cos(math.radians(90 - i*120)),\n      R*math.sin(math.radians(90 - i*120))) for i in range(3)]\nt.penup(); t.goto(P[0]); t.pendown()\nfor i in range(3):\n    koch(P[i], P[(i+1)%3], 4)\nt.done()",
            langs: [{"id": "py", "name": "Python", "file": "koch.py", "code": "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>, <m>math</b>\n\n<em># 科赫雪花：把每条边三等分，中间那段换成凸起的等边三角形，然后递归</b>\n<em># 三条边的凸起必须都【朝外】才是雪花，所以顶点要按逆时针取；</b>\n<em># 顺时针取的话凸起会朝内，画出来是三朵花。</b>\n<m>t</b>.<s>setup</b>(<u>600</b>, <u>520</b>); <m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>0</b>)\n<m>t</b>.<s>color</b>(<i>\"#00e5ff\"</b>); <m>t</b>.<s>pensize</b>(<u>2</b>)\n\n<b>def</b> <s>koch</b>(p, q, depth):\n    <i>\"\"\"把线段 pq 递归细分成科赫曲线，边算边画\"\"\"</b>\n    <b>if</b> depth == <u>0</b>:\n        <m>t</b>.<s>goto</b>(q)\n        <b>return</b>\n    dx, dy = (q[<u>0</b>]-p[<u>0</b>])/<u>3</b>, (q[<u>1</b>]-p[<u>1</b>])/<u>3</b>      <em># 每段长度的向量</b>\n    a = (p[<u>0</b>]+dx, p[<u>1</b>]+dy)                    <em># 第一个三等分点</b>\n    c = (p[<u>0</b>]+<u>2</b>*dx, p[<u>1</b>]+<u>2</b>*dy)              <em># 第二个三等分点</b>\n    ang = <m>math</b>.<s>radians</b>(<u>60</b>)\n    b = (a[<u>0</b>] + dx*<m>math</b>.<s>cos</b>(ang) - dy*<m>math</b>.<s>sin</b>(ang),\n         a[<u>1</b>] + dx*<m>math</b>.<s>sin</b>(ang) + dy*<m>math</b>.<s>cos</b>(ang))  <em># 凸起顶点</b>\n    <s>koch</b>(p, a, depth-<u>1</b>); <s>koch</b>(a, b, depth-<u>1</b>)\n    <s>koch</b>(b, c, depth-<u>1</b>); <s>koch</b>(c, q, depth-<u>1</b>)\n\nR = <u>205</b>\n<em># 逆时针取三个顶点（90° → 210° → 330° 反过来）</b>\nP = [(R*<m>math</b>.<s>cos</b>(<m>math</b>.<s>radians</b>(<u>90</b> - i*<u>120</b>)),\n      R*<m>math</b>.<s>sin</b>(<m>math</b>.<s>radians</b>(<u>90</b> - i*<u>120</b>))) <b>for</b> i <b>in</b> <s>range</b>(<u>3</b>)]\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(P[<u>0</b>]); <m>t</b>.<s>pendown</b>()\n<b>for</b> i <b>in</b> <s>range</b>(<u>3</b>):\n    <s>koch</b>(P[i], P[(i+<u>1</b>)%<u>3</b>], <u>4</b>)\n<m>t</b>.<s>done</b>()", "plain": "import turtle as t, math\n\n# 科赫雪花：把每条边三等分，中间那段换成凸起的等边三角形，然后递归\n# 三条边的凸起必须都【朝外】才是雪花，所以顶点要按逆时针取；\n# 顺时针取的话凸起会朝内，画出来是三朵花。\nt.setup(600, 520); t.hideturtle(); t.speed(0)\nt.color(\"#00e5ff\"); t.pensize(2)\n\ndef koch(p, q, depth):\n    \"\"\"把线段 pq 递归细分成科赫曲线，边算边画\"\"\"\n    if depth == 0:\n        t.goto(q)\n        return\n    dx, dy = (q[0]-p[0])/3, (q[1]-p[1])/3      # 每段长度的向量\n    a = (p[0]+dx, p[1]+dy)                    # 第一个三等分点\n    c = (p[0]+2*dx, p[1]+2*dy)              # 第二个三等分点\n    ang = math.radians(60)\n    b = (a[0] + dx*math.cos(ang) - dy*math.sin(ang),\n         a[1] + dx*math.sin(ang) + dy*math.cos(ang))  # 凸起顶点\n    koch(p, a, depth-1); koch(a, b, depth-1)\n    koch(b, c, depth-1); koch(c, q, depth-1)\n\nR = 205\n# 逆时针取三个顶点（90° → 210° → 330° 反过来）\nP = [(R*math.cos(math.radians(90 - i*120)),\n      R*math.sin(math.radians(90 - i*120))) for i in range(3)]\nt.penup(); t.goto(P[0]); t.pendown()\nfor i in range(3):\n    koch(P[i], P[(i+1)%3], 4)\nt.done()"}, {"id": "js", "name": "JavaScript", "file": "koch.js", "code": "<em>// 科赫雪花 · JavaScript + Canvas 2D</em>\n<em>// 顶点按【逆时针】取，凸起才朝外；顺时针取会画成三朵花。</em>\n<b>const</b> <b>canvas</b> = document.createElement(<i>'<b>canvas</b>'</i>);\n<b>canvas</b>.width = 660; <b>canvas</b>.height = 560;\ndocument.body.appendChild(<b>canvas</b>);\n<b>const</b> <b>ctx</b> = <b>canvas</b>.getContext(<i>'2d'</i>);\n<b>ctx</b>.fillStyle = <i>'#060a14'</i>;\n<b>ctx</b>.fillRect(0, 0, <b>canvas</b>.width, <b>canvas</b>.height);\n\n<b>const</b> R = 205;\n<b>const</b> P = [0, 1, 2].map(i =&gt; {\n  <b>const</b> a = (90 - i * 120) * <b>Math</b>.PI / 180;      <em>// 逆时针</em>\n  <b>return</b> [R * <b>Math</b>.cos(a), R * <b>Math</b>.sin(a)];\n});\n\n<b>function</b> koch(p, q, depth) {\n  <b>if</b> (depth === 0) { <b>ctx</b>.lineTo(q[0], q[1]); <b>return</b>; }\n  <b>const</b> dx = (q[0] - p[0]) / 3, dy = (q[1] - p[1]) / 3;\n  <b>const</b> a = [p[0] + dx, p[1] + dy];\n  <b>const</b> c = [p[0] + 2 * dx, p[1] + 2 * dy];\n  <b>const</b> ang = <b>Math</b>.PI / 3;                        <em>// 60°</em>\n  <b>const</b> b = [a[0] + dx * <b>Math</b>.cos(ang) - dy * <b>Math</b>.sin(ang),\n             a[1] + dx * <b>Math</b>.sin(ang) + dy * <b>Math</b>.cos(ang)];\n  koch(p, a, depth - 1);\n  koch(a, b, depth - 1);\n  koch(b, c, depth - 1);\n  koch(c, q, depth - 1);\n}\n\n<b>ctx</b>.translate(<b>canvas</b>.width / 2, <b>canvas</b>.height / 2 + 40);\n<b>ctx</b>.beginPath();\n<b>const</b> s = P[0];\n<b>ctx</b>.moveTo(s[0], -s[1]);\n<b>for</b> (<b>let</b> i = 0; i &lt; 3; i++) {\n  <b>const</b> a = P[i], b = P[(i + 1) % 3];\n  koch([a[0], -a[1]], [b[0], -b[1]], 4);\n}\n<b>ctx</b>.strokeStyle = <i>'#00e5ff'</i>;\n<b>ctx</b>.lineWidth = 1.6;\n<b>ctx</b>.lineJoin = <i>'round'</i>;\n<b>ctx</b>.stroke();\n", "plain": "// 科赫雪花 · JavaScript + Canvas 2D\n// 顶点按【逆时针】取，凸起才朝外；顺时针取会画成三朵花。\nconst canvas = document.createElement('canvas');\ncanvas.width = 660; canvas.height = 560;\ndocument.body.appendChild(canvas);\nconst ctx = canvas.getContext('2d');\nctx.fillStyle = '#060a14';\nctx.fillRect(0, 0, canvas.width, canvas.height);\n\nconst R = 205;\nconst P = [0, 1, 2].map(i => {\n  const a = (90 - i * 120) * Math.PI / 180;      // 逆时针\n  return [R * Math.cos(a), R * Math.sin(a)];\n});\n\nfunction koch(p, q, depth) {\n  if (depth === 0) { ctx.lineTo(q[0], q[1]); return; }\n  const dx = (q[0] - p[0]) / 3, dy = (q[1] - p[1]) / 3;\n  const a = [p[0] + dx, p[1] + dy];\n  const c = [p[0] + 2 * dx, p[1] + 2 * dy];\n  const ang = Math.PI / 3;                        // 60°\n  const b = [a[0] + dx * Math.cos(ang) - dy * Math.sin(ang),\n             a[1] + dx * Math.sin(ang) + dy * Math.cos(ang)];\n  koch(p, a, depth - 1);\n  koch(a, b, depth - 1);\n  koch(b, c, depth - 1);\n  koch(c, q, depth - 1);\n}\n\nctx.translate(canvas.width / 2, canvas.height / 2 + 40);\nctx.beginPath();\nconst s = P[0];\nctx.moveTo(s[0], -s[1]);\nfor (let i = 0; i < 3; i++) {\n  const a = P[i], b = P[(i + 1) % 3];\n  koch([a[0], -a[1]], [b[0], -b[1]], 4);\n}\nctx.strokeStyle = '#00e5ff';\nctx.lineWidth = 1.6;\nctx.lineJoin = 'round';\nctx.stroke();\n"}, {"id": "c", "name": "C", "file": "koch.c", "code": "<em>/* 科赫雪花 · C 语言，控制台 ASCII\n   编译： gcc koch.c -o koch -lm\n   思路：递归把线段三等分，中间那段换成凸起的等边三角形，\n         最后把折线点按行采样成字符。 */</em>\n#<b>include</b> &lt;stdio.h&gt;\n#<b>include</b> &lt;math.h&gt;\n\n#<b>define</b> WIDTH   79\n#<b>define</b> HEIGHT  40\n#<b>define</b> DEPTH   4\n#<b>define</b> MAXPTS  4096\n\n<b>static</b> <b>double</b> px[MAXPTS], py[MAXPTS];\n<b>static</b> <b>int</b> n = 0;\n\n<em>/* 把线段 pq 递归细分，细分结果追加到 px/py */</em>\n<b>static</b> <b>void</b> koch(<b>double</b> x1, <b>double</b> y1, <b>double</b> x2, <b>double</b> y2, <b>int</b> d)\n{\n    <b>if</b> (d == 0) {\n        <b>if</b> (n &lt; MAXPTS) { px[n] = x2; py[n] = y2; n++; }\n        <b>return</b>;\n    }\n    <b>double</b> dx = (x2 - x1) / 3.0, dy = (y2 - y1) / 3.0;\n    <b>double</b> ax = x1 + dx,        ay = y1 + dy;\n    <b>double</b> cx = x1 + 2 * dx,    cy = y1 + 2 * dy;\n    <b>double</b> ang = <b>M_PI</b> / 3.0;\n    <b>double</b> bx = ax + dx * <b>cos</b>(ang) - dy * <b>sin</b>(ang);\n    <b>double</b> by = ay + dx * <b>sin</b>(ang) + dy * <b>cos</b>(ang);\n    koch(x1, y1, ax, ay, d - 1);\n    koch(ax, ay, bx, by, d - 1);\n    koch(bx, by, cx, cy, d - 1);\n    koch(cx, cy, x2, y2, d - 1);\n}\n\n<b>int</b> <b>main</b>(<b>void</b>)\n{\n    <b>char</b> grid[HEIGHT][WIDTH + 1];\n    <b>int</b> i, j, k;\n    <b>double</b> R = 1.0;\n\n    <em>/* 逆时针取三个顶点 */</em>\n    <b>double</b> vx[3], vy[3];\n    <b>for</b> (i = 0; i &lt; 3; i++) {\n        <b>double</b> a = (90.0 - i * 120.0) * <b>M_PI</b> / 180.0;\n        vx[i] = R * <b>cos</b>(a);\n        vy[i] = R * <b>sin</b>(a);\n    }\n\n    <b>for</b> (i = 0; i &lt; 3; i++) {\n        koch(vx[i], vy[i], vx[(i + 1) % 3], vy[(i + 1) % 3], DEPTH);\n    }\n\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++)\n        <b>for</b> (k = 0; k &lt; WIDTH; k++)\n            grid[j][k] = ' ';\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++) grid[j][WIDTH] = '\\0';\n\n    <em>/* 把点打到字符网格上（y 轴翻转） */</em>\n    <b>for</b> (i = 0; i &lt; n; i++) {\n        <b>int</b> gx = (<b>int</b>)((px[i] + 1.15) / 2.30 * (WIDTH - 1));\n        <b>int</b> gy = (<b>int</b>)((1.15 - py[i]) / 2.30 * (HEIGHT - 1));\n        <b>if</b> (gx &gt;= 0 &amp;&amp; gx &lt; WIDTH &amp;&amp; gy &gt;= 0 &amp;&amp; gy &lt; HEIGHT)\n            grid[gy][gx] = '*';\n    }\n\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++) <b>puts</b>(grid[j]);\n    <b>return</b> 0;\n}\n", "plain": "/* 科赫雪花 · C 语言，控制台 ASCII\n   编译： gcc koch.c -o koch -lm\n   思路：递归把线段三等分，中间那段换成凸起的等边三角形，\n         最后把折线点按行采样成字符。 */\n#include <stdio.h>\n#include <math.h>\n\n#define WIDTH   79\n#define HEIGHT  40\n#define DEPTH   4\n#define MAXPTS  4096\n\nstatic double px[MAXPTS], py[MAXPTS];\nstatic int n = 0;\n\n/* 把线段 pq 递归细分，细分结果追加到 px/py */\nstatic void koch(double x1, double y1, double x2, double y2, int d)\n{\n    if (d == 0) {\n        if (n < MAXPTS) { px[n] = x2; py[n] = y2; n++; }\n        return;\n    }\n    double dx = (x2 - x1) / 3.0, dy = (y2 - y1) / 3.0;\n    double ax = x1 + dx,        ay = y1 + dy;\n    double cx = x1 + 2 * dx,    cy = y1 + 2 * dy;\n    double ang = M_PI / 3.0;\n    double bx = ax + dx * cos(ang) - dy * sin(ang);\n    double by = ay + dx * sin(ang) + dy * cos(ang);\n    koch(x1, y1, ax, ay, d - 1);\n    koch(ax, ay, bx, by, d - 1);\n    koch(bx, by, cx, cy, d - 1);\n    koch(cx, cy, x2, y2, d - 1);\n}\n\nint main(void)\n{\n    char grid[HEIGHT][WIDTH + 1];\n    int i, j, k;\n    double R = 1.0;\n\n    /* 逆时针取三个顶点 */\n    double vx[3], vy[3];\n    for (i = 0; i < 3; i++) {\n        double a = (90.0 - i * 120.0) * M_PI / 180.0;\n        vx[i] = R * cos(a);\n        vy[i] = R * sin(a);\n    }\n\n    for (i = 0; i < 3; i++) {\n        koch(vx[i], vy[i], vx[(i + 1) % 3], vy[(i + 1) % 3], DEPTH);\n    }\n\n    for (j = 0; j < HEIGHT; j++)\n        for (k = 0; k < WIDTH; k++)\n            grid[j][k] = ' ';\n    for (j = 0; j < HEIGHT; j++) grid[j][WIDTH] = '\\0';\n\n    /* 把点打到字符网格上（y 轴翻转） */\n    for (i = 0; i < n; i++) {\n        int gx = (int)((px[i] + 1.15) / 2.30 * (WIDTH - 1));\n        int gy = (int)((1.15 - py[i]) / 2.30 * (HEIGHT - 1));\n        if (gx >= 0 && gx < WIDTH && gy >= 0 && gy < HEIGHT)\n            grid[gy][gx] = '*';\n    }\n\n    for (j = 0; j < HEIGHT; j++) puts(grid[j]);\n    return 0;\n}\n"}]
        }
        ,{
            file: 'spiral.py',
            id: "spiral",
            tab: "\uD83C\uDF00 \u9EC4\u91D1\u87BA\u65CB",
            name: "\u9EC4\u91D1\u87BA\u65CB <i>\u00B7 \u542B\u6590\u6CE2\u90A3\u5951\u6B63\u65B9\u5F62\u8F85\u52A9\u7EBF</i>",
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"Python 海龟绘图画出黄金螺旋，附斐波那契正方形辅助线\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><g class=\"nb-ts-sq\"><path d=\"M201.82,193.82L211.27,193.82L211.27,184.36L201.82,184.36Z\" style=\"animation-delay:0.00s\"/><path d=\"M211.27,184.36L211.27,174.91L201.82,174.91L201.82,184.36Z\" style=\"animation-delay:0.13s\"/><path d=\"M201.82,174.91L182.91,174.91L182.91,193.82L201.82,193.82Z\" style=\"animation-delay:0.26s\"/><path d=\"M182.91,193.82L182.91,222.18L211.27,222.18L211.27,193.82Z\" style=\"animation-delay:0.39s\"/><path d=\"M211.27,222.18L258.55,222.18L258.55,174.91L211.27,174.91Z\" style=\"animation-delay:0.52s\"/><path d=\"M258.55,174.91L258.55,99.27L182.91,99.27L182.91,174.91Z\" style=\"animation-delay:0.65s\"/><path d=\"M182.91,99.27L60.00,99.27L60.00,222.18L182.91,222.18Z\" style=\"animation-delay:0.78s\"/><path d=\"M60.00,222.18L60.00,420.73L258.55,420.73L258.55,222.18Z\" style=\"animation-delay:0.91s\"/><path d=\"M258.55,420.73L580.00,420.73L580.00,99.27L258.55,99.27Z\" style=\"animation-delay:1.04s\"/></g><g class=\"nb-ts-spiral\"><path d=\"M201.82,193.82L202.81,193.77L203.78,193.61L204.74,193.36L205.66,193.00L206.55,192.55L207.38,192.01L208.14,191.39L208.84,190.69L209.47,189.92L210.01,189.09L210.46,188.21L210.81,187.29L211.07,186.33L211.22,185.35L211.27,184.36\" style=\"--len:14.8;animation-delay:0.00s\"/><path d=\"M211.27,184.36L211.22,183.38L211.07,182.40L210.81,181.44L210.46,180.52L210.01,179.64L209.47,178.81L208.84,178.04L208.14,177.34L207.38,176.71L206.55,176.18L205.66,175.73L204.74,175.37L203.78,175.12L202.81,174.96L201.82,174.91\" style=\"--len:14.8;animation-delay:0.16s\"/><path d=\"M201.82,174.91L200.07,174.99L198.34,175.23L196.64,175.63L194.99,176.19L193.39,176.89L191.86,177.74L190.42,178.73L189.08,179.84L187.84,181.08L186.73,182.42L185.74,183.86L184.89,185.39L184.19,186.99L183.63,188.64L183.23,190.34L182.99,192.07L182.91,193.82\" style=\"--len:29.7;animation-delay:0.32s\"/><path d=\"M182.91,193.82L183.02,196.29L183.34,198.74L183.88,201.16L184.62,203.52L185.57,205.81L186.71,208.00L188.04,210.09L189.54,212.05L191.22,213.87L193.04,215.55L195.00,217.05L197.09,218.38L199.29,219.52L201.57,220.47L203.93,221.22L206.35,221.75L208.80,222.07L211.27,222.18\" style=\"--len:44.5;animation-delay:0.48s\"/><path d=\"M211.27,222.18L214.65,222.06L218.00,221.70L221.32,221.10L224.59,220.27L227.79,219.20L230.91,217.91L233.93,216.40L236.83,214.68L239.60,212.75L242.23,210.64L244.70,208.34L247.00,205.87L249.12,203.24L251.04,200.47L252.76,197.56L254.27,194.55L255.56,191.43L256.63,188.23L257.47,184.96L258.06,181.64L258.43,178.28L258.55,174.91\" style=\"--len:74.2;animation-delay:0.64s\"/><path d=\"M258.55,174.91L258.41,170.34L257.99,165.79L257.31,161.28L256.35,156.81L255.12,152.41L253.63,148.09L251.88,143.87L249.88,139.76L247.64,135.78L245.16,131.94L242.45,128.26L239.52,124.75L236.39,121.43L233.07,118.29L229.56,115.37L225.88,112.66L222.04,110.18L218.06,107.94L213.95,105.94L209.73,104.19L205.41,102.70L201.01,101.47L196.54,100.51L192.03,99.82L187.48,99.41L182.91,99.27\" style=\"--len:118.8;animation-delay:0.80s\"/><path d=\"M182.91,99.27L177.23,99.40L171.57,99.80L165.93,100.45L160.32,101.37L154.77,102.54L149.27,103.96L143.85,105.64L138.51,107.57L133.26,109.75L128.12,112.16L123.10,114.81L118.21,117.68L113.45,120.78L108.84,124.10L104.39,127.62L100.11,131.35L96.00,135.27L92.08,139.38L88.35,143.66L84.83,148.11L81.51,152.72L78.41,157.48L75.53,162.37L72.89,167.40L70.47,172.54L68.30,177.78L66.37,183.12L64.69,188.55L63.26,194.04L62.09,199.60L61.18,205.20L60.52,210.84L60.13,216.51L60.00,222.18\" style=\"--len:193.0;animation-delay:0.96s\"/><path d=\"M60.00,222.18L60.11,228.82L60.44,235.44L61.00,242.06L61.77,248.65L62.77,255.21L63.98,261.73L65.41,268.21L67.05,274.64L68.91,281.01L70.99,287.31L73.27,293.54L75.75,299.69L78.45,305.76L81.34,311.73L84.43,317.60L87.72,323.36L91.19,329.02L94.86,334.55L98.70,339.95L102.73,345.23L106.93,350.37L111.29,355.36L115.83,360.21L120.52,364.90L125.36,369.43L130.36,373.80L135.50,378.00L140.77,382.02L146.18,385.87L151.71,389.53L157.36,393.01L163.13,396.30L169.00,399.39L174.97,402.28L181.04,404.97L187.19,407.46L193.42,409.74L199.72,411.81L206.09,413.67L212.52,415.32L219.00,416.75L225.52,417.96L232.08,418.96L238.67,419.73L245.28,420.28L251.91,420.62L258.55,420.73\" style=\"--len:311.9;animation-delay:1.12s\"/><path d=\"M258.55,420.73L265.97,420.64L273.39,420.38L280.80,419.96L288.21,419.36L295.59,418.59L302.96,417.64L310.30,416.53L317.61,415.25L324.90,413.81L332.14,412.19L339.35,410.41L346.52,408.46L353.63,406.34L360.70,404.06L367.71,401.62L374.67,399.02L381.56,396.26L388.39,393.34L395.15,390.26L401.83,387.03L408.44,383.64L414.97,380.10L421.41,376.41L427.77,372.58L434.04,368.60L440.21,364.47L446.29,360.21L452.27,355.80L458.14,351.26L463.91,346.58L469.56,341.77L475.11,336.83L480.54,331.76L485.85,326.58L491.04,321.26L496.10,315.84L501.04,310.29L505.85,304.63L510.53,298.87L515.07,292.99L519.48,287.02L523.74,280.94L527.87,274.76L531.85,268.50L535.69,262.14L539.38,255.69L542.91,249.17L546.30,242.56L549.53,235.87L552.61,229.11L555.53,222.29L558.29,215.40L560.90,208.44L563.34,201.43L565.61,194.36L567.73,187.24L569.68,180.08L571.46,172.87L573.08,165.62L574.53,158.34L575.81,151.03L576.92,143.68L577.86,136.32L578.63,128.93L579.23,121.53L579.66,114.12L579.91,106.70L580.00,99.27\" style=\"--len:504.9;animation-delay:1.28s\"/></g><g class=\"nb-ts-num\"><text x=\"197.1\" y=\"212.0\" style=\"animation-delay:0.39s\">3</text><text x=\"234.9\" y=\"202.5\" style=\"animation-delay:0.52s\">5</text><text x=\"220.7\" y=\"141.1\" style=\"animation-delay:0.65s\">8</text><text x=\"121.5\" y=\"164.7\" style=\"animation-delay:0.78s\">13</text><text x=\"159.3\" y=\"325.5\" style=\"animation-delay:0.91s\">21</text><text x=\"419.3\" y=\"264.0\" style=\"animation-delay:1.04s\">34</text></g></svg>",
            code: "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>\n\n<em># 黄金螺旋 = 斐波那契正方形 + 每格里的 1/4 圆弧</b>\n<em># 关键：正方形和圆弧都【左转】（逆时针）。</b>\n<em>#       圆弧的圆心落在正方形的角上，所以正方形要画在圆心那一侧；</b>\n<em>#       右转画出来的正方形会跑到反面，和弧错开一格。</b>\n<m>t</b>.<s>setup</b>(<u>640</b>, <u>520</b>); <m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>0</b>)\n\n<em># 斐波那契：1 1 2 3 5 8 13 21 34</b>\nfib = [<u>1</b>, <u>1</b>]\n<b>for</b> _ <b>in</b> <s>range</b>(<u>7</b>):\n    fib.<s>append</b>(fib[-<u>1</b>] + fib[-<u>2</b>])\n\nSCALE = <u>14</b>\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(<u>0</b>, <u>0</b>); <m>t</b>.<s>pendown</b>()\n\n<b>for</b> s <b>in</b> fib:\n    L = s * SCALE\n    <em># ① 辅助线：正方形，左转绕一圈（画完海龟回到原点、朝向不变）</b>\n    <m>t</b>.<s>pensize</b>(<u>1</b>); <m>t</b>.<s>color</b>(<i>\"#1b4a5a\"</b>)\n    <b>for</b> _ <b>in</b> <s>range</b>(<u>4</b>):\n        <m>t</b>.<s>forward</b>(L); <m>t</b>.<s>left</b>(<u>90</b>)\n    <em># ② 螺旋：从同一点出发，逆时针扫 1/4 圈</b>\n    <m>t</b>.<s>pensize</b>(<u>2</b>); <m>t</b>.<s>color</b>(<i>\"#00e5ff\"</b>)\n    <m>t</b>.<s>circle</b>(L, <u>90</b>)\n<m>t</b>.<s>done</b>()",
            plain: "import turtle as t\n\n# 黄金螺旋 = 斐波那契正方形 + 每格里的 1/4 圆弧\n# 关键：正方形和圆弧都【左转】（逆时针）。\n#       圆弧的圆心落在正方形的角上，所以正方形要画在圆心那一侧；\n#       右转画出来的正方形会跑到反面，和弧错开一格。\nt.setup(640, 520); t.hideturtle(); t.speed(0)\n\n# 斐波那契：1 1 2 3 5 8 13 21 34\nfib = [1, 1]\nfor _ in range(7):\n    fib.append(fib[-1] + fib[-2])\n\nSCALE = 14\nt.penup(); t.goto(0, 0); t.pendown()\n\nfor s in fib:\n    L = s * SCALE\n    # ① 辅助线：正方形，左转绕一圈（画完海龟回到原点、朝向不变）\n    t.pensize(1); t.color(\"#1b4a5a\")\n    for _ in range(4):\n        t.forward(L); t.left(90)\n    # ② 螺旋：从同一点出发，逆时针扫 1/4 圈\n    t.pensize(2); t.color(\"#00e5ff\")\n    t.circle(L, 90)\nt.done()",
            langs: [{"id": "py", "name": "Python", "file": "spiral.py", "code": "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>\n\n<em># 黄金螺旋 = 斐波那契正方形 + 每格里的 1/4 圆弧</b>\n<em># 关键：正方形和圆弧都【左转】（逆时针）。</b>\n<em>#       圆弧的圆心落在正方形的角上，所以正方形要画在圆心那一侧；</b>\n<em>#       右转画出来的正方形会跑到反面，和弧错开一格。</b>\n<m>t</b>.<s>setup</b>(<u>640</b>, <u>520</b>); <m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>0</b>)\n\n<em># 斐波那契：1 1 2 3 5 8 13 21 34</b>\nfib = [<u>1</b>, <u>1</b>]\n<b>for</b> _ <b>in</b> <s>range</b>(<u>7</b>):\n    fib.<s>append</b>(fib[-<u>1</b>] + fib[-<u>2</b>])\n\nSCALE = <u>14</b>\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(<u>0</b>, <u>0</b>); <m>t</b>.<s>pendown</b>()\n\n<b>for</b> s <b>in</b> fib:\n    L = s * SCALE\n    <em># ① 辅助线：正方形，左转绕一圈（画完海龟回到原点、朝向不变）</b>\n    <m>t</b>.<s>pensize</b>(<u>1</b>); <m>t</b>.<s>color</b>(<i>\"#1b4a5a\"</b>)\n    <b>for</b> _ <b>in</b> <s>range</b>(<u>4</b>):\n        <m>t</b>.<s>forward</b>(L); <m>t</b>.<s>left</b>(<u>90</b>)\n    <em># ② 螺旋：从同一点出发，逆时针扫 1/4 圈</b>\n    <m>t</b>.<s>pensize</b>(<u>2</b>); <m>t</b>.<s>color</b>(<i>\"#00e5ff\"</b>)\n    <m>t</b>.<s>circle</b>(L, <u>90</b>)\n<m>t</b>.<s>done</b>()", "plain": "import turtle as t\n\n# 黄金螺旋 = 斐波那契正方形 + 每格里的 1/4 圆弧\n# 关键：正方形和圆弧都【左转】（逆时针）。\n#       圆弧的圆心落在正方形的角上，所以正方形要画在圆心那一侧；\n#       右转画出来的正方形会跑到反面，和弧错开一格。\nt.setup(640, 520); t.hideturtle(); t.speed(0)\n\n# 斐波那契：1 1 2 3 5 8 13 21 34\nfib = [1, 1]\nfor _ in range(7):\n    fib.append(fib[-1] + fib[-2])\n\nSCALE = 14\nt.penup(); t.goto(0, 0); t.pendown()\n\nfor s in fib:\n    L = s * SCALE\n    # ① 辅助线：正方形，左转绕一圈（画完海龟回到原点、朝向不变）\n    t.pensize(1); t.color(\"#1b4a5a\")\n    for _ in range(4):\n        t.forward(L); t.left(90)\n    # ② 螺旋：从同一点出发，逆时针扫 1/4 圈\n    t.pensize(2); t.color(\"#00e5ff\")\n    t.circle(L, 90)\nt.done()"}, {"id": "js", "name": "JavaScript", "file": "spiral.js", "code": "<em>// 黄金螺旋 · JavaScript + Canvas 2D</em>\n<em>// 斐波那契正方形 + 每个正方形里的 1/4 圆弧。</em>\n<b>const</b> <b>canvas</b> = document.createElement(<i>'<b>canvas</b>'</i>);\n<b>canvas</b>.width = 660; <b>canvas</b>.height = 560;\ndocument.body.appendChild(<b>canvas</b>);\n<b>const</b> <b>ctx</b> = <b>canvas</b>.getContext(<i>'2d'</i>);\n<b>ctx</b>.fillStyle = <i>'#060a14'</i>;\n<b>ctx</b>.fillRect(0, 0, <b>canvas</b>.width, <b>canvas</b>.height);\n\n<b>const</b> fib = [1, 1];\n<b>for</b> (<b>let</b> i = 0; i &lt; 7; i++) fib.push(fib[fib.length - 1] + fib[fib.length - 2]);\n<b>const</b> SCALE = 14;\n\n<em>// 先用纸笔推一遍，拿到所有正方形和弧，再统一缩放居中</em>\n<b>let</b> x = 0, y = 0, hx = 1, hy = 0;\n<b>const</b> squares = [], arcs = [];\n<b>for</b> (<b>const</b> s <b>of</b> fib) {\n  <b>const</b> L = s * SCALE;\n  <b>const</b> corners = [];\n  <b>let</b> px = x, py = y, dx = hx, dy = hy;\n  <b>for</b> (<b>let</b> i = 0; i &lt; 4; i++) {           <em>// 正方形：顺时针</em>\n    corners.push([px, py]);\n    px += dx * L; py += dy * L;\n    <b>const</b> t = dx; dx = dy; dy = -t;\n  }\n  squares.push(corners);\n\n  <b>const</b> cx = x - hy * L, cy = y + hx * L;  <em>// 圆心在左侧</em>\n  <b>const</b> a0 = <b>Math</b>.atan2(y - cy, x - cx);\n  <b>const</b> pts = [];\n  <b>const</b> N = <b>Math</b>.max(10, <b>Math</b>.round(14 + s * 1.6));\n  <b>for</b> (<b>let</b> k = 0; k &lt;= N; k++) {\n    <b>const</b> a = a0 + <b>Math</b>.PI / 2 * k / N;    <em>// 逆时针扫 90°</em>\n    pts.push([cx + L * <b>Math</b>.cos(a), cy + L * <b>Math</b>.sin(a)]);\n  }\n  arcs.push(pts);\n  x = pts[N][0]; y = pts[N][1];\n  <b>const</b> t2 = hx; hx = -hy; hy = t2;\n}\n\n<b>const</b> all = squares.flat().concat(arcs.flat());\n<b>const</b> x0 = <b>Math</b>.min(...all.map(p =&gt; p[0])), x1 = <b>Math</b>.max(...all.map(p =&gt; p[0]));\n<b>const</b> y0 = <b>Math</b>.min(...all.map(p =&gt; p[1])), y1 = <b>Math</b>.max(...all.map(p =&gt; p[1]));\n<b>const</b> mx = (x0 + x1) / 2, my = (y0 + y1) / 2;\n<b>const</b> sc = <b>Math</b>.min((<b>canvas</b>.width - 100) / (x1 - x0), (<b>canvas</b>.height - 100) / (y1 - y0));\n<b>const</b> T = p =&gt; [(p[0] - mx) * sc + <b>canvas</b>.width / 2, <b>canvas</b>.height / 2 - (p[1] - my) * sc];\n\n<em>// 正方形虚线</em>\n<b>ctx</b>.setLineDash([5, 4]);\n<b>ctx</b>.strokeStyle = <i>'rgba(0,229,255,.34)'</i>;\n<b>ctx</b>.lineWidth = 1;\n<b>for</b> (<b>const</b> sq <b>of</b> squares) {\n  <b>ctx</b>.beginPath();\n  sq.forEach((p, i) =&gt; { <b>const</b> q = T(p); i ? <b>ctx</b>.lineTo(q[0], q[1]) : <b>ctx</b>.moveTo(q[0], q[1]); });\n  <b>ctx</b>.closePath();\n  <b>ctx</b>.stroke();\n}\n<b>ctx</b>.setLineDash([]);\n\n<em>// 螺旋实线</em>\n<b>ctx</b>.strokeStyle = <i>'#00e5ff'</i>;\n<b>ctx</b>.lineWidth = 2.2;\n<b>ctx</b>.lineJoin = <i>'round'</i>;\n<b>ctx</b>.beginPath();\narcs.forEach((a, i) =&gt; {\n  a.forEach((p, k) =&gt; { <b>const</b> q = T(p); (i === 0 &amp;&amp; k === 0) ? <b>ctx</b>.moveTo(q[0], q[1]) : <b>ctx</b>.lineTo(q[0], q[1]); });\n});\n<b>ctx</b>.stroke();\n", "plain": "// 黄金螺旋 · JavaScript + Canvas 2D\n// 斐波那契正方形 + 每个正方形里的 1/4 圆弧。\nconst canvas = document.createElement('canvas');\ncanvas.width = 660; canvas.height = 560;\ndocument.body.appendChild(canvas);\nconst ctx = canvas.getContext('2d');\nctx.fillStyle = '#060a14';\nctx.fillRect(0, 0, canvas.width, canvas.height);\n\nconst fib = [1, 1];\nfor (let i = 0; i < 7; i++) fib.push(fib[fib.length - 1] + fib[fib.length - 2]);\nconst SCALE = 14;\n\n// 先用纸笔推一遍，拿到所有正方形和弧，再统一缩放居中\nlet x = 0, y = 0, hx = 1, hy = 0;\nconst squares = [], arcs = [];\nfor (const s of fib) {\n  const L = s * SCALE;\n  const corners = [];\n  let px = x, py = y, dx = hx, dy = hy;\n  for (let i = 0; i < 4; i++) {           // 正方形：顺时针\n    corners.push([px, py]);\n    px += dx * L; py += dy * L;\n    const t = dx; dx = dy; dy = -t;\n  }\n  squares.push(corners);\n\n  const cx = x - hy * L, cy = y + hx * L;  // 圆心在左侧\n  const a0 = Math.atan2(y - cy, x - cx);\n  const pts = [];\n  const N = Math.max(10, Math.round(14 + s * 1.6));\n  for (let k = 0; k <= N; k++) {\n    const a = a0 + Math.PI / 2 * k / N;    // 逆时针扫 90°\n    pts.push([cx + L * Math.cos(a), cy + L * Math.sin(a)]);\n  }\n  arcs.push(pts);\n  x = pts[N][0]; y = pts[N][1];\n  const t2 = hx; hx = -hy; hy = t2;\n}\n\nconst all = squares.flat().concat(arcs.flat());\nconst x0 = Math.min(...all.map(p => p[0])), x1 = Math.max(...all.map(p => p[0]));\nconst y0 = Math.min(...all.map(p => p[1])), y1 = Math.max(...all.map(p => p[1]));\nconst mx = (x0 + x1) / 2, my = (y0 + y1) / 2;\nconst sc = Math.min((canvas.width - 100) / (x1 - x0), (canvas.height - 100) / (y1 - y0));\nconst T = p => [(p[0] - mx) * sc + canvas.width / 2, canvas.height / 2 - (p[1] - my) * sc];\n\n// 正方形虚线\nctx.setLineDash([5, 4]);\nctx.strokeStyle = 'rgba(0,229,255,.34)';\nctx.lineWidth = 1;\nfor (const sq of squares) {\n  ctx.beginPath();\n  sq.forEach((p, i) => { const q = T(p); i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1]); });\n  ctx.closePath();\n  ctx.stroke();\n}\nctx.setLineDash([]);\n\n// 螺旋实线\nctx.strokeStyle = '#00e5ff';\nctx.lineWidth = 2.2;\nctx.lineJoin = 'round';\nctx.beginPath();\narcs.forEach((a, i) => {\n  a.forEach((p, k) => { const q = T(p); (i === 0 && k === 0) ? ctx.moveTo(q[0], q[1]) : ctx.lineTo(q[0], q[1]); });\n});\nctx.stroke();\n"}, {"id": "c", "name": "C", "file": "spiral.c", "code": "<em>/* 黄金螺旋 · C 语言，控制台 ASCII\n   编译： gcc spiral.c -o spiral -lm\n   斐波那契正方形 + 每格的 1/4 圆弧，采样成字符。 */</em>\n#<b>include</b> &lt;stdio.h&gt;\n#<b>include</b> &lt;math.h&gt;\n\n#<b>define</b> WIDTH   79\n#<b>define</b> HEIGHT  40\n#<b>define</b> NSEG    9\n#<b>define</b> MAXPTS  2048\n\n<b>static</b> <b>int</b> fib[NSEG];\n<b>static</b> <b>double</b> px[MAXPTS], py[MAXPTS];\n<b>static</b> <b>int</b> n = 0;\n\n<b>int</b> <b>main</b>(<b>void</b>)\n{\n    <b>char</b> grid[HEIGHT][WIDTH + 1];\n    <b>int</b> i, j, k;\n    <b>double</b> x = 0, y = 0, hx = 1, hy = 0;\n    <b>double</b> SCALE = 15.0;\n\n    fib[0] = 1; fib[1] = 1;\n    <b>for</b> (i = 2; i &lt; NSEG; i++) fib[i] = fib[i - 1] + fib[i - 2];\n\n    <b>for</b> (i = 0; i &lt; NSEG; i++) {\n        <b>double</b> L = fib[i] * SCALE;\n        <b>double</b> cx = x - hy * L, cy = y + hx * L;   <em>/* 圆心在左侧 */</em>\n        <b>double</b> a0 = <b>atan2</b>(y - cy, x - cx);\n        <b>int</b> N = 12 + fib[i];\n        <b>if</b> (N &gt; 40) N = 40;\n        <b>for</b> (k = 0; k &lt;= N; k++) {\n            <b>double</b> a = a0 + <b>M_PI</b> / 2 * k / N;      <em>/* 逆时针 90° */</em>\n            <b>if</b> (n &lt; MAXPTS) {\n                px[n] = cx + L * <b>cos</b>(a);\n                py[n] = cy + L * <b>sin</b>(a);\n                n++;\n            }\n        }\n        x = px[n - 1]; y = py[n - 1];\n        <b>double</b> t = hx; hx = -hy; hy = t;\n    }\n\n    <em>/* 求包围盒并居中 */</em>\n    <b>double</b> x0 = px[0], x1 = px[0], y0 = py[0], y1 = py[0];\n    <b>for</b> (i = 1; i &lt; n; i++) {\n        <b>if</b> (px[i] &lt; x0) x0 = px[i];\n        <b>if</b> (px[i] &gt; x1) x1 = px[i];\n        <b>if</b> (py[i] &lt; y0) y0 = py[i];\n        <b>if</b> (py[i] &gt; y1) y1 = py[i];\n    }\n    <b>double</b> span = (x1 - x0 &gt; y1 - y0) ? (x1 - x0) : (y1 - y0);\n    <b>if</b> (span &lt;= 0) span = 1;\n\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++)\n        <b>for</b> (k = 0; k &lt; WIDTH; k++) grid[j][k] = ' ';\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++) grid[j][WIDTH] = '\\0';\n\n    <b>for</b> (i = 0; i &lt; n; i++) {\n        <b>int</b> gx = (<b>int</b>)((px[i] - x0) / span * (WIDTH - 1));\n        <b>int</b> gy = (<b>int</b>)((y1 - py[i]) / span * (HEIGHT - 1));\n        <b>if</b> (gx &gt;= 0 &amp;&amp; gx &lt; WIDTH &amp;&amp; gy &gt;= 0 &amp;&amp; gy &lt; HEIGHT)\n            grid[gy][gx] = '*';\n    }\n\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++) <b>puts</b>(grid[j]);\n    <b>return</b> 0;\n}\n", "plain": "/* 黄金螺旋 · C 语言，控制台 ASCII\n   编译： gcc spiral.c -o spiral -lm\n   斐波那契正方形 + 每格的 1/4 圆弧，采样成字符。 */\n#include <stdio.h>\n#include <math.h>\n\n#define WIDTH   79\n#define HEIGHT  40\n#define NSEG    9\n#define MAXPTS  2048\n\nstatic int fib[NSEG];\nstatic double px[MAXPTS], py[MAXPTS];\nstatic int n = 0;\n\nint main(void)\n{\n    char grid[HEIGHT][WIDTH + 1];\n    int i, j, k;\n    double x = 0, y = 0, hx = 1, hy = 0;\n    double SCALE = 15.0;\n\n    fib[0] = 1; fib[1] = 1;\n    for (i = 2; i < NSEG; i++) fib[i] = fib[i - 1] + fib[i - 2];\n\n    for (i = 0; i < NSEG; i++) {\n        double L = fib[i] * SCALE;\n        double cx = x - hy * L, cy = y + hx * L;   /* 圆心在左侧 */\n        double a0 = atan2(y - cy, x - cx);\n        int N = 12 + fib[i];\n        if (N > 40) N = 40;\n        for (k = 0; k <= N; k++) {\n            double a = a0 + M_PI / 2 * k / N;      /* 逆时针 90° */\n            if (n < MAXPTS) {\n                px[n] = cx + L * cos(a);\n                py[n] = cy + L * sin(a);\n                n++;\n            }\n        }\n        x = px[n - 1]; y = py[n - 1];\n        double t = hx; hx = -hy; hy = t;\n    }\n\n    /* 求包围盒并居中 */\n    double x0 = px[0], x1 = px[0], y0 = py[0], y1 = py[0];\n    for (i = 1; i < n; i++) {\n        if (px[i] < x0) x0 = px[i];\n        if (px[i] > x1) x1 = px[i];\n        if (py[i] < y0) y0 = py[i];\n        if (py[i] > y1) y1 = py[i];\n    }\n    double span = (x1 - x0 > y1 - y0) ? (x1 - x0) : (y1 - y0);\n    if (span <= 0) span = 1;\n\n    for (j = 0; j < HEIGHT; j++)\n        for (k = 0; k < WIDTH; k++) grid[j][k] = ' ';\n    for (j = 0; j < HEIGHT; j++) grid[j][WIDTH] = '\\0';\n\n    for (i = 0; i < n; i++) {\n        int gx = (int)((px[i] - x0) / span * (WIDTH - 1));\n        int gy = (int)((y1 - py[i]) / span * (HEIGHT - 1));\n        if (gx >= 0 && gx < WIDTH && gy >= 0 && gy < HEIGHT)\n            grid[gy][gx] = '*';\n    }\n\n    for (j = 0; j < HEIGHT; j++) puts(grid[j]);\n    return 0;\n}\n"}]
        }
        ,{
            file: 'terminal.py',
            id: "term",
            tab: "\u25B6 \u7EC8\u7AEF",
            name: "\u4EA4\u4E92\u5F0F\u7EC8\u7AEF <i>\u00B7 \u81EA\u5DF1\u6572\u547D\u4EE4\u8BD5\u8BD5</i>",
            html: "<div class=\"nb-ts-term\"><div class=\"nb-ts-term-bar\"><i style=\"background:#ff5f57\"></i><i style=\"background:#febc2e\"></i><i style=\"background:#28c840\"></i><span class=\"t\">nb@channel: ~ &mdash; 试试敲 help</span></div><div class=\"nb-ts-term-body\" data-term></div><div class=\"nb-ts-thint\">↑ ↓ 翻历史　·　Tab 补全　·　输入 help 看全部命令</div></div>",
            code: "<m>import</b> <m>time</b>, <m>sys</b>, <m>random</b>, <m>datetime</b>\n\n<em># 一个能真的敲命令的终端。每条命令对应下面 COMMANDS 里的一个函数。</b>\nNB = {\n    <i>\"name\"</b>:  <i>\"NB频道 · NoBook Channel\"</b>,\n    <i>\"fans\"</b>:  <u>112363</b>,\n    <i>\"days\"</b>:  <u>213</b>,\n    <i>\"motto\"</b>: <i>\"热爱理科，与作死同行\"</b>,\n}\n\n<b>def</b> <s>c_whoami</b>(_):\n    <b>return</b> NB[<i>\"name\"</b>]\n\n<b>def</b> <s>c_uptime</b>(_):\n    <b>return</b> <i>\"已运行 %d 天 · 粉丝 %s\"</b> % (NB[<i>\"days\"</b>], <s>f</b>+{NB[<i>\"fans\"</b>]:,})\n\n<b>def</b> <s>c_fans</b>(_):\n    <b>return</b> <i>\"B站粉丝：%s\"</b> % <s>f</b>+{NB[<i>\"fans\"</b>]:,}</b>\n\n<b>def</b> <s>c_motto</b>(_):\n    <b>return</b> NB[<i>\"motto\"</b>]\n\n<b>def</b> <s>c_fortune</b>(_):\n    <b>return</b> <m>random</b>.<s>choice</b>(<i>\"化学考试不会的就选 C\"</b>, <i>\"别忘了签到\"</b>)\n\n<b>def</b> <s>c_date</b>(_):\n    <b>return</b> <m>datetime</b>.<s>datetime</b>.<s>now</b>().<s>strftime</b>(<i>\"%Y-%m-%d %H:%M:%S\"</b>)\n\nCOMMANDS = {\n    <i>\"whoami\"</b>: <s>c_whoami</b>,  <i>\"uptime\"</b>: <s>c_uptime</b>,\n    <i>\"nb fans\"</b>: <s>c_fans</b>,   <i>\"nb motto\"</b>: <s>c_motto</b>,\n    <i>\"fortune\"</b>: <s>c_fortune</b>, <i>\"date\"</b>: <s>c_date</b>,\n}\n\n<em># 主循环：读一行、找命令、打印结果</b>\n<b>while</b> <b>True</b>:\n    line = <m>input</b>(<i>\"$ \"</b>).<s>strip</b>()\n    <b>if</b> line <b>in</b> (<i>\"\"</b>, <i>\"exit\"</b>):\n        <b>break</b>\n    fn = COMMANDS.<s>get</b>(line)\n    <b>if</b> fn:\n        <s>type_out</b>(fn(line))\n    <b>else</b>:\n        <s>type_out</b>(<i>\"command not found: \"+</b>line)",
            plain: "import time, sys, random, datetime\n\n# 一个能真的敲命令的终端。每条命令对应下面 COMMANDS 里的一个函数。\nNB = {\n    \"name\":  \"NB频道 · NoBook Channel\",\n    \"fans\":  112363,\n    \"days\":  213,\n    \"motto\": \"热爱理科，与作死同行\",\n}\n\ndef c_whoami(_):\n    return NB[\"name\"]\n\ndef c_uptime(_):\n    return \"已运行 %d 天 · 粉丝 %s\" % (NB[\"days\"], f+{NB[\"fans\"]:,})\n\ndef c_fans(_):\n    return \"B站粉丝：%s\" % f+{NB[\"fans\"]:,}\n\ndef c_motto(_):\n    return NB[\"motto\"]\n\ndef c_fortune(_):\n    return random.choice(\"化学考试不会的就选 C\", \"别忘了签到\")\n\ndef c_date(_):\n    return datetime.datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")\n\nCOMMANDS = {\n    \"whoami\": c_whoami,  \"uptime\": c_uptime,\n    \"nb fans\": c_fans,   \"nb motto\": c_motto,\n    \"fortune\": c_fortune, \"date\": c_date,\n}\n\n# 主循环：读一行、找命令、打印结果\nwhile True:\n    line = input(\"$ \").strip()\n    if line in (\"\", \"exit\"):\n        break\n    fn = COMMANDS.get(line)\n    if fn:\n        type_out(fn(line))\n    else:\n        type_out(\"command not found: \"+line)",
            init: initTerminal,
            langs: [{"id": "py", "name": "Python", "file": "term.py", "code": "<m>import</b> <m>time</b>, <m>sys</b>, <m>random</b>, <m>datetime</b>\n\n<em># 一个能真的敲命令的终端。每条命令对应下面 COMMANDS 里的一个函数。</b>\nNB = {\n    <i>\"name\"</b>:  <i>\"NB频道 · NoBook Channel\"</b>,\n    <i>\"fans\"</b>:  <u>112363</b>,\n    <i>\"days\"</b>:  <u>213</b>,\n    <i>\"motto\"</b>: <i>\"热爱理科，与作死同行\"</b>,\n}\n\n<b>def</b> <s>c_whoami</b>(_):\n    <b>return</b> NB[<i>\"name\"</b>]\n\n<b>def</b> <s>c_uptime</b>(_):\n    <b>return</b> <i>\"已运行 %d 天 · 粉丝 %s\"</b> % (NB[<i>\"days\"</b>], <s>f</b>+{NB[<i>\"fans\"</b>]:,})\n\n<b>def</b> <s>c_fans</b>(_):\n    <b>return</b> <i>\"B站粉丝：%s\"</b> % <s>f</b>+{NB[<i>\"fans\"</b>]:,}</b>\n\n<b>def</b> <s>c_motto</b>(_):\n    <b>return</b> NB[<i>\"motto\"</b>]\n\n<b>def</b> <s>c_fortune</b>(_):\n    <b>return</b> <m>random</b>.<s>choice</b>(<i>\"化学考试不会的就选 C\"</b>, <i>\"别忘了签到\"</b>)\n\n<b>def</b> <s>c_date</b>(_):\n    <b>return</b> <m>datetime</b>.<s>datetime</b>.<s>now</b>().<s>strftime</b>(<i>\"%Y-%m-%d %H:%M:%S\"</b>)\n\nCOMMANDS = {\n    <i>\"whoami\"</b>: <s>c_whoami</b>,  <i>\"uptime\"</b>: <s>c_uptime</b>,\n    <i>\"nb fans\"</b>: <s>c_fans</b>,   <i>\"nb motto\"</b>: <s>c_motto</b>,\n    <i>\"fortune\"</b>: <s>c_fortune</b>, <i>\"date\"</b>: <s>c_date</b>,\n}\n\n<em># 主循环：读一行、找命令、打印结果</b>\n<b>while</b> <b>True</b>:\n    line = <m>input</b>(<i>\"$ \"</b>).<s>strip</b>()\n    <b>if</b> line <b>in</b> (<i>\"\"</b>, <i>\"exit\"</b>):\n        <b>break</b>\n    fn = COMMANDS.<s>get</b>(line)\n    <b>if</b> fn:\n        <s>type_out</b>(fn(line))\n    <b>else</b>:\n        <s>type_out</b>(<i>\"command not found: \"+</b>line)", "plain": "import time, sys, random, datetime\n\n# 一个能真的敲命令的终端。每条命令对应下面 COMMANDS 里的一个函数。\nNB = {\n    \"name\":  \"NB频道 · NoBook Channel\",\n    \"fans\":  112363,\n    \"days\":  213,\n    \"motto\": \"热爱理科，与作死同行\",\n}\n\ndef c_whoami(_):\n    return NB[\"name\"]\n\ndef c_uptime(_):\n    return \"已运行 %d 天 · 粉丝 %s\" % (NB[\"days\"], f+{NB[\"fans\"]:,})\n\ndef c_fans(_):\n    return \"B站粉丝：%s\" % f+{NB[\"fans\"]:,}\n\ndef c_motto(_):\n    return NB[\"motto\"]\n\ndef c_fortune(_):\n    return random.choice(\"化学考试不会的就选 C\", \"别忘了签到\")\n\ndef c_date(_):\n    return datetime.datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")\n\nCOMMANDS = {\n    \"whoami\": c_whoami,  \"uptime\": c_uptime,\n    \"nb fans\": c_fans,   \"nb motto\": c_motto,\n    \"fortune\": c_fortune, \"date\": c_date,\n}\n\n# 主循环：读一行、找命令、打印结果\nwhile True:\n    line = input(\"$ \").strip()\n    if line in (\"\", \"exit\"):\n        break\n    fn = COMMANDS.get(line)\n    if fn:\n        type_out(fn(line))\n    else:\n        type_out(\"command not found: \"+line)"}, {"id": "js", "name": "JavaScript", "file": "terminal.js", "code": "<em>// 交互式终端 · JavaScript（这份就是网页上那个终端本身的做法）</em>\n<em>// Node 里跑：node terminal.js</em>\n<b>const</b> readline = <b>require</b>(<i>'readline'</i>);\n\n<b>const</b> NB = {\n  name: <i>'NB频道 · NoBook Channel'</i>,\n  fans: 112363,\n  days: 213,\n  motto: <i>'热爱理科，与作死同行'</i>\n};\n<b>const</b> FILES = {\n  <i>'about.txt'</i>: <i>'一个由 UP主「NB搞事局」建立的虚拟公司。\\n化学与物理实验 · 日常作死 · NB币虚拟经济'</i>,\n  <i>'motto.txt'</i>: NB.motto\n};\n<b>const</b> MODULES = [<i>'about'</i>, <i>'videos'</i>, <i>'shop'</i>, <i>'bank'</i>, <i>'stock'</i>, <i>'chat'</i>, <i>'tools'</i>, <i>'vote'</i>];\n\n<b>const</b> COMMANDS = {\n  help() {\n    <b>return</b> [\n      <i>'可用命令：'</i>,\n      <i>'  help             显示这份帮助'</i>,\n      <i>'  whoami           我是谁'</i>,\n      <i>'  cat &lt;文件&gt;       读文件（about.txt / motto.txt）'</i>,\n      <i>'  ls [modules/]    列目录'</i>,\n      <i>'  uptime           运行时长'</i>,\n      <i>'  nb fans          粉丝数'</i>,\n      <i>'  nb motto         口号'</i>,\n      <i>'  clear            清屏'</i>,\n      <i>'  exit             退出'</i>\n    ].join(<i>'\\n'</i>);\n  },\n  whoami() { <b>return</b> NB.name; },\n  ls(arg) {\n    <b>return</b> (arg === <i>'modules/'</i> || arg === <i>'modules'</i>)\n      ? MODULES.join(<i>'  '</i>)\n      : <i>'about.txt  motto.txt  modules/'</i>;\n  },\n  cat(arg) {\n    <b>const</b> f = (arg || <i>''</i>).trim();\n    <b>if</b> (!f) <b>return</b> <i>'命令语法不正确。'</i>;\n    <b>return</b> FILES[f] !== undefined ? FILES[f] : <i>'系统找不到指定的文件。'</i>;\n  },\n  uptime() { <b>return</b> <i>'已运行 '</i> + NB.days + <i>' 天'</i>; },\n  nb(arg) {\n    <b>const</b> a = (arg || <i>''</i>).trim();\n    <b>if</b> (a === <i>'fans'</i>)  <b>return</b> <i>'B 站粉丝：'</i> + NB.fans.toLocaleString();\n    <b>if</b> (a === <i>'motto'</i>) <b>return</b> NB.motto;\n    <b>return</b> <i>'用法：nb &lt;fans|motto&gt;'</i>;\n  },\n  clear() { <b>console</b>.clear(); <b>return</b> null; },\n  exit() { <b>return</b> <i>'\\u0000EXIT'</i>; }\n};\nCOMMANDS[<i>'?'</i>] = COMMANDS.help;\n\n<b>const</b> rl = readline.createInterface({ input: process.stdin, output: process.stdout });\n<b>console</b>.log(<i>'输入 help 看全部命令，或者直接敲一条试试。\\n'</i>);\n\n<b>function</b> prompt() {\n  rl.question(<i>'$ '</i>, line =&gt; {\n    <b>const</b> text = line.trim();\n    <b>if</b> (!text) <b>return</b> prompt();\n    <b>const</b> sp = text.indexOf(<i>' '</i>);\n    <b>const</b> name = sp &lt; 0 ? text : text.slice(0, sp);\n    <b>const</b> arg = sp &lt; 0 ? <i>''</i> : text.slice(sp + 1);\n    <b>const</b> fn = COMMANDS[name];\n    <b>if</b> (!fn) {\n      <em>/* 仿 Windows CMD 的报错 */</em>\n      <b>console</b>.log(<i>\"'\"</i> + name + <i>\"' 不是内部或外部命令，也不是可运行的程序\"</i>);\n      <b>console</b>.log(<i>'或批处理文件。'</i>);\n      <b>return</b> prompt();\n    }\n    <b>const</b> out = fn(arg);\n    <b>if</b> (out === <i>'\\u0000EXIT'</i>) { rl.close(); <b>return</b>; }\n    <b>if</b> (out) <b>console</b>.log(out);\n    prompt();\n  });\n}\nprompt();\n", "plain": "// 交互式终端 · JavaScript（这份就是网页上那个终端本身的做法）\n// Node 里跑：node terminal.js\nconst readline = require('readline');\n\nconst NB = {\n  name: 'NB频道 · NoBook Channel',\n  fans: 112363,\n  days: 213,\n  motto: '热爱理科，与作死同行'\n};\nconst FILES = {\n  'about.txt': '一个由 UP主「NB搞事局」建立的虚拟公司。\\n化学与物理实验 · 日常作死 · NB币虚拟经济',\n  'motto.txt': NB.motto\n};\nconst MODULES = ['about', 'videos', 'shop', 'bank', 'stock', 'chat', 'tools', 'vote'];\n\nconst COMMANDS = {\n  help() {\n    return [\n      '可用命令：',\n      '  help             显示这份帮助',\n      '  whoami           我是谁',\n      '  cat <文件>       读文件（about.txt / motto.txt）',\n      '  ls [modules/]    列目录',\n      '  uptime           运行时长',\n      '  nb fans          粉丝数',\n      '  nb motto         口号',\n      '  clear            清屏',\n      '  exit             退出'\n    ].join('\\n');\n  },\n  whoami() { return NB.name; },\n  ls(arg) {\n    return (arg === 'modules/' || arg === 'modules')\n      ? MODULES.join('  ')\n      : 'about.txt  motto.txt  modules/';\n  },\n  cat(arg) {\n    const f = (arg || '').trim();\n    if (!f) return '命令语法不正确。';\n    return FILES[f] !== undefined ? FILES[f] : '系统找不到指定的文件。';\n  },\n  uptime() { return '已运行 ' + NB.days + ' 天'; },\n  nb(arg) {\n    const a = (arg || '').trim();\n    if (a === 'fans')  return 'B 站粉丝：' + NB.fans.toLocaleString();\n    if (a === 'motto') return NB.motto;\n    return '用法：nb <fans|motto>';\n  },\n  clear() { console.clear(); return null; },\n  exit() { return '\\u0000EXIT'; }\n};\nCOMMANDS['?'] = COMMANDS.help;\n\nconst rl = readline.createInterface({ input: process.stdin, output: process.stdout });\nconsole.log('输入 help 看全部命令，或者直接敲一条试试。\\n');\n\nfunction prompt() {\n  rl.question('$ ', line => {\n    const text = line.trim();\n    if (!text) return prompt();\n    const sp = text.indexOf(' ');\n    const name = sp < 0 ? text : text.slice(0, sp);\n    const arg = sp < 0 ? '' : text.slice(sp + 1);\n    const fn = COMMANDS[name];\n    if (!fn) {\n      /* 仿 Windows CMD 的报错 */\n      console.log(\"'\" + name + \"' 不是内部或外部命令，也不是可运行的程序\");\n      console.log('或批处理文件。');\n      return prompt();\n    }\n    const out = fn(arg);\n    if (out === '\\u0000EXIT') { rl.close(); return; }\n    if (out) console.log(out);\n    prompt();\n  });\n}\nprompt();\n"}, {"id": "c", "name": "C", "file": "terminal.c", "code": "<em>/* 交互式终端 · C 语言\n   编译： gcc terminal.c -o terminal\n   实现一个最小的命令分发：读一行、查表、打印结果。 */</em>\n#<b>include</b> &lt;stdio.h&gt;\n#<b>include</b> &lt;string.h&gt;\n#<b>include</b> &lt;stdlib.h&gt;\n\n#<b>define</b> MAXLINE 256\n#<b>define</b> MAXCMD  16\n\n<b>typedef</b> <b>struct</b> {\n    <b>const</b> <b>char</b> *name;\n    <b>void</b> (*fn)(<b>const</b> <b>char</b> *arg);\n} Cmd;\n\n<b>static</b> <b>const</b> <b>char</b> *FILES[][2] = {\n    { <i>\"about.txt\"</i>, <i>\"一个由 UP主「NB搞事局」建立的虚拟公司。\"</i> },\n    { <i>\"motto.txt\"</i>, <i>\"热爱理科，与作死同行\"</i> },\n    { NULL, NULL }\n};\n\n<b>static</b> <b>void</b> c_help(<b>const</b> <b>char</b> *arg)\n{\n    (<b>void</b>)arg;\n    <b>puts</b>(<i>\"可用命令：\"</i>);\n    <b>puts</b>(<i>\"  help             显示这份帮助\"</i>);\n    <b>puts</b>(<i>\"  whoami           我是谁\"</i>);\n    <b>puts</b>(<i>\"  cat &lt;文件&gt;       读文件\"</i>);\n    <b>puts</b>(<i>\"  ls               列目录\"</i>);\n    <b>puts</b>(<i>\"  uptime           运行时长\"</i>);\n    <b>puts</b>(<i>\"  clear            清屏\"</i>);\n    <b>puts</b>(<i>\"  <b>exit</b>             退出\"</i>);\n}\n\n<b>static</b> <b>void</b> c_whoami(<b>const</b> <b>char</b> *arg)\n{\n    (<b>void</b>)arg;\n    <b>puts</b>(<i>\"NB频道 · NoBook Channel\"</i>);\n}\n\n<b>static</b> <b>void</b> c_ls(<b>const</b> <b>char</b> *arg)\n{\n    (<b>void</b>)arg;\n    <b>puts</b>(<i>\"about.txt  motto.txt  modules/\"</i>);\n}\n\n<b>static</b> <b>void</b> c_cat(<b>const</b> <b>char</b> *arg)\n{\n    <b>int</b> i;\n    <b>if</b> (!arg || !*arg) { <b>puts</b>(<i>\"命令语法不正确。\"</i>); <b>return</b>; }\n    <b>for</b> (i = 0; FILES[i][0]; i++) {\n        <b>if</b> (<b>strcmp</b>(FILES[i][0], arg) == 0) { <b>puts</b>(FILES[i][1]); <b>return</b>; }\n    }\n    <b>puts</b>(<i>\"系统找不到指定的文件。\"</i>);\n}\n\n<b>static</b> <b>void</b> c_uptime(<b>const</b> <b>char</b> *arg)\n{\n    (<b>void</b>)arg;\n    <b>puts</b>(<i>\"已运行 213 天\"</i>);\n}\n\n<b>static</b> <b>void</b> c_clear(<b>const</b> <b>char</b> *arg)\n{\n    (<b>void</b>)arg;\n    <em>/* ANSI 清屏 */</em>\n    <b>fputs</b>(<i>\"\\033[2J\\033[H\"</i>, stdout);\n}\n\n<b>static</b> <b>void</b> c_exit(<b>const</b> <b>char</b> *arg)\n{\n    (<b>void</b>)arg;\n    <b>exit</b>(0);\n}\n\n<b>static</b> <b>const</b> Cmd CMDS[] = {\n    { <i>\"help\"</i>,   c_help   },\n    { <i>\"?\"</i>,      c_help   },\n    { <i>\"whoami\"</i>, c_whoami },\n    { <i>\"ls\"</i>,     c_ls     },\n    { <i>\"cat\"</i>,    c_cat    },\n    { <i>\"uptime\"</i>, c_uptime },\n    { <i>\"clear\"</i>,  c_clear  },\n    { <i>\"<b>exit</b>\"</i>,   c_exit   },\n    { NULL, NULL }\n};\n\n<b>int</b> main(<b>void</b>)\n{\n    <b>char</b> line[MAXLINE];\n    <b>puts</b>(<i>\"输入 help 看全部命令，或者直接敲一条试试。\"</i>);\n\n    <b>for</b> (;;) {\n        <b>int</b> i, hit = 0;\n        <b>char</b> *sp, *arg;\n\n        <b>fputs</b>(<i>\"$ \"</i>, stdout);\n        <b>if</b> (!<b>fgets</b>(line, sizeof(line), stdin)) break;\n        line[strcspn(line, <i>\"\\r\\n\"</i>)] = '\\0';\n        <b>if</b> (!line[0]) continue;\n\n        <em>/* 拆出命令和参数 */</em>\n        sp = <b>strchr</b>(line, ' ');\n        arg = <i>\"\"</i>;\n        <b>if</b> (sp) { *sp = '\\0'; arg = sp + 1; }\n\n        <b>for</b> (i = 0; CMDS[i].name; i++) {\n            <b>if</b> (<b>strcmp</b>(CMDS[i].name, line) == 0) {\n                CMDS[i].fn(arg);\n                hit = 1;\n                break;\n            }\n        }\n        <b>if</b> (!hit) {\n            <em>/* 仿 Windows CMD 的报错 */</em>\n            <b>printf</b>(<i>\"'%s' 不是内部或外部命令，也不是可运行的程序\\n\"</i>, line);\n            <b>puts</b>(<i>\"或批处理文件。\"</i>);\n        }\n    }\n    <b>return</b> 0;\n}\n", "plain": "/* 交互式终端 · C 语言\n   编译： gcc terminal.c -o terminal\n   实现一个最小的命令分发：读一行、查表、打印结果。 */\n#include <stdio.h>\n#include <string.h>\n#include <stdlib.h>\n\n#define MAXLINE 256\n#define MAXCMD  16\n\ntypedef struct {\n    const char *name;\n    void (*fn)(const char *arg);\n} Cmd;\n\nstatic const char *FILES[][2] = {\n    { \"about.txt\", \"一个由 UP主「NB搞事局」建立的虚拟公司。\" },\n    { \"motto.txt\", \"热爱理科，与作死同行\" },\n    { NULL, NULL }\n};\n\nstatic void c_help(const char *arg)\n{\n    (void)arg;\n    puts(\"可用命令：\");\n    puts(\"  help             显示这份帮助\");\n    puts(\"  whoami           我是谁\");\n    puts(\"  cat <文件>       读文件\");\n    puts(\"  ls               列目录\");\n    puts(\"  uptime           运行时长\");\n    puts(\"  clear            清屏\");\n    puts(\"  exit             退出\");\n}\n\nstatic void c_whoami(const char *arg)\n{\n    (void)arg;\n    puts(\"NB频道 · NoBook Channel\");\n}\n\nstatic void c_ls(const char *arg)\n{\n    (void)arg;\n    puts(\"about.txt  motto.txt  modules/\");\n}\n\nstatic void c_cat(const char *arg)\n{\n    int i;\n    if (!arg || !*arg) { puts(\"命令语法不正确。\"); return; }\n    for (i = 0; FILES[i][0]; i++) {\n        if (strcmp(FILES[i][0], arg) == 0) { puts(FILES[i][1]); return; }\n    }\n    puts(\"系统找不到指定的文件。\");\n}\n\nstatic void c_uptime(const char *arg)\n{\n    (void)arg;\n    puts(\"已运行 213 天\");\n}\n\nstatic void c_clear(const char *arg)\n{\n    (void)arg;\n    /* ANSI 清屏 */\n    fputs(\"\\033[2J\\033[H\", stdout);\n}\n\nstatic void c_exit(const char *arg)\n{\n    (void)arg;\n    exit(0);\n}\n\nstatic const Cmd CMDS[] = {\n    { \"help\",   c_help   },\n    { \"?\",      c_help   },\n    { \"whoami\", c_whoami },\n    { \"ls\",     c_ls     },\n    { \"cat\",    c_cat    },\n    { \"uptime\", c_uptime },\n    { \"clear\",  c_clear  },\n    { \"exit\",   c_exit   },\n    { NULL, NULL }\n};\n\nint main(void)\n{\n    char line[MAXLINE];\n    puts(\"输入 help 看全部命令，或者直接敲一条试试。\");\n\n    for (;;) {\n        int i, hit = 0;\n        char *sp, *arg;\n\n        fputs(\"$ \", stdout);\n        if (!fgets(line, sizeof(line), stdin)) break;\n        line[strcspn(line, \"\\r\\n\")] = '\\0';\n        if (!line[0]) continue;\n\n        /* 拆出命令和参数 */\n        sp = strchr(line, ' ');\n        arg = \"\";\n        if (sp) { *sp = '\\0'; arg = sp + 1; }\n\n        for (i = 0; CMDS[i].name; i++) {\n            if (strcmp(CMDS[i].name, line) == 0) {\n                CMDS[i].fn(arg);\n                hit = 1;\n                break;\n            }\n        }\n        if (!hit) {\n            /* 仿 Windows CMD 的报错 */\n            printf(\"'%s' 不是内部或外部命令，也不是可运行的程序\\n\", line);\n            puts(\"或批处理文件。\");\n        }\n    }\n    return 0;\n}\n"}]
        }
        ,{
            file: 'visits_chart.py',
            id: "data",
            tab: "\uD83D\uDCCA \u5B9E\u65F6\u6570\u636E",
            name: "\u8BBF\u95EE\u91CF\u8D70\u52BF <i>\u00B7 \u6700\u8FD1 30 \u5929</i>",
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"网站访问量走势面板\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><defs><linearGradient id=\"nbTsArea\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#00e5ff\" stop-opacity=\"0.34\"/><stop offset=\"1\" stop-color=\"#00e5ff\" stop-opacity=\"0\"/></linearGradient></defs><line x1=\"56.0\" y1=\"468.0\" x2=\"612.0\" y2=\"468.0\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"471.5\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">72</text><line x1=\"56.0\" y1=\"364.5\" x2=\"612.0\" y2=\"364.5\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"368.0\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">99</text><line x1=\"56.0\" y1=\"261.0\" x2=\"612.0\" y2=\"261.0\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"264.5\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">125</text><line x1=\"56.0\" y1=\"157.5\" x2=\"612.0\" y2=\"157.5\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"161.0\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">152</text><line x1=\"56.0\" y1=\"54.0\" x2=\"612.0\" y2=\"54.0\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"57.5\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">179</text><path d=\"M56.00,396.19L75.17,354.41L94.34,332.99L113.52,329.04L132.69,335.00L151.86,341.65L171.03,341.57L190.21,331.71L209.38,314.49L228.55,296.69L247.72,286.83L266.90,291.79L286.07,313.91L305.24,349.55L324.41,389.71L343.59,422.49L362.76,436.69L381.93,425.27L401.10,387.64L420.28,329.94L439.45,263.24L458.62,200.24L477.79,151.56L496.97,122.77L516.14,113.16L535.31,116.58L554.48,124.01L573.66,126.99L592.83,120.68L612.00,105.54L612.00,468.00L56.00,468.00Z\" fill=\"url(#nbTsArea)\" class=\"nb-ts-area\"/><path d=\"M56.00,396.19L75.17,354.41L94.34,332.99L113.52,329.04L132.69,335.00L151.86,341.65L171.03,341.57L190.21,331.71L209.38,314.49L228.55,296.69L247.72,286.83L266.90,291.79L286.07,313.91L305.24,349.55L324.41,389.71L343.59,422.49L362.76,436.69L381.93,425.27L401.10,387.64L420.28,329.94L439.45,263.24L458.62,200.24L477.79,151.56L496.97,122.77L516.14,113.16L535.31,116.58L554.48,124.01L573.66,126.99L592.83,120.68L612.00,105.54\" class=\"nb-ts-chart\" style=\"--len:917.8\"/><circle class=\"nb-ts-pt\" cx=\"56.0\" cy=\"396.2\" r=\"3\" style=\"animation-delay:0.90s\"/><circle class=\"nb-ts-pt\" cx=\"151.9\" cy=\"341.7\" r=\"3\" style=\"animation-delay:1.12s\"/><circle class=\"nb-ts-pt\" cx=\"247.7\" cy=\"286.8\" r=\"3\" style=\"animation-delay:1.35s\"/><circle class=\"nb-ts-pt\" cx=\"343.6\" cy=\"422.5\" r=\"3\" style=\"animation-delay:1.57s\"/><circle class=\"nb-ts-pt\" cx=\"439.4\" cy=\"263.2\" r=\"3\" style=\"animation-delay:1.80s\"/><circle class=\"nb-ts-pt\" cx=\"535.3\" cy=\"116.6\" r=\"3\" style=\"animation-delay:2.02s\"/><circle class=\"nb-ts-pt\" cx=\"612.0\" cy=\"105.5\" r=\"3\" style=\"animation-delay:2.21s\"/><text x=\"56.0\" y=\"34\" fill=\"#7fe3ff\" font-size=\"12.5\" font-family=\"ui-monospace,Consolas,monospace\">visits / last 30 days</text><text class=\"nb-ts-pulse\" x=\"616.0\" y=\"95.5\" fill=\"#7fe3ff\" font-size=\"12\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">165</text></svg>",
            code: "<b>import</b> <m>matplotlib</m>.<m>pyplot</m> <b>as</b> <m>plt</m>\n<b>import</b> <m>math</m>\n\n<em># 把最近 30 天的访问量画成折线图</em>\n<em># 真实项目里这一行换成读数据库：SELECT day, visits FROM stats</em>\ndays = <u>30</u>\nvisits = [<u>78</u> + i*<u>2.6</u> + <u>26</u>*<m>math</m>.<s>sin</s>(i/<u>3.4</u>) + <u>14</u>*<m>math</m>.<s>sin</s>(i/<u>1.7</u> + <u>1.2</u>)\n          <b>for</b> i <b>in</b> <s>range</s>(days)]\n\n<m>plt</m>.<s>style</s>.<s>use</s>(<i>\"dark_background\"</i>)\nfig, ax = <m>plt</m>.<s>subplots</s>(figsize=(<u>6.4</u>, <u>5.2</u>), dpi=<u>100</u>)\n\n<em># 折线 + 面积填充</em>\nax.<s>plot</s>(<s>range</s>(days), visits, color=<i>\"#00e5ff\"</i>, linewidth=<u>2</u>)\nax.<s>fill_between</s>(<s>range</s>(days), visits, color=<i>\"#00e5ff\"</i>, alpha=<u>0.15</u>)\n\n<em># 每 5 天标一个点</em>\nidx = <s>list</s>(<s>range</s>(<u>0</u>, days, <u>5</u>))\nax.<s>scatter</s>(idx, [visits[i] <b>for</b> i <b>in</b> idx], color=<i>\"#7fe3ff\"</i>, s=<u>26</u>, zorder=<u>3</u>)\n\nax.<s>set_title</s>(<i>\"visits / last 30 days\"</i>, loc=<i>\"left\"</i>, color=<i>\"#7fe3ff\"</i>)\nax.<s>grid</s>(alpha=<u>0.12</u>, color=<i>\"#00e5ff\"</i>)\nfig.<s>tight_layout</s>()\n<m>plt</m>.<s>show</s>()",
            plain: "import matplotlib.pyplot as plt\nimport math\n\n# 把最近 30 天的访问量画成折线图\n# 真实项目里这一行换成读数据库：SELECT day, visits FROM stats\ndays = 30\nvisits = [78 + i*2.6 + 26*math.sin(i/3.4) + 14*math.sin(i/1.7 + 1.2)\n          for i in range(days)]\n\nplt.style.use(\"dark_background\")\nfig, ax = plt.subplots(figsize=(6.4, 5.2), dpi=100)\n\n# 折线 + 面积填充\nax.plot(range(days), visits, color=\"#00e5ff\", linewidth=2)\nax.fill_between(range(days), visits, color=\"#00e5ff\", alpha=0.15)\n\n# 每 5 天标一个点\nidx = list(range(0, days, 5))\nax.scatter(idx, [visits[i] for i in idx], color=\"#7fe3ff\", s=26, zorder=3)\n\nax.set_title(\"visits / last 30 days\", loc=\"left\", color=\"#7fe3ff\")\nax.grid(alpha=0.12, color=\"#00e5ff\")\nfig.tight_layout()\nplt.show()",
            langs: [{"id": "py", "name": "Python", "file": "data.py", "code": "<b>import</b> <m>matplotlib</m>.<m>pyplot</m> <b>as</b> <m>plt</m>\n<b>import</b> <m>math</m>\n\n<em># 把最近 30 天的访问量画成折线图</em>\n<em># 真实项目里这一行换成读数据库：SELECT day, visits FROM stats</em>\ndays = <u>30</u>\nvisits = [<u>78</u> + i*<u>2.6</u> + <u>26</u>*<m>math</m>.<s>sin</s>(i/<u>3.4</u>) + <u>14</u>*<m>math</m>.<s>sin</s>(i/<u>1.7</u> + <u>1.2</u>)\n          <b>for</b> i <b>in</b> <s>range</s>(days)]\n\n<m>plt</m>.<s>style</s>.<s>use</s>(<i>\"dark_background\"</i>)\nfig, ax = <m>plt</m>.<s>subplots</s>(figsize=(<u>6.4</u>, <u>5.2</u>), dpi=<u>100</u>)\n\n<em># 折线 + 面积填充</em>\nax.<s>plot</s>(<s>range</s>(days), visits, color=<i>\"#00e5ff\"</i>, linewidth=<u>2</u>)\nax.<s>fill_between</s>(<s>range</s>(days), visits, color=<i>\"#00e5ff\"</i>, alpha=<u>0.15</u>)\n\n<em># 每 5 天标一个点</em>\nidx = <s>list</s>(<s>range</s>(<u>0</u>, days, <u>5</u>))\nax.<s>scatter</s>(idx, [visits[i] <b>for</b> i <b>in</b> idx], color=<i>\"#7fe3ff\"</i>, s=<u>26</u>, zorder=<u>3</u>)\n\nax.<s>set_title</s>(<i>\"visits / last 30 days\"</i>, loc=<i>\"left\"</i>, color=<i>\"#7fe3ff\"</i>)\nax.<s>grid</s>(alpha=<u>0.12</u>, color=<i>\"#00e5ff\"</i>)\nfig.<s>tight_layout</s>()\n<m>plt</m>.<s>show</s>()", "plain": "import matplotlib.pyplot as plt\nimport math\n\n# 把最近 30 天的访问量画成折线图\n# 真实项目里这一行换成读数据库：SELECT day, visits FROM stats\ndays = 30\nvisits = [78 + i*2.6 + 26*math.sin(i/3.4) + 14*math.sin(i/1.7 + 1.2)\n          for i in range(days)]\n\nplt.style.use(\"dark_background\")\nfig, ax = plt.subplots(figsize=(6.4, 5.2), dpi=100)\n\n# 折线 + 面积填充\nax.plot(range(days), visits, color=\"#00e5ff\", linewidth=2)\nax.fill_between(range(days), visits, color=\"#00e5ff\", alpha=0.15)\n\n# 每 5 天标一个点\nidx = list(range(0, days, 5))\nax.scatter(idx, [visits[i] for i in idx], color=\"#7fe3ff\", s=26, zorder=3)\n\nax.set_title(\"visits / last 30 days\", loc=\"left\", color=\"#7fe3ff\")\nax.grid(alpha=0.12, color=\"#00e5ff\")\nfig.tight_layout()\nplt.show()"}, {"id": "js", "name": "JavaScript", "file": "visits.js", "code": "<em>// 访问量走势面板 · JavaScript + Canvas 2D</em>\n<em>// 折线 + 面积填充 + 数据点，和页面上那个 SVG 面板同样的观感。</em>\n<b>const</b> <b>canvas</b> = document.createElement(<i>'<b>canvas</b>'</i>);\n<b>canvas</b>.width = 660; <b>canvas</b>.height = 520;\ndocument.body.appendChild(<b>canvas</b>);\n<b>const</b> <b>ctx</b> = <b>canvas</b>.getContext(<i>'2d'</i>);\n<b>ctx</b>.fillStyle = <i>'#060a14'</i>;\n<b>ctx</b>.fillRect(0, 0, <b>canvas</b>.width, <b>canvas</b>.height);\n\n<b>const</b> days = 30;\n<em>// 真实项目里这一行换成接口数据</em>\n<b>const</b> visits = Array.from({ length: days }, (_, i) =&gt;\n  78 + i * 2.6 + 26 * <b>Math</b>.sin(i / 3.4) + 14 * <b>Math</b>.sin(i / 1.7 + 1.2));\n\n<b>const</b> PL = 56, PR = 28, PT = 54, PB = 52;\n<b>const</b> plotW = <b>canvas</b>.width - PL - PR;\n<b>const</b> plotH = <b>canvas</b>.height - PT - PB;\n<b>const</b> mx = <b>Math</b>.max(...visits), mn = <b>Math</b>.min(...visits);\n<b>const</b> PX = i =&gt; PL + plotW * i / (days - 1);\n<b>const</b> PY = v =&gt; PT + plotH * (1 - (v - mn * 0.9) / (mx * 1.08 - mn * 0.9));\n\n<em>// 网格 + y 轴刻度</em>\n<b>ctx</b>.font = <i>'10.5px monospace'</i>;\n<b>ctx</b>.textAlign = <i>'right'</i>;\n<b>for</b> (<b>let</b> k = 0; k &lt; 5; k++) {\n  <b>const</b> gv = mn * 0.9 + (mx * 1.08 - mn * 0.9) * k / 4;\n  <b>const</b> gy = PY(gv);\n  <b>ctx</b>.strokeStyle = <i>'rgba(0,229,255,.11)'</i>;\n  <b>ctx</b>.beginPath(); <b>ctx</b>.moveTo(PL, gy); <b>ctx</b>.lineTo(<b>canvas</b>.width - PR, gy); <b>ctx</b>.stroke();\n  <b>ctx</b>.fillStyle = <i>'rgba(140,200,235,.5)'</i>;\n  <b>ctx</b>.fillText(String(<b>Math</b>.round(gv)), PL - 10, gy + 3.5);\n}\n\n<em>// 面积填充</em>\n<b>const</b> grad = <b>ctx</b>.createLinearGradient(0, PT, 0, PT + plotH);\ngrad.addColorStop(0, <i>'rgba(0,229,255,.34)'</i>);\ngrad.addColorStop(1, <i>'rgba(0,229,255,0)'</i>);\n<b>ctx</b>.beginPath();\n<b>ctx</b>.moveTo(PX(0), PY(visits[0]));\n<b>for</b> (<b>let</b> i = 1; i &lt; days; i++) <b>ctx</b>.lineTo(PX(i), PY(visits[i]));\n<b>ctx</b>.lineTo(PX(days - 1), PT + plotH);\n<b>ctx</b>.lineTo(PX(0), PT + plotH);\n<b>ctx</b>.closePath();\n<b>ctx</b>.fillStyle = grad;\n<b>ctx</b>.fill();\n\n<em>// 折线</em>\n<b>ctx</b>.beginPath();\n<b>ctx</b>.moveTo(PX(0), PY(visits[0]));\n<b>for</b> (<b>let</b> i = 1; i &lt; days; i++) <b>ctx</b>.lineTo(PX(i), PY(visits[i]));\n<b>ctx</b>.strokeStyle = <i>'#00e5ff'</i>;\n<b>ctx</b>.lineWidth = 2.2;\n<b>ctx</b>.lineJoin = <i>'round'</i>;\n<b>ctx</b>.stroke();\n\n<em>// 每 5 天一个点</em>\n<b>ctx</b>.fillStyle = <i>'#7fe3ff'</i>;\n<b>for</b> (<b>let</b> i = 0; i &lt; days; i += 5) {\n  <b>ctx</b>.beginPath();\n  <b>ctx</b>.arc(PX(i), PY(visits[i]), 3, 0, <b>Math</b>.PI * 2);\n  <b>ctx</b>.fill();\n}\n\n<em>// 标题和末端数值</em>\n<b>ctx</b>.textAlign = <i>'left'</i>;\n<b>ctx</b>.fillStyle = <i>'#7fe3ff'</i>;\n<b>ctx</b>.font = <i>'12.5px monospace'</i>;\n<b>ctx</b>.fillText(<i>'visits / last 30 days'</i>, PL, 34);\n<b>ctx</b>.textAlign = <i>'right'</i>;\n<b>ctx</b>.fillText(String(<b>Math</b>.round(visits[days - 1])), PX(days - 1) + 4, PY(visits[days - 1]) - 10);\n", "plain": "// 访问量走势面板 · JavaScript + Canvas 2D\n// 折线 + 面积填充 + 数据点，和页面上那个 SVG 面板同样的观感。\nconst canvas = document.createElement('canvas');\ncanvas.width = 660; canvas.height = 520;\ndocument.body.appendChild(canvas);\nconst ctx = canvas.getContext('2d');\nctx.fillStyle = '#060a14';\nctx.fillRect(0, 0, canvas.width, canvas.height);\n\nconst days = 30;\n// 真实项目里这一行换成接口数据\nconst visits = Array.from({ length: days }, (_, i) =>\n  78 + i * 2.6 + 26 * Math.sin(i / 3.4) + 14 * Math.sin(i / 1.7 + 1.2));\n\nconst PL = 56, PR = 28, PT = 54, PB = 52;\nconst plotW = canvas.width - PL - PR;\nconst plotH = canvas.height - PT - PB;\nconst mx = Math.max(...visits), mn = Math.min(...visits);\nconst PX = i => PL + plotW * i / (days - 1);\nconst PY = v => PT + plotH * (1 - (v - mn * 0.9) / (mx * 1.08 - mn * 0.9));\n\n// 网格 + y 轴刻度\nctx.font = '10.5px monospace';\nctx.textAlign = 'right';\nfor (let k = 0; k < 5; k++) {\n  const gv = mn * 0.9 + (mx * 1.08 - mn * 0.9) * k / 4;\n  const gy = PY(gv);\n  ctx.strokeStyle = 'rgba(0,229,255,.11)';\n  ctx.beginPath(); ctx.moveTo(PL, gy); ctx.lineTo(canvas.width - PR, gy); ctx.stroke();\n  ctx.fillStyle = 'rgba(140,200,235,.5)';\n  ctx.fillText(String(Math.round(gv)), PL - 10, gy + 3.5);\n}\n\n// 面积填充\nconst grad = ctx.createLinearGradient(0, PT, 0, PT + plotH);\ngrad.addColorStop(0, 'rgba(0,229,255,.34)');\ngrad.addColorStop(1, 'rgba(0,229,255,0)');\nctx.beginPath();\nctx.moveTo(PX(0), PY(visits[0]));\nfor (let i = 1; i < days; i++) ctx.lineTo(PX(i), PY(visits[i]));\nctx.lineTo(PX(days - 1), PT + plotH);\nctx.lineTo(PX(0), PT + plotH);\nctx.closePath();\nctx.fillStyle = grad;\nctx.fill();\n\n// 折线\nctx.beginPath();\nctx.moveTo(PX(0), PY(visits[0]));\nfor (let i = 1; i < days; i++) ctx.lineTo(PX(i), PY(visits[i]));\nctx.strokeStyle = '#00e5ff';\nctx.lineWidth = 2.2;\nctx.lineJoin = 'round';\nctx.stroke();\n\n// 每 5 天一个点\nctx.fillStyle = '#7fe3ff';\nfor (let i = 0; i < days; i += 5) {\n  ctx.beginPath();\n  ctx.arc(PX(i), PY(visits[i]), 3, 0, Math.PI * 2);\n  ctx.fill();\n}\n\n// 标题和末端数值\nctx.textAlign = 'left';\nctx.fillStyle = '#7fe3ff';\nctx.font = '12.5px monospace';\nctx.fillText('visits / last 30 days', PL, 34);\nctx.textAlign = 'right';\nctx.fillText(String(Math.round(visits[days - 1])), PX(days - 1) + 4, PY(visits[days - 1]) - 10);\n"}, {"id": "c", "name": "C", "file": "visits.c", "code": "<em>/* 访问量走势 · C 语言，控制台 ASCII 折线图\n   编译： gcc visits.c -o visits -lm */</em>\n#<b>include</b> &lt;stdio.h&gt;\n#<b>include</b> &lt;math.h&gt;\n\n#<b>define</b> WIDTH   79\n#<b>define</b> HEIGHT  22\n#<b>define</b> DAYS    30\n\n<b>int</b> main(<b>void</b>)\n{\n    <b>double</b> v[DAYS], mx = -1e9, mn = 1e9;\n    <b>char</b> grid[HEIGHT][WIDTH + 1];\n    <b>int</b> i, j, k;\n\n    <em>/* 造数据，真实项目里换成读接口 */</em>\n    <b>for</b> (i = 0; i &lt; DAYS; i++) {\n        v[i] = 78 + i * 2.6 + 26 * sin(i / 3.4) + 14 * sin(i / 1.7 + 1.2);\n        <b>if</b> (v[i] &gt; mx) mx = v[i];\n        <b>if</b> (v[i] &lt; mn) mn = v[i];\n    }\n\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++)\n        <b>for</b> (k = 0; k &lt; WIDTH; k++) grid[j][k] = ' ';\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++) grid[j][WIDTH] = '\\0';\n\n    <em>/* 画横向网格线 */</em>\n    <b>for</b> (j = 0; j &lt; HEIGHT; j += 4) grid[j][0] = '|';\n\n    <em>/* 折线点 */</em>\n    <b>for</b> (i = 0; i &lt; DAYS; i++) {\n        <b>int</b> gx = (<b>int</b>)((<b>double</b>)i / (DAYS - 1) * (WIDTH - 6)) + 5;\n        <b>int</b> gy = HEIGHT - 1 - (<b>int</b>)((v[i] - mn * 0.9) / (mx * 1.08 - mn * 0.9) * (HEIGHT - 2));\n        <b>if</b> (gy &lt; 0) gy = 0;\n        <b>if</b> (gy &gt;= HEIGHT) gy = HEIGHT - 1;\n        <em>/* 把相邻点之间的空隙补上，免得断线 */</em>\n        <b>if</b> (i &gt; 0) {\n            <b>int</b> px = (<b>int</b>)((<b>double</b>)(i - 1) / (DAYS - 1) * (WIDTH - 6)) + 5;\n            <b>int</b> py = HEIGHT - 1 - (<b>int</b>)((v[i - 1] - mn * 0.9) / (mx * 1.08 - mn * 0.9) * (HEIGHT - 2));\n            <b>int</b> s, steps = gx - px;\n            <b>for</b> (s = 1; s &lt; steps; s++) {\n                <b>int</b> iy = py + (gy - py) * s / (steps ? steps : 1);\n                <b>int</b> ix = px + s;\n                <b>if</b> (ix &gt;= 0 &amp;&amp; ix &lt; WIDTH &amp;&amp; iy &gt;= 0 &amp;&amp; iy &lt; HEIGHT) grid[iy][ix] = '-';\n            }\n        }\n        <b>if</b> (gx &gt;= 0 &amp;&amp; gx &lt; WIDTH) grid[gy][gx] = '*';\n    }\n\n    <b>printf</b>(<i>\"visits / last %d days   (%.0f ~ %.0f)\\n\\n\"</i>, DAYS, mn, mx);\n    <b>for</b> (j = 0; j &lt; HEIGHT; j++) {\n        <b>printf</b>(<i>\"%3d %s\\n\"</i>,\n               (<b>int</b>)(mx - (mx - mn) * j / (HEIGHT - 1)), grid[j]);\n    }\n    <b>return</b> 0;\n}\n", "plain": "/* 访问量走势 · C 语言，控制台 ASCII 折线图\n   编译： gcc visits.c -o visits -lm */\n#include <stdio.h>\n#include <math.h>\n\n#define WIDTH   79\n#define HEIGHT  22\n#define DAYS    30\n\nint main(void)\n{\n    double v[DAYS], mx = -1e9, mn = 1e9;\n    char grid[HEIGHT][WIDTH + 1];\n    int i, j, k;\n\n    /* 造数据，真实项目里换成读接口 */\n    for (i = 0; i < DAYS; i++) {\n        v[i] = 78 + i * 2.6 + 26 * sin(i / 3.4) + 14 * sin(i / 1.7 + 1.2);\n        if (v[i] > mx) mx = v[i];\n        if (v[i] < mn) mn = v[i];\n    }\n\n    for (j = 0; j < HEIGHT; j++)\n        for (k = 0; k < WIDTH; k++) grid[j][k] = ' ';\n    for (j = 0; j < HEIGHT; j++) grid[j][WIDTH] = '\\0';\n\n    /* 画横向网格线 */\n    for (j = 0; j < HEIGHT; j += 4) grid[j][0] = '|';\n\n    /* 折线点 */\n    for (i = 0; i < DAYS; i++) {\n        int gx = (int)((double)i / (DAYS - 1) * (WIDTH - 6)) + 5;\n        int gy = HEIGHT - 1 - (int)((v[i] - mn * 0.9) / (mx * 1.08 - mn * 0.9) * (HEIGHT - 2));\n        if (gy < 0) gy = 0;\n        if (gy >= HEIGHT) gy = HEIGHT - 1;\n        /* 把相邻点之间的空隙补上，免得断线 */\n        if (i > 0) {\n            int px = (int)((double)(i - 1) / (DAYS - 1) * (WIDTH - 6)) + 5;\n            int py = HEIGHT - 1 - (int)((v[i - 1] - mn * 0.9) / (mx * 1.08 - mn * 0.9) * (HEIGHT - 2));\n            int s, steps = gx - px;\n            for (s = 1; s < steps; s++) {\n                int iy = py + (gy - py) * s / (steps ? steps : 1);\n                int ix = px + s;\n                if (ix >= 0 && ix < WIDTH && iy >= 0 && iy < HEIGHT) grid[iy][ix] = '-';\n            }\n        }\n        if (gx >= 0 && gx < WIDTH) grid[gy][gx] = '*';\n    }\n\n    printf(\"visits / last %d days   (%.0f ~ %.0f)\\n\\n\", DAYS, mn, mx);\n    for (j = 0; j < HEIGHT; j++) {\n        printf(\"%3d %s\\n\",\n               (int)(mx - (mx - mn) * j / (HEIGHT - 1)), grid[j]);\n    }\n    return 0;\n}\n"}]
        }
    ];

    var SHOW_LINES = 26;

    function mount() {
        try {
            if (document.documentElement.getAttribute('theme') !== 'tech') return;
            if (document.getElementById('nbTechRow')) return;
            var inner = document.querySelector('.hero-inner, .vhero-inner');
            if (!inner) return;
            var host = inner.parentNode;

            if (!document.getElementById('nbTechShowcaseCss')) {
                var st = document.createElement('style');
                st.id = 'nbTechShowcaseCss';
                st.textContent = CSS;
                document.head.appendChild(st);
            }

            var row = document.createElement('div');
            row.id = 'nbTechRow';
            row.className = 'nb-ts-row';

            var left = document.createElement('div');
            left.className = 'nb-ts-left';
            var bar = document.createElement('div');
            bar.className = 'nb-ts-bar';
            var title = document.createElement('span');
            title.className = 'sp';
            var tabs = document.createElement('div');
            tabs.className = 'nb-ts-tabs';
            bar.appendChild(title);
            bar.appendChild(tabs);

            var svgBox = document.createElement('div');
            left.appendChild(bar);
            left.appendChild(svgBox);

            var right = document.createElement('div');
            right.className = 'nb-ts-right';
            var wrap = document.createElement('div');
            wrap.className = 'nb-ts-codewrap';
            var head = document.createElement('div');
            head.className = 'nb-ts-codehead';
            var hsp = document.createElement('span');
            hsp.className = 'sp';
            hsp.textContent = '\uD83D\uDCCB \u6E90\u7801';
            var copyBtn = document.createElement('button');
            copyBtn.type = 'button';
            copyBtn.className = 'nb-ts-mini';
            copyBtn.textContent = '\u590D\u5236';
            var dlBtn = document.createElement('button');
            dlBtn.type = 'button';
            dlBtn.className = 'nb-ts-mini';
            dlBtn.textContent = '\u4E0B\u8F7D';
            dlBtn.title = '\u5B58\u6210\u6E90\u6587\u4EF6';
            var toggleBtn = document.createElement('button');
            toggleBtn.type = 'button';
            toggleBtn.className = 'nb-ts-mini';
            toggleBtn.textContent = '\u5C55\u5F00 \u25BE';
            head.appendChild(hsp);
            head.appendChild(copyBtn);
            head.appendChild(dlBtn);
            head.appendChild(toggleBtn);
            var langBar = document.createElement('div');
            langBar.className = 'nb-ts-langs';
            var pre = document.createElement('pre');
            pre.className = 'nb-ts-code';
            wrap.appendChild(head);
            wrap.appendChild(langBar);
            wrap.appendChild(pre);
            right.appendChild(wrap);

            row.appendChild(left);
            row.appendChild(right);

            var scroll = host.querySelector ? host.querySelector('.hero-scroll, .vhero-fade') : null;
            if (scroll && scroll.parentNode === host) host.insertBefore(row, scroll);
            else host.insertBefore(row, inner.nextSibling);

            /* ---------- 渲染某个内容 ---------- */
            var cur = null;
            var curLang = null;          /* 当前选中的语言（没有 langs 就是 null） */

            /* 当前该复制 / 下载的纯文本与文件名 —— 提到这里，
               因为外层的复制、下载、收起按钮都要用。 */
            function curText() { return curLang ? curLang.plain : (cur ? cur.plain : ''); }
            function curFile() {
                if (curLang) return curLang.file;
                if (!cur) return 'code.txt';
                return cur.file || (cur.id + '.py');
            }
            function render(it) {
                cur = it;
                title.innerHTML = it.name;
                /* 内容可以是 svg（图形）也可以是 html（比如可交互的终端） */
                svgBox.innerHTML = it.html || it.svg;
                if (typeof it.init === 'function') it.init(svgBox);

                /* 多语言：渲染一行语言按钮，切换时换代码和文件名 */
                curLang = (it.langs && it.langs.length) ? it.langs[0] : null;
                langBar.innerHTML = '';
                if (it.langs && it.langs.length) {
                    it.langs.forEach(function (lg) {
                        var b = document.createElement('button');
                        b.type = 'button';
                        b.className = 'nb-ts-lang' + (lg === curLang ? ' on' : '');
                        b.textContent = lg.name;
                        b.onclick = function () {
                            curLang = lg;
                            Array.prototype.forEach.call(langBar.children, function (x) {
                                x.classList.toggle('on', x === b);
                            });
                            showCode();
                        };
                        langBar.appendChild(b);
                    });
                }
                showCode();

                function showCode() {
                    /* 标题跟着当前语言走 */
                    hsp.textContent = '\uD83D\uDCCB ' +
                        (curLang ? curLang.name : 'Python') + ' \u6E90\u7801';
                    var code = curLang ? curLang.code : it.code;
                    var arr = code.split('\n');
                    pre.innerHTML = arr.slice(0, SHOW_LINES).join('\n') +
                        (arr.length > SHOW_LINES
                            ? '\n<em># \u2026\u2026 \u5171 ' + arr.length + ' \u884C\uFF0C\u70B9\u300C\u5C55\u5F00\u300D\u770B\u5B8C\u6574\u4EE3\u7801</em>'
                            : '');
                    wrap.classList.remove('open');
                    toggleBtn.textContent = '\u5C55\u5F00 \u25BE';
                    copyBtn.textContent = '\u590D\u5236';
                    copyBtn.classList.remove('done');
                }

                // 代码只截前 SHOW_LINES 行，其余靠「展开」
                var arr = it.code.split('\n');
                pre.innerHTML = arr.slice(0, SHOW_LINES).join('\n') +
                    (arr.length > SHOW_LINES
                        ? '\n<em># \u2026\u2026 \u5171 ' + arr.length + ' \u884C\uFF0C\u70B9\u300C\u5C55\u5F00\u300D\u770B\u5B8C\u6574\u4EE3\u7801</em>'
                        : '');
                wrap.classList.remove('open');
                toggleBtn.textContent = '\u5C55\u5F00 \u25BE';
                copyBtn.textContent = '\u590D\u5236';
                copyBtn.classList.remove('done');
                // Tab 高亮
                Array.prototype.forEach.call(tabs.children, function (b) {
                    b.classList.toggle('on', b.dataset.id === it.id);
                });
            }

            ITEMS.forEach(function (it, i) {
                var b = document.createElement('button');
                b.type = 'button';
                b.className = 'nb-ts-tab' + (i === 0 ? ' on' : '');
                b.dataset.id = it.id;
                b.textContent = it.tab;
                b.onclick = function () { render(it); };
                tabs.appendChild(b);
            });

            dlBtn.onclick = function () {
                var ok = saveText(curFile(), curText());
                dlBtn.textContent = ok ? '\u5DF2\u4E0B\u8F7D \u2713' : '\u4E0B\u8F7D\u5931\u8D25';
                dlBtn.classList.toggle('done', !!ok);
                setTimeout(function () {
                    dlBtn.textContent = '\u4E0B\u8F7D';
                    dlBtn.classList.remove('done');
                }, 1600);
            };

            toggleBtn.onclick = function () {
                var on = wrap.classList.toggle('open');
                if (on) {
                    pre.innerHTML = (curLang ? curLang.code : cur.code);
                } else {
                    /* 收起：只把代码截回去，不整个重渲染（否则语言按钮会被重置） */
                    var keep = curLang;
                    render(cur);
                    if (keep && cur.langs) {
                        curLang = keep;
                        Array.prototype.forEach.call(langBar.children, function (x, i) {
                            x.classList.toggle('on', cur.langs[i] === keep);
                        });
                        var c2 = keep.code.split('\n');
                        pre.innerHTML = c2.slice(0, SHOW_LINES).join('\n') +
                            (c2.length > SHOW_LINES
                                ? '\n<em># \u2026\u2026 \u5171 ' + c2.length + ' \u884C\uFF0C\u70B9\u300C\u5C55\u5F00\u300D\u770B\u5B8C\u6574\u4EE3\u7801</em>'
                                : '');
                    }
                }
                toggleBtn.textContent = on ? '\u6536\u8D77 \u25B4' : '\u5C55\u5F00 \u25BE';
            };

            copyBtn.onclick = function () {
                var text = curText();
                if (!text) { copyBtn.textContent = '\u6CA1\u6709\u5185\u5BB9'; return; }

                function ok() {
                    copyBtn.textContent = '\u5DF2\u590D\u5236 \u2713';
                    copyBtn.classList.add('done');
                    setTimeout(function () {
                        copyBtn.textContent = '\u590D\u5236';
                        copyBtn.classList.remove('done');
                    }, 1600);
                }
                function manual() {
                    /* 最后兜底：展开代码并全选，让用户自己按 Ctrl+C */
                    wrap.classList.add('open');
                    pre.innerHTML = (curLang ? curLang.code : cur.code);
                    var picked = false;
                    try {
                        var rng = document.createRange();
                        rng.selectNodeContents(pre);
                        var sel = window.getSelection();
                        sel.removeAllRanges();
                        sel.addRange(rng);
                        picked = String(sel).length > 0;
                    } catch (e) { picked = false; }
                    copyBtn.textContent = picked ? '\u5DF2\u9009\u4E2D Ctrl+C' : '\u8BF7\u624B\u52A8\u590D\u5236';
                    copyBtn.classList.add('done');
                    setTimeout(function () {
                        copyBtn.textContent = '\u590D\u5236';
                        copyBtn.classList.remove('done');
                    }, 2600);
                }
                function legacy() {
                    try {
                        var ta = document.createElement('textarea');
                        ta.value = text;
                        ta.setAttribute('readonly', '');
                        ta.style.cssText = 'position:fixed;left:-9999px;top:0;opacity:0;';
                        document.body.appendChild(ta);
                        ta.focus();
                        ta.select();
                        try { ta.setSelectionRange(0, ta.value.length); } catch (e0) {}
                        var copied = false;
                        try { copied = document.execCommand('copy'); } catch (e1) { copied = false; }
                        document.body.removeChild(ta);
                        if (copied) ok(); else manual();
                    } catch (e2) {
                        manual();
                    }
                }

                try {
                    if (navigator.clipboard && navigator.clipboard.writeText) {
                        navigator.clipboard.writeText(text).then(ok, legacy);
                    } else {
                        legacy();
                    }
                } catch (e) {
                    legacy();
                }
            };;

            render(ITEMS[0]);
        } catch (e) {}
    }

    function unmount() {
        var el = document.getElementById('nbTechRow');
        if (el && el.parentNode) el.parentNode.removeChild(el);
    }

    function boot() {
        mount();
        window.addEventListener('nb-theme-change', function () { unmount(); mount(); });
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})();
