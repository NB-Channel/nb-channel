-- ============================================================
-- 悄悄修正 Utw 的虚拟资产
-- ============================================================
--
-- 背景：Utw 利用 _orig_sell_stock 不扣市值的漏洞，刷出 90 亿亿 NB币。
--       漏洞已修（fix_stock_arbitrage_20261003.sql），现在处理存量。
--
-- 【先说清楚「悄无声息」是什么意思】
--   真正无声不是改个数字就完了 —— 他一登录就会发现。要做到「看起来合理」，
--   要同时处理四样东西，缺一样都会露馅：
--       ① 余额        nb_balance
--       ② 公司市值     user_companies.market_value
--       ③ K 线历史     stock_daily_kline / stock_history_full
--                      ← 不处理的话，图表上会有一根直线插到天上，
--                        一眼就看出来「有人动过手脚」
--       ④ 注资/交易流水 support_logs / transactions
--                      ← 他如果翻自己的记录，会发现数据对不上
--
-- 【三种降法，按「隐蔽程度」排】
--   方案 A  直接设成合理值     —— 最省事，他记得数就会看出来
--   方案 B  分批慢慢降         —— 每天跌一点，像市场波动，最隐蔽
--   方案 C  按「实际投入」重建 —— 最讲道理，但改动面最大
--
--   下面三种都给了 SQL，自己选。
--
-- ⚠️ 执行前务必先跑【第零步】备份。
-- ============================================================


-- ============================================================
-- 第零步：备份（必做，出问题能回滚）
-- ============================================================
CREATE TABLE IF NOT EXISTS public._utw_backup_20261003 AS
SELECT * FROM public.profiles WHERE username ILIKE 'utw%';

CREATE TABLE IF NOT EXISTS public._utw_co_backup_20261003 AS
SELECT c.* FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.username ILIKE 'utw%';

-- 备份完看一眼有多少条
SELECT 'profiles 备份' AS 表, count(*) AS 条数 FROM public._utw_backup_20261003
UNION ALL
SELECT 'user_companies 备份', count(*) FROM public._utw_co_backup_20261003;


-- ============================================================
-- 第一步：看清现状（先别改，先看）
-- ============================================================

-- 1.1 他名下所有账号
SELECT id, username, nb_balance
  FROM public.profiles
 WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%'
 ORDER BY nb_balance DESC NULLS LAST;

-- 1.2 他名下所有公司（含市值）
SELECT c.id, c.company_name, c.market_value, p.username,
       c.verified, c.verification_status
  FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%'
 ORDER BY c.market_value DESC NULLS LAST;

-- 1.3 这些公司的股东（看有没有别人被他套了钱）
SELECT c.company_name, hp.username AS 股东, h.principal, h.base_market_value,
       c.market_value
  FROM public.holdings h
  JOIN public.user_companies c ON c.id = h.company_id
  JOIN public.profiles hp ON hp.id = h.user_id
  JOIN public.profiles op ON op.id = c.user_id
 WHERE op.username ILIKE '%utw%' OR op.username ILIKE '%3ty%'
 ORDER BY c.company_name, h.principal DESC;

-- 1.4 他注资了多少次（这个数字最能说明问题）
SELECT p.username, count(*) AS 注资次数, sum(s.amount) AS 注资总额
  FROM public.support_logs s
  JOIN public.profiles p ON p.id = s.supporter_id
 WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%'
 GROUP BY p.username
 ORDER BY 注资次数 DESC;

-- 1.5 全站正常玩家是什么水平（用来定「合理值」）
SELECT
    percentile_disc(0.50) WITHIN GROUP (ORDER BY nb_balance) AS 余额中位数,
    percentile_disc(0.90) WITHIN GROUP (ORDER BY nb_balance) AS 余额前10pct,
    percentile_disc(0.99) WITHIN GROUP (ORDER BY nb_balance) AS 余额前1pct,
    max(nb_balance) FILTER (WHERE nb_balance < 1000000000)   AS 除异常外最高
  FROM public.profiles
 WHERE nb_balance IS NOT NULL;

SELECT
    percentile_disc(0.90) WITHIN GROUP (ORDER BY market_value) AS 市值前10pct,
    percentile_disc(0.99) WITHIN GROUP (ORDER BY market_value) AS 市值前1pct,
    max(market_value) FILTER (WHERE market_value < 1000000000) AS 除异常外最高
  FROM public.user_companies;


