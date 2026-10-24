-- ============================================================
-- 修复：增资写流水被 CHECK 约束拦下
-- ============================================================
--
-- 报错：
--   new row for relation "stock_trades" violates
--   check constraint "stock_trades_side_check"
--
-- 原因：
--   amm_part1 建 stock_trades 时把 side 限定成了四种：
--       CHECK (side IN ('buy','sell','dividend','liquidate'))
--   后来加增资功能，往里面插 side = 'inject' —— 不在白名单里，被拦。
--   这是我的疏忽：加新业务类型时忘了同步改约束。
--
-- 修法：把 'inject' 加进允许列表。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：先看现在的约束长什么样
-- ============================================================
SELECT conname AS 约束名,
       pg_get_constraintdef(oid) AS 定义
  FROM pg_constraint
 WHERE conrelid = 'public.stock_trades'::regclass
   AND contype = 'c';


-- ============================================================
-- 第二步：换掉约束
-- ============================================================
ALTER TABLE public.stock_trades
    DROP CONSTRAINT IF EXISTS stock_trades_side_check;

ALTER TABLE public.stock_trades
    ADD CONSTRAINT stock_trades_side_check
    CHECK (side IN ('buy', 'sell', 'dividend', 'liquidate', 'inject'));


-- ============================================================
-- 第三步：验收
-- ============================================================
SELECT conname AS 约束名,
       pg_get_constraintdef(oid) AS 定义
  FROM pg_constraint
 WHERE conrelid = 'public.stock_trades'::regclass
   AND contype = 'c';
-- 应该看到 side = ANY (ARRAY['buy','sell','dividend','liquidate','inject'])


-- ============================================================
-- 第四步：确认没有别的约束会挡增资
-- ------------------------------------------------------------
-- 增资那句 INSERT 是：
--     INSERT INTO public.stock_trades
--         (user_id, company_id, side, cash, shares, price_after)
--     VALUES (p_user_id, p_company_id, 'inject', p_amount, 0, round(v_p1,4));
--
-- 检查这几个字段有没有 NOT NULL 或者别的 CHECK：
-- ============================================================
SELECT column_name AS 字段, data_type AS 类型,
       is_nullable AS 可空, column_default AS 默认值
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'stock_trades'
 ORDER BY ordinal_position;

-- 另外看看有没有别的 CHECK 约束（比如 cash > 0 之类）
SELECT conname AS 约束名, pg_get_constraintdef(oid) AS 定义
  FROM pg_constraint
 WHERE conrelid = 'public.stock_trades'::regclass
 ORDER BY contype;


-- ============================================================
-- 第五步：修完再试一次增资
-- ------------------------------------------------------------
-- 前端直接点就行。想看后端返回什么的话：
-- SELECT public.inject_company_capital(
--     '你的-uuid'::uuid, '你的-session', 公司id, 1000);
-- ============================================================
