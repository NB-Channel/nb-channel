-- ============================================================
--  查 Utw / Veo 名下所有账号的签到现状
--
--  站长说：「还有一个号的签到有问题：Utw小号」
--
--  ⚠️ 「Utw小号」没说是哪一个 —— 他名下账号不少（官方号 / 备用号 /
--     宿舍官号 / 机器店官号 / 借钱1 / 夺舍齐喜 …）。
--     这个脚本把所有名字里带 utw / veo 的账号一次列全，
--     顺便把每个号的签到状态摊开，一眼能看出哪个坏了、坏在哪。
--
--  ⚠️ 只查不改。
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 1. 名字里带 utw / veo 的账号，签到状态一览
--    ⚠️ 重点看这几列：
--        · 连续天数        —— 和「近 60 天真实签到数」对不对得上
--        · 最后签到日      —— 是不是今天（今天没签说明断签了）
--        · 今天签没签      —— 有记录 / 没有
--        · 补签过几次
-- ============================================================
SELECT p.username                                   AS 用户名,
       p.id                                         AS user_id,
       u.last_checkin_date                          AS 最后签到日,
       u.consecutive_days                           AS 连续天数,
       (current_date - u.last_checkin_date)         AS 距今几天,
       (SELECT count(*) FROM public.check_in_records r
         WHERE r.user_id = p.id)                    AS 真实签到总记录,
       (SELECT count(*) FROM public.check_in_records r
         WHERE r.user_id = p.id
           AND r.check_in_date > current_date - 60) AS 近60天真实签到,
       (SELECT count(*) FROM public.checkin_fix_records f
         WHERE f.user_id = p.id)                    AS 补签次数,
       EXISTS (SELECT 1 FROM public.check_in_records r
                WHERE r.user_id = p.id
                  AND r.check_in_date = (now() AT TIME ZONE 'Asia/Shanghai')::date) AS 今天签了
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%veo%'
 ORDER BY u.consecutive_days DESC NULLS LAST, p.username;


-- ============================================================
-- 2. 上面那批里，哪些「看起来不对劲」
--    判据：
--      · 近 60 天真实签到 ≥ 20 条，但连续天数 < 10  —— 连续被算小了
--      · 今天签了，但 last_checkin_date 不是今天        —— 记录没落库
--      · 连续天数 = 0 或 NULL 但明明有签到记录           —— 从来没算过
-- ============================================================
WITH st AS (
    SELECT p.username, p.id, u.last_checkin_date, u.consecutive_days,
           (SELECT count(*) FROM public.check_in_records r
             WHERE r.user_id = p.id AND r.check_in_date > current_date - 60) AS r60,
           (SELECT count(*) FROM public.check_in_records r
             WHERE r.user_id = p.id) AS rtot,
           EXISTS (SELECT 1 FROM public.check_in_records r
                    WHERE r.user_id = p.id
                      AND r.check_in_date = (now() AT TIME ZONE 'Asia/Shanghai')::date) AS today
      FROM public.profiles p
      LEFT JOIN public.user_checkins u ON u.user_id = p.id
     WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%veo%'
)
SELECT username AS 用户名,
       CASE
         WHEN r60 >= 20 AND coalesce(consecutive_days,0) < 10
              THEN '⚠️ 近60天签了 ' || r60 || ' 天，连续却只有 ' || coalesce(consecutive_days,0) || ' —— 连续被算小了'
         WHEN today AND last_checkin_date <> (now() AT TIME ZONE 'Asia/Shanghai')::date
              THEN '⚠️ 今天签了，但最后签到日停在 ' || coalesce(last_checkin_date::text,'空') || ' —— 记录没落库'
         WHEN rtot > 0 AND coalesce(consecutive_days,0) = 0
              THEN '⚠️ 有 ' || rtot || ' 条签到记录，连续天数却是 0'
         WHEN rtot = 0
              THEN '· 一条记录都没有（新号或从没签到）'
         ELSE '· 看起来正常'
       END AS 诊断
  FROM st
 ORDER BY 诊断 DESC, username;


-- ============================================================
-- 3. 上面那批账号最近 30 天的签到日历
--    ✓ = 真实签到   ● = 补签   · = 没有
-- ============================================================
WITH days AS (
    SELECT generate_series(current_date - 29, current_date, interval '1 day')::date AS d
),
who AS (
    SELECT id AS uid, username AS name FROM public.profiles
     WHERE username ILIKE '%utw%' OR username ILIKE '%veo%'
)
SELECT w.name AS 用户名,
       string_agg(
         CASE
           WHEN EXISTS (SELECT 1 FROM public.check_in_records r
                         WHERE r.user_id = w.uid AND r.check_in_date = days.d) THEN '✓'
           WHEN EXISTS (SELECT 1 FROM public.checkin_fix_records f
                         WHERE f.user_id = w.uid AND f.check_in_date = days.d) THEN '●'
           ELSE '·'
         END, '' ORDER BY days.d) AS 近30天
  FROM who w CROSS JOIN days
 GROUP BY w.name
 ORDER BY w.name;

-- ⚠️ 从左到右是【30 天前 → 今天】。
--    一串 ✓ 中间突然出现 · 就是断签那天。


-- ============================================================
--  跑完把 1、2、3 段发我
-- ============================================================
--  我要知道：
--    ① 「Utw小号」到底是哪个用户名
--    ② 它的连续天数、最后签到日、记录数分别是多少
--    ③ 断在哪天
--
--  ⚠️ 上一轮修 Utw 大号（ea24ed9e…）和 Veo（633685cd…）时，
--     根因是「do_check_in 有一段时间没写 check_in_records」，
--     导致签到历史缺了一大段，补签就算不对。
--     如果这个小号也是同一个毛病，修法一样：
--         先补缺失的签到记录 → 再重算连续天数。
-- ============================================================
