-- ============================================================
-- 最后一批收口:
--   ① 市值快照改成服务端计算(前端不能再决定市值数字)
--   ② 评论 4 个 RPC 加会话令牌(不能再用别人的 ID 冒充发言)
--   ③ 8 张还能被匿名写的表全部锁死
-- ⚠️ 执行顺序:先让前端上线(Ctrl+F5 强刷),再跑本文件
--    因为评论 RPC 加令牌后,旧页面的调用会被拒绝
-- ============================================================

-- ---------- ① 市值快照:服务端自己 SUM,前端只能触发 ----------
CREATE OR REPLACE FUNCTION public.publish_stock_snapshot()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_total numeric;
    v_names jsonb;
    v_vals  jsonb;
    v_snap  jsonb;
    v_last  timestamptz;
BEGIN
    -- 市值一律由数据库计算,不信任任何前端提交的数字
    SELECT coalesce(sum(market_value), 0),
           coalesce(jsonb_agg(company_name ORDER BY market_value DESC), '[]'::jsonb),
           coalesce(jsonb_agg(market_value ORDER BY market_value DESC), '[]'::jsonb)
      INTO v_total, v_names, v_vals
      FROM public.user_companies;

    v_snap := jsonb_build_object('names', v_names, 'values', v_vals);

    -- 服务端节流:3 秒内不重复写最新快照
    SELECT max(created_at) INTO v_last FROM public.stock_latest;
    IF v_last IS NOT NULL AND v_last > now() - interval '3 seconds' THEN
        RETURN jsonb_build_object('ok', true, 'skipped', true, 'total_value', v_total);
    END IF;

    DELETE FROM public.stock_latest;
    INSERT INTO public.stock_latest (created_at, total_value, snapshot_data)
    VALUES (now(), v_total, v_snap);

    -- 历史快照:60 秒一条
    IF NOT EXISTS (SELECT 1 FROM public.stock_history_full WHERE recorded_at > now() - interval '60 seconds') THEN
        INSERT INTO public.stock_history_full (recorded_at, total_value, snapshot)
        VALUES (now(), v_total, v_snap);
        INSERT INTO public.stock_history (total_value) VALUES (v_total);
        BEGIN
            PERFORM public.record_daily_kline();
        EXCEPTION WHEN OTHERS THEN
            NULL;   -- 日K线聚合失败不影响主流程
        END;
    END IF;

    RETURN jsonb_build_object('ok', true, 'total_value', v_total);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.publish_stock_snapshot() TO anon;

-- ---------- ② 评论 4 个 RPC 加会话令牌(自动包装,不猜参数类型) ----------
DO $$
DECLARE
    r record;
    v_names text;
    v_sql   text;
BEGIN
    FOR r IN
        SELECT p.proname,
               pg_get_function_arguments(p.oid)          AS args,
               pg_get_function_identity_arguments(p.oid) AS ident,
               pg_get_function_result(p.oid)             AS ret
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('insert_comment', 'update_comment',
                             'delete_comment_cascade', 'toggle_comment_reaction')
           -- 幂等:已经包装过就跳过
           AND NOT EXISTS (
               SELECT 1 FROM pg_proc p2
                 JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
                WHERE n2.nspname = 'public' AND p2.proname = '_orig_' || p.proname)
    LOOP
        -- 取参数名列表(如 p_page_path, p_user_id, ...)
        SELECT string_agg(split_part(trim(x), ' ', 1), ', ')
          INTO v_names
          FROM unnest(string_to_array(r.args, ',')) AS x
         WHERE trim(x) <> '';

        -- 原名改成 _orig_xxx,并禁止匿名直接调用(否则可绕过令牌校验)
        EXECUTE format('ALTER FUNCTION public.%I(%s) RENAME TO %I', r.proname, r.ident, '_orig_' || r.proname);
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated', '_orig_' || r.proname, r.ident);

        -- 建同名包装函数:先校验令牌,再转交原函数
        v_sql := format(
            'CREATE FUNCTION public.%I(%s, p_session text DEFAULT NULL) RETURNS %s '
         || 'LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $w$ '
         || 'BEGIN '
         || 'IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN '
         || '  RETURN jsonb_build_object(''success'', false, ''message'', ''鉴权失败:会话无效或无权操作,请重新登录''); '
         || 'END IF; '
         || 'RETURN public._orig_%I(%s); '
         || 'END $w$',
            r.proname, r.args, r.ret, r.proname, v_names);
        EXECUTE v_sql;
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s, text) TO anon', r.proname, r.ident);

        RAISE NOTICE '已加令牌: %(%)', r.proname, r.args;
    END LOOP;
END $$;

-- ---------- ③ 最后 8 张表:匿名写权限全部收回 ----------
-- bad_words              : 敏感词库,被改=脏话过滤失效
-- registration_attempts  : 被改=抹掉攻击者 IP 痕迹/伪造记录陷害他人
-- user_checkins          : 被改=刷签到奖励
-- verified_users_backup  : 蓝标备份表,历史遗留
-- stock_history/_full/latest : 被改=直接操纵市值与K线
-- comments               : 被改=不登录伪造他人发言(写入已全部改走 RPC)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.bad_words             FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.registration_attempts FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.user_checkins         FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.verified_users_backup FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.stock_history         FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.stock_history_full    FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.stock_latest          FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.comments              FROM anon, authenticated;

-- ---------- ④ 验收:增/改/删三列应全部 false ----------
SELECT c.relname AS 表名,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'SELECT') AS 读,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'INSERT') AS 增,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'UPDATE') AS 改,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'DELETE') AS 删
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
   AND (has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'INSERT')
     OR has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'UPDATE')
     OR has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'DELETE'))
 ORDER BY c.relname;
-- 上面查询返回 0 行 = 全部收口完成
