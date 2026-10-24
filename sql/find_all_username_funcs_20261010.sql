-- ============================================================
--  补漏：把【所有】用户名相关函数都查一遍
--
--  上一版只筛了名字含 update_username 的，结果漏了 change_username。
--  这个查询把 public 下所有「名字里带 user / name / register」的函数都列出来，
--  标明各自有没有白名单、放宽了没有。
--
--  全部只读。
-- ============================================================


-- ============================================================
-- 一、所有可能跟用户名有关的函数
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%!~%'
         THEN '有白名单' ELSE '—' END          AS 白名单,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽'
         WHEN pg_get_functiondef(p.oid) LIKE '%!~%'
         THEN '❌ 还没放宽'
         ELSE '（无白名单逻辑）' END            AS 状态,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%用户名%'
         THEN '有用户名提示' ELSE '—' END       AS 提示
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND (p.proname ILIKE '%user%'
     OR p.proname ILIKE '%name%'
     OR p.proname ILIKE '%register%')
 ORDER BY p.proname;


-- ============================================================
-- 二、重点看 change_username 和几个已知的
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%_orig_%'
         THEN '壳（转发给 _orig_）' ELSE '实体' END AS 类型,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '❌ 没放宽' END   AS 状态,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('!~' in pg_get_functiondef(p.oid)) - 60, 1)
              for 260)                        AS 白名单那句
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname IN ('change_username', 'update_username', '_orig_update_username',
                     'register_user', 'register_finish')
 ORDER BY p.proname;


-- ============================================================
-- 三、还有哪些函数在检查用户名合法性
--     （按函数体里出现「用户名」三个字来找）
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' 
         WHEN pg_get_functiondef(p.oid) LIKE '%!~%'
         THEN '❌ 有白名单但没放宽'
         ELSE '（只是提示文案，无白名单）' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND pg_get_functiondef(p.oid) LIKE '%用户名%'
 ORDER BY p.proname;


-- ============================================================
--  怎么读
-- ============================================================
--  第一张表：凡是「有白名单 + ❌ 还没放宽」的，都是漏网的，要补。
--  第二张表：重点看 change_username 是壳还是实体、有没有白名单。
--  第三张表：所有提到「用户名」的函数，确认没有漏掉的校验点。
--
--  ⚠️ 如果 change_username 有独立的白名单，说明改名的实际入口是它，
--     那我之前改的 _orig_update_username 可能根本没被调用，
--     前端改名时还是会用旧规则拦。
-- ============================================================
