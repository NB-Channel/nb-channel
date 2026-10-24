-- ============================================================
-- 查「小NB2」的注册 IP(封禁礼包第 ⑤ 步没贴结果,单独跑一次)
--   小NB2 user_id   : 7c112908-8e5e-487a-885a-49a2f318aeec
--   注册时间        : 2026-09-25 01:52:37 UTC  =  09:52:37 北京
--
-- 为什么要查:IP 黑名单是 PythonAnywhere 后端执行的(封禁后该 IP 的
--   /api/* 请求会被拒),而注册 IP 日志 registration_attempts 正是后端写的,
--   所以注册也经过后端 → 封 IP 能拦住他再注册。
--
--   但有个关键疑点:他的老网段 2409:8a30:9c84:4e21::/64 早就被封了,
--   他今天却仍然注册成功。所以这次查出来要重点看:
--     · 如果是「新网段」→ 他换了网络,把这个新网段也封上
--     · 如果还是「4e21::/64」→ 说明 IP 封禁没在注册流程上生效,
--       那就得改后端/服务端,封 IP 是白费功夫(见文件末尾)
--
-- 在 Supabase SQL Editor 整段执行
-- ============================================================

-- ---------- ① 注册窗口 ±20 分钟内的全部注册 IP ----------
-- 最后一列直接给出可复制的封禁语句:
--   · IPv6 自动收敛成 /64 整段(只封单地址没用,他换个后缀就回来了)
--   · ⚠️ 命中你自己的网段 7241 会明确警告
SELECT r.ip_address AS 注册IP,
       r.created_at AS 时间,
       EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = r.ip_address) AS 精确IP已封,
       EXISTS (SELECT 1 FROM public.banned_ips b
                WHERE b.ip = '2409:8a30:9c84:4e21::/64') AS 老网段已封,
       CASE
         WHEN r.ip_address LIKE '2409:8a30:9c84:7241:%'
              THEN '⚠️ 这是你自己的网段(7241),不要封!'
         WHEN r.ip_address LIKE '%:%'
              THEN format('INSERT INTO public.banned_ips (ip, reason) VALUES (%L, %L) ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;',
                          split_part(r.ip_address, ':', 1) || ':' || split_part(r.ip_address, ':', 2) || ':'
                       || split_part(r.ip_address, ':', 3) || ':' || split_part(r.ip_address, ':', 4) || '::/64',
                          '小NB2 注册来源网段')
         ELSE format('INSERT INTO public.banned_ips (ip, reason) VALUES (%L, %L) ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;',
                     r.ip_address, '小NB2 注册来源IP')
       END AS 封禁语句
  FROM public.registration_attempts r
 WHERE r.created_at BETWEEN timestamptz '2026-09-25 01:32:37+00'
                         AND timestamptz '2026-09-25 02:12:37+00'
 ORDER BY r.created_at;

-- ---------- ② 同一时间段还注册了哪些账号(找其它小号) ----------
SELECT id, username, created_at AS 注册时间, is_banned AS 已封
  FROM public.profiles
 WHERE created_at BETWEEN timestamptz '2026-09-25 01:32:37+00'
                       AND timestamptz '2026-09-25 02:12:37+00'
 ORDER BY created_at;

-- ---------- ③ 最近 7 天各网段注册统计(看他的活动规律) ----------
-- 按 /64 归类;某网段注册量异常高 = 他在刷号
SELECT CASE WHEN r.ip_address LIKE '%:%'
            THEN split_part(r.ip_address, ':', 1) || ':' || split_part(r.ip_address, ':', 2) || ':'
              || split_part(r.ip_address, ':', 3) || ':' || split_part(r.ip_address, ':', 4) || '::/64'
            ELSE r.ip_address END AS 网段,
       count(*) AS 注册次数,
       count(DISTINCT date_trunc('day', r.created_at)) AS 活跃天数,
       min(r.created_at) AS 最早,
       max(r.created_at) AS 最近,
       bool_or(r.ip_address IN (SELECT b.ip FROM public.banned_ips b)) AS 已封
  FROM public.registration_attempts r
 WHERE r.created_at > now() - interval '7 days'
 GROUP BY 1
 ORDER BY 注册次数 DESC
 LIMIT 25;

-- ---------- ④ 账号 ← 注册 IP 对照(最近 20 个新号) ----------
SELECT p.username AS 用户名,
       p.created_at AS 注册时间,
       p.is_banned AS 已封,
       (SELECT r.ip_address FROM public.registration_attempts r
         WHERE r.created_at BETWEEN p.created_at - interval '3 minutes'
                                AND p.created_at + interval '3 minutes'
         ORDER BY abs(extract(epoch FROM (r.created_at - p.created_at)))
         LIMIT 1) AS 推测注册IP
  FROM public.profiles p
 ORDER BY p.created_at DESC
 LIMIT 20;
