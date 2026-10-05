-- ⚠️ 这份【已过期】—— 写的时候收税基准还是「公司账上的钱」，
--    后来站长改成了按「市值」收。请用 sql\preview_tax_v2_20261005.sql
-- ============================================================
--  今晚 20:00 收税会发生什么 —— 按真实规则模拟一遍
--
--  这个查询【只读不改】，放心跑。
--  它照抄 collect_company_tax() 里的算法，把今晚的结果先算给你看：
--    · 哪几家要交税、各交多少
--    · 一共收上来多少
--    · 哪些中小公司能分到、各分多少
--    · 最后销毁多少
--
--  规则（和函数里一致）：
--    交税：账上 ≥ 30 万才收；税率按总额一刀切
--             < 100 万      0.2%
--             < 2000 万     0.5%
--             < 5000 万     1.0%
--             否则          2.0%
--          账上占全站总额 > 40% 的，再加 5% 垄断税
--          扣款保底 20000
--    发钱：账上 > 0 且 < 100 万的中小公司，按账上从少到多排队，
--          每家拿 min(总额 ÷ 家数, 自己账上的 2%)，总额发完即停
-- ============================================================


-- ============================================================
-- 一、交税明细（谁交、交多少、交完剩多少）
-- ============================================================
WITH site AS (
    SELECT COALESCE(sum(pool_cash), 0)::numeric AS total
      FROM public.user_companies
),
calc AS (
    SELECT
        c.id,
        c.company_name,
        c.pool_cash::numeric                                   AS 现在账上,
        CASE
            WHEN c.pool_cash <  1000000  THEN 0.002
            WHEN c.pool_cash <  20000000 THEN 0.005
            WHEN c.pool_cash <  50000000 THEN 0.010
            ELSE                              0.020
        END                                                    AS 基础税率,
        c.pool_cash::numeric / NULLIF((SELECT total FROM site), 0) AS 占全站比,
        CASE
            WHEN c.pool_cash::numeric / NULLIF((SELECT total FROM site), 0) > 0.40
            THEN 0.05 ELSE 0 END                               AS 垄断加成,
        (SELECT total FROM site)                               AS 全站总额
      FROM public.user_companies c
     WHERE c.pool_cash >= 300000
)
SELECT
    company_name                                               AS 公司,
    round(现在账上, 0)                                          AS 现在账上,
    round(占全站比 * 100, 2) || '%'                             AS 占全站,
    (基础税率 * 100)::text || '%'
        || CASE WHEN 垄断加成 > 0 THEN ' + 5%(垄断)' ELSE '' END AS 税率,
    round(现在账上 * (基础税率 + 垄断加成), 0)                    AS 今晚要交,
    GREATEST(round(现在账上 - 现在账上 * (基础税率 + 垄断加成), 0), 20000) AS 交完剩,
    round(现在账上 * (基础税率 + 垄断加成), 0)                    AS 计入发放池
  FROM calc
 ORDER BY 现在账上 DESC;


