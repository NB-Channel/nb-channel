-- ============================================================
--  93 个包装函数里，到底哪几个【真的查会话令牌】
--
--  起因：
--  前一轮查到「有 93 个函数被包装过」，于是打算逐个查
--  「前端传的是不是别人的 id」。但查到一个反例 ——
--
--      sql/ban_xiaonb2_final.sql:123-150
--          ALTER FUNCTION store_email_code(…) RENAME TO _orig_store_email_code;
--          CREATE OR REPLACE FUNCTION store_email_code(…)   ← 新包装
--          GRANT EXECUTE ON FUNCTION store_email_code(…) TO anon;
--
--  这说明 93 个 _orig_ 里，包装【不都是会话令牌校验】那一种：
--      lock_user_rpcs.sql            会话令牌校验 ← 只有这种才怕「拿别人的 id」
--      ban_xiaonb2_final.sql         封禁检查    ← 不需要会话
--      URGENT_lock_legacy_overloads  REVOKE 旧重载
--      其它加固脚本                   各有各的
--
--  佐证：store_email_code 是在【还没登录】的时候调的（注册流程）。
--        如果它要求会话，就根本没法注册 —— 而站里天天有人注册。
--
--  所以先跑这个，把范围缩到真正查会话的那批，
--  再逐个看前端传的是谁的 id，省得白查几十个。
--
--  只查不改。
-- ============================================================


-- ============================================================
-- 1. 【重点】哪些包装函数体里出现了 _user_ok
--    出现了 = 查会话令牌 = 拿别人的 id 调会失效
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%_user_ok%'
            THEN '⚠️ 查会话' ELSE '— 不查' END AS 会话校验
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname NOT LIKE '\_orig\_%'
   AND p.proname NOT LIKE '\_%'
 ORDER BY 会话校验 DESC, p.proname, 2;

-- ⚠️ 看「⚠️ 查会话」那一批 —— 只有它们才需要逐个核对前端传的是谁的 id。
--    「— 不查」的那些（封禁检查之类）跟「拿别人的 id」没关系。


-- ============================================================
-- 2. 只列查会话的那批（好复制）
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%_user_ok%') AS 查会话
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname NOT LIKE '\_orig\_%'
   AND p.proname NOT LIKE '\_%'
   AND pg_get_functiondef(p.oid) LIKE '%_user_ok%'
 ORDER BY p.proname, 2;


-- ============================================================
-- 3. 反查：每个 _orig_ 的「同名包装」现在长什么样
--    顺便看包装体是三种里的哪一种
-- ============================================================
SELECT replace(o.proname, '_orig_', '') AS 原名,
       pg_get_function_identity_arguments(o.oid) AS 原参数,
       CASE
         WHEN EXISTS (
           SELECT 1 FROM pg_proc w
            WHERE w.pronamespace = o.pronamespace
              AND w.proname = replace(o.proname, '_orig_', '')
              AND pg_get_functiondef(w.oid) LIKE '%_user_ok%')
         THEN '⚠️ 会话校验'
         WHEN EXISTS (
           SELECT 1 FROM pg_proc w
            WHERE w.pronamespace = o.pronamespace
              AND w.proname = replace(o.proname, '_orig_', ''))
         THEN '其它包装（不查会话）'
         ELSE '❌ 没有同名包装（可能被删了）'
       END AS 包装类型
  FROM pg_proc o JOIN pg_namespace n ON n.oid = o.pronamespace
 WHERE n.nspname = 'public' AND o.proname LIKE '\_orig\_%'
 ORDER BY 包装类型, 原名;

-- ⚠️ 如果出现「❌ 没有同名包装」，说明那个 _orig_ 成了孤儿 ——
--    没人调它，不算坏事，但可以清理。


-- ============================================================
-- 4. 登录/注册那几个的实际情况
--    它们是在【还没有会话】的时候调的，被套会话校验就登不进去
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon可调,
       (pg_get_functiondef(p.oid) LIKE '%_user_ok%') AS 查会话
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('login_user','login_user2','store_email_code','update_password',
                     'register_company','register_company_v2','register_company_v3',
                     'nodup_register_company')
 ORDER BY p.proname, 2;

-- 期望：这几个【都不查会话】，而且 anon可调 = true（不然登不进去/注册不了）


-- ============================================================
--  跑完看这几件事
-- ============================================================
--  ① 第 2 段有多少个「查会话」的函数 —— 那才是要逐个核对的范围。
--     如果只有三四十个，说明剩下那批是封禁检查之类，不用查。
--
--  ② 第 3 段有没有「❌ 没有同名包装」的孤儿。
--
--  ③ 第 4 段登录/注册那几个是不是都不查会话、anon 都能调。
--     如果哪个查了会话 —— 那是【登不进去】级别的问题，告诉我。
--
--  把 ①②③ 的结果发我。
-- ============================================================
