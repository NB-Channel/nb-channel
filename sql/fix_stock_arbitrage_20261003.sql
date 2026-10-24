-- ============================================================
-- 修复「注资 → 股东套现 → 老板破产」无限刷币
-- ============================================================
--
-- 【漏洞成因】
--   核心在 _orig_sell_stock：它把本金增值后的钱付给了股东，
--   但【没有从公司市值里扣掉】。
--   于是同一笔市值被支付了两次 ——
--   一次给卖出的股东，一次在老板破产时作为 reward 退给老板。
--
--   完整路径（以你报的数字为例）：
--     初始市值 20000（注册公司时凭空给的）
--     ① 小号 buy 20000        principal=20000, base_mv=20000, 市值仍 20000
--     ② 大号 support 100000   市值 120000，大号扣款 105000
--     ③ 小号 sell（全卖）      position = 20000 × 120000/20000 = 120000
--                             到账 114000（扣 5% 手续费）  ← 小号赚 94000
--                             市值【仍然是 120000】         ← 就错在这里
--     ④ 大号 bankrupt          reward = 120000 - 20000 = 100000
--     净造：+89000 NB币，可无限重复，且金额越滚越大
--
-- 【修复思路】
--   钱从公司流出去，公司市值就必须相应减少 —— 这是最基本的会计恒等式。
--   三处一起改：
--     ① sell_stock：卖出时按实际付出的钱减少市值（保底 20000）
--     ② bankrupt_company：reward 上限收紧为【老板本人净投入】，
--        不再把市值全额退（市值里可能有别人的钱）
--     ③ support_company：加【每公司每日累计注资上限】，
--        防止有人靠大额注资把市值推到天上再配合其他路径
--
-- 【注意】
--   第①条会改变游戏手感：以前卖出不减市值，现在会减。
--   这是必须的 —— 不减就永远有套利空间。
--   建议同步在更新日志里跟玩家说明「卖出会释放市值」。
--
-- 在 Supabase SQL Editor 里执行。
-- ============================================================


-- ============================================================
-- ① _orig_sell_stock：卖出时减少公司市值
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_sell_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_market_value BIGINT;
    v_company_name TEXT;
    v_principal NUMERIC(18,4);
    v_base_mv NUMERIC(18,4);
    v_position NUMERIC(18,4);
    v_sell NUMERIC(18,4);
    v_cost NUMERIC(18,4);
    v_fee INTEGER;
    v_net NUMERIC(18,4);
    v_profit NUMERIC(18,4);
    v_ratio NUMERIC(18,6);
    v_new_principal NUMERIC(18,4);
    v_floor BIGINT := 20000;        -- 公司市值保底（和 withdraw 保持一致）
    v_new_mv BIGINT;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '卖出金额必须大于0');
    END IF;
    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false, 'message', '当前为休市时间（每日 8:00-20:00 交易），请开盘后再操作');
    END IF;

    -- 锁住这一行，避免并发重复卖出
    SELECT market_value, company_name INTO v_market_value, v_company_name
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_market_value IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;

    SELECT principal, base_market_value INTO v_principal, v_base_mv
      FROM public.holdings
     WHERE user_id = p_user_id AND company_id = p_company_id;
    IF v_principal IS NULL OR v_principal <= 0 OR v_base_mv IS NULL OR v_base_mv <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '您还没有持有这家公司');
    END IF;

    v_position := v_principal * (v_market_value::numeric / v_base_mv);
    v_sell := LEAST(p_amount, round(v_position, 2));
    IF v_sell <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '卖出金额太小');
    END IF;

    v_ratio := v_sell / v_position;
    v_cost := round(v_principal * v_ratio, 2);
    v_fee := floor(v_sell * 0.05);
    IF p_use_discount AND public.consume_fee_discount(p_user_id) THEN
        v_fee := floor(v_sell * 0.02);
    END IF;
    v_net := v_sell - v_fee;
    v_profit := round(v_sell - v_cost - v_fee, 2);
    v_new_principal := round(v_principal * (1 - v_ratio), 2);

    UPDATE public.profiles SET nb_balance = nb_balance + v_net WHERE id = p_user_id;

    -- ⭐ 关键修复：钱付出去了，公司市值就必须减去同样的数额。
    --    不扣的话，同一笔市值会既付给股东、又在破产时退给老板。
    --    保底 20000，避免市值被卖穿。
    v_new_mv := GREATEST(v_floor, v_market_value - floor(v_sell)::bigint);
    UPDATE public.user_companies
       SET market_value = v_new_mv
     WHERE id = p_company_id;

    IF v_new_principal <= 0.01 THEN
        DELETE FROM public.holdings WHERE user_id = p_user_id AND company_id = p_company_id;
    ELSE
        UPDATE public.holdings
           SET principal = v_new_principal, updated_at = now()
         WHERE user_id = p_user_id AND company_id = p_company_id;
    END IF;

    INSERT INTO public.transactions (user_id, company_id, type, shares, price, total_amount, fee)
    VALUES (p_user_id, p_company_id, 'sell', 0, v_market_value, v_sell, v_fee);

    RETURN jsonb_build_object(
        'success', true,
        'message', format('成功退出「%s」！卖出 %s NB币，手续费 %s NB币，实际到账 %s NB币，盈亏 %s NB币',
                          v_company_name, v_sell, v_fee, v_net, v_profit),
        'revenue', v_sell,
        'profit', v_profit,
        'position_value', round(v_position, 2),
        'market_value', v_new_mv
    );
