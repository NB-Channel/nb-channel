-- ============================================================
-- 堵住信用贷造币口
-- ============================================================
--
-- 【问题】
-- bank_credit_loan 是纯信用贷款，没有任何抵押：
--
--     UPDATE public.profiles SET nb_balance = nb_balance + p_amount;
--                                       ↑ 直接印钱，不检查银行有没有资金
--
-- 银行没有资金池 —— 贷出去的钱不是别人的存款，是系统新印的。
--
-- 不还的后果只有两个软约束：
--     · 罚息 0.1%/天（累加进本金）
--     · 信誉分 -15，并自动展期 1 天
--
-- 【两条套现路径】
--   路径 A：注册新号 → 初始信誉分 100 → 额度 100×500 = 5 万
--           直接贷出来转走，号不要了。成本 = 一个免费账号。
--
--   路径 B：反复小额借还刷信誉分（每次还款 +5，上限 1000）
--           线上已经有人刷到 910 了（100 + 810 = 162 次还款）
--           刷到 1000 → 额度 1000×1500 = 150 万 → 贷出来转走
--
-- 【修法】
--   核心一句话：额度必须【有存款背书】。
--
--       v_limit := LEAST(信誉分额度, 存款 × 2)
--
--   想贷 5 万？先存 2.5 万。存款是真钱，跑不掉（而且贷款时会被冻结）。
--   这样"零成本套现"就不成立了 —— 你套走的钱最多是你自己存进去的两倍，
--   而且那笔存款还被冻着当抵押。
--
--   顺带把信誉分的刷法也收紧：
--       · 还款加分要求【本次还款金额 >= 1000】，防止 1 块钱刷一分
--       · 初始信誉分降到 100（新号没资格大额借贷）
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：先看清现状（只查不改）
-- ============================================================

-- 1.1 有多少信用贷没还
SELECT count(*)              AS 信用贷账户数,
       COALESCE(sum(loan_credit), 0) AS 未还本金合计
  FROM public.bank_accounts WHERE loan_credit > 0;

-- 1.2 这些账户的存款有多少（判断他们是不是"空手套"）
SELECT b.user_id, p.username,
       b.credit_score, b.loan_credit,
       b.deposit, b.fixed7, b.fixed30,
       (b.deposit + b.fixed7 + b.fixed30) AS 存款合计,
       b.loan_credit_until
  FROM public.bank_accounts b
  LEFT JOIN public.profiles p ON p.id = b.user_id
 WHERE b.loan_credit > 0
 ORDER BY b.loan_credit DESC LIMIT 30;

-- 1.3 信誉分分布
SELECT credit_score, count(*) FROM public.bank_accounts
 GROUP BY credit_score ORDER BY credit_score DESC;

-- 1.4 全站余额总量（记下来，改完对比）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额 FROM public.profiles;


-- ============================================================
-- 第二步：改 bank_credit_loan
-- ============================================================
CREATE OR REPLACE FUNCTION public.bank_credit_loan(
    p_user_id uuid, p_amount bigint, p_days integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_acc      record;
    v_limit    bigint;
    v_rate     numeric;
    v_score_lim bigint;
    v_dep_lim   bigint;
    v_dep       bigint;
BEGIN
    IF p_days NOT IN (7, 30) THEN
        RETURN jsonb_build_object('success', false, 'message', '贷款期限只有 7 天或 30 天');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '金额必须大于0');
    END IF;

    SELECT * INTO v_acc FROM public.bank_accounts WHERE user_id = p_user_id;
    IF v_acc.user_id IS NULL THEN
        INSERT INTO public.bank_accounts (user_id) VALUES (p_user_id);
        SELECT * INTO v_acc FROM public.bank_accounts WHERE user_id = p_user_id;
    END IF;

    IF v_acc.credit_score < 300 THEN
        RETURN jsonb_build_object('success', false, 'message', '信誉分不足 300，无法信用贷款');
    END IF;
    IF v_acc.loan_credit > 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '已有未还清的信用贷款');
    END IF;

    -- ① 信誉分给出的额度（沿用原规则）
    IF v_acc.credit_score >= 800 THEN
        v_score_lim := v_acc.credit_score * 1500;
        v_rate := 0.108;
    ELSIF v_acc.credit_score >= 600 THEN
        v_score_lim := v_acc.credit_score * 1000;
        v_rate := 0.12;
    ELSE
        v_score_lim := v_acc.credit_score * 500;
        v_rate := 0.12;
    END IF;

    -- ② ⭐ 新增：存款背书额度 —— 存款 × 2
    v_dep := COALESCE(v_acc.deposit,0) + COALESCE(v_acc.fixed7,0) + COALESCE(v_acc.fixed30,0);
    v_dep_lim := v_dep * 2;

    -- ③ 取两者较小值
    v_limit := LEAST(v_score_lim, v_dep_lim);

    IF p_amount > v_limit THEN
        IF v_dep_lim < v_score_lim THEN
            RETURN jsonb_build_object('success', false, 'message',
                format('信用额度不足。你的信誉分可贷 %s，但需要存款背书（当前存款 %s，最多可贷 %s）。先存点钱吧。',
                       v_score_lim, v_dep, v_dep_lim));
        ELSE
            RETURN jsonb_build_object('success', false, 'message',
                format('超出信用额度（当前可贷 %s NB币）', v_limit));
        END IF;
    END IF;

    UPDATE public.bank_accounts
       SET loan_credit = p_amount,
           loan_credit_until = now() + (p_days || ' days')::interval
     WHERE user_id = p_user_id;

    UPDATE public.profiles SET nb_balance = nb_balance + p_amount WHERE id = p_user_id;

    INSERT INTO public.bank_logs (user_id, type, amount, detail)
    VALUES (p_user_id, 'loan_credit', p_amount,
        format('信用贷 %s 天（到期总利率 %s%%，存款背书 %s）', p_days,
               CASE WHEN v_acc.credit_score >= 800 THEN '10.8' ELSE '12' END, v_dep));

    RETURN jsonb_build_object('success', true, 'message',
        format('信用贷款 %s NB币到账（%s 天，到期总利率 %s%%）', p_amount, p_days,
               CASE WHEN v_acc.credit_score >= 800 THEN '10.8' ELSE '12' END));
