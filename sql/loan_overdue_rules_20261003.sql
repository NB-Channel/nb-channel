-- ============================================================
-- 贷款逾期新规则：3 天宽限 + 强制扣款 + 首页提醒
-- ============================================================
--
-- 【站长定的规则】
--   逾期后 → 首页弹提醒
--   3 天不处理 → 强制扣款：
--       ① 优先扣【活期存款】，最多扣到 0
--       ② 不够再扣【现金】，现金【可以扣成负数】
--       ③ 定期存款（fixed7 / fixed30）【不动】
--
-- 【改前的行为】
--   到期还不上 → 罚息 0.1%/天累加进本金 + 信誉 -15 + 到期时间顺延 1 天
--   然后……就一直这么拖着。没有强制手段，冻结的抵押品也不没收。
--   实测两个人各借了 150 万，余额只剩 65k / 23，靠罚息感化他们。
--
-- 【改后的行为】
--   到期还不上 → 进入逾期状态（不再顺延日期，这样才能算出逾期几天）
--       逾期 0~2 天：罚息 + 信誉 -15（首页显示提醒，还剩几天）
--       逾期 ≥ 3 天：强制扣款，一次结清
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：备份（万一要回滚）
-- ============================================================
CREATE TABLE IF NOT EXISTS public._func_backup_loan_20261003 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'bank_daily_settle';

SELECT 函数名, length(定义) AS 定义长度 FROM public._func_backup_loan_20261003;


-- ============================================================
-- 第二步：强制扣款的工具函数
-- ------------------------------------------------------------
-- 扣款顺序（站长定的）：
--     ① 活期存款，最多扣到 0     ← 定期不动
--     ② 现金，可以扣成负数
-- 返回每笔从哪扣了多少，方便记流水。
-- ============================================================
CREATE OR REPLACE FUNCTION public._loan_force_collect(
    p_user_id uuid,
    p_owed    bigint,
    p_kind    text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_dep       bigint;
    v_take      bigint;
    v_left      bigint := GREATEST(p_owed, 0);
    v_from_dep  bigint := 0;
    v_from_cash bigint := 0;
BEGIN
    IF v_left <= 0 THEN
        RETURN jsonb_build_object('from_deposit',0,'from_cash',0,'remain',0);
    END IF;

    -- ① 活期存款（最多扣到 0；定期 fixed7 / fixed30 完全不动）
    SELECT COALESCE(deposit, 0) INTO v_dep
      FROM public.bank_accounts WHERE user_id = p_user_id;

    IF COALESCE(v_dep, 0) > 0 THEN
        v_take := LEAST(v_dep, v_left);
        UPDATE public.bank_accounts
           SET deposit = deposit - v_take
         WHERE user_id = p_user_id;
        v_from_dep := v_take;
        v_left := v_left - v_take;
    END IF;

    -- ② 现金（不设下限，可以扣成负数）
    IF v_left > 0 THEN
        UPDATE public.profiles
           SET nb_balance = COALESCE(nb_balance, 0) - v_left
         WHERE id = p_user_id;
        v_from_cash := v_left;
        v_left := 0;
    END IF;

    -- 撤掉抵押冻结标记（债清了）
    UPDATE public.bank_accounts
       SET frozen = false, frozen_amount = 0
     WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
        'from_deposit', v_from_dep,
        'from_cash',    v_from_cash,
        'remain',       v_left);
END
$fn$;


-- ============================================================
-- 第三步：重写 bank_daily_settle
-- ------------------------------------------------------------
-- 第 1~3 段（活期利息、定期7天、定期30天）【原样保留】，
-- 只换第 4 段（抵押贷）和第 5 段（信用贷）。
-- ============================================================
CREATE OR REPLACE FUNCTION public.bank_daily_settle()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_acc record;
    v_interest bigint;
    v_processed integer := 0;
    v_owed bigint;
    v_overdue integer;
    v_res jsonb;
BEGIN
    FOR v_acc IN SELECT * FROM public.bank_accounts WHERE
        deposit > 0 OR fixed7 > 0 OR fixed30 > 0 OR
        loan_principal > 0 OR loan_credit > 0
    LOOP

