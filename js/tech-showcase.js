/* NB频道 · 科技主题展示区
   只在 theme=tech 时挂载。左侧动画 + 右侧对应源码，顶部 Tab 切换内容。
   第一个内容：Python 海龟画谢尔宾斯基三角（深度 4 → 81 个三角形）。*/
(function () {
    'use strict';
    var CSS = ".nb-ts-row{position:relative;z-index:2;max-width:1180px;margin:64px auto 0;display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:start;}\n.nb-ts-left{min-width:0;align-self:start;}\n.nb-ts-right{min-width:0;max-width:100%;display:flex;flex-direction:column;}\n.nb-ts-bar{display:flex;align-items:center;gap:10px;margin-bottom:12px;flex-wrap:wrap;}\n.nb-ts-bar .sp{flex:1;min-width:0;font-size:.76rem;letter-spacing:1.2px;color:rgba(150,220,255,.8);}\n.nb-ts-tabs{display:flex;gap:6px;flex-wrap:wrap;}\n.nb-ts-tab{padding:5px 11px;border-radius:8px;cursor:pointer;font-family:inherit;font-size:.72rem;letter-spacing:.5px;background:rgba(0,229,255,.08);border:1px solid rgba(0,229,255,.22);color:rgba(180,230,255,.85);transition:.2s;}\n.nb-ts-tab:hover{background:rgba(0,229,255,.18);}\n.nb-ts-tab.on{background:rgba(0,229,255,.22);border-color:rgba(0,229,255,.6);color:#eaf9ff;box-shadow:0 0 18px -6px rgba(0,229,255,.7);}\n.nb-ts-svg{display:block;width:100%;height:auto;border-radius:12px;shape-rendering:geometricPrecision;box-shadow:0 20px 50px -30px rgba(0,0,0,.8);}\n.nb-ts-codewrap{display:flex;flex-direction:column;border-radius:12px;background:#1e1e1e;border:1px solid rgba(0,229,255,.2);overflow:hidden;}\n.nb-ts-codehead{display:flex;align-items:center;gap:8px;padding:11px 14px;font-size:.76rem;letter-spacing:1px;color:rgba(180,230,255,.8);}\n.nb-ts-codehead .sp{flex:1;min-width:0;}\n.nb-ts-mini{padding:5px 11px;border-radius:8px;cursor:pointer;font-size:.72rem;font-family:inherit;background:rgba(0,229,255,.1);border:1px solid rgba(0,229,255,.3);color:#7fe3ff;transition:.2s;}\n.nb-ts-mini:hover{background:rgba(0,229,255,.2);}\n.nb-ts-mini.done{background:rgba(120,220,150,.16);border-color:rgba(120,220,150,.5);color:#9be8b4;}\n.nb-ts-code{margin:0;padding:0 14px 16px;max-width:100%;box-sizing:border-box;font:11.5px/1.85 ui-monospace,Consolas,'Courier New',monospace;color:#d4d4d4;white-space:pre;overflow:hidden;-webkit-mask-image:linear-gradient(to bottom,#000 0,#000 70%,rgba(0,0,0,.4) 88%,transparent 100%);mask-image:linear-gradient(to bottom,#000 0,#000 70%,rgba(0,0,0,.4) 88%,transparent 100%);}\n.nb-ts-code b{color:#569cd6;font-weight:400;}\n.nb-ts-code i{color:#ce9178;font-style:normal;}\n.nb-ts-code u{color:#b5cea8;text-decoration:none;}\n.nb-ts-code s{color:#dcdcaa;text-decoration:none;}\n.nb-ts-code m{color:#4ec9b0;}\n.nb-ts-code em{color:#6a9955;font-style:normal;}\n.nb-ts-codewrap.open .nb-ts-code{overflow:auto;-webkit-mask-image:none;mask-image:none;}\n.nb-ts-poly polygon{fill:rgba(0,229,255,.14);stroke:#00e5ff;stroke-width:1.4;stroke-linejoin:round;opacity:0;animation:nbTsPop .5s cubic-bezier(.16,1,.3,1) forwards;}\n@keyframes nbTsPop{from{opacity:0;transform:scale(.6);transform-origin:center;}to{opacity:1;transform:scale(1);}}\n@media(max-width:900px){.nb-ts-row{grid-template-columns:1fr;gap:22px;margin-top:44px;}.nb-ts-code{font-size:10px;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-poly polygon{animation:none;opacity:1;}}\n.nb-ts-path{fill:none;stroke:#00e5ff;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw 2.6s linear forwards;filter:drop-shadow(0 0 5px rgba(0,229,255,.55));}\n@keyframes nbTsDraw{to{stroke-dashoffset:0;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-path{animation:none;stroke-dashoffset:0;}}\n.nb-ts-tline{opacity:0;animation:nbTsLine .28s ease forwards;}\n@keyframes nbTsLine{to{opacity:1;}}\n.nb-ts-caret{animation:nbTsCaret 1.05s steps(1,end) infinite;}\n@keyframes nbTsCaret{0%,49%{opacity:1;}50%,100%{opacity:0;}}\n.nb-ts-chart{fill:none;stroke:#00e5ff;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw 2.2s cubic-bezier(.4,0,.2,1) forwards;filter:drop-shadow(0 0 6px rgba(0,229,255,.6));}\n.nb-ts-area{opacity:0;animation:nbTsFadeIn 1.6s ease .8s forwards;}\n@keyframes nbTsFadeIn{to{opacity:1;}}\n.nb-ts-pt{fill:#7fe3ff;stroke:#060a14;stroke-width:1.4;opacity:0;animation:nbTsPop2 .4s ease forwards;}\n@keyframes nbTsPop2{to{opacity:1;}}\n.nb-ts-pulse{animation:nbTsPulse 1.9s ease-in-out infinite;}\n@keyframes nbTsPulse{0%,100%{opacity:.55;}50%{opacity:1;}}\n@media(prefers-reduced-motion:reduce){.nb-ts-tline,.nb-ts-area,.nb-ts-pt{animation:none;opacity:1;}.nb-ts-chart{animation:none;stroke-dashoffset:0;}.nb-ts-pulse{animation:none;}}\n.nb-ts-sq path{fill:none;stroke:rgba(0,229,255,.34);stroke-width:1;stroke-dasharray:5 4;opacity:0;animation:nbTsSqIn .5s ease forwards;}\n@keyframes nbTsSqIn{to{opacity:1;}}\n.nb-ts-num text{fill:rgba(0,229,255,.42);font:600 11.5px ui-monospace,Consolas,monospace;text-anchor:middle;opacity:0;animation:nbTsSqIn .5s ease forwards;}\n.nb-ts-spiral path{fill:none;stroke:#00e5ff;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:var(--len);stroke-dashoffset:var(--len);animation:nbTsDraw 1.1s linear forwards;filter:drop-shadow(0 0 6px rgba(0,229,255,.55));}\n@media(prefers-reduced-motion:reduce){.nb-ts-sq path,.nb-ts-num text{animation:none;opacity:1;}.nb-ts-spiral path{animation:none;stroke-dashoffset:0;}}\n.nb-ts-term{display:flex;flex-direction:column;height:100%;min-height:330px;border-radius:12px;background:#080d18;border:1px solid rgba(0,229,255,.22);overflow:hidden;box-shadow:0 20px 50px -30px rgba(0,0,0,.8);}\n.nb-ts-term-bar{display:flex;align-items:center;gap:7px;padding:9px 12px;background:rgba(0,229,255,.055);border-bottom:1px solid rgba(0,229,255,.14);flex:0 0 auto;}\n.nb-ts-term-bar i{width:11px;height:11px;border-radius:50%;display:block;}\n.nb-ts-term-bar .t{margin-left:8px;font:11.5px ui-monospace,Consolas,monospace;color:rgba(150,220,255,.5);}\n.nb-ts-term-body{flex:1;min-height:0;overflow-y:auto;padding:12px 14px;font:12.5px/1.72 ui-monospace,Consolas,'Courier New',monospace;color:rgba(205,228,250,.88);}\n.nb-ts-term-body::-webkit-scrollbar{width:8px;}\n.nb-ts-term-body::-webkit-scrollbar-thumb{background:rgba(0,229,255,.28);border-radius:8px;}\n.nb-ts-tl{white-space:pre-wrap;word-break:break-word;}\n.nb-ts-tl.cmd{color:#7fe3ff;}\n.nb-ts-tl.err{color:#ff8a8a;}\n.nb-ts-tl.dim{color:rgba(150,190,225,.5);}\n.nb-ts-tl.hi{color:#ffd24a;}\n.nb-ts-tl.ok{color:#7ee0a8;}\n.nb-ts-tin{display:flex;align-items:center;gap:0;}\n.nb-ts-tin .ps{color:#7fe3ff;flex:0 0 auto;}\n.nb-ts-tin input{flex:1;min-width:0;background:none;border:none;outline:none;color:#eaf4ff;font:inherit;caret-color:#7fe3ff;padding:0;}\n.nb-ts-thint{padding:7px 14px 10px;font-size:.68rem;letter-spacing:.4px;color:rgba(150,200,235,.42);border-top:1px solid rgba(0,229,255,.09);flex:0 0 auto;}";


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
                    '  cat <\u6587\u4ef6>        \u8bfb\u6587\u4ef6\uff08about.txt / motto.txt / README.md\uff09',
                    '  ls [modules/]     \u5217\u76ee\u5f55',
                    '  uptime            \u8fd0\u884c\u65f6\u957f',
                    '  date              \u5f53\u524d\u65f6\u95f4',
                    '  echo <\u6587\u5b57>       \u539f\u6837\u56de\u663e',
                    '  history           \u5386\u53f2\u547d\u4ee4',
                    '  clear             \u6e05\u5c4f',
                    '',
                    '\u2500\u2500 \u516c\u53f8\u7ecf\u8425 \u2500\u2500',
                    '  nb company        \u516c\u53f8\u6863\u6848\uff08\u542b\u5e02\u503c\uff09',
                    '  nb mcap           \u5e02\u503c\u4e0e\u5168\u7ad9\u6392\u540d',
                    '  nb stock [n]      \u5168\u5e02\u573a\u8d70\u52bf\uff08\u771f\u5b9e\u5feb\u7167\uff09',
                    '  nb market         \u5168\u5e02\u573a\u603b\u5e02\u503c',
                    '  nb product        \u4ea7\u54c1\u7ebf',
                    '  nb staff          \u56e2\u961f\u4eba\u6570',
                    '  nb friend         \u53cb\u5546\u540d\u5355',
                    '  nb news           \u6700\u8fd1\u516c\u544a',
                    '',
                    '\u2500\u2500 \u4e2a\u4eba \u2500\u2500',
                    '  nb fans           B \u7ad9\u7c89\u4e1d',
                    '  nb coin           NB \u5e01\u4f59\u989d',
                    '  nb rank [n]       \u5e02\u503c\u6392\u884c\u699c\uff08\u771f\u5b9e\u6570\u636e\uff09',
                    '  nb badge          \u5df2\u89e3\u9501\u5fbd\u7ae0',
                    '  fortune           \u968f\u673a\u4e00\u53e5',
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
                return '\u5df2\u8fd0\u884c ' + NB_CO.days + ' \u5929 \u00b7 \u603b\u8bbf\u95ee 3,000+';
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
            'echo': function (arg) { return arg || ''; },
            'clear': function () { clear(); return null; },
            'sudo': function (arg) {
                return { cls: 'err', text: '\u4f60\u5df2\u7ecf\u662f\u7ba1\u7406\u5458\u4e86\u3002' };
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
                            '\u2502 \u603b\u80a1\u672c  ' + fm(c.total_shares || 0) + ' \u80a1',
                            '\u2502 \u6d41\u901a\u80a1  ' + fm(c.circulating_shares || 0) + ' \u80a1',
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

                /* 友商：除了自己之外市值最高的几家 */
                if (sub === 'friend') {
                    return sbCompanies(12).then(function (all) {
                        var others = (all || []).filter(function (c) {
                            return c.company_name.indexOf('NB') !== 0;
                        }).slice(0, 6);
                        if (!others.length) return {cls: 'err', text: '\u6682\u65e0\u6570\u636e\u3002'};
                        return ['\u5e02\u503c\u9760\u524d\u7684\u90bb\u5c45\uff1a'].concat(
                            others.map(function (c) {
                                return '  ' + c.company_name.slice(0, 16) + '  ' + big(c.market_value || 0);
                            })).join('\n');
                    }).catch(function (e) {
                        return {cls: 'err', text: '\u8054\u7f51\u67e5\u8be2\u5931\u8d25\uff1a' + e.message};
                    });
                }

                /* 老命令保持同步返回 */
                if (sub === 'fans') return 'B \u7ad9\u7c89\u4e1d\uff1a' + fm(112363);
                if (sub === 'coin') return 'NB \u5e01\u4f4e\u989d\uff1a12,800';
                if (sub === 'motto') return TERM_FILES['motto.txt'];
                if (sub === 'badge') {
                    return '\u5df2\u89e3\u9501 7 / 24\uff1a\u521d\u6765\u4e4d\u5230 \u00b7 \u9996\u6b21\u8bc4\u8bba \u00b7 \u7b7e\u5230\u4e03\u5929 \u00b7 \u2026';
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
            id: 'sierpinski',
            tab: '\uD83D\uDD3A \u8C22\u5C14\u5BBE\u65AF\u57FA',
            name: 'Python \u6D77\u9F9F\u7ED8\u56FE <i>\u00B7 \u8C22\u5C14\u5BBE\u65AF\u57FA\u4E09\u89D2</i>',
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"Python 海龟绘图画出谢尔宾斯基三角\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><defs><pattern id=\"nbTsGrid\" width=\"32\" height=\"32\" patternUnits=\"userSpaceOnUse\"><path d=\"M32 0H0V32\" fill=\"none\" stroke=\"rgba(0,229,255,.07)\" stroke-width=\"1\"/></pattern></defs><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><g class=\"nb-ts-poly\"><polygon points=\"70.00,415.00 101.25,415.00 85.62,388.91\" style=\"animation-delay:0.000s\"/><polygon points=\"101.25,415.00 132.50,415.00 116.88,388.91\" style=\"animation-delay:0.035s\"/><polygon points=\"85.62,388.91 116.88,388.91 101.25,362.81\" style=\"animation-delay:0.070s\"/><polygon points=\"132.50,415.00 163.75,415.00 148.12,388.91\" style=\"animation-delay:0.105s\"/><polygon points=\"163.75,415.00 195.00,415.00 179.38,388.91\" style=\"animation-delay:0.140s\"/><polygon points=\"148.12,388.91 179.38,388.91 163.75,362.81\" style=\"animation-delay:0.175s\"/><polygon points=\"101.25,362.81 132.50,362.81 116.88,336.72\" style=\"animation-delay:0.210s\"/><polygon points=\"132.50,362.81 163.75,362.81 148.12,336.72\" style=\"animation-delay:0.245s\"/><polygon points=\"116.88,336.72 148.12,336.72 132.50,310.62\" style=\"animation-delay:0.280s\"/><polygon points=\"195.00,415.00 226.25,415.00 210.62,388.91\" style=\"animation-delay:0.315s\"/><polygon points=\"226.25,415.00 257.50,415.00 241.88,388.91\" style=\"animation-delay:0.350s\"/><polygon points=\"210.62,388.91 241.88,388.91 226.25,362.81\" style=\"animation-delay:0.385s\"/><polygon points=\"257.50,415.00 288.75,415.00 273.12,388.91\" style=\"animation-delay:0.420s\"/><polygon points=\"288.75,415.00 320.00,415.00 304.38,388.91\" style=\"animation-delay:0.455s\"/><polygon points=\"273.12,388.91 304.38,388.91 288.75,362.81\" style=\"animation-delay:0.490s\"/><polygon points=\"226.25,362.81 257.50,362.81 241.88,336.72\" style=\"animation-delay:0.525s\"/><polygon points=\"257.50,362.81 288.75,362.81 273.12,336.72\" style=\"animation-delay:0.560s\"/><polygon points=\"241.88,336.72 273.12,336.72 257.50,310.62\" style=\"animation-delay:0.595s\"/><polygon points=\"132.50,310.62 163.75,310.62 148.12,284.53\" style=\"animation-delay:0.630s\"/><polygon points=\"163.75,310.62 195.00,310.62 179.38,284.53\" style=\"animation-delay:0.665s\"/><polygon points=\"148.12,284.53 179.38,284.53 163.75,258.44\" style=\"animation-delay:0.700s\"/><polygon points=\"195.00,310.62 226.25,310.62 210.62,284.53\" style=\"animation-delay:0.735s\"/><polygon points=\"226.25,310.62 257.50,310.62 241.88,284.53\" style=\"animation-delay:0.770s\"/><polygon points=\"210.62,284.53 241.88,284.53 226.25,258.44\" style=\"animation-delay:0.805s\"/><polygon points=\"163.75,258.44 195.00,258.44 179.38,232.34\" style=\"animation-delay:0.840s\"/><polygon points=\"195.00,258.44 226.25,258.44 210.62,232.34\" style=\"animation-delay:0.875s\"/><polygon points=\"179.38,232.34 210.62,232.34 195.00,206.25\" style=\"animation-delay:0.910s\"/><polygon points=\"320.00,415.00 351.25,415.00 335.62,388.91\" style=\"animation-delay:0.945s\"/><polygon points=\"351.25,415.00 382.50,415.00 366.88,388.91\" style=\"animation-delay:0.980s\"/><polygon points=\"335.62,388.91 366.88,388.91 351.25,362.81\" style=\"animation-delay:1.015s\"/><polygon points=\"382.50,415.00 413.75,415.00 398.12,388.91\" style=\"animation-delay:1.050s\"/><polygon points=\"413.75,415.00 445.00,415.00 429.38,388.91\" style=\"animation-delay:1.085s\"/><polygon points=\"398.12,388.91 429.38,388.91 413.75,362.81\" style=\"animation-delay:1.120s\"/><polygon points=\"351.25,362.81 382.50,362.81 366.88,336.72\" style=\"animation-delay:1.155s\"/><polygon points=\"382.50,362.81 413.75,362.81 398.12,336.72\" style=\"animation-delay:1.190s\"/><polygon points=\"366.88,336.72 398.12,336.72 382.50,310.62\" style=\"animation-delay:1.225s\"/><polygon points=\"445.00,415.00 476.25,415.00 460.62,388.91\" style=\"animation-delay:1.260s\"/><polygon points=\"476.25,415.00 507.50,415.00 491.88,388.91\" style=\"animation-delay:1.295s\"/><polygon points=\"460.62,388.91 491.88,388.91 476.25,362.81\" style=\"animation-delay:1.330s\"/><polygon points=\"507.50,415.00 538.75,415.00 523.12,388.91\" style=\"animation-delay:1.365s\"/><polygon points=\"538.75,415.00 570.00,415.00 554.38,388.91\" style=\"animation-delay:1.400s\"/><polygon points=\"523.12,388.91 554.38,388.91 538.75,362.81\" style=\"animation-delay:1.435s\"/><polygon points=\"476.25,362.81 507.50,362.81 491.88,336.72\" style=\"animation-delay:1.470s\"/><polygon points=\"507.50,362.81 538.75,362.81 523.12,336.72\" style=\"animation-delay:1.505s\"/><polygon points=\"491.88,336.72 523.12,336.72 507.50,310.62\" style=\"animation-delay:1.540s\"/><polygon points=\"382.50,310.62 413.75,310.62 398.12,284.53\" style=\"animation-delay:1.575s\"/><polygon points=\"413.75,310.62 445.00,310.62 429.38,284.53\" style=\"animation-delay:1.610s\"/><polygon points=\"398.12,284.53 429.38,284.53 413.75,258.44\" style=\"animation-delay:1.645s\"/><polygon points=\"445.00,310.62 476.25,310.62 460.62,284.53\" style=\"animation-delay:1.680s\"/><polygon points=\"476.25,310.62 507.50,310.62 491.88,284.53\" style=\"animation-delay:1.715s\"/><polygon points=\"460.62,284.53 491.88,284.53 476.25,258.44\" style=\"animation-delay:1.750s\"/><polygon points=\"413.75,258.44 445.00,258.44 429.38,232.34\" style=\"animation-delay:1.785s\"/><polygon points=\"445.00,258.44 476.25,258.44 460.62,232.34\" style=\"animation-delay:1.820s\"/><polygon points=\"429.38,232.34 460.62,232.34 445.00,206.25\" style=\"animation-delay:1.855s\"/><polygon points=\"195.00,206.25 226.25,206.25 210.62,180.16\" style=\"animation-delay:1.890s\"/><polygon points=\"226.25,206.25 257.50,206.25 241.88,180.16\" style=\"animation-delay:1.925s\"/><polygon points=\"210.62,180.16 241.88,180.16 226.25,154.06\" style=\"animation-delay:1.960s\"/><polygon points=\"257.50,206.25 288.75,206.25 273.12,180.16\" style=\"animation-delay:1.995s\"/><polygon points=\"288.75,206.25 320.00,206.25 304.38,180.16\" style=\"animation-delay:2.030s\"/><polygon points=\"273.12,180.16 304.38,180.16 288.75,154.06\" style=\"animation-delay:2.065s\"/><polygon points=\"226.25,154.06 257.50,154.06 241.88,127.97\" style=\"animation-delay:2.100s\"/><polygon points=\"257.50,154.06 288.75,154.06 273.12,127.97\" style=\"animation-delay:2.135s\"/><polygon points=\"241.88,127.97 273.12,127.97 257.50,101.88\" style=\"animation-delay:2.170s\"/><polygon points=\"320.00,206.25 351.25,206.25 335.62,180.16\" style=\"animation-delay:2.205s\"/><polygon points=\"351.25,206.25 382.50,206.25 366.88,180.16\" style=\"animation-delay:2.240s\"/><polygon points=\"335.62,180.16 366.88,180.16 351.25,154.06\" style=\"animation-delay:2.275s\"/><polygon points=\"382.50,206.25 413.75,206.25 398.12,180.16\" style=\"animation-delay:2.310s\"/><polygon points=\"413.75,206.25 445.00,206.25 429.38,180.16\" style=\"animation-delay:2.345s\"/><polygon points=\"398.12,180.16 429.38,180.16 413.75,154.06\" style=\"animation-delay:2.380s\"/><polygon points=\"351.25,154.06 382.50,154.06 366.88,127.97\" style=\"animation-delay:2.415s\"/><polygon points=\"382.50,154.06 413.75,154.06 398.12,127.97\" style=\"animation-delay:2.450s\"/><polygon points=\"366.88,127.97 398.12,127.97 382.50,101.88\" style=\"animation-delay:2.485s\"/><polygon points=\"257.50,101.88 288.75,101.88 273.12,75.78\" style=\"animation-delay:2.520s\"/><polygon points=\"288.75,101.88 320.00,101.88 304.38,75.78\" style=\"animation-delay:2.555s\"/><polygon points=\"273.12,75.78 304.38,75.78 288.75,49.69\" style=\"animation-delay:2.590s\"/><polygon points=\"320.00,101.88 351.25,101.88 335.62,75.78\" style=\"animation-delay:2.625s\"/><polygon points=\"351.25,101.88 382.50,101.88 366.88,75.78\" style=\"animation-delay:2.660s\"/><polygon points=\"335.62,75.78 366.88,75.78 351.25,49.69\" style=\"animation-delay:2.695s\"/><polygon points=\"288.75,49.69 320.00,49.69 304.38,23.59\" style=\"animation-delay:2.730s\"/><polygon points=\"320.00,49.69 351.25,49.69 335.62,23.59\" style=\"animation-delay:2.765s\"/><polygon points=\"304.38,23.59 335.62,23.59 320.00,-2.50\" style=\"animation-delay:2.800s\"/></g></svg>",
            code: "<b>import</b> <m>turtle</m> <b>as</b> <m>t</m>\n\n<em># 谢尔宾斯基三角：把三角形一分为四，挖掉中间那块，对三个角递归</em>\n<m>t</m>.<s>setup</s>(<u>600</u>, <u>520</u>); <m>t</m>.<s>hideturtle</s>(); <m>t</m>.<s>speed</s>(<u>0</u>)\n<m>t</m>.<s>color</s>(<i>\"#00e5ff\"</i>, <i>\"#0b2b38\"</i>)\n\n<b>def</b> <s>mid</s>(p, q):\n    <b>return</b> ((p[<u>0</u>]+q[<u>0</u>])/<u>2</u>, (p[<u>1</u>]+q[<u>1</u>])/<u>2</u>)\n\n<b>def</b> <s>sierpinski</s>(pts, depth):\n    <b>if</b> depth == <u>0</u>:\n        <m>t</m>.<s>penup</s>(); <m>t</m>.<s>goto</s>(pts[<u>0</u>]); <m>t</m>.<s>pendown</s>()\n        <m>t</m>.<s>begin_fill</s>()\n        <b>for</b> p <b>in</b> pts[<u>1</u>:]: <m>t</m>.<s>goto</s>(p)\n        <m>t</m>.<s>goto</s>(pts[<u>0</u>])\n        <m>t</m>.<s>end_fill</s>()\n        <b>return</b>\n    a, b, c = pts\n    <s>sierpinski</s>([a, <s>mid</s>(a,b), <s>mid</s>(a,c)], depth-<u>1</u>)\n    <s>sierpinski</s>([<s>mid</s>(a,b), b, <s>mid</s>(b,c)], depth-<u>1</u>)\n    <s>sierpinski</s>([<s>mid</s>(a,c), <s>mid</s>(b,c), c], depth-<u>1</u>)\n\nR = <u>250</u>\n<s>sierpinski</s>([(-R, -R*<u>0.62</u>), (R, -R*<u>0.62</u>), (<u>0</u>, R*<u>1.05</u>)], <u>4</u>)\n<m>t</m>.<s>done</s>()",
            plain: "import turtle as t\n\n# 谢尔宾斯基三角：把三角形一分为四，挖掉中间那块，对三个角递归\nt.setup(600, 520); t.hideturtle(); t.speed(0)\nt.color(\"#00e5ff\", \"#0b2b38\")\n\ndef mid(p, q):\n    return ((p[0]+q[0])/2, (p[1]+q[1])/2)\n\ndef sierpinski(pts, depth):\n    if depth == 0:\n        t.penup(); t.goto(pts[0]); t.pendown()\n        t.begin_fill()\n        for p in pts[1:]: t.goto(p)\n        t.goto(pts[0])\n        t.end_fill()\n        return\n    a, b, c = pts\n    sierpinski([a, mid(a,b), mid(a,c)], depth-1)\n    sierpinski([mid(a,b), b, mid(b,c)], depth-1)\n    sierpinski([mid(a,c), mid(b,c), c], depth-1)\n\nR = 250\nsierpinski([(-R, -R*0.62), (R, -R*0.62), (0, R*1.05)], 4)\nt.done()"
        }
        ,{
            id: "koch",
            tab: "\u2744 \u79D1\u8D6B\u96EA\u82B1",
            name: "Python \u6D77\u9F9F\u7ED8\u56FE <i>\u00B7 \u79D1\u8D6B\u96EA\u82B1</i>",
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"Python 海龟绘图画出科赫雪花\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><path class=\"nb-ts-path\" d=\"M320.00,55.00L317.81,58.80L320.00,62.59L315.62,62.59L313.42,66.39L315.62,70.19L320.00,70.19L317.81,73.98L320.00,77.78L315.62,77.78L313.42,81.57L311.23,77.78L306.85,77.78L304.66,81.57L306.85,85.37L302.47,85.37L300.27,89.17L302.47,92.96L306.85,92.96L304.66,96.76L306.85,100.56L311.23,100.56L313.42,96.76L315.62,100.56L320.00,100.56L317.81,104.35L320.00,108.15L315.62,108.15L313.42,111.94L315.62,115.74L320.00,115.74L317.81,119.54L320.00,123.33L315.62,123.33L313.42,127.13L311.23,123.33L306.85,123.33L304.66,127.13L306.85,130.93L302.47,130.93L300.27,134.72L298.08,130.93L293.70,130.93L295.89,127.13L293.70,123.33L289.31,123.33L287.12,127.13L284.93,123.33L280.55,123.33L278.36,127.13L280.55,130.93L276.16,130.93L273.97,134.72L276.16,138.52L280.55,138.52L278.36,142.31L280.55,146.11L276.16,146.11L273.97,149.91L271.78,146.11L267.40,146.11L265.21,149.91L267.40,153.70L263.01,153.70L260.82,157.50L263.01,161.30L267.40,161.30L265.21,165.09L267.40,168.89L271.78,168.89L273.97,165.09L276.16,168.89L280.55,168.89L278.36,172.69L280.55,176.48L276.16,176.48L273.97,180.28L276.16,184.07L280.55,184.07L278.36,187.87L280.55,191.67L284.93,191.67L287.12,187.87L289.31,191.67L293.70,191.67L295.89,187.87L293.70,184.07L298.08,184.07L300.27,180.28L302.47,184.07L306.85,184.07L304.66,187.87L306.85,191.67L311.23,191.67L313.42,187.87L315.62,191.67L320.00,191.67L317.81,195.46L320.00,199.26L315.62,199.26L313.42,203.06L315.62,206.85L320.00,206.85L317.81,210.65L320.00,214.44L315.62,214.44L313.42,218.24L311.23,214.44L306.85,214.44L304.66,218.24L306.85,222.04L302.47,222.04L300.27,225.83L302.47,229.63L306.85,229.63L304.66,233.43L306.85,237.22L311.23,237.22L313.42,233.43L315.62,237.22L320.00,237.22L317.81,241.02L320.00,244.81L315.62,244.81L313.42,248.61L315.62,252.41L320.00,252.41L317.81,256.20L320.00,260.00L315.62,260.00L313.42,263.80L311.23,260.00L306.85,260.00L304.66,263.80L306.85,267.59L302.47,267.59L300.27,271.39L298.08,267.59L293.70,267.59L295.89,263.80L293.70,260.00L289.31,260.00L287.12,263.80L284.93,260.00L280.55,260.00L278.36,263.80L280.55,267.59L276.16,267.59L273.97,271.39L276.16,275.19L280.55,275.19L278.36,278.98L280.55,282.78L276.16,282.78L273.97,286.57L271.78,282.78L267.40,282.78L265.21,286.57L267.40,290.37L263.01,290.37L260.82,294.17L258.63,290.37L254.25,290.37L256.44,286.57L254.25,282.78L249.86,282.78L247.67,286.57L245.48,282.78L241.10,282.78L243.29,278.98L241.10,275.19L245.48,275.19L247.67,271.39L245.48,267.59L241.10,267.59L243.29,263.80L241.10,260.00L236.71,260.00L234.52,263.80L232.33,260.00L227.94,260.00L225.75,263.80L227.94,267.59L223.56,267.59L221.37,271.39L219.18,267.59L214.79,267.59L216.99,263.80L214.79,260.00L210.41,260.00L208.22,263.80L206.03,260.00L201.64,260.00L199.45,263.80L201.64,267.59L197.26,267.59L195.07,271.39L197.26,275.19L201.64,275.19L199.45,278.98L201.64,282.78L197.26,282.78L195.07,286.57L192.88,282.78L188.49,282.78L186.30,286.57L188.49,290.37L184.11,290.37L181.92,294.17L184.11,297.96L188.49,297.96L186.30,301.76L188.49,305.56L192.88,305.56L195.07,301.76L197.26,305.56L201.64,305.56L199.45,309.35L201.64,313.15L197.26,313.15L195.07,316.94L197.26,320.74L201.64,320.74L199.45,324.54L201.64,328.33L197.26,328.33L195.07,332.13L192.88,328.33L188.49,328.33L186.30,332.13L188.49,335.93L184.11,335.93L181.92,339.72L179.73,335.93L175.34,335.93L177.53,332.13L175.34,328.33L170.96,328.33L168.77,332.13L166.57,328.33L162.19,328.33L160.00,332.13L162.19,335.93L157.81,335.93L155.62,339.72L157.81,343.52L162.19,343.52L160.00,347.31L162.19,351.11L157.81,351.11L155.62,354.91L153.42,351.11L149.04,351.11L146.85,354.91L149.04,358.70L144.66,358.70L142.46,362.50L146.85,362.50L149.04,358.70L151.23,362.50L155.62,362.50L157.81,358.70L155.62,354.91L160.00,354.91L162.19,351.11L164.38,354.91L168.77,354.91L166.57,358.70L168.77,362.50L173.15,362.50L175.34,358.70L177.53,362.50L181.92,362.50L184.11,358.70L181.92,354.91L186.30,354.91L188.49,351.11L186.30,347.31L181.92,347.31L184.11,343.52L181.92,339.72L186.30,339.72L188.49,335.93L190.68,339.72L195.07,339.72L197.26,335.93L195.07,332.13L199.45,332.13L201.64,328.33L203.83,332.13L208.22,332.13L206.03,335.93L208.22,339.72L212.60,339.72L214.79,335.93L216.99,339.72L221.37,339.72L219.18,343.52L221.37,347.31L216.99,347.31L214.79,351.11L216.99,354.91L221.37,354.91L219.18,358.70L221.37,362.50L225.75,362.50L227.94,358.70L230.14,362.50L234.52,362.50L236.71,358.70L234.52,354.91L238.90,354.91L241.10,351.11L243.29,354.91L247.67,354.91L245.48,358.70L247.67,362.50L252.05,362.50L254.25,358.70L256.44,362.50L260.82,362.50L263.01,358.70L260.82,354.91L265.21,354.91L267.40,351.11L265.21,347.31L260.82,347.31L263.01,343.52L260.82,339.72L265.21,339.72L267.40,335.93L269.59,339.72L273.97,339.72L276.16,335.93L273.97,332.13L278.36,332.13L280.55,328.33L278.36,324.54L273.97,324.54L276.16,320.74L273.97,316.94L269.59,316.94L267.40,320.74L265.21,316.94L260.82,316.94L263.01,313.15L260.82,309.35L265.21,309.35L267.40,305.56L265.21,301.76L260.82,301.76L263.01,297.96L260.82,294.17L265.21,294.17L267.40,290.37L269.59,294.17L273.97,294.17L276.16,290.37L273.97,286.57L278.36,286.57L280.55,282.78L282.74,286.57L287.12,286.57L284.93,290.37L287.12,294.17L291.51,294.17L293.70,290.37L295.89,294.17L300.27,294.17L302.47,290.37L300.27,286.57L304.66,286.57L306.85,282.78L304.66,278.98L300.27,278.98L302.47,275.19L300.27,271.39L304.66,271.39L306.85,267.59L309.04,271.39L313.42,271.39L315.62,267.59L313.42,263.80L317.81,263.80L320.00,260.00L322.19,263.80L326.58,263.80L324.38,267.59L326.58,271.39L330.96,271.39L333.15,267.59L335.34,271.39L339.73,271.39L337.53,275.19L339.73,278.98L335.34,278.98L333.15,282.78L335.34,286.57L339.73,286.57L337.53,290.37L339.73,294.17L344.11,294.17L346.30,290.37L348.49,294.17L352.88,294.17L355.07,290.37L352.88,286.57L357.26,286.57L359.45,282.78L361.64,286.57L366.03,286.57L363.84,290.37L366.03,294.17L370.41,294.17L372.60,290.37L374.79,294.17L379.18,294.17L376.99,297.96L379.18,301.76L374.79,301.76L372.60,305.56L374.79,309.35L379.18,309.35L376.99,313.15L379.18,316.94L374.79,316.94L372.60,320.74L370.41,316.94L366.03,316.94L363.84,320.74L366.03,324.54L361.64,324.54L359.45,328.33L361.64,332.13L366.03,332.13L363.84,335.93L366.03,339.72L370.41,339.72L372.60,335.93L374.79,339.72L379.18,339.72L376.99,343.52L379.18,347.31L374.79,347.31L372.60,351.11L374.79,354.91L379.18,354.91L376.99,358.70L379.18,362.50L383.56,362.50L385.75,358.70L387.95,362.50L392.33,362.50L394.52,358.70L392.33,354.91L396.71,354.91L398.90,351.11L401.10,354.91L405.48,354.91L403.29,358.70L405.48,362.50L409.86,362.50L412.06,358.70L414.25,362.50L418.63,362.50L420.82,358.70L418.63,354.91L423.01,354.91L425.21,351.11L423.01,347.31L418.63,347.31L420.82,343.52L418.63,339.72L423.01,339.72L425.21,335.93L427.40,339.72L431.78,339.72L433.97,335.93L431.78,332.13L436.17,332.13L438.36,328.33L440.55,332.13L444.93,332.13L442.74,335.93L444.93,339.72L449.32,339.72L451.51,335.93L453.70,339.72L458.08,339.72L455.89,343.52L458.08,347.31L453.70,347.31L451.51,351.11L453.70,354.91L458.08,354.91L455.89,358.70L458.08,362.50L462.47,362.50L464.66,358.70L466.85,362.50L471.23,362.50L473.43,358.70L471.23,354.91L475.62,354.91L477.81,351.11L480.00,354.91L484.38,354.91L482.19,358.70L484.38,362.50L488.77,362.50L490.96,358.70L493.15,362.50L497.54,362.50L495.34,358.70L490.96,358.70L493.15,354.91L490.96,351.11L486.58,351.11L484.38,354.91L482.19,351.11L477.81,351.11L480.00,347.31L477.81,343.52L482.19,343.52L484.38,339.72L482.19,335.93L477.81,335.93L480.00,332.13L477.81,328.33L473.43,328.33L471.23,332.13L469.04,328.33L464.66,328.33L462.47,332.13L464.66,335.93L460.27,335.93L458.08,339.72L455.89,335.93L451.51,335.93L453.70,332.13L451.51,328.33L447.12,328.33L444.93,332.13L442.74,328.33L438.36,328.33L440.55,324.54L438.36,320.74L442.74,320.74L444.93,316.94L442.74,313.15L438.36,313.15L440.55,309.35L438.36,305.56L442.74,305.56L444.93,301.76L447.12,305.56L451.51,305.56L453.70,301.76L451.51,297.96L455.89,297.96L458.08,294.17L455.89,290.37L451.51,290.37L453.70,286.57L451.51,282.78L447.12,282.78L444.93,286.57L442.74,282.78L438.36,282.78L440.55,278.98L438.36,275.19L442.74,275.19L444.93,271.39L442.74,267.59L438.36,267.59L440.55,263.80L438.36,260.00L433.97,260.00L431.78,263.80L429.59,260.00L425.21,260.00L423.01,263.80L425.21,267.59L420.82,267.59L418.63,271.39L416.44,267.59L412.06,267.59L414.25,263.80L412.06,260.00L407.67,260.00L405.48,263.80L403.29,260.00L398.90,260.00L396.71,263.80L398.90,267.59L394.52,267.59L392.33,271.39L394.52,275.19L398.90,275.19L396.71,278.98L398.90,282.78L394.52,282.78L392.33,286.57L390.14,282.78L385.75,282.78L383.56,286.57L385.75,290.37L381.37,290.37L379.18,294.17L376.99,290.37L372.60,290.37L374.79,286.57L372.60,282.78L368.22,282.78L366.03,286.57L363.84,282.78L359.45,282.78L361.64,278.98L359.45,275.19L363.84,275.19L366.03,271.39L363.84,267.59L359.45,267.59L361.64,263.80L359.45,260.00L355.07,260.00L352.88,263.80L350.69,260.00L346.30,260.00L344.11,263.80L346.30,267.59L341.92,267.59L339.73,271.39L337.53,267.59L333.15,267.59L335.34,263.80L333.15,260.00L328.77,260.00L326.58,263.80L324.38,260.00L320.00,260.00L322.19,256.20L320.00,252.41L324.38,252.41L326.58,248.61L324.38,244.81L320.00,244.81L322.19,241.02L320.00,237.22L324.38,237.22L326.58,233.43L328.77,237.22L333.15,237.22L335.34,233.43L333.15,229.63L337.53,229.63L339.73,225.83L337.53,222.04L333.15,222.04L335.34,218.24L333.15,214.44L328.77,214.44L326.58,218.24L324.38,214.44L320.00,214.44L322.19,210.65L320.00,206.85L324.38,206.85L326.58,203.06L324.38,199.26L320.00,199.26L322.19,195.46L320.00,191.67L324.38,191.67L326.58,187.87L328.77,191.67L333.15,191.67L335.34,187.87L333.15,184.07L337.53,184.07L339.73,180.28L341.92,184.07L346.30,184.07L344.11,187.87L346.30,191.67L350.69,191.67L352.88,187.87L355.07,191.67L359.45,191.67L361.64,187.87L359.45,184.07L363.84,184.07L366.03,180.28L363.84,176.48L359.45,176.48L361.64,172.69L359.45,168.89L363.84,168.89L366.03,165.09L368.22,168.89L372.60,168.89L374.79,165.09L372.60,161.30L376.99,161.30L379.18,157.50L376.99,153.70L372.60,153.70L374.79,149.91L372.60,146.11L368.22,146.11L366.03,149.91L363.84,146.11L359.45,146.11L361.64,142.31L359.45,138.52L363.84,138.52L366.03,134.72L363.84,130.93L359.45,130.93L361.64,127.13L359.45,123.33L355.07,123.33L352.88,127.13L350.69,123.33L346.30,123.33L344.11,127.13L346.30,130.93L341.92,130.93L339.73,134.72L337.53,130.93L333.15,130.93L335.34,127.13L333.15,123.33L328.77,123.33L326.58,127.13L324.38,123.33L320.00,123.33L322.19,119.54L320.00,115.74L324.38,115.74L326.58,111.94L324.38,108.15L320.00,108.15L322.19,104.35L320.00,100.56L324.38,100.56L326.58,96.76L328.77,100.56L333.15,100.56L335.34,96.76L333.15,92.96L337.53,92.96L339.73,89.17L337.53,85.37L333.15,85.37L335.34,81.57L333.15,77.78L328.77,77.78L326.58,81.57L324.38,77.78L320.00,77.78L322.19,73.98L320.00,70.19L324.38,70.19L326.58,66.39L324.38,62.59L320.00,62.59L322.19,58.80L320.00,55.00\" style=\"--len:3366.6\"/></svg>",
            code: "<b>import</b> <m>turtle</m> <b>as</b> <m>t</m>, <m>math</m>\n\n<em># 科赫雪花：把每条边三等分，中间那段换成凸起的等边三角形，然后递归</em>\n<m>t</m>.<s>setup</s>(<u>600</u>, <u>520</u>); <m>t</m>.<s>hideturtle</s>(); <m>t</m>.<s>speed</s>(<u>0</u>)\n<m>t</m>.<s>color</s>(<i>\"#00e5ff\"</i>); <m>t</m>.<s>pensize</s>(<u>2</u>)\n\n<b>def</b> <s>koch</s>(p, q, depth):\n    <em>\"\"\"把线段 pq 递归细分成科赫曲线，边算边画\"\"\"</em>\n    <b>if</b> depth == <u>0</u>:\n        <m>t</m>.<s>goto</s>(q); <b>return</b>\n    dx, dy = (q[<u>0</u>]-p[<u>0</u>])/<u>3</u>, (q[<u>1</u>]-p[<u>1</u>])/<u>3</u>\n    a = (p[<u>0</u>]+dx, p[<u>1</u>]+dy)                <em># 三等分点</em>\n    c = (p[<u>0</u>]+<u>2</u>*dx, p[<u>1</u>]+<u>2</u>*dy)\n    ang = <m>math</m>.<s>radians</s>(<u>60</u>)\n    b = (a[<u>0</u>]+dx*<m>math</m>.<s>cos</s>(ang)-dy*<m>math</m>.<s>sin</s>(ang),\n         a[<u>1</u>]+dx*<m>math</m>.<s>sin</s>(ang)+dy*<m>math</m>.<s>cos</s>(ang))  <em># 凸起顶点</em>\n    <s>koch</s>(p, a, depth-<u>1</u>); <s>koch</s>(a, b, depth-<u>1</u>)\n    <s>koch</s>(b, c, depth-<u>1</u>); <s>koch</s>(c, q, depth-<u>1</u>)\n\nR = <u>205</u>\nP = [(R*<m>math</m>.<s>cos</s>(<m>math</m>.<s>radians</s>(<u>90</u>+i*<u>120</u>)),\n      R*<m>math</m>.<s>sin</s>(<m>math</m>.<s>radians</s>(<u>90</u>+i*<u>120</u>))) <b>for</b> i <b>in</b> <s>range</s>(<u>3</u>)]\n<m>t</m>.<s>penup</s>(); <m>t</m>.<s>goto</s>(P[<u>0</u>]); <m>t</m>.<s>pendown</s>()\n<b>for</b> i <b>in</b> <s>range</s>(<u>3</u>):\n    <s>koch</s>(P[i], P[(i+<u>1</u>)%<u>3</u>], <u>4</u>)          <em># 三条边各一条科赫曲线</em>\n<m>t</m>.<s>done</s>()",
            plain: "import turtle as t, math\n\n# 科赫雪花：把每条边三等分，中间那段换成凸起的等边三角形，然后递归\nt.setup(600, 520); t.hideturtle(); t.speed(0)\nt.color(\"#00e5ff\"); t.pensize(2)\n\ndef koch(p, q, depth):\n    \"\"\"把线段 pq 递归细分成科赫曲线，边算边画\"\"\"\n    if depth == 0:\n        t.goto(q); return\n    dx, dy = (q[0]-p[0])/3, (q[1]-p[1])/3\n    a = (p[0]+dx, p[1]+dy)                # 三等分点\n    c = (p[0]+2*dx, p[1]+2*dy)\n    ang = math.radians(60)\n    b = (a[0]+dx*math.cos(ang)-dy*math.sin(ang),\n         a[1]+dx*math.sin(ang)+dy*math.cos(ang))  # 凸起顶点\n    koch(p, a, depth-1); koch(a, b, depth-1)\n    koch(b, c, depth-1); koch(c, q, depth-1)\n\nR = 205\nP = [(R*math.cos(math.radians(90+i*120)),\n      R*math.sin(math.radians(90+i*120))) for i in range(3)]\nt.penup(); t.goto(P[0]); t.pendown()\nfor i in range(3):\n    koch(P[i], P[(i+1)%3], 4)          # 三条边各一条科赫曲线\nt.done()"
        }
        ,{
            id: "spiral",
            tab: "\uD83C\uDF00 \u9EC4\u91D1\u87BA\u65CB",
            name: "\u9EC4\u91D1\u87BA\u65CB <i>\u00B7 \u542B\u6590\u6CE2\u90A3\u5951\u6B63\u65B9\u5F62\u8F85\u52A9\u7EBF</i>",
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"Python 海龟绘图画出黄金螺旋，附斐波那契正方形辅助线\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><g class=\"nb-ts-sq\"><path d=\"M201.82,193.82L211.27,193.82L211.27,184.36L201.82,184.36Z\" style=\"animation-delay:0.00s\"/><path d=\"M211.27,184.36L211.27,174.91L201.82,174.91L201.82,184.36Z\" style=\"animation-delay:0.13s\"/><path d=\"M201.82,174.91L182.91,174.91L182.91,193.82L201.82,193.82Z\" style=\"animation-delay:0.26s\"/><path d=\"M182.91,193.82L182.91,222.18L211.27,222.18L211.27,193.82Z\" style=\"animation-delay:0.39s\"/><path d=\"M211.27,222.18L258.55,222.18L258.55,174.91L211.27,174.91Z\" style=\"animation-delay:0.52s\"/><path d=\"M258.55,174.91L258.55,99.27L182.91,99.27L182.91,174.91Z\" style=\"animation-delay:0.65s\"/><path d=\"M182.91,99.27L60.00,99.27L60.00,222.18L182.91,222.18Z\" style=\"animation-delay:0.78s\"/><path d=\"M60.00,222.18L60.00,420.73L258.55,420.73L258.55,222.18Z\" style=\"animation-delay:0.91s\"/><path d=\"M258.55,420.73L580.00,420.73L580.00,99.27L258.55,99.27Z\" style=\"animation-delay:1.04s\"/></g><g class=\"nb-ts-spiral\"><path d=\"M201.82,193.82L202.81,193.77L203.78,193.61L204.74,193.36L205.66,193.00L206.55,192.55L207.38,192.01L208.14,191.39L208.84,190.69L209.47,189.92L210.01,189.09L210.46,188.21L210.81,187.29L211.07,186.33L211.22,185.35L211.27,184.36\" style=\"--len:14.8;animation-delay:0.00s\"/><path d=\"M211.27,184.36L211.22,183.38L211.07,182.40L210.81,181.44L210.46,180.52L210.01,179.64L209.47,178.81L208.84,178.04L208.14,177.34L207.38,176.71L206.55,176.18L205.66,175.73L204.74,175.37L203.78,175.12L202.81,174.96L201.82,174.91\" style=\"--len:14.8;animation-delay:0.16s\"/><path d=\"M201.82,174.91L200.07,174.99L198.34,175.23L196.64,175.63L194.99,176.19L193.39,176.89L191.86,177.74L190.42,178.73L189.08,179.84L187.84,181.08L186.73,182.42L185.74,183.86L184.89,185.39L184.19,186.99L183.63,188.64L183.23,190.34L182.99,192.07L182.91,193.82\" style=\"--len:29.7;animation-delay:0.32s\"/><path d=\"M182.91,193.82L183.02,196.29L183.34,198.74L183.88,201.16L184.62,203.52L185.57,205.81L186.71,208.00L188.04,210.09L189.54,212.05L191.22,213.87L193.04,215.55L195.00,217.05L197.09,218.38L199.29,219.52L201.57,220.47L203.93,221.22L206.35,221.75L208.80,222.07L211.27,222.18\" style=\"--len:44.5;animation-delay:0.48s\"/><path d=\"M211.27,222.18L214.65,222.06L218.00,221.70L221.32,221.10L224.59,220.27L227.79,219.20L230.91,217.91L233.93,216.40L236.83,214.68L239.60,212.75L242.23,210.64L244.70,208.34L247.00,205.87L249.12,203.24L251.04,200.47L252.76,197.56L254.27,194.55L255.56,191.43L256.63,188.23L257.47,184.96L258.06,181.64L258.43,178.28L258.55,174.91\" style=\"--len:74.2;animation-delay:0.64s\"/><path d=\"M258.55,174.91L258.41,170.34L257.99,165.79L257.31,161.28L256.35,156.81L255.12,152.41L253.63,148.09L251.88,143.87L249.88,139.76L247.64,135.78L245.16,131.94L242.45,128.26L239.52,124.75L236.39,121.43L233.07,118.29L229.56,115.37L225.88,112.66L222.04,110.18L218.06,107.94L213.95,105.94L209.73,104.19L205.41,102.70L201.01,101.47L196.54,100.51L192.03,99.82L187.48,99.41L182.91,99.27\" style=\"--len:118.8;animation-delay:0.80s\"/><path d=\"M182.91,99.27L177.23,99.40L171.57,99.80L165.93,100.45L160.32,101.37L154.77,102.54L149.27,103.96L143.85,105.64L138.51,107.57L133.26,109.75L128.12,112.16L123.10,114.81L118.21,117.68L113.45,120.78L108.84,124.10L104.39,127.62L100.11,131.35L96.00,135.27L92.08,139.38L88.35,143.66L84.83,148.11L81.51,152.72L78.41,157.48L75.53,162.37L72.89,167.40L70.47,172.54L68.30,177.78L66.37,183.12L64.69,188.55L63.26,194.04L62.09,199.60L61.18,205.20L60.52,210.84L60.13,216.51L60.00,222.18\" style=\"--len:193.0;animation-delay:0.96s\"/><path d=\"M60.00,222.18L60.11,228.82L60.44,235.44L61.00,242.06L61.77,248.65L62.77,255.21L63.98,261.73L65.41,268.21L67.05,274.64L68.91,281.01L70.99,287.31L73.27,293.54L75.75,299.69L78.45,305.76L81.34,311.73L84.43,317.60L87.72,323.36L91.19,329.02L94.86,334.55L98.70,339.95L102.73,345.23L106.93,350.37L111.29,355.36L115.83,360.21L120.52,364.90L125.36,369.43L130.36,373.80L135.50,378.00L140.77,382.02L146.18,385.87L151.71,389.53L157.36,393.01L163.13,396.30L169.00,399.39L174.97,402.28L181.04,404.97L187.19,407.46L193.42,409.74L199.72,411.81L206.09,413.67L212.52,415.32L219.00,416.75L225.52,417.96L232.08,418.96L238.67,419.73L245.28,420.28L251.91,420.62L258.55,420.73\" style=\"--len:311.9;animation-delay:1.12s\"/><path d=\"M258.55,420.73L265.97,420.64L273.39,420.38L280.80,419.96L288.21,419.36L295.59,418.59L302.96,417.64L310.30,416.53L317.61,415.25L324.90,413.81L332.14,412.19L339.35,410.41L346.52,408.46L353.63,406.34L360.70,404.06L367.71,401.62L374.67,399.02L381.56,396.26L388.39,393.34L395.15,390.26L401.83,387.03L408.44,383.64L414.97,380.10L421.41,376.41L427.77,372.58L434.04,368.60L440.21,364.47L446.29,360.21L452.27,355.80L458.14,351.26L463.91,346.58L469.56,341.77L475.11,336.83L480.54,331.76L485.85,326.58L491.04,321.26L496.10,315.84L501.04,310.29L505.85,304.63L510.53,298.87L515.07,292.99L519.48,287.02L523.74,280.94L527.87,274.76L531.85,268.50L535.69,262.14L539.38,255.69L542.91,249.17L546.30,242.56L549.53,235.87L552.61,229.11L555.53,222.29L558.29,215.40L560.90,208.44L563.34,201.43L565.61,194.36L567.73,187.24L569.68,180.08L571.46,172.87L573.08,165.62L574.53,158.34L575.81,151.03L576.92,143.68L577.86,136.32L578.63,128.93L579.23,121.53L579.66,114.12L579.91,106.70L580.00,99.27\" style=\"--len:504.9;animation-delay:1.28s\"/></g><g class=\"nb-ts-num\"><text x=\"197.1\" y=\"212.0\" style=\"animation-delay:0.39s\">3</text><text x=\"234.9\" y=\"202.5\" style=\"animation-delay:0.52s\">5</text><text x=\"220.7\" y=\"141.1\" style=\"animation-delay:0.65s\">8</text><text x=\"121.5\" y=\"164.7\" style=\"animation-delay:0.78s\">13</text><text x=\"159.3\" y=\"325.5\" style=\"animation-delay:0.91s\">21</text><text x=\"419.3\" y=\"264.0\" style=\"animation-delay:1.04s\">34</text></g></svg>",
            code: "<m>import</b> <m>turtle</b> <b>as</b> <m>t</b>\n\n<em># 黄金螺旋 = 斐波那契正方形 + 每格里的 1/4 圆弧</b>\n<em># 关键：正方形和圆弧都【左转】（逆时针）。</b>\n<em>#       圆弧的圆心落在正方形的角上，所以正方形要画在圆心那一侧；</b>\n<em>#       右转画出来的正方形会跑到反面，和弧错开一格。</b>\n<m>t</b>.<s>setup</b>(<u>640</b>, <u>520</b>); <m>t</b>.<s>hideturtle</b>(); <m>t</b>.<s>speed</b>(<u>0</b>)\n\n<em># 斐波那契：1 1 2 3 5 8 13 21 34</b>\nfib = [<u>1</b>, <u>1</b>]\n<b>for</b> _ <b>in</b> <s>range</b>(<u>7</b>):\n    fib.<s>append</b>(fib[-<u>1</b>] + fib[-<u>2</b>])\n\nSCALE = <u>14</b>\n<m>t</b>.<s>penup</b>(); <m>t</b>.<s>goto</b>(<u>0</b>, <u>0</b>); <m>t</b>.<s>pendown</b>()\n\n<b>for</b> s <b>in</b> fib:\n    L = s * SCALE\n    <em># ① 辅助线：正方形，左转绕一圈（画完海龟回到原点、朝向不变）</b>\n    <m>t</b>.<s>pensize</b>(<u>1</b>); <m>t</b>.<s>color</b>(<i>\"#1b4a5a\"</b>)\n    <b>for</b> _ <b>in</b> <s>range</b>(<u>4</b>):\n        <m>t</b>.<s>forward</b>(L); <m>t</b>.<s>left</b>(<u>90</b>)\n    <em># ② 螺旋：从同一点出发，逆时针扫 1/4 圈</b>\n    <m>t</b>.<s>pensize</b>(<u>2</b>); <m>t</b>.<s>color</b>(<i>\"#00e5ff\"</b>)\n    <m>t</b>.<s>circle</b>(L, <u>90</b>)\n<m>t</b>.<s>done</b>()",
            plain: "import turtle as t\n\n# 黄金螺旋 = 斐波那契正方形 + 每格里的 1/4 圆弧\n# 关键：正方形和圆弧都【左转】（逆时针）。\n#       圆弧的圆心落在正方形的角上，所以正方形要画在圆心那一侧；\n#       右转画出来的正方形会跑到反面，和弧错开一格。\nt.setup(640, 520); t.hideturtle(); t.speed(0)\n\n# 斐波那契：1 1 2 3 5 8 13 21 34\nfib = [1, 1]\nfor _ in range(7):\n    fib.append(fib[-1] + fib[-2])\n\nSCALE = 14\nt.penup(); t.goto(0, 0); t.pendown()\n\nfor s in fib:\n    L = s * SCALE\n    # ① 辅助线：正方形，左转绕一圈（画完海龟回到原点、朝向不变）\n    t.pensize(1); t.color(\"#1b4a5a\")\n    for _ in range(4):\n        t.forward(L); t.left(90)\n    # ② 螺旋：从同一点出发，逆时针扫 1/4 圈\n    t.pensize(2); t.color(\"#00e5ff\")\n    t.circle(L, 90)\nt.done()"
        }
        ,{
            id: "term",
            tab: "\u25B6 \u7EC8\u7AEF",
            name: "\u4EA4\u4E92\u5F0F\u7EC8\u7AEF <i>\u00B7 \u81EA\u5DF1\u6572\u547D\u4EE4\u8BD5\u8BD5</i>",
            html: "<div class=\"nb-ts-term\"><div class=\"nb-ts-term-bar\"><i style=\"background:#ff5f57\"></i><i style=\"background:#febc2e\"></i><i style=\"background:#28c840\"></i><span class=\"t\">nb@channel: ~ &mdash; 试试敲 help</span></div><div class=\"nb-ts-term-body\" data-term></div><div class=\"nb-ts-thint\">↑ ↓ 翻历史　·　Tab 补全　·　输入 help 看全部命令</div></div>",
            code: "<m>import</b> <m>time</b>, <m>sys</b>, <m>random</b>, <m>datetime</b>\n\n<em># 一个能真的敲命令的终端。每条命令对应下面 COMMANDS 里的一个函数。</b>\nNB = {\n    <i>\"name\"</b>:  <i>\"NB频道 · NoBook Channel\"</b>,\n    <i>\"fans\"</b>:  <u>112363</b>,\n    <i>\"days\"</b>:  <u>213</b>,\n    <i>\"motto\"</b>: <i>\"热爱理科，与作死同行\"</b>,\n}\n\n<b>def</b> <s>c_whoami</b>(_):\n    <b>return</b> NB[<i>\"name\"</b>]\n\n<b>def</b> <s>c_uptime</b>(_):\n    <b>return</b> <i>\"已运行 %d 天 · 粉丝 %s\"</b> % (NB[<i>\"days\"</b>], <s>f</b>+{NB[<i>\"fans\"</b>]:,})\n\n<b>def</b> <s>c_fans</b>(_):\n    <b>return</b> <i>\"B站粉丝：%s\"</b> % <s>f</b>+{NB[<i>\"fans\"</b>]:,}</b>\n\n<b>def</b> <s>c_motto</b>(_):\n    <b>return</b> NB[<i>\"motto\"</b>]\n\n<b>def</b> <s>c_fortune</b>(_):\n    <b>return</b> <m>random</b>.<s>choice</b>(<i>\"化学考试不会的就选 C\"</b>, <i>\"别忘了签到\"</b>)\n\n<b>def</b> <s>c_date</b>(_):\n    <b>return</b> <m>datetime</b>.<s>datetime</b>.<s>now</b>().<s>strftime</b>(<i>\"%Y-%m-%d %H:%M:%S\"</b>)\n\nCOMMANDS = {\n    <i>\"whoami\"</b>: <s>c_whoami</b>,  <i>\"uptime\"</b>: <s>c_uptime</b>,\n    <i>\"nb fans\"</b>: <s>c_fans</b>,   <i>\"nb motto\"</b>: <s>c_motto</b>,\n    <i>\"fortune\"</b>: <s>c_fortune</b>, <i>\"date\"</b>: <s>c_date</b>,\n}\n\n<em># 主循环：读一行、找命令、打印结果</b>\n<b>while</b> <b>True</b>:\n    line = <m>input</b>(<i>\"$ \"</b>).<s>strip</b>()\n    <b>if</b> line <b>in</b> (<i>\"\"</b>, <i>\"exit\"</b>):\n        <b>break</b>\n    fn = COMMANDS.<s>get</b>(line)\n    <b>if</b> fn:\n        <s>type_out</b>(fn(line))\n    <b>else</b>:\n        <s>type_out</b>(<i>\"command not found: \"+</b>line)",
            plain: "import time, sys, random, datetime\n\n# 一个能真的敲命令的终端。每条命令对应下面 COMMANDS 里的一个函数。\nNB = {\n    \"name\":  \"NB频道 · NoBook Channel\",\n    \"fans\":  112363,\n    \"days\":  213,\n    \"motto\": \"热爱理科，与作死同行\",\n}\n\ndef c_whoami(_):\n    return NB[\"name\"]\n\ndef c_uptime(_):\n    return \"已运行 %d 天 · 粉丝 %s\" % (NB[\"days\"], f+{NB[\"fans\"]:,})\n\ndef c_fans(_):\n    return \"B站粉丝：%s\" % f+{NB[\"fans\"]:,}\n\ndef c_motto(_):\n    return NB[\"motto\"]\n\ndef c_fortune(_):\n    return random.choice(\"化学考试不会的就选 C\", \"别忘了签到\")\n\ndef c_date(_):\n    return datetime.datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")\n\nCOMMANDS = {\n    \"whoami\": c_whoami,  \"uptime\": c_uptime,\n    \"nb fans\": c_fans,   \"nb motto\": c_motto,\n    \"fortune\": c_fortune, \"date\": c_date,\n}\n\n# 主循环：读一行、找命令、打印结果\nwhile True:\n    line = input(\"$ \").strip()\n    if line in (\"\", \"exit\"):\n        break\n    fn = COMMANDS.get(line)\n    if fn:\n        type_out(fn(line))\n    else:\n        type_out(\"command not found: \"+line)",
            init: initTerminal
        }
        ,{
            id: "data",
            tab: "\uD83D\uDCCA \u5B9E\u65F6\u6570\u636E",
            name: "\u8BBF\u95EE\u91CF\u8D70\u52BF <i>\u00B7 \u6700\u8FD1 30 \u5929</i>",
            svg: "<svg class=\"nb-ts-svg\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 640 520\" width=\"640\" height=\"520\" role=\"img\" aria-label=\"网站访问量走势面板\"><rect width=\"640\" height=\"520\" fill=\"#060a14\" rx=\"12\"/><rect width=\"640\" height=\"520\" fill=\"url(#nbTsGrid)\" rx=\"12\"/><defs><linearGradient id=\"nbTsArea\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#00e5ff\" stop-opacity=\"0.34\"/><stop offset=\"1\" stop-color=\"#00e5ff\" stop-opacity=\"0\"/></linearGradient></defs><line x1=\"56.0\" y1=\"468.0\" x2=\"612.0\" y2=\"468.0\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"471.5\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">72</text><line x1=\"56.0\" y1=\"364.5\" x2=\"612.0\" y2=\"364.5\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"368.0\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">99</text><line x1=\"56.0\" y1=\"261.0\" x2=\"612.0\" y2=\"261.0\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"264.5\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">125</text><line x1=\"56.0\" y1=\"157.5\" x2=\"612.0\" y2=\"157.5\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"161.0\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">152</text><line x1=\"56.0\" y1=\"54.0\" x2=\"612.0\" y2=\"54.0\" stroke=\"rgba(0,229,255,.11)\" stroke-width=\"1\"/><text x=\"46.0\" y=\"57.5\" fill=\"rgba(140,200,235,.5)\" font-size=\"10.5\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">179</text><path d=\"M56.00,396.19L75.17,354.41L94.34,332.99L113.52,329.04L132.69,335.00L151.86,341.65L171.03,341.57L190.21,331.71L209.38,314.49L228.55,296.69L247.72,286.83L266.90,291.79L286.07,313.91L305.24,349.55L324.41,389.71L343.59,422.49L362.76,436.69L381.93,425.27L401.10,387.64L420.28,329.94L439.45,263.24L458.62,200.24L477.79,151.56L496.97,122.77L516.14,113.16L535.31,116.58L554.48,124.01L573.66,126.99L592.83,120.68L612.00,105.54L612.00,468.00L56.00,468.00Z\" fill=\"url(#nbTsArea)\" class=\"nb-ts-area\"/><path d=\"M56.00,396.19L75.17,354.41L94.34,332.99L113.52,329.04L132.69,335.00L151.86,341.65L171.03,341.57L190.21,331.71L209.38,314.49L228.55,296.69L247.72,286.83L266.90,291.79L286.07,313.91L305.24,349.55L324.41,389.71L343.59,422.49L362.76,436.69L381.93,425.27L401.10,387.64L420.28,329.94L439.45,263.24L458.62,200.24L477.79,151.56L496.97,122.77L516.14,113.16L535.31,116.58L554.48,124.01L573.66,126.99L592.83,120.68L612.00,105.54\" class=\"nb-ts-chart\" style=\"--len:917.8\"/><circle class=\"nb-ts-pt\" cx=\"56.0\" cy=\"396.2\" r=\"3\" style=\"animation-delay:0.90s\"/><circle class=\"nb-ts-pt\" cx=\"151.9\" cy=\"341.7\" r=\"3\" style=\"animation-delay:1.12s\"/><circle class=\"nb-ts-pt\" cx=\"247.7\" cy=\"286.8\" r=\"3\" style=\"animation-delay:1.35s\"/><circle class=\"nb-ts-pt\" cx=\"343.6\" cy=\"422.5\" r=\"3\" style=\"animation-delay:1.57s\"/><circle class=\"nb-ts-pt\" cx=\"439.4\" cy=\"263.2\" r=\"3\" style=\"animation-delay:1.80s\"/><circle class=\"nb-ts-pt\" cx=\"535.3\" cy=\"116.6\" r=\"3\" style=\"animation-delay:2.02s\"/><circle class=\"nb-ts-pt\" cx=\"612.0\" cy=\"105.5\" r=\"3\" style=\"animation-delay:2.21s\"/><text x=\"56.0\" y=\"34\" fill=\"#7fe3ff\" font-size=\"12.5\" font-family=\"ui-monospace,Consolas,monospace\">visits / last 30 days</text><text class=\"nb-ts-pulse\" x=\"616.0\" y=\"95.5\" fill=\"#7fe3ff\" font-size=\"12\" text-anchor=\"end\" font-family=\"ui-monospace,Consolas,monospace\">165</text></svg>",
            code: "<b>import</b> <m>matplotlib</m>.<m>pyplot</m> <b>as</b> <m>plt</m>\n<b>import</b> <m>math</m>\n\n<em># 把最近 30 天的访问量画成折线图</em>\n<em># 真实项目里这一行换成读数据库：SELECT day, visits FROM stats</em>\ndays = <u>30</u>\nvisits = [<u>78</u> + i*<u>2.6</u> + <u>26</u>*<m>math</m>.<s>sin</s>(i/<u>3.4</u>) + <u>14</u>*<m>math</m>.<s>sin</s>(i/<u>1.7</u> + <u>1.2</u>)\n          <b>for</b> i <b>in</b> <s>range</s>(days)]\n\n<m>plt</m>.<s>style</s>.<s>use</s>(<i>\"dark_background\"</i>)\nfig, ax = <m>plt</m>.<s>subplots</s>(figsize=(<u>6.4</u>, <u>5.2</u>), dpi=<u>100</u>)\n\n<em># 折线 + 面积填充</em>\nax.<s>plot</s>(<s>range</s>(days), visits, color=<i>\"#00e5ff\"</i>, linewidth=<u>2</u>)\nax.<s>fill_between</s>(<s>range</s>(days), visits, color=<i>\"#00e5ff\"</i>, alpha=<u>0.15</u>)\n\n<em># 每 5 天标一个点</em>\nidx = <s>list</s>(<s>range</s>(<u>0</u>, days, <u>5</u>))\nax.<s>scatter</s>(idx, [visits[i] <b>for</b> i <b>in</b> idx], color=<i>\"#7fe3ff\"</i>, s=<u>26</u>, zorder=<u>3</u>)\n\nax.<s>set_title</s>(<i>\"visits / last 30 days\"</i>, loc=<i>\"left\"</i>, color=<i>\"#7fe3ff\"</i>)\nax.<s>grid</s>(alpha=<u>0.12</u>, color=<i>\"#00e5ff\"</i>)\nfig.<s>tight_layout</s>()\n<m>plt</m>.<s>show</s>()",
            plain: "import matplotlib.pyplot as plt\nimport math\n\n# 把最近 30 天的访问量画成折线图\n# 真实项目里这一行换成读数据库：SELECT day, visits FROM stats\ndays = 30\nvisits = [78 + i*2.6 + 26*math.sin(i/3.4) + 14*math.sin(i/1.7 + 1.2)\n          for i in range(days)]\n\nplt.style.use(\"dark_background\")\nfig, ax = plt.subplots(figsize=(6.4, 5.2), dpi=100)\n\n# 折线 + 面积填充\nax.plot(range(days), visits, color=\"#00e5ff\", linewidth=2)\nax.fill_between(range(days), visits, color=\"#00e5ff\", alpha=0.15)\n\n# 每 5 天标一个点\nidx = list(range(0, days, 5))\nax.scatter(idx, [visits[i] for i in idx], color=\"#7fe3ff\", s=26, zorder=3)\n\nax.set_title(\"visits / last 30 days\", loc=\"left\", color=\"#7fe3ff\")\nax.grid(alpha=0.12, color=\"#00e5ff\")\nfig.tight_layout()\nplt.show()"
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
            hsp.textContent = '\uD83D\uDCCB Python \u6E90\u7801';
            var copyBtn = document.createElement('button');
            copyBtn.type = 'button';
            copyBtn.className = 'nb-ts-mini';
            copyBtn.textContent = '\u590D\u5236';
            var toggleBtn = document.createElement('button');
            toggleBtn.type = 'button';
            toggleBtn.className = 'nb-ts-mini';
            toggleBtn.textContent = '\u5C55\u5F00 \u25BE';
            head.appendChild(hsp);
            head.appendChild(copyBtn);
            head.appendChild(toggleBtn);
            var pre = document.createElement('pre');
            pre.className = 'nb-ts-code';
            wrap.appendChild(head);
            wrap.appendChild(pre);
            right.appendChild(wrap);

            row.appendChild(left);
            row.appendChild(right);

            var scroll = host.querySelector ? host.querySelector('.hero-scroll, .vhero-fade') : null;
            if (scroll && scroll.parentNode === host) host.insertBefore(row, scroll);
            else host.insertBefore(row, inner.nextSibling);

            /* ---------- 渲染某个内容 ---------- */
            var cur = null;
            function render(it) {
                cur = it;
                title.innerHTML = it.name;
                /* 内容可以是 svg（图形）也可以是 html（比如可交互的终端） */
                svgBox.innerHTML = it.html || it.svg;
                if (typeof it.init === 'function') it.init(svgBox);
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

            toggleBtn.onclick = function () {
                var on = wrap.classList.toggle('open');
                if (on) pre.innerHTML = cur.code;
                else render(cur);
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
                        ta.value = cur.plain;
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
                        navigator.clipboard.writeText(cur.plain).then(done, fallback);
                    } else { fallback(); }
                } catch (e) { fallback(); }
            };

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
