-- ============================================================
-- 用户身份 RPC 令牌化(第 2 批:公司/举报/改密码 + 修后台密码暴力破解)
-- ⚠️ 执行顺序:先让前端上线(Ctrl+F5 强刷),再跑本文件
-- ============================================================

-- ---------- 1) 公司 / 举报 / 改密码 这 5 个加令牌 ----------
DO $$
DECLARE
    cfg record;
    r record;
    v_names text;
    v_ok    boolean;
    v_body  text;
    v_sql   text;
    v_cnt   int := 0;
    v_skip  int := 0;
BEGIN
    FOR cfg IN
        SELECT * FROM (VALUES
            ('register_company',            'p_user_id'),
            ('support_company',             'p_user_id'),
            ('apply_company_verification',  'p_user_id'),
            ('report_company',              'p_user_id'),
            ('update_password',             'user_id')
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

            IF r.ret = 'void' THEN
                v_body := format(
                    'BEGIN IF p_session IS NULL OR NOT public._user_ok(%I, p_session) THEN RETURN; END IF; '
                 || 'PERFORM public._orig_%I(%s); RETURN; END',
                    cfg.userarg, r.proname, v_names);
            ELSIF r.ret LIKE 'TABLE(%' OR r.ret LIKE 'SETOF%' THEN
                v_body := format(
                    'BEGIN IF p_session IS NULL OR NOT public._user_ok(%I, p_session) THEN RETURN; END IF; '
                 || 'RETURN QUERY SELECT * FROM public._orig_%I(%s); END',
                    cfg.userarg, r.proname, v_names);
            ELSIF r.ret IN ('jsonb', 'json') THEN
                v_body := format(
                    'BEGIN IF p_session IS NULL OR NOT public._user_ok(%I, p_session) THEN '
                 || 'RETURN (jsonb_build_object(''ok'', false, ''success'', false, ''message'', '
                 || '''鉴权失败:会话无效或无权操作,请重新登录''))::%s; END IF; '
                 || 'RETURN public._orig_%I(%s); END',
                    cfg.userarg, r.ret, r.proname, v_names);
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
            -- 单个函数建失败不影响整批:自动把原名改回去并跳过
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
    RAISE NOTICE '第2批完成:包装 % 个,跳过 % 个', v_cnt, v_skip;
END $$;

-- ---------- 2) 堵住后台密码暴力破解 ----------
-- check_admin_password_plain 只吃一个密码就返回 true/false,且没有次数限制:
-- 攻击者可以无限次猜后台密码(admin_create_session 的 5次/10分钟 限频形同虚设)。
-- 后台页面已改为直接调 admin_create_session(内部校验密码 + 限频),这里把口子关掉。
REVOKE EXECUTE ON FUNCTION public.check_admin_password_plain(text) FROM PUBLIC, anon, authenticated;

-- ---------- 3) 验收 ----------
-- 3.1 已包装的函数一览
SELECT '已加令牌' AS 类别, p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '\_orig\_%'
 UNION ALL
SELECT '密码校验已封锁', p.proname, pg_get_function_arguments(p.oid)
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'check_admin_password_plain'
 ORDER BY 1, 2;

-- 3.2 确认 check_admin_password_plain 匿名不可执行(false = 已封锁)
SELECT has_function_privilege('anon', 'public.check_admin_password_plain(text)', 'EXECUTE') AS anon_可调用;
