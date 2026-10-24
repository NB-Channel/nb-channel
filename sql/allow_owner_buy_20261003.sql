-- ============================================================
-- 规则修改：持股为 0 时，允许买自己公司
-- ============================================================
--
-- 【为什么要改】
-- 原来的规则是一刀切：
--     IF v_owner = p_user_id THEN 拒绝 END IF;
-- 意思是「只要你是这家公司的 owner，就永远不能买它的股份」。
--
-- 这条是为了防止创始人自己拉高股价、吸引别人跟风、然后砸盘套现。
--
-- 但它有个漏洞：如果创始人【把自己的股份卖光了】，他就成了
-- "没有股份的 owner" —— 分红拿不到、清算拿不到、想买回来又被规则拦着。
-- 站长就是这么撞上的（先卖了 20,000 张创始股，然后才注资 2.1 亿）。
--
-- 【改成什么】
--     只要【手上还有股份】就禁止
--     持股为 0 的 owner，跟普通投资者没区别，允许买
--
-- 【为什么这样安全】
--     买一次之后就有股份了，规则立刻恢复拦截。
--     所以只能买一次，没法反复拉盘。
--     （真想再买，得先把股份卖掉 —— 而卖掉本身要吃 5% 手续费和滑点。）
--
-- ⚠️ 注意：改完之后，你只能一次性买够。买完就成了股东，再买会被拦。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：备份
-- ============================================================
CREATE TABLE IF NOT EXISTS public._func_backup_buy_20261003 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '_orig_buy_stock';

SELECT 函数名, length(定义) AS 长度 FROM public._func_backup_buy_20261003;


-- ============================================================
-- 第二步：改判定
-- ------------------------------------------------------------
-- 只改「不能买自己公司」那一小段，其余逻辑（恒定乘积、手续费、
-- 持仓更新、流水记录）跟原来一模一样。
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_buy_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_cash    numeric;
    v_shares  numeric;
    v_k       numeric;
    v_newc    numeric;
    v_news    numeric;
    v_got     numeric;
    v_fee     numeric;
    v_total   numeric;
    v_bal     numeric;
    v_name    text;
    v_owner   uuid;
    v_p0      numeric;
    v_p1      numeric;
    v_mine    numeric;      -- ⭐ 我在这家公司现在持有多少
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '投入金额必须大于0');
    END IF;

    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN jsonb_build_object('success', false,
            'message', '当前为休市时间（每日 8:00-20:00 交易），请开盘后再操作');
    END IF;

    -- 锁住这家公司，避免并发把池子算歪
    SELECT pool_cash::numeric, pool_shares::numeric, company_name, user_id
      INTO v_cash, v_shares, v_name, v_owner
      FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
    IF v_cash IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;

    -- ⭐⭐ 改的就是这一段 ⭐⭐
    -- 原来：只要你是 owner 就拒绝
    -- 现在：只有你【手上还有股份】时才拒绝
    IF v_owner = p_user_id THEN
        SELECT COALESCE(shares, 0) INTO v_mine
          FROM public.holdings
         WHERE company_id = p_company_id AND user_id = p_user_id;
        v_mine := COALESCE(v_mine, 0);

        IF v_mine > 0 THEN
            RETURN jsonb_build_object('success', false,
                format('不能买入自己公司的股份（你是创始人，已持有 %s 张）。如果想增加持股，需要先把手上的卖掉才能再买。',
                       round(v_mine, 2)));
        END IF;
        -- 持股为 0 → 放行，继续往下走
    END IF;

    v_fee := floor(p_amount * CASE WHEN p_use_discount THEN 0.02 ELSE 0.05 END);
    v_total := p_amount + v_fee;

    SELECT COALESCE(nb_balance,0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal < v_total THEN
        RETURN jsonb_build_object('success', false,
            format('NB币余额不足（需 %s，含 %s 手续费，你有 %s）', v_total, v_fee, v_bal));
    END IF;

    -- 恒定乘积
    v_p0 := v_cash / v_shares;
    v_k  := v_cash * v_shares;
    v_newc := v_cash + p_amount;
    v_news := v_k / v_newc;
    v_got  := v_shares - v_news;

    IF v_got <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '投入金额太小，买不到股份');
    END IF;

    -- 扣钱
    UPDATE public.profiles SET nb_balance = nb_balance - v_total WHERE id = p_user_id;

    -- 更新池子
    UPDATE public.user_companies
       SET pool_cash = v_newc, pool_shares = v_news
     WHERE id = p_company_id;

    -- 更新持仓
    INSERT INTO public.holdings
        (user_id, company_id, shares, cost, principal, base_market_value, updated_at)
    VALUES
        (p_user_id, p_company_id, v_got, p_amount, p_amount, v_cash, now())
    ON CONFLICT (user_id, company_id) DO UPDATE
        SET shares = COALESCE(public.holdings.shares,0) + v_got,
            cost   = COALESCE(public.holdings.cost,0)   + p_amount,
            updated_at = now();

    v_p1 := v_newc / v_news;

    INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, fee, price_after)
    VALUES (p_user_id, p_company_id, 'buy', v_total, v_got, v_fee, round(v_p1,4));

    RETURN jsonb_build_object(
        'success', true, 'ok', true,
        'message', format('买入「%s」成功：投入 %s NB币，得到 %s 张股份，均价 %s，手续费 %s',
                          v_name, p_amount, round(v_got,4),
                          round(p_amount / v_got, 4), v_fee),
        'shares', round(v_got,4),
        'avg_price', round(p_amount / v_got, 4),
        'price_before', round(v_p0,4),
        'price_after', round(v_p1,4),
        'fee', v_fee,
        'paid', v_total);
