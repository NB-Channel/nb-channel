-- ============================================================
-- 修复验证码校验的潜在绕过(NULL 短路)+ 顺带加固登录
--
-- 问题:_verify_email_code 里的判断是
--         IF v_row.code_hash <> md5(coalesce(p_code,'')) THEN ... 报错 ...
--       如果某条验证码记录的 code_hash 是 NULL,这个比较的结果是 NULL(不是 true),
--       PL/pgSQL 的 IF 只在条件为 true 时进入,于是会**跳过报错分支**,
--       直接执行下面的「标记已使用 + 返回 ok」→ 任意验证码都能通过。
--
--       什么情况下会有 NULL:早期数据、或某个写入路径漏传了 hash。
--
-- 修法:① 校验函数显式判 NULL;② 存储函数拒绝 NULL hash(从源头堵住)
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

-- ---------- 1) 校验函数:显式处理 NULL ----------
CREATE OR REPLACE FUNCTION public._verify_email_code(p_email text, p_purpose text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_row public.email_codes%ROWTYPE;
    v_hash text;
BEGIN
    SELECT * INTO v_row FROM public.email_codes
     WHERE email = lower(p_email) AND purpose = p_purpose
       AND used_at IS NULL
     ORDER BY created_at DESC LIMIT 1;

    IF v_row.id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码不存在,请重新获取');
    END IF;
    IF v_row.expires_at < now() THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码已过期,请重新获取');
    END IF;
    IF v_row.attempts >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '尝试次数过多,请重新获取验证码');
    END IF;

    -- 关键修复:code_hash 为空一律视为无效,绝不能因为 NULL 比较而放行
    v_hash := md5(coalesce(p_code, ''));
    IF v_row.code_hash IS NULL
       OR v_row.code_hash = ''
       OR v_row.code_hash <> v_hash THEN
        UPDATE public.email_codes SET attempts = attempts + 1 WHERE id = v_row.id;
        RETURN jsonb_build_object('ok', false, 'message', '验证码错误');
    END IF;

    UPDATE public.email_codes SET used_at = now() WHERE id = v_row.id;
    RETURN jsonb_build_object('ok', true);
END
$fn$;
-- 注意:必须显式写 anon / authenticated —— Supabase 给这两个角色是单独授权的,
-- 只 REVOKE FROM PUBLIC 等于没锁(这正是 create_user_session 出漏洞的原因)
REVOKE ALL ON FUNCTION public._verify_email_code(text, text, text) FROM PUBLIC, anon, authenticated;

-- ---------- 2) 存储函数:拒绝空 hash ----------
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
    v_id     bigint;
BEGIN
    IF p_email IS NULL OR position('@' IN p_email) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '邮箱格式不正确');
    END IF;
    IF p_purpose NOT IN ('register', 'login', 'bind') THEN
        RETURN jsonb_build_object('ok', false, 'message', '未知用途');
    END IF;
    -- 从源头堵住空哈希
    IF p_code_hash IS NULL OR length(trim(p_code_hash)) < 16 THEN
        RETURN jsonb_build_object('ok', false, 'message', '验证码哈希无效');
    END IF;

    -- 限频:60 秒 1 次 / 每天 5 次 / 每 IP 每小时 10 次
    SELECT count(*) INTO v_recent FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '60 seconds';
    IF v_recent > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '发送太频繁,请 60 秒后再试');
    END IF;

    SELECT count(*) INTO v_today FROM public.email_codes
     WHERE email = lower(p_email) AND created_at > now() - interval '1 day';
    IF v_today >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱今日发送次数已达上限');
    END IF;

    IF p_ip IS NOT NULL AND p_ip <> '' AND p_ip <> 'unknown' THEN
        SELECT count(*) INTO v_ip_cnt FROM public.email_codes
         WHERE ip = p_ip AND created_at > now() - interval '1 hour';
        IF v_ip_cnt >= 10 THEN
            RETURN jsonb_build_object('ok', false, 'message', '请求过于频繁,请稍后再试');
        END IF;
    END IF;

    INSERT INTO public.email_codes (email, purpose, code_hash, ip, expires_at)
    VALUES (lower(p_email), p_purpose, p_code_hash, p_ip, now() + interval '10 minutes')
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('ok', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

-- 权限:只允许内部/后端调用(保持与原状一致)
REVOKE ALL ON FUNCTION public.store_email_code(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_email_code(text, text, text, text) TO anon;

-- ---------- 3) 验收/排查 ----------
-- 3.1 有没有空哈希的历史记录(有的话必须清理)
SELECT count(*) FILTER (WHERE code_hash IS NULL OR code_hash = '') AS 空哈希记录数,
       count(*) AS 总记录数
  FROM public.email_codes;

-- 3.2 顺手清掉空的(它们本来也不该存在)
DELETE FROM public.email_codes WHERE code_hash IS NULL OR code_hash = '';

-- 3.3 确认函数已更新(false = 已修复)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%v_row.code_hash IS NULL%') AS 已显式判空
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '_verify_email_code';
