-- ============================================================
-- 信誉分规则重写
-- ============================================================
--
-- 【漏洞：信誉分能刷，刷完就能大额套现】
--
--   原来的规则：每次还款 +5，没有任何条件。
--
--   实测利用方式：
--       存 12500 → 贷 10000 → 当天还掉 → +5 分
--       成本只有 1 天利息 33 NB，收益 5 分
--       重复 120 次 = 花 3960 NB 换 600 分
--       信誉分 700 → 信用贷额度 700 × 1500 = 105 万
--
--   线上已经有两个人这么干了：
--       M               信誉分 700（刷了 60 次），贷了 150 万
--       小NB快餐厅官号    信誉分 910（刷了 54 次），贷了 150 万
--
--   ⚠️ 注意：光加"还款金额 ≥ 10000"的门槛【没用】——
--      钱是循环的，一万块转 120 圈就行。
--      真正能卡住的是【时间】。
--
-- 【新规则】
--
--   信誉分起点 100，上限 1000
--
--   还款加分 +5，三个条件必须同时满足：
--       ① 贷款已持有 ≥ 3 天     ← 卡住高频刷分（刷 120 次要 360 天）
--       ② 本次还款 ≥ 10000      ← 卡住小额刷分
--       ③ 当天还没加过分         ← 卡住脚本并发
--
--   扣分（沿用）：
--       逾期每天 -15
--       被强制扣款 -30
--
--   正常玩家验证：存钱 → 借钱 → 3 天后还 → +5。
--       一个月还 10 次 = +50，一年 +600。合理。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：先看现在有多少人的分数是刷出来的（只查不改）
-- ============================================================
SELECT b.user_id, p.username, b.credit_score,
       b.loan_principal, b.loan_credit,
       (SELECT count(*) FROM public.bank_logs l
         WHERE l.user_id = b.user_id AND l.type = 'credit_change' AND l.amount > 0)
             AS 加分次数,
       (SELECT count(*) FROM public.bank_logs l
         WHERE l.user_id = b.user_id AND l.type = 'repay'
            OR (l.user_id = b.user_id AND l.type = 'repay_credit'))
             AS 还款次数
  FROM public.bank_accounts b
  LEFT JOIN public.profiles p ON p.id = b.user_id
 WHERE b.credit_score > 100
 ORDER BY b.credit_score DESC;


-- ============================================================
-- 第二步：备份现有的两个函数
-- ============================================================
DROP TABLE IF EXISTS public._func_backup_credit_20261003;
CREATE TABLE public._func_backup_credit_20261003 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_bank_repay', '_orig_bank_repay_credit');

SELECT 函数名, length(定义) AS 定义长度 FROM public._func_backup_credit_20261003;


-- ============================================================
-- 第三步：加分工具函数
-- ------------------------------------------------------------
-- 三个条件一起判断，满足才加。返回有没有加上，方便记日志。
-- ============================================================
CREATE OR REPLACE FUNCTION public._credit_gain_on_repay(
    p_user_id   uuid,
    p_loan_type text,      -- 'loan'（抵押贷）或 'loan_credit'（信用贷）
    p_amount    bigint)    -- 本次还款总额
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_days_held integer;
    v_loan_at   timestamptz;
    v_gained    integer;
BEGIN
    -- ① 本次还款金额够大吗（防止借 1 块还 1 块）
    IF COALESCE(p_amount, 0) < 10000 THEN
        RETURN false;
    END IF;

    -- ② 贷款持有了几天（防止当天借当天还）
    SELECT created_at INTO v_loan_at
      FROM public.bank_logs
     WHERE user_id = p_user_id AND type = p_loan_type
     ORDER BY id DESC LIMIT 1;
    IF v_loan_at IS NULL THEN
        RETURN false;
    END IF;
    v_days_held := floor(extract(epoch FROM (now() - v_loan_at)) / 86400);
    IF v_days_held < 3 THEN
        RETURN false;
    END IF;

    -- ③ 今天已经加过了吗（防止脚本并发刷）
    SELECT count(*) INTO v_gained
      FROM public.bank_logs
     WHERE user_id = p_user_id
       AND type = 'credit_change'
       AND amount > 0
       AND created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Shanghai')
                        AT TIME ZONE 'Asia/Shanghai';
    IF v_gained > 0 THEN
        RETURN false;
    END IF;

    -- 三个条件都满足，加分
    UPDATE public.bank_accounts
       SET credit_score = LEAST(credit_score + 5, 1000)
     WHERE user_id = p_user_id;

    INSERT INTO public.bank_logs (user_id, type, amount, detail)
    VALUES (p_user_id, 'credit_change', 5,
            format('按时还款 +5（持有 %s 天，还款 %s）', v_days_held, p_amount));

    RETURN true;