END
$fn$;


-- ============================================================
-- 第三步：验收
-- ============================================================
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '_orig_buy_stock';

-- 确认判定里出现了「已持有」那句（说明改上了）
SELECT CASE WHEN pg_get_functiondef(p.oid) LIKE '%已持有 %s 张%'
            THEN '✅ 规则已改（持股为 0 时可以买）'
            ELSE '❌ 还是旧的（只要 owner 就拒绝）' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '_orig_buy_stock';


-- ============================================================
-- 第四步：买回来
-- ------------------------------------------------------------
-- 跑完上面之后，直接在页面上操作：
--     打开「NB频道」→ 买入 → 输入金额 → 确认
--
-- 我给你算好了（池子现金 10,000 / 池子股份 40,000，股价 0.25）：
--
--     投入   100 币  →  买到约  394 张  →  占玩家持股 94.9%
--     投入   256 币  →  买到约 1000 张  →  占玩家持股 97.9%
--     投入  1000 币  →  买到约 3636 张  →  占玩家持股 99.4%
--     投入 10000 币  →  买到约 20000 张 →  占玩家持股 99.9%
--
-- ⚠️ 只能买一次！买完你就有股份了，规则会立刻恢复拦截。
--    所以想清楚要买多少再下手。
--
-- 【建议】投入 1000 币左右 —— 花小钱拿到 99.4% 的持股，
--        足够你以后正常分红和清算了。
--
-- 买完可以跑这句看看自己占多少：
-- ============================================================
SELECT c.company_name,
       (SELECT COALESCE(shares,0) FROM public.holdings h
         WHERE h.company_id = c.id AND h.user_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid)
           AS 你的持股,
       (SELECT COALESCE(sum(shares),0) FROM public.holdings h WHERE h.company_id = c.id)
           AS 玩家持股之和,
       round(c.pool_cash::numeric / NULLIF(c.pool_shares,0), 4) AS 股价,
       c.pool_cash AS 池子现金
  FROM public.user_companies c
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;


-- ============================================================
-- 回滚
-- ============================================================
-- SELECT 定义 FROM public._func_backup_buy_20261003;
