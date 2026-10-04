-- ============================================================
-- 撤销 Utw 的拉盘操作
-- ============================================================
--
-- 【他做了什么】
-- ① 用「Utw小号」把【自己公司 Utw】拉了 6 笔，共 558.6 亿（本金 532 亿）
--       04:45:07   买 1.05 亿    →  股价 2.7964
--       04:45:16   买 1.05 亿    →  股价 5.4963
--       04:45:31   买 15.75 亿   →  股价 154.4324
--       04:45:32   买 15.75 亿   →  股价 506.6887
--       04:45:58   买 105 亿     →  股价 8051.0234
--       04:46:29   买 420 亿     →  股价 128592.8772
--    结果：股价 1.00 → 128,592.88，市值 382,631 亿
--
-- ② 又用「Utw」主号砸【本站长的公司 NB频道】10.5 亿（本金 10 亿）
--       04:52:42   →  股价 0.3025 → 2,500,055,000.30
--
-- 【为什么他小号能买自己公司】
-- 规则是「owner 本人持股 > 0 时禁止买自己公司」——
-- 只拦 owner 本人，拦不住他的小号。这是设计如此，不是 bug。
--
-- 【能不能精确还原】
-- 能。算过：
--     「Utw」现在股东持股 297,137,660.93
--     减 Utw小号 148,345,365.92
--     减 站长      9,999.33
--     = 148,782,295.68
--   而迁移完成时 = 创始人 148,770,231 + 其他股东 12,064.68 = 148,782,295.68
--   一分不差。
--
-- 【撤销原则】
--   · 退回本金（手续费不退 —— 那 5% 已经销毁了，退回来等于造币）
--   · 删掉他们买到的股份
--   · 股份加回池子，钱从池子扣掉
--
-- 在 Supabase SQL Editor 执行。先跑第一步诊断，再跑第四步。
-- ============================================================


-- ============================================================
-- 第一步：诊断（只查不改）
-- ============================================================

-- 1.1 要撤销的两笔操作
SELECT t.id, t.created_at AS 时间, p.username AS 买家,
       c.company_name AS 公司,
       t.cash AS 实付含手续费,
       round(t.cash / 1.05) AS 本金,
       t.shares AS 买到股份,
       t.price_after AS 成交后股价
  FROM public.stock_trades t
  JOIN public.profiles p ON p.id = t.user_id
  JOIN public.user_companies c ON c.id = t.company_id
 WHERE t.created_at > '2026-10-04 04:40:00+00'
   AND t.side = 'buy'
   AND c.company_name IN ('Utw', 'NB频道')
 ORDER BY t.created_at;

-- 1.2 两个公司现在的状态
SELECT id, company_name, pool_cash, pool_shares, total_shares,
       round(pool_cash::numeric / NULLIF(pool_shares,0), 4) AS 股价
  FROM public.user_companies WHERE company_name IN ('Utw','NB频道') ORDER BY id;

-- 1.3 这两个公司的股东
SELECT c.company_name, p.username AS 股东, round(h.shares,2) AS 持股, h.cost AS 投入成本
  FROM public.holdings h
  JOIN public.profiles p ON p.id = h.user_id
  JOIN public.user_companies c ON c.id = h.company_id
 WHERE c.company_name IN ('Utw','NB频道')
 ORDER BY c.company_name, h.shares DESC;


-- ============================================================
-- 第二步：备份
-- ============================================================
DROP TABLE IF EXISTS public._revert_utw_pump_backup_20261004;
CREATE TABLE public._revert_utw_pump_backup_20261004 AS
SELECT 'company' AS 类型, id::text AS 键, company_name AS 名称,
       pool_cash::text AS 值1, pool_shares::text AS 值2, NULL::text AS 值3,
       now() AS 备份时间
  FROM public.user_companies WHERE company_name IN ('Utw','NB频道')
UNION ALL
SELECT 'holding', h.id::text, p.username || '@' || c.company_name,
       h.shares::text, h.cost::text, h.user_id::text, now()
  FROM public.holdings h
  JOIN public.profiles p ON p.id = h.user_id
  JOIN public.user_companies c ON c.id = h.company_id
 WHERE c.company_name IN ('Utw','NB频道');

SELECT count(*) AS 备份条数 FROM public._revert_utw_pump_backup_20261004;


-- ============================================================
-- 第三步：预览（看撤销后会变成什么样）
-- ============================================================
WITH pump AS (
    SELECT c.id AS cid, c.company_name,
           sum(round(t.cash / 1.05)) AS 要退的钱,   -- 本金合计
           sum(t.shares)             AS 要收回的股份,
           sum(t.cash) - sum(round(t.cash / 1.05)) AS 手续费不退的部分
      FROM public.stock_trades t
      JOIN public.user_companies c ON c.id = t.company_id
     WHERE t.created_at > '2026-10-04 04:40:00+00' AND t.side = 'buy'
       AND c.company_name IN ('Utw','NB频道')
     GROUP BY c.id, c.company_name
)
SELECT c.company_name,
       c.pool_cash                              AS 池子现金_现在,
       c.pool_cash - p.要退的钱                  AS 池子现金_撤销后,
       c.pool_shares                            AS 池子股份_现在,
       c.pool_shares + p.要收回的股份             AS 池子股份_撤销后,
       round((c.pool_cash - p.要退的钱) / NULLIF(c.pool_shares + p.要收回的股份, 0), 4)
                                                AS 股价_撤销后,
       p.要退的钱, p.要收回的股份, p.手续费不退的部分
  FROM public.user_companies c
  JOIN pump p ON p.cid = c.id;

