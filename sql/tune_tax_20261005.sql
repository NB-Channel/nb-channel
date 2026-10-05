-- ============================================================
--  Utw 系公司明细 + 再分配参数调优对比
--
--  背景：站长贴出的发放名单里，几十家公司全是「账上 20000 / 拿到 400 / 涨 2%」。
--  说明发放被【自己账上的 2%】这个上限卡死了 ——
--  小公司基数太小，2% 根本吃不下收上来的税，绝大部分直接被销毁。
--
--  这个查询做三件事（全部只读）：
--    一、Utw 系公司交多少税
--    二、全站汇总：收多少 / 现在这套参数发多少 / 销毁多少
--    三、把发放上限换成 2% / 10% / 20% / 50% / 100%，分别会怎样
--
--  跑完把【二】和【三】的结果发我，我据此定参数。
-- ============================================================


-- ============================================================
-- 一、Utw 系公司（公司名或创始人名里带 utw 的）
-- ============================================================
WITH site AS (
    SELECT COALESCE(sum(pool_cash), 0)::numeric AS total FROM public.user_companies
)
SELECT
    c.id                                                              AS 编号,
    c.company_name                                                     AS 公司,
    COALESCE(p.username, '—')                                          AS 创始人,
    round(c.pool_cash::numeric, 0)                                     AS 现在账上,
    round(c.pool_cash::numeric / NULLIF((SELECT total FROM site), 0) * 100, 3)
        || '%'                                                         AS 占全站,
    CASE
        WHEN c.pool_cash <  1000000  THEN '0.2%'
        WHEN c.pool_cash <  20000000 THEN '0.5%'
        WHEN c.pool_cash <  50000000 THEN '1.0%'
        ELSE                              '2.0%'
    END
    || CASE WHEN c.pool_cash::numeric / NULLIF((SELECT total FROM site), 0) > 0.40
            THEN ' + 5%(垄断)' ELSE '' END                             AS 税率,
    CASE WHEN c.pool_cash >= 300000
         THEN round(floor(c.pool_cash::numeric * (
                  CASE WHEN c.pool_cash <  1000000  THEN 0.002
                       WHEN c.pool_cash <  20000000 THEN 0.005
                       WHEN c.pool_cash <  50000000 THEN 0.010
                       ELSE                              0.020 END
                + CASE WHEN c.pool_cash::numeric / NULLIF((SELECT total FROM site),0) > 0.40
                       THEN 0.05 ELSE 0 END)), 0)
         ELSE 0 END                                                    AS 今晚交税,
    CASE WHEN c.pool_cash >= 300000 THEN '交税'
         WHEN c.pool_cash > 0 AND c.pool_cash < 1000000 THEN '能领'
         ELSE '—' END                                                  AS 身份
  FROM public.user_companies c
  LEFT JOIN public.profiles p ON p.id = c.founder_id
 WHERE c.company_name ILIKE '%utw%'
    OR COALESCE(p.username, '') ILIKE '%utw%'
 ORDER BY c.pool_cash DESC;


-- ============================================================
-- 二、全站汇总：当前规则（发放上限 = 自己账上的 2%）
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
budget AS (
    SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed
),
small AS (
    SELECT c.pool_cash::numeric AS cash
      FROM public.user_companies c
     WHERE c.pool_cash > 0 AND c.pool_cash < 1000000
),
n AS (
    SELECT count(*)::numeric AS c FROM small
),
calc AS (
    SELECT LEAST(
               floor((SELECT b FROM budget) / NULLIF((SELECT c FROM n), 0)),
               floor(cash * 0.02)) AS want
      FROM small
),
tot AS (
    SELECT COALESCE(sum(want), 0)::numeric AS w FROM calc
)
SELECT
    (SELECT round(total, 0) FROM site)                    AS 全站公司账上总额,
    (SELECT count(*) FROM taxed WHERE tax >= 1)           AS 交税公司数,
    (SELECT round(b, 0) FROM budget)                      AS 今晚收税合计,
    (SELECT count(*) FROM small)                          AS 中小公司数,
    (SELECT round(COALESCE(sum(cash), 0), 0) FROM small)  AS 中小公司账上合计,
    (SELECT round(LEAST((SELECT b FROM budget), (SELECT w FROM tot)), 0))
                                                          AS 当前规则_实发,
    (SELECT round(GREATEST((SELECT b FROM budget) - (SELECT w FROM tot), 0), 0))
                                                          AS 当前规则_销毁,
    (SELECT round(LEAST((SELECT b FROM budget), (SELECT w FROM tot))
                  / NULLIF((SELECT b FROM budget), 0) * 100, 1) || '%')
                                                          AS 当前规则_发放率;


-- ============================================================
-- 三、发放上限换成几个值，分别会怎样
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
budget AS (
    SELECT COALESCE(sum(tax), 0)::numeric AS b FROM taxed
),
small AS (
    SELECT c.pool_cash::numeric AS cash
      FROM public.user_companies c
     WHERE c.pool_cash > 0 AND c.pool_cash < 1000000
),
n AS (
    SELECT count(*)::numeric AS c FROM small
),
cfg AS (
    SELECT pct,
           floor((SELECT b FROM budget) / NULLIF((SELECT c FROM n), 0)) AS avgshare
      FROM (VALUES (2), (10), (20), (50), (100)) AS v(pct)
),
calc AS (
    SELECT cfg.pct,
           LEAST(cfg.avgshare, floor(small.cash * cfg.pct / 100.0)) AS want
      FROM cfg CROSS JOIN small
),
tot AS (
    SELECT pct, COALESCE(sum(want), 0)::numeric AS w
      FROM calc GROUP BY pct
)
SELECT
    pct || '%'                                                       AS 发放上限,
    round(LEAST((SELECT b FROM budget), w), 0)                       AS 实发,
    round(GREATEST((SELECT b FROM budget) - w, 0), 0)                AS 销毁,
    round(LEAST((SELECT b FROM budget), w)
          / NULLIF((SELECT b FROM budget), 0) * 100, 1) || '%'       AS 发放率
  FROM tot
 ORDER BY pct;


-- ============================================================
--  怎么读
-- ============================================================
--  · 「当前规则_销毁」如果占了收税合计的九成以上 ——
--    说明 2% 这个上限太小，钱基本都被烧掉了。
--
--  · 第三张表看「发放率」：
--      哪个百分比能把大部分税发出去，又不会让公司一天暴涨失控，就用哪个。
--
--  · 参考倍数（按复利粗算）：
--      2%   约 35 天翻倍
--      10%  约 7 天翻倍
--      20%  约 4 天翻倍
--    小公司本来就该长得快，但太快会让别人不敢买（怕被稀释）。
--
--  · ⚠️ 这个查询只是【模拟】。改参数要改 collect_company_tax() 里的
--    v_cap_pct 常量 —— 想改的话告诉我，我写好 SQL 给你。
-- ============================================================
