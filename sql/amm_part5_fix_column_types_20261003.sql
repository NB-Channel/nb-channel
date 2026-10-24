-- ============================================================
-- 修正列类型：total_shares / market_value 之前是 integer
-- ============================================================
-- 报错：Returned type integer does not match expected type numeric in column 7
--
-- 原因：Part 1 里写的是 ADD COLUMN IF NOT EXISTS total_shares numeric，
--       但 total_shares 这一列【早就存在】（旧系统就在用），
--       所以 IF NOT EXISTS 直接跳过，类型没改，还是 integer。
--
--       AMM 的池子股份会是小数（比如 19047.619047…），
--       integer 存不下，必须改成 numeric。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 一、先看现状
-- ============================================================
SELECT column_name, data_type, numeric_precision, numeric_scale
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'user_companies'
   AND column_name IN ('market_value','total_shares','circulating_shares',
                       'pool_cash','pool_shares')
 ORDER BY column_name;

SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'holdings'
   AND column_name IN ('shares','cost','principal','base_market_value')
 ORDER BY column_name;


-- ============================================================
-- 二、改成 numeric
-- ============================================================
-- 用 USING 显式转换，避免有视图/索引依赖时报错。
-- numeric(20,4) 够用：整数部分 16 位（远超现在任何数值），小数 4 位。

ALTER TABLE public.user_companies
    ALTER COLUMN total_shares TYPE numeric(20,4) USING total_shares::numeric(20,4);

ALTER TABLE public.user_companies
    ALTER COLUMN market_value TYPE numeric(20,4) USING market_value::numeric(20,4);

-- circulating_shares 如果存在也一起改（旧字段，页面可能还在读）
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

-- pool_cash / pool_shares 建的时候就是 numeric（Part 1 新建的），但保险起见再写一遍
ALTER TABLE public.user_companies
    ALTER COLUMN pool_cash   TYPE numeric(20,4) USING pool_cash::numeric(20,4);
ALTER TABLE public.user_companies
    ALTER COLUMN pool_shares TYPE numeric(20,4) USING pool_shares::numeric(20,4);


-- ============================================================
-- 三、验收：类型都对了
-- ============================================================
SELECT column_name, data_type, numeric_precision, numeric_scale
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'user_companies'
   AND column_name IN ('market_value','total_shares','circulating_shares',
                       'pool_cash','pool_shares')
 ORDER BY column_name;
-- 应该全是 numeric


-- ============================================================
-- 四、重跑读取层（把 amm_part4 整段再执行一遍）
-- ------------------------------------------------------------
-- 类型改对之后，get_market_list 就能正常返回了。
-- 直接重跑 amm_part4_read_layer_20261003.sql 整段即可 ——
-- 里面的 CREATE OR REPLACE FUNCTION 都是幂等的。
-- ============================================================


-- ============================================================
-- 五、改完之后立刻试一下
-- ============================================================
-- 带站长 uuid（含"我持有多少"）
SELECT * FROM public.get_market_list('22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid) LIMIT 5;

-- 不带用户（纯行情）
SELECT * FROM public.get_market_list(NULL) LIMIT 5;

-- 持仓
SELECT * FROM public.get_my_holdings('22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid) LIMIT 5;

-- 买卖预览（把 1 换成实际的公司 id）
-- SELECT public.preview_buy(1, 1000);
-- SELECT public.preview_sell(1, 100);
