-- ============================================================
-- 处理 Utw 的 90 亿亿：先摸清资产分布，再决定怎么动
-- ============================================================
--
-- 【为什么要先普查】
--   钱不只存在 nb_balance 一个地方。只改余额，他还能从
--   银行、红包、持仓、公司市值里把钱拿出来。要动就得一起动。
--
-- 【合理值参考】
--   余额榜第 10 名是 15,825,488（Miku），第 11 名 1,950,000。
--   所以正常玩家的天花板大概在【1500 万】。
--   建议给他留 500 万 ~ 2000 万：排名依然靠前，不显得被针对，
--   但不再破坏经济。
--
-- ⚠️ 第 1 步到第 3 步只查不改。第 4 步起才动手，默认全注释掉。
-- ============================================================


-- ============================================================
-- 第 0 步：备份（必做）
-- ============================================================
CREATE TABLE IF NOT EXISTS public._utw_bak_profiles_20261003 AS
SELECT * FROM public.profiles
 WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%';

CREATE TABLE IF NOT EXISTS public._utw_bak_companies_20261003 AS
SELECT c.* FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%';

SELECT 'profiles' AS 表, count(*) AS 备份条数 FROM public._utw_bak_profiles_20261003
UNION ALL
SELECT 'user_companies', count(*) FROM public._utw_bak_companies_20261003;


-- ============================================================
-- 第 1 步：摸清他到底有哪些账号
-- ============================================================
CREATE TEMP TABLE IF NOT EXISTS _utw_ids AS
SELECT id, username FROM public.profiles
 WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%'
    OR username ILIKE '%小nb3%';

SELECT count(*) AS 账号数 FROM _utw_ids;

SELECT id, username, nb_balance
  FROM _utw_ids JOIN public.profiles USING (id)
 ORDER BY nb_balance DESC NULLS LAST;


-- ============================================================
-- 第 2 步：五个地方各有多少钱
-- ============================================================

-- ① 现金
SELECT '① 现金 nb_balance' AS 位置,
       count(*) AS 账户数, sum(nb_balance) AS 合计
  FROM public.profiles WHERE id IN (SELECT id FROM _utw_ids);

-- ② 银行（表名可能是 bank_accounts / bank_deposits，先探一下有哪些表）
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public' AND table_name ILIKE '%bank%';

-- 看到表名之后，把下面这句的表名换成实际的：
-- SELECT '② 银行存款' AS 位置, count(*), sum(balance)
--   FROM public.bank_accounts WHERE user_id IN (SELECT id FROM _utw_ids);

-- ③ 红包（发出去还没被领的，钱还挂在他名下）
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public' AND table_name ILIKE '%redpacket%'
    OR table_schema = 'public' AND table_name ILIKE '%packet%';

-- SELECT '③ 未领红包' AS 位置, count(*), sum(amount)
--   FROM public.redpackets
--  WHERE sender_id IN (SELECT id FROM _utw_ids) AND NOT claimed;

-- ④ 持仓（投在别人公司的本金）
SELECT '④ 持仓本金' AS 位置,
       count(*) AS 笔数, sum(principal) AS 合计
  FROM public.holdings WHERE user_id IN (SELECT id FROM _utw_ids);

-- ⑤ 自己公司市值（能通过 withdraw_company_value 提现）
SELECT '⑤ 自有公司市值' AS 位置,
       count(*) AS 公司数, sum(market_value) AS 合计
  FROM public.user_companies WHERE user_id IN (SELECT id FROM _utw_ids);


-- ============================================================
-- 第 3 步：算个总账，看看到底有多少是刷出来的
-- ============================================================
SELECT
    (SELECT COALESCE(sum(nb_balance),0) FROM public.profiles
      WHERE id IN (SELECT id FROM _utw_ids))                     AS 现金,
    (SELECT COALESCE(sum(principal),0) FROM public.holdings
      WHERE user_id IN (SELECT id FROM _utw_ids))                AS 持仓本金,
    (SELECT COALESCE(sum(market_value),0) FROM public.user_companies
      WHERE user_id IN (SELECT id FROM _utw_ids))                AS 公司市值,
    (SELECT COALESCE(sum(amount),0) FROM public.support_logs
      WHERE supporter_id IN (SELECT id FROM _utw_ids))           AS 历史注资;


-- ============================================================
-- 第 4 步：动手 —— 三选一（默认注释掉）
-- ============================================================

