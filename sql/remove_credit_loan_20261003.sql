-- ============================================================
-- 下线信用贷
-- ============================================================
--
-- 【为什么删】
-- bank_credit_loan 是纯信用贷款，没有任何抵押，贷出来的钱是直接印的：
--
--     UPDATE public.profiles SET nb_balance = nb_balance + p_amount;
--
-- 银行没有资金池，贷出去的不是别人的存款。不还也只有罚息和扣信誉分
-- 两个软约束。等于【注册个新号就能白拿钱】。
--
-- 站长决定：直接删掉这个功能，不做存款背书那套补丁。
--
-- 【删之前要先处理存量】
-- 有人可能已经贷了钱没还。直接停用会让这些债务悬空 ——
-- 所以本脚本先看清有多少、再决定怎么收尾。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：先看清存量（只查不改）
-- ============================================================

-- 1.1 有多少信用贷没还、总额多少
SELECT count(*)                        AS 未还笔数,
       COALESCE(sum(loan_credit), 0)   AS 未还本金合计,
       COALESCE(max(loan_credit), 0)   AS 单笔最大
  FROM public.bank_accounts WHERE loan_credit > 0;

-- 1.2 逐笔明细（看这些人手上还有没有钱可扣）
SELECT b.user_id, p.username,
       b.loan_credit               AS 欠款,
       COALESCE(p.nb_balance, 0)   AS 当前余额,
       b.credit_score              AS 信誉分,
       b.loan_credit_until         AS 到期时间,
       CASE WHEN COALESCE(p.nb_balance,0) >= b.loan_credit
            THEN '余额够，可扣'
            ELSE '余额不够' END      AS 能不能追回
  FROM public.bank_accounts b
  LEFT JOIN public.profiles p ON p.id = b.user_id
 WHERE b.loan_credit > 0
 ORDER BY b.loan_credit DESC LIMIT 50;

-- 1.3 全站余额总量（记下来，收尾后对比）
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额_收尾前 FROM public.profiles;


-- ============================================================
-- 第二步：停用 bank_credit_loan
-- ------------------------------------------------------------
-- 函数不删，只让它永远返回"已下线"。
-- 为什么保留函数体：前端还留着按钮的话，删函数会报
-- "function does not exist"（500），保留的话是干净的
-- 业务提示（success:false）。前端清完之后可以再删。
-- ============================================================
CREATE OR REPLACE FUNCTION public.bank_credit_loan(
    p_user_id uuid, p_amount bigint, p_days integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN jsonb_build_object(
        'success', false,
        'message', '信用贷功能已下线。如需周转请用「抵押贷」——先存款，再按存款的 80% 借。');
END
$fn$;

-- 还款入口也一起停（没有新贷款了，还款没意义）
CREATE OR REPLACE FUNCTION public.bank_repay_credit(p_user_id uuid, p_amount bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN jsonb_build_object(
        'success', false,
        'message', '信用贷功能已下线，无需还款。');
END
$fn$;


-- ============================================================
-- 第三步：处理存量欠款 —— 三选一
-- ------------------------------------------------------------
-- 看完第一步 1.2 的明细再决定。
-- ============================================================

-- ------------------------------------------------------------
-- 【方案 A】一笔勾销（推荐）
-- ------------------------------------------------------------
-- 把未还的信用贷直接清掉，玩家不用还了，钱留在他手里。
--
-- 为什么推荐：
--   · 那些钱多半已经花掉或转走了，硬扣会造成余额变负数
--   · 追回的金额有限，但会得罪一批人
--   · 反正功能都下线了，留个尾巴不如一次清干净
--
-- UPDATE public.bank_accounts
--    SET loan_credit = 0,
--        loan_credit_until = NULL
--  WHERE loan_credit > 0;

-- ------------------------------------------------------------
-- 【方案 B】能扣就扣，扣不动的勾销
-- ------------------------------------------------------------
-- 余额够的扣掉，不够的就算了。
--
-- DO $$
-- DECLARE r RECORD;
-- BEGIN
--     FOR r IN SELECT b.user_id, b.loan_credit,
--                     COALESCE(p.nb_balance,0) AS bal
--                FROM public.bank_accounts b
--                JOIN public.profiles p ON p.id = b.user_id
--               WHERE b.loan_credit > 0
--     LOOP
--         IF r.bal >= r.loan_credit THEN
--             UPDATE public.profiles
--                SET nb_balance = nb_balance - r.loan_credit
--              WHERE id = r.user_id;
--             INSERT INTO public.bank_logs (user_id, type, amount, detail)
--             VALUES (r.user_id, 'repay_credit', r.loan_credit,
--                     '信用贷下线，系统自动收回欠款');
--         ELSE
--             INSERT INTO public.bank_logs (user_id, type, amount, detail)
--             VALUES (r.user_id, 'repay_credit', 0,
--                     format('信用贷下线，欠款 %s 因余额不足被勾销', r.loan_credit));
--         END IF;
--         UPDATE public.bank_accounts
--            SET loan_credit = 0, loan_credit_until = NULL
--          WHERE user_id = r.user_id;
--     END LOOP;
-- END $$;

-- ------------------------------------------------------------
-- 【方案 C】先不动，让他们用原来的还款入口还完
-- ------------------------------------------------------------
-- 但上面已经把 bank_repay_credit 停了 —— 这个方案和第二步冲突，
-- 要用的话把第二步的 bank_repay_credit 那段去掉。
-- 不推荐：会拖很久。


-- ============================================================
-- 第四步：把 bank_daily_settle 里的信用贷分支摘掉
-- ------------------------------------------------------------
-- 它每天会跑一遍，处理逾期、扣信誉分。欠款清零后这个分支就不干活了，
-- 但留着容易引起误会（也白白循环）。要不要摘看下面说明。
--
-- ⚠️ 这一步需要 bank_daily_settle 的完整定义。
--    我没拿到线上版本，所以给的是【改法】：
--
--    找到这一段（第 5 段）：
--        -- 5) 信用贷到期 → 自动扣本息…
--        IF v_acc.loan_credit > 0 AND v_acc.loan_credit_until IS NOT NULL
--           AND v_acc.loan_credit_until <= now() THEN
--            ...
--        END IF;
--
--    整段删掉即可。其余四段（活期利息、定期7天、定期30天、抵押贷）
--    保持不动。
--
--    把线上定义发我，我直接给你改好的完整版本。


-- ============================================================
-- 第五步：验收
-- ============================================================
-- 5.1 函数已停用（试调一次应该返回"已下线"）
-- SELECT public.bank_credit_loan('你的-uuid'::uuid, 100, 7);

-- 5.2 欠款清零情况
SELECT count(*) AS 剩余未还笔数,
       COALESCE(sum(loan_credit),0) AS 剩余未还金额
  FROM public.bank_accounts WHERE loan_credit > 0;

-- 5.3 余额对比
SELECT COALESCE(sum(nb_balance),0) AS 全站总余额_收尾后 FROM public.profiles;


-- ============================================================
-- 第六步：彻底删掉（前端清干净之后再跑）
-- ============================================================
-- DROP FUNCTION IF EXISTS public.bank_credit_loan(uuid, bigint, integer);
-- DROP FUNCTION IF EXISTS public.bank_repay_credit(uuid, bigint);
--
-- 表字段先别删 —— bank_daily_settle 还在引用 loan_credit，
-- 删列会让那个函数报错。等第四步做完再说：
-- ALTER TABLE public.bank_accounts DROP COLUMN IF EXISTS loan_credit;
-- ALTER TABLE public.bank_accounts DROP COLUMN IF EXISTS loan_credit_until;
