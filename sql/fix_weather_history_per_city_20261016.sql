-- ============================================================
--  修：天气曲线「有的城市有实测、有的没采到样」
--
--  【现象】站长截图对比：
--      有的城市  「过去 6 小时实测 · 36 个采样 · 未来 18 小时预测」
--      有的城市  「过去 6 小时没采到样 · 未来 18 小时预测」
--    前者画出了实测的锯齿线，后者只有一条光滑的模型曲线。
--
--  【原因】不是采样没跑，是【取回来的时候被截断了】。
--
--    postgrest（Supabase 那个 REST 层）一次请求【最多返回 1000 行】，
--    而 get_weather_history 是这样的：
--
--        SELECT … FROM weather_history
--         WHERE at >= now() - interval
--         ORDER BY city, at;          ← 没有 LIMIT，但也没按城市限量
--
--    16 座城市一天能攒 16 × 144 = 2304 行，早就超了 1000。
--    结果按 city 字母序排，前面的城市把 1000 行额度用光，
--    排在后面的城市一条都拿不到 —— 所以「有的有、有的没有」，
--    而且是【稳定】的字母序前后之分，不是随机。
--
--  【改法】改成每座城市各取最近 N 条，而不是全局取 1000 条。
--    用窗口函数按城市分区编号，只留每城最新的若干条。
--    16 城 × 42 条 = 672 行，安全落在 1000 以内。
--
--  【为什么每城 42 条】
--    采样是每 10 分钟一次 → 一小时 6 条 → 6 小时 36 条。
--    留点余量给时钟漂移，取 p_hours × 6 + 6 条。
--    p_hours=24 时是 150 条/城 —— 那 16 城就 2400 行了，又会超。
--    所以同时把上限压一下：每城最多 42 条（够 6 小时曲线用），
--    曲线只需要过去 6 小时，取多了也没用。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看现在每座城市各有多少条（跑之前的样子）
-- ============================================================
SELECT city AS 城市,
       count(*) AS 条数,
       max(at) AS 最新一条
  FROM public.weather_history
 WHERE at >= now() - interval '24 hours'
 GROUP BY city
 ORDER BY city;

-- ⚠️ 如果这里看到有些城市是 0 条，说明采样确实没轮到它；
--    如果每座城市都有几十条，那就是【取回来被截断】——
--    也就是这个脚本要修的问题。


-- ============================================================
-- 第 2 步：重建查询函数，改成每城各取最近 N 条
-- ============================================================
DROP FUNCTION IF EXISTS public.get_weather_history(integer);

CREATE OR REPLACE FUNCTION public.get_weather_history(p_hours integer DEFAULT 24)
RETURNS TABLE (
    city        text,
    temp_c      numeric,
    humidity    numeric,
    pressure    numeric,
    aqi         numeric,
    at          timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    -- ⚠️ 必须【按城市分区】限量。
    --    直接 ORDER BY city, at 的话，postgrest 那 1000 行上限会把
    --    字母序靠后的城市整个切掉，表现就是「有的城市没采到样」。
    SELECT city, temp_c, humidity, pressure, aqi, at
      FROM (
            SELECT h.city, h.temp_c, h.humidity, h.pressure, h.aqi, h.at,
                   row_number() OVER (PARTITION BY h.city ORDER BY h.at DESC) AS rn
              FROM public.weather_history h
             WHERE h.at >= now() - make_interval(
                            hours => GREATEST(1, LEAST(COALESCE(p_hours, 24), 168)))
           ) t
     -- 每城最多 42 条：6 小时 × 每小时 6 条 = 36，留 6 条余量。
     -- 曲线只用过去 6 小时，取更多没意义，还会把总行数顶到 1000 上限。
     WHERE rn <= 42
     ORDER BY city, at;
$fn$;

GRANT EXECUTE ON FUNCTION public.get_weather_history(integer) TO anon, authenticated;

COMMENT ON FUNCTION public.get_weather_history(integer) IS
    '天气瞎报 · 取最近 N 小时的历史采样，每座城市最多 42 条（够 6 小时曲线用）。'
    '注意：必须按城市分区限量 —— postgrest 一次最多返 1000 行，'
    '全局排序会把字母序靠后的城市整个切掉。';


-- ============================================================
-- 第 3 步：验证 —— 每座城市都能拿到数据
-- ============================================================
SELECT city AS 城市,
       count(*) AS 拿到条数,
       CASE WHEN count(*) >= 6 THEN '✅ 够画实测线' ELSE '⚠️ 太少，曲线会显示「没采到样」' END AS 状态
  FROM public.get_weather_history(24)
 GROUP BY city
 ORDER BY city;

SELECT '城市总数' AS 项目,
       (SELECT count(DISTINCT city)::text FROM public.get_weather_history(24)) AS 有数据的城市数,
       (SELECT count(*)::text FROM public.weather_state) AS 应该有这么多
UNION ALL
SELECT '返回总行数',
       (SELECT count(*)::text FROM public.get_weather_history(24)),
       '必须小于 1000（postgrest 上限）';


-- ============================================================
--  跑完之后
-- ============================================================
--  · 天气页每座城市的温度曲线左段都应该画出实测锯齿线
--  · 底部文案从「过去 6 小时没采到样」变成「过去 6 小时实测 · N 个采样」
--
--  ⚠️ 如果第 1 步里就有城市是 0 条，那是另一个问题：
--     采样任务（pg_cron 的 weather-history-sample）可能没在跑，
--     或者 tick_weather 的城市数组和 weather_state 不一致。
--     那种情况把这个查询的结果发我。
-- ============================================================
