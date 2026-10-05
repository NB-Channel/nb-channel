-- ============================================================
--  查 bank_credit_loan 那个「没有鉴权的旧重载」有没有被锁住
--
--  情况：
--      bank_credit_loan(p_user_id, p_amount, p_days, p_session)   499 字符   壳，有鉴权
--      bank_credit_loan(p_user_id, p_amount, p_days)             3058 字符   旧版，【没有 session 参数】
--
--  4 参数那个是正规入口：它先 _user_ok 验会话，再转发给 _orig_。
--  3 参数那个是 AMM 之前遗留的完整实现，参数里没有 session ——
--  也就是说它自己不验身份。要是它能被 anon 调用，
--  那任何人只要知道别人的 uuid，就能以别人的名义借钱。
--
--  这个查询查三件事（只读）：
--    一、这个重载的权限（谁能 EXECUTE）
--    二、_orig_* 那一批有没有被锁住
--    三、顺带扫一遍全库：还有没有别的「函数名相同、参数个数不同」的重载
--
--  跑完把结果发我。
-- ============================================================


-- ============================================================
-- 一、两个 bank_credit_loan 重载各自谁能调用
-- ============================================================
SELECT
    p.oid                                              AS 函数id,
    pg_get_function_identity_arguments(p.oid)          AS 参数,
    length(pg_get_functiondef(p.oid))                  AS 源码长度,
    p.prosecdef                                        AS 是SECURITY_DEFINER,
    CASE WHEN p.proacl IS NULL THEN
              '（默认：PUBLIC 可执行 ⚠️）'
         ELSE array_to_string(p.proacl, '  ')
    END                                                AS 权限,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '⚠️ anon 能调' ELSE '✅ anon 不能调' END AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN 'authenticated 能调' ELSE 'authenticated 不能调' END AS authenticated
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'bank_credit_loan'
 ORDER BY length(pg_get_functiondef(p.oid));


-- ============================================================
-- 二、_orig_* 那一批有没有锁住（它们没有自己的鉴权，全靠外层壳）
-- ============================================================
SELECT
    p.proname                                          AS 函数,
    pg_get_function_identity_arguments(p.oid)          AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '⚠️ anon 能调' ELSE '✅ anon 不能调' END AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN '⚠️ 能调' ELSE '✅ 不能调' END        AS authenticated
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%')
 ORDER BY p.proname;


-- ============================================================
-- 三、全库扫一遍：还有哪些函数名有多个重载
--     （重载本身不是错，但「有鉴权的壳 + 没鉴权的旧版」这种组合要警惕）
-- ============================================================
SELECT
    p.proname                                          AS 函数名,
    count(*)                                           AS 重载个数,
    string_agg(pg_get_function_identity_arguments(p.oid), '  |  ' ORDER BY p.oid) AS 各版本参数,
    count(*) FILTER (WHERE position('p_session' in pg_get_function_identity_arguments(p.oid)) > 0)
                                                       AS 带session的版本数,
    count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE'))
                                                       AS anon可调的版本数
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'                 -- 只看普通函数，不含聚合/窗口
   AND p.proname NOT LIKE '\_orig\_%'
 GROUP BY p.proname
HAVING count(*) > 1
 ORDER BY count(*) DESC, p.proname
 LIMIT 40;


-- ============================================================
--  怎么读
-- ============================================================
--  · 第一张表：如果那个 3 参数版本显示「⚠️ anon 能调」，
--    那是个真漏洞 —— 任何人知道别人 uuid 就能冒名借钱。
--    修法：DROP 掉那个旧重载（正规入口是 4 参数那个）。
--
--  · 第二张表：_orig_* 应该【全部】是「anon 不能调 / authenticated 不能调」。
--    它们没有自己的鉴权，谁都能调就等于绕过所有检查。
--
--  · 第三张表：重载个数 > 1 且「带 session 的版本数」小于总数，
--    说明有版本不验身份 —— 逐个看要不要删。
-- ============================================================
