-- ============================================================
-- 每日每公司买入/增资上限
-- ============================================================
--
-- 【为什么需要】
-- Utw 手握 9 亿亿，能炸任意一家公司。
-- 单笔上限（cap_single_trade_20261004.sql）只能限制单次 —— 他可以连砸 100 笔。
--
-- 按【账号】做限制也没用：他有 100 多个号，任何"每账号 X"都能被乘法绕过。
--
-- 【关键设计：限制挂在公司上，不挂在账号上】
--   每家公司每天：
--       买入上限 = min(当日开盘池子现金 × 50%, 5000 万)
--       增资上限 = min(当日开盘池子现金 × 100%, 5000 万)
--
--   他全部小号加起来也只有这一个额度。
--
-- 【为什么用"当日开盘池子现金"做基准，而不是当前池子】
--   用当前池子会滚雪球：
--       他先买 50% → 池子变大 1.5 倍 → 额度跟着变 1.5 倍 → 再买 50%…
--   用当日开盘值，额度在一天之内是固定的，滚不起来。
--
-- 【效果】
--   池子 1.49 亿的公司：每天最多被买入 5000 万 → 价格最多涨到 (1+5000/14900)² ≈ 1.79 倍
--   池子 2 万的小公司：  每天最多被买入 1 万    → 价格最多涨到 4 倍
--
--   想炸到 12 万倍？按上面这个速度得炸很久，而且每天都能被你看见。
--
-- 【对正常玩家的影响】
--   几乎没有。一家正常公司一天被买入池子现金的 50% 已经算很热闹了。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：备份
-- ============================================================
CREATE TABLE IF NOT EXISTS public._func_backup_dailycap_20261004 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock', 'inject_company_capital');

SELECT 函数名, length(定义) AS 长度 FROM public._func_backup_dailycap_20261004;


