-- ============================================================
--  「U星 → U系」改名 · 第二版（拆开跑，不再一个事务里全包）
--
--  ── 上一版为什么没成 ──
--  站长跑完之后查出来：
--      函数里还有U星 = true
--      函数里已有U系 = false
--  说明改函数那一步压根没执行。
--
--  原因是我把三件事塞进了同一个 DO 块：
--      ① UPDATE weather_history
--      ② UPDATE weather_state
--      ③ replace tick_weather
--  而 weather_state.city 是【主键】—— 如果数据库里已经有一条「U系」
--  （某次 tick 插进去的），②就会主键冲突，整个 DO 块报错回滚，
--  ③就永远轮不到执行。
--
--  ── 这一版怎么改 ──
--  拆成独立的 SQL 语句，每步单独跑，前面失败不影响后面。
--  并且先处理「U星 / U系 两条并存」的情况。
--
--  幂等，可以重复跑。
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步（只查）：U星 / U系 各有几条
-- ============================================================
SELECT 'weather_state' AS 表,
       count(*) FILTER (WHERE city = 'U星') AS U星,
       count(*) FILTER (WHERE city = 'U系') AS U系
  FROM public.weather_state
UNION ALL
SELECT 'weather_history',
       count(*) FILTER (WHERE city = 'U星'),
       count(*) FILTER (WHERE city = 'U系')
  FROM public.weather_history;

-- ⚠️ 如果 U星 和 U系 都是 1（weather_state 里），
--    说明两条并存 —— 第 2 步会把 U星 那条删掉，保留 U系。


-- ============================================================
-- 第 2 步：处理 weather_state（主键是 city，两条不能并存）
--   已经有 U系 了 → 删掉 U星 那条
--   还没有 U系    → 把 U星 改名成 U系
-- ============================================================
DELETE FROM public.weather_state
 WHERE city = 'U星'
   AND EXISTS (SELECT 1 FROM public.weather_state WHERE city = 'U系');

UPDATE public.weather_state
   SET city = 'U系'
 WHERE city = 'U星'
   AND NOT EXISTS (SELECT 1 FROM public.weather_state WHERE city = 'U系');


-- ============================================================
-- 第 3 步：weather_history（没有主键冲突，直接改名）
-- ============================================================
UPDATE public.weather_history
   SET city = 'U系'
 WHERE city = 'U星';


-- ============================================================
-- 第 4 步：改 tick_weather 里的城市数组
--   ⚠️ 这一步单独跑，前面几步成功与否都不影响它
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_n    int := 0;
    v_has  boolean;
BEGIN
    FOR r IN
        SELECT pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;
        v_has := position('''U星''' in v_src) > 0;

        IF NOT v_has THEN
            RAISE NOTICE 'tick_weather 里没有 ''U星'' 了，跳过';
            CONTINUE;
        END IF;

        v_new := replace(v_src, '''U星''', '''U系''');

        IF v_new = v_src THEN
            RAISE NOTICE '⚠️ replace 没改到任何东西 —— 函数里的写法可能不是 ''U星'' 这个字面量';
            CONTINUE;
        END IF;

        EXECUTE v_new;
        v_n := v_n + 1;
        RAISE NOTICE '已改 tick_weather（第 % 个）', v_n;
    END LOOP;

    IF v_n = 0 THEN
        RAISE NOTICE '⚠️ 一处都没改成 —— 看下面第 5 步的诊断';
    END IF;
END $$;


-- ============================================================
-- 第 5 步：如果第 4 步还是没成，这里能看出问题在哪
--   把 tick_weather 定义里含「U」的那几行抠出来看
-- ============================================================
SELECT line
  FROM (
    SELECT unnest(string_to_array(pg_get_functiondef(p.oid), E'\n')) AS line
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'tick_weather'
  ) t
 WHERE line LIKE '%U星%' OR line LIKE '%U系%' OR line LIKE '%ARRAY[%'
 ORDER BY line
 LIMIT 20;

-- ⚠️ 如果上面看到的是 'U星'，但第 4 步说「replace 没改到任何东西」，
--    那说明里面的字面量不是普通的单引号字符串（可能是 E'U星' 之类）。
--    把这几行发我，我按实际写法改。


-- ============================================================
-- 第 6 步：验收
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

SELECT (pg_get_functiondef(p.oid) LIKE '%''U星''%') AS 函数里还有U星,
       (pg_get_functiondef(p.oid) LIKE '%''U系''%') AS 函数里已有U系
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'tick_weather';

-- 期望：函数里还有U星 = false，函数里已有U系 = true


-- ============================================================
--  跑完之后
-- ============================================================
--  · 数据里没有 U星 了
--  · tick_weather 也按 U系 写
--  · ⚠️ 前端三处我已经改好提交了（weather.html / weather-Beta.html / app.py）
--    等 GitHub Pages 构建完，页面上就显示「U系」
-- ============================================================
