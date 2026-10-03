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
        if (typeof st.remain !== 'number' || st.remain <= 0) st.remain = DUR[st.phase];
        if (typeof st.endsAt !== 'number') st.endsAt = 0;
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
            st.phase = (st.rounds % 4 === 0) ? 'long' : 'short';
        } else {
            st.phase = 'work';
        }
        st.remain = DUR[st.phase];
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

        if (!document.getElementById(CSS_ID)) {
            var st = document.createElement('style');
            st.id = CSS_ID;
            st.textContent = CSS;
            document.head.appendChild(st);
        }

        var box = document.createElement('div');
        box.id = BOX_ID;
        box.innerHTML =
            '<div class="nb-pomo-panel" data-panel>' +
              '<div class="nb-pomo-head">' +
                '<span class="t">🍅 番茄钟</span>' +
                '<button class="x" data-close title="收起">×</button>' +
              '</div>' +
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
                  '<div class="rd">今日完成 <b data-rounds>0</b> 轮<br>' +
                    '<span data-hint>点小球开始</span></div>' +
                '</div>' +
              '</div>' +
              '<div class="nb-pomo-btns">' +
                '<button data-act="toggle">开始</button>' +
                '<button class="gh" data-act="skip">跳过</button>' +
                '<button class="gh" data-act="reset">重置</button>' +
              '</div>' +
              '<div class="nb-pomo-tip">切页面不会重置 —— 进度按时间戳算，' +
                '换页回来接着走</div>' +
            '</div>' +
            '<button class="nb-pomo-ball" data-ball title="番茄钟">' +
              '<span>🍅</span><span class="mini" data-mini></span>' +
            '</button>';

        document.body.appendChild(box);

        var panel = box.querySelector('[data-panel]');
        var ringEl = box.querySelector('[data-ring]');
        var barEl = box.querySelector('.br');
        var timeEl = box.querySelector('[data-time]');
        var phaseEl = box.querySelector('[data-phase]');
        var roundsEl = box.querySelector('[data-rounds]');
        var hintEl = box.querySelector('[data-hint]');
        var miniEl = box.querySelector('[data-mini]');
        var toggleBtn = box.querySelector('[data-act="toggle"]');
        var ballEl = box.querySelector('[data-ball]');

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
            st.remain = DUR.work;
            st.running = false;
            st.endsAt = 0;
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

            var total = DUR[st.phase];
            var ratio = total > 0 ? Math.max(0, left) / total : 0;
            barEl.style.strokeDashoffset = (CIRC * (1 - ratio)).toFixed(1);
            ringEl.classList.toggle('rest', st.phase !== 'work');

            timeEl.textContent = fmt(left);
            roundsEl.textContent = st.rounds;

            if (st.running) {
                phaseEl.textContent = NAME[st.phase];
                hintEl.textContent = st.phase === 'work' ? '别碰手机' : '起来走走';
                toggleBtn.textContent = '暂停';
            } else {
                phaseEl.textContent = left < total ? '已暂停' : '还没开始';
                hintEl.textContent = '点「开始」';
                toggleBtn.textContent = left < total ? '继续' : '开始';
            }
            miniEl.textContent = fmt(left);

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

        /* 点在面板外收起 */
        document.addEventListener('click', function (e) {
            if (!box.contains(e.target)) panel.classList.remove('open');
        });
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
})();
