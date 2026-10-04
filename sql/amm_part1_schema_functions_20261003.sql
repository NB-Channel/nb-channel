-- ============================================================
-- 股票系统重构 · 第一部分：表结构 + 核心函数（AMM 做市池模型）
-- ============================================================
--
-- 【模型】
--   每家公司有一个池子，装现金和股份。池子自己当对手盘，
--   玩家永远是跟池子成交，不需要等别人挂单。
--
--   恒定乘积：池子现金 × 池子股份 = k
--       买入 x 币  →  现金池变 现金+x，股份池由 k 推出，差额就是买到的股份
--       卖出 s 张  →  股份池变 股份+s，现金池由 k 推出，差额就是拿到的钱
--
-- 【为什么这样就不造币了】
--   钱只在【玩家】和【池子】之间移动，系统不凭空产生也不销毁。
--   池子里钱不够，你股份再多也卖不出钱 —— 能套现的上限就是池子现金。
--
-- 【注册时的初始分配（关键推导）】
--   用户出 C 建公司：
--       池子现金 = C
--       池子股份 = C 张        →  价格 = C / C = 1.00
--       总股本   = 2C 张
--       创始人得 = C 张        →  价值 C × 1.00 = C，正好等于他出的钱
--       池子留   = C 张        →  供别人买
--   验证：如果注册完立刻清算，池子的 C 现金全归创始人（唯一持股人），
--         他出 C、拿回 C，净零 —— 没有造币口 ✅
--
-- 【执行顺序】
--   1. 本脚本（建结构 + 换函数）
--   2. migrate_to_amm_20261003.sql（把现有 93 家公司搬过来）
--   3. 前端改版
--   4. 关掉维护模式
--
-- ⚠️ 本脚本【不动任何现有数据】，只加字段、换函数。
--    跑完之后旧字段（market_value / principal / base_market_value）还在，
--    等迁移完成、页面改好、验证无误之后再删。
-- ============================================================


-- ============================================================
-- 一、表结构
-- ============================================================

-- 1.1 公司表：加池子相关字段
ALTER TABLE public.user_companies
    ADD COLUMN IF NOT EXISTS pool_cash    numeric NOT NULL DEFAULT 0,   -- 池子里的现金
    ADD COLUMN IF NOT EXISTS pool_shares  numeric NOT NULL DEFAULT 0,   -- 池子里的股份
    ADD COLUMN IF NOT EXISTS total_shares numeric NOT NULL DEFAULT 0,   -- 总股本
    ADD COLUMN IF NOT EXISTS founder_id   uuid;                          -- 创始人（用于发分红/破产的权限）

-- 把现有公司的 founder_id 补上
UPDATE public.user_companies SET founder_id = user_id WHERE founder_id IS NULL;

COMMENT ON COLUMN public.user_companies.pool_cash    IS 'AMM 池子现金（公司的全部家底）';
COMMENT ON COLUMN public.user_companies.pool_shares  IS 'AMM 池子股份（可供买卖的流通盘）';
COMMENT ON COLUMN public.user_companies.total_shares IS '总股本 = 池子股份 + 所有玩家持股';
COMMENT ON COLUMN public.user_companies.founder_id   IS '创始人，有权发起分红';

-- 1.2 持仓表：把「本金」换成「股份张数」
ALTER TABLE public.holdings
    ADD COLUMN IF NOT EXISTS shares numeric NOT NULL DEFAULT 0;       -- 持有多少张
ALTER TABLE public.holdings
    ADD COLUMN IF NOT EXISTS cost   numeric NOT NULL DEFAULT 0;       -- 累计投入成本（算均价用）

