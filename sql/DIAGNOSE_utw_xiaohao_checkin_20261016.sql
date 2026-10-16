-- ============================================================
--  Utw小号（2d16ec9f-e598-445a-98ef-ab14314eb240）签到诊断 + 修复
--
--  站长说「还有一个号的签到有问题：Utw小号」。
--
--  ⚠️ 第 1 段是【只查】，先看清它到底哪里不对 —— 跑完把结果发我，
--     我再决定要不要补记录、补多少天（大号那次是「连续 4 天、实际 85」，
--     要补 81 天；这次情况可能不一样）。
--
--  ⚠️ 第 2 段是【修复】，默认【不执行】—— 看清楚第 1 段之后再决定跑不跑。
--     如果第 1 段显示「记录是齐的，只是连续天数没算」，那只要跑第 2 段；
--     如果显示「记录缺了一大段」，那要先把 N 改成实际要恢复的天数。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 段（只查）：现在什么样
-- ============================================================
SELECT p.username                          AS 用户名,
       p.id                                AS user_id,
       u.last_checkin_date                 AS 最后签到日,
       u.consecutive_days                  AS 连续天数,
       (current_date - u.last_checkin_date) AS 距今几天,
       (SELECT count(*) FROM public.check_in_records r
         WHERE r.user_id = p.id)           AS 真实签到总记录,
       (SELECT min(check_in_date) FROM public.check_in_records r
         WHERE r.user_id = p.id)           AS 最早记录,
       (SELECT max(check_in_date) FROM public.check_in_records r
         WHERE r.user_id = p.id)           AS 最晚记录,
       (SELECT count(*) FROM public.check_in_records r
         WHERE r.user_id = p.id
           AND r.check_in_date > current_date - 60) AS 近60天真实签到,
       (SELECT count(*) FROM public.checkin_fix_records f
         WHERE f.user_id = p.id)           AS 补签次数
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.id = '2d16ec9f-e598-445a-98ef-ab14314eb240';


-- 最近 45 天的日历：✓ = 真实签到   ● = 补签   · = 没有
-- ⚠️ 从左到右是【45 天前 → 今天】，一串 ✓ 中间突然出现 · 就是断签那天
WITH days AS (
    SELECT generate_series(current_date - 44, current_date, interval '1 day')::date AS d
)
SELECT to_char(days.d, 'MM-DD') AS 日期,
       CASE
         WHEN EXISTS (SELECT 1 FROM public.check_in_records r
                       WHERE r.user_id = '2d16ec9f-e598-445a-98ef-ab14314eb240'
                         AND r.check_in_date = days.d) THEN '✓ 真实'
         WHEN EXISTS (SELECT 1 FROM public.checkin_fix_records f
                       WHERE f.user_id = '2d16ec9f-e598-445a-98ef-ab14314eb240'
                         AND f.check_in_date = days.d) THEN '● 补签'
         ELSE '·'
       END AS 状态
  FROM days ORDER BY days.d;


-- 补签记录明细
SELECT check_in_date AS 补签日, created_at AS 补签时间
  FROM public.checkin_fix_records
 WHERE user_id = '2d16ec9f-e598-445a-98ef-ab14314eb240'
 ORDER BY check_in_date DESC;


-- 对照：从最后签到日往前数，实际能连多少天（这个数就是「如果记录齐全，
-- 连续天数应该是多少」）
DO $$
DECLARE
    v_uid   uuid := '2d16ec9f-e598-445a-98ef-ab14314eb240';
    v_start date;
    v_idx   int := 0;
    v_n     int := 0;
BEGIN
    SELECT greatest(
             coalesce((SELECT max(check_in_date) FROM public.check_in_records WHERE user_id = v_uid), current_date),
             coalesce((SELECT max(check_in_date) FROM public.checkin_fix_records WHERE user_id = v_uid), current_date)
           ) INTO v_start;
    WHILE v_idx <= 400 LOOP
        IF EXISTS (SELECT 1 FROM public.check_in_records
                    WHERE user_id = v_uid AND check_in_date = v_start - v_idx)
           OR EXISTS (SELECT 1 FROM public.checkin_fix_records
                       WHERE user_id = v_uid AND check_in_date = v_start - v_idx) THEN
            v_n := v_n + 1;
            v_idx := v_idx + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    RAISE NOTICE '从 % 往前，实际连续 % 天', v_start, v_n;
END $$;


-- ============================================================
-- 第 2 段（修复）：⚠️ 看清楚第 1 段再决定跑不跑
-- ============================================================
-- 两种情况，对应两种修法：
--
--   【情况 A】记录是齐的，只是连续天数被算小了（比如显示 4、实际连着 30 天）
--            → 只跑下面这段（重算），不用补记录
--
--   【情况 B】记录缺了一大段（比如显示 4、但他其实连着签到 30 天，
--            只是那 30 天的记录压根没落库）
--            → 先把 N 改成实际要恢复的天数，跑 A-1 补记录，再跑 A-2 重算
--
-- ⚠️ N 默认写的 30 —— 这只是占位，别直接跑，先看第 1 段再定。

-- ---- A-1 补记录（情况 B 才需要；情况 A 跳过这段）----
-- 从「最后签到日」往前推 N-1 天，已有的日期自动跳过，不会重复插。
-- DO $$
-- DECLARE
--     v_uid uuid := '2d16ec9f-e598-445a-98ef-ab14314eb240';
--     v_n   int  := 30;          -- ⚠️ 改成实际要恢复的连续天数
--     v_end date;
-- BEGIN
--     SELECT coalesce(last_checkin_date, (now() AT TIME ZONE 'Asia/Shanghai')::date)
--       INTO v_end FROM public.user_checkins WHERE user_id = v_uid;
--     INSERT INTO public.check_in_records (user_id, check_in_date)
--     SELECT v_uid, v_end - gs FROM generate_series(0, v_n - 1) AS gs
--     ON CONFLICT (user_id, check_in_date) DO NOTHING;
--     RAISE NOTICE '补齐完成：从 % 往前 % 天', v_end, v_n;
-- END $$;

-- ---- A-2 重算连续天数（情况 A 和 B 都要跑）----
DO $$
DECLARE
    v_uid uuid := '2d16ec9f-e598-445a-98ef-ab14314eb240';
    v_n   int;
BEGIN
    v_n := public.recalc_checkin_streak(v_uid);
    UPDATE public.user_checkins
       SET consecutive_days = GREATEST(coalesce(consecutive_days, 0), v_n)
     WHERE user_id = v_uid;
    IF NOT FOUND THEN
        INSERT INTO public.user_checkins (user_id, last_checkin_date, consecutive_days)
        VALUES (v_uid, (now() AT TIME ZONE 'Asia/Shanghai')::date, v_n);
    END IF;
    RAISE NOTICE '重算后连续 % 天', v_n;
END $$;


-- ============================================================
-- 第 3 段：验收
-- ============================================================
SELECT p.username AS 用户名, u.last_checkin_date AS 最后签到,
       u.consecutive_days AS 连续天数,
       (SELECT count(*) FROM public.check_in_records r WHERE r.user_id = p.id) AS 记录数
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.id = '2d16ec9f-e598-445a-98ef-ab14314eb240';


-- ============================================================
--  跑完把第 1 段的结果发我
-- ============================================================
--  我要看三件事：
--    ① 连续天数现在多少
--    ② 真实签到记录多少条、最早最晚是哪天
--    ③ 最近 45 天的日历里，断在哪天
--
--  然后我告诉你：是只要重算（情况 A），还是得先补记录（情况 B）、补几天。
-- ============================================================
