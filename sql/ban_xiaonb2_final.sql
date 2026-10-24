-- ============================================================
-- 小NB2 收口:封 IP + 掐掉他的一次性邮箱域名
--
-- 【已查明】
--   账号 : 小NB2  7c112908-8e5e-487a-885a-49a2f318aeec
--   邮箱 : eyir59ii21@ruutukf.com      ← 一次性临时邮箱(temp-mail.io 家族)
--   IP   : 36.4.58.101                 ← 中国电信 安徽合肥 ASN 4134
--   要码 : 01:40:48 / 01:49:30 / 01:52:14 UTC,01:52:37 注册成功
--
-- 【为什么重点不是 IP】
--   他的历史 IP 全是「中国移动」(安徽阜阳/北京/浙江杭州/河南郑州),
--   这次换成「中国电信·安徽合肥」—— 他在切网络。
--   而站长自己的 IP 横跨湖南/内蒙古,同样在漫游。
--   → 归属地不是可靠身份信号;而且家宽 IPv4 是动态的,封单个 IP 他重拨就换掉。
--   真正稳定的识别物是那个一次性邮箱域名:他不换域名就注册不了,
--   换了域名我们也能继续拉黑 —— 这是一场我们必胜的消耗战。
--
-- 【本文件做四件事】
--   ① 把 36.4.58.101 加进 IP 黑名单(仍是有效的即时封堵)
--   ② 建「一次性邮箱域名黑名单」表 + 收录 ruutukf.com
--   ③ 发码处拦(store_email_code)—— 他连验证码都收不到,还省邮件配额
--   ④ 注册处拦(register_finish)+ 记录注册 IP
--
-- 在 Supabase SQL Editor 整段执行(幂等)
-- ============================================================


-- ============================================================
-- ① 封掉他的 IP
-- ============================================================
-- 只封这一个地址,不封 /24 —— 电信家宽同段可能住着别的真实用户。
-- (动态 IP 他重拨就能换,所以这条是即时封堵,不是长久之计)
INSERT INTO public.banned_ips (ip, reason)
VALUES ('36.4.58.101', '小NB2(小NB官号小号) 注册来源IP')
ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;