-- 1.3 交易流水（新表，便于对账和以后排查）
CREATE TABLE IF NOT EXISTS public.stock_trades (
    id          bigserial PRIMARY KEY,
    user_id     uuid NOT NULL,
    company_id  bigint NOT NULL,
    side        text NOT NULL CHECK (side IN ('buy','sell','dividend','liquidate')),
    cash        numeric NOT NULL DEFAULT 0,     -- 花了/拿到多少钱
    shares      numeric NOT NULL DEFAULT 0,     -- 拿到/卖掉多少张
    fee         numeric NOT NULL DEFAULT 0,     -- 手续费
    price_after numeric NOT NULL DEFAULT 0,     -- 成交后单价
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stock_trades_co ON public.stock_trades (company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_trades_us ON public.stock_trades (user_id, created_at DESC);

-- 1.4 分红记录
CREATE TABLE IF NOT EXISTS public.stock_dividends (
    id          bigserial PRIMARY KEY,
    company_id  bigint NOT NULL,
    total_paid  numeric NOT NULL,
    per_share   numeric NOT NULL,
    created_by  uuid,
    created_at  timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- 二、工具函数
-- ============================================================

-- 2.1 当前股价
CREATE OR REPLACE FUNCTION public.stock_price(p_company_id bigint)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
    SELECT CASE WHEN pool_shares > 0 THEN round(pool_cash / pool_shares, 4) ELSE 0 END
      FROM public.user_companies WHERE id = p_company_id;
$fn$;

GRANT EXECUTE ON FUNCTION public.stock_price(bigint) TO anon, authenticated;

-- 2.2 一个玩家在某公司的持股占「玩家总持股」的比例
--     ⚠️ 注意：分母是【所有玩家持股之和】，不含池子自己的股份。
--        池子的股份是流通盘，不参与分红和清算。
CREATE OR REPLACE FUNCTION public._holder_ratio(p_company_id bigint, p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_mine  numeric;
    v_total numeric;
BEGIN
    SELECT COALESCE(shares,0) INTO v_mine FROM public.holdings
     WHERE company_id = p_company_id AND user_id = p_user_id;
    SELECT COALESCE(sum(shares),0) INTO v_total FROM public.holdings
     WHERE company_id = p_company_id;
    IF v_total IS NULL OR v_total <= 0 THEN RETURN 0; END IF;
    RETURN COALESCE(v_mine,0) / v_total;
END
$fn$;


-- ============================================================
-- 三、注册公司：必须自己出钱建池子
-- ============================================================
-- 参数说明：
--   p_fund = 出多少钱建池子（>= 20000）
--
-- 分配：
--   池子现金 = p_fund
--   池子股份 = p_fund 张         价格 1.00
--   总股本   = 2 * p_fund 张
--   创始人得 = p_fund 张
CREATE OR REPLACE FUNCTION public._orig_register_company(
    p_user_id uuid, p_company_name text, p_need_verify boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_clean TEXT;
    v_word  TEXT;
    v_fund  numeric := 20000;      -- 默认出资额，前端可以传更大的
    v_bal   numeric;
    v_cid   bigint;
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法注册公司');
    END IF;

    -- 名称清洗（沿用原逻辑）
    v_clean := regexp_replace(
        coalesce(p_company_name, ''),
        '[' || chr(8203)||chr(8204)||chr(8205)||chr(8206)||chr(8207)
             || chr(65279)||chr(173)||chr(8288)||chr(12288)
             || chr(9)||chr(10)||chr(13)||chr(32) || ']', '', 'g');
    v_clean := btrim(v_clean);

    IF v_clean = '' THEN
        RETURN jsonb_build_object('success', false, 'message', '请填写公司名称');
    END IF;
    IF v_clean !~ ('^[' || chr(19968) || '-' || chr(40869) || 'a-zA-Z0-9]+$') THEN
        RETURN jsonb_build_object('success', false, 'message', '公司名称只能包含中文、字母和数字');
    END IF;
    IF length(v_clean) < 1 OR length(v_clean) > 20 THEN
        RETURN jsonb_build_object('success', false, 'message', '公司名称需在 1~20 字之间');
    END IF;

    FOR v_word IN SELECT word FROM public.bad_words LOOP
        IF position(lower(v_word) in lower(v_clean)) > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', '公司名称包含违禁词，请更换名称');
        END IF;
    END LOOP;

    IF EXISTS (SELECT 1 FROM public.user_companies
                WHERE lower(btrim(company_name)) = lower(v_clean)) THEN
        RETURN jsonb_build_object('success', false,
            'message', '公司名「' || v_clean || '」已被占用，请换一个名字');
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_companies WHERE user_id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'message', '您已经注册过公司');
    END IF;

    -- ⭐ 关键：注册要真出钱
    SELECT COALESCE(nb_balance, 0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal < v_fund THEN
        RETURN jsonb_build_object('success', false,
            format('注册公司需要出资 %s NB币建初始资金池，你的余额是 %s',
                   v_fund, COALESCE(v_bal, 0)));
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - v_fund WHERE id = p_user_id;

    INSERT INTO public.user_companies
        (user_id, founder_id, company_name, market_value,
         pool_cash, pool_shares, total_shares,
         verified, verification_status)
    VALUES
        (p_user_id, p_user_id, v_clean, v_fund * 2,
         v_fund, v_fund, v_fund * 2,
         false, CASE WHEN p_need_verify THEN 'pending' ELSE 'none' END)
    RETURNING id INTO v_cid;

    -- 创始人拿一半股份，另一半留在池子里
    INSERT INTO public.holdings (user_id, company_id, principal, base_market_value,
                                 shares, cost, updated_at)
    VALUES (p_user_id, v_cid, v_fund, v_fund, v_fund, v_fund, now())
    ON CONFLICT (user_id, company_id) DO UPDATE
        SET shares = EXCLUDED.shares, cost = EXCLUDED.cost, updated_at = now();

    INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, price_after)
    VALUES (p_user_id, v_cid, 'buy', v_fund, v_fund, 1.0);

    RETURN jsonb_build_object(
        'success', true,
        'message', format('公司「%s」注册成功！你出资 %s NB币建了初始资金池，获得 %s 张股份（占总股本一半），股价 1.00',
                          v_clean, v_fund, v_fund),
        'company_id', v_cid,
        'shares', v_fund,
        'price', 1.0,
        'need_verify', p_need_verify);
END
$fn$;


-- ============================================================
-- 四、买入：往池子放钱，拿股份
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

    -- 锁住这家公司，避免并发把池子算歪
    SELECT pool_cash, pool_shares, company_name, user_id
      INTO v_cash, v_shares, v_name, v_owner
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_cash IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;
    IF v_owner = p_user_id THEN
        RETURN jsonb_build_object('success', false,
            'message', '不能买入自己公司的股份（你是创始人，已持有创始股）');
    END IF;

    v_fee := floor(p_amount * CASE WHEN p_use_discount THEN 0.02 ELSE 0.05 END);
    v_total := p_amount + v_fee;

    SELECT COALESCE(nb_balance,0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal < v_total THEN
        RETURN jsonb_build_object('success', false,
            format('NB币余额不足（需 %s，含 %s 手续费，你有 %s）', v_total, v_fee, v_bal));
    END IF;

    -- ⭐ 恒定乘积
    v_p0 := v_cash / v_shares;
    v_k  := v_cash * v_shares;
    v_newc := v_cash + p_amount;
    v_news := v_k / v_newc;
    v_got  := v_shares - v_news;

    IF v_got <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '投入金额太小，买不到股份');
    END IF;

    -- 扣钱
    UPDATE public.profiles SET nb_balance = nb_balance - v_total WHERE id = p_user_id;

    -- 更新池子
    UPDATE public.user_companies
       SET pool_cash = v_newc, pool_shares = v_news
     WHERE id = p_company_id;

    -- 更新持仓
    INSERT INTO public.holdings (user_id, company_id, shares, cost, principal, base_market_value, updated_at)
    VALUES (p_user_id, p_company_id, v_got, p_amount, p_amount, v_cash, now())
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
-- 五、卖出：往池子放股份，拿钱
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
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '卖出金额必须大于0');
    END IF;

    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false,
            'message', '当前为休市时间（每日 8:00-20:00 交易），请开盘后再操作');
    END IF;

    SELECT pool_cash, pool_shares, company_name
      INTO v_cash, v_shares, v_name
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_cash IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;

    SELECT COALESCE(shares,0), COALESCE(cost,0) INTO v_mine, v_cost
      FROM public.holdings WHERE user_id = p_user_id AND company_id = p_company_id;
    IF v_mine IS NULL OR v_mine <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '你还没有持有这家公司');
    END IF;

    -- p_amount 在这里表示"想卖掉多少张股份"
    v_sell := LEAST(p_amount, v_mine);
    IF v_sell <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '卖出份额太小');
    END IF;

    -- ⭐ 恒定乘积（反方向）
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

    -- 加钱
    UPDATE public.profiles SET nb_balance = COALESCE(nb_balance,0) + v_net WHERE id = p_user_id;

    -- 更新池子
    UPDATE public.user_companies
       SET pool_cash = v_newc, pool_shares = v_news
     WHERE id = p_company_id;

    -- 更新持仓（按比例扣成本）
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
-- 六、分红：从池子拿钱按持股比例分
-- ============================================================
CREATE OR REPLACE FUNCTION public.pay_dividend(
    p_user_id uuid, p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_founder uuid;
    v_cash    numeric;
    v_total   numeric;
    v_pershar numeric;
    r         RECORD;
    v_paid    numeric := 0;
    v_cnt     int := 0;
    v_name    text;
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '分红金额必须大于0');
    END IF;

    SELECT founder_id, pool_cash, company_name
      INTO v_founder, v_cash, v_name
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_founder IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;
    IF v_founder <> p_user_id THEN
        RETURN jsonb_build_object('success', false, 'message', '只有创始人可以发起分红');
    END IF;
    IF v_cash < p_amount THEN
        RETURN jsonb_build_object('success', false,
            format('资金池里只有 %s NB币，不够分 %s', v_cash, p_amount));
    END IF;

    SELECT COALESCE(sum(shares),0) INTO v_total FROM public.holdings
     WHERE company_id = p_company_id;
    IF v_total <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '没有股东持股，无法分红');
    END IF;

    v_pershar := p_amount / v_total;

    -- 从池子里扣钱（池子钱少了，股价自动跌，等于除息）
    UPDATE public.user_companies
       SET pool_cash = pool_cash - p_amount
     WHERE id = p_company_id;

    -- 按持股比例分
    FOR r IN SELECT user_id, shares FROM public.holdings
              WHERE company_id = p_company_id AND shares > 0 LOOP
        DECLARE v_his numeric;
        BEGIN
            v_his := round(r.shares * v_pershar, 4);
            IF v_his > 0 THEN
                UPDATE public.profiles SET nb_balance = COALESCE(nb_balance,0) + v_his
                 WHERE id = r.user_id;
                INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, price_after)
                VALUES (r.user_id, p_company_id, 'dividend', v_his, 0, 0);
                v_paid := v_paid + v_his;
                v_cnt := v_cnt + 1;
            END IF;
        END;
    END LOOP;

    INSERT INTO public.stock_dividends (company_id, total_paid, per_share, created_by)
    VALUES (p_company_id, v_paid, round(v_pershar,6), p_user_id);

    RETURN jsonb_build_object(
        'success', true,
        'message', format('「%s」分红完成：共分 %s NB币给 %s 位股东，每股 %s',
                          v_name, round(v_paid,2), v_cnt, round(v_pershar,6)),
        'total', v_paid, 'holders', v_cnt, 'per_share', round(v_pershar,6));
