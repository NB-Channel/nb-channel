-- ============================================================
-- 停掉股票的均值回归（2026-10-01）
-- ============================================================
-- 做法：加一个开关 regress_enabled，默认 '0'（停用）。
--       回归那一段代码保留在函数里，只是被开关跳过 ——
--       以后想恢复，改一个数字就行，不用再改函数。
--
-- 停掉之后股价怎么走：
--   · 随机波动照旧（每日波动率 σ=6%，按真实时间缩放，8 秒节流）
--   · 只少了"偏离市场水平就被拉回来"这一股力
--   · 涨跌停（相对当日开盘 ±50%）、最低市值保底 10000 都不变
--
-- ⚠️ 要注意的副作用：
--   均值回归原本承担两件事 —— 压住过高的、托住过低的。
--   停掉之后这两个力都没了，股价会变成纯随机游走，长期容易走极端。
--   现在结构上的力由另外两个机制接管：
--     · 垄断税（占比 > 40% 加征 5%）压大公司
--     · 成长基金（每天 1500 万）托小公司
--   如果发现小公司开始一路跌到 10000 保底，说明需要把回归开回来一点点
--   （把 regress_k 设成 0.005 这种小值，而不是 0.015）。
-- ============================================================


-- ============================================================
-- ① 开关（默认关闭）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.growth_fund_config (
    key   text PRIMARY KEY,
    value text NOT NULL
);

INSERT INTO public.growth_fund_config (key, value) VALUES ('regress_enabled', '0')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;   -- 这次要覆盖，确保是 0

REVOKE ALL ON public.growth_fund_config FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ② 重写波动函数：回归那一段加开关
-- ============================================================
-- 除"回归被开关控制"这一点外，其余逻辑（交易时段、8 秒节流、
-- 按真实时间缩放、涨跌停冻结与边界、最低市值保底）一字未动。
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
    v_regress_on   text  := '1';                 -- ⭐ 回归开关，从配置表读
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

    -- 读配置：回归开关 + 强度
    BEGIN
        SELECT coalesce(max(value) FILTER (WHERE key = 'regress_enabled'), '1'),
               coalesce(max(value::numeric) FILTER (WHERE key = 'regress_k'), 0.015)
          INTO v_regress_on, v_k_day
          FROM public.growth_fund_config;
    EXCEPTION WHEN OTHERS THEN
        v_regress_on := '1';
        v_k_day := 0.015;
    END;
    IF v_k_day IS NULL OR v_k_day <= 0 THEN v_k_day := 0.015; END IF;

    -- 锚点只有真要回归时才需要算
    IF v_regress_on = '1' THEN
        v_anchor := public._market_median_value();
        IF v_anchor IS NULL OR v_anchor <= 0 THEN v_anchor := 20000; END IF;
    END IF;

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

        -- 随机部分：按 sqrt(时间) 缩放
        v_sigma := v_sigma_day * sqrt(v_dt / v_session_secs);
        change_percent := (random() - 0.5) * 2 * v_sigma * sqrt(3);

        -- ⭐ 均值回归：开关关掉就整段跳过（代码留着，随时能开回来）
        IF v_regress_on = '1' AND company.market_value > 0 THEN
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
-- ③ 随时开回来 / 调力度
-- ============================================================
-- 完全恢复（用之前的强度）：
--   UPDATE public.growth_fund_config SET value='1' WHERE key='regress_enabled';
--
-- 只开一点点（温和托底，推荐先试这个）：
--   UPDATE public.growth_fund_config SET value='1'     WHERE key='regress_enabled';
--   UPDATE public.growth_fund_config SET value='0.004' WHERE key='regress_k';
--
-- 再停掉：
--   UPDATE public.growth_fund_config SET value='0' WHERE key='regress_enabled';


-- ============================================================
-- 验收
-- ============================================================
SELECT key AS 参数, value AS 值 FROM public.growth_fund_config ORDER BY key;
-- 应该看到 regress_enabled = 0

SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public' AND p.proname = 'random_fluctuate_market_values' AND p.prokind = 'f';

-- 确认函数里确实带上了开关判断（应该返回 1 行）
SELECT position('v_regress_on = ''1''' in pg_get_functiondef(p.oid)) AS 开关判断位置
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public' AND p.proname = 'random_fluctuate_market_values';
