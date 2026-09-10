-- ============================================================
-- 验证码限频:只保留「同一邮箱 + 同一用途 60 秒一次」
-- 去掉「每邮箱每天 5 次」和「每 IP 每小时 10 次」
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
    -- 唯一限制:同一邮箱 + 同一用途 60 秒内只能发一次
    SELECT count(*) INTO v_n FROM public.email_codes
     WHERE email = lower(p_email) AND purpose = p_purpose
       AND created_at > now() - interval '60 seconds';
    IF v_n > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '发送太频繁,请 60 秒后再试');
    END IF;
    INSERT INTO public.email_codes (email, purpose, code_hash, ip_address)
    VALUES (lower(p_email), p_purpose, p_code_hash, p_ip);
    RETURN jsonb_build_object('ok', true);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text) TO anon;

-- 清掉今天已发的记录,立刻恢复发送额度(可选)
DELETE FROM public.email_codes WHERE created_at > now() - interval '1 day';
