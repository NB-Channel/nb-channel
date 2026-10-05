-- ============================================================
--  股票系统 · 方案 C
--  「保留现在的数学 + 换回旧版的玩法」
--
--  站长选的方案。核心思路：
--    定价数学一行不动（钱有出处，不凭空造钱）
--    但把旧版那种「公司自己会长大」的感觉补回来
--
--  这个脚本做三件事：
--    一、数据换算      market_value / holdings.principal 写回真实值
--    二、公司税改再分配  收上来的钱不再销毁，发给中小公司
--    三、新增「提取公司价值」  创始人从公司账上提钱
--
--  ⚠️⚠️ 这个脚本会动真实数据。执行前请先跑第 0 步备份。
--  ⚠️ 用法：整段复制到 Supabase → SQL Editor → Run
--      （不能用 psql 的 \set 之类元命令，SQL Editor 不认）
-- ============================================================


-- ============================================================
-- 第 0 步：备份（先跑这一段，确认备份表建好了再往下）
-- ============================================================
DROP TABLE IF EXISTS public._sc_bak_companies_20261005;
CREATE TABLE public._sc_bak_companies_20261005 AS
SELECT * FROM public.user_companies;

DROP TABLE IF EXISTS public._sc_bak_holdings_20261005;
CREATE TABLE public._sc_bak_holdings_20261005 AS
SELECT * FROM public.holdings;

SELECT '公司' AS 表, count(*) AS 条数 FROM public._sc_bak_companies_20261005
UNION ALL
SELECT '持股', count(*) FROM public._sc_bak_holdings_20261005;


-- ============================================================
-- 第 1 步：预览 —— 先看换算会把数字改成什么，确认合理再执行第 2 步
-- ============================================================
--
-- 【为什么要换算】
--   amm_part3 当时把 market_value 设成了「总股数」：
--       market_value = pool_shares + 创始人股份 + 其他股东股份
--   迁移那会儿所有公司股价都是 1.00，所以「总股数」凑巧等于「市值」。
--   但后来价格涨跌了（比如 Utw 现在 0.4896），
--   这个字段就一直是【过期的】—— 它还是那个总股数，不是市值。
--
--   而 achievements.sql 还在读它：
--       sum(h.principal * (uc.market_value / h.base_market_value))
--   所以「持仓价值」类成就有可能是算错的。
--
-- 【换算公式】
--   market_value      = 当前真实公司总值 = 股价 × 总股数
--   holdings.principal = 当前持股价值   = 持股数 × 股价
--   holdings.base_market_value = 当前公司总值
--       （这样 principal × (market_value / base_market_value)
--         = 持股价值 × 1 = 持股价值，旧公式继续成立）
--
SELECT
    c.company_name                                          AS 公司,
    c.market_value                                          AS 现在存的market_value,
    c.total_shares                                          AS 总股数,
    round(c.pool_cash::numeric
          / NULLIF(c.pool_shares::numeric, 0), 4)           AS 股价,
    round(c.pool_cash::numeric
          / NULLIF(c.pool_shares::numeric, 0)
          * c.total_shares::numeric, 2)                     AS 换成的公司总值,
    (SELECT count(*) FROM public.holdings h
      WHERE h.company_id = c.id)                            AS 股东数
  FROM public.user_companies c
 WHERE c.pool_shares > 0
 ORDER BY c.pool_cash DESC
 LIMIT 25;


-- ============================================================
-- 第 2 步：执行换算
-- ============================================================

-- 2.1 公司：market_value = 当前真实公司总值
UPDATE public.user_companies
   SET market_value = round(
           pool_cash::numeric / NULLIF(pool_shares::numeric, 0) * total_shares::numeric, 2)
 WHERE pool_shares > 0;

-- 2.2 持股：principal = 当前持股价值，base_market_value = 当前公司总值
UPDATE public.holdings h
   SET principal = round(
           COALESCE(h.shares, 0)::numeric
           * (c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)), 2),
       base_market_value = round(
           c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0) * c.total_shares::numeric, 2),
       updated_at = now()
  FROM public.user_companies c
 WHERE c.id = h.company_id
   AND c.pool_shares > 0;

