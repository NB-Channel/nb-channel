-- ============================================================
-- 📱 扫码登录（两个方向）
-- ============================================================
-- 一张表装两个方向,用 kind 区分:
--   kind = 'pc_login'      手机授权电脑
--   kind = 'device_login'  电脑授权设备
--
-- ── A · pc_login（手机授权电脑）──────────────────────────────
--   解决:电脑上收邮件、输验证码麻烦
--
--   电脑(未登录)                        手机(已登录)
--   ────────────                        ────────────
--   qr_login_create → code + secret
--   显示二维码(码里是 code)
--   每 2 秒 qr_login_poll               扫码打开 qr-login-Beta.html?c=code
--                                        qr_login_scan(code) 看是谁在请求
--                                        qr_login_confirm(code, 我的id, 我的session)
--   poll 拿到令牌 → 电脑登录
--
-- ── B · device_login（电脑授权设备）───────────────────────────
--   解决:手机上打字慢,不想再输一遍密码
--
--   电脑(已登录)                        手机/别的设备(未登录)
--   ────────────                        ────────────────
--   qr_grant_create(我的id, 我的session)
--   显示二维码(码里是 code)
--   每 2 秒 qr_grant_status              扫码打开 qr-claim-Beta.html?c=code
--                                        qr_grant_info(code) → "你将登录为 x*y"
--                                        qr_grant_claim(code) → 直接拿到令牌
--   显示"已被 xxx 领走"
--
-- ── ⚠️ 两个方向的安全模型完全不同,别混 ──────────────────────
--
--   A：code 只是"请求登录"的凭据。最终令牌要 code + secret 才拿得到,
--      而 secret 只在电脑端手里 → 【偷看二维码拿不到令牌】。
--      要防的是 QRLJacking:别人把二维码发给你,骗你扫码替他登录。
--      所以手机端必须先看清"请求方的 IP" —— IP 是服务端读的,伪造不了。
--
--   B：⚠️ code 本身就是登录凭证 —— 谁扫到谁就登进这个账号。
--      所以:① 有效期只有 90 秒（比 A 的 2 分钟更短）
--           ② 一次性
--           ③ 必须已登录的人才能生成
--           ④ 电脑端要显著警告"别截图发给别人"
--           ⑤ 电脑端显示领走者的 IP,号主能发现异常
--
-- 在 Supabase SQL Editor 执行（幂等）
-- ============================================================


-- ============================================================
-- 1. 表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.qr_login_sessions (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind         text NOT NULL DEFAULT 'pc_login'
                 CHECK (kind IN ('pc_login', 'device_login')),
    code         text NOT NULL UNIQUE CHECK (code ~ '^[0-9A-F]{16}$'),
    secret       text NOT NULL CHECK (secret ~ '^[0-9A-F]{32}$'),
    status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'confirmed', 'consumed', 'cancelled')),
    user_id      uuid,                -- A:确认的账号   B:授权人(创建时就写入)
    -- 浏览器那一侧
    desktop_ua   text,
    desktop_ip   text,
    -- B 专用:哪台设备把会话领走了
    claim_ip     text,
    claim_ua     text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    expires_at   timestamptz NOT NULL DEFAULT now() + interval '2 minutes',
    confirmed_at timestamptz,
    consumed_at  timestamptz
);
-- 兼容已经建过旧版的库
ALTER TABLE public.qr_login_sessions ADD COLUMN IF NOT EXISTS kind     text NOT NULL DEFAULT 'pc_login';
ALTER TABLE public.qr_login_sessions ADD COLUMN IF NOT EXISTS claim_ip text;
ALTER TABLE public.qr_login_sessions ADD COLUMN IF NOT EXISTS claim_ua text;

ALTER TABLE public.qr_login_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.qr_login_sessions FROM anon, authenticated;

