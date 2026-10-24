-- ============================================================
-- 紧急：给买入和增资加单笔上限
-- ============================================================
--
-- 【发生了什么】
-- Utw 用 1 分钟，6 笔买入共 558.6 亿，把他自己公司「Utw」的股价
-- 从 1.00 拉到 128,592.88，市值变成 382,631 亿。
--
--     04:45:07   买 1.05 亿    →  股价 2.7964
--     04:45:16   买 1.05 亿    →  股价 5.4963
--     04:45:31   买 15.75 亿   →  股价 154.4324
--     04:45:32   买 15.75 亿   →  股价 506.6887
--     04:45:58   买 105 亿     →  股价 8051.0234
--     04:46:29   买 420 亿     →  股价 128592.8772
--
-- 【根因：单笔买入没有上限】
-- AMM 的价格冲击是【平方级】的：
--     价格倍数 = (1 + 投入 ÷ 池子现金)²
-- 池子只有 1.49 亿，他砸 420 亿进去 → 价格涨到 (1+282)² ≈ 8 万倍。
--
-- 【修法】
--   买入：单笔不能超过【池子现金的 50%】
--         → 价格最多被推高 2.25 倍（(1+0.5)²），炸不到天上
--   增资：单笔不能超过【池子现金的 2 倍】
--         → 价格最多涨到 3 倍
--
-- 对正常玩家没有影响 —— 没人会一笔买走半个池子。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：备份
-- ============================================================
CREATE TABLE IF NOT EXISTS public._func_backup_cap_20261004 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock', 'inject_company_capital');

SELECT 函数名, length(定义) AS 长度 FROM public._func_backup_cap_20261004;


-- ============================================================
-- 第二步：买入加上限
-- ------------------------------------------------------------
-- 在你现有版本上只加一段判断，其余逻辑不动。
-- （下面按「持股 0 可买」那版重写，因为线上已经是那版了）
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_buy_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_cash    numeric;
    v_shares  numeric;
    v_k       numeric;
    v_newc    numeric;
    v_news    numeric;
    v_got     numeric;
    v_fee     numeric;
    v_total   numeric;
    v_bal     numeric;
    v_name    text;
    v_owner   uuid;
    v_p0      numeric;
    v_p1      numeric;
    v_mine    numeric;
    v_cap     numeric;      -- ⭐ 单笔上限
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '投入金额必须大于0');
    END IF;

    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false,
            'message', '当前为休市时间（每日 8:00-20:00 交易），请开盘后再操作');
    END IF;

    SELECT pool_cash::numeric, pool_shares::numeric, company_name, user_id
      INTO v_cash, v_shares, v_name, v_owner
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_cash IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;

    -- ⭐⭐ 新增：单笔买入不能超过池子现金的 50% ⭐⭐
    -- 防止一笔把价格炸到天上（AMM 的价格冲击是平方级的）
    v_cap := floor(v_cash * 0.5);
    IF p_amount > v_cap THEN
        RETURN jsonb_build_object('success', false,
            format('单笔买入不能超过池子现金的一半（当前池子 %s NB币，单笔最多买 %s）。想买更多请分几笔。',
                   round(v_cash, 0), v_cap));
    END IF;

    -- 持股为 0 的 owner 可以买（持股 > 0 则禁止）
    IF v_owner = p_user_id THEN
        SELECT COALESCE(shares, 0) INTO v_mine
          FROM public.holdings
         WHERE company_id = p_company_id AND user_id = p_user_id;
        v_mine := COALESCE(v_mine, 0);

        IF v_mine > 0 THEN
            RETURN jsonb_build_object('success', false,
                format('不能买入自己公司的股份（你是创始人，已持有 %s 张）。如果想增加持股，需要先把手上的卖掉才能再买。',
                       round(v_mine, 2)));
        END IF;
    END IF;

    v_fee := floor(p_amount * CASE WHEN p_use_discount THEN 0.02 ELSE 0.05 END);
    v_total := p_amount + v_fee;

    SELECT COALESCE(nb_balance,0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal < v_total THEN
        RETURN jsonb_build_object('success', false,
            format('NB币余额不足（需 %s，含 %s 手续费，你有 %s）', v_total, v_fee, v_bal));
    END IF;

    v_p0 := v_cash / v_shares;
    v_k  := v_cash * v_shares;
    v_newc := v_cash + p_amount;
    v_news := v_k / v_newc;
    v_got  := v_shares - v_news;

    IF v_got <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '投入金额太小，买不到股份');
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - v_total WHERE id = p_user_id;

    UPDATE public.user_companies
       SET pool_cash = v_newc, pool_shares = v_news
     WHERE id = p_company_id;

    INSERT INTO public.holdings
        (user_id, company_id, shares, cost, principal, base_market_value, updated_at)
    VALUES
        (p_user_id, p_company_id, v_got, p_amount, p_amount, v_cash, now())
    ON CONFLICT (user_id, company_id) DO UPDATE
        SET shares = COALESCE(public.holdings.shares,0) + v_got,
            cost   = COALESCE(public.holdings.cost,0)   + p_amount,
            updated_at = now();

    v_p1 := v_newc / v_news;

    INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, fee, price_after)
    VALUES (p_user_id, p_company_id, 'buy', v_total, v_got, v_fee, round(v_p1,4));

    RETURN jsonb_build_object(
        'success', true, 'ok', true,
        'message', format('买入「%s」成功：投入 %s NB币，得到 %s 张股份，均价 %s，手续费 %s',
                          v_name, p_amount, round(v_got,4),
                          round(p_amount / v_got, 4), v_fee),
        'shares', round(v_got,4),
        'avg_price', round(p_amount / v_got, 4),
        'price_before', round(v_p0,4),
        'price_after', round(v_p1,4),
        'fee', v_fee,
        'paid', v_total);
