-- ============================================================
-- 扶植中小公司 · 参数调整 + 中位数锚点接线（2026-09-30）
-- ============================================================
-- 按用户要求改三处：
--   ① 免征额 500 万 → 50 万
--   ② 参与分配的门槛 2000 万 → 1000 万
--   ③ 均值回归锚点：平均值 → 中位数（这次真正接线）
--
-- ⚠️ ③ 必须同时调回归强度，否则会过猛：
--    中位数大约 100 万，Utw 14.63 亿 → 偏离 1463 倍，ln(1463) ≈ 7.29
--    原强度 v_k_day = 0.0474，每天累计约 -17%；再叠加垄断税 7% = -24%/天，
--    两天掉一半，太快。所以把强度做成可配置，默认降到 0.015
--    （约 -7%/天，与垄断税叠加约 -14%/天，大约 10 天减半）。
-- ============================================================


-- ============================================================
-- ① 参数表：改默认值 + 新增回归强度
-- ============================================================
CREATE TABLE IF NOT EXISTS public.growth_fund_config (
    key   text PRIMARY KEY,
    value text NOT NULL
);

INSERT INTO public.growth_fund_config (key, value) VALUES
    ('enabled',        '1'),
    ('share_pct',      '25'),         -- 税收的 25% 进基金（原 50%，太猛）
    ('daily_cap',      '20000000'),   -- ⭐ 基金每天最多发 2000 万，发不完的照旧销毁
    ('cap_value',      '10000000'),   -- 1000 万（原 2000 万）
    ('tax_free_below', '500000'),     -- 50 万（原 500 万）
    ('regress_k',      '0.015')       -- 新增：均值回归强度
ON CONFLICT (key) DO NOTHING;

-- 已经跑过旧版的，用这两句把值纠正过来（只在还是旧值时才改，不动你手调过的）
UPDATE public.growth_fund_config SET value = '10000000' WHERE key = 'cap_value'      AND value = '20000000';
UPDATE public.growth_fund_config SET value = '500000'   WHERE key = 'tax_free_below' AND value = '5000000';
-- 已经跑过旧版（share_pct=50）的，降到 25 —— 50% 太猛，一天能把小公司翻半个身
UPDATE public.growth_fund_config SET value = '25'       WHERE key = 'share_pct'      AND value = '50';
INSERT INTO public.growth_fund_config (key, value) VALUES ('regress_k', '0.015')
ON CONFLICT (key) DO NOTHING;
INSERT INTO public.growth_fund_config (key, value) VALUES ('daily_cap', '20000000')
ON CONFLICT (key) DO NOTHING;

REVOKE ALL ON public.growth_fund_config FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ② 中位数锚点函数
-- ============================================================
CREATE OR REPLACE FUNCTION public._market_median_value()
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT coalesce(
             percentile_cont(0.5) WITHIN GROUP (ORDER BY market_value),
             20000)
      FROM public.user_companies
     WHERE market_value > 0;
$$;
REVOKE ALL ON FUNCTION public._market_median_value() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ③ 重写波动函数：锚点换成中位数 + 强度可配置
-- ============================================================
-- 除这两点外，其余逻辑（交易时段、8 秒节流、按真实时间缩放、涨跌停冻结与
-- 边界、最低市值保底）一字未动。原 v_k_day 是 CONSTANT，改成普通变量。
CREATE OR REPLACE FUNCTION public.random_fluctuate_market_values()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    company        RECORD;
    change_percent FLOAT;
    new_value      BIGINT;
    v_day_open     NUMERIC;
    v_last         timestamptz;
    v_anchor       NUMERIC;
    v_ratio        NUMERIC;
    v_pull         FLOAT;
    v_dt           FLOAT;
    v_sigma        FLOAT;
    v_k_day        FLOAT := 0.015;
    v_sigma_day    CONSTANT FLOAT := 0.06;
    v_session_secs CONSTANT FLOAT := 43200;
