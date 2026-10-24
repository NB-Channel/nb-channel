-- ============================================================
--  收税预览（第二版）—— 基准已改成市值
--
--  第一版（preview_tax_20261005.sql）写的时候基准还是「公司账上的钱」，
--  站长后来把 collect_company_tax 改成按市值收了，这份跟着改。
--
--  现行规则（照抄现在的 collect_company_tax）：
--    门槛：市值 ≥ 30 万
--    分档：市值 < 100 万      0.2%
--          市值 < 2000 万     0.5%
--          市值 < 5000 万     1.0%
--          否则               2.0%
--          占全站市值 > 40%   再 +5%（垄断税）
--    扣款：从公司账上扣，单次最多扣账上的 20%，扣完不低于 20000
--    发放：账上 > 0 且 < 100 万的中小公司，按账上从少到多排队，
--          每家拿 min(收税总额 ÷ 家数, 自己账上的 2%)，总额发完即停
--
--  全部只读，不改任何数据。
-- ============================================================


-- ============================================================
-- 一、交税明细
-- ============================================================
WITH m AS (
    SELECT c.id,
           c.company_name,
           c.pool_cash::numeric AS cash,
           round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                 * c.total_shares::numeric, 2) AS mktcap
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
),
site AS (SELECT COALESCE(sum(mktcap), 0) AS total FROM m),
calc AS (
    SELECT m.*,
           CASE WHEN m.mktcap <  1000000  THEN 0.002
                WHEN m.mktcap <  20000000 THEN 0.005
                WHEN m.mktcap <  50000000 THEN 0.010
                ELSE                           0.020 END AS base_rate,
           m.mktcap / NULLIF((SELECT total FROM site), 0) AS share
      FROM m
)
SELECT
    company_name                                          AS 公司,
    round(cash, 0)                                        AS 公司账上,
    round(mktcap, 0)                                      AS 市值,
    round(mktcap / NULLIF(cash, 0), 2)                    AS 倍数,
    round(share * 100, 2) || '%'                          AS 占全站,
    (base_rate * 100)::text || '%'
        || CASE WHEN share > 0.40 THEN ' + 5%(垄断)' ELSE '' END AS 税率,
    round(mktcap * (base_rate + CASE WHEN share > 0.40 THEN 0.05 ELSE 0 END), 0)
                                                          AS 按市值该收,
    round(LEAST(mktcap * (base_rate + CASE WHEN share > 0.40 THEN 0.05 ELSE 0 END),
                cash * 0.20,
                GREATEST(cash - 20000, 0)), 0)            AS 实际会收,
    CASE WHEN mktcap * (base_rate + CASE WHEN share > 0.40 THEN 0.05 ELSE 0 END)
              > cash * 0.20
         THEN '⚠️ 被 20% 上限截住' ELSE '' END             AS 备注
  FROM calc
 WHERE mktcap >= 300000
 ORDER BY mktcap DESC
 LIMIT 40;


