-- ============================================================
-- 修复:验证码限频按"邮箱+用途"分别计算(bind 后立刻发 login 码不再被 60 秒拦截)
-- 在 Supabase SQL Editor 执行(覆盖 store_email_code)
-- ============================================================
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
    -- 同一邮箱 + 同一用途 60 秒内只能发一次(bind 后立即发 login 码不受影响)
    SELECT count(*) INTO v_n FROM public.email_codes
     WHERE email = lower(p_email) AND purpose = p_purpose
       AND created_at > now() - interval '60 seconds';
    IF v_n > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '发送太频繁,请 60 秒后再试');
    END IF;
    -- 同一邮箱每天最多 5 次(所有用途合计,防轰炸)
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
