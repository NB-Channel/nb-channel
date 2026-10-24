-- ============================================================
-- 新增：分红预览接口
-- ============================================================
--
-- 【问题】
-- 分红弹窗显示「你能拿回约 X NB币（按你 0.00% 的持股比例）」，
-- 但实际数据库里该拿 100%。前端算错了。
--
-- 前端那段代码：
--     const totalShares = row ? row.total_shares : (myCompany.total_shares || 0);
--     const myShares    = row ? row.my_shares : 0;
--     const myPct       = myShares / totalShares * 100;
--
-- 两个错误：
--   ① 除数是 total_shares，但分红的分母是【玩家持股之和】——
--      池子自己那份股份是流通盘，不参与分红。
--      total_shares = 池子股份 + 玩家持股，拿它当分母，比例会算小。
--   ② row 取不到时 myShares 直接是 0 —— 这就是站长看到 0.00% 的原因。
--
-- 【修法】
-- 加一个 preview_dividend，把计算挪到数据库里，
-- 跟 preview_buy / preview_sell 一个套路。
-- 前端只管显示，不再自己算。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 分红预览
-- ------------------------------------------------------------
-- 参数：公司 id、用户 id（可空，空了就不算"你能拿多少"）、分红金额
-- ============================================================
CREATE OR REPLACE FUNCTION public.preview_dividend(
    p_company_id bigint,
    p_user_id    uuid,
    p_amount     numeric)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_pool     numeric;
    v_total    numeric;   -- 玩家持股之和（分红的分母）
    v_mine     numeric;
    v_pct      numeric;
    v_cut      numeric;
    v_cnt      int;
BEGIN
    SELECT pool_cash::numeric INTO v_pool
      FROM public.user_companies WHERE id = p_company_id;
    IF v_pool IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '公司不存在');
    END IF;

    -- ⭐ 分母是【玩家持股之和】，不含池子自己的股份
    SELECT COALESCE(sum(shares), 0) INTO v_total
      FROM public.holdings WHERE company_id = p_company_id;

    SELECT COALESCE(shares, 0) INTO v_mine
      FROM public.holdings
     WHERE company_id = p_company_id AND user_id = p_user_id;
    v_mine := COALESCE(v_mine, 0);

    v_pct := CASE WHEN v_total > 0 THEN round(v_mine / v_total * 100, 2) ELSE 0 END;
    v_cut := CASE WHEN v_total > 0 THEN round(COALESCE(p_amount,0) * v_mine / v_total, 2) ELSE 0 END;

    SELECT count(*) INTO v_cnt
      FROM public.holdings WHERE company_id = p_company_id AND shares > 0;

    RETURN jsonb_build_object(
        'ok', true,
        'pool_cash',     round(v_pool, 2),
        'max_amount',    floor(v_pool),            -- 最多能分多少
        'holder_shares', round(v_total, 4),        -- 分红的分母
        'my_shares',     round(v_mine, 4),
        'my_pct',        v_pct,
        'my_cut',        v_cut,
        'per_share',     CASE WHEN v_total > 0 THEN round(COALESCE(p_amount,0) / v_total, 6) ELSE 0 END,
        'holder_count',  v_cnt,
        'others_cut',    CASE WHEN v_total > 0 THEN round(COALESCE(p_amount,0) * (v_total - v_mine) / v_total, 2) ELSE 0 END);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.preview_dividend(bigint, uuid, numeric)
    TO anon, authenticated;


-- ============================================================
-- 顺便给 get_market_list 补一个字段
-- ------------------------------------------------------------
-- 前端算比例时还需要「玩家持股之和」当分母。
-- 与其再调一次接口，不如直接加进行情列表里。
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
    market_cap     numeric,
    verified       boolean,
    my_shares      numeric,
    my_value       numeric,
    holder_shares  numeric     -- ⭐ 新增：玩家持股之和（分红的分母）
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
        round(COALESCE(h.shares,0)::numeric * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)), 4),
        COALESCE((SELECT sum(hh.shares) FROM public.holdings hh
                   WHERE hh.company_id = c.id), 0)::numeric
      FROM public.user_companies c
      LEFT JOIN public.profiles p ON p.id = c.founder_id
      LEFT JOIN public.holdings h
             ON h.company_id = c.id AND h.user_id = p_user_id
     WHERE c.pool_shares > 0
     ORDER BY c.pool_cash::numeric DESC;
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_market_list(uuid) TO anon, authenticated;


-- ============================================================
-- 验收
-- ============================================================
-- 1. 两个函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('preview_dividend','get_market_list')
 ORDER BY 1;

-- 2. 试算：拿站长的公司试（把 uuid 换成你自己的，金额随便填）
-- SELECT public.preview_dividend(
--     (SELECT id FROM public.user_companies WHERE company_name ILIKE '%NB频道%' LIMIT 1),
--     '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid,
--     1000000);

-- 3. 直接看你公司的实际情况（不用调函数）
SELECT c.id, c.company_name,
       c.pool_cash,
       c.pool_shares,
       c.total_shares,
       (SELECT COALESCE(sum(h.shares),0) FROM public.holdings h WHERE h.company_id = c.id)
           AS 玩家持股之和,
       (SELECT COALESCE(sum(h.shares),0) FROM public.holdings h
         WHERE h.company_id = c.id AND h.user_id = c.founder_id)
           AS 创始人持股,
       (SELECT count(*) FROM public.holdings h WHERE h.company_id = c.id AND h.shares > 0)
           AS 股东人数
  FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.founder_id
 WHERE p.id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;
-- 「创始人持股」应该 > 0，而且如果只有你一个股东，它应该等于「玩家持股之和」
