/**
 * AMM 改版自测脚本（临时工具）
 * 用 Edge headless + CDP：
 *   1) 监听 Runtime.exceptionThrown / Log.entryAdded（等价于 window.onerror + unhandledrejection）
 *   2) 注入 localStorage 会话（可选），再 reload，让页面走「已登录」分支
 *   3) 在页面里跑一段断言，把结果打回来
 *
 * 用法：
 *   node tools/amm-cdp-check.js "<url>" "<localStorageJSON>" "<assertionJsFile>"
 */
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const url = process.argv[2];
const storageArg = process.argv[3] || '{}';
// 允许直接把 localStorage 的 JSON 写成文件传路径（免得在 shell 里跟引号打架）
const storageJson = fs.existsSync(storageArg) ? fs.readFileSync(storageArg, 'utf8') : storageArg;
const assertFile = process.argv[4] || '';
const stub = process.argv.includes('--stub');
const port = 9222 + Math.floor(Math.random() * 300);
const userDir = path.join(os.tmpdir(), '_ammcdp_' + Date.now());

// ============================================================
// Supabase 假数据层（只在 --stub 时启用）
// 让「已登录」分支能完整跑一遍：行情 / 我的公司 / 持仓 / 预览 / 图表
// 整段会被 toString() 注入到页面里，所以必须自包含（不能引用 Node 侧变量）。
// ============================================================
const STUB_UID = 'stub-user-0001';
const STUB = {
    profile: { id: STUB_UID, username: '测试UP' },
    companies: [
        { company_id: 101, company_name: '测试科技', founder: '测试UP', price: 1, pool_cash: 20000, pool_shares: 20000, total_shares: 40000, market_cap: 40000, verified: true, my_shares: 20000, my_value: 20000 },
        { company_id: 102, company_name: '别人家的公司', founder: '路人甲', price: 1, pool_cash: 64574500, pool_shares: 64574500, total_shares: 129149000, market_cap: 129149000, verified: false, my_shares: 0, my_value: 0 },
        { company_id: 103, company_name: '大池子公司', founder: '路人乙', price: 1, pool_cash: 149000000, pool_shares: 149000000, total_shares: 298000000, market_cap: 298000000, verified: false, my_shares: 0, my_value: 0 }
    ],
    myCompanyRow: { id: 101, company_name: '测试科技', pool_cash: 20000, pool_shares: 20000, total_shares: 40000, verified: true, verification_status: 'approved' },
    holdings: [
        { company_id: 101, company_name: '测试科技', shares: 20000, cost: 20000, avg_price: 1, current_price: 1, cur_value: 20000, profit: 0, profit_pct: 0, pool_cash: 20000, is_founder: true },
        { company_id: 102, company_name: '别人家的公司', shares: 3000, cost: 2700, avg_price: 0.9, current_price: 1, cur_value: 3000, profit: 300, profit_pct: 11.11, pool_cash: 64574500, is_founder: false }
    ],
    autoBuyRules: [
        { rule_id: 7, company_id: 102, company_name: '别人家的公司', price_target: 0.95, cur_price: 1, amount: 5000, daily_limit: 50000, today_cash: 0, enabled: true, last_run_at: null }
    ]
};

