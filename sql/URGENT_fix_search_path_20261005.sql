-- ============================================================
--  SECURITY DEFINER 函数缺少 search_path 固化 —— 全库排查与加固
--
--  【问题】
--  PostgreSQL 官方文档专门警告过：SECURITY DEFINER 函数必须固定 search_path。
--
--  原因是：函数体以【所有者】的身份运行（通常是 postgres，权限很大），
--  但解析表名 / 函数名时用的是【调用者的 search_path】。
--  如果调用者能把自己的 schema 排到前面，再放一张同名的假表，
--  函数就会去操作那张假表 —— 相当于把 owner 的权限借给了调用者。
--
--  典型例子（站长库里的真实情况）：
--      CREATE FUNCTION public.check_admin_password_plain(input_pwd text)
--      RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
--      AS $function$            ← 这里没有 SET search_path
--      BEGIN
--          SELECT value INTO stored_pwd FROM admin_config WHERE key = 'admin_password';
--          RETURN stored_pwd IS NOT NULL AND stored_pwd = input_pwd;
--      END
--
--  这个函数做的事就是「比对管理员密码」，一旦被冒充，
--  攻击者可以让自己建的 admin_config 表返回任意值 —— 密码校验直接通过。
--
--  【修法】
--  用 ALTER FUNCTION ... SET search_path 给函数挂上固定配置。
--  这个办法：
--    · 不用重写函数体（不会像 CREATE OR REPLACE 那样有覆盖风险）
--    · 可随时用 ALTER FUNCTION ... RESET search_path 撤销
--    · 立即生效，不需要重新部署
--
--  【为什么用 public, pg_temp】
--    pg_temp 放最后是 PostgreSQL 推荐写法 ——
--    放前面会让临时表覆盖正式表，放最后就没有这个风险。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看清有多少、都是谁
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    length(pg_get_functiondef(p.oid))             AS 源码长度,
    COALESCE(array_to_string(p.proconfig, ' | '), '（没有固定任何配置）') AS 现有配置,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN 'anon 可调' ELSE '—' END        AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN 'authenticated 可调' ELSE '—' END AS authenticated
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.prosecdef                                   -- SECURITY DEFINER
   AND NOT EXISTS (
         SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS c
          WHERE c LIKE 'search\_path=%')
 ORDER BY
   -- 先列出「anon 能调」的（最危险：外人就能触发）
   has_function_privilege('anon', p.oid, 'EXECUTE') DESC,
   p.proname;


-- ============================================================
-- 第 1 步：批量加固
-- ============================================================
DO $$
DECLARE
    r record;
    v_cnt int := 0;
    v_cnt_anon int := 0;
BEGIN
    FOR r IN
        SELECT p.oid,
               p.proname,
               pg_get_function_identity_arguments(p.oid) AS ident,
               has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_ok
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.prokind = 'f'
           AND p.prosecdef
           AND NOT EXISTS (
                 SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS c
                  WHERE c LIKE 'search\_path=%')
         ORDER BY p.proname
    LOOP
        EXECUTE format('ALTER FUNCTION public.%I(%s) SET search_path = public, pg_temp',
                       r.proname, r.ident);
        v_cnt := v_cnt + 1;
        IF r.anon_ok THEN
            v_cnt_anon := v_cnt_anon + 1;
            RAISE NOTICE '已加固（anon 可调，重点）: public.%(%)', r.proname, r.ident;
        ELSE
            RAISE NOTICE '已加固: public.%(%)', r.proname, r.ident;
        END IF;
    END LOOP;
    RAISE NOTICE '---- 共加固 % 个函数，其中 anon 可调的 % 个 ----', v_cnt, v_cnt_anon;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    count(*)                                              AS SECURITY_DEFINER函数总数,
    count(*) FILTER (WHERE EXISTS (
        SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS c
         WHERE c LIKE 'search\_path=%'))                  AS 已固定search_path的,
    count(*) FILTER (WHERE NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS c
         WHERE c LIKE 'search\_path=%'))                  AS 还没固定的,
    CASE WHEN count(*) FILTER (WHERE NOT EXISTS (
             SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS c
              WHERE c LIKE 'search\_path=%')) = 0
         THEN '✅ 全部固定了' ELSE '❌ 还有漏的' END      AS 结论
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef;

-- 再看一眼 check_admin_password_plain 这个具体的
SELECT
    p.proname                                          AS 函数,
    pg_get_function_identity_arguments(p.oid)          AS 参数,
    COALESCE(array_to_string(p.proconfig, ' | '), '❌ 还是没有') AS 配置
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'check_admin_password_plain';


-- ============================================================
-- 第 3 步：万一某个函数加固后出问题，怎么撤
-- ============================================================
--  单个撤销：
--      ALTER FUNCTION public.某个函数名(参数类型) RESET search_path;
--  例如：
--      ALTER FUNCTION public.check_admin_password_plain(text) RESET search_path;
--
--  ⚠️ 什么情况会出问题：
--      如果某个函数内部【不带 schema 前缀】地引用了 public 之外的对象
--      （比如 auth.users、storage.objects），
--      那么它原来的 search_path 里可能有那个 schema，
--      现在被固定成 public 就会找不到对象。
--
--      从第 0 步的「现有配置」那一列能看出来：
--      如果某个函数【原本就有】search_path 配置（但格式不标准被筛出来了），
--      加固后要留意它。原本什么都没配的，固定成 public 一定是变安全了
--      （因为它原本就依赖调用者的 search_path，而调用者默认也是 public）。
--
--  ⚠️ 如果跑完发现某个功能报「relation does not exist」，
--     把报错里的函数名发我，我单独处理。


-- ============================================================
--  这次没做的事
-- ============================================================
--  · 没有改任何函数体 —— 全部用 ALTER FUNCTION SET，随时可 RESET。
--  · 没有动管理员密码的存储方式（还是明文）。
--    目前 admin_config 的策略是 (key = 'announcement')，
--    密码那个 key anon 读不到，所以还算安全。
--    要更稳的话可以改成 sha256 + 盐，但那要同时改 check_admin_password_plain
--    和 admin_config 里的值，需要你确认后再动。
-- ============================================================