-- ============================================================
-- ② 一次性邮箱域名黑名单
-- ============================================================
CREATE TABLE IF NOT EXISTS public.banned_email_domains (
    domain     text PRIMARY KEY,
    reason     text DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.banned_email_domains ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.banned_email_domains FROM anon, authenticated;

-- 收录本次这个,再补一批常见的临时邮箱域名打底。
-- 以后遇到新的,往这张表里加一行即可(文件末尾有现成语句)。
INSERT INTO public.banned_email_domains (domain, reason) VALUES
  ('ruutukf.com',       '小NB2 使用的一次性临时邮箱(temp-mail.io)'),
  -- 以下为常见一次性邮箱服务,打底用
  ('temp-mail.org',     '常见一次性邮箱'),
  ('tempmail.com',      '常见一次性邮箱'),
  ('tempmail.net',      '常见一次性邮箱'),
  ('tempmailo.com',     '常见一次性邮箱'),
  ('10minutemail.com',  '常见一次性邮箱'),
  ('10minutemail.net',  '常见一次性邮箱'),
  ('guerrillamail.com', '常见一次性邮箱'),
  ('guerrillamail.info','常见一次性邮箱'),
  ('sharklasers.com',   '常见一次性邮箱'),
  ('grr.la',            '常见一次性邮箱'),
  ('mailinator.com',    '常见一次性邮箱'),
  ('yopmail.com',       '常见一次性邮箱'),
  ('trashmail.com',     '常见一次性邮箱'),
  ('getnada.com',       '常见一次性邮箱'),
  ('dispostable.com',   '常见一次性邮箱'),
  ('maildrop.cc',       '常见一次性邮箱'),
  ('mailnesia.com',     '常见一次性邮箱'),
  ('fakeinbox.com',     '常见一次性邮箱'),
  ('spam4.me',          '常见一次性邮箱'),
  ('discard.email',     '常见一次性邮箱'),
  ('moakt.com',         '常见一次性邮箱'),
  ('mohmal.com',        '常见一次性邮箱'),
  ('emailondeck.com',   '常见一次性邮箱'),
  ('tempr.email',       '常见一次性邮箱'),
  ('1secmail.com',      '常见一次性邮箱'),
  ('1secmail.net',      '常见一次性邮箱'),
  ('1secmail.org',      '常见一次性邮箱'),
  ('dropmail.me',       '常见一次性邮箱'),
  ('throwawaymail.com', '常见一次性邮箱')
ON CONFLICT (domain) DO UPDATE SET reason = EXCLUDED.reason;

-- 判断函数:取 @ 后面那段,小写比较
CREATE OR REPLACE FUNCTION public._email_domain_banned(p_email text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_domain text;
BEGIN
    IF p_email IS NULL OR position('@' IN p_email) = 0 THEN
        RETURN false;   -- 邮箱格式不对时不在这里拦,交给原来的格式校验
    END IF;
    v_domain := lower(btrim(split_part(p_email, '@', 2)));
    IF v_domain = '' THEN
        RETURN false;
    END IF;
    RETURN EXISTS (SELECT 1 FROM public.banned_email_domains d WHERE d.domain = v_domain);
END
$fn$;

REVOKE ALL ON FUNCTION public._email_domain_banned(text) FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ③ 发码处拦截:包裹 store_email_code
-- ============================================================
-- 这个函数历史版本很多(6 个 SQL 文件都重写过它),手抄容易漏掉
-- 后来加的两道限额(v_ip_day / v_site_day)。所以**不动它的函数体**,
-- 改成「改名 + 套一层壳」:壳里查域名黑名单,过了再转交原函数。
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = '_orig_store_email_code')
    THEN
        ALTER FUNCTION public.store_email_code(text, text, text, text)
          RENAME TO _orig_store_email_code;
        REVOKE ALL ON FUNCTION public._orig_store_email_code(text, text, text, text)
          FROM PUBLIC, anon, authenticated;
        RAISE NOTICE '✅ store_email_code 已改名,准备套壳';
    ELSE
        RAISE NOTICE 'ℹ️ 壳已存在,只更新壳本身';
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.store_email_code(
    p_email text, p_purpose text, p_code_hash text, p_ip text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF public._email_domain_banned(p_email) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该邮箱域名属于一次性临时邮箱,请使用常用邮箱注册');
    END IF;
    RETURN public._orig_store_email_code(p_email, p_purpose, p_code_hash, p_ip);
END
$fn$;

REVOKE ALL ON FUNCTION public.store_email_code(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text) TO anon;


-- ============================================================
-- ③.5 确保取 IP / 查 IP 黑名单这两个函数存在
-- ============================================================
-- 本文件刻意做成自包含:即使你还没跑 fix_registration_ip_block.sql,
-- 这里也会把两个函数补上 —— 否则 register_finish 一调用就报
-- "function public._client_ips() does not exist",注册直接挂掉。
CREATE OR REPLACE FUNCTION public._client_ips()
RETURNS text[]
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    v_h   jsonb;
    v_raw text;
    v_out text[] := ARRAY[]::text[];
    v_x   text;
BEGIN
    BEGIN
        v_h := current_setting('request.headers', true)::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN v_out;
    END;
    IF v_h IS NULL THEN RETURN v_out; END IF;

    v_raw := coalesce(v_h ->> 'x-forwarded-for', v_h ->> 'cf-connecting-ip');
    IF v_raw IS NULL OR btrim(v_raw) = '' THEN RETURN v_out; END IF;

    FOREACH v_x IN ARRAY string_to_array(v_raw, ',') LOOP
        v_x := btrim(v_x);
        IF v_x <> '' THEN v_out := v_out || v_x; END IF;
    END LOOP;
    RETURN v_out;
END
$fn$;

REVOKE ALL ON FUNCTION public._client_ips() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._ip_banned(p_ips text[])
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_ip  text;
    v_p64 text;
BEGIN
    IF p_ips IS NULL OR array_length(p_ips, 1) IS NULL THEN
        RETURN false;   -- 拿不到 IP 时一律放行,绝不误伤正常用户
    END IF;

    FOREACH v_ip IN ARRAY p_ips LOOP
        IF EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = v_ip) THEN
            RETURN true;
        END IF;
        IF v_ip LIKE '%:%' THEN
            v_p64 := split_part(v_ip, ':', 1) || ':' || split_part(v_ip, ':', 2) || ':'
                  || split_part(v_ip, ':', 3) || ':' || split_part(v_ip, ':', 4);
            IF EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = v_p64 || '::/64') THEN
                RETURN true;
            END IF;
        END IF;
    END LOOP;
    RETURN false;
END
$fn$;

