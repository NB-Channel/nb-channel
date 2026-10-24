-- ============================================================
-- 只重跑 poll_list 一个函数（修 created_at 缺失）
-- ============================================================
-- 报错：{"message": "column p.created_at does not exist"}
-- 原因：poll_list 外层 jsonb_agg 要按 created_at 排序，
--       但子查询里只 SELECT 了格式化后的 created_text，没带原始列。
-- 这个文件只重建这一个函数，其余的表和数据都不用动。
-- ============================================================

CREATE OR REPLACE FUNCTION public.poll_list(p_user_id uuid DEFAULT NULL, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_uid uuid := NULL;
    v_out jsonb;
BEGIN
    -- 没登录也能看（票数实时公开），只是看不到"我投过没"
    IF p_user_id IS NOT NULL AND p_session IS NOT NULL AND public._user_ok(p_user_id, p_session) THEN
        v_uid := p_user_id;
    END IF;

    SELECT coalesce(jsonb_agg(p ORDER BY p.sort DESC, p.created_at DESC), '[]'::jsonb) INTO v_out
      FROM (
        SELECT po.id, po.slug, po.title, po.description, po.multi, po.closed,
               po.ends_at, po.sort,
               po.created_at,          -- ⚠️ 必须带出来：外层 jsonb_agg 要按它排序

               (po.closed OR (po.ends_at IS NOT NULL AND po.ends_at <= now())) AS is_over,
               to_char(po.ends_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS ends_text,
               -- 给后台的 datetime-local 输入框用，格式必须是 YYYY-MM-DDTHH:MI
               to_char(po.ends_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD"T"HH24:MI') AS ends_local,
               to_char(po.created_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD')      AS created_text,
               (SELECT count(*) FROM public.poll_votes v WHERE v.poll_id = po.id)      AS total,
               (SELECT coalesce(jsonb_agg(o ORDER BY o.idx), '[]'::jsonb) FROM (
                    SELECT op.id, op.idx, op.label,
                           (SELECT count(*) FROM public.poll_votes v2
                             WHERE v2.option_id = op.id) AS votes
                      FROM public.poll_options op WHERE op.poll_id = po.id) o)         AS options,
               CASE WHEN v_uid IS NULL THEN NULL ELSE (
                    SELECT op2.id FROM public.poll_votes v3
                      JOIN public.poll_options op2 ON op2.id = v3.option_id
                     WHERE v3.poll_id = po.id AND v3.user_id = v_uid LIMIT 1) END      AS my_option,
               (v_uid IS NOT NULL AND EXISTS (
                    SELECT 1 FROM public.poll_votes v4
                     WHERE v4.poll_id = po.id AND v4.user_id = v_uid))                 AS voted
          FROM public.polls po) p;

    RETURN jsonb_build_object('success', true, 'list', v_out, 'logged_in', v_uid IS NOT NULL);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;

REVOKE ALL ON FUNCTION public.poll_list(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.poll_list(uuid, text) TO anon;

-- 验收：应该返回 success=true 和投票列表（不再是 column does not exist）
SELECT public.poll_list() AS 结果;
