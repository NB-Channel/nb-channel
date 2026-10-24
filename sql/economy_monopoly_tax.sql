-- ============================================================
-- 两件事（2026-09-30）
-- ============================================================
-- ① 恢复「页面每 10 秒波动一次」
-- ② 新增「垄断税」：市值占全站 > 40% 的公司，在公司税结算时额外征收 5%
-- ============================================================


-- ============================================================
-- ① 给波动函数加回 anon 权限
-- ============================================================
-- 背景：股票页每 10 秒调一次 random_fluctuate_market_values 来推动行情。
--       但 economy_rebalance.sql / lock_system_rpcs.sql 后来把它锁成了
--       只给 service_role，理由是「能操纵行情」。前端于是每轮都拿到
--        42501 permission denied
--       一报错就落进 catch，页面永远显示「⚠️ 上次更新失败」。
--
-- 重新看了实现之后，那个锁是当时没细看代码的保守判断 —— 它其实操纵不了行情：
--   · 8 秒全局节流：8 秒内已波动过就直接 RETURN（不报错）
--   · 波动幅度按【真实经过的秒数】缩放：v_sigma := v_sigma_day * sqrt(v_dt/session)
--     调得再勤，每次也只补上真实过去的那点时间，总量不变
--   · 均值回归同样按 v_dt 缩放，还有单轮 ±0.5% 的护栏
--   · 只在交易时段（北京时间 8:00~20:00）生效，收盘后直接 RETURN
--
-- 所以放开是安全的：调用频率决定「多久检查一次」，不决定「涨跌多少」。
GRANT EXECUTE ON FUNCTION public.random_fluctuate_market_values() TO anon;

-- 顺带确认页面刷新要用的那几个读接口也没被误锁
-- （这些本来就该给匿名：页面只读数据）
DO $do$
BEGIN
    BEGIN
        GRANT EXECUTE ON FUNCTION public.sample_market_snapshot() TO anon;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'sample_market_snapshot 授权跳过：%', SQLERRM;
    END;
END
$do$;


-- ============================================================
-- ② 垄断税
-- ============================================================
-- 规则：某家公司市值占【全站总市值】超过 40% 时，
--       在原有分段税率之上，额外再加征 5%。
--
-- 原有分段税率（按自身市值）：
--   30 万以下免征 / 30万~100万 0.2% / 100万~2000万 0.5%
--   2000万~5000万 1% / 5000万以上 2%
--
-- 叠加后，一家占 90% 的公司实际税率 = 2% + 5% = 7%/天。
-- 按当前数据（Utw 15.09 亿、占 93.76%）估算：每天约扣 1.05 亿，
-- 大约 10 天减半，一个月左右会掉到 40% 线以下 —— 到那时垄断税自动停征。
--
-- 注意：判定用的是「扣税开始前」的全站总市值快照，
--       循环里逐家扣税不会影响本次的判定基准。
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
    v_site_total numeric := 0;     -- ⭐ 全站总市值（本次结算开始前的快照）
    v_share      numeric;          -- ⭐ 这家公司占全站的比重
    v_mono_cnt   int := 0;         -- ⭐ 被加征垄断税的公司数
    v_mono_total numeric := 0;     -- ⭐ 垄断税小计（便于对账）
    v_mono_rate  CONSTANT numeric := 0.05;   -- ⭐ 垄断税税率，可调
    v_mono_line  CONSTANT numeric := 0.40;   -- ⭐ 占比门槛，可调
BEGIN
    -- 先取一次全站总额作为判定基准
    SELECT coalesce(sum(market_value), 0) INTO v_site_total
      FROM public.user_companies;

    FOR r IN
        SELECT id, company_name, market_value
          FROM public.user_companies
         WHERE market_value >= 300000
         ORDER BY market_value DESC
    LOOP
        v_rate := CASE
            WHEN r.market_value <  1000000  THEN 0.002   -- 30 万 ~ 100 万
            WHEN r.market_value <  20000000 THEN 0.005   -- 100 万 ~ 2000 万
            WHEN r.market_value <  50000000 THEN 0.010   -- 2000 万 ~ 5000 万
            ELSE                                 0.020   -- 5000 万以上
        END;

        -- ⭐ 垄断税：占全站 > 40% 的，额外再加 5%
        IF v_site_total > 0 THEN
            v_share := r.market_value::numeric / v_site_total;
            IF v_share > v_mono_line THEN
                v_rate := v_rate + v_mono_rate;
                v_mono_cnt := v_mono_cnt + 1;
                v_mono_total := v_mono_total
                              + floor(r.market_value * v_mono_rate);
            END IF;
        END IF;

        v_tax := floor(r.market_value * v_rate);
        IF v_tax < 1 THEN CONTINUE; END IF;

        UPDATE public.user_companies
           SET market_value = GREATEST(market_value - v_tax, 10000)
         WHERE id = r.id;

        v_total := v_total + v_tax;
        v_count := v_count + 1;
    END LOOP;

    -- 记录收税日期（防止一天收多次）
    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date', to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    RAISE NOTICE '公司税: 征收 % 家,合计 %（其中垄断税 % 家 / %）已销毁',
                 v_count, v_total, v_mono_cnt, v_mono_total;

    RETURN jsonb_build_object(
        'ok', true,
        'companies', v_count,
        'total', v_total,
        'monopoly_companies', v_mono_cnt,
        'monopoly_total', v_mono_total,
        'site_total', v_site_total);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
-- 保持锁定：这是结算函数，绝不能让访客手动触发
REVOKE ALL ON FUNCTION public.collect_company_tax() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 验收
-- ============================================================
-- ① 波动函数现在匿名可调了吗？应该返回 t（或直接跑通不报 42501）
SELECT has_function_privilege('anon',
       'public.random_fluctuate_market_values()', 'EXECUTE') AS 波动函数_匿名可调_应为t;

-- ② 看当前谁会被垄断税命中（只算不扣，改数据前先看清楚）
SELECT company_name                                             AS 公司,
       market_value                                             AS 当前市值,
       round(market_value::numeric
             / nullif((SELECT sum(market_value) FROM public.user_companies), 0)
             * 100, 2)                                          AS 占全站百分比,
       CASE WHEN market_value::numeric
                 / nullif((SELECT sum(market_value) FROM public.user_companies), 0) > 0.40
            THEN '⚠️ 会加征 5%' ELSE '正常' END                  AS 垄断税
  FROM public.user_companies
 WHERE market_value >= 300000
 ORDER BY market_value DESC
 LIMIT 10;

-- ③ 想立刻看一次结算结果（会真的扣税，且当天不会重复扣）
--    ⚠️ 只在确认上面那张表看懂了之后再单独执行这一句
-- SELECT public.collect_company_tax();
