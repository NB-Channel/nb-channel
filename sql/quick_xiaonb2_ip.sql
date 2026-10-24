-- ============================================================
-- 最短路径:小NB2 的 IP
-- 小NB2 user_id : 7c112908-8e5e-487a-885a-49a2f318aeec
-- 注册时间      : 2026-09-25 01:52:37 UTC  =  09:52:37 北京
--
-- 原理:注册必须先收邮箱验证码,验证码由腾讯 SCF 云函数观测到真实 IP 后
--       写进 email_codes.ip_address(服务端观测,客户端伪造不了)。
--       所以它注册前几分钟必然在这里留了记录。
-- ============================================================

-- ---------- A) 注册时间窗内所有要过验证码的 IP ----------
-- 这条最有价值:能看到那个窗口里全部发码记录。
-- 如果小NB2 和别的可疑号共用 IP,这里直接就串出来了。
SELECT email, ip_address AS IP, purpose AS 用途, created_at AS 时间
  FROM public.email_codes
 WHERE created_at BETWEEN timestamptz '2026-09-25 01:30:00+00'
                       AND timestamptz '2026-09-25 02:05:00+00'
 ORDER BY created_at;

-- ---------- B) 按它的邮箱直接反查 ----------
SELECT p.username AS 用户名, p.email AS 邮箱,
       ec.ip_address AS IP, ec.purpose AS 用途, ec.created_at AS 时间
  FROM public.profiles p
  LEFT JOIN public.email_codes ec ON lower(ec.email) = lower(p.email)
 WHERE p.id = '7c112908-8e5e-487a-885a-49a2f318aeec'
 ORDER BY ec.created_at;

-- ---------- C) 顺带:那个 IP 还关联了哪些账号 ----------
-- 等 A/B 出来拿到 IP 后,把它填进下面的 '<IP>' 再跑一次。
-- SELECT DISTINCT p.username, p.id, p.created_at, p.is_banned
--   FROM public.email_codes ec JOIN public.profiles p ON lower(p.email) = lower(ec.email)
--  WHERE ec.ip_address = '<IP>' ORDER BY p.created_at;
