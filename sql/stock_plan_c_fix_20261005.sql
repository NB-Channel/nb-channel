-- ============================================================
--  收尾两件事
--    一、让 market_value 永远自动跟着池子走（解决 85/93 不对齐）
--    二、验证收税定时任务还活着
--
--  背景
--    方案 C 的第 2 步把 market_value 换算成了真实市值，但跑完只有 85/93 对齐。
--    原因不是换算写错了，而是【结构性的】：
--        market_value 只在建公司和迁移时写一次，
--        买卖股票改的是 pool_cash / pool_shares / total_shares，
--        并不会回头更新 market_value。
--    所以只要有人交易过，那家公司就立刻重新变得不对齐 ——
--    今天修好 93/93，明天有人交易又会掉几家。
--
--    而 achievements.sql 读的正是 market_value：
--        sum(h.principal * (uc.market_value / h.base_market_value))
--    它一旦过期，「持仓价值」类成就就是错的。
--
--  做法
--    加一个 BEFORE 触发器：只要 pool_cash / pool_shares / total_shares 有变动，
--    就顺手把 market_value 重算一遍。
--    用 BEFORE 触发器而不是 AFTER + UPDATE，少一次写盘，也不会递归。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 一、触发器：market_value 自动同步
-- ============================================================

CREATE OR REPLACE FUNCTION public.sync_market_value()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    -- 池子股份为 0 时算不出股价，保持原值不动（这种公司本来就异常）
    IF NEW.pool_shares IS NOT NULL AND NEW.pool_shares > 0 THEN
        NEW.market_value := round(
            NEW.pool_cash::numeric
            / NEW.pool_shares::numeric
            * COALESCE(NEW.total_shares, 0)::numeric, 2);
    END IF;
    RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS trg_sync_market_value ON public.user_companies;

CREATE TRIGGER trg_sync_market_value
    BEFORE INSERT OR UPDATE OF pool_cash, pool_shares, total_shares
    ON public.user_companies
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_market_value();


-- ============================================================
-- 二、把现在不对齐的一次性补齐
-- ============================================================
UPDATE public.user_companies
   SET market_value = round(
           pool_cash::numeric / NULLIF(pool_shares::numeric, 0) * total_shares::numeric, 2)
 WHERE pool_shares > 0
   AND abs(market_value
           - round(pool_cash::numeric / NULLIF(pool_shares::numeric, 0)
                   * total_shares::numeric, 2)) >= 0.01;


-- ============================================================
-- 三、验证
-- ============================================================

-- 3.1 市值对齐（这次应该是 93 / 93）
SELECT
    count(*) FILTER (
        WHERE abs(c.market_value
                  - round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                          * c.total_shares::numeric, 2)) < 0.01
    ) || ' / ' || count(*) || ' 家对齐' AS "market_value 对齐情况"
  FROM public.user_companies c
 WHERE c.pool_shares > 0;

-- 3.2 触发器装上了没
SELECT
    tgname                       AS 触发器,
    CASE WHEN tgenabled = 'O' THEN '✅ 已启用' ELSE '❌ 未启用' END AS 状态
  FROM pg_trigger
 WHERE tgrelid = 'public.user_companies'::regclass
   AND tgname = 'trg_sync_market_value';

-- 3.3 定时任务还活着吗
--     （没装 pg_cron 会报错，忽略即可，看 3.4 就行）
SELECT jobid, schedule, command, active
  FROM cron.job
 ORDER BY jobid;

-- 3.4 上次收税是哪天
--     如果这个日期不是今天，说明今晚 20:00 之后会收 —— 明天来看再分配的效果
--     如果这个日期停留在很久以前，说明采样任务没在跑，要单独查
SELECT key AS 项目, value AS 值
  FROM public.market_meta
 WHERE key IN ('last_tax_date');


-- ============================================================
-- 四、想立刻看一次再分配的效果（可选）
-- ============================================================
-- ⚠️ 这个会真的收一次税 + 发一次钱，不要在一天里跑多次。
--    跑之前先记住几个小公司的 pool_cash，跑完对比。
--
--    记住当前值：
--        SELECT company_name, pool_cash FROM public.user_companies
--         WHERE pool_cash < 1000000 ORDER BY pool_cash ASC LIMIT 10;
--
--    跑一次：
--        SELECT public.collect_company_tax();
--
--    再查一次上面的 SELECT，小公司应该都涨了一点（最多涨自己池子的 2%）。
-- ============================================================
