-- ============================================================
-- 股票系统重构 · 第二部分：数据迁移（旧模型 → AMM）
-- ============================================================
--
-- 【必须在 amm_part1_schema_functions_20261003.sql 之后执行】
--
-- 【迁移的核心问题：池子现金从哪来】
--
--   旧模型里 market_value 是个虚数：
--       · 注册时白给 20000（没有任何资金来源）
--       · support_company 注资会推高它（这笔是真钱）
--       · buy_stock 不改变它（买家的钱被销毁了，没进公司）
--       · withdraw_company_value 会掏空它（真钱被提走）
--
--   所以【不能直接拿 market_value 当池子现金】—— 那等于把虚数变成真钱。
--
--   一家公司账上真正进过的钱 = Σ注资 - Σ提取。
--   这就是池子现金的来源。
--
-- 【迁移规则】
--   对每家公司：
--       池子现金 = GREATEST(Σ注资 - Σ提取, 20000)
--                  ↑ 不足 2 万时由系统补到 2 万（一次性启动资金，
--                    明确记账，不是漏洞）
--       价格     = 1.00
--       池子股份 = 池子现金 × 1（价格 1.00 时，钱数 = 股份数）
--       每个股东 = 他的旧持仓价值换算成股份
--                  旧持仓价值 = principal × (旧市值 ÷ base_market_value)
--       总股本   = 池子股份 + 所有股东股份之和
--
-- 【迁移后的效果】
--   · 每家公司价格都是 1.00（统一的起跑线）
--   · 股东的股份数 ≈ 他原来的持仓价值（数值上不变，只是从"本金"变成"张数"）
--   · 池子里的钱 = 公司账上真实有过的钱
--   · 全站货币总量【不增加】（除了系统补的那部分最低启动资金，会单独统计）
--
-- ⚠️ 执行前务必做第 0 步备份。
-- ============================================================


-- ============================================================
-- 第 0 步：备份
-- ============================================================
DROP TABLE IF EXISTS public._amm_bak_companies_20261003;
CREATE TABLE public._amm_bak_companies_20261003 AS
SELECT * FROM public.user_companies;

DROP TABLE IF EXISTS public._amm_bak_holdings_20261003;
CREATE TABLE public._amm_bak_holdings_20261003 AS
SELECT * FROM public.holdings;

DROP TABLE IF EXISTS public._amm_bak_profiles_20261003;
CREATE TABLE public._amm_bak_profiles_20261003 AS
SELECT id, username, nb_balance FROM public.profiles;

SELECT 'companies' AS 表, count(*) AS 条数 FROM public._amm_bak_companies_20261003
UNION ALL SELECT 'holdings', count(*) FROM public._amm_bak_holdings_20261003
UNION ALL SELECT 'profiles', count(*) FROM public._amm_bak_profiles_20261003;

-- 记下迁移前的全站总量，迁移后要对比
SELECT
    (SELECT COALESCE(sum(nb_balance),0) FROM public.profiles)          AS 迁移前_总余额,
    (SELECT COALESCE(sum(market_value),0) FROM public.user_companies)  AS 迁移前_总市值;


-- ============================================================
-- 第 1 步：预览 —— 先看每家公司会迁移成什么，别急着改
-- ============================================================
WITH sup AS (
    SELECT company_id,
           COALESCE(sum(amount),0) AS 注资总额
      FROM public.support_logs GROUP BY company_id
),
wd AS (
    SELECT company_id,
           COALESCE(sum(total_amount),0) AS 提取总额
      FROM public.transactions
     WHERE type IN ('withdraw','company_withdraw')
     GROUP BY company_id
),
hold AS (
    SELECT company_id, COALESCE(sum(principal),0) AS 本金合计
      FROM public.holdings GROUP BY company_id
)
SELECT
    c.id,
    c.company_name,
    c.market_value                                    AS 旧市值,
    COALESCE(sup.注资总额, 0)                          AS 历史注资,
    COALESCE(wd.提取总额, 0)                           AS 历史提取,
    COALESCE(sup.注资总额,0) - COALESCE(wd.提取总额,0)  AS 净进账,
    GREATEST(COALESCE(sup.注资总额,0) - COALESCE(wd.提取总额,0), 20000)
                                                      AS 迁移后池子现金,
    COALESCE(hold.本金合计, 0)                         AS 股东本金合计,
    (SELECT count(*) FROM public.holdings h WHERE h.company_id = c.id) AS 股东数,
    c.founder_id IS NOT NULL                          AS 有创始人
  FROM public.user_companies c
  LEFT JOIN sup  ON sup.company_id  = c.id
  LEFT JOIN wd   ON wd.company_id   = c.id
  LEFT JOIN hold ON hold.company_id = c.id
 ORDER BY c.market_value DESC NULLS LAST
 LIMIT 40;