REVOKE ALL ON FUNCTION public._ip_banned(text[]) FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ④ 注册处拦截 + 记录注册 IP:重建 register_finish
-- ============================================================
-- 域名黑名单 + IP 黑名单 两道都查,IP 用 request.headers 自己抓
-- (registration_attempts 从 09-09 起就没人写了,原因见 fix_registration_ip_block.sql)。
-- 原逻辑一字未改,只在前面插入检查。
CREATE OR REPLACE FUNCTION public.register_finish(p_username text, p_password text, p_email text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_chk  jsonb;
    v_uid  uuid;
    v_exist uuid;
    v_ips  text[];
    v_last text;
BEGIN
    -- ---------- 拦截 1:一次性邮箱域名 ----------
    IF public._email_domain_banned(p_email) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该邮箱域名属于一次性临时邮箱,请使用常用邮箱注册');
    END IF;

    -- ---------- 拦截 2:被封 IP ----------
    v_ips  := public._client_ips();
    v_last := CASE WHEN array_length(v_ips, 1) IS NULL THEN NULL
                   ELSE v_ips[array_length(v_ips, 1)] END;

    -- 记录注册 IP(以前这步是后端做的,09-09 起断了)
    IF v_last IS NOT NULL THEN
        BEGIN
            INSERT INTO public.registration_attempts (ip_address) VALUES (v_last);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '注册IP记录失败(不影响注册): %', SQLERRM;
        END;
    END IF;

    IF public._ip_banned(v_ips) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该网络已被限制注册,如有疑问请联系管理员');
    END IF;

    -- ---------- 以下为原逻辑,未改动 ----------
    v_chk := public._verify_email_code(p_email, 'register', p_code);
    IF NOT (v_chk ->> 'ok')::boolean THEN
        RETURN v_chk;
    END IF;
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


-- ============================================================
-- ⑤ 捞整个小号群
-- ============================================================
-- 1) 全站邮箱域名使用统计 —— 看还有谁在用一次性邮箱
--    账号数 > 1 的域名尤其可疑
SELECT split_part(lower(email), '@', 2) AS 邮箱域名,
       count(*) AS 账号数,
       string_agg(username, ', ' ORDER BY created_at) AS 账号,
       bool_or(is_banned) AS 有封禁账号,
       bool_or(split_part(lower(p.email), '@', 2) IN
               (SELECT d.domain FROM public.banned_email_domains d)) AS 已拉黑
  FROM public.profiles p
 WHERE email IS NOT NULL AND position('@' IN email) > 0
 GROUP BY 1
 ORDER BY 账号数 DESC, 1
 LIMIT 50;

-- 2) 和 小NB2 同一个 IP 还有哪些账号(= 他的其它小号)
SELECT DISTINCT p.username AS 用户名, p.id, p.created_at AS 注册时间, p.is_banned AS 已封, p.email
  FROM public.email_codes ec
  JOIN public.profiles p ON lower(p.email) = lower(ec.email)
 WHERE ec.ip_address = '36.4.58.101'
 ORDER BY p.created_at;

-- 3) 和 小NB2 同一个邮箱域名还有哪些账号
SELECT username AS 用户名, id, created_at AS 注册时间, is_banned AS 已封, email
  FROM public.profiles
 WHERE lower(email) LIKE '%@ruutukf.com'
 ORDER BY created_at;


-- ============================================================
-- ⑥ 验收
-- ============================================================
-- 1) 域名黑名单是否就位(应返回 true)
SELECT public._email_domain_banned('test@ruutukf.com') AS ruutukf已拉黑,
       public._email_domain_banned('test@qq.com')      AS qq邮箱正常放行;

-- 2) 两个函数是否都装了域名检查(都应 true)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%_email_domain_banned%') AS 已查域名黑名单
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('store_email_code', 'register_finish')
 ORDER BY 1;

-- 3) 壳是否包对了(_orig_store_email_code 应该存在)
SELECT p.proname AS 函数, pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '%store_email_code%'
 ORDER BY 1;

-- 4) IP 黑名单
SELECT id, ip, reason FROM public.banned_ips ORDER BY id;


-- ============================================================
-- ⑦ 以后遇到新的临时邮箱,加一行即可
-- ============================================================
-- INSERT INTO public.banned_email_domains (domain, reason)
-- VALUES ('新的临时邮箱域名.com', '小NB 系列使用')
-- ON CONFLICT (domain) DO UPDATE SET reason = EXCLUDED.reason;
