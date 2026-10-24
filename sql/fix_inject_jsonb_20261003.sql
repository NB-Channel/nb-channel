-- ============================================================
-- 修复：增资报 "argument list must have even number of elements"
-- ============================================================
--
-- 原因：jsonb_build_object 要求参数【键值成对】。我在三个地方写成了
--
--     jsonb_build_object('success', false,
--         format('...', ...));
--         ↑ 少了 'message' 这个键，变成 3 个参数（奇数）
--
-- 三处分别是：
--     1. 单次增资超过上限
--     2. 余额不足
--     3. 增资后 7 天内不能卖（在 _orig_sell_stock 里）
--
-- 修法：补上 'message' 键，然后重建这两个函数。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 先备份（万一要回滚）
-- ============================================================
CREATE TABLE IF NOT EXISTS public._func_backup_inject_20261003 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('inject_company_capital', '_orig_sell_stock');

SELECT 函数名, length(定义) AS 定义长度 FROM public._func_backup_inject_20261003;


-- ============================================================
-- 重建两个函数（已修好）
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
    v_ts      numeric;
    v_cap     CONSTANT numeric := 100000000;   -- 单次上限 1 亿，防误输入
BEGIN
    -- 鉴权
    IF p_session IS NULL OR NOT public.verify_session(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    -- 维护模式
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
    IF p_amount > v_cap THEN
        RETURN jsonb_build_object('success', false,
            'message', format('单次增资不能超过 %s NB币', v_cap));
    END IF;

    -- 交易时段（和买卖保持一致）
    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false,
            'message', '当前为休市时间（每日 8:00-20:00），请开盘后再操作');
    END IF;

    -- 锁住公司
    SELECT founder_id, company_name, pool_cash::numeric, pool_shares::numeric,
           total_shares::numeric
      INTO v_founder, v_name, v_pc, v_ps, v_ts
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

    -- 余额
    SELECT COALESCE(nb_balance, 0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal < p_amount THEN
        RETURN jsonb_build_object('success', false,
            'message', format('余额不足（需 %s，你有 %s）', p_amount, v_bal));
    END IF;

    v_p0 := v_pc / v_ps;

    -- ⭐ 钱进池子，股份不变
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


CREATE OR REPLACE FUNCTION public._orig_sell_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_cash   numeric;
    v_shares numeric;
    v_k      numeric;
    v_news   numeric;
    v_newc   numeric;
    v_got    numeric;
    v_fee    numeric;
    v_net    numeric;
    v_mine   numeric;
    v_cost   numeric;
    v_name   text;
    v_p0     numeric;
    v_p1     numeric;
    v_sell   numeric;
    v_founder uuid;
    v_inject_at timestamptz;
    v_lock_days integer;
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '卖出份额必须大于0');
    END IF;

    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false,
            'message', '当前为休市时间（每日 8:00-20:00 交易），请开盘后再操作');
    END IF;

    SELECT pool_cash::numeric, pool_shares::numeric, company_name,
           founder_id, last_injection_at
      INTO v_cash, v_shares, v_name, v_founder, v_inject_at
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_cash IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;

    -- ⭐ 增资锁定：创始人增资后 7 天内不能卖这家公司的股份
    IF v_founder = p_user_id AND v_inject_at IS NOT NULL THEN
        v_lock_days := 7;
        IF v_inject_at > now() - make_interval(days => v_lock_days) THEN
            RETURN jsonb_build_object('success', false,
                'message', format('你在 %s 给本公司增过资，%s 天内不能卖出该公司股份（还剩 %s 天）。',
                       to_char(v_inject_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'),
                       v_lock_days,
                       CEIL(EXTRACT(EPOCH FROM (v_inject_at + make_interval(days => v_lock_days) - now())) / 86400)::int));
        END IF;
    END IF;

    SELECT COALESCE(shares,0), COALESCE(cost,0) INTO v_mine, v_cost
      FROM public.holdings WHERE user_id = p_user_id AND company_id = p_company_id;
    IF v_mine IS NULL OR v_mine <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '你还没有持有这家公司');
    END IF;

    v_sell := LEAST(p_amount, v_mine);
    IF v_sell <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '卖出份额太小');
    END IF;

    v_p0 := v_cash / v_shares;
    v_k  := v_cash * v_shares;
    v_news := v_shares + v_sell;
    v_newc := v_k / v_news;
    v_got  := v_cash - v_newc;

    IF v_got <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '池子里没有足够的现金');
    END IF;

    v_fee := floor(v_got * CASE WHEN p_use_discount THEN 0.02 ELSE 0.05 END);
    v_net := v_got - v_fee;

    UPDATE public.profiles SET nb_balance = COALESCE(nb_balance,0) + v_net WHERE id = p_user_id;

    UPDATE public.user_companies
       SET pool_cash = v_newc, pool_shares = v_news
     WHERE id = p_company_id;

    IF v_sell >= v_mine - 0.0001 THEN
        DELETE FROM public.holdings WHERE user_id = p_user_id AND company_id = p_company_id;
    ELSE
        UPDATE public.holdings
           SET shares = shares - v_sell,
               cost   = GREATEST(cost * (1 - v_sell / v_mine), 0),
               updated_at = now()
         WHERE user_id = p_user_id AND company_id = p_company_id;
    END IF;

    v_p1 := v_newc / v_news;

    INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, fee, price_after)
    VALUES (p_user_id, p_company_id, 'sell', v_net, v_sell, v_fee, round(v_p1,4));

    RETURN jsonb_build_object(
        'success', true, 'ok', true,
        'message', format('卖出「%s」成功：卖掉 %s 张，得到 %s NB币（手续费 %s），成交均价 %s',
                          v_name, round(v_sell,4), v_net, v_fee, round(v_got / v_sell, 4)),
        'shares', round(v_sell,4),
        'cash', v_net,
        'avg_price', round(v_got / v_sell, 4),
        'price_before', round(v_p0,4),
        'price_after', round(v_p1,4),
        'fee', v_fee);
END
$fn$;

-- ============================================================
-- 验收
-- ============================================================
-- 1. 两个函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('inject_company_capital', '_orig_sell_stock')
 ORDER BY 1;

-- 2. 确认没有奇数参数的 jsonb_build_object 了（这个查不出来，
--    但可以直接试调一次）
-- SELECT public.inject_company_capital(
--     '你的-uuid'::uuid, '你的-session', 公司id, 1000);


-- ============================================================
-- 回滚
-- ============================================================
-- SELECT 定义 FROM public._func_backup_inject_20261003;
