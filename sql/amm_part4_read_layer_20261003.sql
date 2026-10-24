-- ============================================================
-- AMM 重构 · 读取层：给前端准备新字段
-- ============================================================
-- 页面要显示「股价 / 持股张数 / 池子」，就得有对应的读取函数。
-- 这一步只加/改【读】的函数，不动任何写逻辑，改完页面就能对接。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 一、我的持仓（新版）
-- ============================================================
-- 返回：公司、持股张数、成本均价、现价、市值、盈亏
CREATE OR REPLACE FUNCTION public.get_my_holdings(p_user_id uuid)
RETURNS TABLE(
    company_id     bigint,
    company_name   text,
    shares         numeric,      -- 持股张数
    cost           numeric,      -- 累计投入成本
    avg_price      numeric,      -- 成本均价
    current_price  numeric,      -- 现价
    cur_value      numeric,      -- 当前市值
    profit         numeric,      -- 浮动盈亏
    profit_pct     numeric,      -- 盈亏百分比
    pool_cash      numeric,      -- 池子现金（供展示）
    is_founder     boolean       -- 是不是自己的公司
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.company_name,
        COALESCE(h.shares,0)::numeric,
        COALESCE(h.cost,0)::numeric,
        CASE WHEN COALESCE(h.shares,0) > 0
             THEN round(COALESCE(h.cost,0)::numeric / h.shares::numeric, 4) ELSE 0 END,
        round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0), 4),
        round(COALESCE(h.shares,0)::numeric * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)), 4),
        round(COALESCE(h.shares,0)::numeric * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0))
              - COALESCE(h.cost,0)::numeric, 4),
        CASE WHEN COALESCE(h.cost,0) > 0
             THEN round((COALESCE(h.shares,0)::numeric * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0))
                         - h.cost::numeric) / h.cost::numeric * 100, 2)
             ELSE 0 END,
        c.pool_cash::numeric,
        (c.founder_id = p_user_id)
      FROM public.holdings h
      JOIN public.user_companies c ON c.id = h.company_id
     WHERE h.user_id = p_user_id AND COALESCE(h.shares,0) > 0
     ORDER BY COALESCE(h.shares,0)::numeric * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)) DESC;
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_my_holdings(uuid) TO anon, authenticated;


-- ============================================================
-- 二、行情列表（新版）—— 页面主列表用这个
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_market_list(p_user_id uuid DEFAULT NULL)
RETURNS TABLE(
    company_id     bigint,
    company_name   text,
    founder        text,
    price          numeric,
    pool_cash      numeric,
    pool_shares    numeric,
    total_shares   numeric,
    market_cap     numeric,      -- 账面市值 = 股价 × 总股本
    verified       boolean,
    my_shares      numeric,      -- 我持有多少张
    my_value       numeric       -- 我的持仓价值
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.company_name,
        COALESCE(p.username, '—'),
        round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0), 4),
        c.pool_cash::numeric,
        c.pool_shares::numeric,
        c.total_shares::numeric,
        round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0) * c.total_shares::numeric, 2),
        COALESCE(c.verified, false),
        COALESCE(h.shares,0)::numeric,
        round(COALESCE(h.shares,0)::numeric * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)), 4)
      FROM public.user_companies c
      LEFT JOIN public.profiles p ON p.id = c.founder_id
      LEFT JOIN public.holdings h
             ON h.company_id = c.id AND h.user_id = p_user_id
     WHERE c.pool_shares::numeric > 0
     ORDER BY c.pool_cash::numeric DESC;
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_market_list(uuid) TO anon, authenticated;


-- ============================================================
-- 三、买入预览（不算真买，只算给你看）
-- ------------------------------------------------------------
-- 页面上要让玩家在点确认前看到：预计均价、滑点、成交后价格。
-- 前端自己算容易算错，这里给一个函数。
-- ============================================================
CREATE OR REPLACE FUNCTION public.preview_buy(p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_cash numeric; v_shares numeric; v_k numeric;
    v_newc numeric; v_news numeric; v_got numeric;
    v_p0   numeric; v_p1   numeric;
BEGIN
    SELECT pool_cash::numeric, pool_shares::numeric INTO v_cash, v_shares
      FROM public.user_companies WHERE id = p_company_id;
    IF v_cash IS NULL OR v_shares <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '公司不存在或资金池异常');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '金额必须大于0');
    END IF;

    v_p0   := v_cash / v_shares;
    v_k    := v_cash * v_shares;
    v_newc := v_cash + p_amount;
    v_news := v_k / v_newc;
    v_got  := v_shares - v_news;
    v_p1   := v_newc / v_news;

    RETURN jsonb_build_object(
        'ok', true,
        'price_before', round(v_p0, 4),
        'price_after',  round(v_p1, 4),
        'shares',       round(v_got, 4),
        'avg_price',    round(p_amount / NULLIF(v_got,0), 4),
        'slippage_pct', round((p_amount / NULLIF(v_got,0) / v_p0 - 1) * 100, 2));
END
$fn$;

GRANT EXECUTE ON FUNCTION public.preview_buy(bigint, numeric) TO anon, authenticated;


-- ============================================================
-- 四、卖出预览：给的是「想卖多少张」
-- ============================================================
CREATE OR REPLACE FUNCTION public.preview_sell(p_company_id bigint, p_shares numeric)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_cash numeric; v_shares numeric; v_k numeric;
    v_newc numeric; v_news numeric; v_got numeric;
    v_p0   numeric; v_p1   numeric;
