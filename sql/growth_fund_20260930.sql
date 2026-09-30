-- ============================================================
-- 扶植中小公司 · 方案（2026-09-30）
-- ============================================================
-- 【要解决的问题】
--   全站 15.64 亿，Utw 一家 14.63 亿（93.57%），其余 91 家合计只有 1.01 亿。
--   光靠垄断税削峰没用 —— 因为他就是分母的 93.57%，削他等于削全站，
--   占比几乎不动（算过：93.57% → 93.2%，按这个速度要 50 天才到 40%）。
--
-- 【核心思路：不造币，只重新分配】
--   公司税现在是【直接销毁、不流入任何账户】。改成：
--       一半照旧销毁（保持通缩压力，防通胀）
--       一半注入「成长基金」，按"离门槛还有多远"分给中小公司
--   钱是从大公司手里收来的，不是凭空发的 —— 所以【零通胀】。
--
-- 【预期效果】（按当前数据估算）
--   Utw 每天缴税 ≈ 14.63亿 × 7% = 1.02 亿，其中 5100 万进基金
--   分给 91 家 → 每家每天约 +56 万（从 111 万 → 167 万，一天 +50%）
--   越接近门槛分得越少 → 自动减速，不会无限膨胀
--   ≈10 天后：Utw 7.1 亿 / 中小合计 6.4 亿 → 他占比降到 ~53%
--   ≈20 天后：Utw 3.4 亿 / 中小合计 13.6 亿 → 他占比降到 ~20%，垄断税自动停征
--
-- ⚠️ 三个参数都放在 exchange_config 风格的表里，随时可调，见文件末尾。
-- ============================================================


-- ============================================================
-- ① 成长基金参数
-- ============================================================
CREATE TABLE IF NOT EXISTS public.growth_fund_config (
    key   text PRIMARY KEY,
    value text NOT NULL
);

INSERT INTO public.growth_fund_config (key, value) VALUES
    ('enabled',        '1'),        -- 1=启用 0=关闭
    ('share_pct',      '50'),       -- 公司税里有多大比例注入基金（%）剩下的照旧销毁
    ('cap_value',      '20000000'), -- 门槛：市值超过这个数的公司不参与分配
    ('tax_free_below', '5000000')   -- 免征额：市值低于这个数的公司不收公司税
ON CONFLICT (key) DO NOTHING;

REVOKE ALL ON public.growth_fund_config FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ② 改造 collect_company_tax：收税 + 顺手注资
-- ============================================================
-- 保留了原有的全部逻辑（分段税率 / 垄断税），只加三件事：
--   · 免征额从 30 万提到 growth_fund_config.tax_free_below
--   · 收上来的税记一个总数
--   · 按比例把一部分发给中小公司
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
    -- ⭐ 基金相关
    v_enabled    boolean := true;
    v_fund_pct   numeric := 50;
    v_cap        numeric := 20000000;
    v_free_below numeric := 5000000;
    v_fund_amt   numeric := 0;
    v_gave       numeric := 0;
    v_got_cnt    int := 0;
BEGIN
    -- 读参数（表不存在或无值时用默认）
    BEGIN
        SELECT coalesce(bool_or(value = '1') FILTER (WHERE key = 'enabled'), true),
               coalesce(max(value::numeric) FILTER (WHERE key = 'share_pct'), 50),
               coalesce(max(value::numeric) FILTER (WHERE key = 'cap_value'), 20000000),
               coalesce(max(value::numeric) FILTER (WHERE key = 'tax_free_below'), 5000000)
          INTO v_enabled, v_fund_pct, v_cap, v_free_below
          FROM public.growth_fund_config;
    EXCEPTION WHEN OTHERS THEN
        v_enabled := false;   -- 参数表出问题就退化成"纯收税"，不影响主流程
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

        -- ⭐ 免征额：小公司不交税，让它们专心长大
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

    -- ⭐ 把一部分税收发给中小公司（零通胀：钱是收来的，不是发的）
    IF v_enabled AND v_fund_pct > 0 AND v_total > 0 THEN
        v_fund_amt := floor(v_total * least(greatest(v_fund_pct, 0), 100) / 100.0);
        IF v_fund_amt > 0 THEN
            -- 按「离门槛还有多远」加权：越小的公司分得越多，接近门槛就停止
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
            SELECT coalesce(sum(market_value), 0) INTO v_gave
              FROM public.user_companies WHERE market_value < v_cap;
        END IF;
    END IF;

    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date', to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    -- 记一笔基金流水，方便以后对账
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
-- ③ 基金流水（方便对账："钱收了多少、发了多少、给了几家"）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.growth_fund_logs (
    day        date PRIMARY KEY,
    collected  numeric NOT NULL DEFAULT 0,
    fund       numeric NOT NULL DEFAULT 0,
    companies  integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.growth_fund_logs FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ④ 均值回归的锚点：平均 → 中位数
-- ============================================================
-- 现在锚点用的是 avg(market_value) —— 但 Utw 一家占了 93.57%，
-- 平均值被他一个人拉到 1700 万，结果"回归"对所有小公司都是往上拉的，
-- 对他却几乎不痛（他偏离倍数被算小了）。
-- 换成中位数（不受极端值影响，大概在 100 万上下）之后，
-- 他偏离中位数约 1400 倍，回归力度才真正体现出来。
--
-- ⚠️ 这一步【本文件只建函数，不接线】。要真生效得把
--    random_fluctuate_market_values 里那一行 avg(...) 换成这个函数，
--    但那要整体重写那个 90 多行的波动函数（含涨跌停、按时间缩放等逻辑），
--    风险比本文件大，所以拆成第二步单独做。
--    先把成长基金跑几天看效果，需要时再动它。
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
-- ⑤ 调参（随时可改，改完下一轮收税/波动就生效）
-- ============================================================
-- 关闭基金发放（只收税、不发钱）：
--   UPDATE public.growth_fund_config SET value='0' WHERE key='enabled';
--
-- 调整注资比例（比如从 50% 提到 70%）：
--   UPDATE public.growth_fund_config SET value='70' WHERE key='share_pct';
--
-- 调整门槛（比如允许更大的公司也参与分配）：
--   UPDATE public.growth_fund_config SET value='50000000' WHERE key='cap_value';
--
-- 调整免征额：
--   UPDATE public.growth_fund_config SET value='3000000' WHERE key='tax_free_below';


-- ============================================================
-- 验收
-- ============================================================
SELECT key AS 参数, value AS 值 FROM public.growth_fund_config ORDER BY key;

-- 当前谁会被分到钱、大概分多少（只算，不改数据）
WITH pool AS (
    SELECT company_name, market_value, (20000000 - market_value) AS weight
      FROM public.user_companies
     WHERE market_value < 20000000 AND market_value > 0
), tot AS (SELECT sum(weight) AS w FROM pool)
SELECT company_name AS 公司, market_value AS 当前市值,
       round((weight::numeric / nullif((SELECT w FROM tot),0) * 51000000)) AS 预估每天分到
  FROM pool ORDER BY weight DESC LIMIT 12;

-- 当前中位数（均值回归的新锚点）
SELECT public._market_median_value() AS 市场市值中位数;
