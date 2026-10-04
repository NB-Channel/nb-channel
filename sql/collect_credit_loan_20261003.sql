-- ============================================================
-- 信用贷逾期收款：扣款（允许扣成负数）
-- ============================================================
--
-- 【背景】
-- 两笔信用贷逾期未还，且两人存款都是 0（空手套）：
--     M                信誉分 700   欠款 1,530,280
--     小NB快餐厅官号     信誉分 910   欠款 1,509,021
--     合计 3,039,301
--
-- 站长决定：直接扣，允许扣成负数 —— 欠债就是欠债，余额负着。
--
-- 【扣成负数会怎样】
--   · buy_stock / sell_stock 会检查余额，负数时买不了东西
--   · bank_deposit 同理，存不了（除非先赚回来）
--   · 签到、红包、转账收款仍然能加钱 —— 所以有还清的路径
--   · 效果等于「账户被冻结到还清为止」
--
-- 【执行顺序】
--   第 0 步备份 → 第 1 步看现状 → 第 2 步扣款 → 第 3 步验收
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第 0 步：备份
-- ============================================================
DROP TABLE IF EXISTS public._credit_loan_backup_20261003;
CREATE TABLE public._credit_loan_backup_20261003 AS
SELECT b.user_id, p.username,
       b.loan_credit          AS 欠款,
       p.nb_balance           AS 扣款前余额,
       b.credit_score         AS 信誉分,
       b.loan_credit_until    AS 原到期时间,
       now()                  AS 备份时间
  FROM public.bank_accounts b
  LEFT JOIN public.profiles p ON p.id = b.user_id
 WHERE b.loan_credit > 0;

SELECT * FROM public._credit_loan_backup_20261003;


-- ============================================================
-- 第 1 步：预览扣完会变成多少（只查不改）
-- ============================================================
SELECT
    p.username                          AS 用户名,
    b.loan_credit                       AS 欠款,
    COALESCE(p.nb_balance, 0)           AS 扣款前余额,
    COALESCE(p.nb_balance, 0) - b.loan_credit AS 扣款后余额,
    CASE WHEN COALESCE(p.nb_balance,0) - b.loan_credit < 0
         THEN '⚠️ 会变负' ELSE '够扣' END AS 结果
  FROM public.bank_accounts b
  JOIN public.profiles p ON p.id = b.user_id
 WHERE b.loan_credit > 0
 ORDER BY b.loan_credit DESC;

-- 顺便记一下全站总量（改完对比，应该正好少 3,039,301）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额_扣款前 FROM public.profiles;


-- ============================================================
-- 第 2 步：扣款
-- ============================================================
DO $$
DECLARE
    r RECORD;
    v_before bigint;
    v_after  bigint;
    v_n      int := 0;
BEGIN
    FOR r IN
        SELECT b.user_id, b.loan_credit, p.username,
               COALESCE(p.nb_balance, 0) AS bal
          FROM public.bank_accounts b
          JOIN public.profiles p ON p.id = b.user_id
         WHERE b.loan_credit > 0
    LOOP
        v_before := r.bal;

        -- ⭐ 直接扣，不设下限 —— 允许扣成负数
        UPDATE public.profiles
           SET nb_balance = COALESCE(nb_balance, 0) - r.loan_credit
         WHERE id = r.user_id
         RETURNING nb_balance INTO v_after;

        -- 记一笔流水，方便以后对账
        INSERT INTO public.bank_logs (user_id, type, amount, detail)
        VALUES (r.user_id, 'repay_credit', r.loan_credit,
                format('信用贷逾期强制扣款（欠款 %s，余额 %s → %s）',
                       r.loan_credit, v_before, v_after));

        -- 清掉欠款标记（钱已经收了）
        UPDATE public.bank_accounts
           SET loan_credit = 0,
               loan_credit_until = NULL
         WHERE user_id = r.user_id;

        RAISE NOTICE '% ：欠款 % 已扣，余额 % → %',
                     r.username, r.loan_credit, v_before, v_after;
        v_n := v_n + 1;
    END LOOP;

    RAISE NOTICE '共处理 % 笔信用贷逾期', v_n;
END $$;


-- ============================================================
-- 第 3 步：验收
-- ============================================================
-- 3.1 两人的余额
SELECT p.username, p.nb_balance AS 扣款后余额
  FROM public.profiles p
 WHERE p.id IN (SELECT user_id FROM public._credit_loan_backup_20261003);

-- 3.2 欠款清零
SELECT count(*) AS 剩余未还笔数 FROM public.bank_accounts WHERE loan_credit > 0;

-- 3.3 全站总量（应该比扣款前正好少 3,039,301）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额_扣款后 FROM public.profiles;

-- 3.4 扣款流水
SELECT user_id, type, amount, detail, created_at
  FROM public.bank_logs
 WHERE type = 'repay_credit' AND detail LIKE '%逾期强制扣款%'
 ORDER BY created_at DESC LIMIT 10;


-- ============================================================
-- 第 4 步：防止再发生 —— 给信用贷加存款背书
-- ------------------------------------------------------------
-- 扣款只是收尾，根子还在 bank_credit_loan 本身：
-- 它不看存款就放款，等于注册个号就能印钱。
--
-- 完整修法在 fix_credit_loan_20261003.sql 的第二步，
-- 核心是一句：
--     v_limit := LEAST(信誉分额度, 存款 × 2)
--
-- 下面给一个【更省事的版本】：不重写整个函数，
-- 而是在最开头加一道存款检查。但你得先给我 bank_credit_loan
-- 的线上定义，我才能把整段补全 —— 或者直接用那份完整的。
-- ============================================================

-- 临时止血：直接把信用贷关掉（想恢复时改成原定义即可）
-- CREATE OR REPLACE FUNCTION public.bank_credit_loan(uuid, bigint, integer)
-- RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
-- AS $fn$ BEGIN
--     RETURN jsonb_build_object('success', false,
--         'message', '信用贷暂时下线维护，请使用抵押贷');
-- END $fn$;


-- ============================================================
-- 回滚
-- ============================================================
-- 从备份表还原余额：
-- UPDATE public.profiles p
--    SET nb_balance = b.扣款前余额
--   FROM public._credit_loan_backup_20261003 b
--  WHERE p.id = b.user_id;
--
-- （欠款记录不会自动恢复 —— 如果只是扣错了想撤回，
--   还原余额就够了，欠款本来就该收。）