BEGIN
    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN;
    END IF;

    SELECT value::timestamptz INTO v_last FROM public.market_meta WHERE key = 'last_fluctuate';
    IF v_last IS NOT NULL AND v_last > now() - interval '8 seconds' THEN
        RETURN;
    END IF;

    v_dt := LEAST(
                GREATEST(
                    EXTRACT(EPOCH FROM (now() - coalesce(v_last, now() - interval '10 seconds')))::float,
                    0),
                900);

    -- 锚点：中位数。用平均值会被超大公司一个人拉高，导致"回归"对小公司
    -- 全是往上拉、对超大公司却几乎不痛（偏离倍数被算小了）。
    v_anchor := public._market_median_value();
    IF v_anchor IS NULL OR v_anchor <= 0 THEN v_anchor := 20000; END IF;

    -- 回归强度可配；配置读不到就用默认，绝不让配置问题中断波动
    BEGIN
        SELECT max(value::numeric) FILTER (WHERE key = 'regress_k')
          INTO v_k_day FROM public.growth_fund_config;
    EXCEPTION WHEN OTHERS THEN
        v_k_day := 0.015;
    END;
    IF v_k_day IS NULL OR v_k_day <= 0 THEN v_k_day := 0.015; END IF;

    FOR company IN SELECT id, market_value FROM user_companies LOOP
        SELECT open INTO v_day_open
          FROM public.stock_daily_kline
         WHERE company_id = company.id AND trade_date = current_date;

        IF v_day_open IS NOT NULL THEN
            IF company.market_value > v_day_open * 1.50
               OR company.market_value < v_day_open * 0.50 THEN
                CONTINUE;
            END IF;
        END IF;

        v_sigma := v_sigma_day * sqrt(v_dt / v_session_secs);
        change_percent := (random() - 0.5) * 2 * v_sigma * sqrt(3);

        IF company.market_value > 0 THEN
            v_ratio := company.market_value::numeric / v_anchor;
            IF v_ratio > 0 THEN
                v_pull := -v_k_day * (v_dt / 86400.0) * ln(v_ratio);
                v_pull := GREATEST(-0.005, LEAST(0.005, v_pull));
                change_percent := change_percent + v_pull;
            END IF;
        END IF;

        new_value := company.market_value + (company.market_value * change_percent);

        IF v_day_open IS NOT NULL THEN
            IF new_value > v_day_open * 1.50 THEN
                new_value := floor(v_day_open * 1.50);
            ELSIF new_value < v_day_open * 0.50 THEN
                new_value := GREATEST(floor(v_day_open * 0.50), 10000);
            END IF;
        END IF;

        IF new_value < 10000 THEN new_value := 10000; END IF;

        UPDATE user_companies SET market_value = new_value WHERE id = company.id;
    END LOOP;

    INSERT INTO public.market_meta(key, value) VALUES ('last_fluctuate', now()::text)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
END;
$fn$;

-- 页面每 10 秒调它（本身有 8 秒节流 + 按真实时间缩放，调得勤不会加速涨跌）
REVOKE ALL ON FUNCTION public.random_fluctuate_market_values() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.random_fluctuate_market_values() TO anon;


-- ============================================================
-- ④ 收税函数：同步新默认值（免征 50 万 / 门槛 1000 万）
-- ============================================================
CREATE OR REPLACE FUNCTION public.collect_company_tax()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    v_enabled    boolean := true;
    v_fund_pct   numeric := 50;
    v_cap        numeric := 10000000;
    v_free_below numeric := 500000;
    v_daily_cap  numeric := 20000000;   -- ⭐ 基金每天发放上限
    v_fund_amt   numeric := 0;
    v_got_cnt    int := 0;
