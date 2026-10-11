-- ============================================================
--  天气瞎报 · 加第 15 座城市：AWST市
--
--  ⚠️ 又提醒一次：tick_weather() 里有【七个平行数组按下标对齐】
--        c 城市名 · b 年均温度 · w 季节振幅 · j 抖动
--        h 基准湿度 · a 基准空气 · s 基准能见度
--     加城市必须七个一起加。3ty 那次只加了 c，
--     结果 3ty市 显示成 60°C / 320 重度污染 / 60km。
--
--  ⚠️ 数组内容【不硬编码】。硬编码的锚点（'27,18,16]'）每加一座城市
--     尾巴就变一次，一变就静默失败。改成正则找
--     「变量名 CONSTANT 类型[] := ARRAY[ … ]」，在 ] 前补一项。
--
--  取值和页面 CITIES 里 AWST市 那条对齐：
--      base 23 · swing 11 · vol 1.2 · hum 55 · aqi 30 · vis 30
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：插一行 AWST市
-- ============================================================
INSERT INTO public.weather_state
    (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force)
VALUES
    ('AWST市', 23.0, 55.0, 101.3, 30.0, 30, (random() * 15)::smallint, 1 + random() * 2)
ON CONFLICT (city) DO NOTHING;


-- ============================================================
-- 第 2 步：七个数组各补一项
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_hit  integer := 0;
    adds   text[][] := ARRAY[
        ['c', '''AWST市'''], ['b', '23'], ['w', '11'], ['j', '1.2'],
        ['h', '55'], ['a', '30'], ['s', '30']
    ];
    k integer;
    v_pat text;
BEGIN
    FOR r IN
        SELECT p.oid, pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;

        IF position('AWST市' in v_src) > 0 THEN
            RAISE NOTICE 'tick_weather 里已经有 AWST市 了，跳过';
            CONTINUE;
        END IF;

        v_new := v_src;
        FOR k IN 1..array_length(adds, 1) LOOP
            v_pat := '(' || adds[k][1] || '\s+CONSTANT\s+\w+\[\]\s*:=\s*ARRAY\[[^\]]*)(\])';
            v_new := regexp_replace(v_new, v_pat, E'\\1,' || adds[k][2] || E'\\2');
        END LOOP;

        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_hit := v_hit + 1;
        ELSE
            RAISE NOTICE '⚠️ 一处都没替换上 —— 函数结构和脚本假设的不一样，别当成成功';
        END IF;
    END LOOP;
    RAISE NOTICE '改了 % 个 tick_weather', v_hit;
END $$;


-- ============================================================
-- 第 3 步：推一轮
-- ============================================================
SELECT public.tick_weather();


-- ============================================================
-- 第 4 步：验证
-- ============================================================
SELECT city AS 城市,
       round(temp_c::numeric, 1)     AS 温度,
       round(humidity::numeric, 0)   AS 湿度,
       round(pressure::numeric, 1)   AS 气压,
       round(visibility::numeric, 0) AS 能见度,
       round(aqi::numeric, 0)        AS 空气,
       round(wind_force::numeric, 1) AS 风力
  FROM public.weather_state ORDER BY city;

SELECT '城市数' AS 项目,
       (SELECT count(*)::text FROM public.weather_state) AS 值,
       '应为 15' AS 说明
UNION ALL
SELECT 'AWST市 在 tick_weather 里',
       CASE WHEN EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                   AND position('AWST市' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 有' ELSE '❌ 没有（第 2 步没成功）' END, ''
UNION ALL
SELECT '前两座还在不在',
       (SELECT string_agg(x, ' ') FROM (
            SELECT unnest(ARRAY['3ty市','Mn(NO3)2市']) AS x) t
         WHERE EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                   AND position(t.x in pg_get_functiondef(p.oid)) > 0)), '3ty市 Mn(NO3)2市';


-- ============================================================
--  跑完之后
-- ============================================================
--  · 天气页多出第 15 张卡「🌏 AWST市」
--  · 空气质量柱状图从 14 根变 15 根
--  · ⚠️ PythonAnywhere 点一次 Reload（app.py 里那行才生效）
-- ============================================================
