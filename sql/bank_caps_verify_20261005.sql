-- ============================================================
--  银行加固 · 收尾确认
--
--  加固脚本跑完了，六处都显示 ✅。这个查询确认两件事：
--    一、有没有重复重载（之前 update_support_rule 踩过这个坑）
--    二、存款上限那道检查插在了【正确位置】没有 ——
--        必须在「扣余额」之前，插在后面会出现「钱已扣、检查才失败」
--
--  只读。跑完把两张表发我。
-- ============================================================


-- ============================================================
-- 一、所有银行函数的重载情况
--     每个函数名应该只有一个重载（壳和实体名字不同，不算重载）
-- ============================================================
SELECT
    p.proname                                 AS 函数名,
    count(*)                                  AS 重载个数,
    string_agg(pg_get_function_identity_arguments(p.oid), '  |  ' ORDER BY p.oid)
                                              AS 各版本的参数,
    string_agg(length(pg_get_functiondef(p.oid))::text, ' / ' ORDER BY p.oid)
                                              AS 各自源码长度
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname ILIKE '%bank%'
 GROUP BY p.proname
 ORDER BY count(*) DESC, p.proname;


-- ============================================================
-- 二、存款上限那道检查的位置对不对
--     看它前面是不是「扣余额」、后面是不是「加存款」
-- ============================================================
SELECT
    p.proname AS 函数,
    -- 检查出现的位置
    position('存款总额上限' in pg_get_functiondef(p.oid))          AS 检查位置,
    -- 扣余额那句的位置
    position('nb_balance - p_amount' in pg_get_functiondef(p.oid)) AS 扣余额位置,
    -- 加存款那句的位置
    position('deposit = deposit + p_amount' in pg_get_functiondef(p.oid))
                                                                   AS 加存款位置,
    -- 加定期那句的位置
    GREATEST(
      position('fixed7 = fixed7 + p_amount' in pg_get_functiondef(p.oid)),
      position('fixed30 = fixed30 + p_amount' in pg_get_functiondef(p.oid))
    )                                                              AS 加定期位置,
    CASE
      WHEN position('存款总额上限' in pg_get_functiondef(p.oid)) = 0
        THEN '❌ 没有检查'
      WHEN position('存款总额上限' in pg_get_functiondef(p.oid))
           < NULLIF(position('nb_balance - p_amount' in pg_get_functiondef(p.oid)), 0)
        THEN '✅ 位置正确（在扣余额之前）'
      ELSE '⚠️ 位置不对 —— 插在扣余额之后了，会出现「钱已扣、检查才失败」'
    END AS 位置判断
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_bank_deposit', '_orig_bank_fixed_deposit')
 ORDER BY p.proname;


-- ============================================================
-- 三、把两个存款函数的关键片段打出来（人工再扫一眼）
-- ============================================================
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('存款总额上限' in pg_get_functiondef(p.oid)) - 350, 1)
              for 1000) AS 检查前后片段
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_bank_deposit', '_orig_bank_fixed_deposit')
   AND position('存款总额上限' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;


-- ============================================================
-- 四、贷款和计息那几处的实际写法（确认改对了）
-- ============================================================
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('100000000' in pg_get_functiondef(p.oid)) - 250, 1)
              for 700) AS 片段
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_bank_loan', '_orig_bank_credit_loan', 'bank_credit_loan')
   AND position('100000000' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;

SELECT
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('利息基数封顶' in pg_get_functiondef(p.oid)) - 300, 1)
              for 1200) AS 计息片段
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname = 'bank_daily_settle';


-- ============================================================
--  怎么读
-- ============================================================
--  · 第一张表：如果某个函数名出现「重载个数 = 2」，说明有两个同名不同参数的版本。
--    这种情况要小心 —— 前端调的时候可能匹配到没加固的那个。
--
--  · 第二张表：位置判断必须是「✅ 位置正确」。
--    如果是「⚠️ 位置不对」，那就得把检查往前挪 —— 告诉我，我改。
--
--  · 第三四张表是人工再扫一眼，看代码长得对不对。
-- ============================================================