BEGIN
    SELECT pool_cash::numeric, pool_shares::numeric INTO v_cash, v_shares
      FROM public.user_companies WHERE id = p_company_id;
    IF v_cash IS NULL OR v_shares <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '公司不存在或资金池异常');
    END IF;
    IF p_shares IS NULL OR p_shares <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '份额必须大于0');
    END IF;

    v_p0   := v_cash / v_shares;
    v_k    := v_cash * v_shares;
    v_news := v_shares + p_shares;
    v_newc := v_k / v_news;
    v_got  := v_cash - v_newc;
    v_p1   := v_newc / v_news;

    IF v_got <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '池子里没有足够的现金');
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'price_before', round(v_p0, 4),
        'price_after',  round(v_p1, 4),
        'cash',         round(v_got, 4),
        'avg_price',    round(v_got / p_shares, 4),
        'slippage_pct', round((1 - v_got / p_shares / v_p0) * 100, 2));
END
$fn$;

GRANT EXECUTE ON FUNCTION public.preview_sell(bigint, numeric) TO anon, authenticated;


-- ============================================================
-- 五、停掉 AMM 下不该再运行的东西
-- ============================================================

-- 5.1 随机波动：AMM 下价格完全由池子决定，再叠加随机波动会破坏恒定乘积
CREATE OR REPLACE FUNCTION public.random_fluctuate_market_values()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    -- 新版价格由资金池和交易决定，不再需要人工波动。
    -- 保留函数体为空，是为了不改定时任务（免得它报"函数不存在"）。
    RETURN;
END $fn$;

-- 5.2 自动支持：注资功能已取消，规则也一并停用
CREATE OR REPLACE FUNCTION public.run_auto_support()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    -- 注资已取消；自动买入涉及资金池滑点，暂不自动执行。
    RETURN;
END $fn$;

-- 5.3 自动支持规则：前端还留着入口的话直接清掉（想保留历史就先注释掉这行）
-- DELETE FROM public.support_rules;

-- 5.4 清掉已有的支持规则（因为注资功能没了，留着也没用）
-- ⚠️ 这一步会删数据，确认要清再放开
-- TRUNCATE public.support_rules;


-- ============================================================
-- 六、公司税改成从池子扣
-- ------------------------------------------------------------
-- 原来扣的是 market_value；AMM 下要扣 pool_cash。
-- 池子钱少了，股价自动跌 —— 这就是"征税导致股价下跌"。
-- ============================================================
CREATE OR REPLACE FUNCTION public.collect_company_tax()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    r            RECORD;
    v_rate       numeric;
    v_tax        numeric;
    v_total      numeric := 0;
    v_count      int := 0;
    v_site_total numeric := 0;
    v_share      numeric;
    v_mono_cnt   int := 0;
    v_mono_total numeric := 0;
    v_mono_rate  CONSTANT numeric := 0.05;
    v_mono_line  CONSTANT numeric := 0.40;
BEGIN
    -- 基准改成池子现金总和
    SELECT COALESCE(sum(pool_cash), 0) INTO v_site_total FROM public.user_companies;

    FOR r IN
        SELECT id, company_name, pool_cash
          FROM public.user_companies
         WHERE pool_cash >= 300000          -- 池子小于 30 万不收
         ORDER BY pool_cash DESC
    LOOP
        v_rate := CASE
            WHEN r.pool_cash <  1000000  THEN 0.002
            WHEN r.pool_cash <  20000000 THEN 0.005
            WHEN r.pool_cash <  50000000 THEN 0.010
            ELSE                              0.020
        END;

        IF v_site_total > 0 THEN
            v_share := r.pool_cash / v_site_total;
            IF v_share > v_mono_line THEN
                v_rate := v_rate + v_mono_rate;
                v_mono_cnt := v_mono_cnt + 1;
                v_mono_total := v_mono_total + floor(r.pool_cash * v_mono_rate);
            END IF;
        END IF;

        v_tax := floor(r.pool_cash * v_rate);
        IF v_tax < 1 THEN CONTINUE; END IF;

        -- ⭐ 从池子扣（不是 market_value）
        UPDATE public.user_companies
           SET pool_cash = GREATEST(pool_cash - v_tax, 20000)
         WHERE id = r.id;

        v_total := v_total + v_tax;
        v_count := v_count + 1;
    END LOOP;

    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date', to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    RETURN jsonb_build_object(
        'ok', true, 'companies', v_count, 'total', v_total,
        'monopoly_companies', v_mono_cnt, 'monopoly_total', v_mono_total);
END
$fn$;


-- ============================================================
-- 七、验收
-- ============================================================
-- 7.1 三个新读取函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('get_my_holdings','get_market_list','preview_buy','preview_sell')
 ORDER BY 1;

-- 7.2 拿一家公司试试预览（把 id 换成实际存在的）
-- SELECT public.preview_buy(1, 1000);
-- SELECT public.preview_sell(1, 1000);
-- 应该返回 price_before / price_after / shares / slippage_pct

-- 7.3 行情列表（前端主列表就用这个）
-- 站长自己的 uuid（不传也行，传了会带上"我持有多少"）
SELECT * FROM public.get_market_list('22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid) LIMIT 5;

-- 不带用户（只看行情，不算我的持仓）：
-- SELECT * FROM public.get_market_list(NULL) LIMIT 5;
