-- ============================================================
-- 撤销增资：把「NB频道」那笔误操作的增资退回来
-- ============================================================
--
-- 【怎么误操作的】
--   ① 注册公司 → 拿到 20,000 张创始股
--   ② 把 20,000 张【全卖了】→ 持股清零，holdings 记录被删
--      池子从 20,000 现金 / 20,000 股份变成 10,000 现金 / 40,000 股份
--   ③ 又注资 2.105 亿 → 池子现金 210,510,000，股价 5262.75
--
--   ⚠️ 增资是往公司池子打钱、不拿股份的操作。
--      所以他注完钱，持股还是 0 —— 分红和清算都拿不到钱。
--
-- 【这个脚本做什么】
--   把那笔增资【原路退回】，池子恢复到注资前的样子。
--
-- 【执行顺序】
--   第一步 诊断 → 第二步 备份 → 第三步 预览 → 第四步 执行 → 第五步 验收
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：诊断（只查不改）
-- ============================================================

-- 1.1 你的公司现在什么样
SELECT c.id, c.company_name,
       c.pool_cash        AS 池子现金,
       c.pool_shares      AS 池子股份,
       c.total_shares     AS 总股本,
       c.total_injected   AS 累计增资,
       c.last_injection_at AS 上次增资,
       round(c.pool_cash::numeric / NULLIF(c.pool_shares,0), 4) AS 当前股价
  FROM public.user_companies c
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;

-- 1.2 你的操作流水（确认卖出和增资的金额）
SELECT side AS 类型, cash AS 金额, shares AS 份额,
       fee AS 手续费, price_after AS 成交后股价, created_at AS 时间
  FROM public.stock_trades
 WHERE user_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid
 ORDER BY created_at;

-- 1.3 ⭐ 那个持有 21 张的人是谁（重要，撤销后他会亏）
SELECT h.user_id, p.username,
       h.shares           AS 持股,
       h.cost             AS 投入成本,
       round(h.shares * (c.pool_cash::numeric / NULLIF(c.pool_shares,0)), 2) AS 当前市值,
       c.company_name
  FROM public.holdings h
  JOIN public.user_companies c ON c.id = h.company_id
  LEFT JOIN public.profiles p ON p.id = h.user_id
 WHERE h.company_id IN (SELECT id FROM public.user_companies
                         WHERE founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid)
   AND h.shares > 0;


-- ============================================================
-- 第二步：备份
-- ============================================================
DROP TABLE IF EXISTS public._revert_inject_backup_20261003;
CREATE TABLE public._revert_inject_backup_20261003 AS
SELECT c.id AS company_id, c.company_name,
       c.pool_cash, c.pool_shares, c.total_shares,
       c.total_injected, c.last_injection_at,
       p.nb_balance AS founder_balance_before,
       now() AS backup_at
  FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.founder_id
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;

SELECT * FROM public._revert_inject_backup_20261003;


-- ============================================================
-- 第三步：预览（看退完之后是什么样，只查不改）
-- ============================================================
SELECT c.company_name,
       c.total_injected                       AS 将退回的金额,
       c.pool_cash                            AS 池子现金_现在,
       c.pool_cash - c.total_injected         AS 池子现金_退回后,
       round((c.pool_cash - c.total_injected)::numeric / NULLIF(c.pool_shares,0), 4) AS 股价_退回后,
       p.nb_balance                           AS 你的余额_现在,
       p.nb_balance + c.total_injected        AS 你的余额_退回后
  FROM public.user_companies c
  JOIN public.profiles p ON p.id = c.founder_id
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;


-- ============================================================
-- 第四步：执行（看完第三步觉得对再跑）
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

        -- 安全阀：池子不能被退成负数
        IF v_newpool < 0 THEN
            RAISE NOTICE '跳过「%」：池子现金 % 不够退 %', r.company_name, r.pc, v_amt;
            CONTINUE;
        END IF;

        -- 钱退回你的余额
        UPDATE public.profiles
           SET nb_balance = COALESCE(nb_balance,0) + v_amt
         WHERE id = v_uid;

        -- 池子扣掉这笔，增资记录清零
        UPDATE public.user_companies
           SET pool_cash         = v_newpool,
               total_injected    = 0,
               last_injection_at = NULL
         WHERE id = r.id;

        -- 记一笔流水，方便以后对账
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
-- 5.1 公司现状
SELECT c.company_name, c.pool_cash AS 池子现金, c.pool_shares AS 池子股份,
       round(c.pool_cash::numeric / NULLIF(c.pool_shares,0), 4) AS 股价,
       c.total_injected AS 累计增资, c.last_injection_at AS 上次增资
  FROM public.user_companies c
 WHERE c.founder_id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;

-- 5.2 你的余额（应该比原来多了 total_injected 那么多）
SELECT username, nb_balance AS 余额
  FROM public.profiles
 WHERE id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;

-- 5.3 撤销流水
SELECT side, cash, created_at FROM public.stock_trades
 WHERE side = 'inject_revert' ORDER BY created_at DESC LIMIT 5;


-- ============================================================
-- 回滚
-- ============================================================
-- UPDATE public.profiles p SET nb_balance = b.founder_balance_before
--   FROM public._revert_inject_backup_20261003 b
--  WHERE p.id = '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid;
--
-- UPDATE public.user_companies c
--    SET pool_cash = b.pool_cash, total_injected = b.total_injected,
--        last_injection_at = b.last_injection_at
--   FROM public._revert_inject_backup_20261003 b
--  WHERE c.id = b.company_id;


-- ============================================================
-- ⚠️ 撤销之后还剩一个问题：你还是【没有股份】
-- ------------------------------------------------------------
-- 撤销增资只是把钱拿回来了。但你之前把 20,000 张创始股卖光了，
-- 现在持股仍然是 0 —— 分红和清算还是轮不到你。
--
-- 那个持有 21 张的人，撤销后手里的股份会从值 11 万变成值几块钱
-- （因为股价从 5262.75 跌回 0.25）。他亏了，这是市场风险，
-- 但如果你想补偿他，或者想把自己的股份拿回来，告诉我，
-- 我另外写。
--
-- 先把钱拿回来，其他的慢慢说。
-- ============================================================
