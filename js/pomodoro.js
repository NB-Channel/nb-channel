/* ============================================================
   NB频道 · 番茄钟（全局悬浮）
   ------------------------------------------------------------
   只在【护眼主题】下出现。挂在右下角，哪个页面都在，
   切页面不会重置 —— 关键是不存「还剩多少秒」，而是存
   【这一轮什么时候结束】的绝对时间戳，切页后按时间戳重算。

   番茄钟规则（经典的那套）：
     专注 25 分钟 → 短休息 5 分钟
     每完成 4 轮专注 → 长休息 15 分钟

   状态存 localStorage：
     nb_pomo = { phase, endsAt, running, remain, rounds, day }
       phase   work | short | long
       endsAt  本轮结束的绝对时刻（毫秒）
       remain  暂停时剩下的毫秒数（暂停才用得到）
       rounds  今天已完成几轮专注
       day     记录属于哪一天，跨天自动清零
   ============================================================ */
(function () {
    'use strict';

    var KEY = 'nb_pomo';
    var DUR = { work: 25 * 60 * 1000, short: 5 * 60 * 1000, long: 15 * 60 * 1000 };
    var NAME = { work: '专注中', short: '短休息', long: '长休息' };
    var CSS_ID = 'nbPomoCss';
    var BOX_ID = 'nbPomoBox';

    /* ---------- 主题判断 ---------- */
    function isEyecare() {
        return document.documentElement.getAttribute('theme') === 'eyecare';
    }

    /* ---------- 状态 ---------- */
    function today() {
        var d = new Date();
        return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
    }
    function load() {
        var st = null;
        try { st = JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (e) {}
        if (!st || typeof st !== 'object') st = {};
        if (st.day !== today()) { st.rounds = 0; st.day = today(); }
        if (st.phase !== 'work' && st.phase !== 'short' && st.phase !== 'long') st.phase = 'work';
        if (typeof st.running !== 'boolean') st.running = false;
        if (typeof st.rounds !== 'number') st.rounds = 0;
        if (typeof st.remain !== 'number' || st.remain <= 0) st.remain = -1;   /* 占位，下面按 min 重算 */
        if (typeof st.endsAt !== 'number') st.endsAt = 0;
        /* 自定义的三段时长（分钟），没设过就用默认的 25/5/15 */
        if (!st.min || typeof st.min !== 'object') st.min = {};
        ['work', 'short', 'long'].forEach(function (k) {
            var v = parseInt(st.min[k], 10);
            if (!(v >= 1 && v <= 180)) st.min[k] = DUR[k] / 60000;
        });
        if (typeof st.total !== 'number') st.total = 0;   /* 今日专注总分钟 */
        if (st.remain === -1) st.remain = durOf(st, st.phase);
        return st;
    }
    function save(st) {
        try { localStorage.setItem(KEY, JSON.stringify(st)); } catch (e) {}
    }
    /* 当前还剩多少毫秒 */
    function remainOf(st) {
        if (!st.running) return st.remain;
        var r = st.endsAt - Date.now();
        return r > 0 ? r : 0;
    }
    /* 取某一阶段当前的时长（毫秒），以用户设置为准 */
    function durOf(st, phase) {
        return (st.min && st.min[phase] ? st.min[phase] : DUR[phase] / 60000) * 60000;
    }
    function fmt(ms) {
        var s = Math.max(0, Math.ceil(ms / 1000));
        var m = Math.floor(s / 60);
        s = s % 60;
        return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }

    /* ---------- 推进到下一阶段 ---------- */
    function advance(st) {
        if (st.phase === 'work') {
            st.rounds += 1;
            st.total += st.min.work;                    /* 累计今日专注分钟 */
            st.phase = (st.rounds % 4 === 0) ? 'long' : 'short';
        } else {
            st.phase = 'work';
        }
        st.remain = durOf(st, st.phase);
        st.endsAt = Date.now() + st.remain;
        st.running = true;
    }

    /* ---------- 样式 ---------- */
    var CSS = [
        /* bottom 要避开页面右下角的「回到顶部」按钮：
           它是 fixed; right:26px; bottom:26px; 46x46，
           也就是占到 72px 高。所以这里从 88px 起，
           正好压在它上面，中间留 16px 空隙。
           移动端它变成 right:18px; bottom:18px; 42x42（占 60px），
           对应挪到 76px。 */
        '#nbPomoBox{position:fixed;right:24px;bottom:88px;z-index:9998;',
        '  font-family:system-ui,-apple-system,"Microsoft YaHei",sans-serif;}',
        /* 悬浮小球 */
        '.nb-pomo-ball{width:52px;height:52px;border-radius:50%;cursor:pointer;',
        '  border:none;padding:0;font-size:24px;line-height:1;',
        '  background:radial-gradient(circle at 34% 30%,#ff8b7a,#c0392b 70%);',
        '  box-shadow:0 6px 20px -6px rgba(140,47,35,.7),0 2px 6px rgba(0,0,0,.25);',
        '  transition:transform .18s ease;display:flex;align-items:center;justify-content:center;}',
        '.nb-pomo-ball:hover{transform:scale(1.07);}',
        '.nb-pomo-ball .ring{position:absolute;inset:-4px;border-radius:50%;',
        '  border:2px solid rgba(140,47,35,.35);}',
        '.nb-pomo-ball .mini{position:absolute;bottom:-2px;right:-2px;',
        '  background:#3a3630;color:#f4f0e6;font-size:10px;font-weight:700;',
        '  padding:1px 5px;border-radius:8px;letter-spacing:.5px;}',
        /* 展开的面板 */
        /* 面板要给实底：护眼主题那边的规则会覆盖背景类属性，
           不加 !important 会变半透明，后面的正文透上来很糊 */
        '.nb-pomo-panel{position:absolute;right:0;bottom:68px;width:250px;',
        '  background:#fdfbf6 !important;border:1px solid rgba(58,54,48,.2) !important;',
        '  border-radius:14px;box-shadow:0 20px 48px -20px rgba(40,34,26,.55);',
        '  padding:18px 18px 14px;display:none;}',
        '.nb-pomo-panel.open{display:block;animation:nbPomoIn .18s ease-out;}',
        '@keyframes nbPomoIn{from{opacity:0;transform:translateY(8px);}to{opacity:1;transform:none;}}',
        '.nb-pomo-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;}',
        '.nb-pomo-head .t{font-size:.78rem;letter-spacing:2px;color:#6b6459;font-weight:700;}',
        '.nb-pomo-head .x{border:none;background:transparent;cursor:pointer;',
        '  color:#8b8375;font-size:1.1rem;line-height:1;padding:2px 4px;}',
        '.nb-pomo-head .x:hover{color:#8c2f23;}',
        '.nb-pomo-mid{display:flex;align-items:center;gap:14px;}',
        '.nb-pomo-ring{position:relative;width:96px;height:96px;flex:0 0 auto;}',
        '.nb-pomo-ring svg{display:block;transform:rotate(-90deg);}',
        '.nb-pomo-ring .tk{fill:none;stroke:rgba(58,54,48,.14);stroke-width:8;}',
        '.nb-pomo-ring .br{fill:none;stroke:#8c2f23;stroke-width:8;stroke-linecap:round;',
        '  transition:stroke-dashoffset .95s linear,stroke .35s;}',
        '.nb-pomo-ring.rest .br{stroke:#7a8a55;}',
        '.nb-pomo-ring .time{position:absolute;inset:0;display:flex;align-items:center;',
        '  justify-content:center;font-size:1.32rem;font-weight:300;color:#2e2a24 !important;',
        '  font-variant-numeric:tabular-nums;letter-spacing:1px;}',
        '.nb-pomo-side .ph{font-size:.92rem;font-weight:800;color:#2e2a24 !important;letter-spacing:2px;}',
        '.nb-pomo-side .rd{margin-top:8px;font-size:.72rem;color:#7a7266;line-height:1.8;}',
        '.nb-pomo-side .rd b{color:#8c2f23;}',
        '.nb-pomo-btns{display:flex;gap:6px;margin-top:14px;flex-wrap:wrap;}',
        '.nb-pomo-btns button{flex:1;min-width:58px;padding:7px 6px;border-radius:7px;cursor:pointer;',
        '  font-family:inherit;font-size:.72rem;letter-spacing:.5px;border:none;',
        '  background:#6b5a3e;color:#e0d9cb;}',
        '.nb-pomo-btns button:hover{background:#544730;}',
        '.nb-pomo-btns button.gh{background:transparent;color:#6b5a3e;',
        '  border:1px solid rgba(107,90,62,.4);}',
        '.nb-pomo-btns button.gh:hover{background:rgba(107,90,62,.12);}',
        '.nb-pomo-tip{margin-top:10px;font-size:.68rem;color:#8b8375;line-height:1.7;}',
        /* 内嵌模式（首页那块）：整行拉宽，横向排布 */
        '#nbPomoBox.nb-pomo-inline{position:relative;right:auto;bottom:auto;z-index:1;',
        '  width:100%;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-ball{display:none !important;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-panel{position:relative;right:auto;',
        '  bottom:auto;width:100%;max-width:none;display:block !important;',
        '  animation:none;padding:26px 30px 22px;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-ring{width:126px;height:126px;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-ring svg{width:126px;height:126px;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-ring .time{font-size:1.85rem;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-side .ph{font-size:1.12rem;}',
        /* 横向三段：圆环 | 状态与记录 | 按钮 */
        '#nbPomoBox.nb-pomo-inline .nb-pomo-mid{gap:34px;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-body{display:flex;align-items:center;',
        '  justify-content:space-between;gap:34px;flex-wrap:wrap;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-side{flex:1;min-width:190px;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-btns{margin-top:0;flex:0 0 auto;',
        '  flex-direction:column;min-width:120px;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-btns button{width:100%;padding:9px 18px;',
        '  font-size:.78rem;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-head .t{font-size:.86rem;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-head .stat{font-size:.78rem;color:#6b6459;}',
        '#nbPomoBox.nb-pomo-inline .nb-pomo-head .stat b{color:#8c2f23;font-size:.95rem;}',
        /* 今日番茄记录点 */
        '.nb-pomo-dots{display:flex;gap:5px;margin-top:11px;flex-wrap:wrap;}',
        '.nb-pomo-dots i{width:13px;height:13px;border-radius:50%;display:block;',
        '  background:rgba(58,54,48,.16);}',
        '.nb-pomo-dots i.on{background:#c0392b;}',
        '.nb-pomo-dots i.now{box-shadow:0 0 0 2px rgba(192,57,43,.3);}',
        /* 时长设置 */
        '.nb-pomo-cfg{display:flex;gap:20px;flex-wrap:wrap;margin-top:18px;',
        '  padding-top:16px;border-top:1px dashed rgba(58,54,48,.16);',
        '  font-size:.74rem;color:#7a7266;align-items:center;}',
        '.nb-pomo-cfg label{display:flex;align-items:center;gap:7px;}',
        '.nb-pomo-cfg input{width:56px;padding:5px 7px;border-radius:6px;text-align:center;',
        '  border:1px solid rgba(58,54,48,.24);background:#fff;color:#3a3630;',
        '  font-family:inherit;font-size:.78rem;outline:none;}',
        '.nb-pomo-cfg input:focus{border-color:#8c2f23;}',
        '.nb-pomo-cfg .reset{margin-left:auto;padding:5px 12px;border-radius:6px;',
        '  cursor:pointer;font-family:inherit;font-size:.72rem;border:none;',
        '  background:rgba(107,90,62,.14);color:#6b5a3e;}',
        '.nb-pomo-cfg .reset:hover{background:rgba(107,90,62,.26);}',
        '@media(max-width:520px){',
        '  #nbPomoBox{right:16px;bottom:76px;}',
        '  .nb-pomo-panel{width:calc(100vw - 32px);right:0;}',
        '}',
        '@media(prefers-reduced-motion:reduce){',
        '  .nb-pomo-panel.open{animation:none;}',
        '  .nb-pomo-ball{transition:none;}',
        '}'
    ].join('\n');

    /* ---------- 面板 HTML ---------- */
    var R = 42, CIRC = 2 * Math.PI * R;

    function build() {
        if (document.getElementById(BOX_ID)) return;
        if (!isEyecare()) return;

        /* 页面上如果给了内嵌容器（首页就有），就渲染到那儿去，
           这种情况下不再建右下角的悬浮球，免得两处重复。 */
        var inlineHost = document.getElementById('nbPomoInline');

        if (!document.getElementById(CSS_ID)) {
            var st = document.createElement('style');
            st.id = CSS_ID;
            st.textContent = CSS;
            document.head.appendChild(st);
        }

        var box = document.createElement('div');
        box.id = BOX_ID;
        if (inlineHost) box.className = 'nb-pomo-inline';
        box.innerHTML =
            '<div class="nb-pomo-panel" data-panel>' +
              '<div class="nb-pomo-head">' +
                '<span class="t">🍅 番茄钟</span>' +
                '<span class="stat" data-stat></span>' +
                '<button class="x" data-close title="收起">×</button>' +
              '</div>' +
              '<div class="nb-pomo-body">' +
              '<div class="nb-pomo-mid">' +
                '<div class="nb-pomo-ring" data-ring>' +
                  '<svg width="96" height="96" viewBox="0 0 96 96">' +
                    '<circle class="tk" cx="48" cy="48" r="' + R + '"/>' +
                    '<circle class="br" cx="48" cy="48" r="' + R + '" ' +
                      'stroke-dasharray="' + CIRC.toFixed(1) + '" stroke-dashoffset="0"/>' +
                  '</svg>' +
                  '<div class="time" data-time>25:00</div>' +
                '</div>' +
                '<div class="nb-pomo-side">' +
                  '<div class="ph" data-phase>还没开始</div>' +
                  '<div class="rd"><span data-hint>点「开始」进入专注</span></div>' +
                  '<div class="nb-pomo-dots" data-dots></div>' +
                '</div>' +
              '</div>' +
              '<div class="nb-pomo-btns">' +
                '<button data-act="toggle">开始</button>' +
                '<button class="gh" data-act="skip">跳过</button>' +
                '<button class="gh" data-act="reset">重置</button>' +
              '</div>' +
              '</div>' +
              '<div class="nb-pomo-cfg">' +
                '<label>专注 <input type="number" min="1" max="180" data-min="work"> 分</label>' +
                '<label>短休息 <input type="number" min="1" max="60" data-min="short"> 分</label>' +
                '<label>长休息 <input type="number" min="1" max="90" data-min="long"> 分</label>' +
                '<button class="reset" data-act="defdur">恢复默认</button>' +
              '</div>' +
              '<div class="nb-pomo-tip">切页面不会重置 —— 进度按时间戳算，' +
                '换页回来接着走。每 4 轮专注后自动进长休息</div>' +
            '</div>' +
            '<button class="nb-pomo-ball" data-ball title="番茄钟">' +
              '<span>🍅</span><span class="mini" data-mini></span>' +
            '</button>';

        (inlineHost || document.body).appendChild(box);

        var panel = box.querySelector('[data-panel]');
        var ringEl = box.querySelector('[data-ring]');
        var barEl = box.querySelector('.br');
        var timeEl = box.querySelector('[data-time]');
        var phaseEl = box.querySelector('[data-phase]');
        var statEl = box.querySelector('[data-stat]');
        var dotsEl = box.querySelector('[data-dots]');
        var hintEl = box.querySelector('[data-hint]');
        var miniEl = box.querySelector('[data-mini]');
        var toggleBtn = box.querySelector('[data-act="toggle"]');
        var ballEl = box.querySelector('[data-ball]');

        /* 内嵌模式：小球藏起来、面板常开（它本来就是页面的一部分）。
           注意这段必须放在上面那批 querySelector 之后 ——
           之前写在了 appendChild 后面，panel 还是 undefined，
           一调 classList 就抛错，后面的 render() 全没执行。 */
        if (inlineHost) {
            if (ballEl) ballEl.style.display = 'none';
            panel.classList.add('open');
        }

        /* 点小球：展开 / 收起 */
        ballEl.addEventListener('click', function () {
            panel.classList.toggle('open');
        });
        box.querySelector('[data-close]').addEventListener('click', function () {
            panel.classList.remove('open');
        });

        /* 操作 */
        toggleBtn.addEventListener('click', function () {
            var st = load();
            if (st.running) {                       /* 暂停：把剩余固化下来 */
                st.remain = remainOf(st);
                st.running = false;
            } else {                                /* 继续：从剩余重新起算 */
                st.endsAt = Date.now() + st.remain;
                st.running = true;
            }
            save(st);
            render();
        });
        box.querySelector('[data-act="skip"]').addEventListener('click', function () {
            var st = load();
            advance(st);
            save(st);
            render();
        });
        box.querySelector('[data-act="reset"]').addEventListener('click', function () {
            var st = load();
            st.phase = 'work';
            st.remain = durOf(st, 'work');
            st.running = false;
            st.endsAt = 0;
            save(st);
            render();
        });

        /* ---------- 时长设置 ---------- */
        box.querySelectorAll('[data-min]').forEach(function (inp) {
            inp.addEventListener('change', function () {
                var st = load();
                var v = parseInt(inp.value, 10);
                if (!(v >= 1 && v <= 180)) { inp.value = st.min[inp.dataset.min]; return; }
                st.min[inp.dataset.min] = v;
                /* 改的正好是当前阶段、又没在跑，就顺手把剩余时间也更新 */
                if (st.phase === inp.dataset.min && !st.running) {
                    st.remain = durOf(st, st.phase);
                }
                save(st);
                render();
            });
        });
        box.querySelector('[data-act="defdur"]').addEventListener('click', function () {
            var st = load();
            st.min = { work: 25, short: 5, long: 15 };
            st.remain = durOf(st, st.phase);
            if (st.running) st.endsAt = Date.now() + st.remain;
            save(st);
            render();
        });

        /* ---------- 渲染 ---------- */
        function render() {
            var st = load();
            var left = remainOf(st);

            /* 时间到了：自动推进（可能是关着页面时走完的，所以用 while） */
            var guard = 0;
            while (st.running && left <= 0 && guard++ < 8) {
                advance(st);
                save(st);
                st = load();
                left = remainOf(st);
            }

            var total = durOf(st, st.phase);
            var ratio = total > 0 ? Math.max(0, left) / total : 0;
            barEl.style.strokeDashoffset = (CIRC * (1 - ratio)).toFixed(1);
            ringEl.classList.toggle('rest', st.phase !== 'work');

            timeEl.textContent = fmt(left);

            /* 顶部统计 */
            var hh = Math.floor(st.total / 60), mm = st.total % 60;
            if (statEl) statEl.innerHTML = '今日 <b>' + st.rounds + '</b> 轮' +
                (st.total > 0 ? ' · 专注 <b>' + (hh > 0 ? hh + ' 时 ' : '') + mm + '</b> 分' : '');

            /* 今日番茄记录点：8 个格子，超出就折叠显示 */
            var SHOW = 8;
            var n = Math.min(st.rounds, SHOW);
            var html = '';
            for (var i = 0; i < SHOW; i++) {
                var cls = i < n ? 'on' : '';
                if (i === n && st.phase === 'work' && st.running) cls += ' now';
                html += '<i class="' + cls + '"></i>';
            }
            if (st.rounds > SHOW) html += '<span style="font-size:.7rem;color:#8c2f23;' +
                'align-self:center;margin-left:4px">+' + (st.rounds - SHOW) + '</span>';
            if (dotsEl) dotsEl.innerHTML = html;

            if (st.running) {
                phaseEl.textContent = NAME[st.phase];
                hintEl.textContent = st.phase === 'work'
                    ? (st.rounds % 4 === 3 ? '这轮结束就长休息' : '别碰手机')
                    : '起来走走，看看远处';
                toggleBtn.textContent = '暂停';
            } else {
                phaseEl.textContent = left < total ? '已暂停' : '还没开始';
                hintEl.textContent = '点「开始」进入专注';
                toggleBtn.textContent = left < total ? '继续' : '开始';
            }
            miniEl.textContent = fmt(left);

            /* 时长输入框同步（别在用户正在输入时覆盖） */
            box.querySelectorAll('[data-min]').forEach(function (inp) {
                if (document.activeElement === inp) return;
                var v = st.min[inp.dataset.min];
                if (inp.value !== String(v)) inp.value = v;
            });

            /* 标签页标题也带上，切到别的标签也能看见 */
            var base = document.title.replace(/^🍅 [\d:]+ · /, '');
            document.title = (st.running ? '🍅 ' + fmt(left) + ' · ' : '') + base;
        }

        render();
        setInterval(render, 1000);

        /* 页面从后台切回来时立刻刷新一次（浏览器会节流定时器） */
        document.addEventListener('visibilitychange', function () {
            if (!document.hidden) render();
        });

        /* 点在面板外收起（内嵌模式不收起） */
        if (!inlineHost) {
            document.addEventListener('click', function (e) {
                if (!box.contains(e.target)) panel.classList.remove('open');
            });
        }
    }

    function destroy() {
        var b = document.getElementById(BOX_ID);
        if (b) b.remove();
        var c = document.getElementById(CSS_ID);
        if (c) c.remove();
    }

    function boot() {
        build();
        /* 主题切换时跟着显示 / 隐藏 */
        window.addEventListener('nb-theme-change', function () {
            destroy();
            build();
        });
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
    /* 给外面调：首页那边挂上内嵌容器后会喊一声，这里重建一次 */
    window.NBPomo = {
        rebuild: function () { destroy(); build(); },
        KEY: KEY,
        DUR: DUR
    };

})();
