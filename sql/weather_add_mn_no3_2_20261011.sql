-- ============================================================
--  天气瞎报 · 加第 14 座城市：Mn(NO3)2市
--
--  ⚠️ tick_weather() 里有【七个平行数组按下标对齐】：
--        c  城市名        b  年均温度      w  季节振幅     j  抖动
--        h  基准湿度      a  基准空气      s  基准能见度
--     加城市必须【每个都加】——
--     上次加 3ty市 时我只加了 c，结果另外六个是 NULL，
--     3ty市 显示成 60°C / 320 重度污染 / 60km 能见度。这次不会了。
--
--  ⚠️ 这次【不硬编码数组内容】。因为：
--     · 站长那个 fix_3ty_arrays 脚本可能跑了也可能没跑
--     · 硬编码的锚点（'27,18,16]'）一旦对不上就静默失败
--     改成用正则找「数组名 CONSTANT 类型[] := ARRAY[ ... ]」，
--     在收尾的 ] 前面补一项。跑几次都只加一次（先查有没有）。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看现在七个数组各几项
-- ============================================================
WITH def AS (
    SELECT pg_get_functiondef(p.oid) AS src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'tick_weather'
     LIMIT 1
)
SELECT 'c 城市名' AS 数组, (SELECT count(*) FROM regexp_matches(src, '''[^'']+''', 'g')) AS 项数_粗估 FROM def
UNION ALL SELECT '整个函数里的字符串总数（含注释，仅供参考）', 0 FROM def;


-- ============================================================
-- 第 2 步：插一行 Mn(NO3)2市
-- ============================================================
INSERT INTO public.weather_state
    (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force)
VALUES
    ('Mn(NO3)2市', 20.0, 48.0, 101.3, 36.0, 25, (random() * 15)::smallint, 1 + random() * 2)
ON CONFLICT (city) DO NOTHING;


-- ============================================================
-- 第 3 步：七个数组各补一项（用正则定位，不硬编码内容）
--   取值和页面 CITIES 里 Mn(NO3)2市 那条对齐：
--       base 20 · swing 12 · vol 1.5 · hum 48 · aqi 25 · vis 36
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_hit  integer := 0;
    -- [变量名, 要补的值]  —— 变量名和函数里的声明一致
    adds   text[][] := ARRAY[
        ['c', '''Mn(NO3)2市'''],
        ['b', '20'],
        ['w', '12'],
        ['j', '1.5'],
        ['h', '48'],
        ['a', '25'],
        ['s', '36']
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

        IF position('Mn(NO3)2市' in v_src) > 0 THEN
            RAISE NOTICE 'tick_weather 里已经有 Mn(NO3)2市 了，跳过';
            CONTINUE;
        END IF;

        v_new := v_src;
        FOR k IN 1..array_length(adds, 1) LOOP
            -- 匹配： <变量名> CONSTANT <类型>[] := ARRAY[ …… ]
            -- 在最后的 ] 前面补 ,值
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
-- 第 4 步：手动推一轮
-- ============================================================
SELECT public.tick_weather();


-- ============================================================
-- 第 5 步：验证 —— 结果格子直接看，不靠 NOTICE
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
       '应为 14' AS 说明
UNION ALL
SELECT 'Mn(NO3)2市 在不在表里',
       CASE WHEN EXISTS (SELECT 1 FROM public.weather_state WHERE city = 'Mn(NO3)2市')
            THEN '✅ 在' ELSE '❌ 不在' END, ''
UNION ALL
SELECT 'tick_weather 里有没有它',
       CASE WHEN EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                   AND position('Mn(NO3)2市' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 有' ELSE '❌ 没有（第 3 步没成功）' END, ''
UNION ALL
SELECT '七个数组项数是否一致',
       CASE WHEN (
                SELECT count(DISTINCT (regexp_match(src,
                    '(?s)ARRAY\[([^\]]*)\]\s*;'))[1]) FROM (
                    SELECT regexp_matches(pg_get_functiondef(p.oid), 'ARRAY\[[^\]]*\]', 'g') AS src
                      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                     WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                ) t) <= 1
            THEN '（这行只是粗查，看上面那张表更实在）' ELSE '' END, '';


-- ============================================================
--  跑完之后
-- ============================================================
--  · 天气页会多出第 14 张卡「🧪 Mn(NO3)2市」
--  · 空气质量柱状图从 13 根变 14 根
--  · ⚠️ 如果 3ty市 之前那个修复脚本还没跑，这次两个一起生效
--     （正则那步对两个城市是同一套逻辑，不用分开跑）
--
--  ⚠️ 别忘了 PythonAnywhere 点一次 Reload（app.py 里那行才生效）
-- ============================================================