// 下面这个函数体是【页面里跑的代码】，必须自包含
function installStubFetch() {
    var STUB = __STUB_DATA__;   // 构建时替换成字面量
    function jsonRes(obj, status) {
        return new Response(JSON.stringify(obj), { status: status || 200, headers: { 'Content-Type': 'application/json' } });
    }
    function ammBuy(cash, shares, amount) {
        var p0 = cash / shares, k = cash * shares;
        var nc = cash + amount, ns = k / nc, got = shares - ns;
        return { ok: true, price_before: +p0.toFixed(4), price_after: +(nc / ns).toFixed(4), shares: +got.toFixed(4), avg_price: +(amount / got).toFixed(4), slippage_pct: +((amount / got / p0 - 1) * 100).toFixed(2) };
    }
    function ammSell(cash, shares, sell) {
        var p0 = cash / shares, k = cash * shares;
        var ns = shares + sell, nc = k / ns, got = cash - nc;
        return { ok: true, price_before: +p0.toFixed(4), price_after: +(nc / ns).toFixed(4), cash: +got.toFixed(4), avg_price: +(got / sell).toFixed(4), slippage_pct: +((1 - got / sell / p0) * 100).toFixed(2) };
    }
    function stubRpc(name, body) {
        var pool = STUB.companies[0];
        for (var i = 0; i < STUB.companies.length; i++) {
            if (Number(STUB.companies[i].company_id) === Number(body && body.p_company_id)) pool = STUB.companies[i];
        }
        switch (name) {
            case 'get_my_balance': return jsonRes({ ok: true, balance: 500000 });
            case 'get_market_list': return jsonRes(STUB.companies);
            case 'get_my_holdings': return jsonRes(STUB.holdings);
            case 'get_my_auto_buy_rules': return jsonRes(STUB.autoBuyRules);
            case 'get_active_shop_effects': return jsonRes({ success: true, fee_discount_count: 0 });
            case 'preview_buy': return jsonRes(ammBuy(Number(pool.pool_cash), Number(pool.pool_shares), Number(body.p_amount)));
            case 'preview_sell': return jsonRes(ammSell(Number(pool.pool_cash), Number(pool.pool_shares), Number(body.p_shares)));
            case 'get_company_kline': return jsonRes([]);
            case 'publish_stock_snapshot': return jsonRes({ success: true });
            default: return jsonRes({ success: true, message: 'stub: ' + name + ' 已调用' });
        }
    }
    function stubFetch(input, init) {
        var u = typeof input === 'string' ? input : (input && input.url) || '';
        var body = {};
        try { body = init && init.body ? JSON.parse(init.body) : {}; } catch (e) {}
        if (/\/rest\/v1\/rpc\//.test(u)) {
            return Promise.resolve(stubRpc(u.split('/rest/v1/rpc/')[1].split('?')[0], body));
        }
        if (/\/rest\/v1\/profiles/.test(u)) return Promise.resolve(jsonRes(STUB.profile));
        // 直接读表的兜底分支：fetchMyCompany 用 maybeSingle()（期望单对象）
        if (/\/rest\/v1\/user_companies/.test(u)) {
            return Promise.resolve(jsonRes(STUB.myCompanyRow));
        }
        if (/\/rest\/v1\//.test(u)) return Promise.resolve(jsonRes([]));
        return window.__realFetch(input, init);
    }
    window.__realFetch = window.fetch.bind(window);
    window.__stubCalls = [];
    window.__rpcLog = [];
    window.fetch = function (input, init) {
        var u = typeof input === 'string' ? input : (input && input.url) || '';
        if (/pbaafgjkwdbwcmsikcmg\.supabase\.co/.test(u)) {
            var name = null, body = null;
            try {
                var m = u.match(/\/rest\/v1\/(?:rpc\/)?([^?]+)/);
                name = m ? m[1] : u.slice(0, 60);
                window.__stubCalls.push(name);
                if (/\/rest\/v1\/rpc\//.test(u)) {
                    try { body = init && init.body ? JSON.parse(init.body) : null; } catch (e2) {}
                    window.__rpcLog.push({ name: name, args: body });
                }
            } catch (e) {}
            // 注册接口故意返回一个「后端拒绝」，这样页面停在表单上，可以断言参数和错误展示
            if (/register_company/.test(name || '')) {
                return Promise.resolve(jsonRes({ success: false, message: 'stub 模拟后端拒绝（注册接口已命中）' }));
            }
            return stubFetch(input, init);
        }
        return window.__realFetch(input, init);
    };
}

function buildStubSource() {
    return '(' + installStubFetch.toString().replace('__STUB_DATA__', JSON.stringify(STUB)) + ')();\n';
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function getWsUrl() {
    for (let i = 0; i < 60; i++) {
        try {
            const r = await fetch(`http://127.0.0.1:${port}/json/version`);
            const j = await r.json();
            if (j.webSocketDebuggerUrl) return j.webSocketDebuggerUrl;
        } catch (e) { /* not up yet */ }
        await sleep(250);
    }
    throw new Error('CDP endpoint never came up');
}

class CDP {
    constructor(ws) {
        this.ws = ws; this.id = 0; this.pending = new Map(); this.handlers = [];
        ws.addEventListener('message', ev => {
            const m = JSON.parse(ev.data);
            if (m.id && this.pending.has(m.id)) {
                const { resolve, reject } = this.pending.get(m.id);
                this.pending.delete(m.id);
                m.error ? reject(new Error(JSON.stringify(m.error))) : resolve(m.result);
            } else if (m.method) {
                this.handlers.forEach(h => h(m));
            }
        });
    }
    send(method, params, sessionId) {
        const id = ++this.id;
        const payload = { id, method, params: params || {} };
        if (sessionId) payload.sessionId = sessionId;
        this.ws.send(JSON.stringify(payload));
        return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
    }
    on(fn) { this.handlers.push(fn); }
}

(async () => {
    const edge = spawn(EDGE, [
        '--headless=new', '--disable-gpu', '--no-sandbox', '--disable-extensions',
        '--hide-scrollbars', '--no-first-run', '--disable-features=Translate',
        `--remote-debugging-port=${port}`, `--user-data-dir=${userDir}`,
        '--window-size=1440,2000', 'about:blank'
    ], { stdio: 'ignore' });

    const errors = [];
    const consoleMsgs = [];
    let cdp;
    try {
        const wsUrl = await getWsUrl();
        const ws = new WebSocket(wsUrl);
        await new Promise((res, rej) => { ws.addEventListener('open', res); ws.addEventListener('error', rej); });
        cdp = new CDP(ws);

        const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
        const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });

        cdp.on(m => {
            if (m.method === 'Runtime.exceptionThrown') {
                const d = m.params.exceptionDetails;
                errors.push((d.exception && (d.exception.description || d.exception.value)) || d.text);
            } else if (m.method === 'Runtime.consoleAPICalled') {
                const txt = (m.params.args || []).map(a => a.value != null ? a.value : (a.description || a.type)).join(' ');
                consoleMsgs.push(m.params.type + ': ' + txt);
                if (m.params.type === 'error') errors.push('console.error: ' + txt);
            } else if (m.method === 'Log.entryAdded') {
                const e = m.params.entry;
                if (e.level === 'error') errors.push('log.error[' + e.source + ']: ' + e.text);
            }
        });

        await cdp.send('Runtime.enable', {}, sessionId);
        await cdp.send('Log.enable', {}, sessionId);
        await cdp.send('Page.enable', {}, sessionId);

        // 页面级 window.onerror / unhandledrejection 钩子（在页面脚本之前装好）
        await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
            source: `
                window.__ammErrors = [];
                window.addEventListener('error', function (e) {
                    try { window.__ammErrors.push('window.onerror: ' + (e.message || e.type) + ' @' + (e.filename||'') + ':' + (e.lineno||0)); } catch (x) {}
                });
                window.addEventListener('unhandledrejection', function (e) {
                    try {
                        var r = e.reason;
                        window.__ammErrors.push('unhandledrejection: ' + ((r && (r.message || r.msg)) || String(r)));
                    } catch (x) {}
                });
            ` + (stub ? buildStubSource() : '')
        }, sessionId);

        // 先直接开目标 URL（确保同源），写入 localStorage 后再 reload 一次，
        // 这样注入的会话在页面脚本第一次执行前就已存在。
        await cdp.send('Page.navigate', { url }, sessionId);
        await sleep(4000);
        const store = JSON.parse(storageJson);
        const storeJs = Object.keys(store).map(k => `localStorage.setItem(${JSON.stringify(k)}, ${JSON.stringify(store[k])});`).join('\n');
        if (storeJs) {
            await cdp.send('Runtime.evaluate', { expression: storeJs, returnByValue: true }, sessionId);
            await cdp.send('Runtime.evaluate', { expression: 'window.__ammErrors = []' }, sessionId);
            await cdp.send('Page.reload', { ignoreCache: true }, sessionId);
            await sleep(9000);   // 等行情 RPC + 图表渲染完
        }

        if (assertFile) {
            const where = await cdp.send('Runtime.evaluate', { expression: 'location.href + " | readyState=" + document.readyState + " | title=" + document.title + " | body=" + (document.body ? document.body.innerText.slice(0,300) : "nobody")', returnByValue: true }, sessionId);
            console.log('=== 当前文档 ===');
            console.log(where.result.value);
            const src = fs.readFileSync(assertFile, 'utf8');
            const r = await cdp.send('Runtime.evaluate', {
                expression: src, returnByValue: true, awaitPromise: true
            }, sessionId);
            if (r.exceptionDetails) {
                errors.push('断言脚本抛错: ' + JSON.stringify(r.exceptionDetails.exception && r.exceptionDetails.exception.description || r.exceptionDetails.text));
            } else {
                console.log('=== 断言结果 ===');
                console.log(typeof r.result.value === 'string' ? r.result.value : JSON.stringify(r.result.value, null, 2));
            }
        }

        const pe = await cdp.send('Runtime.evaluate', {
            expression: 'JSON.stringify(window.__ammErrors || [])', returnByValue: true
        }, sessionId);
        const pageErrors = JSON.parse(pe.result.value || '[]');

        if (stub) {
            const sc = await cdp.send('Runtime.evaluate', {
                expression: 'JSON.stringify({ counts: (window.__stubCalls||[]).reduce(function(a,k){a[k]=(a[k]||0)+1;return a;},{}), rpcLog: window.__rpcLog||[] })',
                returnByValue: true
            }, sessionId);
            console.log('=== 被调用的后端接口（stub 计数）+ RPC 入参 ===');
            console.log(sc.result.value);
        }

        console.log('=== 页面内 error/unhandledrejection ===');
        console.log(pageErrors.length ? pageErrors.join('\n') : '(0 条)');
        console.log('=== CDP 捕获的异常 / console.error ===');
        console.log(errors.length ? errors.join('\n') : '(0 条)');
        console.log('=== console 非错误输出（最后 25 条）===');
        console.log(consoleMsgs.slice(-25).join('\n') || '(无)');
    } catch (e) {
        console.error('脚本失败:', e && e.stack || e);
        process.exitCode = 1;
    } finally {
        try { edge.kill(); } catch (e) {}
        await sleep(400);
        try { fs.rmSync(userDir, { recursive: true, force: true }); } catch (e) {}
    }
})();
