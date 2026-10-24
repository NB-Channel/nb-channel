-- ============================================================
--  天气瞎报 —— 数据放进数据库（照市值那套做法）
--
--  【为什么要改】
--  现在天气是前端 Math.random() 现算的 —— 每个访客各算各的，
--  两个人同时打开看到的数字不一样，一对就露馅。
--
--  【照市值怎么做的】
--  市值那套（sql/market_10s.sql）是这样的：
--      ① 状态存表（user_companies.market_value，由触发器维护）
--      ② 一个【自循环存储过程】market_tick_loop()
--      ③ pg_cron 每分钟 CALL 它一次，它内部循环 6 次、每次 pg_sleep(10)
--         → 实际就是每 10 秒推进一轮
--      ④ 每轮 COMMIT，立刻释放行锁（不这么做访客请求会排队等锁，报 57014）
--      ⑤ 前端调 RPC 读
--
--  天气完全照这个来，而且【不新建 cron、不新建连接】——
--  直接挂进那个已经在跑的循环里，成本几乎为零。
--
--  【一个差别】
--  市值只在交易时段（8:00-20:00）波动，天气要 24 小时都走。
--  所以把天气那步放在 session 判断【外面】，让它每轮都跑。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现在的 market_tick_loop 长什么样
-- ============================================================
SELECT pg_get_functiondef(p.oid) AS market_tick_loop当前定义
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'p'
   AND p.proname = 'market_tick_loop';


