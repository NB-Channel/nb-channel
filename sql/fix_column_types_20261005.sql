-- ============================================================
--  补跑 amm_part5：把 market_value / total_shares 改成 numeric
--  （第二版 —— 修掉「触发器挡住 ALTER」的问题）
--
--  ── 为什么现在才跑 ──
--    amm_part5_fix_column_types_20261003.sql 当时就是干这个的，
--    但一直没被执行 —— 所以这两列到现在还是 integer。
--
--    Part 1 里写的是：
--        ADD COLUMN IF NOT EXISTS total_shares numeric
--    可是 total_shares 这一列【旧系统早就在用】，已经存在，
--    IF NOT EXISTS 直接跳过 —— 类型根本没改，还是 integer。
--    market_value 同理。
--
--  ── 这会造成什么 ──
--    ① market_value 存不下小数
--       市值算出来 1.66 亿零 0.5 → 存进 integer 被截成 1.66 亿
--       → 和真实值差 0.5 → 就是站长看到的那 8 家「不对齐」
--       （另外 85 家市值正好是整数，所以没露馅）
--
--    ② total_shares 也被四舍五入过
--       本该是 338775510.7142，存成 integer 就变成 338775511
--       → 分红比例、市值计算都会带一点误差
--       ⚠️ 已经丢的精度找不回来，改完类型只是保证【以后】不再丢。
--
--  ── 第一版为什么报错 ──
--    ERROR: cannot alter type of a column used in a trigger definition
--    DETAIL: trigger trg_sync_market_value depends on column "total_shares"
--
--    那个触发器（方案 C 收尾时装的市场值自动同步）写的是
--        BEFORE INSERT OR UPDATE OF pool_cash, pool_shares, total_shares
--    正好把 total_shares 框进去了，PostgreSQL 就不让改它的类型。
--    所以这一版：先删触发器 → 改类型 → 再建回来，
--    而且整段包在 DO 块里 —— 改失败的话连删除也会一起回滚，
--    不会出现「触发器没了、类型也没改」的中间状态。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 一、先看现状，并列出所有依赖这几列的触发器
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

-- user_companies 上现在有哪些触发器（看清有没有别的也要临时删）
SELECT
    t.tgname                AS 触发器,
    CASE WHEN t.tgenabled = 'O' THEN '已启用' ELSE '未启用' END AS 状态,
    pg_get_triggerdef(t.oid) AS 定义
  FROM pg_trigger t
 WHERE t.tgrelid = 'public.user_companies'::regclass
   AND NOT t.tgisinternal;

-- holdings 那边有没有同类问题
SELECT
    table_name        AS 表,
    column_name       AS 字段,
    data_type         AS 类型,
    numeric_scale     AS 小数位
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('holdings','stock_trades')
   AND column_name IN ('shares','cost','principal','base_market_value',
                       'amount','price','pool_cash','pool_shares')
 ORDER BY table_name, column_name;


-- ============================================================
-- 二、核心：删触发器 → 改类型 → 重建触发器（包在 DO 块里，要么全成要么全退）
-- ============================================================
DO $$
DECLARE
    r RECORD;
    v_n int := 0;
BEGIN
    -- ① 先删掉挡路的触发器
    DROP TRIGGER IF EXISTS trg_sync_market_value ON public.user_companies;
    RAISE NOTICE '已临时删除 trg_sync_market_value';

    -- ② user_companies：三列改成 numeric(20,4)
    ALTER TABLE public.user_companies
        ALTER COLUMN total_shares TYPE numeric(20,4) USING total_shares::numeric(20,4);
    ALTER TABLE public.user_companies
        ALTER COLUMN market_value TYPE numeric(20,4) USING market_value::numeric(20,4);
    RAISE NOTICE 'total_shares / market_value 已改成 numeric(20,4)';

    -- circulating_shares 是旧字段，页面可能还在读，存在就一起改
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema='public' AND table_name='user_companies'
                  AND column_name='circulating_shares') THEN
        ALTER TABLE public.user_companies
            ALTER COLUMN circulating_shares TYPE numeric(20,4)
            USING circulating_shares::numeric(20,4);
        RAISE NOTICE 'circulating_shares 也改成 numeric 了';
    END IF;

    -- pool_cash / pool_shares 本来就是 numeric，再写一遍只是保险
    ALTER TABLE public.user_companies
        ALTER COLUMN pool_cash   TYPE numeric(20,4) USING pool_cash::numeric(20,4);
    ALTER TABLE public.user_companies
        ALTER COLUMN pool_shares TYPE numeric(20,4) USING pool_shares::numeric(20,4);

    -- ③ holdings 里还是整数的同类列也一起改
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
        v_n := v_n + 1;
    END LOOP;

    RAISE NOTICE '全部改完（holdings 改了 % 列）', v_n;
END $$;


-- ============================================================
-- 三、把触发器建回来（类型改完了，这次不会再挡）
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_market_value()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    IF NEW.pool_shares IS NOT NULL AND NEW.pool_shares > 0 THEN
        NEW.market_value := round(
            NEW.pool_cash::numeric
            / NEW.pool_shares::numeric
            * COALESCE(NEW.total_shares, 0)::numeric, 2);
    END IF;
    RETURN NEW;
END
$fn$;

CREATE TRIGGER trg_sync_market_value
    BEFORE INSERT OR UPDATE OF pool_cash, pool_shares, total_shares
    ON public.user_companies
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_market_value();


-- ============================================================
-- 四、类型对了，把 market_value 重新算一遍
-- ============================================================
-- 这句只 SET market_value，不碰那三列，所以不会触发上面刚建的触发器，
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

-- 5.2 触发器建回来了没
SELECT
    tgname AS 触发器,
    CASE WHEN tgenabled = 'O' THEN '✅ 已启用' ELSE '❌ 未启用' END AS 状态
  FROM pg_trigger
 WHERE tgrelid = 'public.user_companies'::regclass
   AND tgname = 'trg_sync_market_value';

-- 5.3 市值对齐（这次应该是 93 / 93）
SELECT
    count(*) FILTER (
        WHERE abs(c.market_value
                  - round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                          * c.total_shares::numeric, 2)) < 0.01
    ) || ' / ' || count(*) || ' 家对齐' AS "market_value 对齐情况"
  FROM public.user_companies c
 WHERE c.pool_shares > 0;

-- 5.4 还不对齐的，列出来看看
SELECT id, company_name, pool_cash, pool_shares, total_shares, market_value
  FROM public.user_companies
 WHERE pool_shares > 0
   AND (market_value IS NULL
        OR abs(market_value
               - round(pool_cash::numeric / NULLIF(pool_shares::numeric,0)
                       * total_shares::numeric, 2)) >= 0.01);

-- 5.5 行情接口还能正常返回吗
--     改列类型最容易在这里报「Returned type ... does not match expected type ...」
SELECT * FROM public.get_market_list(NULL) LIMIT 5;


-- ============================================================
--  改完之后
-- ============================================================
--  · 5.1 应该全是 numeric
--  · 5.2 应该 ✅ 已启用
--  · 5.3 应该显示 93 / 93
--  · 5.5 如果报「Returned type ... does not match expected type ...」，
--    把 amm_part4_read_layer_20261003.sql 整段重跑一遍即可
--    （里面的 CREATE OR REPLACE 都是幂等的）。
--
--  ⚠️ 如果 DO 块里任何一步失败，整块会回滚 ——
--     触发器不会被留在删除状态，类型也不会改一半。
--     报错了把错误发我，不要分几次手动跑。
-- ============================================================
