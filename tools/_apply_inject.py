# -*- coding: utf-8 -*-
"""
给两个股票页面加「增资」功能。
- 根目录 Virtual stock.html（新潮/经典共用，css/style.css + ui-new.css + classic.css）
- Beta/stock-Beta.html（官网版，css/themes.css 主题变量）
所有替换都要求「恰好命中一次」，否则整体不落盘。
写盘前先 encode 再 open(wb)，避免中途出错把文件清成 0 字节。
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ============================================================
# 0) 共用片段
# ============================================================

# ---- 0.1 「增资记录」区块（两个页面完全相同） ----
RECORDS_SECTION = u"""        <!-- 增资记录（数据源 get_my_injections，含 7 天锁定期状态） -->
        <div id="myInjectionsSection" class="my-company-card" style="display:none; flex-direction:column; align-items:stretch;">
            <div style="width:100%; display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:8px;">
                <strong>\U0001F4B0 增资记录</strong>
                <span style="font-size:0.78rem; color:var(--count-text);">增资不会获得股份；增资后 7 天内不能卖出该公司股份</span>
            </div>
            <div id="injectionsList" style="width:100%; font-size:0.9rem; overflow-x:auto; margin-top:8px;"></div>
        </div>
"""

# ---- 0.2 增资弹窗按钮组（插在清算按钮之后） ----
INJECT_BUTTONS = u"""                <button id="injectBtn" class="company-btn inject-btn" title="\U0001F4B0 给公司资金池打钱：股价上涨（全体股东受益），不获得任何股份；增资后 7 天内不能卖出">\U0001F4B0 增资</button>
"""

# ---- 0.3 公司卡片里的锁定期提示（插在「总股本」那一行末尾） ----
LOCK_LINE = u"""                ${myCompanyLockHtml()}
"""

# ---- 0.4 持有/行情表里红字锁定期说明的辅助函数（插在 isSellLocked 之后） ----
LOCK_NOTE_HELPER = u"""
    // 表格里那行红字（卖出被锁定时显示）
    function lockNoteHtml(companyId) {
        const info = isSellLocked(companyId);
        if (!info.locked) return '';
        return '<div style="color:#f44336; font-size:0.7rem; line-height:1.5;">\U0001F512 ' + escapeHtml(lockTip(info)) + '</div>';
    }
