-- ============================================================
-- 登录暴力破解防护:同一账号 10 分钟内失败 5 次就锁 10 分钟
-- 背景:login_user / login_user2 都没有次数限制,攻击者可以无限次猜密码。
--       (admin_create_session 早就有类似限频,但普通账号登录一直没有)
-- 做法:原名函数改名 _orig_xxx 并禁止匿名直调,再建同名包装函数,
--       先查失败次数 → 通过才转交原函数 → 按结果记录/清除失败。
-- 前端无需改动(函数签名不变),跑完即生效。
-- ============================================================

-- ---------- 1) 失败记录表(匿名完全不可见) ----------
CREATE TABLE IF NOT EXISTS public.login_attempts (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username   text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_attempts_name_time
    ON public.login_attempts (lower(username), created_at);
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.login_attempts FROM anon, authenticated;

-- ---------- 2) 原函数让位(自动取真实签名,幂等) ----------
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS ident
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('login_user', 'login_user2')
           AND NOT EXISTS (
               SELECT 1 FROM pg_proc p2
                 JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
                WHERE n2.nspname = 'public' AND p2.proname = '_orig_' || p.proname)
    LOOP
        EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', r.proname, r.ident, '_orig_' || r.proname);
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated', '_orig_' || r.proname, r.ident);
        RAISE NOTICE '已改名: %(%) -> _orig_%', r.proname, r.ident, r.proname;
    END LOOP;
END $$;

-- ---------- 3) login_user 包装(返回 uuid,评论页改资料时验旧密码也走它) ----------
CREATE OR REPLACE FUNCTION public.login_user(input_username text, input_password text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $w$
DECLARE
    v_key   text := lower(trim(coalesce(input_username, '')));
    v_fails int;
    v_res   uuid;
BEGIN
    SELECT count(*) INTO v_fails FROM public.login_attempts
     WHERE lower(username) = v_key AND created_at > now() - interval '10 minutes';
    IF v_fails >= 5 THEN
        RAISE EXCEPTION '密码错误次数过多,请 10 分钟后再试';
    END IF;

    v_res := public._orig_login_user(input_username, input_password);

    IF v_res IS NULL THEN
        INSERT INTO public.login_attempts (username) VALUES (v_key);
    ELSE
        DELETE FROM public.login_attempts WHERE lower(username) = v_key;
    END IF;
    RETURN v_res;
END
$w$;
GRANT EXECUTE ON FUNCTION public.login_user(text, text) TO anon;

-- ---------- 4) login_user2 包装(返回 jsonb,新版登录页走它) ----------
CREATE OR REPLACE FUNCTION public.login_user2(input_username text, input_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $w$
DECLARE
    v_key   text := lower(trim(coalesce(input_username, '')));
    v_fails int;
    v_res   jsonb;
BEGIN
    SELECT count(*) INTO v_fails FROM public.login_attempts
     WHERE lower(username) = v_key AND created_at > now() - interval '10 minutes';
    IF v_fails >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '密码错误次数过多,请 10 分钟后再试');
    END IF;

    v_res := public._orig_login_user2(input_username, input_password);

    IF v_res IS NULL OR (v_res->>'ok') IS DISTINCT FROM 'true' THEN
        INSERT INTO public.login_attempts (username) VALUES (v_key);
    ELSE
        DELETE FROM public.login_attempts WHERE lower(username) = v_key;
    END IF;
    RETURN v_res;
END
$w$;
GRANT EXECUTE ON FUNCTION public.login_user2(text, text) TO anon;

-- ---------- 5) 验收 ----------
SELECT p.proname AS 函数, p.prosecdef AS security_definer
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('login_user', 'login_user2', '_orig_login_user', '_orig_login_user2')
 ORDER BY p.proname;

-- 原始函数应不可被匿名调用(0 行 = 已封好)
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '\_orig\_login%'
   AND has_function_privilege('anon', p.oid, 'EXECUTE');
