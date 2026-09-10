-- ============================================================
-- 查「小NB官号」攻击者的 IP / 网段
-- 在 Supabase SQL Editor 整段运行,把结果截图或复制发我
-- ============================================================

-- 1) 攻击账号自身信息(注册时间 = 找 IP 的钥匙)
SELECT id, username, created_at, is_banned, banned_reason, email
FROM public.profiles
WHERE id = '593b7c94-2829-401e-980c-55c9257ff8cd'
   OR username ILIKE '%小NB%';

-- 2) 它的注册 IP:registration_attempts 里取注册时间前后 30 分钟的记录
SELECT r.ip_address, r.created_at
FROM public.registration_attempts r
WHERE r.created_at BETWEEN
      (SELECT created_at - interval '30 minutes' FROM public.profiles
        WHERE id = '593b7c94-2829-401e-980c-55c9257ff8cd')
  AND (SELECT created_at + interval '30 minutes' FROM public.profiles
        WHERE id = '593b7c94-2829-401e-980c-55c9257ff8cd')
ORDER BY r.created_at;

-- 3) 全部注册记录按时间倒序(人工比对,看哪个 IP 反复出现)
SELECT ip_address, count(*) AS n, min(created_at) AS first_seen, max(created_at) AS last_seen
FROM public.registration_attempts
GROUP BY ip_address
ORDER BY n DESC
LIMIT 30;

-- 4) 关联可疑账号(转账/仓储日志里出现过的)
SELECT id, username, created_at, is_banned
FROM public.profiles
WHERE id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',
             '97fb943a-0000-0000-0000-000000000000')
ORDER BY created_at;

-- 5) 如果攻击账号绑过邮箱,验证码请求里会留 IP
SELECT email, purpose, ip_address, created_at
FROM public.email_codes
WHERE email IN (SELECT email FROM public.profiles
                 WHERE id = '593b7c94-2829-401e-980c-55c9257ff8cd'
                   AND email IS NOT NULL)
ORDER BY created_at DESC;

-- 6) PythonAnywhere 后端记的 /api/* 访问 IP(他若打过接口,这里最准)
SELECT ip, count(*) AS n, max(ts) AS last_seen
FROM public.api_logs
WHERE ip IS NOT NULL
GROUP BY ip
ORDER BY n DESC
LIMIT 30;

-- 7) 当前已封名单
SELECT * FROM public.banned_ips ORDER BY id DESC;

-- 8) 核对:之前记录的疑似攻击者网段 2409:8a30:9c84:7241::/64 是否真出现在日志里
SELECT 'registration_attempts' AS src, ip_address, created_at
FROM public.registration_attempts
WHERE ip_address LIKE '2409:8a30:9c84:7241:%'
UNION ALL
SELECT 'email_codes', ip_address, created_at
FROM public.email_codes
WHERE ip_address LIKE '2409:8a30:9c84:7241:%'
UNION ALL
SELECT 'api_logs', ip, ts
FROM public.api_logs
WHERE ip LIKE '2409:8a30:9c84:7241:%'
ORDER BY created_at DESC
LIMIT 50;
-- 一条都没有 = 这个网段不是他,别封

-- ============================================================
-- 拿到 IP / 网段后,封禁(IPv6 建议封 /64 整段)
-- ============================================================
-- INSERT INTO public.banned_ips (ip, reason)
-- VALUES ('2409:8a30:9c84:7241::/64', '攻击账号 小NB官号 关联网段')
-- ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;
