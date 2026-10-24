-- ============================================================
--  银行加固（第二版）—— 自动定位函数，不再靠猜名字
--
--  第一版失败的原因：库里的函数是「鉴权壳 + _orig_ 实体」两层结构，
--  我照着仓库的 sql/bank.sql 猜锚点，找的是壳，壳里没有业务逻辑。
--
--  这一版换个做法：
--    · 不按函数名找，按【函数体里有没有某段代码】找
--    · 正则写得宽松（空白符都用 \s*），只认关键字
--    · 到处都匹配不上时，把实际源码片段放进报错信息里 —— 照着改就行
--
--  要装的四道闸：
--    ① 存款总额上限 10 亿（活期 + 定期一起算）—— 加在扣余额之前
--    ② 抵押贷额度封顶 1 亿
--    ③ 信用贷额度封顶 1 亿
--    ④ 利息基数封顶 10 亿
--    ⑤ 页面上显示的抵押额度也封顶
--
--  只加限制，不改任何人的现有数据。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：先看有没有人已经超了
-- ============================================================
SELECT
    count(*)                                                AS 有存款的账号,
    count(*) FILTER (WHERE deposit > 1000000000)            AS 活期超10亿,
    count(*) FILTER (WHERE fixed7 + fixed30 > 1000000000)   AS 定期超10亿,
    count(*) FILTER (WHERE deposit + fixed7 + fixed30 > 1000000000) AS 合计超10亿,
    round(COALESCE(max(deposit + fixed7 + fixed30), 0), 0)  AS 最大存款合计,
    round(COALESCE(sum(deposit + fixed7 + fixed30), 0), 0)  AS 全站存款合计,
    round(COALESCE(sum(loan_principal + loan_credit), 0), 0) AS 全站未还贷款
  FROM public.bank_accounts;


-- ============================================================
-- 通用改写过程：按「函数体里含某段代码」找函数，再替换
-- 下面六个 DO 块结构一样，只是找的代码和替换的内容不同
-- ============================================================

-- ------------------------------------------------------------
-- ① 活期存款：加总额上限（插在扣余额之前）
-- ------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_src text;
    v_new text;
    v_anchor CONSTANT text :=
        '(UPDATE\s+public\.profiles\s+SET\s+nb_balance\s*=\s*nb_balance\s*-\s*p_amount)';
    v_check CONSTANT text :=
        E'-- ⭐ 单账号存款总额上限 10 亿（活期 + 定期一起算）\n'
     || E'    IF (SELECT COALESCE(deposit,0) + COALESCE(fixed7,0) + COALESCE(fixed30,0)\n'
     || E'          FROM public.bank_accounts WHERE user_id = p_user_id) + p_amount > 1000000000 THEN\n'
     || E'        RETURN jsonb_build_object(''success'', false, ''message'',\n'
     || E'            ''单账号存款总额上限 10 亿 NB币（活期 + 定期一起算）。'');\n'
     || E'    END IF;\n\n    \\1';
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname ILIKE '%bank%'
           AND pg_get_functiondef(p.oid) LIKE '%deposit = deposit + p_amount%'
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%存款总额上限%' THEN
            RAISE NOTICE '% 已经加过了，跳过', r.proname;
            CONTINUE;
        END IF;

        v_new := regexp_replace(v_src, v_anchor, v_check);

        IF v_new = v_src THEN
            RAISE EXCEPTION E'找不到「扣余额」那句，函数名是 %。\n'
                '源码片段（含 nb_balance 的部分）：\n%',
                r.proname,
                substring(v_src from GREATEST(position('nb_balance' in v_src) - 300, 1) for 900);
        END IF;

        EXECUTE v_new;
        v_hit := v_hit + 1;
        RAISE NOTICE '✅ % 已加上活期存款上限', r.proname;
    END LOOP;

    IF v_hit = 0 THEN
        RAISE EXCEPTION '没找到含「deposit = deposit + p_amount」的银行函数，可能函数名不含 bank';
    END IF;
END $$;


