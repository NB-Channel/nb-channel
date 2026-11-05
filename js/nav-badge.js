/* ==========================================================
   导航栏未读红点（Beta 页专用补丁）
   ----------------------------------------------------------
   普通版靠 js/common.js 里的 updateUnreadBadge() / updateChatBadge()，
   但 Beta 页不引 common.js，所以导航上的「🔔 消息」「💬 好友」没有红点。

   这个文件做的事：
     1. 找导航里的「消息」「好友」链接（同时兼容 xxx.html 和 xxx-Beta.html）
     2. 用 anon key 直接调 RPC
          get_unread_counts   → 消息中心未读（回复 / @提及 / 点赞…）
          get_unread_messages → 私信未读
     3. 在链接后插一个红点数字徽章，每 60 秒刷新
     4. 未登录 / 请求失败就静默跳过，不打断页面
   ========================================================== */
(function () {
    var SUPABASE_URL = 'https://pbaafgjkwdbwcmsikcmg.supabase.co';
    var ANON = 'sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg';

    function user() {
        try {
            var u = JSON.parse(localStorage.getItem('nb_user') || 'null');
            if (!u || !u.id) return null;
            return { id: u.id, session: localStorage.getItem('nb_session') || '' };
        } catch (e) { return null; }
    }

    // 找导航链接：优先 -Beta 版路径，其次普通版
    function findLink(names) {
        for (var i = 0; i < names.length; i++) {
            var el = document.querySelector('a[href="' + names[i] + '"]') ||
                     document.querySelector('a[href$="/' + names[i] + '"]');
            if (el) return el;
        }
        return null;
    }

    function ensureBadge(link) {
        var b = link.querySelector('.nav-badge');
        if (!b) {
            b = document.createElement('span');
            b.className = 'nav-badge';
            b.style.cssText = 'display:none;background:#ff4757;color:#fff;border-radius:9px;' +
                'font-size:0.65rem;min-width:16px;height:16px;line-height:16px;text-align:center;' +
                'padding:0 4px;margin-left:4px;vertical-align:middle;font-weight:700;';
            link.appendChild(b);
        }
        return b;
    }

    function setBadge(link, n) {
        var b = ensureBadge(link);
        if (n > 0) {
            b.textContent = n > 99 ? '99+' : String(n);
            b.style.display = 'inline-block';
        } else {
            b.style.display = 'none';
        }
    }

    function rpc(fn, body) {
        return fetch(SUPABASE_URL + '/rest/v1/rpc/' + fn, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': ANON,
                'Authorization': 'Bearer ' + ANON
            },
            body: JSON.stringify(body),
            cache: 'no-store'
        }).then(function (r) { return r.ok ? r.json() : null; }).catch(function () { return null; });
    }

    function refresh() {
        var u = user();
        if (!u) return;

        // 消息中心
        var msgLink = findLink(['messages-Beta.html', 'messages.html']);
        if (msgLink) {
            rpc('get_unread_counts', { p_user_id: u.id, p_session: u.session }).then(function (d) {
                var total = 0;
                if (Array.isArray(d)) {
                    d.forEach(function (x) { total += (x && x.count) || 0; });
                } else if (d && typeof d === 'object') {
                    Object.keys(d).forEach(function (k) {
                        var v = d[k];
                        if (typeof v === 'number') total += v;
                    });
                }
                setBadge(msgLink, total);
            });
        }

        // 好友私信
        var chatLink = findLink(['chat-Beta.html', 'chat.html']);
        if (chatLink) {
            rpc('get_unread_messages', { p_user: u.id, p_session: u.session }).then(function (d) {
                var n = (d && d.count) || 0;
                setBadge(chatLink, n);
            });
        }
    }

    function boot() {
        refresh();
        setInterval(refresh, 60000);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () { setTimeout(boot, 600); });
    } else {
        setTimeout(boot, 600);
    }
})();