-- ============================================================
-- 第二步：算当日流水的工具函数
-- ------------------------------------------------------------
-- 返回：今天买进来多少 / 增资进来多少 / 卖出去多少 / 当日开盘的池子现金
--
-- 口径说明：
--   stock_trades.cash 是【实付含手续费】
--     买入：池子收到的是 cash - fee
--     卖出：池子付出的是 cash + fee（cash 是到账净额）
--     增资：池子收到的是 cash（无手续费）
-- ============================================================
CREATE OR REPLACE FUNCTION public._company_daily_flow(p_company_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_bought   numeric := 0;
    v_injected numeric := 0;
    v_sold     numeric := 0;
    v_cash     numeric := 0;
    v_day_start timestamptz;
BEGIN
    -- 北京时间当天 0 点
    v_day_start := date_trunc('day', now() AT TIME ZONE 'Asia/Shanghai')
                   AT TIME ZONE 'Asia/Shanghai';

    SELECT
        COALESCE(sum(CASE WHEN side = 'buy'    THEN cash - COALESCE(fee,0) ELSE 0 END), 0),
        COALESCE(sum(CASE WHEN side = 'inject' THEN cash ELSE 0 END), 0),
        COALESCE(sum(CASE WHEN side = 'sell'   THEN cash + COALESCE(fee,0) ELSE 0 END), 0)
      INTO v_bought, v_injected, v_sold
      FROM public.stock_trades
     WHERE company_id = p_company_id
       AND created_at >= v_day_start;

    SELECT COALESCE(pool_cash, 0)::numeric INTO v_cash
      FROM public.user_companies WHERE id = p_company_id;

    RETURN jsonb_build_object(
        'bought',   v_bought,      -- 今天买进来多少
        'injected', v_injected,    -- 今天增资进来多少
        'sold',     v_sold,        -- 今天卖出去多少
        'now_cash', v_cash,
        -- 当日开盘 = 现在 − 今天进来的 + 今天出去的
        'day_open', GREATEST(v_cash - v_bought - v_injected + v_sold, 0),
        'day_start', v_day_start);
END
$fn$;

GRANT EXECUTE ON FUNCTION public._company_daily_flow(bigint) TO anon, authenticated;


-- ============================================================
-- 第三步：买入加每日上限
-- ------------------------------------------------------------
-- 在现有版本（单笔上限 + 持股0可买）基础上，再加一段每日额度判断。
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
    v_cap     numeric;
    v_flow    jsonb;
    v_open    numeric;
    v_today   numeric;
    v_daily   numeric;
    -- ⭐ 可调参数
    v_buy_pct    CONSTANT numeric := 0.5;        -- 每日买入上限 = 当日开盘池子 × 50%
    v_abs_cap    CONSTANT numeric := 50000000;   -- 绝对上限 5000 万
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

    -- ① 单笔上限：不能超过池子现金的 50%
    v_cap := floor(v_cash * 0.5);
    IF p_amount > v_cap THEN
        RETURN jsonb_build_object('success', false,
            format('单笔买入不能超过池子现金的一半（当前池子 %s NB币，单笔最多买 %s）。想买更多请分几笔。',
                   round(v_cash, 0), v_cap));
    END IF;

    -- ② ⭐ 每日上限：这家公司今天一共能被买入多少
    v_flow  := public._company_daily_flow(p_company_id);
    v_open  := COALESCE((v_flow->>'day_open')::numeric, v_cash);
    v_today := COALESCE((v_flow->>'bought')::numeric, 0);
    v_daily := LEAST(v_open * v_buy_pct, v_abs_cap);
    IF v_daily < 1000 THEN v_daily := 1000; END IF;   -- 保底：小公司至少能买 1000

    IF v_today + p_amount > v_daily THEN
        RETURN jsonb_build_object('success', false,
            format('「%s」今天已经被买入 %s NB币，达到每日上限（%s）。今天还能买 %s，剩下的明天再来。',
                   v_name, round(v_today, 0), round(v_daily, 0),
                   GREATEST(round(v_daily - v_today, 0), 0)));
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
-- 第四步：增资加每日上限
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
    v_cap     numeric;
    v_flow    jsonb;
    v_open    numeric;
    v_today   numeric;
    v_daily   numeric;
    v_inj_pct CONSTANT numeric := 1.0;
    v_abs_cap CONSTANT numeric := 50000000;
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

    -- ① 单笔上限：不能超过池子现金的 2 倍
    v_cap := floor(v_pc * 2);
    IF p_amount > v_cap THEN
        RETURN jsonb_build_object('success', false,
            format('单笔增资不能超过池子现金的 2 倍（当前池子 %s NB币，单笔最多 %s）。想加更多请分几次。',
                   round(v_pc, 0), v_cap));
    END IF;

    -- ② ⭐ 每日上限
    v_flow  := public._company_daily_flow(p_company_id);
    v_open  := COALESCE((v_flow->>'day_open')::numeric, v_pc);
    v_today := COALESCE((v_flow->>'injected')::numeric, 0);
    v_daily := LEAST(v_open * v_inj_pct, v_abs_cap);
    IF v_daily < 1000 THEN v_daily := 1000; END IF;

    IF v_today + p_amount > v_daily THEN
        RETURN jsonb_build_object('success', false,
            format('「%s」今天已经被增资 %s NB币，达到每日上限（%s）。今天还能加 %s，剩下的明天再来。',
                   v_name, round(v_today, 0), round(v_daily, 0),
                   GREATEST(round(v_daily - v_today, 0), 0)));
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
-- 第五步：验收
-- ============================================================
-- 5.1 三个函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('_orig_buy_stock','inject_company_capital','_company_daily_flow')
 ORDER BY 1;

-- 5.2 确认两个限制都写进去了
SELECT p.proname AS 函数,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%单笔买入不能超过池子现金的一半%'
              AND pg_get_functiondef(p.oid) LIKE '%达到每日上限%'
            THEN '✅ 单笔 + 每日 都有限制'
            WHEN pg_get_functiondef(p.oid) LIKE '%单笔增资不能超过池子现金的 2 倍%'
              AND pg_get_functiondef(p.oid) LIKE '%达到每日上限%'
            THEN '✅ 单笔 + 每日 都有限制'
            ELSE '❓ 认不出' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('_orig_buy_stock','inject_company_capital')
 ORDER BY 1;

-- 5.3 看「Utw」今天的流水和额度（现在应该已严重超额）
SELECT c.company_name,
       f->>'day_open' AS 当日开盘池子,
       f->>'bought'   AS 今日买入,
       f->>'injected' AS 今日增资,
       LEAST((f->>'day_open')::numeric * 0.5, 50000000) AS 买入每日上限,
       LEAST((f->>'day_open')::numeric * 1.0, 50000000) AS 增资每日上限
  FROM public.user_companies c,
       LATERAL public._company_daily_flow(c.id) f
 WHERE c.company_name IN ('Utw','NB频道');


-- ============================================================
-- 想让限制更松或更紧，改这两个常量
-- ------------------------------------------------------------
-- 在 _orig_buy_stock 里：
--     v_buy_pct    := 0.5      每日买入上限 = 当日开盘池子 × 50%
--     v_abs_cap    := 50000000 绝对上限 5000 万
-- 在 inject_company_capital 里：
--     v_inj_pct    := 1.0      每日增资上限 = 当日开盘池子 × 100%
--     v_abs_cap    := 50000000
-- ============================================================


-- ============================================================
-- 回滚
-- ============================================================
-- SELECT 定义 FROM public._func_backup_dailycap_20261004;
-- DROP FUNCTION IF EXISTS public._company_daily_flow(bigint);
