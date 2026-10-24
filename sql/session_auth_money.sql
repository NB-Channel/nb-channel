-- ============================================================
-- 堵住「拿别人 user_id 就能动别人钱」的口子(股票 + 银行)
-- 现状:下面这些函数只吃 p_user_id,没有任何会话校验 —— user_id 在评论区/好友列表
--       就能看到,任何人拿别人的 id 就能用别人的 NB币买卖股票、存取款、贷款。
--       其余写操作 RPC 早已加令牌,只剩这两类漏网。
--       本文件给它们套上和其它函数一样的 _user_ok 包装。
-- ⚠️ 前端已同步改成传 p_session(股票页和银行页都带兼容回退),
--    执行本文件后 Ctrl+F5 强刷即可。
-- 在 Supabase SQL Editor 执行
-- ============================================================

DO $$
DECLARE
    cfg    record;
    r      record;
    v_names text;
    v_ok    boolean;
    v_body  text;
    v_sql   text;
    v_cnt   int := 0;
    v_skip  int := 0;
BEGIN
    FOR cfg IN
        SELECT * FROM (VALUES
            ('buy_stock',            'p_user_id'),
            ('sell_stock',           'p_user_id'),
            ('get_bank_account',     'p_user_id'),
            ('bank_deposit',         'p_user_id'),
            ('bank_withdraw',        'p_user_id'),
            ('bank_fixed_deposit',   'p_user_id'),
            ('bank_fixed_withdraw',  'p_user_id'),
            ('bank_loan',            'p_user_id'),
            ('bank_credit_loan',     'p_user_id'),
            ('bank_repay',           'p_user_id'),
            ('bank_repay_credit',    'p_user_id')
        ) AS t(fn, userarg)
    LOOP
        FOR r IN
            SELECT p.proname,
                   pg_get_function_arguments(p.oid)          AS args,
                   pg_get_function_identity_arguments(p.oid) AS ident,
                   pg_get_function_result(p.oid)             AS ret
              FROM pg_proc p
              JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public'
               AND p.proname = cfg.fn
               AND NOT EXISTS (
                   SELECT 1 FROM pg_proc p2
                     JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
                    WHERE n2.nspname = 'public' AND p2.proname = '_orig_' || p.proname)
        LOOP
            SELECT count(*) > 0 INTO v_ok
              FROM unnest(string_to_array(r.args, ',')) AS x
             WHERE split_part(trim(x), ' ', 1) = cfg.userarg;
            IF NOT v_ok THEN
                RAISE NOTICE '跳过 % : 参数里找不到 %', r.proname, cfg.userarg;
                v_skip := v_skip + 1;
                CONTINUE;
            END IF;

            SELECT string_agg(split_part(trim(x), ' ', 1), ', ')
              INTO v_names
              FROM unnest(string_to_array(r.args, ',')) AS x
             WHERE trim(x) <> '';

            EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', r.proname, r.ident, '_orig_' || r.proname);
            EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated', '_orig_' || r.proname, r.ident);

            IF r.ret IN ('jsonb', 'json') THEN
                v_body := format(
                    'BEGIN IF p_session IS NULL OR NOT public._user_ok(%I, p_session) THEN '
                 || 'RETURN (jsonb_build_object(''ok'', false, ''success'', false, ''message'', '
                 || '''鉴权失败:会话无效或无权操作,请重新登录''))::%s; END IF; '
                 || 'RETURN public._orig_%I(%s); END',
                    cfg.userarg, r.ret, r.proname, v_names);
            ELSIF r.ret = 'void' THEN
                v_body := format(
                    'BEGIN IF p_session IS NULL OR NOT public._user_ok(%I, p_session) THEN RETURN; END IF; '
                 || 'PERFORM public._orig_%I(%s); RETURN; END',
                    cfg.userarg, r.proname, v_names);
            ELSE
                v_body := format(
                    'BEGIN IF p_session IS NULL OR NOT public._user_ok(%I, p_session) THEN RETURN NULL; END IF; '
                 || 'RETURN public._orig_%I(%s); END',
                    cfg.userarg, r.proname, v_names);
            END IF;

            v_sql := format(
                'CREATE FUNCTION public.%I(%s, p_session text DEFAULT NULL) RETURNS %s '
             || 'LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $w$ %s $w$',
                r.proname, r.args, r.ret, v_body);
            BEGIN
                EXECUTE v_sql;
                EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s, text) TO anon', r.proname, r.ident);
            EXCEPTION WHEN OTHERS THEN
                BEGIN
                    EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', '_orig_' || r.proname, r.ident, r.proname);
                EXCEPTION WHEN OTHERS THEN
                    NULL;
                END;
                RAISE NOTICE '跳过 %(返回类型 %): %', r.proname, r.ret, SQLERRM;
                v_skip := v_skip + 1;
                CONTINUE;
            END;

            v_cnt := v_cnt + 1;
            RAISE NOTICE '已加令牌: %(%)', r.proname, r.args;
        END LOOP;
    END LOOP;
    RAISE NOTICE '股票+银行令牌化完成:包装 % 个,跳过 % 个', v_cnt, v_skip;
END $$;

-- ---------- 验收 ----------
-- 1) 包装后的签名(应能看到 p_session text DEFAULT NULL)
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('buy_stock','sell_stock','get_bank_account','bank_deposit','bank_withdraw',
                     'bank_fixed_deposit','bank_fixed_withdraw','bank_loan','bank_credit_loan',
                     'bank_repay','bank_repay_credit')
 ORDER BY 1;

-- 2) 未带令牌时应当被挡下(返回 JSON 里含「鉴权失败」)
SELECT public.buy_stock('00000000-0000-0000-0000-000000000000'::uuid, 1, 100) AS 未带令牌买入,
       public.sell_stock('00000000-0000-0000-0000-000000000000'::uuid, 1, 100) AS 未带令牌卖出,
       public.bank_withdraw('00000000-0000-0000-0000-000000000000'::uuid, 100) AS 未带令牌取款;
