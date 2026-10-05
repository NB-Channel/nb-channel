-- ============================================================
--  🔴 锁掉「无鉴权的旧重载」—— 一次性收口
--
--  这是继 URGENT_lock_orig_functions 之后的第二批，把同类问题清干净。
--
--  【问题】
--  数据库里很多操作有两个重载：
--      正规版  xxx(p_user_id, p_session, ...)   先验会话，再转发给 _orig_
--      旧版本  xxx(p_user_id, ...)              不验身份，直接干活
--
--  两个都 anon 可调。PostgREST 按【参数名】选函数 ——
--  前端少传一个 p_session，就会掉进不验身份的那个。
--  攻击者更可以直接构造请求打旧版本，冒用任意 p_user_id。
--
--  已确认的六个（都跑了全仓库调用点排查，确认锁掉不会影响现有功能）：
--
--      bank_credit_loan(uuid, bigint, integer)        🔴 冒名借钱
--      update_comment(uuid, bigint, text)             🔴 改任意评论
--      get_my_holdings(uuid)                          🔴 读任意人持仓
--      set_item_settings(uuid, bigint, jsonb)         🔴 改任意人道具设置
--      purchase_product(bigint, uuid)                 🔴 冒名购买
--      get_my_notifications(...)                      两个版本都带 session，不用动
--
--  【这次的做法 —— 自动判别，不再硬编码清单】
--  锁的条件（三条同时满足）：
--      ① 这个重载的参数里【没有】p_session
--      ② 它现在还允许 anon 或 authenticated 调用
--      ③ 【存在】同名且【带 p_session】的另一个重载
--
--  第 ③ 条是关键 —— 只有「有正规版本可以替代」时才锁，
--  这样不会误伤那些本来就没有 session 版本的普通函数。
--
--  【为什么安全】
--  下面逐个说明为什么锁掉不影响现有功能：
--      · bank_credit_loan    Beta 银行页的 callRpc 本来就注入 p_session；
--                            根目录和 classic-* 的 bank.html 这次也补齐了
--      · update_comment      活跃页面（Beta/ 和根目录）都显式传了 p_session
--      · get_my_holdings     前端那个「不带 session 的兜底」是死代码 ——
--                            代码注释自己写着会报 PGRST203（重载歧义），
--                            永远走不到。锁掉之后歧义消失，反而更稳
--      · set_item_settings   Beta 背包页早就传了；根目录背包页这次补齐；
--                            银行页的「令牌自动注入拦截器」白名单里也有它
--      · purchase_product    只有后端 app.py 在调，
--                            而后端的 rpc() 对它在 _SESSION_RPCS 里，会自动带令牌
--
--  【只收权限，不删函数】
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    length(pg_get_functiondef(p.oid))             AS 源码长度,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '🔴 anon 能调' ELSE '—' END     AS anon,
    CASE WHEN EXISTS (
             SELECT 1 FROM pg_proc q JOIN pg_namespace m ON m.oid = q.pronamespace
              WHERE m.nspname = 'public' AND q.prokind = 'f'
                AND q.proname = p.proname
                AND position('p_session' in pg_get_function_identity_arguments(q.oid)) > 0)
         THEN '有正规版本' ELSE '（无替代）' END    AS 有没有带session的同名版本
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND position('p_session' in pg_get_function_identity_arguments(p.oid)) = 0
   AND position('p_token'   in pg_get_function_identity_arguments(p.oid)) = 0
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
   AND p.proname NOT LIKE '\_orig\_%'
   AND p.proname NOT LIKE '%\_orig\_%'
 ORDER BY 有没有带session的同名版本 DESC, p.proname;


-- ============================================================
-- 第 1 步：⭐ 自动扫描并锁掉「无 session 且有正规版本」的旧重载
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
           -- ① 参数里没有 p_session、也没有 p_token
           AND position('p_session' in pg_get_function_identity_arguments(p.oid)) = 0
           AND position('p_token'   in pg_get_function_identity_arguments(p.oid)) = 0
           -- ② 现在还允许 anon / authenticated 调用
           AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
           -- ③ 存在同名且带 p_session 的另一个重载（有正规版本可替代）
           AND EXISTS (
                 SELECT 1 FROM pg_proc q JOIN pg_namespace m ON m.oid = q.pronamespace
                  WHERE m.nspname = 'public' AND q.prokind = 'f'
                    AND q.proname = p.proname
                    AND position('p_session' in pg_get_function_identity_arguments(q.oid)) > 0)
           -- 排除 _orig_（上一批已经处理，这里不重复）
           AND p.proname NOT LIKE '\_orig\_%'
           AND p.proname NOT LIKE '%\_orig\_%'
         ORDER BY p.proname
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已锁定旧重载: public.%(%)', r.proname, r.ident;
    END LOOP;
    RAISE NOTICE '---- 共锁定 % 个无鉴权重载 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：顺手确认上一批（_orig_* 和旧版管理函数）也锁好了
