-- ============================================================
-- 第 3 批:后端代理调用的 7 个 RPC 令牌化 + 会话校验接口
-- 背景:后端 app.py 靠 X-User-Id 请求头认人(客户端可随意伪造),
--       它代理调用的这 7 个 RPC 又没有令牌校验
--       → 攻击者填上别人的 ID 就能改头像/发作品/删作品/花别人钱
-- 处理:
--   1) 新增 verify_session(供后端校验前端令牌)
--   2) 包装这 7 个 RPC(加 p_session)
--   3) 前端把 nb_session 通过 X-Session 头传给后端,后端再透传给 RPC
-- ⚠️ 顺序:先让前端+后端上线,再跑本文件
-- ============================================================

-- ---------- 1) 会话校验接口(只给后端用) ----------
CREATE OR REPLACE FUNCTION public.verify_session(p_user_id uuid, p_session text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL OR p_session = '' THEN
        RETURN false;
    END IF;
    RETURN public._user_ok(p_user_id, p_session);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.verify_session(uuid, text) TO anon;

-- ---------- 2) 包装 7 个后端代理 RPC ----------
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
            ('update_avatar_url',  'p_user_id'),
            ('set_profile_banner', 'p_user_id'),
            ('create_product',     'p_user_id'),
            ('edit_product',       'p_user_id'),
            ('delete_product',     'p_user_id'),
            ('download_product',   'p_user_id'),
            ('purchase_product',   'p_buyer_id')
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
            RAISE NOTICE '已加令牌: %(%) 用户参数=%', r.proname, r.args, cfg.userarg;
        END LOOP;
    END LOOP;
    RAISE NOTICE '第3批完成:包装 % 个,跳过 % 个', v_cnt, v_skip;
END $$;

-- ---------- 3) 验收 ----------
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname LIKE '\_orig\_%' OR p.proname = 'verify_session')
 ORDER BY p.proname;

-- verify_session 匿名可调用应为 true(后端要用),其它 _orig_ 应全部不可调用
SELECT p.proname AS 函数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_可调用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '\_orig\_%'
   AND has_function_privilege('anon', p.oid, 'EXECUTE')
 ORDER BY p.proname;
-- 上面这段返回 0 行 = 原始函数已全部禁止匿名调用