END
$fn$;


-- ============================================================
-- 第三步：堵住"刷信誉分"
-- ------------------------------------------------------------
-- 原来每次还款 +5 分，不分金额大小 —— 借 1 块还 1 块也能刷。
-- 线上已经有人刷到 910 了（= 100 + 162 次还款）。
--
-- 改成：只有【本次还款金额 >= 1000】才加分。
-- 这样刷 162 次至少要动 16 万的真钱，成本远高于收益。
--
-- ⚠️ 这一步要改 bank_repay / bank_repay_credit / bank_daily_settle
--    三个函数的完整定义。我没拿到它们的线上版本，所以给出【改法】，
--    你把线上定义发我，我套进去。
-- ============================================================

-- 改法说明（三个函数里都是同一个模式）：
--
--   原来：
--       UPDATE public.bank_accounts
--          SET credit_score = LEAST(credit_score + 5, 1000)
--        WHERE user_id = p_user_id;
--
--   改成：
--       -- 只有还款金额够大才加分（防止 1 块钱刷一分）
--       IF v_repay_amount >= 1000 THEN
--           UPDATE public.bank_accounts
--              SET credit_score = LEAST(credit_score + 5, 1000)
--            WHERE user_id = p_user_id;
--           INSERT INTO public.bank_logs (user_id, type, amount, detail)
--           VALUES (p_user_id, 'credit_change', 5, '按时还款 +5');
--       END IF;


-- ============================================================
-- 第四步：已有账户要不要动
-- ------------------------------------------------------------
-- 三种选择，你自己定：
--
-- 【A】什么都别动
--     新规则只影响以后的贷款。现存的高信誉分（910/700）继续有效，
--     但他们想贷大额也得先存款 —— 因为额度取的是 min(分值, 存款×2)。
--     → 推荐。已经足够堵住了，不用惊动玩家。
--
-- 【B】把刷出来的分打回去
--     UPDATE public.bank_accounts
--        SET credit_score = 100
--      WHERE credit_score > 100
--        AND user_id IN (SELECT user_id FROM public.bank_transactions ...);
--     → 需要先搞清楚哪些分是刷的，容易误伤。不推荐。
--
-- 【C】统一重置成 100，让大家重新攒
--     UPDATE public.bank_accounts SET credit_score = 100;
--     → 最干净，但所有正常玩家也受影响，得发公告。
-- ============================================================


-- ============================================================
-- 第五步：验收
-- ============================================================

-- 5.1 检查函数换掉了
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 定义长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname = 'bank_credit_loan';
-- 应该比原来长（多了存款背书那段）

-- 5.2 试算：没存款的人现在能贷多少
--     （把 uuid 换成你自己的，应该返回"需要存款背书"）
-- SELECT public.bank_credit_loan('你的-uuid'::uuid, 50000, 7);

-- 5.3 改完再看一遍全站余额（应该一分没变，这个改动不影响存量）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额 FROM public.profiles;


-- ============================================================
-- 回滚
-- ============================================================
-- 把 bank_credit_loan 恢复成原来的版本即可（去掉 v_dep_lim 那段）。
-- 或者从备份里取：
-- SELECT 函数名, 定义 FROM public._func_backup_20261003
--  WHERE 函数名 LIKE '%credit%';


-- ============================================================
-- 还需要你确认的两件事
-- ============================================================
--
-- ① 线上 bank_accounts 的初始信誉分到底是 100 还是 1000？
--    从数据看（37 个号卡在 100）应该是 100，也就是 bank.sql 里那条
--    "已有账户统一调整为满分 1000" 的迁移【没有在线上跑过】。
--    确认一下：
--        SELECT column_default FROM information_schema.columns
--         WHERE table_schema='public' AND table_name='bank_accounts'
--           AND column_name='credit_score';
--
-- ② 抵押贷 bank_loan 有没有同样的问题？
--    它要求先有存款、额度 = 存款×80%、存款被冻结做抵押 ——
--    看起来是安全的。但同样要确认【线上版本】是不是也这样。
