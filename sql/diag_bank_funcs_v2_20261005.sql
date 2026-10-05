-- ============================================================
--  诊断（第二版）：银行函数的真实结构
--
--  上一版诊断拿到 get_bank_account 的片段，才看清库里的结构：
--
--      get_bank_account(p_user_id, p_session)
--          → 鉴权 → RETURN public._orig_get_bank_account(p_user_id)
--
--  也就是说：数据库上有一层「鉴权壳」，真正的实现叫 _orig_*。
--  我之前的锚点找的是壳，壳里当然没有业务逻辑 —— 这就是没匹配上的原因。
--
--  这个查询把【所有】银行相关函数一次列全，包括 _orig_*，
--  并直接标出每处锚点在哪个函数里存在。
--
--  只读。跑完把三张表都发我。
-- ============================================================


-- ============================================================
-- 一、所有名字里带 bank 的函数（壳和实体都列出来）
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    length(pg_get_functiondef(p.oid))             AS 源码长度,
    -- 壳的特征：函数体里只有一句 RETURN public._orig_xxx
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%_orig_%'
          AND length(pg_get_functiondef(p.oid)) < 700
         THEN '壳（鉴权转发）' ELSE '实体' END     AS 类型,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%存款总额上限%'
         THEN '已加固' ELSE '' END                AS 加固状态
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname ILIKE '%bank%'
 ORDER BY p.proname;


-- ============================================================
-- 二、我打算改的那几处锚点，到底在哪个函数里
-- ============================================================
SELECT
    p.proname AS 函数,
    position('今日活期存款已达上限' in pg_get_functiondef(p.oid)) > 0   AS 活期日限提示,
    position('1000万/天' in pg_get_functiondef(p.oid)) > 0             AS 活期日限文案,
    position('v_today_dep' in pg_get_functiondef(p.oid)) > 0           AS v_today_dep变量,
    position('deposit = deposit + p_amount' in pg_get_functiondef(p.oid)) > 0
                                                                       AS 加活期那句,
    position('fixed7 = fixed7 + p_amount' in pg_get_functiondef(p.oid)) > 0
                                                                       AS 加定期7那句,
    position('fixed30 = fixed30 + p_amount' in pg_get_functiondef(p.oid)) > 0
                                                                       AS 加定期30那句,
    position('0.8' in pg_get_functiondef(p.oid)) > 0                   AS 抵押比例0_8,
    position('v_limit :=' in pg_get_functiondef(p.oid)) > 0            AS 有额度计算,
    position('credit_score' in pg_get_functiondef(p.oid)) > 0          AS 用信誉分,
    position('v_interest :=' in pg_get_functiondef(p.oid)) > 0         AS 有计息,
    position('0.001' in pg_get_functiondef(p.oid)) > 0                 AS 活期利率,
    position('0.02' in pg_get_functiondef(p.oid)) > 0                  AS 定期7利率,
    position('0.10' in pg_get_functiondef(p.oid)) > 0                  AS 定期30利率
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname ILIKE '%bank%'
 ORDER BY p.proname;


-- ============================================================
-- 三、把「实体函数」的关键片段原样打印出来
--     壳跳过（没内容），只打印真正有逻辑的那些
-- ============================================================

-- 3.1 存款相关：找到含「deposit = deposit + p_amount」的那个函数，打印前后
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('deposit = deposit + p_amount' in pg_get_functiondef(p.oid)) - 1500, 1)
              for 2200) AS 片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname ILIKE '%bank%'
   AND position('deposit = deposit + p_amount' in pg_get_functiondef(p.oid)) > 0;

-- 3.2 定期相关：找到含「fixed30 = fixed30 + p_amount」的那个函数
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('fixed30 = fixed30 + p_amount' in pg_get_functiondef(p.oid)) - 1800, 1)
              for 2400) AS 片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname ILIKE '%bank%'
   AND position('fixed30 = fixed30 + p_amount' in pg_get_functiondef(p.oid)) > 0;

-- 3.3 贷款相关：找到含「v_limit :=」的那个函数
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('v_limit :=' in pg_get_functiondef(p.oid)) - 1200, 1)
              for 2000) AS 片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname ILIKE '%bank%'
   AND position('v_limit :=' in pg_get_functiondef(p.oid)) > 0;

-- 3.4 计息相关：找到含「v_interest :=」的那个函数
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('v_interest :=' in pg_get_functiondef(p.oid)) - 400, 1)
              for 2200) AS 片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname ILIKE '%bank%'
   AND position('v_interest :=' in pg_get_functiondef(p.oid)) > 0;

-- 3.5 账户读取（额度显示）：含 collateral_limit 的那个
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('collateral_limit' in pg_get_functiondef(p.oid)) - 900, 1)
              for 1600) AS 片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname ILIKE '%bank%'
   AND position('collateral_limit' in pg_get_functiondef(p.oid)) > 0;


-- ============================================================
--  这次的做法和上次的区别
-- ============================================================
--  上次：照着仓库里的 sql/bank.sql 猜锚点 → 猜错，被守卫拦下。
--  这次：先让数据库自己告诉我函数叫什么、逻辑在哪，
--        再照【实际源码】写替换 —— 不再依赖仓库文件。
--
--  ⚠️ 如果第三部分某一段没输出，说明那个锚点在所有银行函数里都不存在，
--     那就要再放宽搜索（比如换成别的关键词）。
-- ============================================================
