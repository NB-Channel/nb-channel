-- ============================================================
--  🔴 安全修复第三批 —— 审计第二轮查出来的
--
--  站长跑了 audit_round2，三张表查出来四类问题。逐个修：
--
--  【A】Storage 匿名能删文件（最直接可利用）
--      avatars_anon_delete    DELETE  {anon,authenticated}  bucket_id='avatars'
--      images_anon_delete     DELETE  {anon,authenticated}  bucket_id='images'
--      products_anon_delete   DELETE  {anon,authenticated}  bucket_id='products'
--      allow_all_delete       DELETE  {authenticated}       qual = true
--      allow_all_update       UPDATE  {authenticated}       qual = true
--
--      不用登录就能删光全站头像、图片、作品文件；登录用户还能删/覆盖任何文件。
--      攻击方式（不需要知道任何密码）：
--          DELETE /storage/v1/object/avatars/别人的文件名
--
--  【B】一批内部辅助函数匿名可调
--      _credit_gain_on_repay / _holder_ratio / _loan_force_collect /
--      _stock_allowed / comments_guard / _loan_alert_early /
--      random_fluctuate_market_values / record_daily_kline /
--      run_auto_support / sample_market_snapshot
--
--      已逐个核对调用点：活跃页面都没有在调
--      （股票页里只剩注释：「random_fluctuate_market_values 在数据库里已经
--        改成空函数，这里也就不再调用了」「自动支持改为数据库驱动」）。
--
--  【C】备份表的表级权限没收干净
--      14 张 _*_bak_* / _func_backup_* / _evidence_* 表，
--      anon 和 authenticated 都有 INSERT/UPDATE/DELETE 权限。
--      目前靠「RLS 开着 + 没有策略 = 默认全拒」挡着，但这是纸糊的 ——
--      哪天有人给这些表加一条策略，或者关了 RLS，就直接敞开了。
--      顺手一起收掉：这些表本来就只有站长用 SQL 直接看。
--
--  【D】pay_dividend 缺鉴权（这个要配合前端一起改，见文件末尾说明）
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看清现状（只读）
-- ============================================================

-- 0.1 Storage 上现在有哪些危险策略
SELECT tablename, policyname, cmd, roles, qual
  FROM pg_policies
 WHERE schemaname = 'storage'
   AND cmd IN ('DELETE', 'UPDATE', 'INSERT')
 ORDER BY cmd, policyname;

-- 0.2 那批内部函数现在谁能调
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid)  AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '🔴 anon' ELSE '—' END        AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN '🔴 auth' ELSE '—' END        AS authenticated
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_credit_gain_on_repay','_holder_ratio','_loan_force_collect',
                     '_stock_allowed','comments_guard','_loan_alert_early',
                     'random_fluctuate_market_values','record_daily_kline',
                     'run_auto_support','sample_market_snapshot')
 ORDER BY p.proname;

-- 0.3 备份表现在被授了哪些权限
SELECT
    c.relname AS 表名,
    CASE WHEN has_table_privilege('anon', c.oid, 'SELECT') THEN 'S' ELSE '' END ||
    CASE WHEN has_table_privilege('anon', c.oid, 'INSERT') THEN 'I' ELSE '' END ||
    CASE WHEN has_table_privilege('anon', c.oid, 'UPDATE') THEN 'U' ELSE '' END ||
    CASE WHEN has_table_privilege('anon', c.oid, 'DELETE') THEN 'D' ELSE '' END
              AS anon权限,
    CASE WHEN has_table_privilege('authenticated', c.oid, 'SELECT') THEN 'S' ELSE '' END ||
    CASE WHEN has_table_privilege('authenticated', c.oid, 'INSERT') THEN 'I' ELSE '' END ||
    CASE WHEN has_table_privilege('authenticated', c.oid, 'UPDATE') THEN 'U' ELSE '' END ||
    CASE WHEN has_table_privilege('authenticated', c.oid, 'DELETE') THEN 'D' ELSE '' END
              AS authenticated权限
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
   AND (c.relname LIKE '\_%bak%' OR c.relname LIKE '\_func\_backup%'
        OR c.relname LIKE '\_evidence\_%' OR c.relname LIKE '%\_backup%'
        OR c.relname LIKE '\_policy\_backup%' OR c.relname LIKE '\_credit\_loan\_backup%')
 ORDER BY c.relname;


