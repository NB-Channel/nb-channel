-- ============================================================
-- 补丁 2：把破产退款再收紧一道
-- ============================================================
--
-- 【为什么还要改】
--   上一版把 reward 改成「老板净投入」，堵住了「退全部市值」。
--   但【注册时白给的 20000 市值】没被堵住 —— 它没被任何付款背书，
--   却能通过破产变成真钱。
--
--   实测推演（上一版修复后仍然成立）：
--     ① 大号建公司           市值 20000（白给）
--     ② 小号 buy 20000       principal=20000, base_mv=20000, 市值仍 20000
--     ③ 大号 support 10000   市值 30000，扣款 10500
--     ④ 小号 sell            到账 28500        ← 小号赚 8500
--                            市值 → 20000      （扣减修复生效）
--     ⑤ 大号 bankrupt        reward = LEAST(10000, 20000) = 10000
--                            大号 -10500+10000 = -500
--     合计：全站凭空多出 8000
--
-- 【这次改什么】
--   reward 的上限从「当前市值」改成「市值减去保底 20000」——
--   那 20000 是注册时白给的，不给退。
--
--       v_reward := LEAST(v_net_in, GREATEST(v_market_value - 20000, 0));
--
--   重推：④ 之后市值 20000 → reward = LEAST(10000, 0) = 0
--         大号 -10500，小号 +8500，全站净减 2000（手续费）✅
--
--   正常场景（无股东）：建公司 20000 → 注资 10000 → 破产
--          reward = LEAST(10000, 30000-20000) = 10000
--          玩家 -10500 + 10000 = -500，只损失手续费 ✅
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================

CREATE OR REPLACE FUNCTION public._orig_bankrupt_company(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_company_id BIGINT;
    v_company_name TEXT;
    v_market_value BIGINT;
    v_reward BIGINT := 0;
    v_supported BIGINT := 0;        -- 老板自己注资的累计额
    v_withdrawn BIGINT := 0;        -- 老板已经提取走的
    v_net_in BIGINT := 0;           -- 净投入
    v_floor CONSTANT BIGINT := 20000;   -- 注册时白给的市值，不参与退款
BEGIN
    SELECT id, company_name, market_value
      INTO v_company_id, v_company_name, v_market_value
      FROM public.user_companies WHERE user_id = p_user_id;
    IF v_company_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '您还没有虚拟公司');
    END IF;

    -- 老板自己注资了多少
    BEGIN
        SELECT COALESCE(sum(amount), 0) INTO v_supported
          FROM public.support_logs
         WHERE company_id = v_company_id AND supporter_id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        v_supported := 0;
    END;

    -- 老板已经提走多少（withdraw_company_value 的记录）
    BEGIN
        SELECT COALESCE(sum(total_amount), 0) INTO v_withdrawn
          FROM public.transactions
         WHERE company_id = v_company_id AND user_id = p_user_id
           AND type IN ('withdraw', 'company_withdraw');
    EXCEPTION WHEN OTHERS THEN
        v_withdrawn := 0;
    END;

    v_net_in := GREATEST(v_supported - v_withdrawn, 0);

    -- ⭐ 关键：退款不能超过「市值 - 保底 20000」
    --    那 20000 是注册时白给的，没被任何付款背书，
    --    一旦允许它变现，就是一个稳定的造币口。
    v_reward := LEAST(v_net_in, GREATEST(v_market_value - v_floor, 0));

    DELETE FROM public.holdings WHERE company_id = v_company_id;
    DELETE FROM public.user_companies WHERE id = v_company_id;
    DELETE FROM public.verified_users WHERE user_id = p_user_id;
    DELETE FROM public.support_rules WHERE company_id = v_company_id;
    -- 注意：不删 stock_history_full（每条快照含所有公司，按公司名删 = 删光全部K线）

    IF v_reward > 0 THEN
        UPDATE public.profiles SET nb_balance = nb_balance + v_reward WHERE id = p_user_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', CASE WHEN v_reward > 0
                        THEN format('破产成功，退回 %s NB币（你的净投入 %s，可退上限 %s）',
                                    v_reward, v_net_in,
                                    GREATEST(v_market_value - v_floor, 0))
                        ELSE '破产成功，没有可退回的资金' END,
        'reward', v_reward
    );
END;
$function$;


-- ============================================================
-- 顺带确认另一头也是封住的
-- ------------------------------------------------------------
-- sell_stock 那边我加了保底：
--     v_new_mv := GREATEST(20000, v_market_value - floor(v_sell)::bigint);
-- 也就是卖不出 20000 以下。这个和上面的 floor 是一致的 ——
-- 公司账上永远留着这 20000，而它【永远不能变现】。
-- 这样注册白给的 20000 就成了一笔「死钱」，
-- 只能撑门面，不能套现。
--
-- 如果将来想让这 20000 也能用，唯一正确的做法是：
--     注册公司时【真的扣玩家 20000】
-- 那样它就是被真实资金背书了，随便退都没问题。
-- ============================================================


-- ============================================================
-- 验收：确认新版本生效
-- ============================================================
SELECT
    p.proname AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%market_value - v_floor%'
         THEN '✅ 已收紧（那 20000 不给退了）'
         ELSE '❌ 还是旧版' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname = '_orig_bankrupt_company';


-- ============================================================
-- 执行完可以自己验一遍套利路径（不会真的改动数据）
-- ------------------------------------------------------------
-- 拿两个测试号走一遍完整流程，最后比对两个号的余额总和：
--     修复前：总和会增加（造币）
--     修复后：总和只会减少一点（手续费）
-- ============================================================
