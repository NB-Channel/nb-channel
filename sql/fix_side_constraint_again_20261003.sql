-- ============================================================
-- 修 side 约束（第二次了）+ 重跑撤销增资
-- ============================================================
--
-- 报错：
--   new row for relation "stock_trades" violates
--   check constraint "stock_trades_side_check"
--   Failing row contains (..., inject_revert, ...)
--
-- 原因：我在撤销脚本里插 side = 'inject_revert'，但约束里没这个值。
--      这是【同一个坑踩第二次】—— 上次加 'inject' 时也撞过一次。
--
-- ⚠️ 好消息：DO 块是一个事务，INSERT 报错时前面的两个 UPDATE
--    （退钱、扣池子）全部回滚了，数据没动。
--
-- 【这次的处理】
--   不再一个个往里加值了，直接把约束去掉。
--   理由：side 只是个分类标签，加 CHECK 约束带来的收益很小，
--        但每加一种新操作类型就要改一次，已经绊了两次。
--        需要约束的话应该用枚举表，不是硬编码的 CHECK。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：先看现在的约束
-- ============================================================
SELECT conname AS 约束名, pg_get_constraintdef(oid) AS 定义
  FROM pg_constraint
 WHERE conrelid = 'public.stock_trades'::regclass AND contype = 'c';


-- ============================================================
-- 第二步：去掉 side 的 CHECK 约束
-- ============================================================
ALTER TABLE public.stock_trades
    DROP CONSTRAINT IF EXISTS stock_trades_side_check;

-- 顺便把 side 的注释写上，说明有哪些取值（文档代替约束）
COMMENT ON COLUMN public.stock_trades.side IS
    '操作类型：buy 买入 / sell 卖出 / dividend 收到分红 / liquidate 清算分到 / inject 增资 / inject_revert 撤销增资';


-- ============================================================
-- 第三步：验收
-- ============================================================
-- 3.1 约束应该没了（只剩主键）
SELECT conname AS 约束名, contype AS 类型, pg_get_constraintdef(oid) AS 定义
  FROM pg_constraint
 WHERE conrelid = 'public.stock_trades'::regclass
 ORDER BY contype;

-- 3.2 确认数据没被上次的失败影响
SELECT c.company_name,
       c.pool_cash      AS 池子现金,
       c.pool_shares    AS 池子股份,
       c.total_injected AS 累计增资,
       round(c.pool_cash::numeric / NULLIF(c.pool_shares,0), 4) AS 股价,
       p.nb_balance     AS 你的余额
  FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.founder_id
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;
-- 池子现金应该还是 210,510,000，累计增资还是 210,500,000
-- （如果已经变了，说明上次没回滚干净，停下来告诉我）


-- ============================================================
-- 第四步：现在重跑撤销增资
-- ------------------------------------------------------------
-- 把 revert_inject_20261003.sql 的【第四步】那段 DO 块再跑一遍即可。
-- 第二步的备份、第三步的预览不用重跑（除非你想再看一遍数字）。
--
-- 下面把它贴出来，方便直接复制：
-- ============================================================
DO $$
DECLARE
    r           RECORD;
    v_uid       uuid := '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c';
    v_amt       numeric;
    v_newpool   numeric;
    v_n         int := 0;
BEGIN
    FOR r IN
        SELECT id, company_name, COALESCE(total_injected,0) AS inj,
               COALESCE(pool_cash,0) AS pc
          FROM public.user_companies
         WHERE founder_id = v_uid
           AND COALESCE(total_injected,0) > 0
    LOOP
        v_amt := r.inj;
        v_newpool := r.pc - v_amt;

        IF v_newpool < 0 THEN
            RAISE NOTICE '跳过「%」：池子现金 % 不够退 %', r.company_name, r.pc, v_amt;
            CONTINUE;
        END IF;

        UPDATE public.profiles
           SET nb_balance = COALESCE(nb_balance,0) + v_amt
         WHERE id = v_uid;

        UPDATE public.user_companies
           SET pool_cash         = v_newpool,
               total_injected    = 0,
               last_injection_at = NULL
         WHERE id = r.id;

        INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, price_after)
        VALUES (v_uid, r.id, 'inject_revert', v_amt, 0,
                round(v_newpool / NULLIF((SELECT pool_shares FROM public.user_companies WHERE id = r.id),0), 4));

        RAISE NOTICE '「%」已撤销增资 %，池子现金 % → %',
                     r.company_name, v_amt, r.pc, v_newpool;
        v_n := v_n + 1;
    END LOOP;

    RAISE NOTICE '共撤销 % 家公司的增资', v_n;
END $$;


-- ============================================================
-- 第五步：验收
-- ============================================================
SELECT c.company_name, c.pool_cash AS 池子现金, c.pool_shares AS 池子股份,
       round(c.pool_cash::numeric / NULLIF(c.pool_shares,0), 4) AS 股价,
       c.total_injected AS 累计增资, c.last_injection_at AS 上次增资
  FROM public.user_companies c
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;

SELECT username, nb_balance AS 余额 FROM public.profiles
 WHERE id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;

SELECT side AS 类型, cash AS 金额, price_after AS 股价, created_at AS 时间
  FROM public.stock_trades
 WHERE side = 'inject_revert' ORDER BY created_at DESC LIMIT 3;