CREATE INDEX IF NOT EXISTS qr_login_code_idx    ON public.qr_login_sessions (code);
CREATE INDEX IF NOT EXISTS qr_login_created_idx ON public.qr_login_sessions (created_at DESC);
CREATE INDEX IF NOT EXISTS qr_login_ip_idx      ON public.qr_login_sessions (desktop_ip, created_at DESC);
CREATE INDEX IF NOT EXISTS qr_login_user_idx    ON public.qr_login_sessions (user_id, created_at DESC);


-- ============================================================
-- ══════════ A · pc_login：手机授权电脑 ══════════
-- ============================================================

-- ------------------------------------------------------------
-- A1. 电脑端:生成会话
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_login_create(p_ua text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_ip      text := public._request_ip();
    v_recent  integer;
    v_code    text;
    v_secret  text;
BEGIN
    DELETE FROM public.qr_login_sessions WHERE expires_at < now() - interval '1 hour';

    -- 限频:同一 IP 10 分钟最多建 8 个
    SELECT count(*) INTO v_recent FROM public.qr_login_sessions
     WHERE desktop_ip = v_ip AND kind = 'pc_login'
       AND created_at > now() - interval '10 minutes';
    IF v_recent >= 8 THEN
        RETURN jsonb_build_object('ok', false, 'message', '请求过于频繁，请稍后再试');
    END IF;

    v_code   := upper(substring(md5(random()::text || clock_timestamp()::text), 1, 16));
    v_secret := upper(substring(md5(clock_timestamp()::text || random()::text || v_ip), 1, 32));

    INSERT INTO public.qr_login_sessions (kind, code, secret, desktop_ua, desktop_ip, expires_at)
    VALUES ('pc_login', v_code, v_secret, left(coalesce(p_ua, ''), 200), v_ip,
            now() + interval '2 minutes');

    RETURN jsonb_build_object(
        'ok', true, 'code', v_code, 'secret', v_secret, 'ttl', 120,
        'url', 'https://github.nb-channel.top/Beta/qr-login-Beta.html?c=' || v_code);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_login_create(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_login_create(text) TO anon;


-- ------------------------------------------------------------
-- A2. 手机端:先看"是谁在请求"（绝不返回 secret 和 user_id）
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_login_scan(p_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Fa-f]', '', 'g'));
    v_row  record;
BEGIN
    IF length(v_code) <> 16 THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码无效');
    END IF;
    SELECT * INTO v_row FROM public.qr_login_sessions WHERE code = v_code AND kind = 'pc_login';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码无效或已失效，请在电脑上刷新后重新扫');
    END IF;
    IF v_row.expires_at < now() THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码已过期，请在电脑上刷新');
    END IF;
    IF v_row.status <> 'pending' THEN
        RETURN jsonb_build_object('ok', false, 'reason', '这个二维码已经确认过了');
    END IF;
    RETURN jsonb_build_object(
        'ok', true,
        'ua', coalesce(v_row.desktop_ua, ''),
        'ip', coalesce(v_row.desktop_ip, '未知'),
        'created_at', to_char(v_row.created_at AT TIME ZONE 'Asia/Shanghai', 'HH24:MI:SS'));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', '读取失败');
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_login_scan(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_login_scan(text) TO anon;


-- ------------------------------------------------------------
-- A3. 手机端:确认 / 取消（必须带着手机自己的登录会话）
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_login_confirm(
    p_code text, p_user_id uuid, p_session text, p_approve boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Fa-f]', '', 'g'));
    v_row  record;
    v_name text;
BEGIN
    -- ⭐ 手机端必须自己登录着 —— 没登录的人确认不了
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'reason', '请先登录你自己的账号');
    END IF;
    IF length(v_code) <> 16 THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码无效');
    END IF;

    -- 原子抢占:同一张码只有第一个确认的人生效
    UPDATE public.qr_login_sessions
       SET status = CASE WHEN p_approve THEN 'confirmed' ELSE 'cancelled' END,
           user_id      = CASE WHEN p_approve THEN p_user_id ELSE NULL END,
           confirmed_at = now()
     WHERE code = v_code AND kind = 'pc_login' AND status = 'pending' AND expires_at > now()
     RETURNING * INTO v_row;

    IF NOT FOUND THEN
        SELECT * INTO v_row FROM public.qr_login_sessions WHERE code = v_code AND kind = 'pc_login';
        IF NOT FOUND THEN
            RETURN jsonb_build_object('ok', false, 'reason', '二维码无效或已失效');
        END IF;
        IF v_row.expires_at < now() THEN
            RETURN jsonb_build_object('ok', false, 'reason', '二维码已过期，请在电脑上刷新');
        END IF;
        RETURN jsonb_build_object('ok', false, 'reason', '这个二维码已经被确认过了');
    END IF;

    SELECT username INTO v_name FROM public.profiles WHERE id = p_user_id;
    IF p_approve THEN
        RETURN jsonb_build_object('ok', true, 'username', coalesce(v_name, ''),
            'message', '已确认，电脑上会自动登录');
    END IF;
    RETURN jsonb_build_object('ok', true, 'message', '已取消');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_login_confirm(text, uuid, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_login_confirm(text, uuid, text, boolean) TO anon;


-- ------------------------------------------------------------
-- A4. 电脑端:轮询（确认后发一次令牌,原子）
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_login_poll(p_code text, p_secret text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code   text := upper(regexp_replace(coalesce(p_code, ''),   '[^0-9A-Fa-f]', '', 'g'));
    v_secret text := upper(regexp_replace(coalesce(p_secret, ''), '[^0-9A-Fa-f]', '', 'g'));
    v_row    record;
    v_name   text;
    v_tok    text;
BEGIN
    IF length(v_code) <> 16 OR length(v_secret) <> 32 THEN
        RETURN jsonb_build_object('ok', false, 'status', 'invalid');
    END IF;

    -- ⭐ code + secret 都要对。只有二维码(只有 code)的人拿不到令牌。
    SELECT * INTO v_row FROM public.qr_login_sessions
     WHERE code = v_code AND secret = v_secret AND kind = 'pc_login';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'status', 'invalid');
    END IF;

    IF v_row.status = 'pending' THEN
        IF v_row.expires_at < now() THEN
            RETURN jsonb_build_object('ok', true, 'status', 'expired');
        END IF;
        RETURN jsonb_build_object('ok', true, 'status', 'pending');
    END IF;
    IF v_row.status = 'cancelled' THEN
        RETURN jsonb_build_object('ok', true, 'status', 'cancelled');
    END IF;
    IF v_row.status = 'consumed' THEN
        RETURN jsonb_build_object('ok', true, 'status', 'consumed');
    END IF;

    UPDATE public.qr_login_sessions
       SET status = 'consumed', consumed_at = now()
     WHERE code = v_code AND secret = v_secret AND status = 'confirmed'
     RETURNING * INTO v_row;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', true, 'status', 'consumed');
    END IF;
    IF v_row.expires_at < now() THEN
        RETURN jsonb_build_object('ok', true, 'status', 'expired');
    END IF;

    SELECT username INTO v_name FROM public.profiles WHERE id = v_row.user_id;
    v_tok := public.create_user_session(v_row.user_id);
    RETURN jsonb_build_object('ok', true, 'status', 'ok',
        'id', v_row.user_id, 'username', coalesce(v_name, ''), 'token', v_tok);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'status', 'error', 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_login_poll(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_login_poll(text, text) TO anon;


-- ============================================================
-- ══════════ B · device_login：电脑授权设备 ══════════
-- ============================================================
-- ⚠️ 这个方向的 code 本身就是登录凭证。见文件头的安全说明。

-- ------------------------------------------------------------
-- B1. 电脑端(已登录):生成授权二维码
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_grant_create(
    p_user_id uuid, p_session text, p_ua text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_ip     text := public._request_ip();
    v_recent integer;
    v_code   text;
    v_secret text;
    v_name   text;
BEGIN
    -- ⭐ 必须已登录才发得出来
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '请先登录');
    END IF;

    DELETE FROM public.qr_login_sessions WHERE expires_at < now() - interval '1 hour';

    SELECT count(*) INTO v_recent FROM public.qr_login_sessions
     WHERE user_id = p_user_id AND kind = 'device_login'
       AND created_at > now() - interval '10 minutes';
    IF v_recent >= 10 THEN
        RETURN jsonb_build_object('ok', false, 'message', '生成太频繁，请稍后再试');
    END IF;

    v_code   := upper(substring(md5(random()::text || clock_timestamp()::text || p_user_id::text), 1, 16));
    v_secret := upper(substring(md5(clock_timestamp()::text || random()::text || v_ip), 1, 32));
    SELECT username INTO v_name FROM public.profiles WHERE id = p_user_id;

    -- ⭐ 有效期只给 90 秒:这段时间里谁扫到谁就能登进这个账号
    INSERT INTO public.qr_login_sessions
        (kind, code, secret, user_id, desktop_ua, desktop_ip, expires_at)
    VALUES ('device_login', v_code, v_secret, p_user_id,
            left(coalesce(p_ua, ''), 200), v_ip, now() + interval '90 seconds');

    RETURN jsonb_build_object(
        'ok', true, 'code', v_code, 'secret', v_secret,
        'username', coalesce(v_name, ''), 'ttl', 90,
        'url', 'https://github.nb-channel.top/Beta/qr-claim-Beta.html?c=' || v_code);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_grant_create(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_grant_create(uuid, text, text) TO anon;


-- ------------------------------------------------------------
-- B2. 手机端:先看"扫了会登成谁"
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_grant_info(p_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Fa-f]', '', 'g'));
    v_row  record;
    v_name text;
    v_mask text;
BEGIN
    IF length(v_code) <> 16 THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码无效');
    END IF;
    SELECT * INTO v_row FROM public.qr_login_sessions WHERE code = v_code AND kind = 'device_login';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码无效或已失效，请在电脑上刷新');
    END IF;
    IF v_row.expires_at < now() THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码已过期，请在电脑上刷新');
    END IF;
    IF v_row.status <> 'pending' THEN
        RETURN jsonb_build_object('ok', false, 'reason', '这个二维码已经被用过了');
    END IF;

    SELECT username INTO v_name FROM public.profiles WHERE id = v_row.user_id;
    -- 账号名做个遮挡:别把完整名字暴露给随手扫到的人
    v_mask := coalesce(v_name, '');
    IF length(v_mask) > 2 THEN
        v_mask := left(v_mask, 1) || repeat('*', length(v_mask) - 2) || right(v_mask, 1);
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'username_masked', v_mask,
        'desktop_ua', coalesce(v_row.desktop_ua, ''),
        'expires_in', greatest(0, extract(epoch from (v_row.expires_at - now()))::integer));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', '读取失败');
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_grant_info(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_grant_info(text) TO anon;


-- ------------------------------------------------------------
-- B3. 手机端:领走这个会话（原子,只能领一次）
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_grant_claim(p_code text, p_ua text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Fa-f]', '', 'g'));
    v_row  record;
    v_name text;
    v_tok  text;
BEGIN
    IF length(v_code) <> 16 THEN
        RETURN jsonb_build_object('ok', false, 'reason', '二维码无效');
    END IF;

    -- ⭐ 原子抢占:同一张码只有第一台设备能领到
    UPDATE public.qr_login_sessions
       SET status = 'consumed', consumed_at = now(),
           claim_ip = public._request_ip(),
           claim_ua = left(coalesce(p_ua, ''), 200)
     WHERE code = v_code AND kind = 'device_login'
       AND status = 'pending' AND expires_at > now()
     RETURNING * INTO v_row;

    IF NOT FOUND THEN
        SELECT * INTO v_row FROM public.qr_login_sessions WHERE code = v_code AND kind = 'device_login';
        IF NOT FOUND THEN
            RETURN jsonb_build_object('ok', false, 'reason', '二维码无效或已失效，请在电脑上刷新');
        END IF;
        IF v_row.expires_at < now() THEN
            RETURN jsonb_build_object('ok', false, 'reason', '二维码已过期，请在电脑上刷新一个');
        END IF;
        RETURN jsonb_build_object('ok', false, 'reason', '这个二维码已经被用过了，请让电脑上刷新一个');
    END IF;

    SELECT username INTO v_name FROM public.profiles WHERE id = v_row.user_id;
    v_tok := public.create_user_session(v_row.user_id);

    RETURN jsonb_build_object('ok', true,
        'id', v_row.user_id, 'username', coalesce(v_name, ''), 'token', v_tok);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_grant_claim(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_grant_claim(text, text) TO anon;


-- ------------------------------------------------------------
-- B4. 电脑端:看有没有被领走（只给自己看,不发令牌）
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qr_grant_status(p_code text, p_secret text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code   text := upper(regexp_replace(coalesce(p_code, ''),   '[^0-9A-Fa-f]', '', 'g'));
    v_secret text := upper(regexp_replace(coalesce(p_secret, ''), '[^0-9A-Fa-f]', '', 'g'));
    v_row    record;
BEGIN
    IF length(v_code) <> 16 OR length(v_secret) <> 32 THEN
        RETURN jsonb_build_object('ok', false, 'status', 'invalid');
    END IF;
    SELECT * INTO v_row FROM public.qr_login_sessions
     WHERE code = v_code AND secret = v_secret AND kind = 'device_login';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'status', 'invalid');
    END IF;
    IF v_row.status = 'consumed' THEN
        RETURN jsonb_build_object('ok', true, 'status', 'claimed',
            'claim_ip', coalesce(v_row.claim_ip, '未知'),
            'claim_ua', coalesce(v_row.claim_ua, ''),
            'at', to_char(coalesce(v_row.consumed_at, now()) AT TIME ZONE 'Asia/Shanghai', 'HH24:MI:SS'));
    END IF;
    IF v_row.status = 'cancelled' THEN
        RETURN jsonb_build_object('ok', true, 'status', 'cancelled');
    END IF;
    IF v_row.expires_at < now() THEN
        RETURN jsonb_build_object('ok', true, 'status', 'expired');
    END IF;
    RETURN jsonb_build_object('ok', true, 'status', 'pending');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'status', 'error');
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_grant_status(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_grant_status(text, text) TO anon;


-- ============================================================
-- 公共:取消（两个方向都能用,不挑 kind）
-- ============================================================
CREATE OR REPLACE FUNCTION public.qr_login_cancel(p_code text, p_secret text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_code   text := upper(regexp_replace(coalesce(p_code, ''),   '[^0-9A-Fa-f]', '', 'g'));
    v_secret text := upper(regexp_replace(coalesce(p_secret, ''), '[^0-9A-Fa-f]', '', 'g'));
BEGIN
    UPDATE public.qr_login_sessions
       SET status = 'cancelled'
     WHERE code = v_code AND secret = v_secret AND status = 'pending';
    RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.qr_login_cancel(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qr_login_cancel(text, text) TO anon;


-- ============================================================
-- 验收
-- ============================================================
SELECT p.proname AS 函数, pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND (p.proname LIKE 'qr\_login\_%' OR p.proname LIKE 'qr\_grant\_%')
 ORDER BY 1;
-- 期望 9 行

SELECT has_table_privilege('anon', 'public.qr_login_sessions', 'SELECT') AS anon_能读表_应为false;

SELECT kind AS 方向, status AS 状态, count(*) AS 条数
  FROM public.qr_login_sessions GROUP BY 1, 2 ORDER BY 1, 2;
-- 刚建完应该是 0 行