-- ============================================================
-- 第 1 步：状态表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.weather_state (
    city        text PRIMARY KEY,
    temp_c      numeric(6,2)  NOT NULL,
    humidity    numeric(5,2)  NOT NULL,
    pressure    numeric(7,2)  NOT NULL,
    visibility  numeric(6,2)  NOT NULL,
    aqi         numeric(6,2)  NOT NULL,
    wind_dir    smallint      NOT NULL,
    wind_force  numeric(5,2)  NOT NULL,
    updated_at  timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.weather_state IS
    '天气瞎报 · 十二座虚拟城市的当前气象（由 tick_weather 每 10 秒推进一轮）';

-- 只让函数读写，前端不直接碰表
ALTER TABLE public.weather_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.weather_state FROM anon, authenticated;


-- ============================================================
-- 第 2 步：初始化十二座城市
--   每座的基准值来自页面里的设定：年均温度 / 季节振幅 / 湿度 / 空气 / 能见度
-- ============================================================
INSERT INTO public.weather_state
    (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force)
SELECT v.city, v.temp, v.hum, 101.3, v.vis, v.aqi,
       (random() * 15)::smallint, 1 + random() * 3
  FROM (VALUES
    ('NB频道总部',   22.0, 45.0, 28.0,  22.0),
    ('U星',          12.0, 30.0, 42.0,  24.0),
    ('AWM市',         6.0, 62.0, 48.0,  20.0),
    ('Lemon市',      20.0, 58.0, 26.0,  26.0),
    ('Oganesson市',  34.0, 22.0, 30.0,  38.0),
    ('Fafat市',      17.0, 72.0, 22.0,  34.0),
    ('GC3市',        15.0, 52.0, 26.0,  42.0),
    ('UVS市',        25.0, 34.0, 50.0,  18.0),
    ('UWSF市',       13.0, 55.0, 38.0,  21.0),
    ('PTC市',        27.0, 40.0, 28.0,  30.0),
    ('5U市',         18.0, 60.0, 25.0,  32.0),
    ('Ubn市',        16.0, 64.0, 24.0,  36.0)
  ) AS v(city, temp, hum, vis, aqi)
ON CONFLICT (city) DO NOTHING;


-- ============================================================
-- 第 3 步：推进一轮（十二座城市各随机游走一步）
--
--   季节系数：-cos(2π × (一年中第几天 - 15) / 365.25)
--       1 月中旬 = -1（最冷），7 月中旬 = +1（最热）
--   每座城市有自己的年均基准和季节振幅，所以四季表现不同。
--
--   数据之间互相关联，不是六个独立随机数：
--       温度高 → 湿度低、气压略低
--       湿度高 + 空气差 → 能见度低
--       风大 → 空气不容易堆积
-- ============================================================
CREATE OR REPLACE FUNCTION public.tick_weather()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    -- 城市的基准设定：年均温度、季节振幅、每轮抖动、基准湿度、基准空气、基准能见度
    c CONSTANT text[]    := ARRAY['NB频道总部','U星','AWM市','Lemon市','Oganesson市',
                                  'Fafat市','GC3市','UVS市','UWSF市','PTC市','5U市','Ubn市'];
    b CONSTANT numeric[] := ARRAY[22,12,6,20,34,17,15,25,13,27,18,16];       -- 年均温度
    w CONSTANT numeric[] := ARRAY[ 2,26,14, 9, 8,11,12,10,15, 7,13,12];      -- 季节振幅
    j CONSTANT numeric[] := ARRAY[.4,3.2,1.4,1,2.6,1.2,1.1,.9,1.6,1.3,1.2,1];-- 抖动
    h CONSTANT numeric[] := ARRAY[45,30,62,58,22,72,52,34,55,40,60,64];      -- 基准湿度
    a CONSTANT numeric[] := ARRAY[22,24,20,26,38,34,42,18,21,30,32,36];      -- 基准空气
    s CONSTANT numeric[] := ARRAY[28,42,48,26,30,22,26,50,38,28,25,24];      -- 基准能见度

    v_doy    numeric;
    v_season numeric;
    r        record;
    i        int;
    v_target numeric;
BEGIN
    -- 季节系数
    v_doy := EXTRACT(DOY FROM (now() AT TIME ZONE 'Asia/Shanghai'))::numeric;
    v_season := -cos(2 * pi() * (v_doy - 15) / 365.25);

    FOR i IN 1..array_length(c, 1) LOOP
        SELECT * INTO r FROM public.weather_state WHERE city = c[i];
        CONTINUE WHEN NOT FOUND;

        -- ① 温度：往「季节应有值」靠 35%，再加抖动（随机游走，不会突变）
        v_target := b[i] + w[i] * v_season;
        r.temp_c := r.temp_c + (v_target - r.temp_c) * 0.35
                    + (random() * 2 - 1) * j[i];
        r.temp_c := GREATEST(-55, LEAST(60, r.temp_c));

        -- ② 湿度：温度偏高就偏干
        r.humidity := r.humidity
                    + ((h[i] - (r.temp_c - b[i]) * 1.1) - r.humidity) * 0.3
                    + (random() * 6 - 3);
        r.humidity := GREATEST(5, LEAST(100, r.humidity));

        -- ③ 空气：湿度大、风小的时候更容易堆积
        r.aqi := r.aqi
               + ((a[i] + (r.humidity - 50) * 0.35 + (4 - r.wind_force) * 5) - r.aqi) * 0.25
               + (random() * 14 - 7);
        r.aqi := GREATEST(8, LEAST(320, r.aqi));

        -- ④ 气压：温度高则略低
        r.pressure := r.pressure
                    + ((101.3 - (r.temp_c - 15) * 0.085) - r.pressure) * 0.3
                    + (random() * 0.7 - 0.35);
        r.pressure := GREATEST(87, LEAST(108, r.pressure));

        -- ⑤ 能见度：湿度和空气差都会压低它
        r.visibility := r.visibility
                      + ((s[i] * (1 - (r.humidity - 55) / 190) - r.aqi / 45) - r.visibility) * 0.3
                      + (random() * 2.4 - 1.2);
        r.visibility := GREATEST(0.2, LEAST(60, r.visibility));

        -- ⑥ 风：慢慢转向、慢慢变大变小
        IF random() < 0.3 THEN
            r.wind_dir := (r.wind_dir + CASE WHEN random() < 0.5 THEN 1 ELSE 15 END) % 16;
        END IF;
        r.wind_force := GREATEST(0.2, LEAST(12, r.wind_force + (random() * 0.9 - 0.45)));

        UPDATE public.weather_state
           SET temp_c = r.temp_c, humidity = r.humidity, pressure = r.pressure,
               visibility = r.visibility, aqi = r.aqi,
               wind_dir = r.wind_dir, wind_force = r.wind_force,
               updated_at = now()
         WHERE city = c[i];
    END LOOP;
END;
$fn$;

COMMENT ON FUNCTION public.tick_weather() IS
    '天气瞎报 · 推进一轮（十二座城市各随机游走一步，按真实季节）';


-- ============================================================
-- 第 4 步：前端读数据用的 RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_weather()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
    SELECT COALESCE(jsonb_agg(x ORDER BY x->>'city'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
                   'city',       city,
                   'temp_c',     round(temp_c, 1),
                   'temp_f',     round(temp_c * 9 / 5 + 32, 1),
                   'humidity',   round(humidity)::int,
                   'pressure',   round(pressure, 2),
                   'visibility', round(visibility, 1),
                   'aqi',        round(aqi)::int,
                   'wind_dir',   wind_dir,
                   'wind_force', round(wind_force, 1),
                   'updated_at', updated_at
               ) AS x
          FROM public.weather_state
      ) t;
$fn$;

COMMENT ON FUNCTION public.get_weather() IS
    '天气瞎报 · 返回十二座城市的当前气象（只读）';

GRANT EXECUTE ON FUNCTION public.get_weather() TO anon, authenticated;


-- ============================================================
-- 第 5 步：挂进已有的市场循环（不新建 cron、不新建连接）
--
--   市值那个过程是：cron 每分钟 CALL 一次 → 内部 6 轮 × pg_sleep(10)
--   天气直接挂进去，每轮顺带推进一次 —— 也就是每 10 秒一轮。
--
--   ⚠️ 关键差别：市值只在交易时段（8:00-20:00）波动，
--      天气要 24 小时都走，所以把天气那步放到 session 判断【外面】。
--
--   这里是按内容找锚点改的，不是整段重写 ——
--   万一库里的过程和仓库里那份不一样，脚本会【报出来】而不是改错。
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
    v_old CONSTANT text :=
        'FOR i IN 1..6 LOOP' || E'\n' ||
        '            PERFORM public.random_fluctuate_market_values();';
    v_rep CONSTANT text :=
        'FOR i IN 1..6 LOOP' || E'\n' ||
        '            IF v_in_session THEN' || E'\n' ||
        '                PERFORM public.random_fluctuate_market_values();' || E'\n' ||
        '            END IF;' || E'\n' ||
        '            PERFORM public.tick_weather();   -- 天气 24 小时都走';
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prokind = 'p'
       AND p.proname = 'market_tick_loop';

    IF v_src IS NULL THEN
        RAISE NOTICE '⚠️ 库里没有 market_tick_loop 这个过程 —— 天气表已建好，但没挂上定时';
        RETURN;
    END IF;

    IF position('tick_weather' in v_src) > 0 THEN
        RAISE NOTICE '跳过：market_tick_loop 里已经有 tick_weather 了';
        RETURN;
    END IF;

    IF position(v_old in v_src) = 0 THEN
        RAISE NOTICE '⚠️ 匹配不上那段循环 —— 没改动。请把第 0 步的结果发我，我照着改。';
        RETURN;
    END IF;

    v_new := replace(v_src, v_old, v_rep);
    EXECUTE v_new;
    RAISE NOTICE '✅ 天气已挂进 market_tick_loop（每 10 秒一轮，24 小时不停）';
END $$;


-- ============================================================
-- 第 6 步：验证
-- ============================================================

-- 6.1 表里有没有十二座
SELECT count(*) AS 城市数,
       CASE WHEN count(*) = 12 THEN '✅ 十二座齐了'
            ELSE '❌ 应该是 12' END AS 结论
  FROM public.weather_state;

-- 6.2 当前数据
SELECT city AS 城市, temp_c AS 摄氏, round(temp_c*9/5+32,1) AS 华氏,
       humidity AS 湿度, pressure AS 气压, visibility AS 能见度,
       aqi AS 空气, wind_dir AS 风向, wind_force AS 风力, updated_at AS 更新于
  FROM public.weather_state ORDER BY city;

-- 6.3 RPC 能不能调
SELECT jsonb_array_length(public.get_weather()) AS RPC返回条数;

-- 6.4 挂上了没有
SELECT CASE WHEN position('tick_weather' in pg_get_functiondef(p.oid)) > 0
            THEN '✅ 已挂进 market_tick_loop'
            ELSE '❌ 没挂上' END AS 定时状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'p' AND p.proname = 'market_tick_loop';


-- ============================================================
-- 第 7 步：手动跑一轮看看（可选）
-- ============================================================
-- SELECT public.tick_weather();
-- 隔十几秒再跑一次，然后看第 6.2 步的数字变没变。
--
-- ⚠️ 注意：定时任务只在【交易时段】每分钟被唤醒，
--    但过程内部现在无论是不是交易时段都会推进天气 ——
--    所以 24 小时都在走。
-- ============================================================
