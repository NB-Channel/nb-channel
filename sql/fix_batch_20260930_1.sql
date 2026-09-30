-- ============================================================
-- 一批修复 · 第 1 批（2026-09-30）
-- ============================================================
-- 内容：
--   ① 后台「查询 API 日志」超时（canceling statement due to statement timeout）
--   ② 评论区举报限频其实是坏的（依赖的表根本不存在）
--
-- 本文件纯后端改动，跑完不需要刷新页面就能生效。
-- 前端的配套改动已在同一次提交里推上去。
-- ============================================================


-- ============================================================
-- ① 修 API 日志查询超时
-- ============================================================
-- 原因：两个函数都在全表扫。
--   · admin_get_api_logs    : endpoint LIKE '%x%' 前导通配符 → 索引用不上
--   · admin_api_log_summary : count(*) 全表 + 两次全表 GROUP BY
-- 后台每 20 秒批量写一批日志，一个月就是百万行级别，这么扫必然超时。
--
-- 修法：都给一个时间范围（默认最近 7 天），让索引 idx_api_logs_ts 真正生效。
--       汇总也只统计这个范围，并且合并成一次扫描。
--
-- ⚠️ 顺带说：日志该清了。文件末尾附了一句清理（保留 7 天），
--    确认没问题后可以单独跑一下，数据量下来以后这些查询会更快。

