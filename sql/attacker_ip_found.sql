-- ============================================================
-- 攻击者「小NB官号」的 IP —— 已查明(2026-09-09)
-- ============================================================
-- 结论:
--   注册时的精确 IP : 2409:8a30:9c84:4e21:81ab:3bcf:630b:35f1
--   所属网段(/64)   : 2409:8a30:9c84:4e21::/64   (中国移动 · 广东)
--
-- 证据链(用 registration_attempts 与 profiles.created_at 秒级对齐):
--   账号 小NB官号(593b7c94-2829-401e-980c-55c9257ff8cd)
--     profiles.created_at      = 2026-05-17 02:47:16.008172+00
--     registration_attempts    = 2026-05-17 02:47:16.833874+00  同 IP 同秒
--   同一 IP 上的马甲矩阵(全部 5 条记录,只有这一个精确地址):
--     2026-05-16 03:07:35  注册 NB
--     2026-05-16 03:09:03  注册 GPC公司
--     2026-05-16 03:14:36  (无对应账号,疑似注册失败)
--     2026-05-17 02:47:16  注册 小NB官号
--     2026-05-17 02:48:59  注册 GPC
--
--   ⚠️ 注意:曾怀疑的 2409:8a30:9c84:7241::/64 **不是他**,那是站长自己的宽带
--      (该网段注册了 17 个号,含小Na(Na公司)、NB备用号、NB多人号0/1,
--       以及 2026-09-08 12:36~12:42 的测试号),封了会把自己挡在门外。
-- ============================================================

-- ---------- 封禁攻击者网段(IPv6 地址会在同 /64 内轮换,必须封整段) ----------
INSERT INTO public.banned_ips (ip, reason)
VALUES ('2409:8a30:9c84:4e21::/64', '盗号案:小NB官号 注册来源网段(2026-05-17)')
ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;

-- 精确地址也一起封(万一他禁用隐私扩展、地址不变)
INSERT INTO public.banned_ips (ip, reason)
VALUES ('2409:8a30:9c84:4e21:81ab:3bcf:630b:35f1', '盗号案:小NB官号 注册来源IP')
ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;

-- 查看结果:
-- SELECT * FROM public.banned_ips ORDER BY id DESC;

-- ============================================================
-- 顺手修一个隐私漏洞:registration_attempts 目前 anon 可读全表
-- (不登录就能拉走全部 314 条注册 IP,含站长自己的)
-- 前端只用 RPC can_register / record_registration,不直接读表,收紧无影响
-- ============================================================
REVOKE SELECT ON public.registration_attempts FROM anon;
REVOKE SELECT ON public.registration_attempts FROM authenticated;

-- 如果执行后注册流程报错(极少数情况:某 RPC 不是 SECURITY DEFINER),再放开读:
-- GRANT SELECT ON public.registration_attempts TO anon;