-- ============================================================
-- 二、汇总：收多少 / 发给谁 / 销毁多少
-- ============================================================
WITH site AS (
    SELECT COALESCE(sum(pool_cash), 0)::numeric AS total FROM public.user_companies
),
taxed AS (
    SELECT c.id,
           floor(c.pool_cash::numeric * (
               CASE WHEN c.pool_cash <  1000000  THEN 0.002
                    WHEN c.pool_cash <  20000000 THEN 0.005
                    WHEN c.pool_cash <  50000000 THEN 0.010
                    ELSE                              0.020 END
             + CASE WHEN c.pool_cash::numeric / NULLIF((SELECT total FROM site),0) > 0.40
                    THEN 0.05 ELSE 0 END)) AS tax
      FROM public.user_companies c
     WHERE c.pool_cash >= 300000
),
budget AS (SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed),
small AS (
    SELECT c.id, c.company_name, c.pool_cash::numeric AS cash,
           row_number() OVER (ORDER BY c.pool_cash ASC, c.id ASC) AS rn
      FROM public.user_companies c
     WHERE c.pool_cash > 0 AND c.pool_cash < 1000000
),
cnt AS (SELECT count(*)::numeric AS n FROM small),
give AS (
    SELECT s.id, s.company_name, s.cash, s.rn,
           LEAST(floor((SELECT b FROM budget) / NULLIF((SELECT n FROM cnt), 0)),
                 floor(s.cash * 0.02)) AS want
      FROM small s
),
cum AS (
    SELECT g.*, COALESCE(sum(want) OVER (ORDER BY rn ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS before_sum
      FROM give g
)
SELECT
    (SELECT round(b, 0) FROM budget)                       AS 今晚收税合计,
    (SELECT count(*) FROM taxed WHERE tax >= 1)            AS 交税公司数,
    (SELECT count(*) FROM small)                           AS 中小公司数,
    (SELECT round(COALESCE(sum(
         CASE WHEN before_sum < (SELECT b FROM budget) THEN want ELSE 0 END), 0)) FROM cum)
                                                           AS 实际发放合计,
    (SELECT count(*) FROM cum
      WHERE before_sum < (SELECT b FROM budget) AND want >= 1)
                                                           AS 能分到的公司数,
    (SELECT round(b, 0) FROM budget)
      - (SELECT COALESCE(sum(
           CASE WHEN before_sum < (SELECT b FROM budget) THEN want ELSE 0 END), 0) FROM cum)
                                                           AS 销毁;


-- ============================================================
-- 三、能分到钱的中小公司（按分到的顺序）
-- ============================================================
WITH site AS (
    SELECT COALESCE(sum(pool_cash), 0)::numeric AS total FROM public.user_companies
),
taxed AS (
    SELECT floor(c.pool_cash::numeric * (
               CASE WHEN c.pool_cash <  1000000  THEN 0.002
                    WHEN c.pool_cash <  20000000 THEN 0.005
                    WHEN c.pool_cash <  50000000 THEN 0.010
                    ELSE                              0.020 END
             + CASE WHEN c.pool_cash::numeric / NULLIF((SELECT total FROM site),0) > 0.40
                    THEN 0.05 ELSE 0 END)) AS tax
      FROM public.user_companies c
     WHERE c.pool_cash >= 300000
),
budget AS (SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed),
small AS (
    SELECT c.id, c.company_name, c.pool_cash::numeric AS cash,
           row_number() OVER (ORDER BY c.pool_cash ASC, c.id ASC) AS rn
      FROM public.user_companies c
     WHERE c.pool_cash > 0 AND c.pool_cash < 1000000
),
cnt AS (SELECT count(*)::numeric AS n FROM small),
give AS (
    SELECT s.id, s.company_name, s.cash, s.rn,
           LEAST(floor((SELECT b FROM budget) / NULLIF((SELECT n FROM cnt), 0)),
                 floor(s.cash * 0.02)) AS want
      FROM small s
),
cum AS (
    SELECT g.*, COALESCE(sum(want) OVER (ORDER BY rn ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS before_sum
      FROM give g
)
SELECT
    rn                                                              AS 顺序,
    company_name                                                    AS 公司,
    round(cash, 0)                                                  AS 现在账上,
    CASE WHEN before_sum < (SELECT b FROM budget) THEN want ELSE 0 END AS 今晚能拿,
    round(CASE WHEN before_sum < (SELECT b FROM budget) THEN want ELSE 0 END
          / NULLIF(cash, 0) * 100, 2)                               AS 涨幅百分比
  FROM cum
 ORDER BY rn
 LIMIT 40;


-- ============================================================
--  怎么读
-- ============================================================
--  · 「今晚收税合计」就是发放池的总预算
--  · 「销毁」是发不完剩下的 —— 这部分会让全站轻微通缩
--  · 第三张表按发放顺序排，涨得最多的是最穷的那几家
--  · 每家涨幅上限就是自己账上的 2%（上表「涨幅百分比」一列看得出来）
--
--  ⚠️ 这是模拟，实际以函数跑出来的为准 ——
--     因为触发时各家的账上余额可能已经因为别的交易变了。
-- ============================================================
