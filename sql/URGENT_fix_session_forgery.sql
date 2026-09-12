-- ============================================================
-- 🔴 紧急修复:内部函数权限泄露(可伪造任意账号登录)
--
-- ⚠️ 这条要先跑!实测确认的漏洞:
--     POST /rest/v1/rpc/create_user_session {"p_user_id":"任意用户ID"}
--     → 直接返回 32 位会话令牌,verify_session 返回 true,能读该账号数据。
--     不需要密码、不需要验证码;user_id 在评论区/公司/好友列表里都是公开的。
--
-- 根因:Supabase 会给 anon / authenticated 角色**单独授予** public 下所有函数的
--       EXECUTE 权限。当初只写了 REVOKE ... FROM PUBLIC,这只收回"PUBLIC"这个
--       伪角色的权限,**没有动 anon 的独立授权**,所以匿名一直能调。
--       正确写法必须显式写 FROM PUBLIC, anon, authenticated。
--
-- 实测同时暴露的还有:
--     _verify_email_code  → 可被匿名调用(能消耗/试探别人的验证码)
--     _admin_token_valid  → 可被匿名调用(能试探后台令牌)
--
-- 修法:把「所有内部函数」的权限统一收回。内部调用不受影响 ——
--       login_finish / register_finish / 各个包装函数都是 SECURITY DEFINER,
--       以函数所有者的身份运行,照样能调用这些内部函数。
--
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

-- ---------- 1) 批量收回所有内部函数的权限 ----------
DO $$
DECLARE
    r     record;
    v_cnt int := 0;
BEGIN
    FOR r IN
        SELECT p.oid,
               p.proname,
               pg_get_function_identity_arguments(p.oid) AS ident
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.prokind = 'f'
           AND (
                 p.proname LIKE '\_%'                       -- 所有下划线开头的内部函数
                 OR p.proname = 'create_user_session'        -- 签发会话(核心漏洞)
               )
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已收回: public.%(%)', r.proname, r.ident;
    END LOOP;
    RAISE NOTICE '---- 共处理 % 个内部函数 ----', v_cnt;
END $$;

-- ---------- 2) 验收:匿名应该全部调用不了(false = 已修好) ----------
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS 匿名还能调用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND (p.proname LIKE '\_%' OR p.proname = 'create_user_session')
 ORDER BY 1;

-- 确认前端要用的函数没被误伤(true = 正常可用)
SELECT p.proname AS 前端接口, has_function_privilege('anon', p.oid, 'EXECUTE') AS 匿名可用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('login_user2', 'login_finish', 'register_finish', 'bind_email_finish',
                     'lookup_login_email', 'logout_session', 'verify_session', 'store_email_code')
 ORDER BY 1;

-- ---------- 3) 取证:有没有被利用过 ----------
-- 3.1 会话总量与签发时间分布
SELECT count(*) AS 会话总数,
       count(*) FILTER (WHERE expires_at > now()) AS 仍有效,
       min(created_at) AS 最早签发,
       max(created_at) AS 最近签发
  FROM public.user_sessions;

-- 3.2 短时间被大量签发的小时(伪造的特征)
SELECT date_trunc('hour', created_at) AS 小时, count(*) AS 签发条数
  FROM public.user_sessions
 GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- ---------- 4) 善后:作废可能被伪造的会话 ----------
-- 没法区分哪条是伪造的,最稳是全部作废、让大家重新登录一次。
-- 确认后再手动执行(默认注释掉):
-- TRUNCATE public.user_sessions;
--
-- 或者只清最近的:
-- DELETE FROM public.user_sessions WHERE created_at > now() - interval '7 days';
