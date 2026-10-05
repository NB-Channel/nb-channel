-- ============================================================
--  诊断：银行那几个函数在库里【实际】长什么样
--
--  上一版 bank_caps 脚本里，bank_deposit 的锚点没匹配上 ——
--  说明库里的版本和仓库 sql/bank.sql 不是同一版。
--
--  这个查询把每个函数的关键片段原样打印出来（只读），
--  照着实际文本改锚点，就不会再猜错。
--
--  用法：整段复制到 Supabase → SQL Editor → Run，
--        把结果全部发回来。
-- ============================================================


-- ============================================================
-- 一、总览：这些函数在库里存不存在、多长、参数是什么
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    length(pg_get_functiondef(p.oid))             AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%存款总额上限%'
         THEN '已加固' ELSE '未加固' END         AS 加固状态
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('bank_deposit','bank_fixed_deposit','bank_loan',
                     'bank_credit_loan','bank_daily_settle','get_bank_account')
 ORDER BY p.proname;


-- ============================================================
-- 二、逐个检查：我打算用的锚点在库里到底存不存在
--     （1 = 存在，0 = 不存在）
-- ============================================================
SELECT
    'bank_deposit' AS 函数,
    position('今日活期存款已达上限' in pg_get_functiondef(p.oid)) > 0 AS 有日限提示,
    position('10000000' in pg_get_functiondef(p.oid)) > 0             AS 有1000万这个数,
    position('UPDATE public.profiles SET nb_balance = nb_balance - p_amount' in pg_get_functiondef(p.oid)) > 0
                                                                      AS 有扣余额那句,
    position('v_today_dep' in pg_get_functiondef(p.oid)) > 0          AS 有v_today_dep变量
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_deposit'

UNION ALL

SELECT
    'bank_fixed_deposit',
    position('今日' in pg_get_functiondef(p.oid)) > 0,
    position('10000000' in pg_get_functiondef(p.oid)) > 0,
    position('UPDATE public.profiles SET nb_balance = nb_balance - p_amount' in pg_get_functiondef(p.oid)) > 0,
    position('v_today_dep' in pg_get_functiondef(p.oid)) > 0
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_fixed_deposit'

UNION ALL

SELECT
    'bank_loan',
    position('v_limit :=' in pg_get_functiondef(p.oid)) > 0,
    position('0.8' in pg_get_functiondef(p.oid)) > 0,
    position('超出抵押额度' in pg_get_functiondef(p.oid)) > 0,
    position('frozen_amount' in pg_get_functiondef(p.oid)) > 0
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_loan'

UNION ALL

SELECT
    'bank_daily_settle',
    position('v_interest :=' in pg_get_functiondef(p.oid)) > 0,
    position('0.001' in pg_get_functiondef(p.oid)) > 0,
    position('0.02' in pg_get_functiondef(p.oid)) > 0,
    position('0.10' in pg_get_functiondef(p.oid)) > 0
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_daily_settle';


-- ============================================================
-- 三、把关键片段原样打印出来（这是重点，照着它改锚点）
-- ============================================================

-- 3.1 bank_deposit：从「余额不足」到「UPDATE bank_accounts」那一段
SELECT
    substring(pg_get_functiondef(p.oid)
              from position('余额不足' in pg_get_functiondef(p.oid)) - 200
              for 1200) AS bank_deposit_片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_deposit';

-- 3.2 bank_fixed_deposit：从「余额不足」往后 1200 字
SELECT
    substring(pg_get_functiondef(p.oid)
              from position('余额不足' in pg_get_functiondef(p.oid)) - 200
              for 1200) AS bank_fixed_deposit_片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_fixed_deposit';

-- 3.3 bank_loan：从「v_limit」往后 600 字
SELECT
    substring(pg_get_functiondef(p.oid)
              from position('v_limit' in pg_get_functiondef(p.oid))
              for 600) AS bank_loan_片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_loan';

-- 3.4 bank_daily_settle：从第一个「v_interest」往后 1200 字
SELECT
    substring(pg_get_functiondef(p.oid)
              from position('v_interest' in pg_get_functiondef(p.oid))
              for 1200) AS bank_daily_settle_片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='bank_daily_settle';

-- 3.5 get_bank_account：从「collateral_limit」往后 400 字
SELECT
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('collateral_limit' in pg_get_functiondef(p.oid)) - 200, 1)
              for 600) AS get_bank_account_片段
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='get_bank_account';


-- ============================================================
--  我要拿这些片段做什么
-- ============================================================
--  照抄实际文本改锚点，然后重写 bank_caps 脚本。
--  这次不再靠「照仓库里那份 sql 猜」—— 以库里的实际源码为准。
--
--  顺带说一句：这次的守卫起作用了 ——
--  锚点没匹配上时它直接 RAISE EXCEPTION 停下，
--  没有出现「以为改好了其实没改」的情况。
-- ============================================================
