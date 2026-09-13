-- ============================================================
-- 🟡 验证码发信加固:防止邮件配额被滥用耗尽
--
-- 背景:收到两封退信 —— 有人用不存在的邮箱调用了发码接口:
--         2026-09-10 21:38  uue@2026.com                     (对方域名无邮件服务器)
--         2026-09-12 09:14  nb-channel-is-make-bugs-machlne@cloudflare.nb-channel.top
--
--       注册流程本来就要给「用户填的任意邮箱」发码,所以这不是漏洞;
--       但现有的限频只按「单个邮箱」和「单个 IP 每小时」算,挡不住两类滥用:
--         · 换邮箱:每个邮箱每天 5 次,但邮箱可以无限换
--         · 换 IP:每 IP 每小时 10 次,但 IP 也可以换
--       后果很实际:163 免费邮箱每天的发送配额有限,被刷完 →
--       **所有正常用户都收不到验证码**;退信还会把你的邮箱淹没,
--       严重时网易会把发件账号判定为垃圾邮件来源。
--
-- 本文件新增两道闸:
--   ① 每个 IP 每天最多 20 封
--   ② 全站每天最多 200 封(保配额的最后一道防线)
--
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
    v_recent    int;
    v_mail_day  int;
    v_ip_hour   int;
    v_ip_day    int;
    v_site_day  int;
    v_has_ip    boolean;
BEGIN
    IF p_email IS NULL OR position('@' IN p_email) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '邮箱格式不正确');
    END IF;
    IF p_purpose NOT IN ('register', 'login', 'bind') THEN
        RETURN jsonb_build_object('ok', false, 'message', '未知用途');
    END IF;
    IF p_code_hash IS NULL OR length(trim(p_code_hash)) < 16 THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码哈希无效');
    END IF;

    v_has_ip := p_ip IS NOT NULL AND p_ip <> '' AND p_ip <> 'unknown';

    -- ① 同一邮箱 60 秒 1 次
    SELECT count(*) INTO v_recent FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '60 seconds';
    IF v_recent > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '发送太频繁,请 60 秒后再试');
    END IF;

    -- ② 同一邮箱每天 5 次
    SELECT count(*) INTO v_mail_day FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '1 day';
    IF v_mail_day >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱今日发送次数已达上限');
    END IF;

    IF v_has_ip THEN
        -- ③ 同一 IP 每小时 10 次
        SELECT count(*) INTO v_ip_hour FROM public.email_codes
         WHERE ip_address = p_ip AND created_at > now() - interval '1 hour';
        IF v_ip_hour >= 10 THEN
            RETURN jsonb_build_object('ok', false, 'message', '请求过于频繁,请稍后再试');
        END IF;

        -- ④ 新增:同一 IP 每天 20 次(挡住"换邮箱刷"的玩法)
        SELECT count(*) INTO v_ip_day FROM public.email_codes
         WHERE ip_address = p_ip AND created_at > now() - interval '1 day';
        IF v_ip_day >= 20 THEN
            RETURN jsonb_build_object('ok', false, 'message', '当前网络今日发送次数已达上限,请明天再试');
        END IF;
    END IF;

    -- ⑤ 新增:全站每天 200 次(保护发信配额,这个上限到了谁都发不了)
    SELECT count(*) INTO v_site_day FROM public.email_codes
     WHERE created_at > now() - interval '1 day';
    IF v_site_day >= 200 THEN
        RETURN jsonb_build_object('ok', false, 'message', '今日验证码发送量已达上限,请明天再试(或联系管理员)');
    END IF;

    -- ⚠️ 列名是 ip_address(不是 ip);expires_at 有默认值(10 分钟)
    INSERT INTO public.email_codes (email, purpose, code_hash, ip_address)
    VALUES (lower(p_email), p_purpose, p_code_hash, p_ip);

    RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

REVOKE ALL ON FUNCTION public.store_email_code(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text) TO anon;

-- ---------- 验收 ----------
-- 1) 函数里应包含新增的两道闸
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%v_ip_day%')   AS 有IP每日限制,
       (pg_get_functiondef(p.oid) LIKE '%v_site_day%') AS 有全站每日限制,
       (pg_get_functiondef(p.oid) LIKE '%ip_address%') AS 列名正确
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'store_email_code';

-- 2) 看看有没有被刷过:按小时统计发码量
SELECT date_trunc('hour', created_at) AS 小时,
       count(*) AS 发码条数,
       count(DISTINCT email) AS 不同邮箱,
       count(DISTINCT ip_address) AS 不同IP
  FROM public.email_codes
 GROUP BY 1
 ORDER BY 1 DESC
 LIMIT 20;

-- 3) 总量 + 今天已用掉多少配额
SELECT count(*) AS 历史总数,
       count(*) FILTER (WHERE created_at > now() - interval '1 day') AS 今天已发,
       count(DISTINCT email) AS 涉及邮箱数
  FROM public.email_codes;

-- 4) 有没有明显异常的邮箱(不存在/故意构造的)
SELECT email, count(*) AS 次数, min(created_at) AS 首次, max(created_at) AS 最近
  FROM public.email_codes
 GROUP BY email
 HAVING count(*) >= 3
 ORDER BY 2 DESC, 4 DESC
 LIMIT 20;

-- ---------- 5) 顺带清理:删掉 2 天前的旧码(表不用一直涨) ----------
DELETE FROM public.email_codes WHERE created_at < now() - interval '2 days';
