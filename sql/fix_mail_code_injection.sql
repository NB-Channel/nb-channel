-- ============================================================
-- 🔴 修「匿名可注入验证码 → 直接盗号」
-- ============================================================
-- 【漏洞】
--   store_email_code(p_email, p_purpose, p_code_hash, p_ip) 对 anon 开放,
--   而 p_code_hash 是【调用方提供的明文哈希】,从不校验来源。
--   登录第二步 login_finish(p_username, p_code) 又不需要密码。
--
--   于是:
--     1) store_email_code(受害者邮箱, 'login', md5('111111'), 假IP) → {"ok":true}
--     2) login_finish(受害者用户名, '111111')                       → 直接发会话令牌
--   不需要密码、不需要收邮件。实测第 1 步确实返回 {"ok": true}。
--
--   同一路径也能绕过后台的邮箱二次验证:
--     store_email_code(管理员邮箱,'admin',md5('111111')) + admin_create_session(正确密码,'111111')
--
-- 【为什么这么修】
--   整个仓库往 email_codes 表 INSERT 的地方只有 6 处,
--   全都在 store_email_code 的不同历史版本里 —— 它是唯一入口。
--   所以只要让「唯一的合法调用方(腾讯 SCF)」证明自己是它,洞就没了。
--
--   做法:SCF 在环境变量里放一个密钥,发码时带上;数据库比对不对就拒。
--   密钥永远不进浏览器,也不进这个文件（本文件在公开仓库里,
--   写死等于公开）—— 由数据库现生成,你复制到 SCF 环境变量。
--
-- 【灰度,不会弄坏发信】
--   mail_secret_required 默认 '0'。跑完这个文件,行为和你现在完全一样。
--   等你在 SCF 配好 MAIL_SECRET 并测通一封邮件之后,再把这个开关打成 '1'。
--   打错了改回 '0' 立刻恢复。
--
-- 在 Supabase SQL Editor 执行（幂等）
-- ============================================================


