(function () {
    var out = {};
    function txt(el) { return el ? (el.textContent || '').trim() : null; }

    // ---- 表头 ----
    var ths = Array.prototype.map.call(document.querySelectorAll('.data-table thead th'), function (t) { return txt(t); });
    out.thead = ths;

    // ---- 主列表前 8 行 ----
    var rows = document.querySelectorAll('#tableBody tr');
    out.rowCount = rows.length;
    out.rows = Array.prototype.slice.call(rows, 0, 8).map(function (tr) {
        return Array.prototype.map.call(tr.children, function (td) { return txt(td); });
    });

    // ---- 校验：股价列必须形如 1.0000 ----
    var priceOk = 0, priceBad = [];
    Array.prototype.forEach.call(rows, function (tr) {
        var td = tr.children[1];
        if (!td) return;
        var s = txt(td);
        if (/^\d+\.\d{4}$/.test(s)) priceOk++; else priceBad.push(s);
    });
    out.priceCells = { ok: priceOk, bad: priceBad.slice(0, 5) };

    // ---- 校验：资金池列必须是「亿 / 万」缩写或 1,234.56 形式，不能是长数字 ----
    var poolOk = 0, poolBad = [];
    Array.prototype.forEach.call(rows, function (tr) {
        var td = tr.children[2];
        if (!td) return;
        var s = txt(td);
        if (/(亿|万)$/.test(s) || /^[\d,]+\.\d{2}$/.test(s)) poolOk++; else poolBad.push(s);
    });
    out.poolCells = { ok: poolOk, bad: poolBad.slice(0, 5) };

    // ---- 涨跌幅列 ----
    out.changeCells = Array.prototype.slice.call(rows, 0, 5).map(function (tr) { return txt(tr.children[5]); });

    // ---- 状态面板 ----
    out.statsPanel = (txt(document.getElementById('statsPanel')) || '').slice(0, 400);
    out.myCompanySection = (txt(document.getElementById('myCompanySection')) || '').slice(0, 300);
    out.dataTimestamp = txt(document.getElementById('dataTimestamp'));
    out.marketStatus = txt(document.getElementById('marketStatus'));
    out.balanceSpan = txt(document.getElementById('balanceSpan'));
    out.userStatusSpan = (txt(document.getElementById('userStatusSpan')) || '').slice(0, 120);
    out.autoBuyBtn = txt(document.getElementById('openSupportDialogBtn'));
    out.kLineTitle = (txt(document.getElementById('kLineTitle')) || '').slice(0, 120);
    out.kLineHasCanvas = !!document.querySelector('#kLineChart canvas');
    out.chartCanvas = !!document.querySelector('#stockChart');

    // ---- 旧模型残留检查 ----
    out.legacy = {
        supportCompany: typeof window.supportCompany,
        showSupportDialog: typeof window.showSupportDialog,
        setAutoSupportRule: typeof window.setAutoSupportRule,
        checkAutoSupportRules: typeof window.checkAutoSupportRules,
        withdrawCompanyValue: typeof window.withdrawCompanyValue,
        showAutoBuyDialog: typeof window.showAutoBuyDialog,
        payDividend: typeof window.payDividend,
        bankruptCompany: typeof window.bankruptCompany,
        fetchMarketList: typeof window.fetchMarketList,
        formatPrice: typeof window.formatPrice,
        formatLarge: typeof window.formatLarge
    };

    // ---- 格式化函数实测 ----
    out.fmt = {
        price_1: window.formatPrice ? window.formatPrice(1) : null,
        large_149000000: window.formatLarge ? window.formatLarge(149000000) : null,
        large_64574500: window.formatLarge ? window.formatLarge(64574500) : null,
        large_1234_567: window.formatLarge ? window.formatLarge(1234.567) : null,
        large_0: window.formatLarge ? window.formatLarge(0) : null
    };

    // ---- 交易弹窗：买入模式（不真下单，只看预览渲染） ----
    return (async function () {
        try {
            if (typeof window.showTradeDialog === 'function' && window.allCompanies && window.allCompanies.length) {
                var c = window.allCompanies[0];
                await window.showTradeDialog(c.company_id, c.company_name, c.price, 'buy');
                out.tradeModalVisible = document.getElementById('tradeModal').style.display;
                out.tradePriceText = txt(document.getElementById('tradePrice'));
                out.tradeLabel = txt(document.getElementById('tradeAmountLabel'));
                out.tradeInputValue = document.getElementById('tradeShares').value;
                out.tradeHolding = txt(document.getElementById('tradeHolding'));
                // 等预览（防抖 280ms）
                await new Promise(function (r) { setTimeout(r, 2500); });
                out.tradePreview = (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 400);
                out.tradeCapHint = (txt(document.getElementById('tradeCapHint')) || '').slice(0, 200);

                // 卖出模式
                await window.showTradeDialog(c.company_id, c.company_name, c.price, 'sell');
                out.sellLabel = txt(document.getElementById('tradeAmountLabel'));
                out.sellInputValue = document.getElementById('tradeShares').value;
                await new Promise(function (r) { setTimeout(r, 2500); });
                out.sellPreview = (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 400);
                document.getElementById('tradeModal').style.display = 'none';
            } else {
                out.tradeModalVisible = 'skip: showTradeDialog 不可用或行情为空';
            }
        } catch (e) { out.tradeErr = String(e && e.message || e); }
        return JSON.stringify(out, null, 2);
    })();
})()