-- 1) 活期利息 0.1%
        IF v_acc.deposit > 0 THEN
            v_interest := floor(v_acc.deposit * 0.001);   -- 活期 0.1%/天
            IF v_interest > 0 THEN
                UPDATE public.bank_accounts SET deposit = deposit + v_interest
                 WHERE user_id = v_acc.user_id;
                UPDATE public.profiles SET nb_balance = nb_balance + v_interest
                 WHERE id = v_acc.user_id;
                INSERT INTO public.bank_logs (user_id, type, amount, detail)
                VALUES (v_acc.user_id, 'interest', v_interest, '活期利息 0.1%');
            END IF;
        END IF;

        -- 2) 定期 7 天到期 → 转活期+利息
        IF v_acc.fixed7 > 0 AND v_acc.fixed7_until IS NOT NULL
           AND v_acc.fixed7_until <= now() THEN
            v_interest := floor(v_acc.fixed7 * 0.02);
            UPDATE public.bank_accounts
               SET deposit = deposit + v_acc.fixed7 + v_interest,
                   fixed7 = 0, fixed7_until = NULL
             WHERE user_id = v_acc.user_id;
            UPDATE public.profiles SET nb_balance = nb_balance + v_acc.fixed7 + v_interest
             WHERE id = v_acc.user_id;
            INSERT INTO public.bank_logs (user_id, type, amount, detail)
            VALUES (v_acc.user_id, 'interest', v_interest,
                format('定期7天到期（本金 %s + 利息 %s，总利率2%%）', v_acc.fixed7, v_interest));
        END IF;

        -- 3) 定期 30 天到期 → 转活期+利息
        IF v_acc.fixed30 > 0 AND v_acc.fixed30_until IS NOT NULL
           AND v_acc.fixed30_until <= now() THEN
            v_interest := floor(v_acc.fixed30 * 0.10);
            UPDATE public.bank_accounts
               SET deposit = deposit + v_acc.fixed30 + v_interest,
                   fixed30 = 0, fixed30_until = NULL
             WHERE user_id = v_acc.user_id;
            UPDATE public.profiles SET nb_balance = nb_balance + v_acc.fixed30 + v_interest
             WHERE id = v_acc.user_id;
            INSERT INTO public.bank_logs (user_id, type, amount, detail)
            VALUES (v_acc.user_id, 'interest', v_interest,
                format('定期30天到期（本金 %s + 利息 %s，总利率10%%）', v_acc.fixed30, v_interest));
        END IF;

        -- 4) 抵押贷到期
        --    余额够 → 自动还款；不够 → 逾期（宽限 3 天，之后强制扣款）
        IF v_acc.loan_principal > 0 AND v_acc.loan_until IS NOT NULL
           AND v_acc.loan_until <= now() THEN
            DECLARE
                v_loan_start timestamptz;
                v_days integer;
            BEGIN
                SELECT created_at INTO v_loan_start
                  FROM public.bank_logs
                 WHERE user_id = v_acc.user_id AND type = 'loan'
                 ORDER BY id DESC LIMIT 1;
                IF v_loan_start IS NULL THEN v_loan_start := now() - interval '1 day'; END IF;
                v_days := GREATEST(ceil(extract(epoch FROM (now() - v_loan_start)) / 86400), 1);
                v_interest := floor(v_acc.loan_principal * 0.10 * v_days / 30);
                v_owed := v_acc.loan_principal + v_interest;

                IF (SELECT nb_balance FROM public.profiles WHERE id = v_acc.user_id) >= v_owed THEN
                    -- ===== 正常还款（余额够）=====
                    UPDATE public.profiles SET nb_balance = nb_balance - v_owed
                     WHERE id = v_acc.user_id;
                    UPDATE public.bank_accounts
                       SET loan_principal = 0, loan_until = NULL,
                           frozen = false, frozen_amount = 0
                     WHERE user_id = v_acc.user_id;
                    UPDATE public.bank_accounts
                       SET credit_score = LEAST(credit_score + 5, 1000)
                     WHERE user_id = v_acc.user_id;
                    INSERT INTO public.bank_logs (user_id, type, amount, detail)
                    VALUES (v_acc.user_id, 'repay', v_owed,
                        format('抵押贷自动还款（本金 %s + 利息 %s，%s 天）',
                               v_acc.loan_principal, v_interest, v_days));
                    INSERT INTO public.bank_logs (user_id, type, amount, detail)
                    VALUES (v_acc.user_id, 'credit_change', 5, '按时还款 +5');
                ELSE
                    -- ===== 逾期 =====
                    v_overdue := GREATEST(
                        ceil(extract(epoch FROM (now() - v_acc.loan_until)) / 86400)::int, 0);

                    IF v_overdue < 3 THEN
                        -- 宽限期：只罚息 + 扣分，首页会显示提醒
                        -- ⚠️ 注意【不再把 loan_until 顺延】—— 不然算不出逾期几天
                        v_interest := floor(v_acc.loan_principal * 0.001);
                        UPDATE public.bank_accounts
                           SET loan_principal = loan_principal + v_interest,
                               credit_score = GREATEST(credit_score - 15, 0)
                         WHERE user_id = v_acc.user_id;
                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'penalty', v_interest,
                            format('抵押贷逾期第 %s 天（本金 %s，罚息 %s 累加进本金，还剩 %s 天宽限）',
                                   v_overdue + 1, v_acc.loan_principal, v_interest, 3 - v_overdue));
                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'credit_change', -15, '贷款逾期 -15');
                    ELSE
                        -- ===== 超过 3 天：强制扣款 =====
                        -- 顺序：活期存款（最多到 0）→ 现金（可负）→ 定期不动
                        v_res := public._loan_force_collect(v_acc.user_id, v_owed, '抵押贷');

                        UPDATE public.bank_accounts
                           SET loan_principal = 0, loan_until = NULL
                         WHERE user_id = v_acc.user_id;

                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'force_collect', v_owed,
                            format('抵押贷逾期 %s 天，强制扣款：存款扣 %s + 现金扣 %s（本金 %s + 利息 %s）',
                                   v_overdue,
                                   COALESCE((v_res->>'from_deposit')::bigint, 0),
                                   COALESCE((v_res->>'from_cash')::bigint, 0),
                                   v_acc.loan_principal, v_interest));
                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'credit_change', -30, '逾期被强制扣款 -30');
                        UPDATE public.bank_accounts
                           SET credit_score = GREATEST(credit_score - 30, 0)
                         WHERE user_id = v_acc.user_id;
                    END IF;
                END IF;
            END;
        END IF;

        -- 5) 信用贷到期（逻辑同抵押贷）
        IF v_acc.loan_credit > 0 AND v_acc.loan_credit_until IS NOT NULL
           AND v_acc.loan_credit_until <= now() THEN
            DECLARE
                v_loan_start2 timestamptz;
                v_days2 integer;
            BEGIN
                SELECT created_at INTO v_loan_start2
                  FROM public.bank_logs
                 WHERE user_id = v_acc.user_id AND type = 'loan_credit'
                 ORDER BY id DESC LIMIT 1;
                IF v_loan_start2 IS NULL THEN v_loan_start2 := now() - interval '1 day'; END IF;
                v_days2 := GREATEST(ceil(extract(epoch FROM (now() - v_loan_start2)) / 86400), 1);
                v_interest := floor(v_acc.loan_credit *
                                    (CASE WHEN v_acc.credit_score >= 800 THEN 0.108 ELSE 0.12 END)
                                    * v_days2 / 30);
                v_owed := v_acc.loan_credit + v_interest;

                IF (SELECT nb_balance FROM public.profiles WHERE id = v_acc.user_id) >= v_owed THEN
                    -- ===== 正常还款 =====
                    UPDATE public.profiles SET nb_balance = nb_balance - v_owed
                     WHERE id = v_acc.user_id;
                    UPDATE public.bank_accounts
                       SET loan_credit = 0, loan_credit_until = NULL
                     WHERE user_id = v_acc.user_id;
                    UPDATE public.bank_accounts
                       SET credit_score = LEAST(credit_score + 5, 1000)
                     WHERE user_id = v_acc.user_id;
                    INSERT INTO public.bank_logs (user_id, type, amount, detail)
                    VALUES (v_acc.user_id, 'repay_credit', v_owed,
                        format('信用贷自动还款（本金 %s + 利息 %s，%s 天）',
                               v_acc.loan_credit, v_interest, v_days2));
                    INSERT INTO public.bank_logs (user_id, type, amount, detail)
                    VALUES (v_acc.user_id, 'credit_change', 5, '按时还款 +5');
                ELSE
                    -- ===== 逾期 =====
                    v_overdue := GREATEST(
                        ceil(extract(epoch FROM (now() - v_acc.loan_credit_until)) / 86400)::int, 0);

                    IF v_overdue < 3 THEN
                        v_interest := floor(v_acc.loan_credit * 0.001);
                        UPDATE public.bank_accounts
                           SET loan_credit = loan_credit + v_interest,
                               credit_score = GREATEST(credit_score - 15, 0)
                         WHERE user_id = v_acc.user_id;
                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'penalty', v_interest,
                            format('信用贷逾期第 %s 天（本金 %s，罚息 %s 累加进本金，还剩 %s 天宽限）',
                                   v_overdue + 1, v_acc.loan_credit, v_interest, 3 - v_overdue));
                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'credit_change', -15, '贷款逾期 -15');
                    ELSE
                        v_res := public._loan_force_collect(v_acc.user_id, v_owed, '信用贷');

                        UPDATE public.bank_accounts
                           SET loan_credit = 0, loan_credit_until = NULL
                         WHERE user_id = v_acc.user_id;

                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'force_collect', v_owed,
                            format('信用贷逾期 %s 天，强制扣款：存款扣 %s + 现金扣 %s（本金 %s + 利息 %s）',
                                   v_overdue,
                                   COALESCE((v_res->>'from_deposit')::bigint, 0),
                                   COALESCE((v_res->>'from_cash')::bigint, 0),
                                   v_acc.loan_credit, v_interest));
                        INSERT INTO public.bank_logs (user_id, type, amount, detail)
                        VALUES (v_acc.user_id, 'credit_change', -30, '逾期被强制扣款 -30');
                        UPDATE public.bank_accounts
                           SET credit_score = GREATEST(credit_score - 30, 0)
                         WHERE user_id = v_acc.user_id;
                    END IF;
                END IF;
            END;
        END IF;

        v_processed := v_processed + 1;
    END LOOP;
    RETURN v_processed;
