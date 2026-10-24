-- ============================================================
--  修 3ty市 数字发疯（60°C / 320 空气 / 60km 能见度）
--
--  【原因】上一版 weather_add_3ty_20261011.sql 里我用
--      replace(函数定义, '''Ubn市'']', '''Ubn市'',''3ty市'']')
--  把城市名加进了 c 数组，但 tick_weather 里【还有六个平行的数值数组】
--  （年均温度 / 季节振幅 / 抖动 / 湿度 / 空气 / 能见度），它们还是 12 个。
--
--  于是 FOR i IN 1..13 跑到第 13 次时：
--      c[13] = '3ty市'   ✓
--      b[13] / w[13] / … = NULL   ✗
--  算出来的温度、空气、能见度全乱了 —— 表现就是 60°C、320 重度污染。
--
--  【教训】往这种「多个平行数组按下标对齐」的函数里加一项，
--  必须【把每个数组都加一项】，只加名字等于把后面全错位。
--  这也是我第五次栽在「按内容改函数」上。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看现在六个数组各有多少项
-- ============================================================
SELECT 'c 城市名' AS 数组, (SELECT count(*) FROM regexp_matches(
           (SELECT pg_get_functiondef(p.oid) FROM pg_proc p
              JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather' LIMIT 1),
           '''(?:[^'']|'''')*''', 'g')) AS 项数;
-- ↑ 上面这个只是粗估（会把所有字符串都算进去），真要准的看第 3 步的结果格子


-- ============================================================
-- 第 2 步：把六个数值数组各补上第 13 项
--   取值和页面 CITIES 里 3ty市 那条对齐：
--       base 24（年均温度）· swing 10（季节振幅）· vol 1.3（抖动）
--       hum 52（基准湿度）· aqi 28（基准空气）· vis 33（基准能见度）
--
--   做法：整段重写 tick_weather，把七个数组都写成 13 项。
--   ⚠️ 不这么做的话，只要哪天再动一次这个函数，还是会错位。
-- ============================================================
DO $$
DECLARE
    r     record;
    v_src text;
    v_new text;
    v_hit integer := 0;
    -- 原始数组（12 项）→ 补上第 13 项
    -- ⚠️ 锚点必须【够长够唯一】。短锚点（比如 '16]'）在别处也会命中，
    --    会把不该改的地方改掉 —— 这种错很难查，所以每个都取了 3~5 个数的尾巴。
    subs  text[][] := ARRAY[
        ['''Ubn市'']',              '''Ubn市'',''3ty市'']'],          -- c 城市名
        ['27,18,16]',               '27,18,16,24]'],                  -- b 年均温度
        ['7,13,12]',                '7,13,12,10]'],                  -- w 季节振幅
        ['.9,1.6,1.3,1.2,1]',       '.9,1.6,1.3,1.2,1,1.3]'],        -- j 抖动
        ['40,60,64]',               '40,60,64,52]'],                 -- h 湿度
        ['30,32,36]',               '30,32,36,28]'],                 -- a 空气
        ['28,25,24]',               '28,25,24,33]']                  -- s 能见度
    ];
    k integer;
BEGIN
    FOR r IN
        SELECT p.oid, pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;

        IF position('3ty市' in v_src) > 0
           AND position('16,24]' in v_src) > 0 THEN
            RAISE NOTICE 'tick_weather 的七个数组看着都已经是 13 项了，跳过';
            CONTINUE;
        END IF;

        v_new := v_src;
        FOR k IN 1..array_length(subs, 1) LOOP
            v_new := replace(v_new, subs[k][1], subs[k][2]);
        END LOOP;

        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_hit := v_hit + 1;
        ELSE
            RAISE NOTICE '⚠️ 一处都没替换上，函数结构和脚本假设的不一样';
        END IF;
    END LOOP;
    RAISE NOTICE '改了 % 个 tick_weather', v_hit;
END $$;


-- ============================================================
-- 第 3 步：把 3ty市 那一行重置回正常值
--   （它已经被 NULL 基准带偏了，得先拉回来）
-- ============================================================
UPDATE public.weather_state
   SET temp_c     = 24.0,
       humidity   = 52.0,
       pressure   = 101.3,
       visibility = 33.0,
       aqi        = 28,
       wind_force = 2.0
 WHERE city = '3ty市';


-- ============================================================
-- 第 4 步：手动推一轮，看 3ty市 有没有回到正常范围
--   正常应该落在：温度 12~36（看季节）、空气 10~60、能见度 20~55
-- ============================================================
SELECT public.tick_weather();

SELECT city AS 城市,
       round(temp_c::numeric, 1)     AS 温度,
       round(humidity::numeric, 0)   AS 湿度,
       round(pressure::numeric, 1)   AS 气压,
       round(visibility::numeric, 0) AS 能见度,
       round(aqi::numeric, 0)        AS 空气,
       round(wind_force::numeric, 1) AS 风力
  FROM public.weather_state ORDER BY city;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 3ty市 应该和其他 12 座在一个量级
--  · 天气页上那根冲天的空气质量柱子会降下来
--  · 每 10 秒 tick 一轮，之后它自己正常游走
--
--  ⚠️ 站长还得去 PythonAnywhere 点一次 Reload —— /api/weather 那边
--     也有城市列表，虽然那边只影响接口不影响页面。
-- ============================================================
