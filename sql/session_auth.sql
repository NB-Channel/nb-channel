-- ============================================================
-- NB频道 - 用户会话令牌(修复"改ID冒仿登录"漏洞 · 第一层)
-- 在 Supabase SQL Editor 中整体执行(可重复执行)
-- 说明:
--   登录成功签发随机令牌,高危操作必须携带令牌并校验本人;
--   令牌以 md5 哈希入库,即使库泄露也无法反推令牌。
-- ============================================================

-- 1) 会话表:令牌哈希 + 用户 + 有效期
CREATE TABLE IF NOT EXISTS public.user_sessions (
    token_hash text PRIMARY KEY,          -- md5(原始令牌)
    user_id    uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL DEFAULT now() + interval '30 days'
);
CREATE INDEX IF NOT EXISTS idx_user_sessions_uid ON public.user_sessions (user_id);
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
-- 读写全部只走函数,匿名与登录角色均不可直查(防偷令牌)
DROP POLICY IF EXISTS user_sessions_no_anon ON public.user_sessions;
REVOKE ALL ON public.user_sessions FROM anon, authenticated;

-- 2) 签发函数(仅服务端内部可调,不授权给匿名,避免被冒用生成)
CREATE OR REPLACE FUNCTION public.create_user_session(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_raw  text;
    v_hash text;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'user required';
    END IF;
    v_raw  := md5(random()::text || clock_timestamp()::text || p_user_id::text || random()::text);
    v_hash := md5(v_raw);
    -- 同用户只保留最近 5 个会话,防表膨胀
    DELETE FROM public.user_sessions
     WHERE user_id = p_user_id
       AND token_hash NOT IN (
           SELECT token_hash FROM public.user_sessions
            WHERE user_id = p_user_id
            ORDER BY created_at DESC LIMIT 5
       );
    INSERT INTO public.user_sessions (token_hash, user_id)
    VALUES (v_hash, p_user_id);
    RETURN v_raw;
END
$fn$;
REVOKE ALL ON FUNCTION public.create_user_session(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_user_session(uuid) TO service_role;

-- 3) 校验函数:会话有效且属于该用户
CREATE OR REPLACE FUNCTION public._user_ok(p_user_id uuid, p_token text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_sessions
         WHERE token_hash = md5(coalesce(p_token, ''))
           AND user_id = p_user_id
           AND expires_at > now()
    )
$$;
REVOKE ALL ON FUNCTION public._user_ok(uuid, text) FROM PUBLIC;

-- 4) 登出(删除会话)
CREATE OR REPLACE FUNCTION public.logout_session(p_token text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    DELETE FROM public.user_sessions WHERE token_hash = md5(coalesce(p_token, ''));
    SELECT true
$$;
REVOKE ALL ON FUNCTION public.logout_session(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.logout_session(text) TO anon;

-- 5) 登录(新):校验用户名密码成功后同时签发会话
--    保留旧 login_user 不动(兼容),新流程改用本函数
CREATE OR REPLACE FUNCTION public.login_user2(input_username text, input_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_uid uuid;
BEGIN
    v_uid := public.login_user(input_username, input_password);
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '用户名或密码错误');
    END IF;
    RETURN jsonb_build_object(
        'ok', true,
        'id',    v_uid,
        'token', public.create_user_session(v_uid)
    );
END
$fn$;
GRANT EXECUTE ON FUNCTION public.login_user2(text, text) TO anon;

-- 6) 高危函数安全包裹通用样例(后续文件逐个包裹以下函数)
--    update_bio / bankrupt_company / transfer_nb / claim_redpacket
--    do_check_in / do_lottery / buy_shop_item / sell_shop_item
--    use_shop_item / set_item_settings / update_password
--    包裹器文件:session_auth_highrisk.sql(见下一条消息/文件)
