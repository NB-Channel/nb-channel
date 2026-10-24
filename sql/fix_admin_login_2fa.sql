-- ============================================================
-- 管理员后台 登录加邮箱二次验证 + 修掉「假 IP 绕过限频」
-- ============================================================
-- 【这次修的两个问题】
--
-- 问题 1（你提的）：后台页 https://github.nb-channel.top/Website backend.html
--   任何人可访问。虽然进不去,但登录接口是公开的,密码可以被无限次尝试。
--   → 加邮箱二次验证：密码对了还要收到发到【你邮箱】的 6 位码。
--
-- 问题 2（我在代码里发现的,比问题 1 更严重）：
--   admin_create_session 的限频是按 p_ip 数的,而 p_ip 是【前端从
--   api.ipify.org 拿到后自己传上来的】—— 攻击者随便填个值就绕过：
--
--     POST /rest/v1/rpc/admin_create_session {"p_pwd":"123456","p_ip":"1.1.1.1"}
--     POST /rest/v1/rpc/admin_create_session {"p_pwd":"admin", "p_ip":"1.1.1.2"}
--     ...每次换个假 IP,「5 次/10 分钟」永远数不到 5
--
--   → 服务端自己从请求头读真实 IP,彻底不看前端传的那个参数。
--     注意：加了邮箱验证之后这个问题【仍然要修】——
--     因为「问一次密码对不对」这个动作本身还是能无限做,
--     等于把密码暴破出来（虽然还需要邮箱码才能登录,但密码就不该被问出来）。
--
-- 【为什么邮箱验证放在 SCF 而不是这里】
--   Postgres 发不了邮件。发信还是走原来那条链：
--     前端 → 腾讯 SCF(scf_mail_sender.py) → store_email_code → SMTP
--   本文件只提供 SCF 需要调的两个函数 + 最后签发会话。
--
-- 【万一邮箱通道坏了怎么办 —— 破窗办法】
--   你有 SQL 权限,直接手工造一个 30 分钟的会话就行：
--     INSERT INTO public.admin_sessions (token, expires_at)
--     VALUES (gen_random_uuid(), now() + interval '30 minutes')
--     RETURNING token;
--   把返回的 token 贴进浏览器 Console：
--     sessionStorage.setItem('admin_token', '<粘这里>'); location.reload();
--   这条不用改任何代码,永久可用。
--
-- 在 Supabase SQL Editor 执行（幂等）
-- ============================================================


