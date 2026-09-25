-- ============================================================
-- 恢复被算坏的连续签到天数(以用户 Utw 为例)
--
-- 背景:
--   补签函数原来只从「补签日」往前数,又漏算补签记录,还会直接覆盖原值
--   → 连续 69 天被写成 29。
--   修好算法后自动重算也只能恢复到 32,因为 do_check_in 有一段时间
--   没写 check_in_records(签到历史),数据库里根本没那 37 天的记录。
--
-- 所以恢复要两步:① 把缺失的历史记录补回来 ② 重算连续天数
--
-- 在 Supabase SQL Editor 执行(按顺序)
-- ============================================================

-- ============================================================
-- 第 0 步:先看他现在的记录长什么样(判断是不是"最近连续 N 天")
-- ============================================================
SELECT count(*) AS 现有记录数,
       min(check_in_date) AS 最早记录,
       max(check_in_date) AS 最晚记录,
       count(*) FILTER (WHERE check_in_date > current_date - 60) AS 近60天记录数
  FROM public.check_in_records
 WHERE user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888';

-- 最近 40 天的签到日(有断档会很明显)
SELECT check_in_date AS 签到日
  FROM public.check_in_records
 WHERE user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888'
   AND check_in_date > current_date - 40
 ORDER BY check_in_date DESC;

-- 他补签过几次
SELECT check_in_date AS 补签日 FROM public.checkin_fix_records
 WHERE user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888'
 ORDER BY check_in_date DESC;


-- ============================================================
-- 第 1 步:补齐 69 天的签到记录
-- ============================================================
-- 从「他最后一次签到那天」往前推 68 天(含当天共 69 天),
-- 已经存在的日期会自动跳过,不会重复插入。
-- 想恢复成 70 天就把 68 改成 69。
INSERT INTO public.check_in_records (user_id, check_in_date)
SELECT u.user_id, u.last_checkin_date - gs
  FROM public.user_checkins u
 CROSS JOIN generate_series(0, 68) AS gs
 WHERE u.user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888'
ON CONFLICT (user_id, check_in_date) DO NOTHING;


-- ============================================================
-- 第 2 步:重算连续天数并写回
-- ============================================================
DO $$
DECLARE
    v_n int;
BEGIN
    v_n := public.recalc_checkin_streak('ea24ed9e-6584-4d8b-84b6-36f594200888');
    UPDATE public.user_checkins
       SET consecutive_days = v_n
     WHERE user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888';
    RAISE NOTICE '✅ 连续签到天数已恢复为 % 天', v_n;
END $$;


-- ============================================================
-- 第 3 步:确认结果
-- ============================================================
SELECT u.user_id, p.username, u.last_checkin_date AS 最后签到, u.consecutive_days AS 连续天数
  FROM public.user_checkins u
  LEFT JOIN public.profiles p ON p.id = u.user_id
 WHERE u.user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888';


-- ============================================================
-- 备用:如果他的历史记录缺得太乱、补齐后仍不对,直接手工指定
-- ============================================================
-- UPDATE public.user_checkins SET consecutive_days = 69
--  WHERE user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888';


-- ============================================================
-- 排查:还有哪些用户也受过影响(记录数明显少于连续天数的)
-- ============================================================
SELECT u.user_id,
       p.username,
       u.consecutive_days AS 连续天数,
       (SELECT count(*) FROM public.check_in_records c WHERE c.user_id = u.user_id) AS 历史记录数,
       u.last_checkin_date AS 最后签到
  FROM public.user_checkins u
  LEFT JOIN public.profiles p ON p.id = u.user_id
 WHERE u.consecutive_days > 3
 ORDER BY u.consecutive_days DESC
 LIMIT 20;
