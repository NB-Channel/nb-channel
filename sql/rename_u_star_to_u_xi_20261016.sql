-- ============================================================
--  天气瞎报：把「U星」改名成「U系」
--
--  站长说：「把天气瞎报的U星改成U系」
--
--  ── 名字散在几处 ──
--      前端  weather.html / Beta/weather-Beta.html 的 CITIES 数组
--      后端  pythonanywhere/app.py 的 _UV_GEO 系数表
--      数据库 weather_state.city         ← 每座城当前那一条
--            weather_history.city        ← 每 10 分钟采一次的历史
--            tick_weather() 里的城市数组  ← ⚠️ 写死的，不改会插回旧名字
--
--  ⚠️ 顺序很重要：
--      先改 tick_weather()，再改两张表的数据。
--      反过来的话，改完数据、下一次 tick 又按数组插一条「U星」回来。
--      所以这里：
--          第 1 步  改数据
--          第 2 步  改函数（把 ARRAY 里的 'U星' 换成 'U系'）
--          第 3 步  验收
--      两步都在一个事务里，中途出错会一起回滚。
--
--  幂等，可以重复跑。
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状（只查）
-- ============================================================
SELECT 'weather_state' AS 表, count(*) AS 行数
  FROM public.weather_state WHERE city = 'U星'
UNION ALL
SELECT 'weather_history', count(*)
  FROM public.weather_history WHERE city = 'U星'
UNION ALL
SELECT 'weather_state（已有 U系）', count(*)
  FROM public.weather_state WHERE city = 'U系';

-- tick_weather 里有没有 'U星'
SELECT (pg_get_functiondef(p.oid) LIKE '%''U星''%') AS 函数里还有U星,
       (pg_get_functiondef(p.oid) LIKE '%''U系''%') AS 函数里已有U系
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'tick_weather';


-- ============================================================
-- 第 1 步：改数据 + 改函数（一个事务）
-- ============================================================
DO $$
DECLARE
    v_s int := 0;
    v_h int := 0;
    r   record;
    v_src text;
    v_new text;
    v_fn  int := 0;
BEGIN
    -- ---------- ① 改历史表（先改，量大） ----------
    UPDATE public.weather_history
       SET city = 'U系'
     WHERE city = 'U星';
    GET DIAGNOSTICS v_h = ROW_COUNT;

    -- ---------- ② 改当前状态表 ----------
    UPDATE public.weather_state
       SET city = 'U系'
     WHERE city = 'U星';
    GET DIAGNOSTICS v_s = ROW_COUNT;

    RAISE NOTICE '数据改名：weather_state % 行，weather_history % 行', v_s, v_h;

    -- ---------- ③ 改 tick_weather 里的城市数组 ----------
    -- ⚠️ 用 replace 改函数定义再 EXECUTE 回去 —— 不整段重写，
    --    因为那个函数里数组很长，手抄容易抄错。
    --    锚点用带引号的 'U星'，只影响那个字符串字面量。
    FOR r IN
        SELECT pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;
        IF position('''U星''' in v_src) > 0 THEN
            v_new := replace(v_src, '''U星''', '''U系''');
            EXECUTE v_new;
            v_fn := v_fn + 1;
        ELSE
            RAISE NOTICE 'tick_weather 里没有 ''U星'' 了，跳过';
        END IF;
    END LOOP;

    RAISE NOTICE '函数改名：处理了 % 个 tick_weather', v_fn;
END $$;


-- ============================================================
-- 第 2 步：验收
-- ============================================================
-- 2.1 数据里应该已经没有 U星 了
SELECT 'weather_state' AS 表,
       count(*) FILTER (WHERE city = 'U星') AS 还有U星,
       count(*) FILTER (WHERE city = 'U系') AS 已有U系,
       count(*)                            AS 总行数
  FROM public.weather_state
UNION ALL
SELECT 'weather_history',
       count(*) FILTER (WHERE city = 'U星'),
       count(*) FILTER (WHERE city = 'U系'),
       count(*)
  FROM public.weather_history;

-- 2.2 函数里应该也没有了
SELECT (pg_get_functiondef(p.oid) LIKE '%''U星''%') AS 函数里还有U星,
       (pg_get_functiondef(p.oid) LIKE '%''U系''%') AS 函数里已有U系
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'tick_weather';

-- 2.3 看一眼 U系 现在有没有数据（温度、湿度这些）
-- ⚠️ 表里的列名是 temp_c，不是 temperature（我第一版写错了）
SELECT city AS 城市, temp_c AS 温度, humidity AS 湿度,
       pressure AS 气压, aqi AS 空气质量, updated_at AS 更新时间
  FROM public.weather_state
 WHERE city = 'U系';


-- ============================================================
--  跑完之后
-- ============================================================
--  · 数据库里这座城市叫「U系」了
--  · tick_weather 以后也会按「U系」写
--  · ⚠️ 前端还有 3 处要改（不在这脚本里，我另外改）：
--        weather.html / Beta/weather-Beta.html 的 CITIES 数组
--        pythonanywhere/app.py 的 _UV_GEO 系数表
--    只改数据库不改前端的话，页面上还会显示「U星」——
--    因为前端那个数组是写死的显示名，它拿着「U星」去查，查不到数据。
-- ============================================================
