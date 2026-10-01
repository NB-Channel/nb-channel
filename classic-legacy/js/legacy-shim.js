/* ============================================================
   js/legacy-shim.js —— 让 8 月旧版页面能跑在现在的数据库上

   背景：旧版页面有 36 处直接读写数据库，但其中一部分表和权限
         在后来被改过（安全加固、或函数改名），旧版一跑就报错：
           · profiles 表被 REVOKE（防个人资料匿名可读）—— 29 处在用
           · reports / report_attempts 被 REVOKE —— 4 处在用
           · lottery_records / product_purchases 被 REVOKE —— 3 处在用

   做法：不恢复表权限（那等于把漏洞放回来），而是加这一层，
         把旧代码的写法翻译成 RPC 调用。旧页面自身几乎不用动。

   加载：放在 common.js 之后、页面自己的脚本之前。

   ⚠️ 只对 classic-legacy/ 这套旧版生效，新页面（Beta/*）不要引它。
   ============================================================ */
(function () {
    'use strict';

    var SB = window.supabaseClient;
    if (!SB || typeof SB.from !== 'function' || typeof SB.rpc !== 'function') {
        console.warn('[legacy-shim] 没找到 supabaseClient，跳过');
        return;
    }

    // ---------- 小工具 ----------
    function myId() {
        try { return (JSON.parse(localStorage.getItem('nb_user') || 'null') || {}).id || null; }
        catch (e) { return null; }
    }
    function mySession() {
        try { return localStorage.getItem('nb_session') || null; } catch (e) { return null; }
    }
    function pick(obj, fields) {
        if (!obj) return null;
        if (!fields || fields === '*' || fields === '') return obj;
        var out = {};
        String(fields).split(',').forEach(function (f) {
            f = f.trim();
            if (f && Object.prototype.hasOwnProperty.call(obj, f)) out[f] = obj[f];
        });
        return out;
    }
    function err(msg) { return { message: msg, code: 'SHIM' }; }

    var origFrom = SB.from.bind(SB);

    // ============================================================
    // ① profiles：拦截 .from('profiles')，翻译成 RPC
    // ============================================================
    // 旧代码的三种典型写法：
    //   .from('profiles').select('nb_balance').eq('id', user.id).single()
    //   .from('profiles').select('username').order('username')
    //   .from('profiles').update({ username: x }).eq('id', user.id)
    function profilesShim() {
        var st = { op: 'select', fields: '*', eq: {}, neq: {}, update: null, single: false, maybe: false };

        function exec() {
            // --- update：只能是改自己的用户名 ---
            if (st.op === 'update') {
                var target = st.eq.id;
                var body = st.update || {};
                if (target && String(target) === String(myId())) {
                    if (typeof body.username === 'string') {
                        return SB.rpc('change_username', {
                            p_user_id: target, p_session: mySession(), p_username: body.username
                        }).then(function (r) {
                            var d = r.data || {};
                            if (!d.success) return { data: null, error: err(d.message || '改名失败') };
                            return { data: null, error: null };
                        });
                    }
                    // 其它字段的更新不支持的，直接拒绝（旧版也只改用户名）
                    return Promise.resolve({ data: null, error: err('legacy-shim 不支持的 profiles 更新字段') });
                }
                return Promise.resolve({ data: null, error: err('只能修改自己的资料') });
            }

            // --- select ---
            var target = st.eq.id;

            // 按 id 查（最常见）
            if (target) {
                var mine = (String(target) === String(myId()));
                if (mine) {
                    return SB.rpc('get_my_profile', { p_user_id: target, p_session: mySession() })
                        .then(function (r) {
                            var d = r.data || {};
                            if (!d.success) return { data: null, error: err(d.message || '读取资料失败') };
                            return { data: pick(d.profile, st.fields), error: null };
                        });
                }
                return SB.rpc('get_public_profiles', { p_ids: [target] }).then(function (r) {
                    var d = r.data || {};
                    var row = (d.list && d.list[0]) || null;
                    if (!row) return { data: null, error: st.single ? err('资料不存在') : null };
                    return { data: pick(row, st.fields), error: null };
                });
            }

            // 按用户名查（改名查重）
            if (st.eq.username) {
                return SB.rpc('check_username_taken', {
                    p_username: st.eq.username, p_exclude_id: st.neq.id || null
                }).then(function (r) {
                    var d = r.data || {};
                    return { data: d.taken ? { id: 'taken' } : null, error: null };
                });
            }

            // 没有条件 → 拿全部用户名（旧版用它做 @ 提及候选）
            return SB.rpc('get_username_list').then(function (r) {
                var d = r.data || {};
                return { data: d.list || [], error: null };
            });
        }

        var api = {
            select: function (f) { st.op = 'select'; st.fields = f || '*'; return api; },
            update: function (o) { st.op = 'update'; st.update = o; return api; },
            insert: function () { return api; },
            eq:      function (k, v) { st.eq[k] = v; return api; },
            neq:     function (k, v) { st.neq[k] = v; return api; },
            in:      function () { return api; },
            gte:     function () { return api; },
            lte:     function () { return api; },
            order:   function () { return api; },
            limit:   function () { return api; },
            single:      function () { st.single = true; return api; },
            maybeSingle: function () { st.maybe = true; return api; },
            then: function (resolve, reject) { return exec().then(resolve, reject); },
            catch: function (fn) { return exec().catch(fn); }
        };
        return api;
    }

    // ============================================================
    // ② 拦截 from()
    // ============================================================
    SB.from = function (table) {
        if (table === 'profiles') return profilesShim();
        return origFrom(table);
    };
    // 也拦截 .table()（后端 SDK 风格，某些旧代码可能用）
    if (typeof SB.table === 'function') {
        var origTable = SB.table.bind(SB);
        SB.table = function (t) { return t === 'profiles' ? profilesShim() : origTable(t); };
    }

    // ============================================================
    // ③ 提供拆分"嵌套查询"的辅助函数
    // ============================================================
    // 旧代码里有 5 处是 PostgREST 的关联查询，比如
    //   .from('comments').select('*, profiles(username, avatar_url)')
    // 这依赖 profiles 可读，现在不通了。改成两步：先查主表，再批量补用户名。
    window.LegacyJoin = {
        // 给一组行补上 profiles 字段（就地改，保持旧代码的取值方式）
        attachProfiles: function (rows, profilesKey, userIdField) {
            rows = rows || [];
            var ids = [];
            rows.forEach(function (r) {
                var uid = r && r[userIdField || 'user_id'];
                if (uid && ids.indexOf(uid) === -1) ids.push(uid);
            });
            if (!ids.length) return Promise.resolve(rows);

            return SB.rpc('get_public_profiles', { p_ids: ids }).then(function (res) {
                var map = {};
                ((res.data || {}).list || []).forEach(function (p) { map[p.id] = p; });
                rows.forEach(function (r) {
                    var uid = r && r[userIdField || 'user_id'];
                    if (uid && map[uid]) r[profilesKey || 'profiles'] = map[uid];
                });
                return rows;
            }).catch(function () { return rows; });
        }
    };

    // ============================================================
    // ④ 举报：旧版直接写 reports / report_attempts，改成走 RPC
    // ============================================================
    // 旧版两处写法：
    //   .from('reports').select('id').eq('comment_id',x).eq('reporter_user_id',y).maybeSingle()
    //   .from('reports').insert({...})
    //   .from('report_attempts').select('id',{count:'exact',head:true}).eq('ip_address',ip).gte(...)
    //   .from('report_attempts').insert({ip_address: ip})
    window.LegacyReport = {
        // 举报一条评论（登录态由 p_user_id/p_session 带）
        submit: function (commentId, reason) {
            var uid = myId(), s = mySession();
            if (!uid || !s) return Promise.resolve({ data: null, error: err('请先登录') });
            // 评论归属哪一页，旧代码里是靠 page_path 推的，这里交给服务端按 comment_id 找
            return SB.rpc('submit_comment_report', {
                p_user_id: uid, p_comment_id: commentId,
                p_reason: reason || '违规', p_session: s
            }).then(function (r) {
                var d = r.data || {};
                return { data: d.success ? {} : null, error: d.success ? null : err(d.message || '举报失败') };
            });
        },
        // 我举报过这条吗
        mine: function (commentId) {
            var uid = myId(), s = mySession();
            if (!uid || !s) return Promise.resolve({ data: null, error: null });
            // 签名：check_my_report(p_user_id uuid, p_comment_id bigint, p_session text)
            return SB.rpc('check_my_report', {
                p_user_id: uid, p_comment_id: commentId, p_session: s
            }).then(function (r) {
                var d = r.data || {};
                return { data: (d.reported ? { id: 'y' } : null), error: null };
            }).catch(function () { return { data: null, error: null }; });
        }
    };
    ['reports', 'report_attempts'].forEach(function (t) {
        var prev = SB.from;
        SB.from = function (table) {
            if (table === t) {
                // 返回一个"什么都不做"的桩，避免直接抛错（旧代码对 error 有判断）
                return {
                    select: function () { return this; }, insert: function () { return this; },
                    eq: function () { return this; }, gte: function () { return this; },
                    order: function () { return this; }, limit: function () { return this; },
                    single: function () { return this; }, maybeSingle: function () { return this; },
                    then: function (res) { return Promise.resolve({ data: null, error: err('请用 LegacyReport') }).then(res); }
                };
            }
            return prev(table);
        };
    });

    // ============================================================
    // ⑤ 抽奖记录 / 购买记录：包一层
    // ============================================================
    window.LegacyCount = {
        // 今天抽过几次（旧版用它判断还剩几次机会）
        lotteryToday: function (userId) {
            // 签名：get_my_lottery_records(p_user_id uuid, p_session text DEFAULT NULL)
            // 它 RETURNS TABLE(...)，所以 PostgREST 直接返回数组，不是 {list:[]}
            return SB.rpc('get_my_lottery_records', {
                p_user_id: userId, p_session: mySession()
            }).then(function (r) {
                var list = Array.isArray(r.data) ? r.data : ((r.data || {}).list || []);
                var today = new Date().toISOString().slice(0, 10);
                return list.filter(function (x) {
                    return String(x.created_at || '').slice(0, 10) === today;
                }).length;
            }).catch(function () { return 0; });
        },
        // 我买过哪些作品
        myPurchased: function (userId, session) {
            return SB.rpc('get_my_purchased_ids', { p_user_id: userId, p_session: session })
                .then(function (r) { return ((r.data || {}).ids) || []; })
                .catch(function () { return []; });
        }
    };

    console.log('[legacy-shim] 已启用：profiles / reports / report_attempts / lottery_records / product_purchases 已转成 RPC');
})();
