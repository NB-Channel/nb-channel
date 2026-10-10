-- ============================================================
--  天气历史采样 · 改用独立 cron（修上一版没生效的问题）
--
--  【上一版为什么没采到数据】
--  上一版想把 sample_weather_history() 挂进 tick_weather()，
--  锚点是在函数定义里找 "RETURN;" 然后插一行。
--  但 plpgsql 允许函数体直接结束、【不写 RETURN;】——
--  如果 tick_weather 是这样写的，锚点就命不中，
--  DO 块只会 RAISE NOTICE 报一句「找不到 RETURN;」（而 SQL Editor
--  默认不显示 NOTICE），于是看起来「跑成功了」，实际一行都没插进去。
--
--  实测：weather_history 里 0 条，而 get_weather() 的 updated_at
--  每 10 秒都在变 —— 说明 tick_weather 本身在跑，只是采样没被调到。
--
--  【这一版】
--  不再改任何函数，直接用 pg_cron 每 10 分钟调一次采样函数。
--  好处：不依赖函数内部长什么样，也不会因为以后重定义 tick_weather
--        而把挂接弄丢。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：把上一版可能插进去的那行清掉（有就清，没有也无所谓）
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_fix  int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND p.proname = 'tick_weather'
    LOOP
        v_src := r.def;
        IF position('sample_weather_history' in v_src) = 0 THEN
            CONTINUE;                       -- 没插进去过
        END IF;
        v_new := replace(v_src,
            E'PERFORM public.sample_weather_history();   -- 顺带做历史采样\n    ',
            '');
        v_new := replace(v_new, 'PERFORM public.sample_weather_history();', '');
        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_fix := v_fix + 1;
        END IF;
    END LOOP;
    RAISE NOTICE '清掉 % 处旧挂接', v_fix;
END $$;


-- ============================================================
-- 第 2 步：重建采样函数
--   ⚠️ 必须先 DROP —— 上一版建的是 RETURNS void，这一版改成 RETURNS integer，
--      而 CREATE OR REPLACE 只有在【参数和返回类型都相同】时才能替换，
--      否则会报 42P13: cannot change return type of existing function。
-- ============================================================
DROP FUNCTION IF EXISTS public.sample_weather_history();

CREATE OR REPLACE FUNCTION public.sample_weather_history()
RETURNS integer                       -- 改成返回「这次写了几行」，方便手动调时看结果
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_last   timestamptz;
    v_force  boolean := false;
    v_n      integer := 0;
BEGIN
    SELECT (value)::timestamptz INTO v_last
      FROM public.market_meta WHERE key = 'last_weather_sample';

    -- 手动调用时想立刻采一次：SET LOCAL nb_force_sample = 'on';
    BEGIN
        v_force := current_setting('nb_force_sample') = 'on';
    EXCEPTION WHEN OTHERS THEN
        v_force := false;
    END;

    IF NOT v_force AND v_last IS NOT NULL AND now() - v_last < interval '9 minutes' THEN
        RETURN 0;                         -- 距上次不到 9 分钟，跳过
    END IF;

    INSERT INTO public.weather_history
        (city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force, at)
    SELECT city, temp_c, humidity, pressure, visibility, aqi, wind_dir, wind_force, now()
      FROM public.weather_state;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    INSERT INTO public.market_meta (key, value)
    VALUES ('last_weather_sample', now()::text)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    DELETE FROM public.weather_history WHERE at < now() - interval '7 days';

    RETURN v_n;
END;
$fn$;

COMMENT ON FUNCTION public.sample_weather_history() IS
    '天气瞎报 · 把 weather_state 快照进 weather_history（每 10 分钟一次，保留 7 天），返回写入行数';


-- ============================================================
-- 第 3 步：注册 cron（每 10 分钟一次）
-- ============================================================
DO $$
BEGIN
    PERFORM cron.unschedule('weather-history-sample');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

SELECT cron.schedule('weather-history-sample', '*/10 * * * *',
                     'SELECT public.sample_weather_history()');


-- ============================================================
-- 第 4 步：立刻手动采一次（不用等 10 分钟）
-- ============================================================
SELECT public.sample_weather_history() AS 本次写入行数;


-- ============================================================
-- 第 5 步：验证（结果格子直接看，不靠 NOTICE）
-- ============================================================
-- 5.1 cron 注册上了没
SELECT jobid AS 任务号, schedule AS 频率, command AS 命令, active AS 启用
  FROM cron.job WHERE jobname = 'weather-history-sample';

-- 5.2 跑过没有（过一两分钟再看这张表）
SELECT status AS 状态,
       to_char(start_time AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI:SS') AS 开始,
       left(COALESCE(return_message, ''), 70) AS 返回
  FROM cron.job_run_details
 WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'weather-history-sample')
 ORDER BY start_time DESC LIMIT 5;

-- 5.3 历史表里现在有多少
SELECT count(*) AS 总条数,
       count(DISTINCT city) AS 城市数,
       COALESCE(to_char(min(at) AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'), '（空）') AS 最早,
       COALESCE(to_char(max(at) AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'), '（空）') AS 最新
  FROM public.weather_history;

-- 5.4 每座城各有多少条（应该都是同一个数）
SELECT city AS 城市, count(*) AS 条数
  FROM public.weather_history GROUP BY city ORDER BY city;


-- ============================================================
--  接下来
-- ============================================================
--  第 4 步应该返回 12（12 座城各写一行）。
--  如果返回 0，说明距上次采样不到 9 分钟 —— 等一会儿再调，
--  或者先手动把 market_meta 里的 last_weather_sample 删掉：
--      DELETE FROM public.market_meta WHERE key = 'last_weather_sample';
--
--  之后天气页的温度曲线会：
--      点数 < 6   → 显示模型推算
--      点数 >= 6  → 自动切成「实际记录 · N 个采样」
--  每 10 分钟多一个点，攒满 24 小时需要一天。
-- ============================================================
