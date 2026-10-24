-- ============================================================
-- 会话自动续期:只要在有效期内访问过,登录状态就一直保持
-- 背景:_user_ok 原本是 LANGUAGE sql STABLE(只读),无法续期。
--       现在改成 plpgsql,校验通过后把过期时间往后推。
-- 效果:会话 30 天有效;每次访问只要剩余不足 25 天就续满 30 天
--       → 经常上站的人永远不会被登出(约 5 天写一次库,不产生写放大)
-- 执行:在 Supabase SQL Editor 整段运行,无需改前端、无需 Reload
-- ============================================================

CREATE OR REPLACE FUNCTION public._user_ok(p_user_id uuid, p_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_hash text := md5(coalesce(p_token, ''));
    v_ok   boolean;
BEGIN
    IF p_user_id IS NULL OR coalesce(p_token, '') = '' THEN
        RETURN false;
    END IF;

    -- 1) 校验:令牌存在、属于该用户、且未过期
    SELECT true INTO v_ok
      FROM public.user_sessions
     WHERE token_hash = v_hash
       AND user_id = p_user_id
       AND expires_at > now()
     LIMIT 1;

    IF v_ok IS NOT TRUE THEN
        RETURN false;
    END IF;

    -- 2) 自动续期:剩余不足 25 天时续满 30 天
    --    (用 25 天做阈值,避免每次调用都写库)
    UPDATE public.user_sessions
       SET expires_at = now() + interval '30 days'
     WHERE token_hash = v_hash
       AND expires_at < now() + interval '25 days';

    RETURN true;
END
$fn$;

-- 权限与原来保持一致(仅内部函数可用,不暴露给匿名)
REVOKE ALL ON FUNCTION public._user_ok(uuid, text) FROM PUBLIC;

-- ---------- 验收 ----------
SELECT p.proname AS 函数,
       l.lanname AS 语言,
       CASE p.provolatile
            WHEN 'v' THEN 'volatile(可写)'
            WHEN 's' THEN 'stable(只读)'
            WHEN 'i' THEN 'immutable'
            ELSE p.provolatile::text END AS 易变性,
       p.prosecdef AS security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
 WHERE n.nspname = 'public' AND p.proname = '_user_ok';
-- 期望:语言=plpgsql,易变性=volatile(可写),security_definer=true

-- 看看现有会话的剩余时间(跑完这个 SQL 后,访问一下网站再跑一次,过期时间应该往后推了)
SELECT user_id,
       to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI') AS 创建时间,
       to_char(expires_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI') AS 过期时间,
       round(extract(epoch FROM (expires_at - now())) / 86400, 1) AS 剩余天数
  FROM public.user_sessions
 ORDER BY expires_at DESC
 LIMIT 10;

-- ---------- 可选:清理已经过期的会话(表很小,偶尔跑一次就行) ----------
-- DELETE FROM public.user_sessions WHERE expires_at < now() - interval '1 day';
