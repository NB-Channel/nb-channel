-- ============================================================
-- 股票系统重构 · 补丁：给创始人补上股份
-- ============================================================
--
-- 【问题】
--   Part 2 迁移时只处理了 holdings 表里已有的记录，
--   但旧模型里【创始人不需要持股】（他靠 user_companies.user_id 直接拿钱）。
--   结果迁移后大部分公司的创始人 0 股份。
--
--   而新模型里：
--       分红 按玩家持股比例分    → 他 0 股拿不到
--       清算 池子现金按持股比例分 → 他 0 股拿不到
--   等于他出的钱全归了"股东"，而他自己不是股东。
--
--   这还跟 Part 1 的注册规则不一致 ——
--   注册时明确写了「创始人得 C 张股份」，迁移却没给。
--
-- 【修法】
--   按注册的同一套规则补：
--       创始人股份 = pool_cash    （价格 1.00 时，出多少钱 = 拿多少张）
--       池子股份   = 不变          （价格保持 1.00 不变）
--       总股本     = 池子股份 + 创始人股份 + 其他股东股份
--
--   验证（以 Utw 为例）：
--       池子现金   148,770,231
--       池子股份   148,770,231   → 价格仍 1.0000 ✅
--       创始人股份 148,770,231   → 价值 = 他出的钱 ✅
--       其他股东   12,064.6781   （迁移过来的，不动）
--       总股本     297,552,526
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第 0 步：先看现在什么状况（只查不改）
-- ============================================================
SELECT
    c.company_name,
    c.founder_id,
    fp.username                       AS 创始人,
    c.pool_cash,
    c.pool_shares,
    (SELECT COALESCE(shares,0) FROM public.holdings h
      WHERE h.company_id = c.id AND h.user_id = c.founder_id)   AS 创始人现有股份,
    (SELECT COALESCE(sum(shares),0) FROM public.holdings h
      WHERE h.company_id = c.id AND h.user_id <> c.founder_id)  AS 其他股东股份,
    c.total_shares
  FROM public.user_companies c
  LEFT JOIN public.profiles fp ON fp.id = c.founder_id
 ORDER BY c.pool_cash DESC
 LIMIT 30;

-- 统计一下有多少家创始人 0 股份
SELECT
    count(*) AS 公司总数,
    count(*) FILTER (WHERE COALESCE((
        SELECT shares FROM public.holdings h
         WHERE h.company_id = c.id AND h.user_id = c.founder_id), 0) <= 0)
             AS 创始人0股份的
  FROM public.user_companies c;


-- ============================================================
-- 第 1 步：补股份
-- ============================================================
DO $$
DECLARE
    c            RECORD;
    v_my         numeric;
    v_others     numeric;
    v_should     numeric;    -- 创始人应得的股份
    v_add        numeric;    -- 需要补多少
    v_n          int := 0;
BEGIN
    FOR c IN SELECT * FROM public.user_companies LOOP

        -- 创始人现在有多少
        SELECT COALESCE(shares,0) INTO v_my
          FROM public.holdings
         WHERE company_id = c.id AND user_id = c.founder_id;
        v_my := COALESCE(v_my, 0);

        -- 其他股东合计
        SELECT COALESCE(sum(shares),0) INTO v_others
          FROM public.holdings
         WHERE company_id = c.id AND user_id <> c.founder_id;
        v_others := COALESCE(v_others, 0);

        -- 创始人应得 = 他出资的金额（价格 1.00 时钱数等于张数）
        v_should := round(COALESCE(c.pool_cash, 0), 4);
        v_add    := GREATEST(v_should - v_my, 0);

        IF v_add > 0 THEN
            INSERT INTO public.holdings
                (user_id, company_id, shares, cost, principal, base_market_value, updated_at)
            VALUES
                (c.founder_id, c.id, v_add, COALESCE(c.pool_cash,0),
                 COALESCE(c.pool_cash,0), COALESCE(c.pool_cash,0), now())
            ON CONFLICT (user_id, company_id) DO UPDATE
                SET shares = COALESCE(public.holdings.shares,0) + v_add,
                    cost   = COALESCE(public.holdings.cost,0) + COALESCE(c.pool_cash,0),
                    updated_at = now();
            v_n := v_n + 1;
        END IF;

        -- 重算总股本：池子 + 创始人 + 其他股东
        UPDATE public.user_companies
           SET total_shares = round(
                   COALESCE(pool_shares,0)
                 + GREATEST(v_should, v_my)
                 + v_others, 4),
               market_value = round(
                   COALESCE(pool_shares,0)
                 + GREATEST(v_should, v_my)
                 + v_others, 4)::bigint
         WHERE id = c.id;

    END LOOP;

    RAISE NOTICE '给 % 家公司的创始人补了股份', v_n;
