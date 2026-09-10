-- ============================================================
-- 写权限全面收口:把 4 张还能被匿名写的表锁掉
-- 配合前端改动:auto-support 规则的增删改改成令牌 RPC
-- 执行顺序:先让前端上线(已推送),再跑本文件
-- ============================================================

-- ---------- 1) 自动支持规则的三个 RPC(带会话令牌校验) ----------

-- 设置规则(先删同公司旧规则,再插入)
CREATE OR REPLACE FUNCTION public.set_support_rule(
    p_user_id uuid, p_session text, p_company_id bigint, p_threshold numeric, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 2000 THEN
        RETURN jsonb_build_object('ok', false, 'message', '自动支持金额需在 1~2000 NB币之间');
    END IF;
    IF p_threshold IS NULL OR p_threshold < 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '阈值不能为负数');
    END IF;
    DELETE FROM public.support_rules WHERE user_id = p_user_id AND company_id = p_company_id;
    INSERT INTO public.support_rules (user_id, company_id, threshold, amount)
    VALUES (p_user_id, p_company_id, p_threshold, p_amount);
    RETURN jsonb_build_object('ok', true, 'message', '自动支持规则已设置');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.set_support_rule(uuid, text, bigint, numeric, numeric) TO anon;

-- 删除规则(只能删自己的)
CREATE OR REPLACE FUNCTION public.delete_support_rule(
    p_user_id uuid, p_session text, p_rule_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_n int;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    DELETE FROM public.support_rules WHERE id = p_rule_id AND user_id = p_user_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '规则不存在或无权操作');
    END IF;
    RETURN jsonb_build_object('ok', true, 'message', '已取消自动支持规则');
END
$fn$;
GRANT EXECUTE ON FUNCTION public.delete_support_rule(uuid, text, bigint) TO anon;

-- 修改规则(只能改自己的)
CREATE OR REPLACE FUNCTION public.update_support_rule(
    p_user_id uuid, p_session text, p_rule_id bigint, p_threshold numeric, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_n int;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 2000 THEN
        RETURN jsonb_build_object('ok', false, 'message', '自动支持金额需在 1~2000 NB币之间');
    END IF;
    IF p_threshold IS NULL OR p_threshold < 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '阈值不能为负数');
    END IF;
    UPDATE public.support_rules
       SET threshold = p_threshold, amount = p_amount
     WHERE id = p_rule_id AND user_id = p_user_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '规则不存在或无权操作');
    END IF;
    RETURN jsonb_build_object('ok', true, 'message', '修改成功');
END
$fn$;
GRANT EXECUTE ON FUNCTION public.update_support_rule(uuid, text, bigint, numeric, numeric) TO anon;

-- ---------- 2) 收口:这 4 张表匿名只能读,不能增/改/删 ----------
-- support_logs  : 写入走 support_company RPC(本来就是) → 直接锁
-- support_rules : 写入改走上面三个 RPC → 直接锁
-- api_logs      : 由 PythonAnywhere 后端用 service key 写 → 直接锁
-- notifications : 写入走 get_my_notifications 等 RPC → 直接锁
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.support_logs    FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.support_rules   FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.api_logs        FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.notifications   FROM anon, authenticated;

-- ---------- 3) 验收:下面 4 行的三列应该全是 false ----------
SELECT c.relname AS 表,
       has_table_privilege('anon', c.oid, 'INSERT') AS 可增,
       has_table_privilege('anon', c.oid, 'UPDATE') AS 可改,
       has_table_privilege('anon', c.oid, 'DELETE') AS 可删
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public'
   AND c.relname IN ('support_logs', 'support_rules', 'api_logs', 'notifications',
                     'admin_config', 'profiles', 'comments', 'banned_ips')
 ORDER BY c.relname;