-- ------------------------------------------------------------
-- ② 定期存款：加同样的上限（这个函数原来一个限制都没有）
-- ------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_src text;
    v_new text;
    v_anchor CONSTANT text :=
        '(UPDATE\s+public\.profiles\s+SET\s+nb_balance\s*=\s*nb_balance\s*-\s*p_amount)';
    v_check CONSTANT text :=
        E'-- ⭐ 单账号存款总额上限 10 亿（活期 + 定期一起算）\n'
     || E' /* 上限 */'
     || E'    IF (SELECT COALESCE(deposit,0) + COALESCE(fixed7,0) + COALESCE(fixed30,0)\n'
     || E'          FROM public.bank_accounts WHERE user_id = p_user_id) + p_amount > 1000000000 THEN\n'
     || E'        RETURN jsonb_build_object(''success'', false, ''message'',\n'
     || E'            ''单账号存款总额上限 10 亿 NB币（活期 + 定期一起算）。'');\n'
     || E'    END IF;\n\n    \\1';
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname ILIKE '%bank%'
           AND pg_get_functiondef(p.oid) LIKE '%fixed30 = fixed30 + p_amount%'
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%存款总额上限%' THEN
            RAISE NOTICE '% 已经加过了，跳过', r.proname;
            CONTINUE;
        END IF;

        v_new := regexp_replace(v_src, v_anchor, v_check);

        IF v_new = v_src THEN
            RAISE EXCEPTION E'找不到「扣余额」那句，函数名是 %。\n源码片段：\n%',
                r.proname,
                substring(v_src from GREATEST(position('nb_balance' in v_src) - 300, 1) for 900);
        END IF;

        EXECUTE v_new;
        v_hit := v_hit + 1;
        RAISE NOTICE '✅ % 已加上定期存款上限', r.proname;
    END LOOP;

    IF v_hit = 0 THEN
        RAISE EXCEPTION '没找到含「fixed30 = fixed30 + p_amount」的银行函数';
    END IF;
END $$;


-- ------------------------------------------------------------
-- ③ 抵押贷：额度封顶 1 亿（宽松正则，只要形如 floor((...deposit...)*0.8)）
-- ------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_src text;
    v_new text;
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname ILIKE '%bank%'
           AND pg_get_functiondef(p.oid) LIKE '%loan_principal%'
           AND position('0.8' in pg_get_functiondef(p.oid)) > 0
           AND position('collateral_limit' in pg_get_functiondef(p.oid)) = 0  -- 排除显示层
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%绝对上限%' THEN
            RAISE NOTICE '% 已经加过了，跳过', r.proname;
            CONTINUE;
        END IF;

        v_new := regexp_replace(
            v_src,
            'v_limit\s*:=\s*floor\s*\(\s*\(\s*v_acc\.deposit\s*\+\s*v_acc\.fixed7\s*\+\s*v_acc\.fixed30\s*\)\s*\*\s*0\.8\s*\)',
            E'-- ⭐ 存款的 80%，但【绝对上限 1 亿】—— 不看存款有多少\n'
         || E'    v_limit := LEAST(floor((v_acc.deposit + v_acc.fixed7 + v_acc.fixed30) * 0.8),\n'
         || E'                     100000000)');

        IF v_new = v_src THEN
            RAISE EXCEPTION E'找不到抵押额度那句，函数名是 %。\n'
                '源码片段（含 v_limit 的部分）：\n%',
                r.proname,
                substring(v_src from GREATEST(position('v_limit' in v_src) - 300, 1) for 800);
        END IF;

        EXECUTE v_new;
        v_hit := v_hit + 1;
        RAISE NOTICE '✅ % 抵押贷额度已封顶 1 亿', r.proname;
    END LOOP;

    IF v_hit = 0 THEN
        RAISE NOTICE '⚠️ 没找到抵押贷函数（可能名字不含 bank），跳过';
    END IF;
END $$;


-- ------------------------------------------------------------
-- ④ 信用贷：三个档位都封顶 1 亿
-- ------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_src text;
    v_new text;
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname ILIKE '%bank%'
           AND pg_get_functiondef(p.oid) LIKE '%loan_credit%'
           AND position('credit_score *' in pg_get_functiondef(p.oid)) > 0
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%绝对上限%' THEN
            RAISE NOTICE '% 已经加过了，跳过', r.proname;
            CONTINUE;
        END IF;

        v_new := regexp_replace(v_src,
            'v_acc\.credit_score\s*\*\s*(1500|1000|500)',
            E'LEAST(v_acc.credit_score * \\1, 100000000) /* 绝对上限 1 亿 */', 'g');

        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_hit := v_hit + 1;
            RAISE NOTICE '✅ % 信用贷额度已封顶 1 亿', r.proname;
        END IF;
    END LOOP;

    IF v_hit = 0 THEN
        RAISE NOTICE '⚠️ 没有需要改的信用贷函数，跳过';
    END IF;
END $$;