CREATE OR REPLACE FUNCTION public.admin_get_api_logs(
    p_token text,
    p_limit int DEFAULT 200,
    p_endpoint text DEFAULT NULL,
    p_ip text DEFAULT NULL,
    p_status int DEFAULT NULL,
    p_days int DEFAULT 7          -- ⭐ 新增：只看最近几天，默认 7
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_rows jsonb;
    v_days int := GREATEST(1, LEAST(COALESCE(p_days, 7), 90));
    v_from timestamptz := now() - make_interval(days => v_days);
    v_ep   text := NULLIF(trim(COALESCE(p_endpoint, '')), '');
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('ok', false, 'message', '无效或过期的管理会话');
    END IF;

    SELECT jsonb_agg(x) INTO v_rows FROM (
        SELECT id,
               to_char(ts AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI:SS') AS ts,
               endpoint, method, ip, status, ua
        FROM public.api_logs
        -- ⭐ 先按时间卡死，让 idx_api_logs_ts 生效（原来没有这一条，等于全表扫）
        WHERE ts >= v_from
          -- ⭐ 端点改用「前缀匹配」：LIKE 'x%' 能走索引，'%x%' 走不了。
          --    后台那个搜索框填的本来就是端点开头，前缀匹配够用。
          AND (v_ep IS NULL OR endpoint LIKE v_ep || '%')
          AND (p_ip IS NULL OR ip = p_ip)
          AND (p_status IS NULL OR status = p_status)
        ORDER BY ts DESC, id DESC
        LIMIT GREATEST(1, LEAST(p_limit, 1000))
    ) x;

    RETURN jsonb_build_object('ok', true, 'rows', COALESCE(v_rows, '[]'::jsonb),
                              'days', v_days);
END $$;

-- 汇总：原来 5 次全表扫描，现在合并成一次「只扫最近 N 天」
CREATE OR REPLACE FUNCTION public.admin_api_log_summary(
    p_token text,
    p_days int DEFAULT 7          -- ⭐ 新增
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_today int; v_429 int; v_total bigint;
    v_ep jsonb; v_ip jsonb; v_last text;
    v_days int := GREATEST(1, LEAST(COALESCE(p_days, 7), 90));
    v_from timestamptz := now() - make_interval(days => v_days);
    v_day_start timestamptz := date_trunc('day', now() AT TIME ZONE 'Asia/Shanghai') AT TIME ZONE 'Asia/Shanghai';
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('ok', false, 'message', '无效或过期的管理会话');
    END IF;

    -- total 也改成只数范围内的，不再数全表
    SELECT count(*),
           count(*) FILTER (WHERE ts >= v_day_start),
           count(*) FILTER (WHERE status = 429),
           to_char(max(ts) AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI:SS')
      INTO v_total, v_today, v_429, v_last
      FROM public.api_logs
     WHERE ts >= v_from;

    SELECT jsonb_agg(x) INTO v_ep FROM (
        SELECT endpoint, count(*) AS n FROM public.api_logs
         WHERE ts >= v_from
         GROUP BY endpoint ORDER BY n DESC LIMIT 12) x;

    SELECT jsonb_agg(x) INTO v_ip FROM (
        SELECT ip, count(*) AS n FROM public.api_logs
         WHERE ts >= v_from AND ip IS NOT NULL
         GROUP BY ip ORDER BY n DESC LIMIT 12) x;

    RETURN jsonb_build_object('ok', true,
        'total', v_total, 'today', v_today, 'rate_limited', v_429,
        'endpoints', COALESCE(v_ep, '[]'::jsonb), 'ips', COALESCE(v_ip, '[]'::jsonb),
        'last', v_last, 'days', v_days);
END $$;

-- 函数签名变了（多了 p_days），旧的要删掉，否则会留下两个重载，
-- PostgREST 可能挑到旧的那个 —— 这个坑之前踩过。
DROP FUNCTION IF EXISTS public.admin_get_api_logs(text, int, text, text, int);
DROP FUNCTION IF EXISTS public.admin_api_log_summary(text);

GRANT EXECUTE ON FUNCTION public.admin_get_api_logs(text, int, text, text, int, int) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_api_log_summary(text, int) TO anon;


-- ============================================================
-- ② 修评论区举报限频
-- ============================================================
-- 现状：前端查 report_attempts 表来数「这个 IP 10 分钟内举报了几次」，
--       但那张表**根本不存在** —— 查询报错被 catch 吞掉了，所以限频一直没生效。
--       而且它数的是前端自己传上来的 IP，伪造一下就能绕过。
--
-- 修法：整条举报链路收进一个 RPC：登录校验 + 限频 + 查重 + 写入，一次原子完成。
--       限频用的 IP 由服务端自己从请求头读（_request_ip），前端伪造不了。

CREATE TABLE IF NOT EXISTS public.report_attempts (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ip_address text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_report_attempts_ip_ts
    ON public.report_attempts (ip_address, created_at DESC);

-- 这张表是内部记账用的，客户端不许直接碰
REVOKE ALL ON public.report_attempts FROM PUBLIC, anon, authenticated;
ALTER TABLE public.report_attempts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.submit_comment_report(
    p_user_id    uuid,
    p_comment_id bigint,
    p_reason     text,
    p_session    text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_ip     text := public._request_ip();
    v_reason text := trim(COALESCE(p_reason, ''));
    v_cnt    int;
BEGIN
    -- ① 必须登录
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'reason', '请先登录再举报');
    END IF;

    -- ② 理由校验（前端也校验了，这里兜底）
    IF v_reason = '' THEN
        RETURN jsonb_build_object('ok', false, 'reason', '请填写举报原因');
    END IF;
    IF length(v_reason) > 100 THEN
        RETURN jsonb_build_object('ok', false, 'reason', '举报原因不能超过100字');
    END IF;

    -- ③ 评论必须存在（防止举报一个不存在的 id）
    IF NOT EXISTS (SELECT 1 FROM public.comments WHERE id = p_comment_id) THEN
        RETURN jsonb_build_object('ok', false, 'reason', '这条评论不存在或已被删除');
    END IF;

    -- ④ 限频：同一个 IP 10 分钟最多 5 次（IP 由服务端读，伪造不了）
    SELECT count(*) INTO v_cnt FROM public.report_attempts
     WHERE ip_address = v_ip AND created_at > now() - interval '10 minutes';
    IF v_cnt >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'reason', '您举报过于频繁，请10分钟后再试');
    END IF;

    -- ⑤ 查重：同一个人对同一条评论只能举报一次
    IF EXISTS (SELECT 1 FROM public.reports
                WHERE comment_id = p_comment_id AND reporter_user_id = p_user_id) THEN
        RETURN jsonb_build_object('ok', false, 'reason', '您已经举报过这条评论了');
    END IF;

    -- ⑥ 记账 + 写入
    INSERT INTO public.report_attempts (ip_address) VALUES (v_ip);

    INSERT INTO public.reports (comment_id, reporter_user_id, reason)
    VALUES (p_comment_id, p_user_id, v_reason);

    -- 顺手清理 1 天前的记账（表一直很小）
    DELETE FROM public.report_attempts WHERE created_at < now() - interval '1 day';

    RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.submit_comment_report(uuid, bigint, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_comment_report(uuid, bigint, text, text) TO anon;

-- 举报现在统一走上面那个 RPC，所以把「直接往 reports 表插」的权限也收掉 ——
-- 否则别人可以绕开限频和查重，直接往表里塞举报。
REVOKE INSERT ON public.reports FROM anon, authenticated;


-- ============================================================
-- 验收
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public'
   AND p.proname IN ('admin_get_api_logs','admin_api_log_summary','submit_comment_report')
   AND p.prokind = 'f'
 ORDER BY 1;
-- 应该是 3 行：前两个带 p_days，第三个带 p_session

SELECT has_table_privilege('anon', 'public.report_attempts', 'SELECT') AS 记账表_匿名可读_应为f;

-- ---------- 可选：清理旧日志（数据量下来，日志页会快很多）----------
-- 确认上面都正常之后，可以跑这一句把 7 天前的日志删掉。
-- 后台的「清理」按钮也是干这事（保留 30 天），这里更狠一点。
-- DELETE FROM public.api_logs WHERE ts < now() - interval '7 days';