END;
$$;


-- ============================================================
-- 第四步：首页提醒用的读取函数
-- ------------------------------------------------------------
-- 首页调这个，有逾期就显示横幅。
-- 不建新表 —— 直接查 bank_accounts，不产生额外数据。
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_loan_alert(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_acc   record;
    v_items jsonb := '[]'::jsonb;
    v_od    integer;
    v_int   bigint;
    v_owed  bigint;
    v_left  integer;
BEGIN
    SELECT * INTO v_acc FROM public.bank_accounts WHERE user_id = p_user_id;
    IF v_acc.user_id IS NULL THEN
        RETURN jsonb_build_object('has_alert', false, 'items', '[]'::jsonb);
    END IF;

    -- 抵押贷
    IF v_acc.loan_principal > 0 AND v_acc.loan_until IS NOT NULL
       AND v_acc.loan_until <= now() THEN
        v_od := GREATEST(ceil(extract(epoch FROM (now() - v_acc.loan_until)) / 86400)::int, 0);
        v_int := floor(v_acc.loan_principal * 0.10 *
                       GREATEST(ceil(extract(epoch FROM (now() - v_acc.loan_until)) / 86400), 1) / 30);
        v_owed := v_acc.loan_principal + v_int;
        v_left := GREATEST(3 - v_od, 0);
        v_items := v_items || jsonb_build_object(
            'kind', '抵押贷',
            'principal', v_acc.loan_principal,
            'interest', v_int,
            'owed', v_owed,
            'overdue_days', v_od,
            'days_left', v_left,
            'deposit', v_acc.deposit,
            'bal', (SELECT nb_balance FROM public.profiles WHERE id = p_user_id),
            'message', CASE WHEN v_left > 0
                THEN format('你的抵押贷已逾期 %s 天，应还 %s NB币。还有 %s 天，逾期满 3 天将自动从存款和余额中扣除。',
                            v_od, v_owed, v_left)
                ELSE format('你的抵押贷已逾期 %s 天，应还 %s NB币，即将被强制扣款。',
                            v_od, v_owed) END);
    END IF;

    -- 信用贷
    IF v_acc.loan_credit > 0 AND v_acc.loan_credit_until IS NOT NULL
       AND v_acc.loan_credit_until <= now() THEN
        v_od := GREATEST(ceil(extract(epoch FROM (now() - v_acc.loan_credit_until)) / 86400)::int, 0);
        v_int := floor(v_acc.loan_credit *
                       (CASE WHEN v_acc.credit_score >= 800 THEN 0.108 ELSE 0.12 END) *
                       GREATEST(ceil(extract(epoch FROM (now() - v_acc.loan_credit_until)) / 86400), 1) / 30);
        v_owed := v_acc.loan_credit + v_int;
        v_left := GREATEST(3 - v_od, 0);
        v_items := v_items || jsonb_build_object(
            'kind', '信用贷',
            'principal', v_acc.loan_credit,
            'interest', v_int,
            'owed', v_owed,
            'overdue_days', v_od,
            'days_left', v_left,
            'deposit', v_acc.deposit,
            'bal', (SELECT nb_balance FROM public.profiles WHERE id = p_user_id),
            'message', CASE WHEN v_left > 0
                THEN format('你的信用贷已逾期 %s 天，应还 %s NB币。还有 %s 天，逾期满 3 天将自动从存款和余额中扣除。',
                            v_od, v_owed, v_left)
                ELSE format('你的信用贷已逾期 %s 天，应还 %s NB币，即将被强制扣款。',
                            v_od, v_owed) END);
    END IF;

    RETURN jsonb_build_object(
        'has_alert', jsonb_array_length(v_items) > 0,
        'items', v_items);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_my_loan_alert(uuid) TO anon, authenticated;


-- ============================================================
-- 第五步：验收
-- ============================================================
-- 5.1 三个函数都在
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('bank_daily_settle','_loan_force_collect','get_my_loan_alert')
 ORDER BY 1;

-- 5.2 那两个人的逾期状态（应该显示已逾期、宽限 0 天）
SELECT p.username,
       b.loan_credit                                        AS 信用贷欠款,
       b.loan_credit_until                                  AS 到期时间,
       GREATEST(ceil(extract(epoch FROM (now() - b.loan_credit_until))/86400)::int, 0) AS 逾期天数,
       COALESCE(p.nb_balance,0)                             AS 现金,
       b.deposit                                            AS 活期存款
  FROM public.bank_accounts b
  JOIN public.profiles p ON p.id = b.user_id
 WHERE b.loan_credit > 0 OR b.loan_principal > 0;

-- 5.3 试调提醒函数
-- SELECT public.get_my_loan_alert('7f9f116f-9a48-4e32-8c26-f4a49f970079'::uuid);


-- ============================================================
-- 第六步：手动跑一次结算（看效果）
-- ------------------------------------------------------------
-- ⚠️ 跑之前想清楚：那两个人已经逾期超过 3 天，一跑就会【立刻强制扣款】。
--    如果你想走 collect_credit_loan 那份脚本手动扣，就先别跑这个。
-- ============================================================
-- SELECT public.bank_daily_settle();


-- ============================================================
-- 回滚
-- ============================================================
-- SELECT 定义 FROM public._func_backup_loan_20261003;  -- 取出原定义重跑