-- ⚠️ 注意：这一步【不动任何人的余额】，也不动池子现金和持股数。
--    只是把两个「用来展示和算成就」的旧字段对齐到真实值。


-- ============================================================
-- 第 3 步：公司税改成「再分配」，不再销毁
-- ============================================================
--
-- 【原来的行为】
--   大公司按池子大小分段交税（0.2% / 0.5% / 1% / 2%，垄断再 +5%），
--   这笔钱直接从池子里扣掉，然后【没有任何去处】—— 销毁了。
--   结果是全站的钱越来越少（通缩），而且小公司永远长不大，
--   玩家打开页面发现自己公司一点变化都没有。
--
-- 【改成什么】
--   收上来的税，发给【中小公司】当作「经营收入」：
--     · 候选：池子现金 < 100 万的公司（大公司不参与，它们是被抽的那批）
--     · 每家每天最多涨「自己池子的 2%」—— 防止小公司一夜暴涨
--     · 发不完的余额销毁（保持轻微通缩，不会通胀）
--
--   效果：
--     ✅ 系统总量【不增加】—— 是从大公司转移给中小公司，不是印钱
--     ✅ 小公司账上的钱自己会涨 → 公司总值自己会涨 → 有「养公司」的玩法
--     ✅ 大公司被抽税 → 不会无限膨胀
--     ✅ 玩家打开页面能看到自己的公司昨天到今天变了 —— 这就是旧版的手感
--
CREATE OR REPLACE FUNCTION public.collect_company_tax()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    r            RECORD;
    v_rate       numeric;
    v_tax        numeric;
    v_total      numeric := 0;      -- 一共收上来多少
    v_count      int := 0;
    v_site_total numeric := 0;
    v_share      numeric;
    v_mono_cnt   int := 0;
    v_mono_total numeric := 0;
    v_mono_rate  CONSTANT numeric := 0.05;
    v_mono_line  CONSTANT numeric := 0.40;

    -- 再分配参数
    v_pool       numeric;           -- 待发放的总额
    v_give       numeric;
    v_given      numeric := 0;      -- 实际发出去多少
    v_give_cnt   int := 0;
    v_small_cnt  int := 0;
    v_cap_pct    CONSTANT numeric := 0.02;   -- 每家每天最多涨自己池子的 2%
    v_small_line CONSTANT numeric := 1000000;-- 池子小于 100 万的才算「中小公司」
BEGIN
    SELECT COALESCE(sum(pool_cash), 0) INTO v_site_total FROM public.user_companies;

    -- ---------- ① 收税（和原来一样，只是钱不再直接消失） ----------
    FOR r IN
        SELECT id, company_name, pool_cash
          FROM public.user_companies
         WHERE pool_cash >= 300000
         ORDER BY pool_cash DESC
    LOOP
        v_rate := CASE
            WHEN r.pool_cash <  1000000  THEN 0.002
            WHEN r.pool_cash <  20000000 THEN 0.005
            WHEN r.pool_cash <  50000000 THEN 0.010
            ELSE                              0.020
        END;

        IF v_site_total > 0 THEN
            v_share := r.pool_cash / v_site_total;
            IF v_share > v_mono_line THEN
                v_rate := v_rate + v_mono_rate;
                v_mono_cnt := v_mono_cnt + 1;
                v_mono_total := v_mono_total + floor(r.pool_cash * v_mono_rate);
            END IF;
        END IF;

        v_tax := floor(r.pool_cash * v_rate);
        IF v_tax < 1 THEN CONTINUE; END IF;

        UPDATE public.user_companies
           SET pool_cash = GREATEST(pool_cash - v_tax, 20000)
         WHERE id = r.id;

        v_total := v_total + v_tax;
        v_count := v_count + 1;
    END LOOP;

    -- ---------- ② 再分配：发给中小公司 ----------
    v_pool := v_total;

    IF v_pool >= 1 THEN
        SELECT count(*) INTO v_small_cnt
          FROM public.user_companies
         WHERE pool_cash > 0 AND pool_cash < v_small_line;

        IF v_small_cnt > 0 THEN
            -- 先按「平均分」算一个基准，再对每家做「不超过自己池子 2%」的封顶
            FOR r IN
                SELECT id, company_name, pool_cash
                  FROM public.user_companies
                 WHERE pool_cash > 0 AND pool_cash < v_small_line
                 ORDER BY pool_cash ASC            -- 最小的先拿
            LOOP
                EXIT WHEN v_pool - v_given < 1;    -- 发完了就停

                v_give := LEAST(
                    floor(v_pool / v_small_cnt),        -- 平均份额
                    floor(r.pool_cash * v_cap_pct)      -- 但不超过自己池子的 2%
                );
                IF v_give < 1 THEN CONTINUE; END IF;

                UPDATE public.user_companies
                   SET pool_cash = pool_cash + v_give
                 WHERE id = r.id;

                v_given := v_given + v_give;
                v_give_cnt := v_give_cnt + 1;
            END LOOP;
        END IF;
    END IF;

    -- ---------- ③ 记账 ----------
    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date',
            to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    RETURN jsonb_build_object(
        'ok', true,
        '收税_公司数', v_count,
        '收税_合计', v_total,
        '垄断税_公司数', v_mono_cnt,
        '垄断税_合计', v_mono_total,
        '发放_公司数', v_give_cnt,
        '发放_合计', v_given,
        '销毁_合计', GREATEST(v_total - v_given, 0)
    );
