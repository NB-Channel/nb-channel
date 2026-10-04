(function () {
    var out = {};
    function txt(el) { return el ? (el.textContent || '').trim() : null; }
    function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

    return (async function () {
        try {
            var c = allCompanies[0];
            var mine = allCompanies.filter(function (x) { return x.myShares > 0; })[0] || c;

            // ============ 1. 买入：预览 + 防抖 ============
            await showTradeDialog(c.company_id, c.company_name, c.price, 'buy');
            var inp = document.getElementById('tradeShares');
            out.buy = {
                modal: document.getElementById('tradeModal').style.display,
                title: txt(document.getElementById('tradeTitle')),
                priceText: txt(document.getElementById('tradePrice')),
                label: txt(document.getElementById('tradeAmountLabel')),
                input: inp.value,
                holding: txt(document.getElementById('tradeHolding')),
                balance: txt(document.getElementById('tradeBalance')),
                capHint: txt(document.getElementById('tradeCapHint')),
                quickButtons: Array.prototype.map.call(document.querySelectorAll('#tradeQuickRow button'), function (b) { return b.textContent; }),
                previewOnOpen: (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 300)
            };
            // 防抖：连敲 3 次，只有最后一次的结果应该显示
            inp.dispatchEvent(new Event('input', { bubbles: true })); inp.value = '100';
            inp.dispatchEvent(new Event('input', { bubbles: true })); inp.value = '1000';
            inp.dispatchEvent(new Event('input', { bubbles: true })); inp.value = '5000';
            out.buy.immediatePreview = (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 120);
            await wait(2600);
            out.buy.previewAfterDebounce = (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 400);
            out.buy.previewMatchesLastInput = /投入 5,000/.test(out.buy.previewAfterDebounce || '');

            // 快捷按钮点击
            var qb = document.querySelectorAll('#tradeQuickRow button');
            if (qb.length) {
                qb[1].click();
                await wait(2600);
                out.buy.afterQuickClick = { input: inp.value, preview: (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 260) };
            }

            // 小池子大额 → 滑点红字告警
            await showTradeDialog(mine.company_id, mine.company_name, mine.price, 'buy');
            inp = document.getElementById('tradeShares');
            inp.dispatchEvent(new Event('input', { bubbles: true })); inp.value = '100000';
            await wait(2600);
            var big = txt(document.getElementById('tradeAmountPreview')) || '';
            out.buySmallPool = { text: big.slice(0, 400), hasRedWarn: /明显推动价格/.test(big) };

            // ============ 2. 卖出：语义是「张」 ============
            await showTradeDialog(mine.company_id, mine.company_name, mine.price, 'sell');
            inp = document.getElementById('tradeShares');
            out.sell = {
                title: txt(document.getElementById('tradeTitle')),
                label: txt(document.getElementById('tradeAmountLabel')),
                input: inp.value,
                holding: txt(document.getElementById('tradeHolding')),
                capHint: (txt(document.getElementById('tradeCapHint')) || '').slice(0, 220),
                quickButtons: Array.prototype.map.call(document.querySelectorAll('#tradeQuickRow button'), function (b) { return b.textContent; }),
                min: inp.getAttribute('min'),
                step: inp.getAttribute('step'),
                max: inp.getAttribute('max')
            };
            inp.dispatchEvent(new Event('input', { bubbles: true })); inp.value = '20000';
            await wait(2600);
            out.sell.previewAfterDebounce = (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 400);
            // 「全部」快捷按钮
            var sq = document.querySelectorAll('#tradeQuickRow button');
            if (sq.length) {
                sq[sq.length - 1].click();
                await wait(2600);
                out.sell.afterAllClick = { input: inp.value, preview: (txt(document.getElementById('tradeAmountPreview')) || '').slice(0, 300) };
            }
            document.getElementById('tradeModal').style.display = 'none';

            // ============ 3. 自动抄底 ============
            await showAutoBuyDialog();
            await wait(1400);
            var dlg = document.getElementById('customDialog');
            out.autoBuy = {
                open: !!dlg,
                title: dlg ? txt(dlg.querySelector('h3')) : null,
                rules: dlg ? (txt(document.getElementById('autoBuyRulesList')) || '').slice(0, 300) : null,
                options: dlg ? Array.prototype.map.call(dlg.querySelectorAll('#autoBuyCompanySelect option'), function (o) { return o.textContent; }) : [],
                excludesMyCompany: dlg ? !/测试科技/.test(txt(document.getElementById('autoBuyCompanySelect')) || '') : null,
                fields: dlg ? ['autoBuyCompanySelect', 'autoBuyTarget', 'autoBuyAmount', 'autoBuyDailyLimit', 'setAutoBuyRuleBtn'].map(function (id) { return id + '=' + !!document.getElementById(id); }) : []
            };
            var saveBtn = document.getElementById('setAutoBuyRuleBtn');
            if (saveBtn) {
                document.getElementById('autoBuyTarget').value = '0';
                document.getElementById('autoBuyAmount').value = '5000';
                saveBtn.click(); await wait(500);
                out.autoBuy.badTargetMsg = (txt(document.getElementById('customMessageText')) || '').slice(0, 100);
                document.getElementById('customMessageModal').style.display = 'none';

                document.getElementById('autoBuyTarget').value = '0.95';
                document.getElementById('autoBuyAmount').value = '5000';
                document.getElementById('autoBuyDailyLimit').value = '100';
                saveBtn.click(); await wait(500);
                out.autoBuy.smallDailyMsg = (txt(document.getElementById('customMessageText')) || '').slice(0, 120);
                document.getElementById('customMessageModal').style.display = 'none';
            }
            if (document.getElementById('closeDialogBtn')) document.getElementById('closeDialogBtn').click();

            // ============ 4. 分红 ============
            payDividend();
            await wait(1200);
            var pm = document.getElementById('nbPromptModal');
            out.dividend = {
                open: !!pm,
                title: pm ? txt(pm.querySelector('h3')) : null,
                body: pm ? (txt(pm.querySelector('p')) || '').slice(0, 320) : null,
                placeholder: pm ? pm.querySelector('#nbPromptInput').placeholder : null
            };
            if (pm) {
                pm.querySelector('#nbPromptInput').value = '5000';
                pm.querySelector('#nbPromptOk').click();
                await wait(900);
                out.dividend.confirm = (txt(document.getElementById('customConfirmText')) || '').slice(0, 320);
                document.getElementById('customConfirmCancel').click();
            }
            // 超过池子现金 → 应该拦下
            payDividend(); await wait(900);
            var pm2 = document.getElementById('nbPromptModal');
            if (pm2) {
                pm2.querySelector('#nbPromptInput').value = '999999999';
                pm2.querySelector('#nbPromptOk').click();
                await wait(900);
                out.dividend.overPoolMsg = (txt(document.getElementById('customMessageText')) || '').slice(0, 120);
                document.getElementById('customMessageModal').style.display = 'none';
            }

            // ============ 5. 清算 ============
            bankruptCompany();
            await wait(900);
            out.bankrupt = {
                title: txt(document.getElementById('customConfirmTitle')),
                text: (txt(document.getElementById('customConfirmText')) || '').slice(0, 400)
            };
            document.getElementById('customConfirmCancel').click();
        } catch (e) {
            out.err = String((e && e.stack) || e);
        }
        return JSON.stringify(out, null, 2);
    })();
})()
