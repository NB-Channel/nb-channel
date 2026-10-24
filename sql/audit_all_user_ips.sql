-- ============================================================
-- 全量 IP 审计:所有账号 ← IP 对照
--
-- 【数据源说明】站上记 IP 的地方一共四张表,但只有一张是活的:
--   email_codes.ip_address        ← ✅ 活的。发验证码时记的,而注册必须收验证码,
--                                    发信由 PythonAnywhere 后端做,后端能看到真实 IP。
--                                    小NB2 注册时必然在这里留了记录。
--   registration_attempts         ← ❌ 09-09 起停止写入(见 fix_registration_ip_block.sql)
--   admin_login_attempts.ip_address ← 只管后台登录,且按 IP 覆盖写,历史留存少
--   api_logs.ip                   ← ❌ 空的(已确认 0 行)
--
-- ⚠️ 一个必须知道的前提:email_codes 的 IP 是调用方作为参数传进来的(p_ip)。
--    如果是后端传的 → 可信;如果是前端传的 → 可以被伪造。
--    第 ⑥ 条就是验证这一点:比对你自己账号记的 IP 和你真实公网 IP。
--
-- 在 Supabase SQL Editor 整段执行,把结果贴回来
-- ============================================================


-- ============================================================
-- ① 直接答案:小NB2 的邮箱 + 它的全部 IP 记录
-- ============================================================
SELECT p.username AS 用户名,
       p.email AS 邮箱,
       ec.ip_address AS IP,
       ec.purpose AS 用途,
       ec.created_at AS 时间,
       EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = ec.ip_address) AS 已在黑名单
  FROM public.profiles p
  LEFT JOIN public.email_codes ec ON lower(ec.email) = lower(p.email)
 WHERE p.id = '7c112908-8e5e-487a-885a-49a2f318aeec'
 ORDER BY ec.created_at DESC;


-- ============================================================
-- ② 全部账号 ← IP 对照表(按注册时间倒序)
-- ============================================================
-- 每个账号取「最早一次发码」的 IP —— 最接近注册当时。
SELECT p.username AS 用户名,
       p.id AS user_id,
       to_char(p.created_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI') AS 注册时间,
       p.is_banned AS 已封,
       p.email AS 邮箱,
       (SELECT ec.ip_address FROM public.email_codes ec
         WHERE lower(ec.email) = lower(p.email)
         ORDER BY ec.created_at LIMIT 1) AS 最早发码IP,
       (SELECT count(*) FROM public.email_codes ec
         WHERE lower(ec.email) = lower(p.email)) AS 发码次数,
       (SELECT to_char(max(ec.created_at) AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI')
          FROM public.email_codes ec WHERE lower(ec.email) = lower(p.email)) AS 最近发码
  FROM public.profiles p
 ORDER BY p.created_at DESC;


-- ============================================================
-- ③ 按 IP 聚合:哪些 IP 下面挂着多个账号(= 小号群)
-- ============================================================
-- 同一 IP 出过多个账号 → 大概率是同一人。这是抓小号最有效的一条。
SELECT ec.ip_address AS IP,
       CASE WHEN ec.ip_address LIKE '%:%'
            THEN split_part(ec.ip_address, ':', 1) || ':' || split_part(ec.ip_address, ':', 2) || ':'
              || split_part(ec.ip_address, ':', 3) || ':' || split_part(ec.ip_address, ':', 4) || '::/64'
            ELSE ec.ip_address END AS 网段,
       count(DISTINCT ec.email) AS 不同邮箱,
       count(DISTINCT p.id) AS 关联账号数,
       string_agg(DISTINCT p.username, ', ') AS 账号,
       min(ec.created_at) AS 最早,
       max(ec.created_at) AS 最近,
       bool_or(p.is_banned) AS 有封禁账号
  FROM public.email_codes ec
  JOIN public.profiles p ON lower(p.email) = lower(ec.email)
 WHERE ec.created_at > now() - interval '60 days'
 GROUP BY ec.ip_address
 ORDER BY 关联账号数 DESC, 最近 DESC
 LIMIT 40;


-- ============================================================
-- ④ 所有出现过的 IP + 自动生成封禁语句
-- ============================================================
SELECT ec.ip_address AS IP,
       count(*) AS 发码次数,
       count(DISTINCT ec.email) AS 邮箱数,
       max(ec.created_at) AS 最近,
       EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = ec.ip_address) AS 精确已封,
       CASE
         WHEN ec.ip_address LIKE '2409:8a30:9c84:7241:%'
              THEN '⚠️ 你自己的网段(7241),不要封!'
         WHEN ec.ip_address IS NULL OR ec.ip_address = '' OR ec.ip_address = 'unknown'
              THEN '—(没记到 IP)'
         WHEN ec.ip_address LIKE '%:%'
              THEN format('INSERT INTO public.banned_ips (ip, reason) VALUES (%L, %L) ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;',
                          split_part(ec.ip_address, ':', 1) || ':' || split_part(ec.ip_address, ':', 2) || ':'
                       || split_part(ec.ip_address, ':', 3) || ':' || split_part(ec.ip_address, ':', 4) || '::/64',
                          '违规账号来源网段')
         ELSE format('INSERT INTO public.banned_ips (ip, reason) VALUES (%L, %L) ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;',
                     ec.ip_address, '违规账号来源IP')
       END AS 封禁语句
  FROM public.email_codes ec
 WHERE ec.created_at > now() - interval '60 days'
 GROUP BY ec.ip_address
 ORDER BY 发码次数 DESC
 LIMIT 60;


-- ============================================================
-- ⑤ 各数据源到底有没有数据(一眼看清哪张表是活的)
-- ============================================================
SELECT 'email_codes'            AS 表, count(*) AS 行数, max(created_at) AS 最新一条 FROM public.email_codes
UNION ALL
SELECT 'registration_attempts', count(*), max(created_at) FROM public.registration_attempts
UNION ALL
SELECT 'admin_login_attempts',  count(*), max(created_at) FROM public.admin_login_attempts
UNION ALL
SELECT 'api_logs',              count(*), max(ts)         FROM public.api_logs;


-- ============================================================
-- ⑥ 可信度自检:你自己账号记的 IP,是不是你真实公网 IP?
-- ============================================================
-- 先把自己真实 IP 查出来(浏览器打开 https://ipwho.is 看 "ip" 那个字段),
-- 再跑这条,看两边是否一致:
--   一致   → IP 是后端传的,可信,④ 生成的封禁语句可以直接用
--   不一致 → IP 是前端传的,可以被伪造,封 IP 的意义有限(告诉我,我改成服务端抓)
SELECT p.username AS 用户名, p.email AS 邮箱,
       ec.ip_address AS 记录IP, ec.purpose AS 用途, ec.created_at AS 时间
  FROM public.profiles p
  JOIN public.email_codes ec ON lower(ec.email) = lower(p.email)
 WHERE p.id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'   -- 站长账号
 ORDER BY ec.created_at DESC
 LIMIT 10;
