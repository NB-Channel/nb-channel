-- ============================================================
--  修「自动抄底规则」的编辑接口 —— 它写的是个死字段
--
--  【问题】
--    个人中心的「修改规则」调的是 update_support_rule(p_threshold, ...)，
--    而这个函数写的是 support_rules.threshold：
--
--        UPDATE public.support_rules
--           SET threshold = p_threshold, amount = p_amount
--         WHERE id = p_rule_id AND user_id = p_user_id;
--
--    但 AMM 重构（amm_part6）之后，threshold 已经是个【没人读的死字段】：
--        -- 老的 threshold 字段语义是「市值低于此就支持」，
--        -- 现在改成「股价低于此就买」，新字段叫 price_target
--        ADD COLUMN IF NOT EXISTS price_target numeric
--        -- 新建规则时 threshold 直接写 NULL：
--        INSERT INTO support_rules (..., threshold, amount, price_target, ...)
--        VALUES (..., NULL, p_amount::int, p_price_target, ...)
--
--    所以：在个人中心改规则 = 改了个寂寞，price_target 一点没动。
--
--  【顺带两个小问题】
--    ① 金额上限还是老的 2000，而 AMM 里 set_auto_buy_rule 用的是 10 ~ 100000
--       → 在个人中心改只能填 ≤2000，股票页却能填到 10 万，两边不一致
--    ② 不能改「每天上限」daily_limit
--
--  【改法】
--    重写这个函数：
--      · 参数名 p_threshold → p_price_target（前端也要跟着改）
--      · 写 price_target 而不是 threshold
--      · 金额范围对齐成 10 ~ 100000
--      · 新增可选的 p_daily_limit
--      · 目标股价必须大于 0
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 一、先看现状：有多少规则是「threshold 有值但 price_target 是空」的
--     （这些就是被个人中心改坏了的规则 —— 改了 threshold，
--      但真正生效的 price_target 没动）
-- ============================================================
SELECT
    count(*)                                                          AS 规则总数,
    count(*) FILTER (WHERE price_target IS NOT NULL)                  AS 有目标股价的,
    count(*) FILTER (WHERE price_target IS NULL)                      AS 没目标股价的,
    count(*) FILTER (WHERE threshold IS NOT NULL)                     AS 死字段有值的,
    count(*) FILTER (WHERE price_target IS NULL AND threshold IS NOT NULL)
                                                                      AS 疑似被改坏的
  FROM public.support_rules;


-- ============================================================
-- 二、重写 update_support_rule
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_support_rule(
    p_user_id      uuid,
    p_session      text,
    p_rule_id      bigint,
    p_price_target numeric,                    -- 目标股价（跌到这个价以下就买）
    p_amount       numeric,                    -- 每次买入金额
    p_daily_limit  numeric DEFAULT NULL        -- 每天上限（不传就保持不变）
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_n int;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false,
            'message', '登录状态已过期，请重新登录');
    END IF;

    IF p_amount IS NULL OR p_amount < 10 OR p_amount > 100000 THEN
        RETURN jsonb_build_object('ok', false,
            'message', '每次买入金额要在 10 ~ 100000 NB币之间');
    END IF;

    IF p_price_target IS NULL OR p_price_target <= 0 THEN
        RETURN jsonb_build_object('ok', false,
            'message', '目标股价要大于 0');
    END IF;

    IF p_daily_limit IS NOT NULL AND p_daily_limit < p_amount THEN
        RETURN jsonb_build_object('ok', false,
            'message', '每天上限不能小于每次买入金额');
    END IF;

    -- ⭐ 写 price_target，不再写那个没人读的 threshold
    UPDATE public.support_rules
       SET price_target = p_price_target,
           amount       = floor(p_amount),
           daily_limit  = COALESCE(p_daily_limit, daily_limit)
     WHERE id = p_rule_id AND user_id = p_user_id;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '规则不存在或无权操作');
    END IF;

    RETURN jsonb_build_object('ok', true, 'message', '修改成功');
END
$fn$;

GRANT EXECUTE ON FUNCTION public.update_support_rule(uuid, text, bigint, numeric, numeric, numeric)
    TO anon, authenticated;


-- ============================================================
-- 三、顺手把「被改坏的规则」提示出来（不自动改，让你自己决定）
-- ============================================================
-- 这些规则的 price_target 是空的 → 永远不会触发买入。
-- 如果那些 threshold 值看着像股价（比如 0.95），可以手工搬过去：
--
--     UPDATE public.support_rules
--        SET price_target = threshold, threshold = NULL
--      WHERE price_target IS NULL AND threshold IS NOT NULL
--        AND threshold > 0 AND threshold < 100;      -- 只搬看着像股价的
--
SELECT id, user_id, company_id, threshold, price_target, amount, enabled
  FROM public.support_rules
 WHERE price_target IS NULL
 ORDER BY id
 LIMIT 50;


-- ============================================================
-- 四、验证
-- ============================================================
SELECT
    p.proname AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%SET price_target = p_price_target%'
         THEN '✅ 改成写 price_target 了'
         ELSE '❌ 还在写 threshold' END AS 状态,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%100000%'
         THEN '✅ 金额上限已对齐 10~100000'
         ELSE '❌ 还是老的 2000' END AS 金额范围
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'update_support_rule';


-- ============================================================
--  做完之后
-- ============================================================
--  ⚠️ 前端（profile-Beta.html / profile.html）也要跟着改：
--     调用参数从 p_threshold 换成 p_price_target，
--     否则 RPC 找不到参数会直接报错。
--     前端那边我一并改好了，跟着这次提交一起上。
-- ============================================================
