-- ============================================================
-- 新增:从自己公司提取资金(老板把公司市值变现成 NB币)
-- 与"破产"的区别:破产会解散公司;这个只是把市值里的钱取出来,公司继续经营。
-- 约束:
--   · 只有公司老板能提
--   · 提取后市值不得低于 20000(保留初始投资,防止把空壳公司丢给股东)
--   · 有外部股东时会返回提示(仍然允许,属自由市场行为)
-- 在 Supabase SQL Editor 执行
-- ============================================================

CREATE OR REPLACE FUNCTION public.withdraw_company_value(
    p_user_id uuid, p_session text, p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_owner   uuid;
    v_mv      numeric;
    v_bal     numeric;
    v_floor   numeric := 20000;      -- 提现后市值保底
    v_holders int := 0;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '提取金额需大于 0');
    END IF;

    SELECT user_id, market_value INTO v_owner, v_mv
      FROM public.user_companies WHERE id = p_company_id;
    IF v_owner IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '公司不存在');
    END IF;
    IF v_owner <> p_user_id THEN
        RETURN jsonb_build_object('ok', false, 'message', '只能提取自己公司的资金');
    END IF;

    IF v_mv - p_amount < v_floor THEN
        RETURN jsonb_build_object('ok', false, 'message',
            '提取后市值不能低于 ' || v_floor || ' NB币(当前市值 ' || v_mv ||
            ',最多可提 ' || greatest(0, floor(v_mv - v_floor)) || ' )');
    END IF;

    -- 有外部股东时给个提示(不算错误,仍然允许提取)
    BEGIN
        SELECT count(*) INTO v_holders
          FROM public.holdings
         WHERE company_id = p_company_id AND user_id <> p_user_id;
    EXCEPTION WHEN OTHERS THEN
        v_holders := 0;
    END;

    UPDATE public.user_companies
       SET market_value = market_value - p_amount
     WHERE id = p_company_id;

    UPDATE public.profiles
       SET nb_balance = coalesce(nb_balance, 0) + p_amount
     WHERE id = p_user_id
     RETURNING nb_balance INTO v_bal;

    RETURN jsonb_build_object(
        'ok', true,
        'message', '已从公司提取 ' || p_amount || ' NB币,当前余额 ' || v_bal,
        'withdrawn', p_amount,
        'balance', v_bal,
        'market_value', v_mv - p_amount,
        'holders', v_holders,
        'holders_tip', CASE WHEN v_holders > 0
            THEN '注意:该公司有 ' || v_holders || ' 位外部股东,提取会让他们持有的份额贬值'
            ELSE NULL END
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.withdraw_company_value(uuid, text, bigint, numeric) TO anon;

-- ---------- 验收 ----------
SELECT p.proname AS 新函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'withdraw_company_value';