-- 汇总：系统一共要补多少钱（净进账不足 2 万的那些公司）
WITH sup AS (SELECT company_id, COALESCE(sum(amount),0) AS s FROM public.support_logs GROUP BY company_id),
     wd  AS (SELECT company_id, COALESCE(sum(total_amount),0) AS w FROM public.transactions
              WHERE type IN ('withdraw','company_withdraw') GROUP BY company_id)
SELECT
    count(*) AS 公司总数,
    count(*) FILTER (WHERE GREATEST(COALESCE(sup.s,0) - COALESCE(wd.w,0), 20000) = 20000)
             AS 需要补足到2万的,
    sum(GREATEST(COALESCE(sup.s,0) - COALESCE(wd.w,0), 20000)) AS 迁移后全站池子现金合计,
    sum(GREATEST(20000 - (COALESCE(sup.s,0) - COALESCE(wd.w,0)), 0)) AS 系统要补的总额
  FROM public.user_companies c
  LEFT JOIN sup ON sup.company_id = c.id
  LEFT JOIN wd  ON wd.company_id  = c.id;


-- ============================================================
-- 第 2 步：正式迁移（看完第 1 步觉得没问题再跑）
-- ============================================================
DO $$
DECLARE
    c            RECORD;
    h            RECORD;
    v_sup        numeric;
    v_wd         numeric;
    v_pool       numeric;
    v_old_mv     numeric;
    v_base       numeric;
    v_val        numeric;
    v_total_hold numeric;
    v_founder    uuid;
    v_n_co       int := 0;
    v_n_hold     int := 0;
BEGIN
    FOR c IN SELECT * FROM public.user_companies LOOP
        v_old_mv := COALESCE(c.market_value, 20000);

        -- ① 池子现金 = 历史净进账，不足 2 万补到 2 万
        SELECT COALESCE(sum(amount),0) INTO v_sup
          FROM public.support_logs WHERE company_id = c.id;
        SELECT COALESCE(sum(total_amount),0) INTO v_wd
          FROM public.transactions
         WHERE company_id = c.id AND type IN ('withdraw','company_withdraw');
        v_pool := GREATEST(COALESCE(v_sup,0) - COALESCE(v_wd,0), 20000);

        -- ② 股东按旧持仓价值换算股份
        v_total_hold := 0;
        FOR h IN SELECT * FROM public.holdings WHERE company_id = c.id LOOP
            v_base := COALESCE(NULLIF(h.base_market_value, 0), v_old_mv);
            -- 旧持仓价值 = 本金 × (旧市值 / 基准市值)
            v_val  := GREATEST(COALESCE(h.principal, 0) * (v_old_mv / v_base), 0);
            UPDATE public.holdings
               SET shares = round(v_val, 4),
                   cost   = COALESCE(h.principal, 0),
                   updated_at = now()
             WHERE id = h.id;
            v_total_hold := v_total_hold + round(v_val, 4);
            v_n_hold := v_n_hold + 1;
        END LOOP;

        -- ③ 池子股份：价格定为 1.00，所以股份数 = 现金数
        --    总股本 = 池子股份 + 所有股东股份
        v_founder := COALESCE(c.founder_id, c.user_id);

        UPDATE public.user_companies
           SET pool_cash    = round(v_pool, 4),
               pool_shares  = round(v_pool, 4),
               total_shares = round(v_pool + v_total_hold, 4),
               founder_id   = v_founder,
               -- market_value 暂时同步成新口径，页面过渡期还要用
               market_value = round(v_pool + v_total_hold, 4)::bigint
         WHERE id = c.id;

        v_n_co := v_n_co + 1;
    END LOOP;

    RAISE NOTICE '迁移完成：% 家公司，% 条持仓', v_n_co, v_n_hold;
