-- ============================================================
--  银行加固：单账号存款上限 + 贷款额度绝对上限
--
--  起因
--    站长问「他钱太多会有什么后果」。查下来全站余额 9.0 × 10¹⁸，
--    其中【前 1 名占 100.0000%】，其余 232 个账号加起来是负数。
--
--    那个余额本身能直接买空全站（全站公司账上才 8.07 亿），
--    但更危险的是【银行】—— 它能把那笔钱放大：
--
--      · bank_deposit（活期）有「今日上限 1000 万/天」✅
--      · bank_fixed_deposit（定期）【一个限制都没有】❌
--            存 9 × 10¹⁸ 进定期 30 天（总利率 10%）
--            → 30 天后凭空多出 9 × 10¹⁷
--      · bank_loan（抵押贷）额度 = 存款 × 0.8
--            → 存 9 × 10¹⁸ 就能借出 7.2 × 10¹⁸
--      · bank_daily_settle 按【全额】计息，没有封顶
--
--  这个脚本加四道闸（站长要求）：
--    ① 单账号存款总额上限 10 亿（活期 + 定期一起算）
--    ② 抵押贷额度加绝对上限 1 亿（不看存款有多少）
--    ③ 利息基数封顶 10 亿 —— 已经存进来的超额部分也不再生息
--    ④ 信用贷也加同样的绝对上限（信誉分要是被刷高，同样会失控）
--
--  ⚠️ 只加限制、不改任何人的现有数据。
--     已经存在的超额存款不会被没收，只是不再产生利息、也借不出更多的钱。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状 —— 有没有人已经超了
-- ============================================================
SELECT
    count(*)                                                       AS 有存款的账号,
    count(*) FILTER (WHERE deposit > 1000000000)                   AS 活期超10亿的,
    count(*) FILTER (WHERE fixed7 + fixed30 > 1000000000)          AS 定期超10亿的,
    count(*) FILTER (WHERE deposit + fixed7 + fixed30 > 1000000000)
                                                                   AS 合计超10亿的,
    round(COALESCE(max(deposit + fixed7 + fixed30), 0), 0)         AS 最大存款合计,
    round(COALESCE(sum(deposit + fixed7 + fixed30), 0), 0)         AS 全站存款合计,
    round(COALESCE(sum(loan_principal + loan_credit), 0), 0)       AS 全站未还贷款
  FROM public.bank_accounts;


-- ============================================================
-- 一、bank_deposit：加单账号存款总额上限
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'bank_deposit'
     LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public.bank_deposit';
    END IF;

    IF v_src LIKE '%存款总额上限%' THEN
        RAISE NOTICE 'bank_deposit 已经加过了，跳过';
        RETURN;
    END IF;

    -- 在「今日活期存款已达上限」那段检查之后插入总额检查
    v_new := regexp_replace(
        v_src,
        '(今日活期存款已达上限（1000万/天）''\);\s*END IF;)',
        E'\\1\n\n    -- ⭐ 单账号存款总额上限 10 亿（活期 + 定期一起算）\n'
        || E'    IF (SELECT COALESCE(deposit,0) + COALESCE(fixed7,0) + COALESCE(fixed30,0)\n'
        || E'          FROM public.bank_accounts WHERE user_id = p_user_id) + p_amount > 1000000000 THEN\n'
        || E'        RETURN jsonb_build_object(''success'', false, ''message'',\n'
        || E'            ''单账号存款总额上限 10 亿 NB币（活期 + 定期一起算）。'');\n'
        || E'    END IF;'
    );

    IF v_new = v_src THEN
        RAISE EXCEPTION 'bank_deposit 没匹配上，别硬改 —— 先把 pg_get_functiondef 的输出贴出来看看';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ bank_deposit 已加上存款总额上限';
END $$;


-- ============================================================
-- 二、bank_fixed_deposit：加同样的上限（这个函数原来一个限制都没有）
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'bank_fixed_deposit'
     LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public.bank_fixed_deposit';
    END IF;

    IF v_src LIKE '%存款总额上限%' THEN
        RAISE NOTICE 'bank_fixed_deposit 已经加过了，跳过';
        RETURN;
    END IF;

    -- 插在「余额不足」检查之后
    v_new := regexp_replace(
        v_src,
        '(''NB币余额不足''\);\s*END IF;)',
        E'\\1\n\n    -- ⭐ 单账号存款总额上限 10 亿（活期 + 定期一起算）\n'
        || E'    --    这个函数原来【一个额度限制都没有】，是全站最大的一个口子\n'
        || E'    IF (SELECT COALESCE(deposit,0) + COALESCE(fixed7,0) + COALESCE(fixed30,0)\n'
        || E'          FROM public.bank_accounts WHERE user_id = p_user_id) + p_amount > 1000000000 THEN\n'
        || E'        RETURN jsonb_build_object(''success'', false, ''message'',\n'
        || E'            ''单账号存款总额上限 10 亿 NB币（活期 + 定期一起算）。'');\n'
        || E'    END IF;',
        'g'          -- 两个函数里都有这句，只取第一个即可（bank_fixed_deposit 里就一处）
    );

    IF v_new = v_src THEN
        RAISE EXCEPTION 'bank_fixed_deposit 没匹配上，别硬改';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ bank_fixed_deposit 已加上存款总额上限';