-- ------------------------------------------------------------
-- ⑤ 每日结算：利息基数封顶 10 亿
-- ------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_src text;
    v_new text;
    v_n int := 0;
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname ILIKE '%bank%'
           AND position('v_interest' in pg_get_functiondef(p.oid)) > 0
           AND position('deposit' in pg_get_functiondef(p.oid)) > 0
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%利息基数封顶%' THEN
            RAISE NOTICE '% 已经加过了，跳过', r.proname;
            CONTINUE;
        END IF;

        v_new := v_src;
        v_n := 0;

        -- 活期 0.1%
        v_new := regexp_replace(v_new,
            'floor\s*\(\s*v_acc\.deposit\s*\*\s*0\.001\s*\)',
            E'floor(LEAST(v_acc.deposit, 1000000000) * 0.001) /* 利息基数封顶 10 亿 */');
        IF v_new <> v_src THEN v_n := v_n + 1; END IF;
        v_src := v_new;

        -- 定期 7 天 2%
        v_new := regexp_replace(v_new,
            'floor\s*\(\s*v_acc\.fixed7\s*\*\s*0\.02\s*\)',
            E'floor(LEAST(v_acc.fixed7, 1000000000) * 0.02) /* 利息基数封顶 10 亿 */');
        IF v_new <> v_src THEN v_n := v_n + 1; END IF;
        v_src := v_new;

        -- 定期 30 天 10%
        v_new := regexp_replace(v_new,
            'floor\s*\(\s*v_acc\.fixed30\s*\*\s*0\.10\s*\)',
            E'floor(LEAST(v_acc.fixed30, 1000000000) * 0.10) /* 利息基数封顶 10 亿 */');
        IF v_new <> v_src THEN v_n := v_n + 1; END IF;

        IF v_n = 0 THEN
            RAISE NOTICE '⚠️ % 里没找到计息语句，跳过', r.proname;
            CONTINUE;
        END IF;

        EXECUTE v_new;
        v_hit := v_hit + 1;
        RAISE NOTICE '✅ % 利息基数已封顶（改了 % 处）', r.proname, v_n;
    END LOOP;

    IF v_hit = 0 THEN
        RAISE NOTICE '⚠️ 没有需要改的结算函数，跳过';
    END IF;
END $$;


-- ------------------------------------------------------------
-- ⑥ 账户读取：显示的抵押额度也封顶（这段已经确认过实际写法）
-- ------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_src text;
    v_new text;
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname ILIKE '%bank%'
           AND position('collateral_limit' in pg_get_functiondef(p.oid)) > 0
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%display_cap%' THEN
            RAISE NOTICE '% 已经改过了，跳过', r.proname;
            CONTINUE;
        END IF;

        -- 实际写法已确认：
        --   'collateral_limit', floor((v_acc.deposit + v_acc.fixed7 + v_acc.fixed30) * 0.8),
        v_new := regexp_replace(
            v_src,
            '''collateral_limit''\s*,\s*floor\s*\(\s*\(\s*v_acc\.deposit\s*\+\s*v_acc\.fixed7\s*\+\s*v_acc\.fixed30\s*\)\s*\*\s*0\.8\s*\)',
            E'''collateral_limit'', LEAST(floor((v_acc.deposit + v_acc.fixed7 + v_acc.fixed30) * 0.8),\n'
         || E'                                   100000000)   /* display_cap */');

        IF v_new = v_src THEN
            RAISE NOTICE '⚠️ % 的 collateral_limit 写法不一样，跳过（只是显示值偏大，不影响实际能借多少）', r.proname;
            CONTINUE;
        END IF;

        EXECUTE v_new;
        v_hit := v_hit + 1;
        RAISE NOTICE '✅ % 显示的抵押额度已封顶', r.proname;
    END LOOP;

    IF v_hit = 0 THEN
        RAISE NOTICE '⚠️ 没有需要改的显示函数，跳过';
    END IF;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%存款总额上限%' THEN '✅' ELSE '' END AS 存款上限,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%绝对上限%'     THEN '✅' ELSE '' END AS 贷款封顶,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%利息基数封顶%' THEN '✅' ELSE '' END AS 利息封顶,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%display_cap%'  THEN '✅' ELSE '' END AS 显示封顶
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname ILIKE '%bank%'
 ORDER BY p.proname;


-- ============================================================
--  如果某个 DO 块报错
-- ============================================================
--  它会直接把函数的实际源码片段打印在错误信息里。
--  把那段贴给我，我照着改 —— 不用你手动去查。
--
--  ⚠️ 六个 DO 块是独立的：前面成功了、后面失败也没关系，
--     重跑时已经改过的会被「已经加过了，跳过」挡掉，不会重复加。
-- ============================================================
