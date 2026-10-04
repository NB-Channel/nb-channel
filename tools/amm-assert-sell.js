(function () {
    var out = { steps: [] };
    function txt(el) { return el ? (el.textContent || '').trim() : null; }
    function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

    return (async function () {
        try {
            var mine = allCompanies.filter(function (x) { return x.myShares > 0; })[0] || allCompanies[0];
            out.steps.push('company=' + mine.company_name + ' myShares=' + mine.myShares + ' pool=' + mine.poolCash);
            await showTradeDialog(mine.company_id, mine.company_name, mine.price, 'sell');
            var inp = document.getElementById('tradeShares');
            out.afterOpen = { inputValue: inp.value, label: txt(document.getElementById('tradeAmountLabel')), mode: tradeState.mode, parse: parseFloat(inp.value) };
            inp.value = String(mine.myShares);
            out.afterSetValue = { inputValue: inp.value, parse: parseFloat(inp.value) };
            inp.dispatchEvent(new Event('input', { bubbles: true }));
            await wait(2500);
            out.afterDebounce = { inputValue: inp.value, parse: parseFloat(inp.value), preview: (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 400) };

            // 直接强制再算一次，看是不是请求本身有问题
            document.getElementById('tradeShares').value = '20000';
            await updateTradePreview(true);
            out.afterForce = { inputValue: inp.value, preview: (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 400) };

            // 直接调 RPC 看返回
            var r = await supabaseClient.rpc('preview_sell', { p_company_id: mine.company_id, p_shares: 20000 });
            out.rawRpc = { error: r.error ? r.error.message : null, data: r.data };
        } catch (e) {
            out.err = String((e && e.stack) || e);
        }
        return JSON.stringify(out, null, 2);
    })();
})()
