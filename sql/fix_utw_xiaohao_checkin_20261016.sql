-- ============================================================
--  修 Utw小号的签到：补 10 天记录 + 重算连续天数
--
--  站长说这个小号的签到有问题，给的目标是【连续 10 天】。
--
--  ── 诊断结果 ──
--      user_id     2d16ec9f-e598-445a-98ef-ab14314eb240
--      最后签到日   2026-10-16（今天）
--      连续天数     2
--      真实签到记录 0 条  ← ⚠️ 一条都没有
--      补签次数     1（2026-10-14）
--      注册时间     2026-08-22（到今天第 56 天）
--
--  ── 病因 ──
--      do_check_in 有一段时间没写 check_in_records（签到历史）。
--      这个大号、Veo 都中过招，这个小号也一样 ——
--      它一直在签到（last_checkin_date 都到今天了），
--      但签到历史【一条都没存下来】。
--
--      「连续天数 2」是 do_check_in 按 last_checkin_date 递推出来的，
--      和签到历史对不上。
--
--      ✅ do_check_in 上一轮已经修好了（sql/pre_lock_user_rpcs_fixes_20261016.sql），
--         以后签到会正常落库。现在只要把缺的历史补回来。
--
--  ── 做什么 ──
--      ① 从「最后签到日」往前补 10 天（含当天）
--         已有的日期自动跳过，不会重复插
--      ② 重算连续天数
--      ③ 验收
--
--  ⚠️ 为什么是 10：历史全丢了，数据库里没有任何依据能反推实际连着签了几天，
--     所以这个数只能由站长给。他给的是 10。
--
--  幂等，可以重复跑。
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：改之前先记一下
-- ============================================================
SELECT p.username AS 用户名, u.last_checkin_date AS 最后签到,
       u.consecutive_days AS 改前连续天数,
       (SELECT count(*) FROM public.check_in_records r WHERE r.user_id = p.id) AS 改前记录数
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.id = '2d16ec9f-e598-445a-98ef-ab14314eb240';


-- ============================================================
-- 第 1 步：补 10 天签到记录
--   从「最后签到日」往前推 9 天（含当天共 10 天）。
--   ⚠️ 用库里的 last_checkin_date，不写死日期 ——
--      万一是隔天跑的，起点自动跟着走。
-- ============================================================
DO $$
DECLARE
    v_uid uuid := '2d16ec9f-e598-445a-98ef-ab14314eb240';
    v_end date;
    v_n   int  := 10;          -- 要恢复的连续天数
    v_ins int;
BEGIN
    -- 起点：库里的最后签到日；万一没有，用今天
    SELECT coalesce(u.last_checkin_date, (now() AT TIME ZONE 'Asia/Shanghai')::date)
      INTO v_end
      FROM public.user_checkins u
     WHERE u.user_id = v_uid;

    IF v_end IS NULL THEN
        v_end := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    END IF;

    INSERT INTO public.check_in_records (user_id, check_in_date)
    SELECT v_uid, v_end - gs
      FROM generate_series(0, v_n - 1) AS gs
    ON CONFLICT (user_id, check_in_date) DO NOTHING;

    GET DIAGNOSTICS v_ins = ROW_COUNT;
    RAISE NOTICE '补签到记录：从 % 往前 % 天，新插入 % 行（已有的自动跳过）',
                 v_end, v_n, v_ins;
END $$;


-- ============================================================
-- 第 2 步：重算连续天数
--   ⚠️ 是【重算】，不是把 10 写死 —— 靠第 1 步补的记录算出来。
--      算出来不是 10 就说明记录没补够，看第 3 步。
-- ============================================================
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
    RAISE NOTICE '重算后连续 % 天（期望 10）', v_n;
END $$;


-- ============================================================
-- 第 3 步：验收
-- ============================================================
-- 3.1 期望：连续天数 10、记录数 10
SELECT p.username AS 用户名, u.last_checkin_date AS 最后签到,
       u.consecutive_days AS 连续天数,
       (SELECT count(*) FROM public.check_in_records r WHERE r.user_id = p.id) AS 真实签到记录数,
       (SELECT min(check_in_date) FROM public.check_in_records r WHERE r.user_id = p.id) AS 最早,
       (SELECT max(check_in_date) FROM public.check_in_records r WHERE r.user_id = p.id) AS 最晚
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.id = '2d16ec9f-e598-445a-98ef-ab14314eb240';

-- 3.2 最近 15 天日历（应该是一串 ✓ 连着到今天）
WITH days AS (
    SELECT generate_series(current_date - 14, current_date, interval '1 day')::date AS d
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


-- ============================================================
--  跑完之后
-- ============================================================
--  · Utw小号 应该是连续 10 天、10 条签到记录
--  · 以后再签到时 do_check_in 会正常写历史（上一轮修好的）
--  · 它那张补签卡（补的 10-14）现在那条日期也有真实记录了 ——
--    不影响什么，就是热力图上那天会亮起来
--
--  ⚠️ 如果 3.1 里不是 10：
--      看 3.1 的记录数是不是 10。不够就是第 1 步没插进去，把结果发我。
-- ============================================================
