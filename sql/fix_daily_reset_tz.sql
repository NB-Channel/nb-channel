-- ============================================================
-- 修复:每日重置时间慢 8 小时(转盘次数 / 抽奖券日期口径不一致)
--
-- 症状:用户反馈"签到·转盘每天要等到早上 8 点才重置"。
--
-- 根因:shop.sql 里 get_lottery_today 和 do_lottery【同一个函数里两种口径】:
--     -- 抽奖券加成:用北京时间 ✓
--     AND settings->>'lottery_date' = (now() AT TIME ZONE 'Asia/Shanghai')::date::text;
--     -- 今日已抽次数:用 UTC 日期 ✗
--     WHERE user_id = p_user_id AND created_at::date = current_date;
--
--   created_at 是 timestamptz,::date 会按【数据库时区(UTC)】切,
--   所以"今天"的边界落在北京时间早上 8 点。
--   于是北京 0:00~8:00 之间:券判定已经是"今天",次数却还在数昨天 →
--   每天要等到 8 点才重置。
--
--   注:签到本身是对的 —— do_check_in 里用的是
--       v_today := (now() AT TIME ZONE 'Asia/Shanghai')::date
--       所以签到在北京 0 点整重置 ✓ 受影响的是同一页的「转盘每日次数」。
--
-- 修法:用 pg_get_functiondef 取出线上真实定义,只替换那一处表达式。
--   不手抄函数体 —— do_lottery / get_lottery_today 在 lottery.sql 与
--   shop.sql 里各有版本,且 do_lottery 还被令牌包装过(线上是
--   do_lottery(uuid,text) → _orig_do_lottery(uuid)),手抄必漏。
--
-- 在 Supabase SQL Editor 执行(幂等,可重复跑)
-- ============================================================

DO $$
DECLARE
    r      record;
    v_def  text;
    v_new  text;
    v_cnt  int := 0;
    v_pat  text := 'created_at\s*::\s*date\s*=\s*current_date';
    v_rep  text := '(created_at AT TIME ZONE ''Asia/Shanghai'')::date'
                || ' = (now() AT TIME ZONE ''Asia/Shanghai'')::date';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           -- 必须过滤 prokind = 'f':pg_get_functiondef 对聚合函数会直接报错
           AND p.prokind = 'f'
           AND pg_get_functiondef(p.oid) ~ v_pat
         ORDER BY p.proname
    LOOP
        v_def := pg_get_functiondef(r.oid);
        v_new := regexp_replace(v_def, v_pat, v_rep, 'g');
        IF v_new <> v_def THEN
            BEGIN
                EXECUTE v_new;
                v_cnt := v_cnt + 1;
                RAISE NOTICE '✅ 已修正 % 的每日重置口径', r.proname;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '⚠️ % 替换失败: %', r.proname, SQLERRM;
            END;
        END IF;
    END LOOP;

    IF v_cnt = 0 THEN
        RAISE NOTICE 'ℹ️ 没有需要修正的函数(可能已经改过)';
    ELSE
        RAISE NOTICE '共修正 % 个函数', v_cnt;
    END IF;
END $$;


-- ============================================================
-- 顺手:前端访问计数也用 UTC 日期(同类问题,影响小但一并说明)
-- ============================================================
-- profile-Beta.html 里:
--   var visitKey = 'nb_visit_' + viewUid + '_' + new Date().toISOString().slice(0, 10);
-- toISOString() 是 UTC,所以"同一访客每天只记一次"的分界点也落在北京 8 点。
-- 这只影响主页访问量的计数(会多记一次),不影响数据正确性,已在同一批前端改动里修。


-- ============================================================
-- 验收 1:还有没有函数在用 UTC 日期做"今天"的判断(应返回 0 行)
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND pg_get_functiondef(p.oid) ~ 'created_at\s*::\s*date\s*=\s*current_date'
 ORDER BY 1;
-- 期望:0 行。还有行的话就是有版本没被替换到,把函数名贴我。


-- ============================================================
-- 验收 2:确认 do_lottery / get_lottery_today 现在用的是北京时间
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%Asia/Shanghai%') AS 已用北京时间,
       (pg_get_functiondef(p.oid) LIKE '%= current_date%') AS 仍含UTC日期
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname IN ('do_lottery', 'get_lottery_today', '_orig_do_lottery')
 ORDER BY 1;
-- 期望:已用北京时间 = true,仍含UTC日期 = false
