-- ============================================================
--  诊断：为什么还有 8 家 market_value 不对齐
--
--  触发器装上了、UPDATE 也跑了，但 85/93 没变成 93/93。
--  说明这 8 家的问题不是「值过期」，而是别的原因 —— 很可能是某个字段是空的。
--
--  用法：整段复制到 Supabase → SQL Editor → Run，把结果发我
-- ============================================================

-- ------------------------------------------------------------
-- 一、把不对齐的那几家全列出来，连关键字段一起看
-- ------------------------------------------------------------
SELECT
    c.id                                          AS 公司id,
    c.company_name                                AS 公司名,
    c.pool_cash                                   AS 池子现金,
    c.pool_shares                                 AS 池子股份,
    c.total_shares                                AS 总股数,
    c.market_value                                AS 现在存的值,
    round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
          * c.total_shares::numeric, 2)           AS 应该是多少,
    -- 逐个字段标出是不是空的，一眼定位
    CASE WHEN c.pool_cash   IS NULL THEN '⚠️ pool_cash 空'   ELSE '' END ||
    CASE WHEN c.pool_shares IS NULL THEN '⚠️ pool_shares 空' ELSE '' END ||
    CASE WHEN c.total_shares IS NULL THEN '⚠️ total_shares 空' ELSE '' END ||
    CASE WHEN c.market_value IS NULL THEN '⚠️ market_value 空' ELSE '' END
                                                  AS 可疑字段,
    c.founder_id IS NULL                          AS 没有创始人,
    (SELECT count(*) FROM public.holdings h WHERE h.company_id = c.id) AS 股东数
  FROM public.user_companies c
 WHERE c.pool_shares > 0
   AND (
        c.market_value IS NULL
     OR round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
              * c.total_shares::numeric, 2) IS NULL
     OR abs(c.market_value
            - round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                    * c.total_shares::numeric, 2)) >= 0.01
   )
 ORDER BY c.id;


-- ------------------------------------------------------------
-- 二、整体体检：每种「空值组合」各有多少家
-- ------------------------------------------------------------
SELECT
    count(*)                                                      AS 公司总数,
    count(*) FILTER (WHERE pool_shares IS NULL OR pool_shares = 0) AS pool_shares空或0,
    count(*) FILTER (WHERE pool_cash IS NULL)                      AS pool_cash空,
    count(*) FILTER (WHERE total_shares IS NULL)                   AS total_shares空,
    count(*) FILTER (WHERE market_value IS NULL)                   AS market_value空,
    count(*) FILTER (WHERE pool_shares > 0)                        AS 池子股份正常,
    -- 校验用的分母就是这个
    count(*) FILTER (
        WHERE pool_shares > 0
          AND abs(market_value
                  - round(pool_cash::numeric / NULLIF(pool_shares::numeric,0)
                          * total_shares::numeric, 2)) < 0.01
    )                                                              AS 对齐的
  FROM public.user_companies;


-- ------------------------------------------------------------
-- 三、字段类型（顺便确认 market_value 不是整数类型）
--     amm_part5 当时想把 market_value 改成 numeric(20,4)，
--     如果那个 ALTER 没跑到，它可能还是 bigint，
--     那样 round(x, 2) 存进去会被截成整数，永远差一点。
-- ------------------------------------------------------------
SELECT
    column_name      AS 字段,
    data_type        AS 类型,
    numeric_precision AS 精度,
    numeric_scale    AS 小数位,
    is_nullable      AS 可空
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'user_companies'
   AND column_name IN ('pool_cash','pool_shares','total_shares','market_value',
                       'circulating_shares','base_market_value')
 ORDER BY column_name;


-- ============================================================
--  怎么读结果
-- ============================================================
--  · 如果「可疑字段」那列写着某个字段空 → 那几家是数据本身有问题，
--    不是触发器没生效。要不要补值取决于业务上该怎么算，别乱补。
--
--  · 如果字段都不空、但类型那栏显示 market_value 是 bigint（小数位 0）
--    → 那就是类型的锅，round 到 2 位存不进去。重新跑一遍 amm_part5 的
--      ALTER COLUMN 就能解决。
--
--  · 如果都不空、类型也对、但算出来就是差 ≥ 0.01
--    → 把这几行的数字发我，我再算一遍。
-- ============================================================
