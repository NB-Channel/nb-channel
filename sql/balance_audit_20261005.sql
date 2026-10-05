-- ============================================================
--  余额分布体检 —— 钱到底堆在谁手里
--
--  背景：站长提出「蒸发一半不是好事吗，现在膨胀严重」。
--  这个判断可能是对的，但得先看清【膨胀在哪】：
--
--      公司账上（pool_cash）   = 玩家买股票真金白银投进来的，没有超发
--      余额（nb_balance）      = 里面混着当年刷出来的钱
--
--  如果超发的钱全堆在少数几个账号的余额里，
--  那「销毁公司账上的钱」就是在让持股的普通玩家亏钱，
--  却碰不到真正超发的那部分。
--
--  这个查询只做统计，不显示具体是谁（除了第一名，站长自己知道是谁）。
--  全部只读。
-- ============================================================


-- ============================================================
-- 一、总量对比：余额 vs 公司账上
-- ============================================================
SELECT
    (SELECT round(COALESCE(sum(nb_balance), 0), 0) FROM public.profiles)      AS 全站余额合计,
    (SELECT round(COALESCE(sum(pool_cash), 0), 0)   FROM public.user_companies) AS 公司账上合计,
    (SELECT count(*) FROM public.profiles)                                    AS 账号数,
    (SELECT count(*) FROM public.profiles WHERE COALESCE(nb_balance,0) > 0)   AS 有余额的账号,
    -- 余额合计 ÷ 公司账上合计，看超发有多严重
    round((SELECT COALESCE(sum(nb_balance), 0) FROM public.profiles)
          / NULLIF((SELECT COALESCE(sum(pool_cash), 0) FROM public.user_companies), 0), 1)
                                                                              AS 倍数_余额是公司账上的几倍;


-- ============================================================
-- 二、余额分布 —— 看是不是「极少数账号占了绝大部分」
-- ============================================================
WITH b AS (
    SELECT COALESCE(nb_balance, 0)::numeric AS v
      FROM public.profiles
),
s AS (SELECT sum(v) AS total FROM b)
SELECT
    '前 1 名'   AS 档, round(max(v), 0) AS 合计,
    round(max(v) / NULLIF((SELECT total FROM s), 0) * 100, 4) || '%' AS 占全站余额
  FROM (SELECT v FROM b ORDER BY v DESC LIMIT 1) t
UNION ALL
SELECT '前 3 名', round(sum(v), 0),
       round(sum(v) / NULLIF((SELECT total FROM s), 0) * 100, 4) || '%'
  FROM (SELECT v FROM b ORDER BY v DESC LIMIT 3) t
UNION ALL
SELECT '前 10 名', round(sum(v), 0),
       round(sum(v) / NULLIF((SELECT total FROM s), 0) * 100, 4) || '%'
  FROM (SELECT v FROM b ORDER BY v DESC LIMIT 10) t
UNION ALL
SELECT '前 20 名', round(sum(v), 0),
       round(sum(v) / NULLIF((SELECT total FROM s), 0) * 100, 4) || '%'
  FROM (SELECT v FROM b ORDER BY v DESC LIMIT 20) t
UNION ALL
SELECT '其余全部', round(sum(v), 0),
       round(sum(v) / NULLIF((SELECT total FROM s), 0) * 100, 4) || '%'
  FROM (SELECT v FROM b ORDER BY v DESC OFFSET 20) t;


-- ============================================================
-- 三、按量级分档 —— 看钱堆在什么尺度的账号里
-- ============================================================
SELECT
    CASE
        WHEN COALESCE(nb_balance,0) < 10000        THEN '1. 一万以下'
        WHEN COALESCE(nb_balance,0) < 1000000      THEN '2. 一万 ~ 一百万'
        WHEN COALESCE(nb_balance,0) < 100000000    THEN '3. 一百万 ~ 一亿'
        WHEN COALESCE(nb_balance,0) < 1000000000000 THEN '4. 一亿 ~ 一万亿'
        ELSE                                            '5. 一万亿以上 ⚠️'
    END                                                       AS 余额档,
    count(*)                                                  AS 账号数,
    round(COALESCE(sum(nb_balance), 0), 0)                    AS 这一档合计,
    round(COALESCE(sum(nb_balance), 0)
          / NULLIF((SELECT COALESCE(sum(nb_balance),0) FROM public.profiles), 0) * 100, 4)
        || '%'                                                AS 占全站余额
  FROM public.profiles
 GROUP BY 1
 ORDER BY 1;


-- ============================================================
-- 四、这些余额能买下多少公司
-- ============================================================
WITH s AS (
    SELECT COALESCE(sum(nb_balance), 0)::numeric     AS bal,
           COALESCE(sum(pool_cash), 0)::numeric      AS pools
      FROM public.profiles, public.user_companies
     LIMIT 1
)
SELECT
    (SELECT round(COALESCE(sum(nb_balance),0), 0) FROM public.profiles)       AS 全站余额,
    (SELECT round(COALESCE(sum(pool_cash),0), 0)   FROM public.user_companies) AS 全站公司账上,
    -- 全站余额能把所有公司账上买空几次
    round((SELECT COALESCE(sum(nb_balance),0) FROM public.profiles)
          / NULLIF((SELECT COALESCE(sum(pool_cash),0) FROM public.user_companies), 0), 1)
                                                                              AS 能买空全站几次;


-- ============================================================
--  怎么读
-- ============================================================
--  · 如果「倍数_余额是公司账上的几倍」是几十、几百甚至上亿 ——
--    说明余额严重超发，而销毁公司账上的钱根本治不了它。
--
--  · 如果「前 1 名」占了全站余额的九成以上 ——
--    那超发就集中在一个人身上，该动的是那个余额，不是公司账上。
--
--  · 如果第三张表「一万亿以上」那一档只有 1~2 个账号 ——
--    同上。
--
--  · 反过来，如果余额分布还算均匀、总量也就公司账上的几倍 ——
--    那说明膨胀没那么严重，销毁公司账上的钱确实是在伤普通人。
-- ============================================================
