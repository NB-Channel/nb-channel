-- ============================================================
-- 🔴 第二批紧急修复:无令牌的旧版管理函数仍对匿名开放
--
-- 从「所有 anon 可调用函数」的审计结果里发现,下面这些**旧版本**忘了收权限,
-- 它们没有 p_token / p_session 参数 —— 任何人直接调用就能:
--
--   admin_ban_user(uuid, text)            → 封禁任意账号        🔴 最高危
--   admin_ignore_report(bigint)           → 忽略任意举报
--   admin_verify_company(bigint, boolean) → 认证任意公司(拿蓝标)
--   admin_rename_company(bigint, text)    → 改任意公司名
--   delete_verified_user(uuid)            → 删除认证用户
--   claim_coin(uuid) / can_claim_coin     → 领币(彩蛋)
--   consume_fee_discount(uuid)            → 消耗手续费减免券
--   delete_old_history()                  → 删除历史行情
--   check_report_rate_limit()             → 无实际用途
--
-- 已扫描确认:以上函数**前端与后端都没有任何调用点**
--   · 后台页面用的是带 p_token 的版本(那些保留,不动)
--   · consume_fee_discount 是 buy_stock 内部调用的,但 buy_stock 是
--     SECURITY DEFINER,以所有者身份运行,收回 anon 权限不影响它
--
-- 做法:逐个收回权限(用 DO 块包住,函数不存在也不会中断),
--       不删函数本身 —— 万一将来要排查历史,定义还在。
--
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

DO $$
DECLARE
    r record;
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
             -- 无令牌的旧版管理函数(带 p_token 的同名版本不在这里,保留)
             (p.proname = 'admin_ban_user'           AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
          OR (p.proname = 'admin_ignore_report'      AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
          OR (p.proname = 'admin_verify_company'     AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
          OR (p.proname = 'admin_rename_company')
          OR (p.proname = 'delete_verified_user')
          OR (p.proname = 'claim_coin')
          OR (p.proname = 'can_claim_coin')
          OR (p.proname = 'consume_fee_discount')
          OR (p.proname = 'delete_old_history')
          OR (p.proname = 'check_report_rate_limit')
           )
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已锁定: public.%(%)', r.proname, r.ident;
    END LOOP;
    RAISE NOTICE '---- 共锁定 % 个函数 ----', v_cnt;
END $$;

-- ---------- 验收:这些都应该是 false ----------
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS 匿名还能调用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname IN ('admin_ban_user', 'admin_ignore_report', 'admin_verify_company',
                     'admin_rename_company', 'delete_verified_user', 'claim_coin',
                     'can_claim_coin', 'consume_fee_discount', 'delete_old_history',
                     'check_report_rate_limit')
 ORDER BY 1, 2;

-- ---------- 确认后台要用的带令牌版本没被误伤(true = 正常) ----------
SELECT p.proname AS 后台接口,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS 匿名可用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('admin_ban_user', 'admin_ignore_report', 'admin_verify_company',
                     'admin_create_session', 'admin_check_session', 'admin_dashboard_stats')
   AND pg_get_function_identity_arguments(p.oid) LIKE '%p_token%'
 ORDER BY 1;

-- ---------- 取证:这些口子有没有被用过 ----------
-- 被额外封禁的账号(排除你手动封的,自己判断):
SELECT id, username, is_banned, banned_reason
  FROM public.profiles WHERE is_banned IS TRUE ORDER BY username;

-- 有没有公司被莫名认证:
SELECT id, company_name, verified, verification_status, user_id
  FROM public.user_companies WHERE verified IS TRUE ORDER BY id;
