-- ============================================================
-- 判断网段 2409:8a30:9c84:7241::/64 到底是谁的
-- (封错网段 = 把你自己或社区正常用户挡在门外,先跑这个)
-- ============================================================

-- A) 全部注册尝试都来自哪些网段(/64)?
--    如果名单里几乎只有 2409:8a30:9c84:7241 一个,说明这网段是站长自己常用的宽带,别封!
SELECT regexp_replace(ip_address, '^(([0-9a-fA-F]+:){4}).*$', '\1::/64') AS prefix64,
       count(*) AS 次数, min(created_at) AS 最早, max(created_at) AS 最近
FROM public.registration_attempts
GROUP BY 1
ORDER BY 次数 DESC
LIMIT 20;

-- B) 每个账号 ← 注册时间前 3 分钟内最近的一次注册尝试 IP(账号-IP 对应表)
SELECT p.username, p.created_at, p.is_banned,
       (SELECT r.ip_address FROM public.registration_attempts r
         WHERE r.created_at <= p.created_at
           AND r.created_at > p.created_at - interval '3 minutes'
         ORDER BY r.created_at DESC LIMIT 1) AS likely_ip
FROM public.profiles p
ORDER BY p.created_at DESC
LIMIT 60;

-- C) 只看这个网段注册出来的账号(看有没有明显不是你 / 明显是攻击者的号)
SELECT p.username, p.created_at, p.is_banned, p.banned_reason,
       (SELECT r.ip_address FROM public.registration_attempts r
         WHERE r.created_at <= p.created_at
           AND r.created_at > p.created_at - interval '3 minutes'
         ORDER BY r.created_at DESC LIMIT 1) AS likely_ip
FROM public.profiles p
WHERE EXISTS (
    SELECT 1 FROM public.registration_attempts r
     WHERE r.created_at <= p.created_at
       AND r.created_at > p.created_at - interval '3 minutes'
       AND r.ip_address LIKE '2409:8a30:9c84:7241:%')
ORDER BY p.created_at DESC
LIMIT 60;

-- ============================================================
-- 确认是攻击者之后才执行:
-- INSERT INTO public.banned_ips (ip, reason)
-- VALUES ('2409:8a30:9c84:7241::/64', '攻击账号 小NB官号 关联网段')
-- ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;
-- ============================================================
