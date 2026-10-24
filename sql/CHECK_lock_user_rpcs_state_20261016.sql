-- ============================================================
--  查：lock_user_rpcs.sql 到底跑过没有、包了哪些函数
--
--  起因：站长跑完两个修复脚本，回来的结果是 ——
--      get_active_shop_effects(p_user_id, p_session)      ← 已经有 p_session
--      get_checkin_heatmap(p_user_id, p_days, p_session)  ← 已经有 p_session
--  但我那两个脚本只【新建】了公开版，没动本体。
--  本体会带 p_session，只能是 lock_user_rpcs.sql 已经跑过了。
--
--  ⚠️ 如果真跑过，那审计里预测的「会坏」其实【早就已经在坏】了：
--      · 看别人主页的签到热力图 —— 空白
--      · 导航栏两个红点（🔔 消息 / 👥 好友）—— 不亮
--      · 6 处「查别人装扮」—— 主页/评论/私信装扮不显示
--          （这一处本次已经拆公开版修好了）
--
--  这个脚本【只查不改】。
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 1. 有多少个函数被包过（_orig_ 前缀的就是被包的）
-- ============================================================
SELECT count(*) AS 已被包装的函数数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '\_orig\_%';


-- ============================================================
-- 2. 具体是哪些（对照 lock_user_rpcs.sql 的 34 个名单）
-- ============================================================
SELECT replace(p.proname, '_orig_', '') AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 原参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon还能直接调
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '\_orig\_%'
 ORDER BY 1;

-- ⚠️ 「anon还能直接调」这一列应该是 false ——
--    如果哪个是 true，说明那个 _orig_ 没被 REVOKE，
--    别人可以绕过包装直接调原函数（等于包装白加）。


-- ============================================================
-- 3. 对照：同名函数现在有几个版本、各自的参数
--    ⚠️ 重点看有没有【两个候选】都匹配前端传的参数名 → PGRST203
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon可调
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN (
        -- lock_user_rpcs 名单里的 34 个
        'send_message','get_messages','get_unread_messages','get_conversations',
        'mark_conversation_read','recall_message','unrecall_message','delete_my_message',
        'clear_conversation','delete_conversation','set_conversation_mute',
        'get_or_create_conversation','send_friend_request','respond_friend_request',
        'remove_friend','get_friends','get_friend_requests',
        'buy_title','equip_title','set_title_slot','visit_profile',
        'get_checkin_heatmap','get_active_shop_effects','record_balance_count',
        'update_username','get_my_holdings','use_checkin_fix','get_lottery_today',
        'get_my_notifications','delete_notification','mark_notification_read',
        'mark_all_notifications_read','delete_read_notifications','get_unread_counts',
        -- 本次新建的两个公开版
        'get_public_shop_effects','get_public_checkin_heatmap')
 ORDER BY 1, 2;

-- ⚠️ 同一个函数名如果出现两行、且都 anon可调 = true，
--    再看前端传的参数名能不能唯一确定一个 ——
--    定不下来就会报 PGRST203（整页报错）。
--    重点核对 get_my_holdings。


-- ============================================================
-- 4. 补签函数现在什么状态（本次改的那个）
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%_user_ok%') AS 校验会话
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname = 'use_checkin_fix' OR p.proname = '_orig_use_checkin_fix')
 ORDER BY 1, 2;

-- 期望：只剩 use_checkin_fix(uuid, date, text)，而且「校验会话」= true
-- ⚠️ 如果还有 _orig_use_checkin_fix 挂着，不用管（没人调它），
--    但确认它 anon 调不了。


-- ============================================================
--  跑完看这几件事
-- ============================================================
--  ① 第 1 段的数量 —— 如果是 0，说明 lock_user_rpcs 没跑过，
--     那前面那两个 p_session 是别的地方加的，告诉我我重新判断。
--     如果是 30 上下，说明跑过了，审计预测的坏都是真的。
--
--  ② 第 2 段的「anon还能直接调」有没有 true —— 有的话是漏洞
--     （绕过包装直调原函数）。
--
--  ③ 第 3 段 get_my_holdings 是不是两行都 anon可调 = true。
--
--  ④ 第 4 段补签函数是不是只剩一个、且校验会话。
--
--  把 ①②③④ 的结果发我。
-- ============================================================