END;
$function$;


-- ============================================================
-- ② _orig_bankrupt_company：reward 收紧为「老板本人净投入」
-- ------------------------------------------------------------
--   原来 reward = market_value - 20000，等于把公司账上所有的钱
--   都退给老板 —— 但那些钱里有股东投入的部分（甚至刚被别人注资）。
--   改成：只退老板自己通过 support 投进去的净额（扣掉已经提取的）。
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
    v_invested BIGINT := 0;         -- 老板自己买入的（一般买不了自己公司，保险起见）
BEGIN
    SELECT id, company_name, market_value
      INTO v_company_id, v_company_name, v_market_value
      FROM public.user_companies WHERE user_id = p_user_id;
    IF v_company_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '您还没有虚拟公司');
    END IF;

    -- 老板自己注资了多少（support_logs 里 supporter = 自己 的记录）
    BEGIN
        SELECT COALESCE(sum(amount), 0) INTO v_supported
          FROM public.support_logs
         WHERE company_id = v_company_id AND supporter_id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        v_supported := 0;
    END;

    -- 老板已经通过 withdraw_company_value 提走多少
    BEGIN
        SELECT COALESCE(sum(total_amount), 0) INTO v_withdrawn
          FROM public.transactions
         WHERE company_id = v_company_id AND user_id = p_user_id
           AND type IN ('withdraw', 'company_withdraw');
    EXCEPTION WHEN OTHERS THEN
        v_withdrawn := 0;
    END;

    v_net_in := GREATEST(v_supported - v_withdrawn, 0);

    -- 退款不超过净投入，也不超过公司当前市值
    v_reward := LEAST(v_net_in, GREATEST(v_market_value, 0));

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
                        THEN format('破产成功，退回你的净投入 %s NB币', v_reward)
                        ELSE '破产成功，没有可退回的净投入' END,
        'reward', v_reward
    );
END;
$function$;


-- ============================================================
-- ③ _orig_support_company：加每公司每日累计注资上限
-- ------------------------------------------------------------
--   单次已有 100000 的上限，但没有累计限制 ——
--   一天内可以注资几万次，把市值推到任意高度。
--   这里加一个「每公司每日累计 200 万」的硬顶（可按需调整）。
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_support_company(
    p_user_id uuid, p_company_id bigint, p_amount integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_owner_id UUID;
    v_market_value INTEGER;
    v_fee INTEGER := 0;
    v_total_pay INTEGER;
    v_cap CONSTANT INTEGER := 2000000;      -- 每公司每日累计注资上限
    v_today INTEGER := 0;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '支持金额必须大于0');
    END IF;
    IF p_amount > 100000 THEN
        RETURN jsonb_build_object('success', false, 'message', '单次手动支持金额不能超过100000 NB币');
    END IF;

    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false, 'message', '当前为休市时间（每日 8:00-20:00 交易），请开盘后再操作');
    END IF;

    -- 当日该公司的累计注资
    BEGIN
        SELECT COALESCE(sum(amount), 0) INTO v_today
          FROM public.support_logs
         WHERE company_id = p_company_id
           AND (created_at AT TIME ZONE 'Asia/Shanghai')::date
               = (now() AT TIME ZONE 'Asia/Shanghai')::date;
    EXCEPTION WHEN OTHERS THEN
        v_today := 0;
    END;

    IF v_today + p_amount > v_cap THEN
        RETURN jsonb_build_object('success', false, 'message',
            format('该公司今日注资已达上限（%s / %s NB币），请明天再来', v_today, v_cap));
    END IF;

    SELECT user_id, market_value INTO v_owner_id, v_market_value
      FROM public.user_companies WHERE id = p_company_id;
    IF v_owner_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '虚拟公司不存在');
    END IF;

    IF v_owner_id = p_user_id THEN
        v_fee := floor(p_amount * 0.05);
    END IF;
    v_total_pay := p_amount + v_fee;

    UPDATE public.profiles SET nb_balance = nb_balance - v_total_pay
     WHERE id = p_user_id AND nb_balance >= v_total_pay;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message',
            format('NB币余额不足（需 %s NB币%s）', v_total_pay,
                   CASE WHEN v_fee > 0 THEN format('，含 %s NB币手续费', v_fee) ELSE '' END));
    END IF;

    UPDATE public.user_companies
       SET market_value = market_value + p_amount
     WHERE id = p_company_id;

    INSERT INTO public.support_logs (supporter_id, company_id, amount)
    VALUES (p_user_id, p_company_id, p_amount);

    IF v_fee > 0 THEN
        RETURN jsonb_build_object('success', true, 'message',
            format('成功支持自己的公司 %s NB币（手续费 %s NB币，共支付 %s NB币）', p_amount, v_fee, v_total_pay));
    END IF;
    RETURN jsonb_build_object('success', true, 'message', format('成功支持 %s NB币', p_amount));
END;
$function$;


-- ============================================================
-- 验收：确认三个函数都换掉了
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_sell_stock', '_orig_bankrupt_company', '_orig_support_company')
 ORDER BY p.proname;