-- ------------------------------------------------------------
-- 【方案 A】一次性压到合理值
-- ------------------------------------------------------------
-- DO $$
-- DECLARE
--     v_cash BIGINT := 5000000;     -- 现金留 500 万
--     v_mv   BIGINT := 500000;      -- 公司市值各留 50 万
-- BEGIN
--     UPDATE public.profiles SET nb_balance = v_cash
--      WHERE id IN (SELECT id FROM _utw_ids);
--
--     UPDATE public.user_companies SET market_value = v_mv
--      WHERE user_id IN (SELECT id FROM _utw_ids);
--
--     -- 持仓：把他的本金压到 0（等于清仓，钱不再占着别人的公司）
--     -- ⚠️ 慎用：如果他是正常投资别人，这会误伤那些公司
--     -- DELETE FROM public.holdings WHERE user_id IN (SELECT id FROM _utw_ids);
-- END $$;


-- ------------------------------------------------------------
-- 【方案 B】分批降（隐蔽，但慢）
-- ------------------------------------------------------------
-- 每天降 20%，从 9e18 降到 500 万需要：
--     ln(9e18 / 5e6) / 0.20 = ln(1.8e12) / 0.20 = 28.2 / 0.20 = 141 天
-- 四个多月。太慢了，除非你不着急。
--
-- CREATE TABLE IF NOT EXISTS public._utw_decay (
--     user_id uuid PRIMARY KEY, target_bal bigint, pct numeric DEFAULT 0.20);
-- INSERT INTO public._utw_decay (user_id, target_bal)
-- SELECT id, 5000000 FROM _utw_ids ON CONFLICT DO NOTHING;
--
-- CREATE OR REPLACE FUNCTION public._utw_decay_step() RETURNS void
-- LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- BEGIN
--     UPDATE public.profiles p
--        SET nb_balance = GREATEST(d.target_bal,
--              floor(COALESCE(p.nb_balance,0) * (1 - d.pct))::bigint)
--       FROM public._utw_decay d WHERE p.id = d.user_id;
-- END $$;


-- ------------------------------------------------------------
-- 【方案 C】封号 + 清零（最彻底）
-- ------------------------------------------------------------
-- 如果他不只是刷币，还有抄袭/攻击别人的前科（仓库里有
-- 证据_utw抄袭_20260925 这个目录），那不如直接处理账号。
-- 但这是运营决定，不是技术决定 —— 你得先想清楚要不要公开。
--
-- UPDATE public.profiles SET nb_balance = 0
--  WHERE id IN (SELECT id FROM _utw_ids);
-- UPDATE public.profiles SET banned = true       -- 列名按实际改
--  WHERE id IN (SELECT id FROM _utw_ids);


-- ============================================================
-- 第 5 步：防复发 —— 余额异常告警
-- ============================================================
-- 这次刷到 90 亿亿才被发现，就是因为没人盯着。
-- 加一道最简单的闸：任何账号余额超过阈值就记一条通知给管理员。
--
-- CREATE OR REPLACE FUNCTION public._balance_watchdog()
-- RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- DECLARE
--     v_cap CONSTANT bigint := 100000000;    -- 1 亿
--     r RECORD;
-- BEGIN
--     FOR r IN SELECT id, username, nb_balance FROM public.profiles
--               WHERE nb_balance > v_cap LOOP
--         -- 每天最多提醒一次，避免刷屏
--         IF NOT EXISTS (
--             SELECT 1 FROM public.notifications
--              WHERE user_id = r.id AND type = 'balance_alert'
--                AND created_at > now() - interval '20 hours'
--         ) THEN
--             INSERT INTO public.notifications (user_id, type, title, content)
--             VALUES (r.id, 'balance_alert', '余额异常提醒',
--                     format('你的余额已达 %s NB币，请确认来源是否正常。', r.nb_balance));
--         END IF;
--     END LOOP;
-- END $$;
--
-- 挂到采样里顺手调（或 pg_cron）：
--     PERFORM public._balance_watchdog();


-- ============================================================
-- 第 6 步：验收
-- ============================================================
SELECT p.username, p.nb_balance AS 余额,
       (SELECT COALESCE(sum(market_value),0) FROM public.user_companies
         WHERE user_id = p.id) AS 公司市值
  FROM public.profiles p
 WHERE p.id IN (SELECT id FROM _utw_ids)
 ORDER BY p.nb_balance DESC NULLS LAST;

SELECT
    (SELECT COALESCE(sum(nb_balance),0) FROM public.profiles)          AS 全站总余额,
    (SELECT COALESCE(sum(market_value),0) FROM public.user_companies)  AS 全站总市值,
    (SELECT count(*) FROM public.profiles WHERE nb_balance > 100000000) AS 超一亿账号数;
