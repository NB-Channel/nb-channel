-- ============================================================
-- 处理 Utw 全部账号的资产（可直接执行版）
-- ============================================================
--
-- 账号匹配规则：username ILIKE '%utw%'  （站长确认带 Utw 的都是他的号）
--   覆盖：Utw / utw / Utvv / Utw小号 / Utw宿舍官号 /
--         Utw的机器店官号 / Utw的小NB肉餐厅官号 / Utw的3ty肉餐厅官号
--
-- 【保留值】按余额榜定的：
--     第 10 名  Miku           15,825,488
--     第 11 名  小NB3ty保护号    1,950,000
--   → 正常玩家天花板约 1500 万
--   → 这里给每个号留 【500 万现金】，公司市值各留 【50 万】
--     8 个号合计 4000 万现金 —— 依然比所有人都富，但不破坏经济
--     觉得高或低，改下面 v_cash / v_mv 两个数字即可
--
-- ⚠️ 执行顺序：第 0 步备份 → 第 1 步普查 → 第 2 步动手 → 第 3 步验收
--    第 2 步默认是注释掉的，你看完普查结果再放开。
-- ============================================================


-- ============================================================
-- 第 0 步：备份
-- ============================================================
DROP TABLE IF EXISTS public._utw_bak_profiles;
CREATE TABLE public._utw_bak_profiles AS
SELECT * FROM public.profiles WHERE username ILIKE '%utw%';

DROP TABLE IF EXISTS public._utw_bak_companies;
CREATE TABLE public._utw_bak_companies AS
SELECT c.* FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.username ILIKE '%utw%';

DROP TABLE IF EXISTS public._utw_bak_holdings;
CREATE TABLE public._utw_bak_holdings AS
SELECT h.* FROM public.holdings h
  JOIN public.profiles p ON p.id = h.user_id
 WHERE p.username ILIKE '%utw%';

SELECT 'profiles' AS 已备份表, count(*) AS 条数 FROM public._utw_bak_profiles
UNION ALL SELECT 'user_companies', count(*) FROM public._utw_bak_companies
UNION ALL SELECT 'holdings',       count(*) FROM public._utw_bak_holdings;


-- ============================================================
-- 第 1 步：普查 —— 钱到底在哪五个地方
-- ============================================================

-- 1.1 账号清单
SELECT id, username, nb_balance
  FROM public.profiles
 WHERE username ILIKE '%utw%'
 ORDER BY nb_balance DESC NULLS LAST;

-- 1.2 五处资产汇总
WITH ids AS (
    SELECT id FROM public.profiles WHERE username ILIKE '%utw%'
)
SELECT '① 现金'      AS 位置, count(*) AS 笔数,
       COALESCE(sum(p.nb_balance), 0) AS 合计
  FROM public.profiles p WHERE p.id IN (SELECT id FROM ids)
UNION ALL
SELECT '④ 持仓本金', count(*), COALESCE(sum(h.principal), 0)
  FROM public.holdings h WHERE h.user_id IN (SELECT id FROM ids)
UNION ALL
SELECT '⑤ 公司市值', count(*), COALESCE(sum(c.market_value), 0)
  FROM public.user_companies c WHERE c.user_id IN (SELECT id FROM ids)
ORDER BY 位置;

-- 1.3 银行存款（表名自动探测，有什么查什么）
DO $$
DECLARE
    t text;
    ids uuid[];
    n bigint;
BEGIN
    SELECT array_agg(id) INTO ids FROM public.profiles WHERE username ILIKE '%utw%';
    FOR t IN
        SELECT table_name FROM information_schema.tables
         WHERE table_schema = 'public'
           AND (table_name ILIKE '%bank%' OR table_name ILIKE '%deposit%')
           AND table_name NOT ILIKE '%log%'
    LOOP
        BEGIN
            EXECUTE format(
                'SELECT count(*) FROM public.%I WHERE user_id = ANY($1)', t)
              INTO n USING ids;
            RAISE NOTICE '银行存款表 % ：他名下有 % 条记录', t, n;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '银行存款表 % ：查不了（% ）', t, SQLERRM;
        END;
    END LOOP;
END $$;

-- 1.4 红包（发出未领的）
DO $$
DECLARE
    t text;
    n bigint;
BEGIN
    FOR t IN
        SELECT table_name FROM information_schema.tables
         WHERE table_schema = 'public'
           AND (table_name ILIKE '%redpacket%' OR table_name ILIKE '%packet%')
    LOOP
        RAISE NOTICE '发现红包表: %', t;
    END LOOP;
END $$;

-- 1.5 他名下公司（含市值和股东数）
SELECT c.id, c.company_name, c.market_value,
       (SELECT count(*) FROM public.holdings h
         WHERE h.company_id = c.id AND h.user_id <> c.user_id) AS 外部股东数
  FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.username ILIKE '%utw%'
 ORDER BY c.market_value DESC NULLS LAST;