-- ============================================================
-- 0. 管理员邮箱（写死在服务端,前端拿不到、也改不了）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.admin_settings (
    key        text PRIMARY KEY,
    value      text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;
-- ⚠️ 必须同时点名 anon / authenticated：
--    Supabase 是把权限直接授给这两个角色的,只 REVOKE FROM PUBLIC 不管用
REVOKE ALL ON public.admin_settings FROM anon, authenticated;

-- ⭐ 把下面这个邮箱改成你要收验证码的地址（默认和发信账号相同,发给自己）
INSERT INTO public.admin_settings (key, value) VALUES
    ('admin_email', 'nbchannel@163.com')
ON CONFLICT (key) DO NOTHING;


-- ============================================================
-- 1. 读真实 IP（服务端从请求头拿,不听前端的）
-- ============================================================
-- PostgREST 会把请求头塞进 request.headers 这个 GUC 里,函数能直接读。
-- 顺序：cf-connecting-ip（Cloudflare 写的,最可信）
--     → x-forwarded-for 最后一段（Supabase 边缘追加的）
--     → x-real-ip
CREATE OR REPLACE FUNCTION public._request_ip()
RETURNS text
LANGUAGE plpgsql STABLE
AS $fn$
DECLARE
    v_hdr  json;
    v_ip   text;
    v_xff  text;
BEGIN
    BEGIN
        v_hdr := current_setting('request.headers', true)::json;
    EXCEPTION WHEN OTHERS THEN
        v_hdr := NULL;
    END;
    IF v_hdr IS NULL THEN
        RETURN 'unknown';
    END IF;

    v_ip := nullif(btrim(v_hdr ->> 'cf-connecting-ip'), '');
    IF v_ip IS NOT NULL THEN RETURN v_ip; END IF;

    -- XFF 第一段是客户端可伪造的,取最后一段（由最近的代理追加）
    v_xff := v_hdr ->> 'x-forwarded-for';
    IF v_xff IS NOT NULL AND btrim(v_xff) <> '' THEN
        v_ip := nullif(btrim(reverse(split_part(reverse(v_xff), ',', 1))), '');
        IF v_ip IS NOT NULL THEN RETURN v_ip; END IF;
    END IF;

    v_ip := nullif(btrim(v_hdr ->> 'x-real-ip'), '');
    IF v_ip IS NOT NULL THEN RETURN v_ip; END IF;

    RETURN 'unknown';
END
$fn$;
REVOKE ALL ON FUNCTION public._request_ip() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 2. 第一步：验密码（过了才让 SCF 发码）
-- ============================================================
-- ⚠️ 这个函数就是「密码预言机」,必须自带限频,
--    而且限频只能按【服务端读到的真实 IP】算。
CREATE OR REPLACE FUNCTION public.admin_request_code(p_pwd text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_ip      text := public._request_ip();
    v_ok      boolean;
    v_attempt integer;
    v_email   text;
    v_ready   timestamptz;
BEGIN
    -- 每 IP 10 分钟最多 5 次;全站 10 分钟最多 30 次（IP 万一还能伪造也压得住）
    SELECT count(*) INTO v_attempt FROM public.admin_login_attempts
     WHERE ip_address = v_ip AND created_at > now() - interval '10 minutes';
    IF v_attempt >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '尝试次数过多，请10分钟后再试');
    END IF;

    SELECT count(*) INTO v_attempt FROM public.admin_login_attempts
     WHERE created_at > now() - interval '10 minutes';
    IF v_attempt >= 30 THEN
        RETURN jsonb_build_object('ok', false, 'message', '系统繁忙，请稍后再试');
    END IF;

    SELECT public.check_admin_password_plain(p_pwd) INTO v_ok;
    IF NOT coalesce(v_ok, false) THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('ok', false, 'message', '密码错误');
    END IF;

    SELECT value INTO v_email FROM public.admin_settings WHERE key = 'admin_email';
    IF v_email IS NULL OR position('@' in v_email) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '管理员邮箱未配置');
    END IF;

    -- 同一邮箱 60 秒内只能要一次码
    SELECT max(created_at) INTO v_ready FROM public.email_codes
     WHERE email = lower(v_email) AND purpose = 'admin';
    IF v_ready IS NOT NULL AND v_ready > now() - interval '60 seconds' THEN
        RETURN jsonb_build_object('ok', false,
            'message', '验证码刚刚发过，请 ' ||
                       ceil(60 - extract(epoch from (now() - v_ready)))::text || ' 秒后再试');
    END IF;

    -- ⚠️ 关键一步：把旧的 admin 码清掉。
    --    因为 store_email_code 有「同一邮箱每天最多 5 次」的硬上限,
    --    不清的话你一天只能进后台 5 次。admin 是管理员自己的邮箱,
    --    清掉旧码不影响任何用户（用户那条链走的是别的 purpose,碰不到）。
    DELETE FROM public.email_codes
     WHERE email = lower(v_email) AND purpose = 'admin';

    -- 密码对了不记失败记录;但也不在这里清空别的 IP 的记录
    RETURN jsonb_build_object('ok', true, 'message', '密码正确，正在发送验证码');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_request_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_request_code(text) TO anon;

-- 给 SCF 用的：拿管理员邮箱（SCF 用 anon key,所以单独开一个只返回邮箱的）
CREATE OR REPLACE FUNCTION public.admin_email_for_code()
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_email text;
BEGIN
    SELECT value INTO v_email FROM public.admin_settings WHERE key = 'admin_email';
    RETURN v_email;   -- 只吐一个邮箱地址,不吐任何别的东西
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_email_for_code() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_email_for_code() TO anon;


-- ============================================================
-- 3. 第二步：验密码 + 邮箱验证码 → 签发 30 分钟会话
-- ============================================================
-- 签名从 (text, text) 变成 (text, text, text)：多了必填的 p_code。
DROP FUNCTION IF EXISTS public.admin_create_session(text, text);