-- ============================================================
-- 【A】收紧 Storage 策略
-- ============================================================
DO $$
DECLARE
    v_cnt int := 0;
    v_name text;
BEGIN
    -- A.1 删掉「任何登录用户能删/改任何文件」这两条
    FOR v_name IN
        SELECT policyname FROM pg_policies
         WHERE schemaname = 'storage' AND tablename = 'objects'
           AND policyname IN ('allow_all_delete', 'allow_all_update',
                              'allow_all_insert', 'allow_all_select')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', v_name);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已删除过宽策略: %', v_name;
    END LOOP;

    -- A.2 删掉「匿名能删」的三条
    FOR v_name IN
        SELECT policyname FROM pg_policies
         WHERE schemaname = 'storage' AND tablename = 'objects'
           AND policyname IN ('avatars_anon_delete', 'images_anon_delete',
                              'products_anon_delete')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', v_name);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已删除匿名删除策略: %', v_name;
    END LOOP;

    RAISE NOTICE '---- Storage 共删除 % 条策略 ----', v_cnt;
END $$;

-- A.3 删掉「匿名能往 avatars / images 写」的（products 上传是功能需要的，保留）
DO $$
DECLARE
    v_name text;
    v_cnt int := 0;
BEGIN
    FOR v_name IN
        SELECT policyname FROM pg_policies
         WHERE schemaname = 'storage' AND tablename = 'objects'
           AND policyname IN ('avatars_anon_insert', 'images_anon_insert')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', v_name);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已删除匿名写入策略: %', v_name;
    END LOOP;
    RAISE NOTICE '---- 共删除 % 条 ----', v_cnt;
END $$;

-- ⚠️ 说明：删掉之后，头像上传还能不能用，取决于前端走的是哪条路。
--    头像上传一般走 profiles 表的 avatar_url 字段 + Storage 直传。
--    如果发现头像传不上去了，在下面这段里挑一条放开（按需二选一）：
--
--    -- 允许【登录用户】往 avatars 桶上传（推荐）
--    CREATE POLICY avatars_auth_insert ON storage.objects
--      FOR INSERT TO authenticated
--      WITH CHECK (bucket_id = 'avatars');
--
--    -- 允许【匿名】往 avatars 桶上传（前端没做登录态时用，不推荐）
--    CREATE POLICY avatars_anon_insert ON storage.objects
--      FOR INSERT TO anon, authenticated
--      WITH CHECK (bucket_id = 'avatars');


-- ============================================================
-- 【B】锁掉内部辅助函数
-- ============================================================
DO $$
DECLARE
    r record;
    v_cnt int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS ident
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('_credit_gain_on_repay','_holder_ratio','_loan_force_collect',
                             '_stock_allowed','comments_guard','_loan_alert_early',
                             'random_fluctuate_market_values','record_daily_kline',
                             'run_auto_support','sample_market_snapshot')
           AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已锁定: public.%(%)', r.proname, r.ident;
    END LOOP;
    RAISE NOTICE '---- 共锁定 % 个内部函数 ----', v_cnt;
END $$;

-- ⚠️ 为什么锁了不影响功能：
--    · 这些函数要么是内部辅助（被别的 SECURITY DEFINER 函数调用，
--      以所有者身份运行，不受 anon 权限影响）
--    · 要么是 cron 调的（cron 以 postgres 身份运行）
--    · 要么是触发器函数（触发器的执行不需要调用者有 EXECUTE 权限）
--    · 活跃前端页面已经不再调用它们（逐个核对过，只剩注释）


-- ============================================================
-- 【C】收掉备份表的表级权限
-- ============================================================
DO $$
DECLARE
    r record;
    v_cnt int := 0;