-- 预期：
--   Utw      池子现金 53,348,780,231 → 148,770,231   股份 414,865.75 → 148,770,231   股价 → 1.0000
--   NB频道    池子现金 1,000,011,000 → 11,000        股份 0.40 → 36,363.64          股价 → 0.3024


-- ============================================================
-- 第四步：执行
-- ============================================================
DO $$
DECLARE
    r RECORD;
    v_refund numeric;
    v_shares numeric;
BEGIN
    FOR r IN
        SELECT c.id AS cid, c.company_name,
               sum(round(t.cash / 1.05)) AS 退钱,
               sum(t.shares)             AS 收股
          FROM public.stock_trades t
          JOIN public.user_companies c ON c.id = t.company_id
         WHERE t.created_at > '2026-10-04 04:40:00+00' AND t.side = 'buy'
           AND c.company_name IN ('Utw','NB频道')
         GROUP BY c.id, c.company_name
    LOOP
        v_refund := r.退钱;
        v_shares := r.收股;

        RAISE NOTICE '--- 处理「%」：退 % NB币，收回 % 张股份 ---',
                     r.company_name, v_refund, v_shares;

        -- ① 退钱给买家们（按 trade 逐笔退）
        FOR r IN
            SELECT t.user_id, round(t.cash / 1.05) AS 退
              FROM public.stock_trades t
             WHERE t.company_id = r.cid
               AND t.created_at > '2026-10-04 04:40:00+00'
               AND t.side = 'buy'
        LOOP
            UPDATE public.profiles
               SET nb_balance = COALESCE(nb_balance,0) + r.退
             WHERE id = r.user_id;
            RAISE NOTICE '    退给 % ：%', r.user_id, r.退;
        END LOOP;

        -- ② 删掉这些买家在这个公司的持股
        --    ⚠️ 只删这轮买入的买家，不碰创始人和其他老股东
        DELETE FROM public.holdings h
         WHERE h.company_id = r.cid
           AND h.user_id IN (
               SELECT DISTINCT t.user_id FROM public.stock_trades t
                WHERE t.company_id = r.cid
                  AND t.created_at > '2026-10-04 04:40:00+00'
                  AND t.side = 'buy'
           )
           AND h.user_id <> (SELECT founder_id FROM public.user_companies WHERE id = r.cid);
        -- 创始人的持股不动

        -- ③ 恢复池子
        UPDATE public.user_companies
           SET pool_cash   = pool_cash - v_refund,
               pool_shares = pool_shares + v_shares
         WHERE id = r.cid;

        RAISE NOTICE '    「%」池子已恢复', r.company_name;
    END LOOP;
END $$;


-- ============================================================
-- 第五步：验收
-- ============================================================
SELECT id, company_name, pool_cash, pool_shares, total_shares,
       round(pool_cash::numeric / NULLIF(pool_shares,0), 4) AS 股价,
       round(pool_cash::numeric / NULLIF(pool_shares,0) * total_shares::numeric, 2) AS 市值
  FROM public.user_companies WHERE company_name IN ('Utw','NB频道') ORDER BY id;
-- 预期：Utw 股价 1.0000、市值约 2.98 亿；NB频道 股价 0.3024

-- 股东恢复情况
SELECT c.company_name, p.username AS 股东, round(h.shares,2) AS 持股, h.cost AS 投入成本
  FROM public.holdings h
  JOIN public.profiles p ON p.id = h.user_id
  JOIN public.user_companies c ON c.id = h.company_id
 WHERE c.company_name IN ('Utw','NB频道')
 ORDER BY c.company_name, h.shares DESC;

-- 全站总量（应该比撤销前【少】—— 因为退的是本金，手续费那 5% 不退）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额 FROM public.profiles;


-- ============================================================
-- 回滚
-- ============================================================
-- 从 _revert_utw_pump_backup_20261004 恢复池子：
-- UPDATE public.user_companies c
--    SET pool_cash = b.值1::numeric, pool_shares = b.值2::numeric
--   FROM public._revert_utw_pump_backup_20261004 b
--  WHERE b.类型 = 'company' AND c.id = b.键::bigint;
--
-- （持股表和余额没做完整回滚备份 —— 真要回滚的话得重跑一遍正向操作）


-- ============================================================
-- ⚠️ 三件事你要知道
-- ============================================================
--
-- ① 你在「Utw」里那 9,999.33 股也会被删掉
--    你是 04:21:56 花 10,500 买的，现在值 12.86 亿 —— 但那是他拉盘拉出来的。
--    撤销后你把 10,000 本金拿回来，等于没赚没亏。
--    如果你想留着这 9,999 股（值 12.86 亿），告诉我，我改成不删你的。
--
-- ② 手续费那 5% 不退
--    Utw小号 实付 558.6 亿，退 532 亿，差 26.6 亿是手续费 —— 已经销毁了。
--    退回来的话等于造币。
--
-- ③ 还有别的股东在「Utw」里（MINE / 快乐生活每一天 / Microsoft …）
--    他们的持股不动，但股价从 128,592 跌回 1.00 后，他们的市值会大幅缩水。
--    这是必然的 —— 他们的"市值"本来就是他拉出来的。
-- ============================================================
