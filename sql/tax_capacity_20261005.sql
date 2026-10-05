-- ============================================================
--  再分配容量分析 —— 到底能发出去多少
--
--  上一份查询的结果：
--      收税合计 3045 万，但发放率最高只到 22.6%（上限调到 300% 时），
--      剩下 77% 直接销毁。
--
--  根子：接收方（账上 < 100 万的中小公司）总池子只有约 262 万，
--  而要发 3045 万 —— 得让它们一天涨 1162%，不可能。
--
--  这个查询回答两个问题（全部只读）：
--    一、如果把「接收门槛」往上提，接收方的总池子能有多大？
--    二、门槛 × 发放上限 的各种组合下，实发 / 销毁 / 平均涨幅分别是多少？
--
--  跑完把两张表都发我。
-- ============================================================


-- ============================================================
-- 一、不同接收门槛下，接收方的家数与总池子
-- ============================================================
WITH site AS (
    SELECT COALESCE(sum(pool_cash), 0)::numeric AS total FROM public.user_companies
),
taxed AS (
    SELECT LEAST(
               round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                     * c.total_shares::numeric, 2)
               * (CASE WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2) <  1000000  THEN 0.002
                       WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2) <  20000000 THEN 0.005
                       WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2) <  50000000 THEN 0.010
                       ELSE                                              0.020 END
                + CASE WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2)
                            / NULLIF((SELECT total FROM site), 0) > 0.40
                       THEN 0.05 ELSE 0 END),
               c.pool_cash::numeric * 0.20,
               GREATEST(c.pool_cash::numeric - 20000, 0)) AS tax
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
       AND round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                 * c.total_shares::numeric, 2) >= 300000
),
budget AS (SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed)
SELECT
    line || ' 万'                                  AS 接收门槛,
    (SELECT count(*) FROM public.user_companies
      WHERE pool_cash > 0 AND pool_cash < line * 10000)          AS 家数,
    (SELECT round(COALESCE(sum(pool_cash), 0), 0) FROM public.user_companies
      WHERE pool_cash > 0 AND pool_cash < line * 10000)          AS 接收方总池子,
    (SELECT round(b, 0) FROM budget)                             AS 收税合计,
    -- 要发完的话，接收方平均要涨多少
    round((SELECT b FROM budget)
          / NULLIF((SELECT COALESCE(sum(pool_cash), 0) FROM public.user_companies
                     WHERE pool_cash > 0 AND pool_cash < line * 10000), 0) * 100, 1)
                                                                 AS 发完需涨百分比
  FROM (VALUES (100), (500), (2000), (5000), (10000), (20000), (50000)) AS v(line)
 ORDER BY line;


-- ============================================================
-- 二、门槛 × 发放上限 的组合矩阵
--    每个组合给出：实发 / 销毁 / 发放率 / 接收方平均涨幅
-- ============================================================
WITH site AS (
    SELECT COALESCE(sum(pool_cash), 0)::numeric AS total FROM public.user_companies
),
taxed AS (
    SELECT LEAST(
               round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                     * c.total_shares::numeric, 2)
               * (CASE WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2) <  1000000  THEN 0.002
                       WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2) <  20000000 THEN 0.005
                       WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2) <  50000000 THEN 0.010
                       ELSE                                              0.020 END
                + CASE WHEN round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                                 * c.total_shares::numeric, 2)
                            / NULLIF((SELECT total FROM site), 0) > 0.40
                       THEN 0.05 ELSE 0 END),
               c.pool_cash::numeric * 0.20,
               GREATEST(c.pool_cash::numeric - 20000, 0)) AS tax
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
       AND round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                 * c.total_shares::numeric, 2) >= 300000
),
budget AS (SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed),
lines AS (SELECT * FROM (VALUES (100), (500), (2000), (5000), (10000)) AS v(line)),
pcts  AS (SELECT * FROM (VALUES (2), (10), (20), (50), (100)) AS v(pct)),
grid  AS (SELECT lines.line, pcts.pct FROM lines CROSS JOIN pcts),
small AS (
    SELECT g.line, g.pct, c.pool_cash::numeric AS cash
      FROM grid g
      JOIN public.user_companies c
        ON c.pool_cash > 0 AND c.pool_cash < g.line * 10000
),
cnt AS (
    SELECT line, pct, count(*)::numeric AS n, COALESCE(sum(cash), 0)::numeric AS pool
      FROM small GROUP BY line, pct
),
calc AS (
    SELECT s.line, s.pct, s.cash,
           LEAST(floor((SELECT b FROM budget) / NULLIF(cc.n, 0)),
                 floor(s.cash * s.pct / 100.0)) AS want,
           cc.pool
      FROM small s JOIN cnt cc ON cc.line = s.line AND cc.pct = s.pct
),
tot AS (
    SELECT line, pct, COALESCE(sum(want), 0)::numeric AS w, max(pool) AS pool
      FROM calc GROUP BY line, pct
)
SELECT
    line || ' 万'                                              AS 接收门槛,
    pct || '%'                                                 AS 发放上限,
    round(LEAST((SELECT b FROM budget), w), 0)                 AS 实发,
    round(GREATEST((SELECT b FROM budget) - w, 0), 0)          AS 销毁,
    round(LEAST((SELECT b FROM budget), w)
          / NULLIF((SELECT b FROM budget), 0) * 100, 1) || '%' AS 发放率,
    round(LEAST((SELECT b FROM budget), w) / NULLIF(pool, 0) * 100, 1) || '%'
                                                               AS 接收方平均涨幅
  FROM tot
 ORDER BY line, pct;


-- ============================================================
--  怎么读
-- ============================================================
--  · 第一张表找「发完需涨百分比」——
--    这个数就是「把所有税都发出去，接收方得涨多少」。
--    几百以内还能考虑，上千就不现实了。
--
--  · 第二张表找「发放率高 + 接收方平均涨幅可接受」的那个组合。
--    涨幅参考：一天 1~3% 玩家感觉明显但不夸张；
--              一天 10% 已经很快；一天 50% 以上就太疯了。
--
--  · 如果怎么调都发不出去，那结论就是【收税收太多了】——
--    那就得降税率（基准换成市值之后，税率其实该跟着减半）。
-- ============================================================
