-- ============================================================
--  第 1 步（只读）：看 Utw / Veo 的签到现状
--
--  站长反馈：「补签完只有签到天数+1，把大号85、小号10还一下」
--      大号 = Utw
--      小号 = Veo
--
--  ⚠️ 这个脚本【一个字都不改】，只把现状列出来。
--     先看结果，确认无误再跑第 2 步（修 bug）和第 3 步（恢复天数）。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================

-- ============================================================
-- 1. 两个号的连续天数 / 最后签到日
-- ============================================================
SELECT p.username                        AS 用户名,
       p.id                              AS user_id,
       c.last_checkin_date               AS 最后签到日,
       c.consecutive_days                AS 连续天数,
       (current_date - c.last_checkin_date) AS 距今几天
  FROM public.profiles p
  LEFT JOIN public.user_checkins c ON c.user_id = p.id
 WHERE p.id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',   -- Utw
                '633685cd-57c3-4659-a588-5915af9d5136')   -- Veo
 ORDER BY p.username;


-- ============================================================
-- 2. 真实签到记录：各有几天、最早最晚
-- ============================================================
SELECT p.username                                        AS 用户名,
       count(*)                                          AS 真实签到记录数,
       min(r.check_in_date)                              AS 最早,
       max(r.check_in_date)                              AS 最晚,
       count(*) FILTER (WHERE r.check_in_date > current_date - 60) AS 近60天
  FROM public.profiles p
  LEFT JOIN public.check_in_records r ON r.user_id = p.id
 WHERE p.id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',
                '633685cd-57c3-4659-a588-5915af9d5136')
 GROUP BY p.username
 ORDER BY p.username;


-- ============================================================
-- 3. 补签记录：补过几次、补的哪几天
-- ============================================================
SELECT p.username        AS 用户名,
       f.check_in_date   AS 补签日,
       f.created_at      AS 补签时间
  FROM public.profiles p
  LEFT JOIN public.checkin_fix_records f ON f.user_id = p.id
 WHERE p.id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',
                '633685cd-57c3-4659-a588-5915af9d5136')
 ORDER BY p.username, f.check_in_date DESC;


-- ============================================================
-- 4. 最近 40 天的签到日历（看一眼断在哪儿）
--    ✓ = 真实签到    ● = 补签    · = 没有
-- ============================================================
WITH days AS (
    SELECT generate_series(current_date - 39, current_date, interval '1 day')::date AS d
),
who AS (
    SELECT 'ea24ed9e-6584-4d8b-84b6-36f594200888'::uuid AS uid, 'Utw' AS name
    UNION ALL
    SELECT '633685cd-57c3-4659-a588-5915af9d5136'::uuid, 'Veo'
)
SELECT w.name AS 用户名,
       to_char(days.d, 'MM-DD') AS 日期,
       CASE
           WHEN EXISTS (SELECT 1 FROM public.check_in_records r
                         WHERE r.user_id = w.uid AND r.check_in_date = days.d) THEN '✓ 真实'
           WHEN EXISTS (SELECT 1 FROM public.checkin_fix_records f
                         WHERE f.user_id = w.uid AND f.check_in_date = days.d) THEN '● 补签'
           ELSE '·'
       END AS 状态
  FROM who w CROSS JOIN days
 ORDER BY w.name, days.d DESC;


-- ============================================================
-- 5. 按现在的算法「从今天往前数」能数出多少天
--    （顺便看和库里存的 consecutive_days 差多少）
--    ⚠️ 这只是参考值，第 3 步恢复时会用更准的算法
-- ============================================================
WITH who AS (
    SELECT 'ea24ed9e-6584-4d8b-84b6-36f594200888'::uuid AS uid, 'Utw' AS name
    UNION ALL
    SELECT '633685cd-57c3-4659-a588-5915af9d5136'::uuid, 'Veo'
),
cnt AS (
    SELECT w.uid, w.name,
           count(*) FILTER (
               WHERE r.check_in_date > current_date - 400
           ) AS 近400天真实签到数
      FROM who w
      LEFT JOIN public.check_in_records r ON r.user_id = w.uid
     GROUP BY w.uid, w.name
)
SELECT c.name AS 用户名,
       u.consecutive_days AS 库里存的连续天数,
       c.近400天真实签到数 AS 近400天真实签到数
  FROM cnt c
  LEFT JOIN public.user_checkins u ON u.user_id = c.uid
 ORDER BY c.name;


-- ============================================================
--  跑完看这几件事
-- ============================================================
--  ① 第 1 段的「连续天数」现在是多少？离 85 / 10 差多远？
--  ② 第 4 段的日历里，断档在哪几天？
--     —— 如果断的地方正好是「补签过的那天」，那就是 bug ①
--  ③ 第 3 段如果补签记录【不止一条】，基本能确定是 bug ①
--     （往前数连续时不算补签记录，所以补第二次接不上第一次）
--
--  ⚠️ 把第 1、3、4 段的结果发给我，我按实际情况写恢复脚本。
--     现在还不改任何数据。
-- ============================================================