CREATE OR REPLACE FUNCTION public.admin_create_session(
    p_pwd  text,
    p_code text,          -- ⭐ 必填：邮箱收到的 6 位验证码
    p_ip   text DEFAULT NULL   -- 保留参数但不使用（兼容旧前端），真实 IP 服务端自己读
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_ip      text := public._request_ip();
    v_ok      boolean;
    v_attempt integer;
    v_email   text;
    v_tok     uuid;
    v_v       jsonb;      -- _verify_email_code 返回的是 jsonb,不是 boolean
BEGIN
    -- 限频（真实 IP）
    SELECT count(*) INTO v_attempt FROM public.admin_login_attempts
     WHERE ip_address = v_ip AND created_at > now() - interval '10 minutes';
    IF v_attempt >= 5 THEN
        RETURN jsonb_build_object('success', false, 'message', '尝试次数过多，请10分钟后再试');
    END IF;
    SELECT count(*) INTO v_attempt FROM public.admin_login_attempts
     WHERE created_at > now() - interval '10 minutes';
    IF v_attempt >= 30 THEN
        RETURN jsonb_build_object('success', false, 'message', '系统繁忙，请稍后再试');
    END IF;

    IF p_code IS NULL OR btrim(p_code) = '' THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('success', false, 'need_code', true,
            'message', '请输入邮箱验证码');
    END IF;

    -- ① 验密码
    SELECT public.check_admin_password_plain(p_pwd) INTO v_ok;
    IF NOT coalesce(v_ok, false) THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('success', false, 'message', '密码错误');
    END IF;

    SELECT value INTO v_email FROM public.admin_settings WHERE key = 'admin_email';
    IF v_email IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '管理员邮箱未配置');
    END IF;

    -- ② 验邮箱验证码（_verify_email_code 自带「10 分钟过期 + 错 5 次就锁 + 一次性」）
    v_v := public._verify_email_code(v_email, 'admin', btrim(p_code));
    IF NOT coalesce((v_v ->> 'ok')::boolean, false) THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('success', false,
            'message', coalesce(v_v ->> 'message', '验证码错误或已过期'));
    END IF;

    -- ③ 全过了：清掉这个 IP 的失败记录,发 30 分钟会话
    DELETE FROM public.admin_login_attempts WHERE ip_address = v_ip;
    -- 用过的码已经由 _verify_email_code 标了 used_at,留着不占额度（store_email_code 只数 created_at）
    DELETE FROM public.email_codes WHERE email = lower(v_email) AND purpose = 'admin';

    v_tok := gen_random_uuid();
    INSERT INTO public.admin_sessions (token, expires_at)
    VALUES (v_tok, now() + interval '30 minutes');

    RETURN jsonb_build_object('success', true, 'token', v_tok::text);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_create_session(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_session(text, text, text) TO anon;


-- ============================================================
-- 4. email_codes.purpose 允许 'admin'
-- ============================================================
-- 建表时 purpose 只是个普通 text 列（没有 CHECK），所以正常情况这里什么都不做。
-- 这段是兜底：万一以后有人给 purpose 加了取值约束，自动放宽到包含 'admin'，
-- 免得加个验证码还要先报错再去改约束。
DO $do$
DECLARE
    v_name text;
BEGIN
    FOR v_name IN
        SELECT con.conname
          FROM pg_constraint con
          JOIN pg_class rel ON rel.oid = con.conrelid
          JOIN pg_namespace n ON n.oid = rel.relnamespace
         WHERE n.nspname = 'public' AND rel.relname = 'email_codes'
           AND con.contype = 'c'
           AND pg_get_constraintdef(con.oid) LIKE '%purpose%'
    LOOP
        EXECUTE format('ALTER TABLE public.email_codes DROP CONSTRAINT %I', v_name);
        RAISE NOTICE '已移除 purpose 约束：%', v_name;
    END LOOP;

    -- 重新加一条宽松的（如果原来根本没有约束，这条也只是补上，不影响现有数据）
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint con
          JOIN pg_class rel ON rel.oid = con.conrelid
          JOIN pg_namespace n ON n.oid = rel.relnamespace
         WHERE n.nspname = 'public' AND rel.relname = 'email_codes'
           AND con.conname = 'email_codes_purpose_chk')
    THEN
        ALTER TABLE public.email_codes
            ADD CONSTRAINT email_codes_purpose_chk
            CHECK (purpose IN ('register', 'login', 'bind', 'admin'));
    END IF;
END
$do$;


-- ============================================================
-- 5. 验收
-- ============================================================

-- 5.1 管理员邮箱（应该只有一行,且是你自己的邮箱）
SELECT key AS 配置项, value AS 值 FROM public.admin_settings;

-- 5.2 函数签名
SELECT p.proname AS 函数, pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname IN ('admin_create_session','admin_request_code',
                     'admin_email_for_code','_request_ip')
 ORDER BY 1;
-- 期望 4 行,其中 admin_create_session 必须是 (text, text, text)
-- 如果还看到 (text, text) 的旧版本,再执行一次：
--   DROP FUNCTION IF EXISTS public.admin_create_session(text, text);

-- 5.3 确认没有别的 IP 参数能绕过（这个函数不该存在了）
SELECT count(*) AS 旧版本残留数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname = 'admin_create_session'
   AND pg_get_function_identity_arguments(p.oid) = 'text, text';
-- 期望 0

-- 5.4 看真实 IP 读得对不对（在后台页 Console 里跑一下也能验证）
-- SELECT public._request_ip();   -- 权限已收,只有 SECURITY DEFINER 内部能调

-- 5.5 登录失败记录（有没有人在撞你密码）
SELECT ip_address AS 来源IP, count(*) AS 次数,
       to_char(max(created_at) AT TIME ZONE 'Asia/Shanghai','MM-DD HH24:MI') AS 最近一次
  FROM public.admin_login_attempts
 WHERE created_at > now() - interval '24 hours'
 GROUP BY ip_address ORDER BY 2 DESC LIMIT 20;

-- 5.6 当前有效会话
SELECT token, to_char(expires_at AT TIME ZONE 'Asia/Shanghai','MM-DD HH24:MI') AS 到期
  FROM public.admin_sessions WHERE expires_at > now() ORDER BY expires_at;
