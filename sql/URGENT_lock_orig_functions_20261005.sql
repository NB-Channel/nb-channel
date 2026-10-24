-- ============================================================
--  🔴 紧急：锁掉能绕过鉴权的 _orig_* 函数
--
--  【问题】
--  数据库里每个写操作都是两层结构：
--      外层壳  buy_stock(p_user_id, p_session, ...)   ← 先 _user_ok 验会话
--      内层实现 _orig_buy_stock(p_user_id, ...)       ← 不验身份，信任调用方
--
--  内层【必须】只让壳调得到。但现在有 6 个内层匿名可调：
--
--      _orig_buy_stock            🔴 能冒用任何人买股票（花他的钱）
--      _orig_sell_stock           🔴 能冒用任何人卖股票
--      _orig_bankrupt_company     🔴 能把别人的公司清算掉
--      _orig_support_company      🔴 能冒用别人注资
--      _orig_register_company     🔴 能冒用别人注册公司
--      _orig_register_company_v3  🔴 同上
--
--  攻击方式（只要知道别人的 uuid）：
--      supabase.rpc('_orig_buy_stock',
--                   { p_user_id: '受害者uuid', p_company_id: 1, p_amount: 999999999 })
--
--  【为什么会漏】
--  仓库里的锁脚本（lock_backend_rpcs / lock_user_rpcs / lock_user_rpcs2）
--  都是【硬编码函数清单】的。而上面这些是 2026-10-03 那次 AMM 股票重构
--  【新造】的函数 —— 造出来之后没人把它们加进清单。
--
--  【这次的做法】
--  不再硬编码清单：扫【所有】以 _orig_ 开头、且 anon 或 authenticated
--  还能调用的函数，一并收回权限。以后新增的 _orig_ 也能被覆盖到。
--
--  【为什么安全】
--  外层壳都是 SECURITY DEFINER —— 以所有者（postgres）身份运行，
--  所有者对自己的函数始终有 EXECUTE 权限，REVOKE 收不走。
--  所以壳照常转发，只是外人不能绕过壳直接调内层了。
--
--  【只收权限，不删函数】
--  定义留着，万一将来要排查历史还在。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等，可重复跑）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状 —— 哪些 _orig_ 现在是敞开的
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '🔴 anon 能调' ELSE '—' END     AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN '🔴 能调' ELSE '—' END          AS authenticated
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%')
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：把「无令牌的旧版管理函数」也一起锁上
--          （URGENT2_lock_legacy_admin.sql 那份清单，重跑一遍）
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
                 (p.proname = 'admin_ban_user'      AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
              OR (p.proname = 'admin_ignore_report' AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
              OR (p.proname = 'admin_verify_company' AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
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
        RAISE NOTICE '已锁定（旧版管理函数）: public.%(%)', r.proname, r.ident;
    END LOOP;
    RAISE NOTICE '---- 旧版管理函数共锁定 % 个 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：⭐ 自动扫描并锁掉所有敞开的 _orig_*
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
           AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%')
           AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
         ORDER BY p.proname
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已锁定: public.%(%)', r.proname, r.ident;
    END LOOP;
    RAISE NOTICE '---- 共锁定 % 个 _orig_ 函数 ----', v_cnt;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================

-- 3.1 _orig_* 应该一个都调不了了
SELECT
    count(*)                                                          AS _orig_函数总数,
    count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
                        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
                                                                      AS 还能调的,
    CASE WHEN count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
                                   OR has_function_privilege('authenticated', p.oid, 'EXECUTE')) = 0
         THEN '✅ 全部锁住了' ELSE '❌ 还有漏的' END                    AS 结论
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%');

-- 3.2 三个管理员函数的无 token 版本
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '❌ 还能调' ELSE '✅ 锁住了' END AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN '❌ 还能调' ELSE '✅ 锁住了' END AS authenticated
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('admin_ban_user','admin_ignore_report','admin_verify_company')
 ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);

-- 3.3 壳还能用吗 —— 这几个应该有权限（它们是正规入口）
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '✅ 可调（正常）' ELSE '❌ 调不了了（有问题）' END AS anon
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('buy_stock','sell_stock','bankrupt_company','bank_deposit',
                     'bank_fixed_deposit','bank_loan','bank_credit_loan','get_bank_account')
 ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);


-- ============================================================
--  第 4 步：还有一类要你决定（不自动动）
-- ============================================================
--  下面这些是【同名重载】里没有 session 参数的那个版本。
--  它们不叫 _orig_，所以上面的自动扫描碰不到：
--
--      bank_credit_loan(p_user_id, p_amount bigint, p_days integer)   ← 旧版完整实现
--      get_my_holdings(p_user_id)                                     ← 前端在用！
--      set_item_settings(p_user_id, p_item_id, p_settings)
--      update_comment(p_user_id, p_comment_id, p_content)
--      get_my_notifications(p_user_id, p_type, p_limit, p_offset)
--      purchase_product(p_product_id, p_buyer_id, p_type, p_company_id)
--
--  ⚠️ 里面 get_my_holdings(uuid) 前端【确实在用】（有一处不带 session 的调用），
--     直接锁掉会出问题。所以这一批不自动处理，先列出来：
--
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN 'anon 能调' ELSE '—' END        AS anon,
    length(pg_get_functiondef(p.oid))             AS 源码长度
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname IN ('bank_credit_loan','get_my_holdings','set_item_settings',
                     'update_comment','get_my_notifications','purchase_product')
 ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);

-- 看完把这一张发我，我一个一个判断哪些能锁、哪些前端在用。


-- ============================================================
--  跑完之后
-- ============================================================
--  · 3.1 应该「✅ 全部锁住了」
--  · 3.2 两个版本都应该「✅ 锁住了」（带 token 的那个本来就有令牌校验，
--        锁不锁都行；不带 token 的那个必须锁）
--  · 3.3 壳应该都还能调 —— 如果这里出现「❌ 调不了了」，
--        说明我判断错了 SECURITY DEFINER 的行为，得立刻回滚：
--            GRANT EXECUTE ON FUNCTION public.xxx(参数) TO anon, authenticated;
-- ============================================================