BEGIN
    FOR r IN
        SELECT c.relname
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public' AND c.relkind = 'r'
           AND (c.relname LIKE '\_%bak%' OR c.relname LIKE '\_func\_backup%'
                OR c.relname LIKE '\_evidence\_%' OR c.relname LIKE '%\_backup%'
                OR c.relname LIKE '\_policy\_backup%' OR c.relname LIKE '\_credit\_loan\_backup%')
    LOOP
        EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', r.relname);
        v_cnt := v_cnt + 1;
        RAISE NOTICE '已收回权限: %', r.relname;
    END LOOP;
    RAISE NOTICE '---- 共处理 % 张备份表 ----', v_cnt;
END $$;

-- ⚠️ 这些表你以后要看，直接用 SQL Editor（以 postgres 身份）查就行，
--    不受影响。收回的是 anon / authenticated 的权限。


-- ============================================================
-- 第 4 步：验证
-- ============================================================
SELECT 'Storage 剩余危险策略' AS 项目,
       count(*)::text AS 数量,
       CASE WHEN count(*) = 0 THEN '✅' ELSE '❌ 还有' END AS 结论
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND cmd IN ('DELETE','UPDATE')
   AND (qual IS NULL OR qual::text = 'true')

UNION ALL

SELECT '内部函数还能调的',
       count(*)::text,
       CASE WHEN count(*) = 0 THEN '✅' ELSE '❌ 还有' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_credit_gain_on_repay','_holder_ratio','_loan_force_collect',
                     '_stock_allowed','comments_guard','_loan_alert_early',
                     'random_fluctuate_market_values','record_daily_kline',
                     'run_auto_support','sample_market_snapshot')
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))

UNION ALL

SELECT '备份表还敞开的',
       count(*)::text,
       CASE WHEN count(*) = 0 THEN '✅' ELSE '❌ 还有' END
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
   AND (c.relname LIKE '\_%bak%' OR c.relname LIKE '\_func\_backup%'
        OR c.relname LIKE '\_evidence\_%' OR c.relname LIKE '%\_backup%'
        OR c.relname LIKE '\_policy\_backup%' OR c.relname LIKE '\_credit\_loan\_backup%')
   AND (has_table_privilege('anon', c.oid, 'SELECT')
     OR has_table_privilege('anon', c.oid, 'INSERT')
     OR has_table_privilege('authenticated', c.oid, 'SELECT')
     OR has_table_privilege('authenticated', c.oid, 'INSERT'));


-- ============================================================
--  还剩两件事（这次【没做】，要你确认后再动）
-- ============================================================
--
--  ① pay_dividend 缺鉴权
--       它校验了「参数里的 uuid 是不是公司创始人」，但没验证调用者身份。
--       攻击者知道创始人 uuid 就能反复触发分红，把公司账上掏空、股价砸下来。
--       修法：加 p_session 参数 + _user_ok 校验。
--       ⚠️ 这会新建一个重载，必须同时 DROP 掉旧的 3 参数版本
--          （上次 update_support_rule 就是忘了 DROP，留了个后门）。
--       前端（Beta/stock-Beta.html 和 Virtual stock.html）也要跟着传 p_session。
--       等你说动，我一起改。
--
--  ② 管理员密码是【明文】存的
--       check_admin_password_plain 的实现：
--           SELECT value INTO stored_pwd FROM admin_config WHERE key = 'admin_password';
--           RETURN stored_pwd IS NOT NULL AND stored_pwd = input_pwd;
--       明文比较。这本身还算能接受（因为 admin_config 有 RLS），
--       但【必须确认 anon 读不到 admin_config】——
--       要是能读，管理员密码就是公开的。
--       下一句就是查这个的：
--
SELECT polname, polcmd, polroles::regrole[], pg_get_expr(polqual, polrelid) AS 条件
  FROM pg_policy
 WHERE polrelid = 'public.admin_config'::regclass;
--
--       跑出来如果 roles 里有 anon 或者条件是 true，就是🔴严重问题。
-- ============================================================