END
$fn$;


-- ============================================================
-- 第四步：重写 _orig_bank_repay（还抵押贷）
-- ------------------------------------------------------------
-- 逻辑基于 bank.sql 里的版本，只把「无条件 +5」换成调用工具函数。
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_bank_repay(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_acc        record;
    v_loan_start timestamptz;
    v_days       integer;
    v_interest   bigint;
    v_total      bigint;
    v_balance    bigint;
    v_gained     boolean := false;
BEGIN
    SELECT * INTO v_acc FROM public.bank_accounts WHERE user_id = p_user_id;
    IF v_acc.user_id IS NULL OR v_acc.loan_principal <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '没有未还清的抵押贷款');
    END IF;

    SELECT created_at INTO v_loan_start
      FROM public.bank_logs
     WHERE user_id = p_user_id AND type = 'loan'
     ORDER BY id DESC LIMIT 1;
    IF v_loan_start IS NULL THEN
        v_loan_start := now() - interval '1 day';
    END IF;

    v_days := GREATEST(ceil(extract(epoch FROM (now() - v_loan_start)) / 86400), 1);
    v_interest := floor(v_acc.loan_principal * 0.10 * v_days / 30);
    v_total := v_acc.loan_principal + v_interest;

    SELECT nb_balance INTO v_balance FROM public.profiles WHERE id = p_user_id;
    IF COALESCE(v_balance, 0) < v_total THEN
        RETURN jsonb_build_object('success', false, 'message',
            format('余额不足（需还 %s NB币，当前余额 %s）', v_total, COALESCE(v_balance, 0)));
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - v_total WHERE id = p_user_id;
    UPDATE public.bank_accounts
       SET loan_principal = 0, loan_until = NULL,
           frozen = false, frozen_amount = 0
     WHERE user_id = p_user_id;

    INSERT INTO public.bank_logs (user_id, type, amount, detail)
    VALUES (p_user_id, 'repay', v_total,
            format('偿还抵押贷（本金 %s + 利息 %s，%s 天）',
                   v_acc.loan_principal, v_interest, v_days));

    -- ⭐ 信誉分：换成有条件加分
    v_gained := public._credit_gain_on_repay(p_user_id, 'loan', v_total);

    RETURN jsonb_build_object('success', true, 'message',
        format('已还款 %s NB币（本金 %s + 利息 %s），存款已解冻%s',
               v_total, v_acc.loan_principal, v_interest,
               CASE WHEN v_gained THEN '，信誉分 +5'
                    ELSE '（本次不加信誉分：需还款满 1 万、持有满 3 天、且当天未加过）' END));
END
$fn$;


