-- ============================================================
--  修：本地直通报 "function digest(text, unknown) does not exist"
--
--  【原因】digest() 属于 pgcrypto 扩展。
--      Supabase 上扩展装在 extensions 这个 schema，
--      而我那个 admin_create_session 写的是 SET search_path = public ——
--      所以函数体里找不到 digest。
--
--  【改法】两件事一起做，哪条路都通：
--      ① 确认 pgcrypto 装了，并且把 extensions 加进 search_path
--      ② 函数体里用【全限定名】调用，不靠 search_path
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：确认 pgcrypto 在不在，在哪
-- ============================================================
SELECT e.extname AS 扩展,
       n.nspname AS 装在哪,
       e.extversion AS 版本
  FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
 WHERE e.extname = 'pgcrypto';

-- 如果上面一行都没返回 → pgcrypto 没装，跑下面这句
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


-- ============================================================
-- 第 2 步：重建函数
--   ⚠️ 和上一版的差别只有两处：
--      · SET search_path = public, extensions   ← 加上了 extensions
--      · digest(...) 改成 extensions.digest(...)  ← 全限定名，双保险
--   其余逻辑一个字没动。
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_create_session(
    p_pwd          text,
    p_code         text,
    p_ip           text DEFAULT NULL,      -- 保留但不用（真实 IP 服务端自己读）
    p_local_secret text DEFAULT NULL       -- 本地直通：只有站长机器上那个密钥
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions       -- ⭐ 这里加了 extensions
AS $fn$
DECLARE
    v_ip      text := public._request_ip();
    v_ok      boolean;
    v_attempt integer;
    v_email   text;
    v_tok     uuid;
    v_v       jsonb;
    v_hash    text;
    v_mine    text;
    v_bypass  boolean := false;
BEGIN
    -- ---------- 限频（真实 IP）----------
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

    -- ---------- ① 先验密码（不管走哪条通道都要）----------
    SELECT public.check_admin_password_plain(p_pwd) INTO v_ok;
    IF NOT coalesce(v_ok, false) THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('success', false, 'message', '密码错误');
    END IF;

    -- ---------- ② 判断走哪条通道 ----------
    IF p_local_secret IS NOT NULL AND btrim(p_local_secret) <> '' THEN
        SELECT value INTO v_hash FROM public.admin_settings WHERE key = 'local_bypass_hash';
        IF v_hash IS NOT NULL THEN
            -- ⚠️ 用全限定名调用，不靠 search_path
            v_mine := encode(extensions.digest(btrim(p_local_secret), 'sha256'), 'hex');
            IF v_mine = lower(btrim(v_hash)) THEN
                v_bypass := true;
            END IF;
        END IF;
        -- ⚠️ 密钥不对【不报错、不记失败次数】—— 直接往下走验证码流程。
        --    否则拿 anon key 乱试的人可以靠提示来探测，
        --    也能靠这个把站长的 IP 打到限频里去。
    END IF;

    IF v_bypass THEN
        DELETE FROM public.admin_login_attempts WHERE ip_address = v_ip;
        v_tok := gen_random_uuid();
        INSERT INTO public.admin_sessions (token, expires_at)
        VALUES (v_tok, now() + interval '30 minutes');
        RETURN jsonb_build_object('success', true, 'token', v_tok::text, 'via', 'local');
    END IF;

    -- ---------- ③ 原来的通道：邮箱验证码 ----------
    IF p_code IS NULL OR btrim(p_code) = '' THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('success', false, 'need_code', true,
            'message', '请输入邮箱验证码');
    END IF;

    SELECT value INTO v_email FROM public.admin_settings WHERE key = 'admin_email';
    IF v_email IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '管理员邮箱未配置');
    END IF;

    v_v := public._verify_email_code(v_email, 'admin', btrim(p_code));
    IF NOT coalesce((v_v ->> 'ok')::boolean, false) THEN
        INSERT INTO public.admin_login_attempts (ip_address) VALUES (v_ip);
        RETURN jsonb_build_object('success', false,
            'message', coalesce(v_v ->> 'message', '验证码错误或已过期'));
    END IF;

    -- ---------- ④ 全过了：清失败记录，发 30 分钟会话 ----------
    DELETE FROM public.admin_login_attempts WHERE ip_address = v_ip;
    DELETE FROM public.email_codes WHERE email = lower(v_email) AND purpose = 'admin';

    v_tok := gen_random_uuid();
    INSERT INTO public.admin_sessions (token, expires_at)
    VALUES (v_tok, now() + interval '30 minutes');

    RETURN jsonb_build_object('success', true, 'token', v_tok::text, 'via', 'email');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.admin_create_session(text, text, text, text) TO anon, authenticated;


-- ============================================================
-- 第 3 步：验证 —— 直接算一遍，看 digest 通不通
-- ============================================================
-- 3.1 pgcrypto 在哪
SELECT 'pgcrypto 装在哪' AS 项目, n.nspname AS 值
  FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
 WHERE e.extname = 'pgcrypto';

-- 3.2 直接算一遍，和库里存的比对
--     ⚠️ 这里算的是【站长那份密钥】的 sha256
SELECT encode(extensions.digest('cF7oc1OdoZAmZnLISir4zInK8ckSeejHdKecvYiLqM0', 'sha256'), 'hex') AS 算出来的,
       lower((SELECT value FROM public.admin_settings WHERE key = 'local_bypass_hash'))     AS 库里存的;

-- 3.3 正式比对
SELECT CASE WHEN encode(extensions.digest('cF7oc1OdoZAmZnLISir4zInK8ckSeejHdKecvYiLqM0', 'sha256'), 'hex')
                 = lower((SELECT value FROM public.admin_settings WHERE key = 'local_bypass_hash'))
            THEN '✅ 对得上 —— 回后台填密码就能进'
            ELSE '❌ 对不上 —— 密钥和库里的哈希不是一对，告诉我' END AS 结论;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 后台登录框填密码 → 直接进去，不用验证码
--  · 公网那边照旧要邮箱验证码（没变）
-- ============================================================