END
$fn$;


-- ============================================================
-- 第三步：增资加上限
-- ------------------------------------------------------------
-- 增资不加股份，所以价格是线性上涨：价格倍数 = 1 + 投入 ÷ 池子现金。
-- 他要是注 1 万亿进 1.49 亿的池子，价格一样炸。
-- 限制单笔不超过池子现金的 2 倍 → 价格最多涨到 3 倍。
-- ============================================================
CREATE OR REPLACE FUNCTION public.inject_company_capital(
    p_user_id    uuid,
    p_session    text,
    p_company_id bigint,
    p_amount     numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_founder uuid;
    v_name    text;
    v_pc      numeric;
    v_ps      numeric;
    v_bal     numeric;
    v_p0      numeric;
    v_p1      numeric;
    v_cap     numeric;      -- ⭐ 单笔上限
BEGIN
    IF p_session IS NULL OR NOT public.verify_session(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '增资金额必须大于 0');
    END IF;
    IF p_amount < 1000 THEN
        RETURN jsonb_build_object('success', false, 'message', '单次增资不能少于 1000 NB币');
    END IF;

    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false,
            'message', '当前为休市时间（每日 8:00-20:00），请开盘后再操作');
    END IF;

    SELECT founder_id, company_name, pool_cash::numeric, pool_shares::numeric
      INTO v_founder, v_name, v_pc, v_ps
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_founder IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;
    IF v_founder <> p_user_id THEN
        RETURN jsonb_build_object('success', false,
            'message', '只有创始人可以给公司增资');
    END IF;
    IF v_ps IS NULL OR v_ps <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '公司资金池异常，无法增资');
    END IF;

    -- ⭐⭐ 新增：单笔增资不能超过池子现金的 2 倍 ⭐⭐
    v_cap := floor(v_pc * 2);
    IF p_amount > v_cap THEN
        RETURN jsonb_build_object('success', false,
            format('单笔增资不能超过池子现金的 2 倍（当前池子 %s NB币，单笔最多 %s）。想加更多请分几次。',
                   round(v_pc, 0), v_cap));
    END IF;

    SELECT COALESCE(nb_balance, 0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal < p_amount THEN
        RETURN jsonb_build_object('success', false,
            format('余额不足（需 %s，你有 %s）', p_amount, v_bal));
    END IF;

    v_p0 := v_pc / v_ps;

    UPDATE public.profiles
       SET nb_balance = nb_balance - p_amount
     WHERE id = p_user_id;

    UPDATE public.user_companies
       SET pool_cash        = COALESCE(pool_cash,0) + p_amount,
           last_injection_at = now(),
           total_injected    = COALESCE(total_injected,0) + p_amount
     WHERE id = p_company_id;

    v_p1 := (v_pc + p_amount) / v_ps;

    INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, price_after)
    VALUES (p_user_id, p_company_id, 'inject', p_amount, 0, round(v_p1, 4));

    RETURN jsonb_build_object(
        'success', true,
        'message', format('已向「%s」增资 %s NB币。股价 %s → %s（+%s%%），全体股东共同受益。注意：7 天内你不能卖出该公司股份。',
                          v_name, round(p_amount,2), round(v_p0,4), round(v_p1,4),
                          round((v_p1 / NULLIF(v_p0,0) - 1) * 100, 2)),
        'price_before', round(v_p0,4),
        'price_after',  round(v_p1,4),
        'amount', p_amount);
END
$fn$;


-- ============================================================
-- 第四步：验收
-- ============================================================
-- 4.1 两个函数都在，而且是新版
SELECT p.proname AS 函数,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%单笔买入不能超过池子现金的一半%'
                 THEN '✅ 买入已加上限'
            WHEN pg_get_functiondef(p.oid) LIKE '%单笔增资不能超过池子现金的 2 倍%'
                 THEN '✅ 增资已加上限'
            ELSE '❓ 认不出' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('_orig_buy_stock','inject_company_capital')
 ORDER BY 1;

-- 4.2 试算：拿「Utw」试一笔超大买入，应该被拒
-- SELECT public._orig_buy_stock(
--     (SELECT id FROM public.profiles WHERE username = 'Utw' LIMIT 1),
--     (SELECT id FROM public.user_companies WHERE company_name = 'Utw' LIMIT 1),
--     100000000000, false);
-- 预期返回：「单笔买入不能超过池子现金的一半…」


-- ============================================================
-- 回滚
-- ============================================================
-- SELECT 定义 FROM public._func_backup_cap_20261004;
