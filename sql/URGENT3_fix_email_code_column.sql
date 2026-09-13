-- ============================================================
-- 🔴 紧急修复:验证码发送报错 column "ip" does not exist
--
-- 原因:我上一版重写 store_email_code 时,凭印象写了 INSERT 的列名 ip,
--       而 email_codes 表的真实列名是 ip_address(见 email_code.sql 里的建表语句)。
--       结果发验证码时报列不存在 → 登录/注册都收不到验证码。
--
-- 本文件用正确的列名重写该函数,并把限频逻辑保留(60 秒 / 每天 5 次 / 每 IP 每小时 10 次)。
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

CREATE OR REPLACE FUNCTION public.store_email_code(
    p_email text, p_purpose text, p_code_hash text, p_ip text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_recent int;
    v_today  int;
    v_ip_cnt int;
BEGIN
    IF p_email IS NULL OR position('@' IN p_email) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '邮箱格式不正确');
    END IF;
    IF p_purpose NOT IN ('register', 'login', 'bind') THEN
        RETURN jsonb_build_object('ok', false, 'message', '未知用途');
    END IF;
    -- 从源头拒绝空哈希(否则验证码校验会被 NULL 短路绕过)
    IF p_code_hash IS NULL OR length(trim(p_code_hash)) < 16 THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码哈希无效');
    END IF;

    -- 限频:同一邮箱 60 秒 1 次
    SELECT count(*) INTO v_recent FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '60 seconds';
    IF v_recent > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '发送太频繁,请 60 秒后再试');
    END IF;

    -- 限频:同一邮箱每天最多 5 次
    SELECT count(*) INTO v_today FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '1 day';
    IF v_today >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱今日发送次数已达上限');
    END IF;

    -- 限频:同一 IP 每小时最多 10 次
    IF p_ip IS NOT NULL AND p_ip <> '' AND p_ip <> 'unknown' THEN
        SELECT count(*) INTO v_ip_cnt FROM public.email_codes
         WHERE ip_address = p_ip AND created_at > now() - interval '1 hour';
        IF v_ip_cnt >= 10 THEN
            RETURN jsonb_build_object('ok', false, 'message', '请求过于频繁,请稍后再试');
        END IF;
    END IF;

    -- ⚠️ 列名是 ip_address(不是 ip);expires_at 有默认值(10 分钟),这里不用写
    INSERT INTO public.email_codes (email, purpose, code_hash, ip_address)
    VALUES (lower(p_email), p_purpose, p_code_hash, p_ip);

    RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

-- 权限:SCF 云函数用 anon key 调用,需要保留 anon
REVOKE ALL ON FUNCTION public.store_email_code(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text) TO anon;

-- ---------- 验收 ----------
-- 1) 函数里应该出现 ip_address,不该再出现裸 ip
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%ip_address%') AS 用了正确列名
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'store_email_code';

-- 2) 表的真实列名(对照用)
SELECT column_name AS 列名, data_type AS 类型
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'email_codes'
 ORDER BY ordinal_position;

-- 3) 顺便确认邮箱验证码校验函数也已是修复后的版本(判断 NULL 的写法)
SELECT p.proname AS 校验函数,
       (pg_get_functiondef(p.oid) LIKE '%code_hash IS NULL%') AS 已显式判空
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '_verify_email_code';
