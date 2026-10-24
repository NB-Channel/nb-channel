-- ============================================================
-- NB频道 - 邮箱验证码(注册/登录 2FA · 第三层)
-- 前置:先执行 session_auth.sql(依赖 user_sessions)
-- 执行方式:在 Supabase SQL Editor 整体执行
-- 设计:验证码由 PythonAnywhere 生成并邮件发送;
--       数据库只存 md5 哈希,防前端绕过。
-- ============================================================

-- 1) profiles 增加 email(唯一,可为空;老账号未绑定前为空)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;
DROP INDEX IF EXISTS idx_profiles_email;
CREATE UNIQUE INDEX idx_profiles_email ON public.profiles (email) WHERE email IS NOT NULL;

-- 2) 验证码表(哈希存储)
CREATE TABLE IF NOT EXISTS public.email_codes (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text NOT NULL,
    purpose    text NOT NULL,             -- register / login / bind
    code_hash  text NOT NULL,             -- md5(6位码)
    ip_address text,
    attempts   integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL DEFAULT now() + interval '10 minutes',
    used_at    timestamptz
);
CREATE INDEX IF NOT EXISTS idx_email_codes_lookup
    ON public.email_codes (email, purpose, created_at DESC);
ALTER TABLE public.email_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS email_codes_no_anon ON public.email_codes;
REVOKE ALL ON public.email_codes FROM anon, authenticated;

-- 3) 存储验证码(PA 调用;带限频,防轰炸)
CREATE OR REPLACE FUNCTION public.store_email_code(p_email text, p_purpose text, p_code_hash text, p_ip text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_n int;
BEGIN
    IF p_email IS NULL OR p_code_hash IS NULL OR length(p_code_hash) <> 32 THEN
        RETURN jsonb_build_object('ok', false, 'message', '参数错误');
    END IF;
    -- 同一邮箱 60 秒内只能发一次
    SELECT count(*) INTO v_n FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '60 seconds';
    IF v_n > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '发送太频繁,请 60 秒后再试');
    END IF;
    -- 同一邮箱每天最多 5 次
    SELECT count(*) INTO v_n FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '1 day';
    IF v_n >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱今日验证码已达上限');
    END IF;
    -- 同一 IP 每小时最多 10 次
    IF p_ip IS NOT NULL THEN
        SELECT count(*) INTO v_n FROM public.email_codes
         WHERE ip_address = p_ip AND created_at > now() - interval '1 hour';
        IF v_n >= 10 THEN
            RETURN jsonb_build_object('ok', false, 'message', '操作过于频繁,请稍后再试');
        END IF;
    END IF;
    INSERT INTO public.email_codes (email, purpose, code_hash, ip_address)
    VALUES (lower(p_email), p_purpose, p_code_hash, p_ip);
    RETURN jsonb_build_object('ok', true);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text) TO anon;

-- 4) 校验并消耗验证码(内部)
CREATE OR REPLACE FUNCTION public._verify_email_code(p_email text, p_purpose text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_row public.email_codes%ROWTYPE;
BEGIN
    SELECT * INTO v_row FROM public.email_codes
     WHERE email = lower(p_email) AND purpose = p_purpose
       AND used_at IS NULL
     ORDER BY created_at DESC LIMIT 1;
    IF v_row.id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码不存在,请重新获取');
    END IF;
    IF v_row.expires_at < now() THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码已过期,请重新获取');
    END IF;
    IF v_row.attempts >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '尝试次数过多,请重新获取验证码');
    END IF;
    IF v_row.code_hash <> md5(coalesce(p_code, '')) THEN
        UPDATE public.email_codes SET attempts = attempts + 1 WHERE id = v_row.id;
        RETURN jsonb_build_object('ok', false, 'message', '验证码错误');
    END IF;
    UPDATE public.email_codes SET used_at = now() WHERE id = v_row.id;
    RETURN jsonb_build_object('ok', true);
