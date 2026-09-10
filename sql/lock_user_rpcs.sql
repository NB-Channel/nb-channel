-- ============================================================
-- 用户身份 RPC 令牌化(第 1 批:聊天/好友/称号/持仓/通知等 34 个)
-- 原理:原名函数改名为 _orig_xxx 并禁止匿名调用,再建同名包装函数,
--       先校验会话令牌,通过才转交原函数。原函数体一字未改。
-- 自动适配三种返回类型:jsonb / 集合(TABLE) / 标量
-- ⚠️ 执行顺序:先让前端上线(Ctrl+F5 强刷),再跑本文件
-- ============================================================
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
            -- 聊天 / 私信(用户参数)
            ('send_message',                'p_sender'),
            ('get_messages',                'p_user'),
            ('get_unread_messages',         'p_user'),
            ('get_conversations',           'p_user'),
            ('mark_conversation_read',      'p_user'),
            ('recall_message',              'p_user'),
            ('unrecall_message',            'p_user'),
            ('delete_my_message',           'p_user'),
            ('clear_conversation',          'p_user'),
            ('delete_conversation',         'p_user'),
            ('set_conversation_mute',       'p_user'),
            ('get_or_create_conversation',  'p_user_a'),
            -- 好友
            ('send_friend_request',         'p_from'),
            ('respond_friend_request',      'p_user_id'),
            ('remove_friend',               'p_user_id'),
            ('get_friends',                 'p_user_id'),
            ('get_friend_requests',         'p_user_id'),
            -- 称号
            ('buy_title',                   'p_user_id'),
            ('equip_title',                 'p_user_id'),
            ('set_title_slot',              'p_user_id'),
            -- 个人中心 / 持仓 / 签到
            ('visit_profile',               'p_user_id'),
            ('get_checkin_heatmap',         'p_user_id'),
            ('get_active_shop_effects',     'p_user_id'),
            ('record_balance_count',        'p_user_id'),
            ('update_username',             'user_id'),
            ('get_my_holdings',             'p_user_id'),
            ('use_checkin_fix',             'p_user_id'),
            ('get_lottery_today',           'p_user_id'),
            -- 通知
            ('get_my_notifications',        'p_user_id'),
            ('delete_notification',         'p_user_id'),
            ('mark_notification_read',      'p_user_id'),
            ('mark_all_notifications_read', 'p_user_id'),
            ('delete_read_notifications',   'p_user_id'),
            ('get_unread_counts',           'p_user_id')
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
            -- 该函数里必须真有这个"当前用户"参数,否则跳过(不猜、不硬来)
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

            -- 1) 原名让位,并禁止匿名直接调用(否则可绕过校验)
            EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', r.proname, r.ident, '_orig_' || r.proname);
            EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated', '_orig_' || r.proname, r.ident);

            -- 2) 按返回类型生成包装函数体
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

            -- 3) 建同名包装函数
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
            RAISE NOTICE '已加令牌: %(%) 用户参数=% 返回=%', r.proname, r.args, cfg.userarg, r.ret;
        END LOOP;
    END LOOP;
    RAISE NOTICE '完成:包装 % 个,跳过 % 个', v_cnt, v_skip;
END $$;

-- ---------- 验收:列出已包装的函数 ----------
SELECT p.proname AS 已加令牌的函数,
       pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname LIKE '\_orig\_%'
 ORDER BY p.proname;
