-- ============================================================
-- 兑换失败留痕（2026-09-30）
-- ============================================================
-- 问题：兑换失败【不留任何痕迹】。
--       submit_u_exchange 只在成功入账时写记录，验签失败 / 额度不足 /
--       码已用过这些情况都是提前 RETURN 掉的，事后完全查不到。
--       结果就是「用户说换不了，但后台看不出任何异常」。
--
-- 做法：不改原函数的逻辑，而是把它【包一层】——
--       原函数改名保留，新函数同名，调用完看一眼结果，
--       失败就把原因记下来，然后原样返回。
--
--       好处是不用重写那 100 多行、不会碰到扣款和入账那段核心逻辑。
-- ============================================================


-- ============================================================
-- ① 失败记录表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.exchange_fail_logs (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    uuid,
    username   text,          -- 留档，用户改名后还能对上号
    u_code     text,          -- 只存前 40 位，够定位就行
    u_amount   numeric,       -- 用户界面上填的数量
    reason     text NOT NULL, -- 服务端返回的失败原因
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ex_fail_ts ON public.exchange_fail_logs (created_at DESC);

-- 内部记账表，客户端一律不许碰
REVOKE ALL ON public.exchange_fail_logs FROM PUBLIC, anon, authenticated;
ALTER TABLE public.exchange_fail_logs ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- ② 把原函数改名（保留，逻辑一行不动）
-- ============================================================
ALTER FUNCTION public.submit_u_exchange(uuid, text, numeric, text)
    RENAME TO _submit_u_exchange_orig;

-- ⚠️ 改名之后权限是跟着函数走的 —— 原函数此刻对 anon 还是可执行，
--    别人可以绕过下面的包装直接调它。必须把口子关上。
REVOKE ALL ON FUNCTION public._submit_u_exchange_orig(uuid, text, numeric, text)
    FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ③ 同名包装：跑原逻辑，失败就留痕
-- ============================================================
CREATE OR REPLACE FUNCTION public.submit_u_exchange(
    p_user_id uuid, p_u_code text, p_u_amount numeric DEFAULT NULL, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_ret    jsonb;
    v_reason text;
BEGIN
    v_ret := public._submit_u_exchange_orig(p_user_id, p_u_code, p_u_amount, p_session);

    -- 只在失败时记一笔。成功的那些本来就写进 u_exchange_requests 了。
    IF v_ret IS NULL OR (v_ret ->> 'success') IS DISTINCT FROM 'true' THEN
        v_reason := coalesce(nullif(v_ret ->> 'message', ''), '未知错误');
        BEGIN
            INSERT INTO public.exchange_fail_logs (user_id, username, u_code, u_amount, reason)
            SELECT p_user_id,
                   (SELECT username FROM public.profiles WHERE id = p_user_id),
                   left(coalesce(p_u_code, ''), 40),
                   p_u_amount,
                   left(v_reason, 200);
        EXCEPTION WHEN OTHERS THEN
            -- 留痕失败绝不能影响主流程
            NULL;
        END;
    END IF;

    RETURN v_ret;
EXCEPTION WHEN OTHERS THEN
    -- 原函数自己炸了也要留痕，并把错误原样返回
    BEGIN
        INSERT INTO public.exchange_fail_logs (user_id, username, u_code, u_amount, reason)
        VALUES (p_user_id,
                (SELECT username FROM public.profiles WHERE id = p_user_id),
                left(coalesce(p_u_code, ''), 40), p_u_amount,
                left('内部错误: ' || SQLERRM, 200));
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN coalesce(v_ret, jsonb_build_object('success', false, 'message', SQLERRM));
END
$fn$;
REVOKE ALL ON FUNCTION public.submit_u_exchange(uuid, text, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_u_exchange(uuid, text, numeric, text) TO anon;


-- ============================================================
-- ④ 后台查看
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_list_exchange_fails(
    p_token  text,
    p_days   integer DEFAULT 7,
    p_limit  integer DEFAULT 100,
    p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_days int := greatest(1, least(coalesce(p_days, 7), 90));
    v_lim  int := greatest(1, least(coalesce(p_limit, 100), 300));
    v_off  int := greatest(0, coalesce(p_offset, 0));
    v_list jsonb;
    v_total int;
    v_top  jsonb;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;

    SELECT count(*) INTO v_total
      FROM public.exchange_fail_logs
     WHERE created_at >= now() - (v_days || ' days')::interval;

    -- 原因 TOP：一眼看出最近主要是哪类失败
    SELECT coalesce(jsonb_agg(x), '[]'::jsonb) INTO v_top FROM (
        SELECT reason, count(*) AS n
          FROM public.exchange_fail_logs
         WHERE created_at >= now() - (v_days || ' days')::interval
         GROUP BY reason ORDER BY n DESC LIMIT 8) x;

    SELECT coalesce(jsonb_agg(y ORDER BY y.created_at DESC), '[]'::jsonb) INTO v_list FROM (
        SELECT id, username, user_id, u_code, u_amount, reason,
               to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI:SS') AS created_at
          FROM public.exchange_fail_logs
         WHERE created_at >= now() - (v_days || ' days')::interval
         ORDER BY created_at DESC
         LIMIT v_lim OFFSET v_off) y;

    RETURN jsonb_build_object('success', true, 'total', v_total,
                              'top', v_top, 'list', v_list, 'days', v_days);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_list_exchange_fails(text, integer, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_exchange_fails(text, integer, integer, integer) TO anon;


-- ============================================================
-- ⑤ 清理（可挂在定时任务里，或手动跑）
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_purge_exchange_fails(
    p_token text, p_keep_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_n    bigint;
    v_keep int := greatest(1, least(coalesce(p_keep_days, 30), 365));
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;

    DELETE FROM public.exchange_fail_logs
     WHERE created_at < now() - make_interval(days => v_keep);
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN jsonb_build_object('success', true, 'deleted', v_n, 'keep_days', v_keep);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_purge_exchange_fails(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_purge_exchange_fails(text, integer) TO anon;


-- ============================================================
-- 验收
-- ============================================================
-- 原函数改名了吗、包装在不在
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public'
   AND p.proname IN ('submit_u_exchange','_submit_u_exchange_orig',
                     'admin_list_exchange_fails','admin_purge_exchange_fails')
   AND p.prokind = 'f'
 ORDER BY 1;
-- 应该 4 行

-- 关键：原函数改名后 anon 不该还能直接调它（否则能绕过包装）
SELECT has_function_privilege('anon',
       'public._submit_u_exchange_orig(uuid,text,numeric,text)', 'EXECUTE')
       AS 原函数_匿名可调_应为f;

-- 失败记录表建好了、而且匿名读不到
SELECT has_table_privilege('anon', 'public.exchange_fail_logs', 'SELECT')
       AS 失败表_匿名可读_应为f;

-- 表结构
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'exchange_fail_logs'
 ORDER BY ordinal_position;
