-- ============================================================
--  修上一个脚本的报错（42883）
--
--  站长跑 weather_add_mn_no3_2_20261011.sql 时报：
--      ERROR: 42883: function regexp_match(text[], unknown) does not exist
--
--  原因：我第 5 步里那项「七个数组项数是否一致」的检查写错了 ——
--      regexp_matches(…, 'g') 返回的是 setof text[]（数组），
--      我却拿它当 text 传给 regexp_match。
--      而且那一项本来也没什么用（我当时自己都标了「这行只是粗查」）。
--
--  这个脚本做两件事：
--      ① 给一个【真能用】的检查 —— 把七个数组各有多少项打出来
--      ② 说明第 2~4 步（插城市、补数组、推一轮）如果已经跑过就不用再跑
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
--  第 1 步：把「插城市 + 补七个数组」再跑一遍
--    （都是幂等的：城市已在就跳过，数组已补就不动）
--    上一个脚本第 120 行报错，但它第 2~4 步很可能已经执行了 ——
--    这一步是为了「不管跑没跑都不会错」。
-- ============================================================
INSERT INTO public.weather_state
    (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force)
VALUES
    ('Mn(NO3)2市', 20.0, 48.0, 101.3, 36.0, 25, (random() * 15)::smallint, 1 + random() * 2)
ON CONFLICT (city) DO NOTHING;

DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_hit  integer := 0;
    adds   text[][] := ARRAY[
        ['c', '''Mn(NO3)2市'''], ['b', '20'], ['w', '12'], ['j', '1.5'],
        ['h', '48'], ['a', '25'], ['s', '36']
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
            v_pat := '(' || adds[k][1] || '\s+CONSTANT\s+\w+\[\]\s*:=\s*ARRAY\[[^\]]*)(\])';
            v_new := regexp_replace(v_new, v_pat, E'\\1,' || adds[k][2] || E'\\2');
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

SELECT public.tick_weather();


-- ============================================================
--  第 2 步：检查七个数组各几项（这个才是准的）
--
--  做法：把函数定义里每段「ARRAY[ ... ]」抠出来，数逗号个数 + 1。
--      项数应该七个都一样（14）。
-- ============================================================
WITH def AS (
    SELECT pg_get_functiondef(p.oid) AS src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'tick_weather'
     LIMIT 1
),
arrs AS (
    SELECT m[1] AS body
      FROM def, regexp_matches(def.src, 'ARRAY\[([^\]]*)\]', 'g') AS m
),
counted AS (
    SELECT row_number() OVER () AS 序号,
           -- 逗号数 + 1 = 项数（数组里没有嵌套，所以直接数逗号就行）
           (length(body) - length(replace(body, ',', '')) + 1) AS 项数,
           left(btrim(body), 46) AS 开头
      FROM arrs
)
SELECT 序号 AS 第几个数组,
       项数,
       CASE 项数 WHEN 14 THEN '✅' ELSE '⚠️ 应该是 14' END AS 状态,
       开头
  FROM counted
 ORDER BY 序号;


-- ============================================================
--  顺带：确认 Mn(NO3)2市 和 3ty市 都齐了
-- ============================================================
SELECT city AS 城市,
       round(temp_c::numeric, 1)     AS 温度,
       round(humidity::numeric, 0)   AS 湿度,
       round(pressure::numeric, 1)   AS 气压,
       round(visibility::numeric, 0) AS 能见度,
       round(aqi::numeric, 0)        AS 空气,
       round(wind_force::numeric, 1) AS 风力
  FROM public.weather_state
 WHERE city IN ('3ty市', 'Mn(NO3)2市')
 ORDER BY city;

SELECT '城市数' AS 项目,
       (SELECT count(*)::text FROM public.weather_state) AS 值,
       '应为 14' AS 说明
UNION ALL
SELECT 'Mn(NO3)2市 在 tick_weather 里',
       CASE WHEN EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                   AND position('Mn(NO3)2市' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 有' ELSE '❌ 没有' END, ''
UNION ALL
SELECT '3ty市 在 tick_weather 里',
       CASE WHEN EXISTS (
                SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname='public' AND p.prokind='f' AND p.proname='tick_weather'
                   AND position('3ty市' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 有' ELSE '❌ 没有' END, '';


-- ============================================================
--  如果上面「第几个数组」那几行的项数不是 14
-- ============================================================
--  说明第 3 步（补七个数组）没跑成功，把上一个脚本的
--  【第 2 步到第 4 步】再单独跑一遍：
--
--      INSERT INTO public.weather_state (…) VALUES ('Mn(NO3)2市', …)
--          ON CONFLICT (city) DO NOTHING;
--      DO $$ … 补七个数组 … $$;
--      SELECT public.tick_weather();
--
--  第 1 步和第 5 步不用重跑（一个只是看，一个是刚才报错那段）。
-- ============================================================