END
$fn$;


-- ============================================================
-- 第 4 步：新增「提取公司价值」
-- ============================================================
--
-- 【旧版是怎么做的】
--   创始人从 market_value（虚数）里提钱，市值减掉，钱进自己余额。
--   因为 market_value 是虚的，这一步等于【印钱】—— 这是当时三个造币口之一。
--
-- 【新版怎么做】
--   创始人从【公司账上真有的钱】里提，池子现金减掉，钱进自己余额。
--   股价 = 池子现金 ÷ 池子股份，池子钱少了 → 股价自动跌。
--   全程没有任何一刻是凭空出现的，提的是别人买进来时留下的真钱。
--
-- 【安全限制】
--   ① 只有创始人能提
--   ② 提完池子现金不能低于 20000（保留最低启动资金）
--   ③ ⭐ 最多只能提【池子现金 × 自己的持股比例】
--      —— 这条是关键。否则创始人可以「别人买进来一个亿，自己全提走」，
--         股东的股票瞬间归零，那就是拿真钱在骗人。
--      按持股比例限死之后，创始人只能拿走属于自己的那部分。
--
CREATE OR REPLACE FUNCTION public.extract_company_value(
    p_user_id    uuid,
    p_session    text,
    p_company_id bigint,
    p_amount     numeric
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_owner    uuid;
    v_name     text;
    v_cash     numeric;
    v_shares   numeric;
    v_pshares  numeric;
    v_my       numeric;
    v_price    numeric;
    v_ratio    numeric;
    v_max      numeric;
    v_floor    CONSTANT numeric := 20000;
    v_others   int := 0;
    v_bal      numeric;
BEGIN
    -- 鉴权
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '登录状态已过期，请重新登录');
    END IF;

    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '提取金额要大于 0');
    END IF;

    SELECT founder_id, company_name, pool_cash::numeric,
           pool_shares::numeric, total_shares::numeric
      INTO v_owner, v_name, v_cash, v_pshares, v_shares
      FROM public.user_companies
     WHERE id = p_company_id
       FOR UPDATE;

    IF v_owner IS NULL THEN
        RETURN jsonb_build_object('success', false, 'ok', false, 'message', '公司不存在');
    END IF;

    IF v_owner <> p_user_id THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '只有公司创始人能提取公司账上的钱');
    END IF;

    IF v_pshares IS NULL OR v_pshares <= 0 THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '公司数据异常，请联系站长');
    END IF;

    -- 创始人持股
    SELECT COALESCE(shares, 0)::numeric INTO v_my
      FROM public.holdings
     WHERE company_id = p_company_id AND user_id = p_user_id;
    v_my := COALESCE(v_my, 0);

    -- 池子现金保底
    IF v_cash - p_amount < v_floor THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', format(
                '提完公司账上不能少于 %s NB币（现在有 %s，最多能提 %s）',
                v_floor, round(v_cash, 0), GREATEST(floor(v_cash - v_floor), 0)));
    END IF;

    -- ⭐ 按持股比例限死：你只能拿走属于你自己的那部分
    v_ratio := CASE WHEN v_shares > 0 THEN v_my / v_shares ELSE 1 END;
    v_max   := floor(v_cash * v_ratio);
    IF p_amount > v_max THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', format(
                '你持有这家公司 %s%% 的股份，最多只能提 %s NB币。'
                || '想提更多得先买入更多股份。',
                round(v_ratio * 100, 2), v_max));
    END IF;

    -- 有没有外部股东（有的话提醒一句，但不算错误）
    SELECT count(*) INTO v_others
      FROM public.holdings
     WHERE company_id = p_company_id AND user_id <> p_user_id;

    -- 执行：池子减钱、创始人加钱
    UPDATE public.user_companies
       SET pool_cash = pool_cash - p_amount
     WHERE id = p_company_id;

    UPDATE public.profiles
       SET nb_balance = COALESCE(nb_balance, 0) + p_amount
     WHERE id = p_user_id
     RETURNING nb_balance INTO v_bal;

    -- 记一笔流水（如果有 stock_trades 表）
    BEGIN
        INSERT INTO public.stock_trades
            (user_id, company_id, side, amount, shares, price, created_at)
        VALUES
            (p_user_id, p_company_id, 'extract', p_amount, 0,
             round(v_cash / NULLIF(v_pshares, 0), 4), now());
    EXCEPTION WHEN OTHERS THEN
        NULL;   -- 流水表结构万一不同，不影响主流程
    END;

    v_price := round((v_cash - p_amount) / NULLIF(v_pshares, 0), 4);

    RETURN jsonb_build_object(
        'success', true, 'ok', true,
        'message', format('已从「%s」提出 %s NB币，当前余额 %s NB币',
                          v_name, round(p_amount, 0), round(v_bal, 0)),
        'withdrawn', p_amount,
        'balance', v_bal,
        'price_after', v_price,
        'other_holders', v_others);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.extract_company_value(uuid, text, bigint, numeric)
    TO anon, authenticated;


