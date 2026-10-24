-- ============================================================
--  「U星 → U系」改名 —— 只查结果的验收脚本
--
--  上一个脚本（rename_u_star_to_u_xi_20261016.sql）最后一段
--  我把字段名写错了（写成 temperature，实际是 temp_c），
--  所以那一段报错。
--
--  ⚠️ 但前面几步应该是跑过了 —— Supabase 的 SQL Editor 是一条一条执行的。
--     这个脚本就是确认一下：改名到底成没成。
--
--  只查不改。
-- ============================================================


-- ============================================================
-- 1. 数据里还有没有 U星
--    期望：还有U星 = 0，已有U系 = 1（weather_state）
--          weather_history 的已有U系 应该有很多（每 10 分钟一条）
-- ============================================================
SELECT 'weather_state' AS 表,
       count(*) FILTER (WHERE city = 'U星') AS 还有U星,
       count(*) FILTER (WHERE city = 'U系') AS 已有U系,
       count(*)                             AS 总行数
  FROM public.weather_state
UNION ALL
SELECT 'weather_history',
       count(*) FILTER (WHERE city = 'U星'),
       count(*) FILTER (WHERE city = 'U系'),
       count(*)
  FROM public.weather_history;


-- ============================================================
-- 2. tick_weather 里还有没有 'U星'
--    期望：函数里还有U星 = false
-- ============================================================
SELECT (pg_get_functiondef(p.oid) LIKE '%''U星''%') AS 函数里还有U星,
       (pg_get_functiondef(p.oid) LIKE '%''U系''%') AS 函数里已有U系
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'tick_weather';


-- ============================================================
-- 3. U系 现在有没有数据（列名是 temp_c，不是 temperature）
-- ============================================================
SELECT city     AS 城市,
       temp_c   AS 温度,
       humidity AS 湿度,
       pressure AS 气压,
       aqi      AS 空气质量,
       updated_at AS 更新时间
  FROM public.weather_state
 WHERE city = 'U系';


-- ============================================================
-- 4. 顺手确认前端那三处也改好了（这些在代码里，不在库里）
--    ⚠️ 这条查不出来 —— 但我已经改过并提交了：
--        weather.html / Beta/weather-Beta.html 的 CITIES
--        pythonanywhere/app.py 的 _UV_GEO
--    等 GitHub Pages 构建完，页面上就会显示「U系」。
-- ============================================================


-- ============================================================
--  看结果按这个判断
-- ============================================================
--  · 1 里「还有U星」全是 0，且「已有U系」不是 0  →  改成功了 ✓
--  · 2 里「函数里还有U星」= false                  →  函数也改好了 ✓
--  · 3 能查出一行（温度湿度这些有数）               →  数据是活的 ✓
--
--  ⚠️ 如果 1 里「还有U星」不是 0，说明那个 DO 块没跑成 ——
--     把上一个脚本再跑一遍就行（它是幂等的）。
--  ⚠️ 如果 2 里「函数里还有U星」= true，说明 replace 那步没执行 ——
--     同样再跑一遍。
-- ============================================================
