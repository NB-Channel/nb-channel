-- ============================================================
--  天气瞎报 · 历史记录（给温度曲线提供真实累计数据）
--
--  【为什么要这个】
--  现在的温度曲线是按公式推的模型曲线（日均值 + 日内余弦 + 二阶谐波）。
--  站长希望能用【真实累计下来的数据】画。
--  所以加一张历史表，把每次推进的数值存一份，图表优先画实际记录。
--
--  【采样频率】
--      每 10 分钟一次（不是每次 tick 都存）
--      12 城 × 144 次/天 = 1728 行/天
--      保留 7 天 → 约 1.2 万行，很轻。
--  采样时机挂在已有的 tick_weather() 里 —— tick_weather 本来每 10 秒被调一次，
--  里面判断「距上次采样够不够 10 分钟」，够就写一行。
--  这样不用新开 cron，也不用改 weather_tick_loop。
--
--  【⚠️ 重要】这张表是从现在【才开始积累】的。
--      刚建好时是空的，图表会自动退回模型曲线，并在下面标明「模型推算」；
--      攒够 6 个点之后自动改画实际记录，标明「实际记录」。
--      也就是说：温度曲线要过大约 1 小时才开始变成真实数据，
--      要看满 24 小时的真实曲线，得等一天。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：建表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.weather_history (
    id          bigserial PRIMARY KEY,
    city        text        NOT NULL,
    temp_c      numeric(6,2),
    humidity    numeric(6,2),
    pressure    numeric(7,2),
    visibility  numeric(7,2),
    aqi         numeric(6,2),
    wind_dir    integer,
    wind_force  numeric(5,2),
    at          timestamptz NOT NULL DEFAULT now()
);

-- 按城市 + 时间查（图表就是这么查的）
CREATE INDEX IF NOT EXISTS idx_weather_history_city_at
    ON public.weather_history (city, at DESC);

COMMENT ON TABLE public.weather_history IS
    '天气瞎报 · 历史采样（每 10 分钟一条/城，保留 7 天，由 tick_weather 顺带写入）';


-- ============================================================
-- 第 2 步：采样函数（由 tick_weather 调用）
--   自己判断「距上次采样够不够 10 分钟」，不够就直接返回，开销极小。
-- ============================================================
CREATE OR REPLACE FUNCTION public.sample_weather_history()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_meta   text;
    v_last   timestamptz;
BEGIN
    -- 用 market_meta 这张现成的键值表记「上次采样时间」
    SELECT (value)::timestamptz INTO v_last
      FROM public.market_meta WHERE key = 'last_weather_sample';

    IF v_last IS NOT NULL AND now() - v_last < interval '10 minutes' THEN
        RETURN;                       -- 还不够 10 分钟，跳过
    END IF;

    INSERT INTO public.weather_history
        (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force, at)
    SELECT city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force, now()
      FROM public.weather_state;

    INSERT INTO public.market_meta (key, value)
    VALUES ('last_weather_sample', now()::text)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    -- 顺手清理 7 天前的
    DELETE FROM public.weather_history WHERE at < now() - interval '7 days';
END;
$fn$;

COMMENT ON FUNCTION public.sample_weather_history() IS
    '天气瞎报 · 每 10 分钟把 weather_state 快照进 weather_history，并清理 7 天前的';


-- ============================================================
-- 第 3 步：把采样挂进 tick_weather —— 按【内容】定位，不认函数名
--   （前面的教训：靠函数名定位踩过三次坑）
-- ============================================================
DO $$
DECLARE
    r        record;
    v_src    text;
    v_new    text;
    v_hit    int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;
        IF position('sample_weather_history' in v_src) > 0 THEN
            RAISE NOTICE 'tick_weather 里已经挂了采样，跳过';
            CONTINUE;
        END IF;
        -- 在函数体里找 RETURN;（tick_weather 结尾那个），插在它前面
        v_new := regexp_replace(v_src,
                     '(RETURN;)',
                     E'PERFORM public.sample_weather_history();   -- 顺带做历史采样\n    \\1',
                     'i');
        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_hit := v_hit + 1;
        ELSE
            RAISE NOTICE '⚠️ tick_weather 里找不到 RETURN;，没挂上采样';
        END IF;
    END LOOP;
    RAISE NOTICE '✅ 挂了 % 个 tick_weather', v_hit;
END $$;


-- ============================================================
-- 第 4 步：查询函数（前端调用）
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
    SELECT h.city, h.temp_c, h.humidity, h.pressure, h.aqi, h.at
      FROM public.weather_history h
     WHERE h.at >= now() - make_interval(hours => GREATEST(1, LEAST(COALESCE(p_hours, 24), 168)))
     ORDER BY h.city, h.at;
$fn$;

GRANT EXECUTE ON FUNCTION public.get_weather_history(integer) TO anon, authenticated;

COMMENT ON FUNCTION public.get_weather_history(integer) IS
    '天气瞎报 · 取最近 N 小时的历史采样（默认 24，最多 168），给温度曲线用';


-- ============================================================
-- 第 5 步：验证
-- ============================================================
-- 5.1 表和函数在不在
SELECT 'weather_history 表' AS 项目,
       CASE WHEN to_regclass('public.weather_history') IS NOT NULL
            THEN '✅ 已建' ELSE '❌ 没有' END AS 状态
UNION ALL
SELECT 'sample_weather_history()',
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname='public' AND p.proname='sample_weather_history')
            THEN '✅ 已建' ELSE '❌ 没有' END
UNION ALL
SELECT 'get_weather_history()',
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname='public' AND p.proname='get_weather_history')
            THEN '✅ 已建' ELSE '❌ 没有' END;

-- 5.2 采样有没有挂进 tick_weather
SELECT 'tick_weather 挂采样' AS 项目,
       CASE WHEN EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                   AND position('sample_weather_history' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 已挂' ELSE '❌ 没挂上' END AS 状态;

-- 5.3 当前累计了多少条（刚建好应该是 0）
SELECT count(*) AS 已累计条数,
       COALESCE(to_char(min(at) AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'), '（还没有）') AS 最早,
       COALESCE(to_char(max(at) AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'), '（还没有）') AS 最新
  FROM public.weather_history;


-- ============================================================
--  跑完之后
-- ============================================================
--  手动立刻采一次，不用等 10 分钟：
--      SELECT public.sample_weather_history();
--  然后刷新天气页，曲线下方会标明数据来源。
--
--  ⚠️ 刚建好时表是空的 —— 曲线会先显示模型推算，攒够 6 个点（约 1 小时）
--     自动切成实际记录。要看满 24 小时的真实曲线得等一天。
-- ============================================================