END $$;


-- ============================================================
-- 第 3 步：验收（四条都要过）
-- ============================================================

-- 3.1 每家公司：池子股份 + 股东股份 = 总股本
SELECT count(*) AS 股本不配对的公司数
  FROM public.user_companies c
 WHERE abs(c.total_shares -
           (c.pool_shares + COALESCE((SELECT sum(shares) FROM public.holdings
                                       WHERE company_id = c.id), 0))) > 0.01;
-- 预期 0

-- 3.2 每家公司价格都是 1.00
SELECT count(*) AS 价格不等于1的公司数,
       min(round(pool_cash / NULLIF(pool_shares,0), 4)) AS 最低价,
       max(round(pool_cash / NULLIF(pool_shares,0), 4)) AS 最高价
  FROM public.user_companies WHERE pool_shares > 0;
-- 预期 0 家、最低=最高=1.0000

-- 3.3 没有池子为 0 的公司（否则买卖会除以零）
SELECT count(*) AS 池子为0的公司 FROM public.user_companies WHERE pool_shares <= 0;
-- 预期 0

-- 3.4 全站货币总量对比（关键：余额不能变多）
SELECT
    (SELECT COALESCE(sum(nb_balance),0) FROM public.profiles)      AS 迁移后_总余额,
    (SELECT 迁移前_总余额 FROM (
        SELECT COALESCE(sum(nb_balance),0) AS 迁移前_总余额
          FROM public._amm_bak_profiles_20261003) x)               AS 迁移前_总余额,
    (SELECT COALESCE(sum(pool_cash),0) FROM public.user_companies) AS 迁移后_池子现金合计,
    (SELECT COALESCE(sum(market_value),0) FROM public.user_companies) AS 迁移后_总市值;
-- 余额应该【一分没变】。池子现金合计 = 系统真实注资净额 + 补足部分。

-- 3.5 抽查几家公司看细节
SELECT c.company_name,
       c.pool_cash, c.pool_shares, c.total_shares,
       round(c.pool_cash / NULLIF(c.pool_shares,0), 4) AS 股价,
       (SELECT count(*) FROM public.holdings h WHERE h.company_id = c.id) AS 股东数,
       (SELECT COALESCE(sum(shares),0) FROM public.holdings h WHERE h.company_id = c.id) AS 股东股份合计
  FROM public.user_companies c
 ORDER BY c.pool_cash DESC LIMIT 15;


-- ============================================================
-- 第 4 步：迁移完先别关维护模式
-- ------------------------------------------------------------
-- 顺序是：
--   1. 跑本脚本
--   2. 跑第 3 步验收，四条都过
--   3. 改前端页面
--   4. 用站长自己的号试几笔买卖
--   5. 确认没问题 → 关维护模式
-- ============================================================
-- UPDATE public.stock_settings SET value='0', updated_at=now()
--  WHERE key='maintenance';


-- ============================================================
-- 出问题怎么回滚
-- ============================================================
-- 把公司表和持仓表恢复原样：
-- UPDATE public.user_companies c
--    SET market_value = b.market_value,
--        pool_cash = 0, pool_shares = 0, total_shares = 0
--   FROM public._amm_bak_companies_20261003 b
--  WHERE c.id = b.id;
--
-- UPDATE public.holdings h
--    SET principal = b.principal,
--        base_market_value = b.base_market_value,
--        shares = 0, cost = 0
--   FROM public._amm_bak_holdings_20261003 b
--  WHERE h.id = b.id;
--
-- 余额本来就没动，不用恢复。