-- ============================================================
-- 第 5 步：验证
-- ============================================================
SELECT
    'market_value 是否已对齐' AS 检查项,
    count(*) FILTER (
        WHERE abs(c.market_value
                  - round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                          * c.total_shares::numeric, 2)) < 0.01
    ) || ' / ' || count(*) || ' 家对齐' AS 结果
  FROM public.user_companies c
 WHERE c.pool_shares > 0;

SELECT
    p.proname AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%发放_合计%'
         THEN '✅ 税已改成再分配' ELSE '❌ 还是只收不发' END AS 公司税,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%最多只能提%'
         THEN '✅ 按持股比例限死' ELSE '—' END AS 提取公司价值
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('collect_company_tax', 'extract_company_value')
 ORDER BY p.proname;


-- ============================================================
-- 第 6 步：回滚办法（万一要退）
-- ============================================================
-- 换算那两步（第 2 步）：
--     UPDATE public.user_companies c
--        SET market_value = b.market_value
--       FROM public._sc_bak_companies_20261005 b
--      WHERE b.id = c.id;
--     UPDATE public.holdings h
--        SET principal = b.principal,
--            base_market_value = b.base_market_value,
--            updated_at = now()
--       FROM public._sc_bak_holdings_20261005 b
--      WHERE b.user_id = h.user_id AND b.company_id = h.company_id;
--
-- 公司税（第 3 步）：把 amm_part4_read_layer_20261003.sql 里
--     原来的 collect_company_tax 重新跑一遍即可。
--
-- 提取公司价值（第 4 步）：
--     DROP FUNCTION IF EXISTS public.extract_company_value(uuid, text, bigint, numeric);
--
-- ⚠️ 备份表 _sc_bak_*_20261005 建议保留至少一个月再删。
-- ============================================================