-- ============================================================
-- 第五步：重写 _orig_bank_repay_credit（还信用贷）
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_bank_repay_credit(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_acc        record;
    v_loan_start timestamptz;
    v_days       integer;
    v_rate       numeric;
    v_interest   bigint;
    v_total      bigint;
    v_balance    bigint;
    v_gained     boolean := false;
BEGIN
    SELECT * INTO v_acc FROM public.bank_accounts WHERE user_id = p_user_id;
    IF v_acc.user_id IS NULL OR v_acc.loan_credit <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '没有未还清的信用贷款');
    END IF;

    SELECT created_at INTO v_loan_start
      FROM public.bank_logs
     WHERE user_id = p_user_id AND type = 'loan_credit'
     ORDER BY id DESC LIMIT 1;
    IF v_loan_start IS NULL THEN
        v_loan_start := now() - interval '1 day';
    END IF;

    v_rate := CASE WHEN v_acc.credit_score >= 800 THEN 0.108 ELSE 0.12 END;
    v_days := GREATEST(ceil(extract(epoch FROM (now() - v_loan_start)) / 86400), 1);
    v_interest := floor(v_acc.loan_credit * v_rate * v_days / 30);
    v_total := v_acc.loan_credit + v_interest;

    SELECT nb_balance INTO v_balance FROM public.profiles WHERE id = p_user_id;
    IF COALESCE(v_balance, 0) < v_total THEN
        RETURN jsonb_build_object('success', false, 'message',
            format('余额不足（需还 %s NB币，当前余额 %s）', v_total, COALESCE(v_balance, 0)));
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - v_total WHERE id = p_user_id;
    UPDATE public.bank_accounts
       SET loan_credit = 0, loan_credit_until = NULL
     WHERE user_id = p_user_id;

    INSERT INTO public.bank_logs (user_id, type, amount, detail)
    VALUES (p_user_id, 'repay_credit', v_total,
            format('偿还信用贷（本金 %s + 利息 %s，%s 天）',
                   v_acc.loan_credit, v_interest, v_days));

    v_gained := public._credit_gain_on_repay(p_user_id, 'loan_credit', v_total);

    RETURN jsonb_build_object('success', true, 'message',
        format('已还款 %s NB币（本金 %s + 利息 %s）%s',
               v_total, v_acc.loan_credit, v_interest,
               CASE WHEN v_gained THEN '，信誉分 +5'
                    ELSE '（本次不加信誉分：需还款满 1 万、持有满 3 天、且当天未加过）' END));
END
$fn$;


-- ============================================================
-- 第六步：验收
-- ============================================================
-- 6.1 三个函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('_orig_bank_repay','_orig_bank_repay_credit','_credit_gain_on_repay')
 ORDER BY 1;

-- 6.2 外壳还在（前端调的是这个）
SELECT p.proname AS 外壳, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('bank_repay','bank_repay_credit');


-- ============================================================
-- 第七步：存量信誉分怎么处理（三选一，默认不动）
-- ------------------------------------------------------------
-- 【A】不动（推荐先这样）
--     新规则只影响以后。已经刷上去的分继续用，
--     但他们的贷款已经收尾（扣成负数了），分再高也借不出钱
--     —— 因为余额是负的，bank_credit_loan 里的余额检查会拦。
--
-- 【B】把明显刷出来的分打回 100
--     判断依据：加分次数远大于"合理"次数。
--     从数据看，M 是 700（加分 60 次）、小NB快餐厅官号是 910（加分 54 次），
--     都是冲着刷分去的。
--
-- UPDATE public.bank_accounts SET credit_score = 100
--  WHERE user_id IN (
--      SELECT user_id FROM public.bank_logs
--       WHERE type='credit_change' AND amount > 0
--       GROUP BY user_id HAVING count(*) >= 20
--  );
--
-- 【C】全部重置成 100
-- UPDATE public.bank_accounts SET credit_score = 100;
--     → 最干净，但正常玩家也受影响，得发公告。


-- ============================================================
-- 回滚
-- ============================================================
-- SELECT 定义 FROM public._func_backup_credit_20261003;
-- 取出原定义重跑即可。


-- ============================================================
-- ⚠️ 执行前请确认一件事
-- ------------------------------------------------------------
-- 我是基于仓库里的 sql/bank.sql 写的 _orig_bank_repay。
-- 如果线上的版本跟仓库不一样（比如多了别的逻辑），
-- 我这个替换会把它覆盖掉。
--
-- 先对比一下：
--     SELECT 定义 FROM public._func_backup_credit_20261003
--      WHERE 函数名 = '_orig_bank_repay';
--
-- 如果里面除了「还款 + 解冻 + 信誉+5」还有别的东西，
-- 把定义发我，我把它一起并进去。
-- ============================================================
