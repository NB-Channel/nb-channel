-- ============================================================
-- 逾期提醒改成「提前提醒」
-- ============================================================
--
-- 【问题】
-- 原来的 get_my_loan_alert 只在 loan_until <= now() 时才返回提醒，
-- 也就是【已经逾期了才告诉你】—— 那时候罚息和信誉分已经开始扣了。
-- 等于提醒来得太晚，只能看着它变糟。
--
-- 【改法】
-- 提前 3 天就开始提醒，分三种状态：
--
--   upcoming   还没到期，但 3 天内到期    提示还剩几天、应还多少
--   grace      已逾期，还在 3 天宽限期内   提示已逾期几天、还剩几天会被强制扣款
--   overdue    已逾期且超过宽限期         提示即将/已被强制扣款
--
-- 返回里多了一个 status 字段，前端按它决定配色：
--     upcoming  蓝色（提醒，不紧张）
--     grace     橙色（警告）
--     overdue   红色（紧急）
--
-- 【另外加了一个提前天数参数】
--     提前提醒的天数由 stock_settings 里的 'loan_alert_days' 控制，
--     默认 3，想改就 UPDATE 一行，不用动函数。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：提前提醒的天数做成可配置
-- ============================================================
INSERT INTO public.stock_settings (key, value) VALUES
    ('loan_alert_days', '3')
ON CONFLICT (key) DO NOTHING;

SELECT * FROM public.stock_settings WHERE key = 'loan_alert_days';


-- ============================================================
-- 第二步：重写 get_my_loan_alert
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_loan_alert(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_acc      record;
    v_items    jsonb := '[]'::jsonb;
    v_ahead    integer := 3;      -- 提前几天提醒
    v_od       integer;
    v_due_in   integer;
    v_int      bigint;
    v_owed     bigint;
    v_p0       numeric;
    v_p1       numeric;
    v_st       text;
BEGIN
    -- 提前提醒天数（读配置，读不到就用默认 3）
    BEGIN
        SELECT value::int INTO v_ahead
          FROM public.stock_settings WHERE key = 'loan_alert_days';
    EXCEPTION WHEN OTHERS THEN
        v_ahead := 3;
    END;
    v_ahead := COALESCE(v_ahead, 3);

    SELECT * INTO v_acc FROM public.bank_accounts WHERE user_id = p_user_id;
    IF v_acc.user_id IS NULL THEN
        RETURN jsonb_build_object('has_alert', false, 'items', '[]'::jsonb);
    END IF;

    -- ---------------- 抵押贷 ----------------
    IF v_acc.loan_principal > 0 AND v_acc.loan_until IS NOT NULL THEN
        v_due_in := CEIL(EXTRACT(EPOCH FROM (v_acc.loan_until - now())) / 86400)::int;
        v_od     := GREATEST(-v_due_in, 0);

        IF v_due_in <= v_ahead THEN
            -- 利息：按实际借款天数折算（跟 bank_daily_settle 一致）
            DECLARE v_start timestamptz; v_days integer;
            BEGIN
                SELECT created_at INTO v_start FROM public.bank_logs
                 WHERE user_id = p_user_id AND type = 'loan'
                 ORDER BY id DESC LIMIT 1;
                v_days := GREATEST(CEIL(EXTRACT(EPOCH FROM (now() - COALESCE(v_start, now() - interval '1 day'))) / 86400), 1);
                v_int := floor(v_acc.loan_principal * 0.10 * v_days / 30);
            END;
            v_owed := v_acc.loan_principal + v_int;

            IF v_od <= 0 THEN
                v_st := 'upcoming';
            ELSIF v_od < 3 THEN
                v_st := 'grace';
            ELSE
                v_st := 'overdue';
            END IF;

            v_items := v_items || jsonb_build_object(
                'kind', '抵押贷',
                'status', v_st,
                'principal', v_acc.loan_principal,
                'interest', v_int,
                'owed', v_owed,
                'due_at', v_acc.loan_until,
                'due_in_days', GREATEST(v_due_in, 0),
                'overdue_days', v_od,
                'days_left', CASE WHEN v_od > 0 THEN GREATEST(3 - v_od, 0) ELSE NULL END,
                'deposit', v_acc.deposit,
                'bal', (SELECT nb_balance FROM public.profiles WHERE id = p_user_id),
                'message', CASE v_st
                    WHEN 'upcoming' THEN format('你的抵押贷还有 %s 天到期，应还 %s NB币（本金 %s + 利息 %s）。到期余额不足会自动从存款扣除。',
                                                GREATEST(v_due_in,0), v_owed, v_acc.loan_principal, v_int)
                    WHEN 'grace'    THEN format('你的抵押贷已逾期 %s 天，应还 %s NB币。还有 %s 天宽限，逾期满 3 天将自动从存款和余额中扣除。',
                                                v_od, v_owed, GREATEST(3 - v_od, 0))
                    ELSE                 format('你的抵押贷已逾期 %s 天，应还 %s NB币，即将被强制扣款。',
                                                v_od, v_owed)
                END);
        END IF;
    END IF;

    -- ---------------- 信用贷 ----------------
    IF v_acc.loan_credit > 0 AND v_acc.loan_credit_until IS NOT NULL THEN
        v_due_in := CEIL(EXTRACT(EPOCH FROM (v_acc.loan_credit_until - now())) / 86400)::int;
        v_od     := GREATEST(-v_due_in, 0);

        IF v_due_in <= v_ahead THEN
            DECLARE v_start2 timestamptz; v_days2 integer; v_rate numeric;
            BEGIN
                SELECT created_at INTO v_start2 FROM public.bank_logs
                 WHERE user_id = p_user_id AND type = 'loan_credit'
                 ORDER BY id DESC LIMIT 1;
                v_days2 := GREATEST(CEIL(EXTRACT(EPOCH FROM (now() - COALESCE(v_start2, now() - interval '1 day'))) / 86400), 1);
                v_rate := CASE WHEN v_acc.credit_score >= 800 THEN 0.108 ELSE 0.12 END;
                v_int := floor(v_acc.loan_credit * v_rate * v_days2 / 30);
            END;
            v_owed := v_acc.loan_credit + v_int;

            IF v_od <= 0 THEN
                v_st := 'upcoming';
            ELSIF v_od < 3 THEN
                v_st := 'grace';
            ELSE
                v_st := 'overdue';
            END IF;

            v_items := v_items || jsonb_build_object(
                'kind', '信用贷',
                'status', v_st,
                'principal', v_acc.loan_credit,
                'interest', v_int,
                'owed', v_owed,
                'due_at', v_acc.loan_credit_until,
                'due_in_days', GREATEST(v_due_in, 0),
                'overdue_days', v_od,
                'days_left', CASE WHEN v_od > 0 THEN GREATEST(3 - v_od, 0) ELSE NULL END,
                'deposit', v_acc.deposit,
                'bal', (SELECT nb_balance FROM public.profiles WHERE id = p_user_id),
                'message', CASE v_st
                    WHEN 'upcoming' THEN format('你的信用贷还有 %s 天到期，应还 %s NB币（本金 %s + 利息 %s）。请提前备好余额。',
                                                GREATEST(v_due_in,0), v_owed, v_acc.loan_credit, v_int)
                    WHEN 'grace'    THEN format('你的信用贷已逾期 %s 天，应还 %s NB币。还有 %s 天宽限，逾期满 3 天将自动从存款和余额中扣除。',
                                                v_od, v_owed, GREATEST(3 - v_od, 0))
                    ELSE                 format('你的信用贷已逾期 %s 天，应还 %s NB币，即将被强制扣款。',
                                                v_od, v_owed)
                END);
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'has_alert', jsonb_array_length(v_items) > 0,
        'alert_days', v_ahead,
        'items', v_items);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_my_loan_alert(uuid) TO anon, authenticated;