END $$;


-- ============================================================
-- 三、bank_loan：抵押贷额度加绝对上限 1 亿
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'bank_loan'
     LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public.bank_loan';
    END IF;

    IF v_src LIKE '%绝对上限%' THEN
        RAISE NOTICE 'bank_loan 已经加过了，跳过';
        RETURN;
    END IF;

    v_new := regexp_replace(
        v_src,
        'v_limit\s*:=\s*floor\(\(v_acc\.deposit\s*\+\s*v_acc\.fixed7\s*\+\s*v_acc\.fixed30\)\s*\*\s*0\.8\)',
        E'-- ⭐ 存款的 80%，但【绝对上限 1 亿】—— 不看存款有多少\n'
        || E'    v_limit := LEAST(floor((v_acc.deposit + v_acc.fixed7 + v_acc.fixed30) * 0.8),\n'
        || E'                     100000000)'
    );

    IF v_new = v_src THEN
        RAISE EXCEPTION 'bank_loan 没匹配上，别硬改';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ bank_loan 抵押贷额度已封顶 1 亿';
END $$;


-- ============================================================
-- 四、bank_credit_loan：信用贷也封顶（信誉分要是被刷高，同样失控）
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
    v_n   int := 0;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'bank_credit_loan'
     LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public.bank_credit_loan';
    END IF;

    IF v_src LIKE '%绝对上限%' THEN
        RAISE NOTICE 'bank_credit_loan 已经加过了，跳过';
        RETURN;
    END IF;

    v_new := regexp_replace(
        v_src,
        'v_limit\s*:=\s*v_acc\.credit_score\s*\*\s*1500',
        'v_limit := LEAST(v_acc.credit_score * 1500, 100000000)   -- ⭐ 绝对上限 1 亿',
        'g');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    v_new := regexp_replace(
        v_src,
        'v_limit\s*:=\s*v_acc\.credit_score\s*\*\s*1000',
        'v_limit := LEAST(v_acc.credit_score * 1000, 100000000)   -- ⭐ 绝对上限 1 亿',
        'g');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    v_new := regexp_replace(
        v_src,
        'v_limit\s*:=\s*v_acc\.credit_score\s*\*\s*500',
        'v_limit := LEAST(v_acc.credit_score * 500, 100000000)    -- ⭐ 绝对上限 1 亿',
        'g');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;

    IF v_n = 0 THEN
        RAISE EXCEPTION 'bank_credit_loan 没匹配上，别硬改';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ bank_credit_loan 信用贷额度已封顶 1 亿（改了 % 处）', v_n;
END $$;


-- ============================================================
-- 五、bank_daily_settle：利息基数封顶 10 亿
--     —— 已经存进来的超额部分也不再生息
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
    v_n   int := 0;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'bank_daily_settle'
     LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public.bank_daily_settle';
    END IF;

    IF v_src LIKE '%利息基数%' THEN
        RAISE NOTICE 'bank_daily_settle 已经加过了，跳过';
        RETURN;
    END IF;

    -- 活期 0.1%/天
    v_new := regexp_replace(
        v_src,
        'v_interest\s*:=\s*floor\(v_acc\.deposit\s*\*\s*0\.001\)',
        E'v_interest := floor(LEAST(v_acc.deposit, 1000000000) * 0.001);  -- ⭐ 利息基数封顶 10 亿');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    -- 定期 7 天
    v_new := regexp_replace(
        v_src,
        'v_interest\s*:=\s*floor\(v_acc\.fixed7\s*\*\s*0\.02\)',
        E'v_interest := floor(LEAST(v_acc.fixed7, 1000000000) * 0.02);    -- ⭐ 利息基数封顶 10 亿');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    -- 定期 30 天
    v_new := regexp_replace(
        v_src,
        'v_interest\s*:=\s*floor\(v_acc\.fixed30\s*\*\s*0\.10\)',
        E'v_interest := floor(LEAST(v_acc.fixed30, 1000000000) * 0.10);   -- ⭐ 利息基数封顶 10 亿');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;

    IF v_n = 0 THEN
        RAISE EXCEPTION 'bank_daily_settle 没匹配上，别硬改';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ bank_daily_settle 利息基数已封顶（改了 % 处）', v_n;
