-- ============================================================
--  补跑 amm_part5：把 market_value / total_shares 改成 numeric
--
--  为什么现在才跑
--    amm_part5_fix_column_types_20261003.sql 当时就是干这个的，
--    但一直没被执行 —— 所以这两列到现在还是 integer。
--
--    Part 1 里写的是：
--        ADD COLUMN IF NOT EXISTS total_shares numeric
--    可是 total_shares 这一列【旧系统早就在用】，已经存在，
--    IF NOT EXISTS 直接跳过 —— 类型根本没改，还是 integer。
--    market_value 同理。
--
--  这会造成什么
--    ① market_value 存不下小数
--       市值算出来 1.66 亿零 0.5 → 存进 integer 被截成 1.66 亿
--       → 和真实值差 0.5 → 就是站长看到的那 8 家「不对齐」
--       （另外 85 家市值正好是整数，所以没露馅）
--
--    ② total_shares 也被四舍五入过
--       总股数本该是 338775510.7142 这种小数，存成 integer 就变成 338775511
--       → 分红比例、市值计算都会带一点误差
--       ⚠️ 已经存进去的旧值改不回来（精度已经丢了），
--          但改完类型之后，【以后】写的值就带小数了。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 一、先看现状（确认还是 integer）
-- ============================================================
SELECT
    column_name       AS 字段,
    data_type         AS 类型,
    numeric_scale     AS 小数位,
    is_nullable       AS 可空
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'user_companies'
   AND column_name IN ('market_value','total_shares','circulating_shares',
                       'pool_cash','pool_shares')
 ORDER BY column_name;

-- 顺便看 holdings 那几张表，它们的 shares 也可能有同样的问题
SELECT
    table_name        AS 表,
    column_name       AS 字段,
    data_type         AS 类型,
    numeric_scale     AS 小数位
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('holdings','holdings_history','stock_trades')
   AND column_name IN ('shares','cost','principal','base_market_value',
                       'amount','price','pool_cash','pool_shares')
 ORDER BY table_name, column_name;


-- ============================================================
-- 二、改类型
-- ============================================================
-- 用 USING 显式转换，避免有视图/索引依赖时报错。
-- numeric(20,4)：整数部分 16 位（远超现在任何数值），小数 4 位。

ALTER TABLE public.user_companies
    ALTER COLUMN total_shares TYPE numeric(20,4) USING total_shares::numeric(20,4);

ALTER TABLE public.user_companies
    ALTER COLUMN market_value TYPE numeric(20,4) USING market_value::numeric(20,4);

-- circulating_shares 是旧字段，页面可能还在读，一起改
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema='public' AND table_name='user_companies'
                  AND column_name='circulating_shares') THEN
        ALTER TABLE public.user_companies
            ALTER COLUMN circulating_shares TYPE numeric(20,4)
            USING circulating_shares::numeric(20,4);
        RAISE NOTICE 'circulating_shares 也改成 numeric 了';
    END IF;
END $$;

-- pool_cash / pool_shares 本来就是 numeric，这里再写一遍只是为了保险
ALTER TABLE public.user_companies
    ALTER COLUMN pool_cash   TYPE numeric(20,4) USING pool_cash::numeric(20,4);
ALTER TABLE public.user_companies
    ALTER COLUMN pool_shares TYPE numeric(20,4) USING pool_shares::numeric(20,4);


-- ============================================================
-- 三、顺手把 holdings 里同类的整数列也改掉（如果有）
-- ============================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT column_name
          FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'holdings'
           AND column_name IN ('shares','cost','principal','base_market_value')
           AND data_type IN ('integer','bigint','smallint')
    LOOP
        EXECUTE format(
            'ALTER TABLE public.holdings ALTER COLUMN %I TYPE numeric(20,4) '
            || 'USING %I::numeric(20,4)', r.column_name, r.column_name);
        RAISE NOTICE 'holdings.% 也改成 numeric 了', r.column_name;
    END LOOP;
END $$;


-- ============================================================
-- 四、类型对了，把 market_value 重新算一遍
-- ============================================================
-- 触发器 trg_sync_market_value 只在这三列被 SET 时才触发，
-- 而下面这句只 SET market_value —— 所以不会触发触发器，
-- 是直接写进去的，正好。
UPDATE public.user_companies
   SET market_value = round(
           pool_cash::numeric / NULLIF(pool_shares::numeric, 0) * total_shares::numeric, 2)
 WHERE pool_shares > 0;


-- ============================================================
-- 五、验收
-- ============================================================

-- 5.1 类型全对了没（应该全是 numeric）
SELECT
    column_name   AS 字段,
    data_type     AS 类型,
    numeric_scale AS 小数位
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = 'user_companies'
   AND column_name IN ('market_value','total_shares','circulating_shares',
                       'pool_cash','pool_shares')
 ORDER BY column_name;

-- 5.2 市值对齐（这次应该是 93 / 93）
SELECT
    count(*) FILTER (
        WHERE abs(c.market_value
                  - round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                          * c.total_shares::numeric, 2)) < 0.01
    ) || ' / ' || count(*) || ' 家对齐' AS "market_value 对齐情况"
  FROM public.user_companies c
 WHERE c.pool_shares > 0;

-- 5.3 还不对齐的，列出来看看是什么情况
SELECT id, company_name, pool_cash, pool_shares, total_shares, market_value
  FROM public.user_companies
 WHERE pool_shares > 0
   AND (market_value IS NULL
        OR abs(market_value
               - round(pool_cash::numeric / NULLIF(pool_shares::numeric,0)
                       * total_shares::numeric, 2)) >= 0.01);

-- 5.4 行情接口还能正常返回吗（改类型最容易在这里出问题）
SELECT * FROM public.get_market_list(NULL) LIMIT 5;


-- ============================================================
--  改完之后
-- ============================================================
--  · 5.2 应该显示 93 / 93
--  · 5.4 如果报错「Returned type ... does not match expected type ...」，
--    说明还有别的函数没跟上新类型 —— 把 amm_part4_read_layer_20261003.sql
--    整段重跑一遍即可（里面的 CREATE OR REPLACE 都是幂等的）。
--
--  ⚠️ total_shares 以前被截断丢掉的小数【找不回来】了 ——
--     这次只是保证以后不再丢。已经存着的整数值继续用，
--     影响是分红比例上小数点后几位的误差，可以忽略。
-- ============================================================