END
$fn$;

GRANT EXECUTE ON FUNCTION public.pay_dividend(uuid, bigint, numeric) TO anon, authenticated;


-- ============================================================
-- 七、清算（原「破产」）：池子现金按持股比例分给股东
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_bankrupt_company(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_cid     bigint;
    v_name    text;
    v_cash    numeric;
    v_total   numeric;
    v_founder uuid;
    r         RECORD;
    v_his     numeric;
    v_paid    numeric := 0;
    v_cnt     int := 0;
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;

    SELECT id, company_name, pool_cash, founder_id
      INTO v_cid, v_name, v_cash, v_founder
      FROM public.user_companies WHERE user_id = p_user_id FOR UPDATE;
    IF v_cid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '你还没有虚拟公司');
    END IF;

    SELECT COALESCE(sum(shares),0) INTO v_total FROM public.holdings
     WHERE company_id = v_cid;

    -- ⭐ 池子里的现金【按持股比例】分给所有股东
    IF v_total > 0 AND v_cash > 0 THEN
        FOR r IN SELECT user_id, shares FROM public.holdings
                  WHERE company_id = v_cid AND shares > 0 LOOP
            v_his := round(v_cash * (r.shares / v_total), 4);
            IF v_his > 0 THEN
                UPDATE public.profiles SET nb_balance = COALESCE(nb_balance,0) + v_his
                 WHERE id = r.user_id;
                INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, price_after)
                VALUES (r.user_id, v_cid, 'liquidate', v_his, 0, 0);
                v_paid := v_paid + v_his;
                v_cnt := v_cnt + 1;
            END IF;
        END LOOP;
    END IF;

    DELETE FROM public.holdings WHERE company_id = v_cid;
    DELETE FROM public.user_companies WHERE id = v_cid;
    DELETE FROM public.verified_users WHERE user_id = p_user_id;
    DELETE FROM public.support_rules WHERE company_id = v_cid;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('「%s」已清算：资金池剩余 %s NB币，按持股比例分给了 %s 位股东（你分到 %s）',
                          v_name, round(v_cash,2), v_cnt,
                          round(COALESCE((SELECT v_cash * (h.shares / NULLIF(v_total,0))
                                            FROM public.holdings h
                                           WHERE h.company_id = v_cid AND h.user_id = p_user_id), 0), 2)),
        'pool_cash', v_cash,
        'distributed', v_paid,
        'holders', v_cnt);