END
$fn$;
REVOKE ALL ON FUNCTION public._verify_email_code(text, text, text) FROM PUBLIC;

-- 5) 登录第一步:校验用户名密码,返回邮箱掩码(PA 据此发码)
CREATE OR REPLACE FUNCTION public.lookup_login_email(p_username text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_uid uuid;
    v_email text;
BEGIN
    v_uid := public.login_user(p_username, p_password);
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '用户名或密码错误');
    END IF;
    SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;
    IF v_email IS NULL OR v_email = '' THEN
        RETURN jsonb_build_object('ok', true, 'need_bind', true);
    END IF;
    RETURN jsonb_build_object('ok', true, 'email', v_email);
END
$fn$;
REVOKE ALL ON FUNCTION public.lookup_login_email(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text, text) TO anon;

-- 6) 注册完成:验证码校验 + 建号 + 绑定邮箱
CREATE OR REPLACE FUNCTION public.register_finish(p_username text, p_password text, p_email text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_chk jsonb;
    v_uid uuid;
    v_exist uuid;
BEGIN
    v_chk := public._verify_email_code(p_email, 'register', p_code);
    IF NOT (v_chk ->> 'ok')::boolean THEN
        RETURN v_chk;
    END IF;
    -- 邮箱占用
    SELECT id INTO v_exist FROM public.profiles WHERE email = lower(p_email);
    IF v_exist IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱已被注册');
    END IF;
    v_uid := public.register_user(p_username, p_password);
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '用户名已存在或不符合规则');
    END IF;
    BEGIN
        UPDATE public.profiles SET email = lower(p_email) WHERE id = v_uid;
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱已被注册');
    END;
    RETURN jsonb_build_object('ok', true, 'id', v_uid);
END
$fn$;
REVOKE ALL ON FUNCTION public.register_finish(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_finish(text, text, text, text) TO anon;

-- 7) 登录完成:验证登录码,签发会话令牌
CREATE OR REPLACE FUNCTION public.login_finish(p_username text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_uid uuid;
    v_email text;
    v_chk jsonb;
BEGIN
    SELECT id, email INTO v_uid, v_email FROM public.profiles WHERE username = p_username;
    IF v_uid IS NULL OR v_email IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '账号不存在或未绑定邮箱');
    END IF;
    v_chk := public._verify_email_code(v_email, 'login', p_code);
    IF NOT (v_chk ->> 'ok')::boolean THEN
        RETURN v_chk;
    END IF;
    IF (SELECT is_banned FROM public.profiles WHERE id = v_uid) THEN
        RETURN jsonb_build_object('ok', false, 'message', '账号已被封禁,请联系管理员');
    END IF;
    RETURN jsonb_build_object('ok', true, 'id', v_uid, 'token', public.create_user_session(v_uid));
END
$fn$;
REVOKE ALL ON FUNCTION public.login_finish(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_finish(text, text) TO anon;

-- 8) 老账号首次绑定邮箱(需密码 + 绑定码,绑定码发到新邮箱)
CREATE OR REPLACE FUNCTION public.bind_email_finish(p_username text, p_password text, p_new_email text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_uid uuid;
    v_chk jsonb;
BEGIN
    v_uid := public.login_user(p_username, p_password);
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '用户名或密码错误');
    END IF;
    v_chk := public._verify_email_code(p_new_email, 'bind', p_code);
    IF NOT (v_chk ->> 'ok')::boolean THEN
        RETURN v_chk;
    END IF;
    BEGIN
        UPDATE public.profiles SET email = lower(p_new_email) WHERE id = v_uid;
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱已被使用');
    END;
    RETURN jsonb_build_object('ok', true, 'id', v_uid);
END
$fn$;
REVOKE ALL ON FUNCTION public.bind_email_finish(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bind_email_finish(text, text, text, text) TO anon;

-- 9) 查看/清理(管理)
-- SELECT * FROM public.email_codes ORDER BY id DESC LIMIT 20;
-- DELETE FROM public.email_codes WHERE created_at < now() - interval '2 days';