-- ============================================================
-- 第三步：验收
-- ============================================================
-- 3.1 现在所有人的贷款提醒状态
SELECT p.username,
       COALESCE(b.loan_principal,0) AS 抵押贷,
       COALESCE(b.loan_credit,0)    AS 信用贷,
       COALESCE(b.loan_until, b.loan_credit_until) AS 到期时间,
       CASE
         WHEN COALESCE(b.loan_until, b.loan_credit_until) IS NULL THEN '无贷款'
         WHEN COALESCE(b.loan_until, b.loan_credit_until) > now() THEN
              '还有 ' || CEIL(EXTRACT(EPOCH FROM (COALESCE(b.loan_until,b.loan_credit_until) - now()))/86400)::int || ' 天到期'
         ELSE '已逾期 ' || GREATEST(CEIL(EXTRACT(EPOCH FROM (now() - COALESCE(b.loan_until,b.loan_credit_until)))/86400)::int,0) || ' 天'
       END AS 状态
  FROM public.bank_accounts b
  JOIN public.profiles p ON p.id = b.user_id
 WHERE COALESCE(b.loan_principal,0) > 0 OR COALESCE(b.loan_credit,0) > 0;

-- 3.2 试调（把 uuid 换成有贷款的号，或换成你自己的看空结果）
-- SELECT public.get_my_loan_alert('22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid);
--   没贷款时应该返回 {"has_alert": false, "alert_days": 3, "items": []}


-- ============================================================
-- 想改提前几天
-- ============================================================
-- UPDATE public.stock_settings SET value = '7' WHERE key = 'loan_alert_days';


-- ============================================================
-- 回滚
-- ============================================================
-- 从 loan_overdue_rules_20261003.sql 里取原来那版 get_my_loan_alert 重跑