--         如果上一批还没跑，这里会补上
-- ============================================================
DO $$
DECLARE
    r record;
    v_cnt int := 0;
BEGIN
    -- 2.1 所有还敞开的 _orig_*
    FOR r IN
        SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS ident
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%')
           AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已锁定 _orig_: public.%(%)', r.proname, r.ident;
    END LOOP;

    -- 2.2 无令牌的旧版管理函数
    FOR r IN
        SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS ident
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
           AND (
                 (p.proname = 'admin_ban_user'          AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
              OR (p.proname = 'admin_ignore_report'     AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
              OR (p.proname = 'admin_verify_company'    AND pg_get_function_identity_arguments(p.oid) NOT LIKE '%p_token%')
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
        RAISE NOTICE '已锁定旧版管理函数: public.%(%)', r.proname, r.ident;
    END LOOP;

    RAISE NOTICE '---- 第 2 步共锁定 % 个 ----', v_cnt;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================

-- 3.1 还有没有「无 session 且有正规版本」却敞开的
SELECT
    count(*) AS 还有几个敞开的,
    CASE WHEN count(*) = 0 THEN '✅ 全部收口' ELSE '❌ 还有漏的' END AS 结论
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND position('p_session' in pg_get_function_identity_arguments(p.oid)) = 0
   AND position('p_token'   in pg_get_function_identity_arguments(p.oid)) = 0
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
   AND EXISTS (SELECT 1 FROM pg_proc q JOIN pg_namespace m ON m.oid = q.pronamespace
                WHERE m.nspname = 'public' AND q.prokind = 'f'
                  AND q.proname = p.proname
                  AND position('p_session' in pg_get_function_identity_arguments(q.oid)) > 0)
   AND p.proname NOT LIKE '\_orig\_%' AND p.proname NOT LIKE '%\_orig\_%';

-- 3.2 _orig_ 应该一个都调不了了
SELECT
    count(*) AS _orig_总数,
    count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
                        OR has_function_privilege('authenticated', p.oid, 'EXECUTE')) AS 还能调的,
    CASE WHEN count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
                                   OR has_function_privilege('authenticated', p.oid, 'EXECUTE')) = 0
         THEN '✅ 全部锁住' ELSE '❌ 还有漏的' END AS 结论
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%');

-- 3.3 ⭐ 最要紧的一项：逐个判断每行是「预期内」还是「要回滚」
--
--     ⚠️ 上一版这里只看「能不能调」，把【成功锁掉的旧版】也标成了「要回滚」，
--        结果四个正确的操作看起来像出错。现在按参数里有没有 p_session 分开判断：
--
--          没有 p_session 的（旧版）→ 应该【锁住】，锁住了才算 ✅
--          带  p_session 的（正规版）→ 应该【能调】，锁住才是 ❌
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    CASE
      WHEN position('p_session' in pg_get_function_identity_arguments(p.oid)) = 0
        THEN CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
                       OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
                  THEN '❌ 旧版还开着（该锁没锁）'
                  ELSE '✅ 旧版已锁（预期内）' END
      ELSE CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
                  THEN '✅ 可调（正常）'
                  ELSE '❌ 正规版被锁了，要回滚' END
    END                                       AS 判断
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname IN ('buy_stock','sell_stock','bankrupt_company','bank_deposit',
                     'bank_fixed_deposit','bank_loan','bank_credit_loan',
                     'get_bank_account','get_my_holdings','update_comment',
                     'set_item_settings','purchase_product','get_my_notifications')
 ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);


-- ============================================================
--  出问题时的回滚（只在 3.3 出现 ❌ 时用）
-- ============================================================
--  GRANT EXECUTE ON FUNCTION public.buy_stock(uuid, text, bigint, numeric, boolean)
--      TO anon, authenticated;
--  —— 把函数名和参数换成 3.3 里那个 ❌ 的行即可。
--
--  另外：前端也一起改了（给 callRpc / set_item_settings 补 p_session、
--  删掉 get_my_holdings 的死代码兜底），那些改动不依赖这个脚本，
--  先跑脚本或先部署前端都可以。
-- ============================================================