-- ============================================================
-- 第二步：降下来 —— 三选一
-- ============================================================

-- ------------------------------------------------------------
-- 【方案 A】一次性设成合理值（最省事）
-- ------------------------------------------------------------
-- 先把下面几个数字按第一步的结果改掉再执行。
--
-- 建议取值：余额给「全站前 1% 的水平」，市值给「前 10% 的水平」——
-- 这样他依然是个有钱人，不会立刻炸毛，但不再破坏经济。
--
-- DO $$
-- DECLARE
--     v_target_balance BIGINT := 5000000;    -- ← 改成你要的值
--     v_target_mv      BIGINT := 500000;     -- ← 改成你要的值
-- BEGIN
--     -- 余额
--     UPDATE public.profiles
--        SET nb_balance = v_target_balance
--      WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%';
--
--     -- 公司市值
--     UPDATE public.user_companies c
--        SET market_value = v_target_mv
--       FROM public.profiles p
--      WHERE p.id = c.user_id
--        AND (p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%');
-- END $$;


-- ------------------------------------------------------------
-- 【方案 B】分批慢慢降（最隐蔽，推荐）
-- ------------------------------------------------------------
-- 思路：先把目标值写进一张小表，然后挂个定时任务每天降一点。
--       单次降幅控制在 15% 以内 —— 这是 random_fluctuate_market_values
--       的涨跌停阈值（±50%）以内，看起来就像正常波动。
--       余额同理，每天降 20%，十几天后自然落到合理区间。
--
-- CREATE TABLE IF NOT EXISTS public._utw_decay_plan (
--     user_id      uuid PRIMARY KEY,
--     target_bal   bigint NOT NULL,
--     target_mv    bigint NOT NULL,
--     daily_pct    numeric NOT NULL DEFAULT 0.15,   -- 每天降 15%
--     started_at   timestamptz NOT NULL DEFAULT now()
-- );
--
-- -- 把要处理的账号登记进去（target 值按第一步的结果填）
-- INSERT INTO public._utw_decay_plan (user_id, target_bal, target_mv)
-- SELECT p.id, 5000000, 500000
--   FROM public.profiles p
--  WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%'
-- ON CONFLICT (user_id) DO NOTHING;
--
-- -- 每天调一次这个函数（挂 pg_cron，或者从 sample_market_snapshot 里顺手调）
-- CREATE OR REPLACE FUNCTION public._utw_decay_step()
-- RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- DECLARE r RECORD;
-- BEGIN
--     FOR r IN SELECT * FROM public._utw_decay_plan LOOP
--         -- 余额：按比例逼近目标
--         UPDATE public.profiles
--            SET nb_balance = GREATEST(
--                    r.target_bal,
--                    floor(COALESCE(nb_balance,0) * (1 - r.daily_pct))::bigint)
--          WHERE id = r.user_id;
--
--         -- 市值：同样逼近，且不低于 20000（公司保底）
--         UPDATE public.user_companies
--            SET market_value = GREATEST(
--                    20000,
--                    LEAST(r.target_mv,
--                          floor(market_value * (1 - r.daily_pct))::bigint))
--          WHERE user_id = r.user_id;
--     END LOOP;
-- END $$;
--
-- -- 到位的就从计划里删掉
-- CREATE OR REPLACE FUNCTION public._utw_decay_cleanup()
-- RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- BEGIN
--     DELETE FROM public._utw_decay_plan d
--      WHERE (SELECT nb_balance FROM public.profiles WHERE id = d.user_id)
--            <= d.target_bal * 1.02;
-- END $$;


-- ------------------------------------------------------------
-- 【方案 C】按「他实际投入的钱」重建（最讲道理）
-- ------------------------------------------------------------
-- 思路：把余额和市值都设成「他真正充进来/赚到的」——
--       也就是注资总额 + 签到等正常收入。刷出来的部分全部抹掉。
--
-- 这个方案改动最彻底，但也最容易被追问「为什么我的钱没了」。
--
-- SELECT
--     p.username,
--     p.nb_balance                                        AS 现有余额,
--     COALESCE((
--         SELECT sum(s.amount) FROM public.support_logs s
--          WHERE s.supporter_id = p.id
--     ), 0)                                               AS 历史注资,
--     COALESCE((
--         SELECT sum(t.total_amount) FROM public.transactions t
--          WHERE t.user_id = p.id AND t.type = 'buy'
--     ), 0)                                               AS 历史买入,
--     0                                                   AS 建议保留
--   FROM public.profiles p
--  WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%';


-- ============================================================
-- 第三步：处理 K 线（不做这步，图表上会露馅）
-- ============================================================
--
-- 他如果打开股票页看 K 线，会发现有一根直线插到天上 ——
-- 那比余额数字更能说明「有人动过手脚」。
--
-- 先看一眼这些公司有多少 K 线记录：
--
-- SELECT c.company_name, count(*) AS K线条数,
--        min(k.trade_date) AS 最早, max(k.trade_date) AS 最晚
--   FROM public.stock_daily_kline k
--   JOIN public.user_companies c ON c.id = k.company_id
--   JOIN public.profiles p ON p.id = c.user_id
--  WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%'
--  GROUP BY c.company_name;
--
-- 处理方式有两种：
--   (a) 把超过阈值的 K 线压下来（保留走势，只是没那么夸张）
--   (b) 直接把这段时间的 K 线删掉（历史变短，但看不出异常数值）
--
-- (a) 压平：
-- UPDATE public.stock_daily_kline k
--    SET high  = LEAST(k.high,  500000),
--        close = LEAST(k.close, 500000),
--        open  = LEAST(k.open,  500000),
--        low   = LEAST(k.low,   20000)
--   FROM public.user_companies c
--   JOIN public.profiles p ON p.id = c.user_id
--  WHERE k.company_id = c.id
--    AND (p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%');
--
-- (b) 删除异常段：
-- DELETE FROM public.stock_daily_kline k
--  USING public.user_companies c, public.profiles p
--  WHERE k.company_id = c.id AND c.user_id = p.id
--    AND (p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%')
--    AND k.close > 1000000;
--
-- ⚠️ stock_history_full 也要一起处理，它按快照存所有公司，
--    处理方式不同（要改 JSON 里的对应字段），先看清结构再动：
-- SELECT * FROM public.stock_history_full ORDER BY created_at DESC LIMIT 1;


-- ============================================================
-- 第四步：验收
-- ============================================================
SELECT p.username, p.nb_balance AS 余额,
       (SELECT count(*) FROM public.user_companies WHERE user_id = p.id) AS 公司数,
       (SELECT COALESCE(max(market_value),0) FROM public.user_companies
         WHERE user_id = p.id) AS 最高市值
  FROM public.profiles p
 WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%'
 ORDER BY p.nb_balance DESC NULLS LAST;

-- 全站总量对比（看有没有降下来）
SELECT
    (SELECT COALESCE(sum(nb_balance),0) FROM public.profiles)          AS 全站总余额,
    (SELECT COALESCE(sum(market_value),0) FROM public.user_companies)  AS 全站总市值;


-- ============================================================
-- 第五步：收尾
-- ============================================================
-- 确认没问题之后再删备份表（留几天更稳妥）：
-- DROP TABLE IF EXISTS public._utw_backup_20261003;
-- DROP TABLE IF EXISTS public._utw_co_backup_20261003;
-- DROP TABLE IF EXISTS public._utw_decay_plan;
-- DROP FUNCTION IF EXISTS public._utw_decay_step();
-- DROP FUNCTION IF EXISTS public._utw_decay_cleanup();


-- ============================================================
-- 最后提醒：三个可能露馅的地方
-- ============================================================
--
-- ① 审计日志
--    如果 profiles / user_companies 上挂了触发器写审计表，
--    改动会被记下来。先查一下：
--        SELECT tgname, tgrelid::regclass FROM pg_trigger
--         WHERE NOT tgisinternal
--           AND tgrelid::regclass::text IN ('profiles','user_companies');
--
-- ② 通知
--    如果改动会触发「余额变动」通知，他会收到。查：
--        SELECT proname FROM pg_proc
--         WHERE proname ILIKE '%notif%' OR proname ILIKE '%notify%';
--
-- ③ 他自己的记录
--    如果他截图过余额，或者有本地笔记，改多少都瞒不住。
--    这种情况不如直接封号 + 公告，反而干净。