-- ============================================================
-- 二、汇总：收多少 / 发多少 / 销毁多少
-- ============================================================
WITH m AS (
    SELECT c.pool_cash::numeric AS cash,
           round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                 * c.total_shares::numeric, 2) AS mktcap
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
),
site AS (SELECT COALESCE(sum(mktcap), 0) AS total FROM m),
taxed AS (
    SELECT LEAST(
               mktcap * (CASE WHEN mktcap <  1000000  THEN 0.002
                              WHEN mktcap <  20000000 THEN 0.005
                              WHEN mktcap <  50000000 THEN 0.010
                              ELSE                        0.020 END
                       + CASE WHEN mktcap / NULLIF((SELECT total FROM site), 0) > 0.40
                              THEN 0.05 ELSE 0 END),
               cash * 0.20,
               GREATEST(cash - 20000, 0)) AS tax
      FROM m
     WHERE mktcap >= 300000
),
budget AS (SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed),
small AS (
    SELECT c.pool_cash::numeric AS cash
      FROM public.user_companies c
     WHERE c.pool_cash > 0 AND c.pool_cash < 1000000
),
n AS (SELECT count(*)::numeric AS c FROM small),
calc AS (
    SELECT LEAST(floor((SELECT b FROM budget) / NULLIF((SELECT c FROM n), 0)),
                 floor(cash * 0.02)) AS want
      FROM small
),
tot AS (SELECT COALESCE(sum(want), 0)::numeric AS w FROM calc)
SELECT
    (SELECT round(total, 0) FROM site)                   AS 全站市值合计,
    (SELECT count(*) FROM taxed WHERE tax >= 1)          AS 交税公司数,
    (SELECT round(b, 0) FROM budget)                     AS 今晚收税合计,
    (SELECT count(*) FROM small)                         AS 中小公司数,
    (SELECT round(COALESCE(sum(cash), 0), 0) FROM small) AS 中小公司账上合计,
    (SELECT round(LEAST((SELECT b FROM budget), (SELECT w FROM tot)), 0))
                                                         AS 实际发放,
    (SELECT round(GREATEST((SELECT b FROM budget) - (SELECT w FROM tot), 0), 0))
                                                         AS 销毁,
    (SELECT round(LEAST((SELECT b FROM budget), (SELECT w FROM tot))
                  / NULLIF((SELECT b FROM budget), 0) * 100, 1) || '%')
                                                         AS 发放率;


-- ============================================================
-- 三、发放上限换成几个值，分别会怎样
-- ============================================================
WITH m AS (
    SELECT c.pool_cash::numeric AS cash,
           round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                 * c.total_shares::numeric, 2) AS mktcap
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
),
site AS (SELECT COALESCE(sum(mktcap), 0) AS total FROM m),
taxed AS (
    SELECT LEAST(
               mktcap * (CASE WHEN mktcap <  1000000  THEN 0.002
                              WHEN mktcap <  20000000 THEN 0.005
                              WHEN mktcap <  50000000 THEN 0.010
                              ELSE                        0.020 END
                       + CASE WHEN mktcap / NULLIF((SELECT total FROM site), 0) > 0.40
                              THEN 0.05 ELSE 0 END),
               cash * 0.20,
               GREATEST(cash - 20000, 0)) AS tax
      FROM m
     WHERE mktcap >= 300000
),
budget AS (SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed),
small AS (
    SELECT c.pool_cash::numeric AS cash
      FROM public.user_companies c
     WHERE c.pool_cash > 0 AND c.pool_cash < 1000000
),
n AS (SELECT count(*)::numeric AS c FROM small),
cfg AS (
    SELECT pct, floor((SELECT b FROM budget) / NULLIF((SELECT c FROM n), 0)) AS avgshare
      FROM (VALUES (2), (10), (20), (50), (100), (300)) AS v(pct)
),
calc AS (
    SELECT cfg.pct,
           LEAST(cfg.avgshare, floor(small.cash * cfg.pct / 100.0)) AS want
      FROM cfg CROSS JOIN small
),
tot AS (
    SELECT pct, COALESCE(sum(want), 0)::numeric AS w FROM calc GROUP BY pct
)
SELECT
    pct || '%'                                                     AS 发放上限,
    round(LEAST((SELECT b FROM budget), w), 0)                     AS 实发,
    round(GREATEST((SELECT b FROM budget) - w, 0), 0)              AS 销毁,
    round(LEAST((SELECT b FROM budget), w)
          / NULLIF((SELECT b FROM budget), 0) * 100, 1) || '%'     AS 发放率
  FROM tot
 ORDER BY pct;


-- ============================================================
--  怎么读
-- ============================================================
--  · 「销毁」占收税合计的比例，就是白白烧掉的钱。
--  · 「发放率」太低说明发放上限（自己账上的 2%）把管道堵死了 ——
--    收上来一大堆，能接住的只有几百块，剩下的全烧掉。
--  · 第三张表给几档参考。倍数换算：
--      2%   约 35 天翻倍      50%  约 2 天翻倍
--      10%  约 7 天翻倍       100% 约 1 天翻倍
--      20%  约 4 天翻倍       300% 半天翻倍
--  · ⚠️ 这只是模拟。真改要改 collect_company_tax 里的 v_give_pct 常量。
-- ============================================================
