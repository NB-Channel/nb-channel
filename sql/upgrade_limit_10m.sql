-- ============================================================
-- 「提升公司市值」单次上限:1 亿 → 1000 万
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

CREATE OR REPLACE FUNCTION public.upgrade_company_value(
    p_user_id uuid, p_session text, p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_bal   numeric;
    v_owner uuid;
    v_new   numeric;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF p_amount IS NULL OR p_amount < 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '提升金额无效');
    END IF;
    IF p_amount = 0 THEN
        RETURN jsonb_build_object('ok', true, 'message', '按基础市值 20000 注册', 'added', 0);
    END IF;
    IF p_amount > 10000000 THEN
        RETURN jsonb_build_object('ok', false, 'message', '单次提升不能超过 1000 万 NB币');
    END IF;

    SELECT user_id INTO v_owner FROM public.user_companies WHERE id = p_company_id;
    IF v_owner IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '公司不存在');
    END IF;
    IF v_owner <> p_user_id THEN
        RETURN jsonb_build_object('ok', false, 'message', '只能提升自己公司的市值');
    END IF;

    SELECT nb_balance INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal IS NULL OR v_bal < p_amount THEN
        RETURN jsonb_build_object('ok', false, 'message',
            'NB币不足(需要 ' || p_amount || ',当前 ' || coalesce(v_bal, 0) || ')');
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - p_amount WHERE id = p_user_id;
    UPDATE public.user_companies SET market_value = market_value + p_amount
     WHERE id = p_company_id
     RETURNING market_value INTO v_new;

    RETURN jsonb_build_object('ok', true,
        'message', '已花费 ' || p_amount || ' NB币,公司市值提升至 ' || v_new,
        'added', p_amount, 'market_value', v_new);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.upgrade_company_value(uuid, text, bigint, numeric) TO anon;

-- ---------- 验收 ----------
-- 带一个无效会话调用:应先被鉴权挡下;上限已写入函数体(可用下面这句确认)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%10000000%') AS 上限已是1000万,
       (pg_get_functiondef(p.oid) LIKE '%> 100000000%') AS 还残留1亿上限
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'upgrade_company_value';