BEGIN
    BEGIN
        SELECT coalesce(bool_or(value = '1') FILTER (WHERE key = 'enabled'), true),
               coalesce(max(value::numeric) FILTER (WHERE key = 'share_pct'), 25),
               coalesce(max(value::numeric) FILTER (WHERE key = 'cap_value'), 10000000),
               coalesce(max(value::numeric) FILTER (WHERE key = 'tax_free_below'), 500000),
               coalesce(max(value::numeric) FILTER (WHERE key = 'daily_cap'), 20000000)
          INTO v_enabled, v_fund_pct, v_cap, v_free_below, v_daily_cap
          FROM public.growth_fund_config;
    EXCEPTION WHEN OTHERS THEN
        v_enabled := false;
    END;

    SELECT coalesce(sum(market_value), 0) INTO v_site_total FROM public.user_companies;

    FOR r IN
        SELECT id, company_name, market_value
          FROM public.user_companies
         WHERE market_value >= 300000
         ORDER BY market_value DESC
    LOOP
        v_rate := CASE
            WHEN r.market_value <  1000000  THEN 0.002
            WHEN r.market_value <  20000000 THEN 0.005
            WHEN r.market_value <  50000000 THEN 0.010
            ELSE                                 0.020
        END;

        IF v_site_total > 0 THEN
            v_share := r.market_value::numeric / v_site_total;
            IF v_share > v_mono_line THEN
                v_rate := v_rate + v_mono_rate;
                v_mono_cnt := v_mono_cnt + 1;
                v_mono_total := v_mono_total + floor(r.market_value * v_mono_rate);
            END IF;
        END IF;

        -- 低于免征额的不收税
        IF r.market_value < v_free_below THEN
            CONTINUE;
        END IF;

        v_tax := floor(r.market_value * v_rate);
        IF v_tax < 1 THEN CONTINUE; END IF;

        UPDATE public.user_companies
           SET market_value = GREATEST(market_value - v_tax, 10000)
         WHERE id = r.id;

        v_total := v_total + v_tax;
        v_count := v_count + 1;
    END LOOP;

    -- 一部分税收发给中小公司（零通胀：钱是收来的，不是发的）
    IF v_enabled AND v_fund_pct > 0 AND v_total > 0 THEN
        v_fund_amt := floor(v_total * least(greatest(v_fund_pct, 0), 100) / 100.0);
        -- ⭐ 封顶：一天最多发这么多，多出来的照旧销毁（不造币）
        IF v_daily_cap > 0 THEN
            v_fund_amt := LEAST(v_fund_amt, v_daily_cap);
        END IF;
        IF v_fund_amt > 0 THEN
            WITH pool AS (
                SELECT id, (v_cap - market_value) AS weight
                  FROM public.user_companies
                 WHERE market_value < v_cap AND market_value > 0
            ), tot AS (
                SELECT sum(weight) AS w FROM pool
            ), give AS (
                SELECT p.id AS cid,
                       floor(v_fund_amt * (p.weight::numeric / nullif(t.w, 0))) AS amt
                  FROM pool p, tot t
                 WHERE t.w > 0
            )
            UPDATE public.user_companies c
               SET market_value = c.market_value + g.amt
              FROM give g
             WHERE c.id = g.cid AND g.amt >= 1;

            GET DIAGNOSTICS v_got_cnt = ROW_COUNT;
        END IF;
    END IF;

    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date', to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    IF v_fund_amt > 0 THEN
        BEGIN
            INSERT INTO public.growth_fund_logs (day, collected, fund, companies)
            VALUES ((now() AT TIME ZONE 'Asia/Shanghai')::date, v_total, v_fund_amt, v_got_cnt)
            ON CONFLICT (day) DO UPDATE
              SET collected = EXCLUDED.collected,
                  fund      = EXCLUDED.fund,
                  companies = EXCLUDED.companies;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RAISE NOTICE '公司税: 征收 % 家 / %；垄断税 % 家 / %；成长基金发放 %（覆盖 % 家）',
                 v_count, v_total, v_mono_cnt, v_mono_total, v_fund_amt, v_got_cnt;

    RETURN jsonb_build_object(
        'ok', true, 'companies', v_count, 'total', v_total,
        'monopoly_companies', v_mono_cnt, 'monopoly_total', v_mono_total,
        'fund_amount', v_fund_amt, 'fund_companies', v_got_cnt,
        'site_total', v_site_total);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.collect_company_tax() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 验收
-- ============================================================
SELECT key AS 参数, value AS 值 FROM public.growth_fund_config ORDER BY key;

SELECT public._market_median_value()                                   AS 中位数_新锚点,
       (SELECT round(avg(market_value)) FROM public.user_companies)    AS 平均值_旧锚点,
       (SELECT max(market_value) FROM public.user_companies)           AS 最大值;

-- 参与分配的公司数量
SELECT count(*) FILTER (WHERE market_value < 10000000 AND market_value > 0) AS 参与分配,
       count(*) FILTER (WHERE market_value >= 10000000)                   AS 不参与,
       count(*)                                                           AS 总数
  FROM public.user_companies;

-- 谁会被分到钱、每天大概分多少（按每日上限 2000 万估算）
WITH pool AS (
    SELECT company_name, market_value, (10000000 - market_value) AS weight
      FROM public.user_companies
     WHERE market_value < 10000000 AND market_value > 0
), tot AS (SELECT sum(weight) AS w FROM pool)
SELECT company_name AS 公司, market_value AS 当前市值,
       round(weight::numeric / nullif((SELECT w FROM tot), 0) * 20000000) AS 预估每天分到
  FROM pool ORDER BY weight DESC LIMIT 15;
