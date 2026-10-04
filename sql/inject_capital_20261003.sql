-- ============================================================
-- 新功能：创始人增资
-- ============================================================
--
-- 【为什么加】
-- AMM 模型下，公司市值只能靠【别人买入】推高。
-- 创始人自己：不能买自己公司（防操纵）、注资功能已取消、分红只会让股价跌。
-- 结果创始人对自己的公司完全使不上劲，只能干等。
--
-- 【增资是什么】
--   创始人往自己公司的资金池里打钱，但【不获得任何股份】。
--
--   池子现金变多、池子股份不变 → 股价上涨 → 全体股东一起受益。
--
--   钱进了池子就是公司的，不会凭空消失（池子是封闭的）。
--   创始人想拿回来只有两条路：分红（全体股东一起分）或清算（按持股比例分）。
--
-- 【和旧版「注资」的区别】
--   旧版注资会【增加 market_value】，而 market_value 是个虚数，
--   配合破产能套现 —— 那是造币。
--   新版增资是往真实的池子里放钱，池子是封闭的，不造币。
--
-- 【风险：先抬价再套现】
--   创始人可以投一笔钱拉高价格，吸引别人跟风买，然后卖掉自己的创始人股份。
--   算过一笔（公司池子 2 万，创始人持一半）：
--       增资 100 万 + 注册 2 万 = 投入 102 万
--       没人跟风 → 卖股份拿回 48.45 万      亏 53.5 万
--       有人跟风买 100 万 → 拿回 127.5 万    赚 25.5 万
--   所以这不是无风险套利，他得赌有人跟。
--
--   为了防"当天拉高当天砸盘"，加一条：
--       【增资后 7 天内，创始人不能卖自己公司的股份】
--   ⚠️ 这条防不了耐心的人（等 7 天再卖）。要彻底防住只能禁止增资，
--      但那又回到"创始人使不上劲"的老问题。属于产品取舍。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：加字段
-- ============================================================
ALTER TABLE public.user_companies
    ADD COLUMN IF NOT EXISTS last_injection_at timestamptz,      -- 上次增资时间
    ADD COLUMN IF NOT EXISTS total_injected    numeric NOT NULL DEFAULT 0;  -- 累计增资额

COMMENT ON COLUMN public.user_companies.last_injection_at IS '上次增资时间（用于 7 天锁定）';
COMMENT ON COLUMN public.user_companies.total_injected    IS '创始人累计增资额（不含注册出资）';


-- ============================================================
-- 第二步：增资函数
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
            format('单次增资不能超过 %s NB币', v_cap));
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
            format('余额不足（需 %s，你有 %s）', p_amount, v_bal));
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

GRANT EXECUTE ON FUNCTION public.inject_company_capital(uuid, text, bigint, numeric)
    TO anon, authenticated;


-- ============================================================
-- 第三步：卖出时检查 7 天锁定
-- ------------------------------------------------------------
-- 需要重写 _orig_sell_stock（AMM 版），在开头加一道检查。
-- 其余逻辑跟 amm_part1 里那版一字不差。
-- ============================================================
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
                format('你在 %s 给本公司增过资，%s 天内不能卖出该公司股份（还剩 %s 天）。',
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
-- 第四步：查我的增资记录（前端展示用）
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_injections(p_user_id uuid)
RETURNS TABLE(
    company_id   bigint,
    company_name text,
    cash         numeric,
    price_after  numeric,
    created_at   timestamptz,
    lock_until   timestamptz,
    locked       boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN QUERY
    SELECT t.company_id, c.company_name, t.cash, t.price_after, t.created_at,
           c.last_injection_at + interval '7 days',
           (c.last_injection_at IS NOT NULL
            AND c.last_injection_at > now() - interval '7 days')
      FROM public.stock_trades t
      JOIN public.user_companies c ON c.id = t.company_id
     WHERE t.user_id = p_user_id AND t.side = 'inject'
     ORDER BY t.created_at DESC LIMIT 50;
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_my_injections(uuid) TO anon, authenticated;


-- ============================================================
-- 第五步：验收
-- ============================================================
-- 5.1 字段加上了
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name='user_companies'
   AND column_name IN ('last_injection_at','total_injected');

-- 5.2 三个函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('inject_company_capital','_orig_sell_stock','get_my_injections')
 ORDER BY 1;

-- 5.3 试算：拿你自己的公司试一笔小额（把 uuid 换成你的）
-- SELECT public.inject_company_capital(
--     '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid,
--     '你的-session-token', 1, 1000);


-- ============================================================
-- 回滚
-- ============================================================
-- DROP FUNCTION IF EXISTS public.inject_company_capital(uuid,text,bigint,numeric);
-- ALTER TABLE public.user_companies DROP COLUMN IF EXISTS last_injection_at;
-- ALTER TABLE public.user_companies DROP COLUMN IF EXISTS total_injected;
-- _orig_sell_stock 从 amm_part1_schema_functions_20261003.sql 里取原版重跑


-- ============================================================
-- 待办：前端按钮
-- ------------------------------------------------------------
-- 两个股票页要加一个「💰 增资」按钮（仅创始人可见）：
--     点开 → 输入金额（最低 1000）→ 显示「股价会从 X 涨到 Y」
--     → 调 inject_company_capital
-- 并在锁定期间隐藏或禁用「卖出」按钮，提示还剩几天。
-- ============================================================