-- 1.6 注资次数（最能说明问题的一个数）
SELECT p.username, count(*) AS 注资次数, sum(s.amount) AS 注资总额
  FROM public.support_logs s
  JOIN public.profiles p ON p.id = s.supporter_id
 WHERE p.username ILIKE '%utw%'
 GROUP BY p.username ORDER BY 注资次数 DESC;


-- ============================================================
-- 第 2 步：动手（看完第 1 步再放开注释）
-- ============================================================
-- DO $$
-- DECLARE
--     v_cash CONSTANT BIGINT := 5000000;    -- 每个号留 500 万现金
--     v_mv   CONSTANT BIGINT :=  500000;    -- 每家公司留 50 万市值
--     v_n    INT := 0;
-- BEGIN
--     -- ① 现金
--     UPDATE public.profiles SET nb_balance = v_cash
--      WHERE username ILIKE '%utw%';
--     GET DIAGNOSTICS v_n = ROW_COUNT;
--     RAISE NOTICE '现金已处理 % 个账号', v_n;
--
--     -- ⑤ 公司市值
--     UPDATE public.user_companies c SET market_value = v_mv
--       FROM public.profiles p
--      WHERE p.id = c.user_id AND p.username ILIKE '%utw%';
--     GET DIAGNOSTICS v_n = ROW_COUNT;
--     RAISE NOTICE '公司市值已处理 % 家', v_n;
--
--     -- ④ 持仓：他的本金压到 0.01（等于清仓）。
--     --    用 0.01 而不是删记录 —— 有些页面靠记录存在判断"是否持有"
--     UPDATE public.holdings h SET principal = 0.01
--       FROM public.profiles p
--      WHERE p.id = h.user_id AND p.username ILIKE '%utw%';
--     GET DIAGNOSTICS v_n = ROW_COUNT;
--     RAISE NOTICE '持仓已处理 % 笔', v_n;
-- END $$;

-- ② 银行存款（表名按第 1.3 步的实际结果替换）
-- UPDATE public.bank_accounts  SET balance = 100000
--  WHERE user_id IN (SELECT id FROM public.profiles WHERE username ILIKE '%utw%');
-- UPDATE public.bank_deposits  SET amount = 100000
--  WHERE user_id IN (SELECT id FROM public.profiles WHERE username ILIKE '%utw%');

-- ③ 红包（把未领的撤回，钱回到他账上再一起压 —— 或者直接标记失效）
-- DELETE FROM public.redpackets
--  WHERE sender_id IN (SELECT id FROM public.profiles WHERE username ILIKE '%utw%')
--    AND NOT claimed;


-- ============================================================
-- 第 3 步：验收
-- ============================================================
SELECT p.username, p.nb_balance AS 余额,
       (SELECT count(*) FROM public.user_companies WHERE user_id = p.id) AS 公司数,
       (SELECT COALESCE(max(market_value),0) FROM public.user_companies
         WHERE user_id = p.id) AS 最高市值
  FROM public.profiles p
 WHERE p.username ILIKE '%utw%'
 ORDER BY p.nb_balance DESC NULLS LAST;

SELECT
    (SELECT COALESCE(sum(nb_balance),0) FROM public.profiles)          AS 全站总余额,
    (SELECT COALESCE(sum(market_value),0) FROM public.user_companies)  AS 全站总市值,
    (SELECT count(*) FROM public.profiles WHERE nb_balance > 100000000) AS 超一亿账号数,
    (SELECT count(*) FROM public.profiles WHERE nb_balance > 10000000)  AS 超一千万账号数;


-- ============================================================
-- 第 4 步：防复发 —— 余额看门狗
-- ============================================================
-- 这次刷到 90 亿亿才发现，就是没人盯总量。
-- 挂到采样里顺手调一次（sample_market_snapshot 每 15 分钟跑）。
--
-- CREATE OR REPLACE FUNCTION public._balance_watchdog()
-- RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- DECLARE
--     v_cap CONSTANT bigint := 100000000;   -- 1 亿
--     r RECORD;
-- BEGIN
--     FOR r IN SELECT id, username, nb_balance FROM public.profiles
--               WHERE nb_balance > v_cap LOOP
--         -- 写进后台日志表，管理员在后台能看到
--         BEGIN
--             INSERT INTO public.api_logs (user_id, action, detail)
--             VALUES (r.id, 'BALANCE_ALERT',
--                     format('%s 余额 %s 超过阈值', r.username, r.nb_balance));
--         EXCEPTION WHEN OTHERS THEN
--             NULL;   -- 表名不对就算了，别让看门狗自己报错
--         END;
--     END LOOP;
-- END $$;


-- ============================================================
-- 第 5 步：确认无误后清理备份（留几天更稳）
-- ============================================================
-- DROP TABLE IF EXISTS public._utw_bak_profiles;
-- DROP TABLE IF EXISTS public._utw_bak_companies;
-- DROP TABLE IF EXISTS public._utw_bak_holdings;
