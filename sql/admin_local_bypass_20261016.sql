-- ============================================================
--  后台登录：加一条【本地直通】通道（站长要的「本地不用邮箱验证码」）
--
--  【为什么不能直接把验证码删掉】
--      admin_create_session 是用【公开的 anon key】从浏览器调的。
--      一旦去掉验证码校验，公网上任何人只要知道密码就能进后台 ——
--      两道锁变一道锁。所以不能删，只能【另开一条只有本地知道的通道】。
--
--  【怎么开的】
--      ① 站长机器上有一个 32 字节随机密钥（admin-local-secret.txt）
--      ② 数据库只存它的 sha256（这个文件里就有）
--      ③ admin-proxy.py（只在 127.0.0.1 监听）读密钥，
--         改写 HTML 时注入页面
--      ④ 登录时：本地 → 传密钥；公网 → 照旧传邮箱验证码
--      ⑤ 这个函数：密钥哈希对得上 → 跳过验证码；否则照旧
--
--  【安全边界】
--      · 密钥不在 __admin__.html 里（那文件哪天传上去也不怕）
--      · 密钥不在 git 里（.gitignore 已挡）
--      · 公网访问时页面里没有这个密钥，走的是原来的验证码流程
--      · 密钥比对用 sha256，且长度是 32 字节随机 —— 猜不到
--
--  ⚠️ 跑之前先把下面那个 __HASH__ 换成 admin-local-secret-留档.txt 里的哈希
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：把密钥的 sha256 存进 admin_settings
--   ⚠️ 下面这串是站长那份 admin-local-secret.txt 的 sha256
--      换了密钥就要重新跑这一段
-- ============================================================
INSERT INTO public.admin_settings (key, value)
VALUES ('local_bypass_hash', 'ba4f6622813f7501a8c80fc4a44a49cb6c927f7944b3eca68c5e39ddbc85bda5')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;


-- ============================================================
-- 第 2 步：改 admin_create_session
--   在原来的「密码 + 验证码」基础上，多一条「密码 + 本地密钥」
--   ⚠️ 参数只【新增】一个带默认值的 p_local_secret，
--      旧的调用方式（只传 p_pwd/p_code）完全不受影响。
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_create_session(
    p_pwd          text,
    p_code         text,
    p_ip           text DEFAULT NULL,      -- 保留但不用（真实 IP 服务端自己读）
    p_local_secret text DEFAULT NULL       -- ⭐ 本地直通：只有站长机器上那个密钥
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
    v_v       jsonb;
    v_hash    text;
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
    -- 传了 p_local_secret 且它的 sha256 和库里存的对得上 → 本地直通
    IF p_local_secret IS NOT NULL AND btrim(p_local_secret) <> '' THEN
        SELECT value INTO v_hash FROM public.admin_settings WHERE key = 'local_bypass_hash';
        IF v_hash IS NOT NULL
           AND encode(digest(btrim(p_local_secret), 'sha256'), 'hex') = lower(btrim(v_hash)) THEN
            v_bypass := true;
        END IF;
        -- ⚠️ 密钥不对【不报错、不记失败次数】—— 直接往下走验证码流程。
        --    否则拿 anon key 乱试的人可以靠「密钥对不对」的提示来探测，
        --    也能靠这个把站长的 IP 打到限频里去。
    END IF;

    IF v_bypass THEN
        -- 本地直通：跳过邮箱验证码，直接发会话
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

COMMENT ON FUNCTION public.admin_create_session(text, text, text, text) IS
    '后台登录。两条通道：①密码+邮箱验证码（公网）②密码+本地密钥（只在站长机器上，p_local_secret）。';


-- ============================================================
-- 第 3 步：验证
-- ============================================================
SELECT 项目, 值 FROM (
    SELECT 'admin_settings 里的密钥哈希' AS 项目,
           CASE WHEN EXISTS (SELECT 1 FROM public.admin_settings WHERE key = 'local_bypass_hash')
                THEN '✅ 已写入' ELSE '❌ 没有' END AS 值
    UNION ALL
    SELECT '函数里有没有 local_secret 分支',
           CASE WHEN EXISTS (
                    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                     WHERE n.nspname='public' AND p.prokind='f'
                       AND p.proname='admin_create_session'
                       AND position('local_bypass_hash' in pg_get_functiondef(p.oid)) > 0)
                THEN '✅ 有' ELSE '❌ 没有（第 2 步没成功）' END
    UNION ALL
    SELECT 'admin_create_session 有几个重载',
           (SELECT count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname='public' AND p.prokind='f' AND p.proname='admin_create_session')
           || ' 个（旧的 3 参版还在也没关系，前端会调 4 参那个）'
) t;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 公网访问后台：照旧要邮箱验证码（一个字没变）
--  · 本地访问后台（用「启动后台.bat」）：只填密码就能进
--  · 想换密钥：重新生成 → 更新 admin-local-secret.txt
--              → 改这一段第 1 步的哈希 → 重跑
--
--  ⚠️ 还要改两个本地文件才能真正生效（见下一条消息）：
--      admin-proxy.py   读密钥并注入页面
--      __admin__.html   本地时改用密钥登录
-- ============================================================