-- ============================================================
-- 1. 被拒绝的注入尝试（跑完能看见有没有人在试）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.mail_code_rejects (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text,
    purpose    text,
    ip_address text,
    reason     text,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.mail_code_rejects ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mail_code_rejects FROM anon, authenticated;
CREATE INDEX IF NOT EXISTS mail_code_rejects_idx ON public.mail_code_rejects (created_at DESC);


-- ============================================================
-- 2. 生成密钥 + 灰度开关
-- ============================================================
-- ⚠️ 密钥由数据库现生成,不写在本文件里（本文件在公开仓库中）
INSERT INTO public.admin_settings (key, value) VALUES
    ('mail_secret',
     upper(md5(random()::text || clock_timestamp()::text || pg_backend_pid()::text))
     || upper(md5(clock_timestamp()::text || random()::text || 'nb-mail-v1'))),
    ('mail_secret_required', '0')       -- 先关着,等你 SCF 配好再打开
ON CONFLICT (key) DO NOTHING;


-- ============================================================
-- 3. 套上密钥校验
-- ============================================================
-- ① 先删掉旧的 4 参数版本。
--    不删的话 PostgREST 会看到两个重载,攻击者直接调旧的那个就绕开了。
DROP FUNCTION IF EXISTS public.store_email_code(text, text, text, text);

-- ② 新版本：多一个 p_secret。
--    给它默认值,这样不带密钥的旧调用仍然能「匹配到函数」,
--    只是会被校验拒掉 —— 比报「函数不存在」更好排查。
CREATE OR REPLACE FUNCTION public.store_email_code(
    p_email text, p_purpose text, p_code_hash text, p_ip text DEFAULT NULL,
    p_secret text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_secret text;
    v_need   boolean;
BEGIN
    SELECT value INTO v_secret FROM public.admin_settings WHERE key = 'mail_secret';
    SELECT coalesce(value, '0') = '1' INTO v_need
      FROM public.admin_settings WHERE key = 'mail_secret_required';

    -- ⭐ 总闸：只有拿得出密钥的调用方（腾讯 SCF）才能发码
    IF coalesce(v_need, false) THEN
        IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
            INSERT INTO public.mail_code_rejects (email, purpose, ip_address, reason)
            VALUES (left(coalesce(p_email, ''), 120), left(coalesce(p_purpose, ''), 20),
                    left(coalesce(p_ip, ''), 60),
                    CASE WHEN p_secret IS NULL THEN '没带密钥' ELSE '密钥不对' END);
            RETURN jsonb_build_object('ok', false, 'message', '未授权的发码请求');
        END IF;
    END IF;

    -- 原来套壳里的域名黑名单校验,保留
    IF public._email_domain_banned(p_email) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该邮箱域名属于一次性临时邮箱,请使用常用邮箱注册');
    END IF;

    -- 转交原来那个带全部限频逻辑的函数
    -- （v_ip_hour / v_ip_day / v_site_day 都还在它里面,没被覆盖）
    RETURN public._orig_store_email_code(p_email, p_purpose, p_code_hash, p_ip);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

REVOKE ALL ON FUNCTION public.store_email_code(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text, text) TO anon;


-- ============================================================
-- 4. 验收
-- ============================================================

-- 4.1 ⭐ 复制这一行的值 → 填到 SCF 的 MAIL_SECRET 环境变量
SELECT value AS "把这个填到 SCF 的 MAIL_SECRET"
  FROM public.admin_settings WHERE key = 'mail_secret';

-- 4.2 灰度开关（跑完应该还是 0）
SELECT key AS 配置项, value AS 值 FROM public.admin_settings
 WHERE key = 'mail_secret_required';

-- 4.3 函数签名（旧的 4 参数版本不该存在）
SELECT p.proname AS 函数, pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname IN ('store_email_code', '_orig_store_email_code')
 ORDER BY 1;
-- 期望两行：
--   _orig_store_email_code | text, text, text, text
--   store_email_code       | text, text, text, text, text

-- 4.4 确认 _orig_store_email_code 匿名调不到（这道必须封死）
SELECT has_function_privilege('anon',
       'public._orig_store_email_code(text,text,text,text)', 'EXECUTE') AS anon_可调_应为false;


-- ============================================================
-- 5. 配好 SCF 之后：打开开关
-- ============================================================
-- 第 1 步：腾讯云 SCF → scf_mail_sender → 函数配置 → 环境变量
--           变量名  MAIL_SECRET
--           变量值  上面 4.1 查出来的那 64 位
--         保存后必须点【部署】才生效。
--
-- 第 2 步：去网站注册页真发一次验证码,确认能收到。
--
-- 第 3 步：确认能收到之后,回来跑这句打开总闸：
--
--   UPDATE public.admin_settings SET value = '1', updated_at = now()
--    WHERE key = 'mail_secret_required';
--
-- ⚠️ 万一打开之后收不到验证码 → 立刻改回 '0' 恢复：
--
--   UPDATE public.admin_settings SET value = '0', updated_at = now()
--    WHERE key = 'mail_secret_required';


-- ============================================================
-- 6. 打开开关后的自检（模拟攻击者,不带密钥）
-- ============================================================
DO $do$
DECLARE v_r jsonb;
BEGIN
    v_r := public.store_email_code(
        'zz-probe@nb-channel.top', 'login',
        md5('111111'), '203.0.113.99', NULL);      -- ⭐ 故意不带密钥
    IF (v_r ->> 'ok')::boolean IS TRUE THEN
        RAISE NOTICE '❌ 不带密钥仍然能发码 —— 开关还没打开吧？返回: %', v_r;
    ELSE
        RAISE NOTICE '✅ 已拦截: %', v_r;
    END IF;
    DELETE FROM public.mail_code_rejects WHERE ip_address = '203.0.113.99';
END
$do$;

-- 6.2 有没有人在试着注入（装上之后定期看一眼）
SELECT to_char(created_at AT TIME ZONE 'Asia/Shanghai','MM-DD HH24:MI') AS 时间,
       email AS 目标邮箱, purpose AS 用途, ip_address AS 来源IP, reason AS 原因
  FROM public.mail_code_rejects
 ORDER BY id DESC LIMIT 50;

-- 6.3 清理：漏洞还在时可能被塞进去的假码 + 我探测留下的记录
SELECT id, email, purpose, ip_address,
       to_char(created_at AT TIME ZONE 'Asia/Shanghai','MM-DD HH24:MI') AS 时间
  FROM public.email_codes
 WHERE used_at IS NULL AND expires_at > now()
 ORDER BY id DESC LIMIT 50;
-- 看着不对的按 id 删：DELETE FROM public.email_codes WHERE id = <id>;

-- 我探测时插的那条假记录（可以直接跑）
DELETE FROM public.email_codes WHERE email = 'zz-probe@nb-channel.top';