"""

# ---- 0.5 增资核心 JS ----
INJECT_JS = u"""    // ============================================================
    // 增资（创始人专属）
    // ------------------------------------------------------------
    // 创始人往自己公司的 AMM 资金池打钱，【不获得任何股份】：
    //   股价 = pool_cash / pool_shares
    //   增资后股价 = (pool_cash + 金额) / pool_shares
    // 上涨带来的收益归全体股东（含创始人自己已持有的部分）。
    //
    //   增资：inject_company_capital(p_user_id, p_session, p_company_id, p_amount)
    //   查询：get_my_injections(p_user_id) → locked=true 表示该公司还在 7 天锁定期内
    //
    // 失败原因一律直接展示后端 message，前端不自己拼文案。
    // 注意：本页注释里的「注资」是旧模型的功能，已被 AMM 取消；这个新功能叫「增资」，
    //      和旧注资不是一回事（旧注资换股份，增资换股价）。
    // ============================================================
    const INJECT_MIN = 1000;              // 单次最低增资额（后端同样有下限）
    let injectRegistry = {};              // company_id -> { locked, until, days }
    let injectionRecords = [];            // get_my_injections 原始记录（时间倒序）
    let injectState = null;               // 当前增资弹窗状态
    let injectBalance = 0;                // 点开增资弹窗时抓到的最新余额

    // 金额展示：整数加千分位，免得 10,000 写成 10000 一眼看不出量级
    function fmtNbInt(n) {
        const v = Math.round(Number(n) || 0);
        return v.toLocaleString('en-US');
    }

    // 一条增资记录的金额：get_my_injections 的字段叫 cash，
    // inject_company_capital 的返回值叫 amount —— 两个都认。
    function injectRecAmount(rec) {
        if (!rec) return 0;
        const v = (rec.amount === null || rec.amount === undefined) ? rec.cash : rec.amount;
        return Number(v) || 0;
    }

    // 有效锁定期：以 locked=true 且 lock_until 还没到为准（时间字段取不到时退回 locked 字段）
    function injectionLockInfo(rec) {
        if (!rec) return { locked: false, until: null, days: 0 };
        if (rec.locked !== true) return { locked: false, until: null, days: 0 };
        const rawUntil = rec.lock_until || rec.locked_until || rec.unlock_at || null;
        const until = rawUntil ? new Date(rawUntil) : null;
        const t = until ? until.getTime() : NaN;
        if (!isNaN(t)) {
            const msLeft = t - Date.now();
            if (msLeft <= 0) return { locked: false, until: until, days: 0 };
            return { locked: true, until: until, days: Math.max(1, Math.ceil(msLeft / 86400000)) };
        }
        return { locked: true, until: until, days: 0 };
    }

    // 悬停提示文案
    function lockTip(info) {
        if (!info || !info.locked) return '';
        const left = info.days > 0 ? ('还剩 ' + info.days + ' 天') : '锁定期未结束';
        const untilTxt = info.until ? ('，' + info.until.toLocaleString('zh-CN', { hour12: false }) + ' 解锁') : '';
        return '增资后 7 天内不能卖出（' + left + untilTxt + '）';
    }

    // 某公司是否被增资锁定期锁住（行情表 / 持仓表 / 交易弹窗共用）
    function isSellLocked(companyId) {
        if (companyId === null || companyId === undefined) return { locked: false, until: null, days: 0 };
        return injectRegistry[String(companyId)] || { locked: false, until: null, days: 0 };
    }

    // 表格里那行红字（卖出被锁定时显示）
    function lockNoteHtml(companyId) {
        const info = isSellLocked(companyId);
        if (!info.locked) return '';
        return '<div style="color:#f44336; font-size:0.7rem; line-height:1.5;">\U0001F512 ' + escapeHtml(lockTip(info)) + '</div>';
    }

    // 拉我的增资记录 + 重建锁定表。失败只 console.warn，绝不影响主流程。
    async function fetchMyInjections(uid) {
        let u = uid || currentUserId;
        if (!u) {
            try {
                const raw = localStorage.getItem('nb_user');
                if (raw) { const o = JSON.parse(raw); if (o && o.id) u = o.id; }
            } catch (e) { /* 忽略 */ }
        }
        if (!u) { injectionRecords = []; injectRegistry = {}; return []; }
        try {
            // get_my_injections 只有 (uuid) 一个签名，不需要 p_session
            const r = await supabaseClient.rpc('get_my_injections', { p_user_id: u });
            if (r.error) {
                console.warn('get_my_injections 调用失败：', r.error.message);
                if (window.console && console.info) console.info('（增资锁定期需要该函数；调用失败时页面按「未锁定」显示）');
                return injectionRecords;
            }
            injectionRecords = Array.isArray(r.data) ? r.data.slice() : [];
        } catch (e) {
            console.warn('get_my_injections 异常', e);
            return injectionRecords;
        }
        // 记录按时间倒序 → 每家公司第一条（最新一条）就是最终锁定状态
        const reg = {};
        injectionRecords.forEach(rec => {
            const cid = String(rec.company_id);
            if (reg[cid]) return;
            reg[cid] = injectionLockInfo(rec);
        });
        injectRegistry = reg;
        return injectionRecords;
    }

    // 增资弹窗：前端自己算「增资后股价」，不调接口
    async function showInjectDialog(poolCash, poolShares) {
        if (!currentUserId) { await showMessage('提示', '请先登录'); return; }
        if (!myCompany) { await showMessage('提示', '您还没有虚拟公司'); return; }
        const cash = Number(poolCash) || 0;
        const shares = Number(poolShares) || 0;
        if (!(shares > 0)) {
            await showMessage('提示', '公司股本数据异常（池子股份为 0），暂时无法增资，请稍后刷新重试。');
            return;
        }
        const modal = document.getElementById('injectModal');
        if (!modal) return;

        // 先把余额抓准（比页面缓存可靠），再决定默认金额
        try { injectBalance = Number(await fetchUserBalance()) || 0; } catch (e) { injectBalance = 0; }
        let defAmount = 10000;
        if (injectBalance > 0 && injectBalance < defAmount) defAmount = Math.floor(injectBalance);
        if (defAmount < INJECT_MIN) defAmount = '';

        document.getElementById('injectCompanyName').innerText = myCompany.company_name;
        document.getElementById('injectCurrentPrice').innerText = formatPrice(safeDiv(cash, shares));
        document.getElementById('injectBalance').innerText = fmtNbInt(injectBalance);
        const input = document.getElementById('injectAmount');
        if (input) {
            input.value = defAmount === '' ? '' : String(defAmount);
            input.oninput = () => updateInjectPreview();
            input.onchange = () => updateInjectPreview();
        }

        // 快捷档位：低于起投额的档位直接不显示
        const quickRow = document.getElementById('injectQuickRow');
        if (quickRow) {
            quickRow.innerHTML = '';
            [{ v: 1000, label: '1000' }, { v: 10000, label: '1万' },
             { v: 100000, label: '10万' }, { v: 500000, label: '50万' }].forEach(p => {
                if (p.v < INJECT_MIN) return;
                const b = document.createElement('button');
                b.type = 'button';
                b.className = 'company-btn inject-chip';
                b.setAttribute('data-amount', String(p.v));
                b.style.cssText = 'margin:0; padding:4px 14px; font-size:0.78rem;';
                b.textContent = p.label;
                b.onclick = () => {
                    if (input) input.value = String(p.v);
                    updateInjectPreview();
                };
                quickRow.appendChild(b);
            });
        }

        injectState = { companyId: myCompany.id, name: myCompany.company_name, poolCash: cash, poolShares: shares };
        modal.style.display = 'flex';
        updateInjectPreview();
    }

    function closeInjectDialog() {
        const m = document.getElementById('injectModal');
        if (m) m.style.display = 'none';
        injectState = null;
    }

    // 实时预览：增资后股价 = (池子现金 + 金额) / 池子股份
    function updateInjectPreview() {
        if (!injectState) return;
        const inputEl = document.getElementById('injectAmount');
        const amount = Math.floor(Number(inputEl && inputEl.value) || 0);
        const msgBox = document.getElementById('injectMsg');
        const afterEl = document.getElementById('injectAfterPrice');
        const pctEl = document.getElementById('injectPct');
        const btn = document.getElementById('injectOkBtn');

        // 快捷档位高亮
        document.querySelectorAll('#injectQuickRow .inject-chip').forEach(b => {
            const on = amount > 0 && Number(b.getAttribute('data-amount')) === amount;
            b.style.outline = on ? '2px solid var(--status-border)' : 'none';
        });

        if (!(amount > 0)) {
            afterEl.innerText = '\u2014';
            pctEl.innerText = '';
            msgBox.innerText = '请输入增资金额';
            msgBox.style.color = 'var(--count-text)';
            if (btn) { btn.disabled = true; btn.style.opacity = '.55'; btn.style.cursor = 'not-allowed'; }
            return;
        }

        const before = safeDiv(injectState.poolCash, injectState.poolShares);
        const after = safeDiv(injectState.poolCash + amount, injectState.poolShares);
        const pct = before > 0 ? (after - before) / before * 100 : 0;
        afterEl.innerText = formatPrice(after);
        pctEl.innerText = (pct >= 0 ? '\u2b06 +' : '\u2b07 ') + pct.toFixed(2) + '%';
        pctEl.style.color = pct >= 0 ? '#f44336' : '#4caf50';

        let err = '';
        if (amount < INJECT_MIN) {
            err = '单次增资不能少于 ' + fmtNbInt(INJECT_MIN) + ' NB币';
        } else if (injectBalance > 0 && amount > injectBalance) {
            err = '余额不足：需要 ' + fmtNbInt(amount) + ' NB币，你的余额 ' + fmtNbInt(injectBalance) + ' NB币';
        }
        if (err) {
            msgBox.innerText = '\u26a0\ufe0f ' + err;
            msgBox.style.color = '#f44336';
            if (btn) { btn.disabled = true; btn.style.opacity = '.55'; btn.style.cursor = 'not-allowed'; }
        } else {
            msgBox.innerText = '本次增资 ' + fmtNbInt(amount) + ' NB币，不获得任何股份';
            msgBox.style.color = 'var(--count-text)';
            if (btn) { btn.disabled = false; btn.style.opacity = ''; btn.style.cursor = 'pointer'; }
        }
    }

    // 确认增资
    async function runInject() {
        if (!currentUserId) { await showMessage('提示', '请先登录'); return; }
        if (!myCompany) { await showMessage('提示', '您还没有虚拟公司'); return; }
        if (!injectState) return;

        const amount = Math.floor(Number(document.getElementById('injectAmount').value) || 0);
        if (!(amount > 0)) { await showMessage('提示', '请输入有效的增资金额'); return; }
        if (amount < INJECT_MIN) { await showMessage('提示', '单次增资不能少于 ' + fmtNbInt(INJECT_MIN) + ' NB币'); return; }
        if (injectBalance > 0 && amount > injectBalance) {
            await showMessage('提示', 'NB币余额不足：需要 ' + fmtNbInt(amount) + ' NB币，你有 ' + fmtNbInt(injectBalance) + ' NB币');
            return;
        }

        const ok = await showConfirm('确认增资',
            '确定给「' + myCompany.company_name + '」增资 ' + fmtNbInt(amount) + ' NB币吗？\\n\\n' +
            '\u26a0\ufe0f 增资不会获得任何股份，钱会变成公司的资金（股价上涨，全体股东受益）。\\n' +
            '\u26a0\ufe0f 增资后 7 天内，你不能卖出这家公司的股份。');
        if (!ok) return;

        const btn = document.getElementById('injectOkBtn');
        if (btn) { btn.disabled = true; btn.innerText = '提交中…'; }

        let data = null, error = null;
        try {
            // 后端只有 inject_company_capital(uuid, text, bigint, numeric) 一个签名，必须带 p_session
            const r = await supabaseClient.rpc('inject_company_capital', {
                p_user_id: currentUserId,
                p_session: localStorage.getItem('nb_session'),
                p_company_id: myCompany.id,
                p_amount: amount
            });
            data = r.data; error = r.error;
        } catch (e) { error = e; }

        if (btn) { btn.disabled = false; btn.innerText = '\U0001F4B0 确认增资'; }
        if (error) { await showMessage('增资失败', error.message || '未知错误'); return; }
        if (!data || data.success === false) {
            // 后端给的原因（休市 / 余额不足 / 非创始人 / 金额超限 …）直接展示，前端不另拼文案
            await showMessage('增资失败', (data && data.message) || '增资失败');
            try { injectBalance = Number(await fetchUserBalance()) || 0; } catch (e) { /* 忽略 */ }
            document.getElementById('injectBalance').innerText = fmtNbInt(injectBalance);
            updateInjectPreview();
            return;
        }

        closeInjectDialog();
        await fetchUserBalance();
        await fetchAllCompanies();
        await refreshStockDataFromDB();     // 内部会重新 fetchMyCompany + 渲染「我的公司」
        await fetchMyInjections();          // 增资成功 → 重新拉锁定期
        renderMyCompanySection();
        renderInjectionRecords();
        await showMessage('增资成功', (data.message || '增资成功') +
            '\\n\\n\u23f3 增资后 7 天内不能卖出该公司股份，到期会自动解锁。');
    }

    // 增资记录列表（数据源 get_my_injections）
    function renderInjectionRecords() {
        const section = document.getElementById('myInjectionsSection');
        const box = document.getElementById('injectionsList');
        if (!section || !box) return;
        if (!currentUserId || !injectionRecords.length) {
            section.style.display = 'none';
            return;
        }
        section.style.display = 'flex';

        const asc = injectionRecords.slice().sort((a, b) =>
            (Date.parse(a.created_at) || 0) - (Date.parse(b.created_at) || 0));

        let html = '<table class="data-table" style="font-size:0.82rem;"><thead><tr>' +
            '<th>时间</th><th>公司</th><th>增资金额</th><th>增资后股价</th><th>7 天卖出锁定期</th>' +
            '</tr></thead><tbody>';
        // 最新的排最上面；同一家公司多次增资时按「累计投入」倒推当时的股价
        for (let i = asc.length - 1; i >= 0; i--) {
            const r = asc[i];
            const d = r.created_at ? new Date(r.created_at) : null;
            const timeTxt = (d && !isNaN(d.getTime()))
                ? (d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0') +
                   ' ' + String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'))
                : '\u2014';
            const amt = injectRecAmount(r);
            // 累计到这一条为止，这家公司一共增资了多少
            let cum = 0;
            for (let j = 0; j <= i; j++) {
                if (String(asc[j].company_id) === String(r.company_id)) cum += injectRecAmount(asc[j]);
            }
            const isMine = !!(myCompany && Number(myCompany.id) === Number(r.company_id));
            const poolShares = isMine ? (Number(myCompany.pool_shares) || 0) : 0;
            const poolCashNow = isMine ? (Number(myCompany.pool_cash) || 0) : 0;
            let priceTxt;
            if (isMine && poolShares > 0 && poolCashNow >= 0 && cum > 0) {
                // 现在池子现金 - 这条之后的增资额 = 这一条刚结束时的池子现金
                let after = 0;
                for (let j = i + 1; j < asc.length; j++) {
                    if (String(asc[j].company_id) === String(r.company_id)) after += injectRecAmount(asc[j]);
                }
                priceTxt = formatPrice(safeDiv(Math.max(0, poolCashNow - after), poolShares));
            } else {
                // 池子股数取不到（不是自己的公司）→ 退回后端记录的成交后价格
                priceTxt = formatPrice(Number(r.price_after) || 0);
            }
            const info = injectionLockInfo(r);
            const lockTxt = info.locked
                ? '<span style="color:#f44336;" title="' + escapeHtml(lockTip(info)) + '">\U0001F512 锁定期' +
                  (info.days > 0 ? '还剩 ' + info.days + ' 天' : '未结束') + '</span>'
                : '<span style="color:#4caf50;">\u2705 已解锁</span>';
            html += '<tr>' +
                '<td style="font-family:monospace;">' + timeTxt + '</td>' +
                '<td>' + escapeHtml(r.company_name || ('公司#' + r.company_id)) + '</td>' +
                '<td style="font-family:monospace; color:#f44336;">+' + fmtNbInt(amt) + '</td>' +
                '<td style="font-family:monospace;">' + priceTxt + '</td>' +
                '<td>' + lockTxt + '</td>' +
                '</tr>';
        }
        html += '</tbody></table>';
        box.innerHTML = html;
    }

    // 「我的公司」区块里的锁定期说明（增资后 7 天内不能卖出）
    function myCompanyLockHtml() {
        if (!myCompany) return '';
        const info = isSellLocked(myCompany.id);
        if (!info.locked) return '';
        return ' \u00b7 <span style="color:#f44336;" title="' + escapeHtml(lockTip(info)) + '">\U0001F512 锁定期' +
            (info.days > 0 ? '还剩 ' + info.days + ' 天' : '未结束') + '，暂不能卖出</span>';
    }

"""


# ============================================================
# 1) 两个页面各自的「增资」样式 / 按钮
# ============================================================
ROOT_CSS = u"""        /* 「增资」按钮与快捷档位（创始人专属；颜色全部走本页 CSS 变量） */
        .company-btn.inject-btn { background: linear-gradient(135deg, #10b981, #059669); color: #fff; }
        .company-btn.inject-btn:hover { background: linear-gradient(135deg, #059669, #047857); }
        #injectQuickRow .company-btn.inject-chip:hover { background: var(--nav-btn-hover-bg); color: white; }
        #injectAmount { -moz-appearance: textfield; appearance: textfield; }
        #injectAmount::-webkit-outer-spin-button,
        #injectAmount::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }

"""

ROOT_BTN = u"""                <button id="injectBtn" class="company-btn inject-btn" title="\U0001F4B0 给公司资金池打钱：股价上涨（全体股东受益），不获得任何股份；增资后 7 天内不能卖出">\U0001F4B0 增资</button>
                <button id="dividendBtn" class="company-btn" style="background:linear-gradient(135deg,#f59e0b,#d97706);color:#fff;border:none;">\U0001F4B8 分红</button>
"""

BETA_CSS = u"""        /* 「增资」按钮与快捷档位（创始人专属；颜色全部走主题变量，7 套主题都看得见） */
        .company-btn.inject-btn { background: linear-gradient(135deg, var(--brand, #10b981), var(--brand-deep, #059669)); color: #fff; }
        .company-btn.inject-btn:hover { filter: brightness(.92); }
        #injectQuickRow .company-btn.inject-chip:hover { background: var(--brand); color: #fff; }
        #injectAmount {
            -webkit-appearance: none; appearance: none;
            border: 1px solid var(--card-border); background: var(--bg-color); color: var(--text-color);
            border-radius: 30px; padding: 8px 14px; margin: 6px 0; flex: 1; min-width: 150px;
            font-size: 1rem; font-family: inherit;
        }
        #injectAmount::-webkit-outer-spin-button,
        #injectAmount::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
        #injectModal .modal-content { max-width: 470px; text-align: left; }
        #injectModal .inject-panel {
            margin: 12px 0 6px; padding: 10px 12px; border-radius: 12px;
            background: var(--count-bg); border: 1px solid var(--card-border);
            font-size: .85rem; line-height: 2; color: var(--text-color);
        }
        #injectModal .inject-warn {
            font-size: .78rem; line-height: 1.85; padding: 10px 12px; border-radius: 12px;
            background: var(--count-bg); border: 1px solid var(--card-border); color: var(--text-color);
        }
        #injectModal .inject-warn > div { margin-top: 6px; }
        #injectModal .inject-warn > div:first-child { margin-top: 0; }

"""

BETA_BTN = u"""                <button id="injectBtn" class="company-btn inject-btn" title="\U0001F4B0 给公司资金池打钱：股价上涨（全体股东受益），不获得任何股份；增资后 7 天内不能卖出">\U0001F4B0 增资</button>
                <button id="dividendBtn" class="company-btn" style="background:linear-gradient(135deg,#f59e0b,#d97706);color:#fff;border:none;">\U0001F4B8 分红</button>
"""


# ============================================================
# 2) 增资弹窗 HTML（结构相同；Beta 用类 + 变量，根目录沿用行内 + 变量）
# ============================================================
MODAL_STRUCT = u"""<!-- 增资弹窗（创始人专属：往自己公司的 AMM 资金池打钱，不获得任何股份） -->
<div id="injectModal" class="custom-modal">
    <div class="modal-content" style="max-width: 470px; text-align: left;">
        <h3 style="text-align:center; margin-bottom:12px;">\U0001F4B0 给「<span id="injectCompanyName"></span>」增资</h3>
        <div style="font-size:0.9rem;">
            <label for="injectAmount" style="font-size:0.85rem;">金额</label>
            <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
                <input type="number" id="injectAmount" min="1000" step="1" value="" placeholder="最低 1000"
                       style="flex:1; min-width:140px; padding:8px; margin:6px 0; border-radius:30px; border:1px solid var(--card-border); background:var(--bg-color); color:var(--text-color);">
                <span style="font-size:0.85rem;">NB币</span>
            </div>
            <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap; margin-bottom:4px;">
                <span style="font-size:0.78rem; color:var(--count-text);">快捷：</span>
                <span id="injectQuickRow" style="display:flex; gap:6px; flex-wrap:wrap;"></span>
            </div>
            <div id="injectMsg" style="font-size:0.8rem; color:var(--count-text); min-height:1.4em; line-height:1.6;"></div>
        </div>
        <div style="margin:12px 0 6px; padding:10px 12px; border-radius:12px; background:var(--count-bg); border:1px solid var(--card-border); font-size:0.85rem; line-height:2;">
            <div style="display:flex; justify-content:space-between; gap:8px;"><span>当前股价</span><strong id="injectCurrentPrice" style="font-family:monospace;">-</strong></div>
            <div style="display:flex; justify-content:space-between; gap:8px;"><span>增资后股价</span><span><strong id="injectAfterPrice" style="font-family:monospace;">-</strong> <span id="injectPct" style="font-size:0.78rem;"></span></span></div>
            <div style="display:flex; justify-content:space-between; gap:8px;"><span>你的余额</span><strong style="font-family:monospace;"><span id="injectBalance">-</span> NB币</strong></div>
        </div>
        <div style="font-size:0.78rem; line-height:1.85; color:var(--count-text); padding:10px 12px; border-radius:12px; background:var(--count-bg); border:1px solid var(--card-border);">
            <div style="color:var(--text-color);">\u26a0\ufe0f 增资不会获得任何股份，钱会变成公司的资金。你能拿回来只有两个途径：分红（全体股东一起分）或清算（按持股比例分）。</div>
            <div style="color:var(--text-color); margin-top:6px;">\u26a0\ufe0f 增资后 7 天内，你不能卖出这家公司的股份。</div>
        </div>
        <div style="display:flex; gap:10px; margin-top:14px;">
            <button id="injectCancelBtn" class="cancel" style="flex:1;">取消</button>
            <button id="injectOkBtn" style="flex:1; background:#f59e0b; color:#fff;">\U0001F4B0 确认增资</button>
        </div>
    </div>
</div>

"""

MODAL_BETA = (MODAL_STRUCT
              .replace(u'<div id="injectModal" class="custom-modal">',
                       u'<div id="injectModal" class="custom-modal">')
              .replace(u'<div style="margin:12px 0 6px; padding:10px 12px; border-radius:12px; background:var(--count-bg); border:1px solid var(--card-border); font-size:0.85rem; line-height:2;">',
                       u'<div class="inject-panel">')
              .replace(u'<div style="font-size:0.78rem; line-height:1.85; color:var(--count-text); padding:10px 12px; border-radius:12px; background:var(--count-bg); border:1px solid var(--card-border);">',
                       u'<div class="inject-warn">')
              .replace(u'<div style="color:var(--text-color); margin-top:6px;">',
                       u'<div>')
              .replace(u'<div style="color:var(--text-color);">\u26a0\ufe0f 增资不会',
                       u'<div>\u26a0\ufe0f 增资不会'))


# ============================================================
# 3) 每个页面的替换清单
# ============================================================
def build_pairs(variant):
    root = (variant == 'root')
    css = ROOT_CSS if root else BETA_CSS
    btn = ROOT_BTN if root else BETA_BTN
    modal = MODAL_STRUCT if root else MODAL_BETA

    if root:
        path = os.path.join(ROOT, u'Virtual stock.html')
        a_css = u"""        .danger-btn:hover { background: #c82333; }
        /* 自定义模态框 */
"""
        a_css_new = u"""        .danger-btn:hover { background: #c82333; }
""" + css + u"""        /* 自定义模态框 */
"""
        a_holdings = (u'            <div id="holdingsList" style="width:100%; font-size:0.9rem; overflow-x:auto;">\u52a0\u8f7d\u4e2d...</div>\n'
                      u'        </div>\n')
        a_modal = u"""<script>
    if (typeof supabase === 'undefined' && typeof window.supabase !== 'undefined') { var supabase = window.supabase; }
"""
        a_init = u"""            await fetchMyCompany();
            await fetchAllCompanies();
            renderMyCompanySection();
            await refreshStockDataFromDB();
            await buildChartWithFade(currentChartType);
            startAutoRefreshTimer();
"""
        a_init_new = u"""            await fetchMyCompany();
            await fetchAllCompanies();
            await fetchMyInjections();      // 增资锁定期（先拿到，再渲染按钮）
            renderMyCompanySection();
            await refreshStockDataFromDB();
            await buildChartWithFade(currentChartType);
            startAutoRefreshTimer();
"""
        a_cap = u"""        // 提示行：买入看余额与滑点，卖出看持股 + 池子能变现的上限
        const capHint = document.getElementById('tradeCapHint');
"""
        a_cap_new = u"""        // 增资锁定期：这家公司刚增资过的话，7 天内不能卖出
        const sellLock = isSellLocked(companyId);
        const lockNotice = document.getElementById('tradeLockNotice');
        if (lockNotice) {
            if (sellLock.locked) {
                lockNotice.innerText = '\U0001F512 你在 7 天增资锁定期内（' + (sellLock.days > 0 ? '还剩 ' + sellLock.days + ' 天' : '未结束') +
                    '），暂时不能卖出「' + companyName + '」的股份。';
                lockNotice.style.display = 'block';
            } else {
                lockNotice.style.display = 'none';
            }
        }
        const sellLocked = (mode === 'sell' && sellLock.locked);

        // 提示行：买入看余额与滑点，卖出看持股 + 池子能变现的上限
        const capHint = document.getElementById('tradeCapHint');
"""
        a_cap_hint_html = u"""            <div id="tradeCapHint" style="font-size:0.8rem; color:var(--count-text); display:none; line-height:1.7; white-space:pre-line;"></div>
"""
        a_cap_hint_html_new = (u'            <div id="tradeLockNotice" style="display:none; font-size:0.8rem; color:#f44336; line-height:1.7; font-weight:700; margin-bottom:4px;"></div>\n'
                               + a_cap_hint_html)
        a_bind = u"""        buyBtn.onclick = () => executeTrade('buy');
        sellBtn.onclick = () => executeTrade('sell');
"""
        a_bind_new = u"""        buyBtn.onclick = () => executeTrade('buy');
        sellBtn.onclick = () => executeTrade('sell');
        // 锁定期内：卖出按钮变灰 + 不可点
        sellBtn.disabled = !!sellLocked;
        sellBtn.style.opacity = sellLocked ? '.5' : '';
        sellBtn.style.cursor = sellLocked ? 'not-allowed' : 'pointer';
        sellBtn.title = sellLocked ? lockTip(sellLock) : '';
"""
        a_exec = u"""        // 卖出：数量超过持股只提示，后端 LEAST(份额, 持仓) 会自动截断成全部卖出
        if (mode === 'sell' && tradeState.myShares > 0 && amount > tradeState.myShares + 1e-9) {
"""
        a_exec_new = u"""        // 增资锁定期内不允许卖出（后端同样会拦，这里先给个明确提示）
        if (mode === 'sell') {
            const lk = isSellLocked(tradeState.companyId);
            if (lk.locked) { await showMessage('暂不能卖出', '增资后 7 天内不能卖出（' + (lk.days > 0 ? '还剩 ' + lk.days + ' 天' : '锁定期未结束') + '）。'); return; }
        }
        // 卖出：数量超过持股只提示，后端 LEAST(份额, 持仓) 会自动截断成全部卖出
        if (mode === 'sell' && tradeState.myShares > 0 && amount > tradeState.myShares + 1e-9) {
"""
        a_hold_sell = u"""            const trading = isTradingHours();
            const tradeBtns = trading
                ? `<button class="trade-btn buy" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#f44336; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem; margin-right:4px;">买入</button>
                   <button class="trade-btn sell" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`
                : '<span style="color:var(--count-text); font-size:0.75rem;">\U0001F634 休市</span>';
"""
        a_hold_sell_new = u"""            const trading = isTradingHours();
            // 增资锁定期内：卖出按钮变灰 + 不可点
            const hLock = isSellLocked(h.company_id);
            const tradeBtns = trading
                ? `<button class="trade-btn buy" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#f44336; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem; margin-right:4px;">买入</button>
                   ${hLock.locked
                        ? `<button class="trade-btn sell locked" data-locked="1" title="${escapeHtml(lockTip(hLock))}" style="background:#9e9e9e; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:not-allowed; font-size:0.75rem;">\U0001F512 锁定</button>`
                        : `<button class="trade-btn sell" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`}`
                : '<span style="color:var(--count-text); font-size:0.75rem;">\U0001F634 休市</span>';
            const lockNote = lockNoteHtml(h.company_id);
"""
        a_hold_row = u"""                <td>${profitHtml}</td>
                <td>${tradeBtns}</td>
            </tr>`;
"""
        a_hold_row_new = u"""                <td>${profitHtml}</td>
                <td>${tradeBtns}${lockNote}</td>
            </tr>`;
"""
        a_hold_bind = u"""        list.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
"""
        a_hold_bind_new = u"""        list.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = async (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                if (btn.getAttribute('data-locked') === '1') {
                    const lk = isSellLocked(companyId);
                    await showMessage('暂不能卖出', '增资后 7 天内不能卖出（' + (lk.days > 0 ? '还剩 ' + lk.days + ' 天' : '锁定期未结束') + '）。');
                    return;
                }
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
"""
        a_dt_sell = u"""                       <button class="trade-btn sell" data-id="${item.id}" data-name="${escapeHtml(item.name)}" data-price="${item.price}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`
"""
        a_dt_lock = u"""            const itemLock = isSellLocked(item.id);
            const lockNote = lockNoteHtml(item.id);
"""
        a_dt_row = u"""                <td>${changeHtml}</td>
                <td>${tradeBtns}</td>
            </tr>`;
"""
        a_dt_row_new = u"""                <td>${changeHtml}</td>
                <td>${tradeBtns}${lockNote}</td>
            </tr>`;
"""
        a_dt_bind = u"""        document.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
            };
        });

        // \u2705 独立绑定股票名称点击事件
"""
        a_dt_bind_new = u"""        document.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = async (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                if (btn.getAttribute('data-locked') === '1') {
                    const lk = isSellLocked(companyId);
                    await showMessage('暂不能卖出', '增资后 7 天内不能卖出（' + (lk.days > 0 ? '还剩 ' + lk.days + ' 天' : '锁定期未结束') + '）。');
                    return;
                }
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
            };
        });

        // \u2705 独立绑定股票名称点击事件
"""
        a_record_hook = u"""        if (currentUserId) {
            await fetchMyCompany();
            renderMyCompanySection();
        }
    }
"""
        a_record_hook_new = u"""        if (currentUserId) {
            await fetchMyCompany();
            renderMyCompanySection();
            renderInjectionRecords();
        }
    }
"""
        # 根目录的关闭回调只有一行（整段原样保留，只在后面追加增资弹窗的绑定）
        a_endbind = u"""    document.getElementById('tradeCloseBtn')?.addEventListener('click', () => {
        document.getElementById('tradeModal').style.display = 'none';
    });
"""
        a_endbind_new = a_endbind
        a_inject_binds = u"""    document.getElementById('injectOkBtn')?.addEventListener('click', runInject);
    document.getElementById('injectCancelBtn')?.addEventListener('click', closeInjectDialog);
    document.getElementById('injectModal')?.addEventListener('click', (e) => {
        if (e.target && e.target.id === 'injectModal') closeInjectDialog();
    });
"""
    else:
        path = os.path.join(ROOT, u'Beta', u'stock-Beta.html')
        a_css = u"""        .danger-btn:hover { background: #c82333; }
        /* 自定义模态框 */
"""
        a_css_new = u"""        .danger-btn:hover { background: #c82333; }
""" + css + u"""        /* 自定义模态框 */
"""
        a_holdings = (u'            <div id="holdingsList" style="width:100%; font-size:0.9rem; overflow-x:auto;">\u52a0\u8f7d\u4e2d...</div>\n'
                      u'        </div>\n')
        a_modal = u"""<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
"""
        a_init = u"""            await fetchUserBalance();
            await fetchAllCompanies();
            await fetchMyCompany();
            renderMyCompanySection();
            await refreshStockDataFromDB();
"""
        a_init_new = u"""            await fetchUserBalance();
            await fetchAllCompanies();
            await fetchMyCompany();
            await fetchMyInjections();      // 增资锁定期（先拿到，再渲染按钮）
            renderMyCompanySection();
            await refreshStockDataFromDB();
"""
        a_cap = u"""        // 提示行：买入看余额，卖出看持股 + 池子能变现的上限
        const capHint = document.getElementById('tradeCapHint');
"""
        a_cap_new = u"""        // 增资锁定期：这家公司刚增资过的话，7 天内不能卖出
        const sellLock = isSellLocked(companyId);
        const lockNotice = document.getElementById('tradeLockNotice');
        if (lockNotice) {
            if (sellLock.locked) {
                lockNotice.innerText = '\U0001F512 你在 7 天增资锁定期内（' + (sellLock.days > 0 ? '还剩 ' + sellLock.days + ' 天' : '未结束') +
                    '），暂时不能卖出「' + companyName + '」的股份。';
                lockNotice.style.display = 'block';
            } else {
                lockNotice.style.display = 'none';
            }
        }
        const sellLocked = (mode === 'sell' && sellLock.locked);

        // 提示行：买入看余额，卖出看持股 + 池子能变现的上限
        const capHint = document.getElementById('tradeCapHint');
"""
        a_cap_hint_html = u"""            <div id="tradeCapHint" style="font-size:0.8rem; color:#e67e22; display:none;"></div>
"""
        a_cap_hint_html_new = (u'            <div id="tradeLockNotice" style="display:none; font-size:0.8rem; color:#f44336; line-height:1.7; font-weight:700; margin-bottom:4px;"></div>\n'
                               + a_cap_hint_html)
        a_bind = u"""        buyBtn.onclick = () => executeTrade('buy');
        sellBtn.onclick = () => executeTrade('sell');
"""
        a_bind_new = u"""        buyBtn.onclick = () => executeTrade('buy');
        sellBtn.onclick = () => executeTrade('sell');
        // 锁定期内：卖出按钮变灰 + 不可点
        sellBtn.disabled = !!sellLocked;
        sellBtn.style.opacity = sellLocked ? '.5' : '';
        sellBtn.style.cursor = sellLocked ? 'not-allowed' : 'pointer';
        sellBtn.title = sellLocked ? lockTip(sellLock) : '';
"""
        a_exec = u"""        // 卖出：数量超过持股只提示，后端 LEAST(份额, 持仓) 会自动截断成全部卖出
        if (mode === 'sell' && tradeState.myShares > 0 && amount > tradeState.myShares + 1e-9) {
"""
        a_exec_new = u"""        // 增资锁定期内不允许卖出（后端同样会拦，这里先给个明确提示）
        if (mode === 'sell') {
            const lk = isSellLocked(tradeState.companyId);
            if (lk.locked) { await showMessage('暂不能卖出', '增资后 7 天内不能卖出（' + (lk.days > 0 ? '还剩 ' + lk.days + ' 天' : '锁定期未结束') + '）。'); return; }
        }
        // 卖出：数量超过持股只提示，后端 LEAST(份额, 持仓) 会自动截断成全部卖出
        if (mode === 'sell' && tradeState.myShares > 0 && amount > tradeState.myShares + 1e-9) {
"""
        a_hold_sell = u"""            const trading = isTradingHours();
            const tradeBtns = trading
                ? `<button class="trade-btn buy" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#f44336; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem; margin-right:4px;">买入</button>
                   <button class="trade-btn sell" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`
                : '<span style="color:var(--count-text); font-size:0.75rem;">\U0001F634 休市</span>';
"""
        a_hold_sell_new = u"""            const trading = isTradingHours();
            // 增资锁定期内：卖出按钮变灰 + 不可点
            const hLock = isSellLocked(h.company_id);
            const tradeBtns = trading
                ? `<button class="trade-btn buy" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#f44336; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem; margin-right:4px;">买入</button>
                   ${hLock.locked
                        ? `<button class="trade-btn sell locked" data-locked="1" title="${escapeHtml(lockTip(hLock))}" style="background:#9e9e9e; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:not-allowed; font-size:0.75rem;">\U0001F512 锁定</button>`
                        : `<button class="trade-btn sell" data-id="${h.company_id}" data-name="${escapeHtml(h.company_name)}" data-price="${curPrice}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`}`
                : '<span style="color:var(--count-text); font-size:0.75rem;">\U0001F634 休市</span>';
            const lockNote = lockNoteHtml(h.company_id);
"""
        a_hold_row = u"""                <td>${profitHtml}</td>
                <td>${tradeBtns}</td>
            </tr>`;
"""
        a_hold_row_new = u"""                <td>${profitHtml}</td>
                <td>${tradeBtns}${lockNote}</td>
            </tr>`;
"""
        a_hold_bind = u"""        list.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
"""
        a_hold_bind_new = u"""        list.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = async (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                if (btn.getAttribute('data-locked') === '1') {
                    const lk = isSellLocked(companyId);
                    await showMessage('暂不能卖出', '增资后 7 天内不能卖出（' + (lk.days > 0 ? '还剩 ' + lk.days + ' 天' : '锁定期未结束') + '）。');
                    return;
                }
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
"""
        a_dt_sell = u"""                       <button class="trade-btn sell" data-id="${item.id}" data-name="${escapeHtml(item.name)}" data-price="${item.price}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`
"""
        a_dt_lock = u"""            const itemLock = isSellLocked(item.id);
            const lockNote = lockNoteHtml(item.id);
"""
        a_dt_row = u"""                <td>${changeHtml}</td>
                <td>${tradeBtns}</td>
            </tr>`;
"""
        a_dt_row_new = u"""                <td>${changeHtml}</td>
                <td>${tradeBtns}${lockNote}</td>
            </tr>`;
"""
        a_dt_bind = u"""        document.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
            };
        });

        // \u2705 独立绑定股票名称点击事件
"""
        a_dt_bind_new = u"""        document.querySelectorAll('.trade-btn').forEach(btn => {
            btn.onclick = async (e) => {
                e.stopPropagation();
                const companyId = parseInt(btn.dataset.id);
                const companyName = btn.dataset.name;
                const price = parseFloat(btn.dataset.price) || 0;
                if (btn.getAttribute('data-locked') === '1') {
                    const lk = isSellLocked(companyId);
                    await showMessage('暂不能卖出', '增资后 7 天内不能卖出（' + (lk.days > 0 ? '还剩 ' + lk.days + ' 天' : '锁定期未结束') + '）。');
                    return;
                }
                const mode = btn.classList.contains('buy') ? 'buy' : 'sell';
                showTradeDialog(companyId, companyName, price, mode);
            };
        });

        // \u2705 独立绑定股票名称点击事件
"""
        a_record_hook = u"""        if (currentUserId) {
            await fetchMyCompany();
            renderMyCompanySection();
        }
    }
"""
        a_record_hook_new = u"""        if (currentUserId) {
            await fetchMyCompany();
            renderMyCompanySection();
            renderInjectionRecords();
        }
    }
"""
        # Beta 的关闭回调里多一行 tradeState = null;，anchor 必须带上它
        a_endbind = u"""    document.getElementById('tradeCloseBtn')?.addEventListener('click', () => {
        document.getElementById('tradeModal').style.display = 'none';
        tradeState = null;
    });
"""
        a_endbind_new = a_endbind
        a_inject_binds = u"""    document.getElementById('injectOkBtn')?.addEventListener('click', runInject);
    document.getElementById('injectCancelBtn')?.addEventListener('click', closeInjectDialog);
    document.getElementById('injectModal')?.addEventListener('click', (e) => {
        if (e.target && e.target.id === 'injectModal') closeInjectDialog();
    });
"""

    # 公共改动点（两个页面 anchor 相同）
    common = []
    # (1) 公司卡片：总股本那行末尾加锁定期提示
    common.append((
        u"                \u00b7 \u603b\u80a1\u672c: <span style=\"font-family:monospace;\">${formatLarge(myCompany.total_shares)}</span> \u5f20\n                ${statusHtml}\n",
        u"                \u00b7 \u603b\u80a1\u672c: <span style=\"font-family:monospace;\">${formatLarge(myCompany.total_shares)}</span> \u5f20\n                ${statusHtml}\n"
        + LOCK_LINE))
    # (2) 分红按钮前插入「增资」按钮
    common.append((
        u"""                <button id="dividendBtn" class="company-btn" style="background:linear-gradient(135deg,#f59e0b,#d97706);color:#fff;border:none;">\U0001F4B8 分红</button>\n""",
        btn))
    # (3) 绑定增资按钮
    common.append((
        u"""        document.getElementById('dividendBtn')?.addEventListener('click', payDividend);\n""",
        u"""        document.getElementById('dividendBtn')?.addEventListener('click', payDividend);\n        document.getElementById('injectBtn')?.addEventListener('click', () => showInjectDialog(myCompany.pool_cash, myCompany.pool_shares));\n"""))
    # (4) 增资核心 JS：插在 payDividend 之后
    common.append((
        u"""        renderMyCompanySection();
        await showMessage('分红完成', data.message || '分红已发放');
    }
""",
        u"""        renderMyCompanySection();
        await showMessage('分红完成', data.message || '分红已发放');
    }

""" + INJECT_JS))

    # 行情表：一行里要插两处 —— 先在行首算好变量，再把卖出按钮换成灰色「锁定」。
    a_dt_head = u"""            const reportBtn = (item.id && item.id !== 'undefined' && !isNaN(item.id))
                ? `<button class="report-company-btn" data-company-id="${item.id}" data-company-name="${escapeHtml(item.name)}" style="background:none; border:none; color:#ff6b6b; cursor:pointer; font-size:0.7rem;">\U0001F6A8 举报公司</button>`
                : '';
            const trading = isTradingHours();
            const tradeBtns = currentUserId
                ? (trading
                    ? `<button class="trade-btn buy" data-id="${item.id}" data-name="${escapeHtml(item.name)}" data-price="${item.price}" style="background:#f44336; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem; margin-right:4px;">买入</button>
                       <button class="trade-btn sell" data-id="${item.id}" data-name="${escapeHtml(item.name)}" data-price="${item.price}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`
"""
    # 卖出按钮本体（不带行首缩进，方便在 a_dt_head 里定位；替换时再补回缩进）
    a_dt_sell = u"""<button class="trade-btn sell" data-id="${item.id}" data-name="${escapeHtml(item.name)}" data-price="${item.price}" style="background:#4caf50; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:pointer; font-size:0.75rem;">卖出</button>`
"""
    if a_dt_sell not in a_dt_head:
        raise SystemExit('a_dt_sell 不在 a_dt_head 里')
    # 先在行首插入两个变量，再单独把卖出按钮换掉（两处独立替换，互不干扰）
    a_dt_head_new = (u"""            const itemLock = isSellLocked(item.id);
            const lockNote = lockNoteHtml(item.id);
""" + a_dt_head)
    a_dt_sell_new = (u'${itemLock.locked\n'
                     + u'                        ? `<button class="trade-btn sell locked" data-locked="1" title="${escapeHtml(lockTip(itemLock))}" style="background:#9e9e9e; color:white; border:none; border-radius:20px; padding:3px 12px; cursor:not-allowed; font-size:0.75rem;">\U0001F512 锁定</button>`\n'
                     + u'                        : `' + a_dt_sell + u'}`\n')

    # 两个源文件都是 CRLF：统一按「LF 版」写 anchor，比对/插入时再转成 CRLF，
    # 这样既不用在几十个 anchor 里手写 \r\n，也能保证原有行尾风格不变。
    def to_lf(t):
        return t.replace(u'\r\n', u'\n')

    def to_crlf(t):
        return t.replace(u'\r\n', u'\n').replace(u'\n', u'\r\n')

    pairs = [
        (to_lf(a_css), to_lf(a_css_new)),                           # 增资样式
        (to_lf(a_holdings), to_lf(a_holdings + RECORDS_SECTION)),   # 增资记录区块
    ] + [(to_lf(o), to_lf(n)) for (o, n) in common] + [
        (to_lf(a_modal), to_lf(modal + a_modal)),                   # 增资弹窗
        (to_lf(a_init), to_lf(a_init_new)),                         # 页面加载时拉一次锁定期
        (to_lf(a_record_hook), to_lf(a_record_hook_new)),           # 刷新时同步增资记录
        (to_lf(a_hold_sell), to_lf(a_hold_sell_new)),               # 持仓表：锁定按钮 + 红字说明
        (to_lf(a_hold_row), to_lf(a_hold_row_new)),                 # 持仓表：把红字说明放进单元格
        (to_lf(a_dt_head), to_lf(a_dt_head_new)),                   # 行情表：行首加锁定变量
        (to_lf(a_dt_sell), to_lf(a_dt_sell_new)),                   # 行情表：卖出按钮换成「锁定」
        (to_lf(a_dt_row), to_lf(a_dt_row_new)),                     # 行情表：把红字说明放进单元格
        (to_lf(a_cap_hint_html), to_lf(a_cap_hint_html_new)),       # 交易弹窗加锁定期红字行
        (to_lf(a_cap), to_lf(a_cap_new)),                           # 计算 sellLock
        (to_lf(a_bind), to_lf(a_bind_new)),                         # 卖出按钮置灰
        (to_lf(a_exec), to_lf(a_exec_new)),                         # 提交前兜底拦截
        (to_lf(a_hold_bind), to_lf(a_hold_bind_new)),               # 持仓表卖出按钮事件：锁定提示
        (to_lf(a_dt_bind), to_lf(a_dt_bind_new)),                   # 行情表卖出按钮事件：锁定提示
        (to_lf(a_endbind), to_lf(a_endbind_new + a_inject_binds)),   # 增资弹窗按钮事件
    ]
    return path, [(o, n) for (o, n) in pairs if o != n]


def apply(path, pairs):
    # 按 LF 读入比对（anchor 都是 LF 版），落盘前再换回 CRLF
    with io.open(path, 'r', encoding='utf-8', newline='') as f:
        s = f.read().replace(u'\r\n', u'\n')
    for i, (old, new) in enumerate(pairs):
        if old == new:
            continue
        n = s.count(old)
        if n != 1:
            raise SystemExit(u'[FAIL] %s 第 %d 个替换命中 %d 次（应为 1 次）:\n%r' % (path, i + 1, n, old[:200]))
        s = s.replace(old, new, 1)
    data = s.replace(u'\n', u'\r\n').encode('utf-8')   # 先 encode 再落盘
    with open(path, 'wb') as f:
        f.write(data)
    return len(data)


def dry_run(path, pairs):
    with io.open(path, 'r', encoding='utf-8', newline='') as f:
        s = f.read().replace(u'\r\n', u'\n')
    bad = []
    for i, (old, new) in enumerate(pairs):
        if old == new:
            continue
        c = s.count(old)
        if c != 1:
            bad.append((i + 1, c, old))
    return bad


if __name__ == '__main__':
    import sys as _sys
    _sys.stdout = io.TextIOWrapper(_sys.stdout.buffer, encoding='utf-8', errors='replace')
    if len(_sys.argv) > 1 and _sys.argv[1] == 'apply':
        for v in ('root', 'beta'):
            p, prs = build_pairs(v)
            n = apply(p, prs)
            print('%-5s %s  %d bytes written' % (v, p, n))
    else:
        for v in ('root', 'beta'):
            p, prs = build_pairs(v)
            bad = dry_run(p, prs)
            print('%-5s %s  (%d replacements, %d bad anchors)' % (v, p, len(prs), len(bad)))
            for (i, c, old) in bad:
                print('   [FAIL %2d] match=%d  %r' % (i, c, old[:170]))