END $$;


-- ============================================================
-- 第 2 步：验收
-- ============================================================

-- 2.1 股本配对：池子股份 + 所有股东股份 = 总股本
SELECT count(*) AS 股本不配对的公司数
  FROM public.user_companies c
 WHERE abs(c.total_shares -
           (c.pool_shares + COALESCE((SELECT sum(shares) FROM public.holdings
                                       WHERE company_id = c.id), 0))) > 0.01;
-- 预期 0

-- 2.2 价格仍是 1.00
SELECT count(*) AS 价格异常数,
       min(round(pool_cash / NULLIF(pool_shares,0), 4)) AS 最低,
       max(round(pool_cash / NULLIF(pool_shares,0), 4)) AS 最高
  FROM public.user_companies WHERE pool_shares > 0;
-- 预期 0 家，最低=最高=1.0000

-- 2.3 还有没有创始人 0 股份的
SELECT count(*) AS 创始人仍0股份的
  FROM public.user_companies c
 WHERE COALESCE((SELECT shares FROM public.holdings h
                  WHERE h.company_id = c.id AND h.user_id = c.founder_id), 0) <= 0;
-- 预期 0

-- 2.4 抽查：创始人持股价值应该等于他出的钱
SELECT
    c.company_name,
    fp.username                                    AS 创始人,
    c.pool_cash                                    AS 出资,
    (SELECT round(shares,2) FROM public.holdings h
      WHERE h.company_id = c.id AND h.user_id = c.founder_id) AS 创始人股份,
    round((SELECT shares FROM public.holdings h
            WHERE h.company_id = c.id AND h.user_id = c.founder_id)
          * (c.pool_cash / NULLIF(c.pool_shares,0)), 2)       AS 持股价值,
    c.total_shares
  FROM public.user_companies c
  LEFT JOIN public.profiles fp ON fp.id = c.founder_id
 ORDER BY c.pool_cash DESC LIMIT 15;
-- 「持股价值」应该 ≈ 「出资」

-- 2.5 全站余额没变（补股份不发钱，余额应该一分不动）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额 FROM public.profiles;


-- ============================================================
-- 第 3 步：补一个约束，防以后再出现
-- ------------------------------------------------------------
-- 约束内容：创始人必须有股份。用触发器实现（没法用 CHECK 跨表）。
-- ============================================================
-- CREATE OR REPLACE FUNCTION public._ensure_founder_shares()
-- RETURNS trigger LANGUAGE plpgsql AS $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM public.holdings
--                     WHERE company_id = NEW.id AND user_id = NEW.founder_id
--                       AND shares > 0) THEN
--         RAISE EXCEPTION '公司 % 的创始人没有股份，这是不允许的', NEW.id;
--     END IF;
--     RETURN NEW;
-- END $$;
--
-- ⚠️ 这个触发器会和注册流程冲突（注册时是先插公司、再插持仓），
--    要用的话得改成 DEFERRABLE 约束触发器。先不启用，记在这里备查。


-- ============================================================
-- 回滚（把补的股份撤掉）
-- ============================================================
-- 从备份表恢复持仓：
-- UPDATE public.holdings h
--    SET shares = b.shares, cost = b.cost
--   FROM public._amm_bak_holdings_20261003 b
--  WHERE h.id = b.id;
-- DELETE FROM public.holdings h
--  WHERE NOT EXISTS (SELECT 1 FROM public._amm_bak_holdings_20261003 b WHERE b.id = h.id);