END $$;


-- ============================================================
-- 六、get_bank_account：把抵押额度也封顶（页面上显示的数要和实际一致）
-- ============================================================
DO $$
DECLARE
    v_src text;
    v_new text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'get_bank_account'
     LIMIT 1;

    IF v_src IS NULL THEN
        RAISE NOTICE '⚠️ 找不到 get_bank_account，跳过（不影响主流程）';
        RETURN;
    END IF;

    IF v_src LIKE '%存款总额上限%' THEN
        RAISE NOTICE 'get_bank_account 已经改过了，跳过';
        RETURN;
    END IF;

    -- 抵押额度显示也要封顶，否则页面会显示一个根本借不出来的数
    v_new := regexp_replace(
        v_src,
        '''collateral_limit''\s*,\s*floor\(\(v_acc\.deposit\s*\+\s*v_acc\.fixed7\s*\+\s*v_acc\.fixed30\)\s*\*\s*0\.8\)',
        E'''collateral_limit'', LEAST(floor((v_acc.deposit + v_acc.fixed7 + v_acc.fixed30) * 0.8),\n'
        || E'                                   100000000)');
    v_src := v_new;

    -- 顺便把上限也返回给前端，方便页面提示
    v_new := regexp_replace(
        v_src,
        '(''credit_rate''\s*,\s*v_credit_rate)',
        E'\\1,\n        ''deposit_cap'', 1000000000,\n        ''loan_cap'', 100000000');

    IF v_new = v_src THEN
        RAISE NOTICE '⚠️ get_bank_account 没匹配上，跳过（不影响主流程，只是页面显示的额度可能偏大）';
        RETURN;
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ get_bank_account 也改了（抵押额度封顶 + 返回两个上限给前端）';
END $$;


-- ============================================================
-- 七、验证：四道闸都装上了没
-- ============================================================
SELECT
    p.proname AS 函数,
    CASE
      WHEN p.proname = 'bank_deposit'
        THEN CASE WHEN pg_get_functiondef(p.oid) LIKE '%存款总额上限%'
                  THEN '✅ 存款总额上限 10 亿' ELSE '❌ 没加上' END
      WHEN p.proname = 'bank_fixed_deposit'
        THEN CASE WHEN pg_get_functiondef(p.oid) LIKE '%存款总额上限%'
                  THEN '✅ 存款总额上限 10 亿' ELSE '❌ 没加上' END
      WHEN p.proname = 'bank_loan'
        THEN CASE WHEN pg_get_functiondef(p.oid) LIKE '%绝对上限%'
                  THEN '✅ 抵押贷封顶 1 亿' ELSE '❌ 没加上' END
      WHEN p.proname = 'bank_credit_loan'
        THEN CASE WHEN pg_get_functiondef(p.oid) LIKE '%绝对上限%'
                  THEN '✅ 信用贷封顶 1 亿' ELSE '❌ 没加上' END
      WHEN p.proname = 'bank_daily_settle'
        THEN CASE WHEN pg_get_functiondef(p.oid) LIKE '%利息基数封顶%'
                  THEN '✅ 利息基数封顶 10 亿' ELSE '❌ 没加上' END
      ELSE '—'
    END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('bank_deposit','bank_fixed_deposit','bank_loan',
                     'bank_credit_loan','bank_daily_settle')
 ORDER BY p.proname;


-- ============================================================
-- 八、顺手确认定时任务还挂着（利息结算是它跑的）
-- ============================================================
SELECT jobid, schedule, command, active
  FROM cron.job
 WHERE command ILIKE '%bank_daily_settle%';


-- ============================================================
--  这次没做的事（供参考）
-- ============================================================
--  · 【没有】去动那个 9 × 10¹⁸ 的余额本身 —— 只加闸，不改数据。
--    那笔钱怎么处理站长还在想（余额税 / 一次性修正 / 不动）。
--
--  · 【没有】给买卖股票加每日额度 —— 之前加过一版但从没部署。
--    那个余额真要砸进市场，靠额度挡不住（他能开很多小号）。
--    真正该处理的是那笔余额本身。
-- ============================================================
