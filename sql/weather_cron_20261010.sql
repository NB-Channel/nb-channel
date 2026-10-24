-- ============================================================
--  天气瞎报 —— 自己一条定时任务（照市值那套，但不挂在它里面）
--
--  【为什么不用上一版的办法】
--  上一版想把 tick_weather 挂进 market_tick_loop。两个问题：
--
--    ① 挂不上
--       我用的锚点假设了具体缩进（12 空格），而 pg_get_functiondef
--       返回的缩进未必是这样；库里跑的也未必就是 sql/market_10s.sql
--       那份（sql/auto_support_backend.sql 里还有一份同名的）。
--       匹配不上时只 RAISE NOTICE 跳过，而 SQL Editor 默认不显示
--       NOTICE —— 所以看起来「什么都没发生」。
--
--    ② 就算挂上了也不对
--       market_tick_loop 里那个 FOR 循环是包在
--           IF v_in_session THEN   -- 北京时间 8:00 ~ 20:00
--       里面的。天气挂进去就会跟着只在交易时段走，
--       过了晚上 8 点就停 —— 和「24 小时都走」的要求不符。
--
--  【这一版】
--  给天气【自己一条定时任务】，照市值那套完全一样的写法：
--      自循环存储过程（6 轮 × pg_sleep(10) = 每 10 秒一轮）
--      + pg_cron 每分钟 CALL 一次
--  不碰 market_tick_loop 一个字。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：自循环存储过程
--   和 market_tick_loop 一样：每轮 COMMIT 释放行锁，然后 sleep 10 秒。
--   不用 IF 包起来 —— 天气 24 小时都走。
-- ============================================================
DROP PROCEDURE IF EXISTS public.weather_tick_loop();

CREATE OR REPLACE PROCEDURE public.weather_tick_loop()
LANGUAGE plpgsql
AS $fn$
DECLARE
    i integer;
BEGIN
    -- 循环总时长约 60 秒，先解除本会话的语句超时限制
    SET statement_timeout = 0;

    FOR i IN 1..6 LOOP
        PERFORM public.tick_weather();
        COMMIT;                     -- 每轮提交，立即释放行锁
        IF i < 6 THEN
            PERFORM pg_sleep(10);   -- 于是实际节奏就是每 10 秒一轮
        END IF;
    END LOOP;
END;
$fn$;

COMMENT ON PROCEDURE public.weather_tick_loop() IS
    '天气瞎报 · 自循环：每 10 秒推进一轮，24 小时不停（由 pg_cron 每分钟唤醒）';

-- 只让 pg_cron 调，前端不碰
REVOKE ALL ON PROCEDURE public.weather_tick_loop() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 第 2 步：注册每分钟任务
-- ============================================================
DO $$
BEGIN
    PERFORM cron.unschedule('weather-10s-tick');
EXCEPTION WHEN OTHERS THEN
    NULL;   -- 本来就没有，忽略
END $$;

SELECT cron.schedule('weather-10s-tick', '* * * * *',
                     'CALL public.weather_tick_loop()');


-- ============================================================
-- 第 3 步：验证
-- ============================================================
-- 3.1 任务注册上了没
SELECT jobid AS 任务号, schedule AS 频率, command AS 命令, active AS 启用
  FROM cron.job
 WHERE jobname = 'weather-10s-tick';

-- 3.2 跑过没有（等一分钟再看这张表）
SELECT status AS 状态,
       to_char(start_time AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI:SS') AS 开始,
       left(COALESCE(return_message, ''), 80) AS 返回
  FROM cron.job_run_details
 WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'weather-10s-tick')
 ORDER BY start_time DESC
 LIMIT 5;

-- 3.3 过程在不在
SELECT p.proname AS 过程,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%tick_weather%'
            THEN '✅ 里面有 tick_weather' ELSE '❌ 里面没有' END AS 内容
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'p'
   AND p.proname = 'weather_tick_loop';


-- ============================================================
-- 第 4 步：立刻确认函数本身没问题（不等定时任务）
-- ============================================================
-- 先看现在的数：
SELECT city AS 城市, temp_c AS 摄氏, aqi AS 空气
  FROM public.weather_state ORDER BY city;

-- 手动推一轮：
SELECT public.tick_weather();

-- 再看一次 —— 数字应该变了（对比上面那份）：
SELECT city AS 城市, temp_c AS 摄氏, aqi AS 空气
  FROM public.weather_state ORDER BY city;


-- ============================================================
--  接下来
-- ============================================================
--  第 4 步如果数字变了 → tick_weather 函数本身没问题。
--  等一分钟看第 3.2 步有没有 status='Succeeded' —— 有就说明自动跑起来了。
--  然后刷新天气页，数字应该每 10 秒自己变。
--
--  ⚠️ 如果第 3.2 步是 status='Failed'，把报错发我。
--     最常见的两种：
--       · "invalid transaction termination" —— pg_cron 不支持过程里 COMMIT，
--         那就改成「每分钟推一轮」（把 FOR 循环去掉、只留一次 tick_weather）
--       · 权限不足 —— 补 GRANT
--
--  ⚠️ 现在这个方案会占【两条】常驻连接（市值一条、天气一条）。
--     Supabase 免费额度一般够（直连 60 条），如果以后紧张，
--     可以把天气那条改成「每两分钟唤醒、内部跑 12 轮」。
-- ============================================================
