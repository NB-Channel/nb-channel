-- ============================================================
--  天气瞎报 · 加第 13 座城市：3ty市
--
--  页面那边（weather.html / Beta/weather-Beta.html）已经加好了，
--  但页面拿的是数据库 get_weather() 返回的数据 ——
--  weather_state 里没有 3ty市 这一行的话，第 13 张卡是空的。
--
--  要改两处：
--      ① weather_state 里插一行（初始值）
--      ② tick_weather() 里的城市数组加一项 —— 不加的话它永远不会被推进
--
--  ⚠️ ②是用【按内容替换】做的：在 pg_get_functiondef 里找到那个城市数组，
--     把 'Ubn市' 换成 'Ubn市','3ty市'。找不到就 RAISE NOTICE 报出来，
--     不静默失败（之前栽过：NOTICE 在 SQL Editor 里不显示，
--     看起来像成功其实没改）。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看现在有几座城
-- ============================================================
SELECT count(*) AS 城市数, string_agg(city, ' ' ORDER BY city) AS 城市
  FROM public.weather_state;


-- ============================================================
-- 第 2 步：插一行 3ty市
--   初始值跟页面 CITIES 里的 base / hum / aqi / vis 对齐：
--       base 24（年均基准温度）、hum 52、aqi 28、vis 33
--   气压先给标准值 101.3，风向风力随机 —— tick 跑起来之后这些都会自己游走
-- ============================================================
INSERT INTO public.weather_state
    (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force)
VALUES
    ('3ty市', 24.0, 52.0, 101.3, 33.0, 28, (random() * 15)::smallint, 1 + random() * 3)
ON CONFLICT (city) DO NOTHING;


-- ============================================================
-- 第 3 步：把 3ty市 加进 tick_weather 的城市数组
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_hit  integer := 0;
BEGIN
    FOR r IN
        SELECT p.oid, pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;

        IF position('3ty市' in v_src) > 0 THEN
            RAISE NOTICE 'tick_weather 里已经有 3ty市 了，跳过';
            CONTINUE;
        END IF;

        -- 城市数组长这样：'Fafat市','GC3市',…,'5U市','Ubn市']
        -- 所以找 'Ubn市' 后面那个 ] ，在它前面补一项
        v_new := replace(v_src, '''Ubn市'']', '''Ubn市'',''3ty市'']');

        IF v_new = v_src THEN
            -- 有的写法是 'Ubn市', 后面还有别的；换成在 'Ubn市' 后面直接插
            v_new := replace(v_src, '''Ubn市'',', '''Ubn市'',''3ty市'',');
        END IF;

        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_hit := v_hit + 1;
        ELSE
            RAISE NOTICE '⚠️ tick_weather 里没找到 ''Ubn市'' 那种写法，没加上';
        END IF;
    END LOOP;
    RAISE NOTICE '改了 % 个 tick_weather', v_hit;
END $$;


-- ============================================================
-- 第 4 步：验证（结果格子直接看，不靠 NOTICE）
-- ============================================================
SELECT city AS 城市,
       round(temp_c::numeric, 1) AS 温度,
       round(humidity::numeric, 0) AS 湿度,
       round(aqi::numeric, 0) AS 空气,
       round(visibility::numeric, 0) AS 能见度
  FROM public.weather_state ORDER BY city;

SELECT '城市数' AS 项目,
       (SELECT count(*)::text FROM public.weather_state) AS 值,
       '应为 13' AS 说明
UNION ALL
SELECT '3ty市 在不在表里',
       CASE WHEN EXISTS (SELECT 1 FROM public.weather_state WHERE city = '3ty市')
            THEN '✅ 在' ELSE '❌ 不在' END,
       ''
UNION ALL
SELECT 'tick_weather 认不认 3ty市',
       CASE WHEN EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'tick_weather'
                   AND position('3ty市' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 认' ELSE '❌ 不认（第 3 步没成功）' END,
       '';


-- ============================================================
--  跑完之后
-- ============================================================
--  · 天气页会多出第 13 张卡「🛰️ 3ty市」
--  · 空气质量柱状图从 12 根变 13 根
--  · 等 tick 跑一轮（10 秒）它的数字就开始自己动了
--
--  ⚠️ 还有一处要改的是 PythonAnywhere 上的 /api/weather：
--     仓库里的 pythonanywhere/app.py 已经加了 '3ty市': (27, 1.04)，
--     但要【点 Reload】才会生效。
-- ============================================================
