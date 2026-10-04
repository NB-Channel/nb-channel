(function () {
    var out = {};
    function txt(el) { return el ? (el.textContent || '').trim() : null; }
    function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

    return (async function () {
        try {
            var cap = document.getElementById('capitalAmount');
            var hint = document.getElementById('capitalHint');
            out.hasCapitalInput = !!cap;
            out.defaultCapital = cap ? cap.value : null;
            out.min = cap ? cap.getAttribute('min') : null;
            out.step = cap ? cap.getAttribute('step') : null;
            out.quickButtons = Array.prototype.map.call(document.querySelectorAll('.quick-amounts button'), function (b) {
                return b.textContent + '(data-add=' + b.dataset.add + ')';
            });
            out.hintInitial = (txt(hint) || '').slice(0, 400);
            out.ownerName = txt(document.getElementById('ownerName'));

            // 快捷按钮：第三个应设成 100000
            var qbs = document.querySelectorAll('.quick-amounts button');
            if (qbs.length >= 3) {
                qbs[2].click();
                await wait(200);
                out.afterQuickClick3 = { value: cap.value, hint: (txt(hint) || '').slice(0, 400) };
            }
            // 低于最低 → 本地拦下
            cap.value = '5000';
            document.getElementById('companyName').value = '测试新公司';
            document.getElementById('submitBtn').click();
            await wait(400);
            out.tooLowMsg = txt(document.getElementById('errorMsg'));

            // 超过余额 → 本地拦下（stub 余额 500000）
            cap.value = '900000';
            document.getElementById('submitBtn').click();
            await wait(400);
            out.overBalanceMsg = txt(document.getElementById('errorMsg'));

            // 正常提交 → 应打 register_company_funded
            cap.value = '20000';
            document.getElementById('companyName').value = '测试新公司';
            window.__rpcLog = [];
            var realRpc = supabaseClient.rpc.bind(supabaseClient);
            supabaseClient.rpc = function (name, args) {
                window.__rpcLog.push({ name: name, args: JSON.parse(JSON.stringify(args || {})) });
                return realRpc(name, args);
            };
            document.getElementById('submitBtn').click();
            await wait(1500);
            out.submitRpc = window.__rpcLog;
            out.errorAfterSubmit = txt(document.getElementById('errorMsg'));
            out.submitBtnState = { text: txt(document.getElementById('submitBtn')), disabled: document.getElementById('submitBtn').disabled };
        } catch (e) {
            out.err = String((e && e.stack) || e);
        }
        return JSON.stringify(out, null, 2);
    })();
})()