END
$fn$;


-- ============================================================
-- 八、注资：AMM 模型下【没有这个操作了】
-- ------------------------------------------------------------
-- 原来「注资」是给所有股东送钱（造币根源）。
-- AMM 模型下，公司融资只能靠【发新股】—— 但那样太复杂，
-- 而且你这个场景里没有真实的"项目用钱"需求。
--
-- 所以直接停用。保留函数只是为了不让前端报错。
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_support_company(
    p_user_id uuid, p_company_id bigint, p_amount integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN jsonb_build_object('success', false, 'ok', false,
        'message', '新版交易模型已取消「注资」功能。想增加持股请直接买入，公司资金池会随之增厚。');
END
$fn$;


-- ============================================================
-- 九、提取公司价值：也停用（创始人要拿钱请走「分红」）
-- ============================================================
CREATE OR REPLACE FUNCTION public.withdraw_company_value(
    p_user_id uuid, p_session text, p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN jsonb_build_object('ok', false,
        'message', '新版交易模型已取消「提取公司价值」。创始人想从公司拿钱请用「分红」，那样全体股东一起分。');
END
$fn$;


-- ============================================================
-- 十、验收
-- ============================================================
-- 10.1 六个入口的函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_register_company','_orig_buy_stock','_orig_sell_stock',
                     '_orig_bankrupt_company','_orig_support_company',
                     'withdraw_company_value','pay_dividend','stock_price')
 ORDER BY 1;

-- 10.2 新字段都在
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name='user_companies'
   AND column_name IN ('pool_cash','pool_shares','total_shares','founder_id')
 ORDER BY column_name;

-- 10.3 注意：现在只是【函数换好了】，老公司的池子还是 0。
--      下一步必须跑 migrate_to_amm_20261003.sql 把数据搬过来，
--      在那之前买卖会失败（池子股份为 0 会导致除以零）。
SELECT count(*) AS 池子还没初始化的公司
  FROM public.user_companies WHERE pool_shares <= 0;
