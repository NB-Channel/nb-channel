-- ============================================================
-- 修「后台数据匿名可读」漏洞（2026-09-28）
-- ============================================================
-- 有人反馈：把 Website backend.html 下载下来、部署到自己的 pages.dev，
--           就能看到后台的举报列表 / 公司认证申请。
--           只能看、不能操作（写操作要 token，被拒了）。
--
-- 根因：
--   后台前端是「纯网页 + 公开 anon key」，而它读举报列表用的是
--   PostgREST 的嵌套查询，直连数据库查表：
--       supabaseClient.from('reports').select(`comments!inner(...)`)
--   既然 anon 要能查，那 reports 表就必须对所有人开放 ——
--   于是任何人拿网页里写死的那把公开 key 都能读。
--
--   实测确认 reports 表当时是「所有列匿名可读」，里面装着
--   谁举报了谁(reporter_user_id)、举报原因、被举报的评论/公司/作品。
--
-- 修法：
--   1) 新增两个带管理员 token 校验的 RPC，返回和原来一模一样的嵌套结构
--      → 后台前端改成调 RPC，不再直连查表
--   2) 前端上线后，把 reports / api_logs 的匿名读权限撤掉
--
-- ⚠️ 分两步跑，顺序不能反：
--      第一步（下方 SECTION 1）现在就能跑，纯新增，不影响任何现有功能
--      第二步（下方 SECTION 2）必须等新前端推送上去、确认后台正常之后再跑
--      跑早了后台就会当场读不到数据（但随时可以用 GRANT 撤回来）。
-- ============================================================


-- ============================================================
-- SECTION 1 · 现在就跑：新增两个 RPC
-- ============================================================

-- ------------------------------------------------------------
-- 1.1 举报列表（评论 / 公司 / 作品三种都用它）
-- ------------------------------------------------------------
-- 返回结构与原来 PostgREST 嵌套查询保持一致，前端只需把
--   from('reports').select(`...`)  →  rpc('admin_list_reports', {...})
-- 然后取 res.list / res.total。
CREATE OR REPLACE FUNCTION public.admin_list_reports(
    p_token       text,
    p_target_type text,
    p_date_from   timestamptz DEFAULT NULL,
    p_limit       integer DEFAULT 50,
    p_offset      integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_type   text := nullif(trim(coalesce(p_target_type, '')), '');
    v_limit  int  := least(greatest(coalesce(p_limit, 50), 1), 200);
    v_offset int  := greatest(coalesce(p_offset, 0), 0);
    v_total  int;
    v_list   jsonb;
BEGIN
    -- 没 token 就什么都看不到 —— 这正是这次要补的那道门
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '管理员会话无效或已过期,请重新登录');
    END IF;
    IF v_type IS NULL OR v_type NOT IN ('comment', 'company', 'product') THEN
        RETURN jsonb_build_object('success', false, 'message', 'target_type 只能是 comment / company / product');
    END IF;

    SELECT count(*) INTO v_total
      FROM public.reports r
     WHERE r.target_type = v_type
       AND (p_date_from IS NULL OR r.created_at >= p_date_from);

    SELECT coalesce(jsonb_agg(x ORDER BY x.created_at DESC), '[]'::jsonb)
      INTO v_list
      FROM (
        SELECT
            r.id,
            r.reason,
            r.created_at,
            r.comment_id,
            r.company_id,
            r.product_id,
            jsonb_build_object('username', coalesce(rp.username, '未知')) AS reporter,
            -- 评论举报：带上被举报评论的正文和作者
            CASE WHEN r.comment_id IS NULL THEN NULL ELSE (
                SELECT jsonb_build_object(
                           'id', c.id,
                           'content', c.content,
                           'user_id', c.user_id,
                           'profiles', jsonb_build_object('username', coalesce(cp.username, '未知')))
                  FROM public.comments c
                  LEFT JOIN public.profiles cp ON cp.id = c.user_id
                 WHERE c.id = r.comment_id
            ) END AS comments,
            -- 公司举报：带上公司名和所有者
            CASE WHEN r.company_id IS NULL THEN NULL ELSE (
                SELECT jsonb_build_object(
                           'id', uc.id,
                           'company_name', uc.company_name,
                           'user_id', uc.user_id,
                           'profiles', jsonb_build_object('username', coalesce(up.username, '未知')))
                  FROM public.user_companies uc
                  LEFT JOIN public.profiles up ON up.id = uc.user_id
                 WHERE uc.id = r.company_id
            ) END AS companies,
            -- 作品举报：带上作品标题和作者
            CASE WHEN r.product_id IS NULL THEN NULL ELSE (
                SELECT jsonb_build_object(
                           'id', p.id,
                           'title', p.title,
                           'author_id', p.author_id,
                           'profiles', jsonb_build_object('username', coalesce(pp.username, '未知')))
                  FROM public.products p
                  LEFT JOIN public.profiles pp ON pp.id = p.author_id
                 WHERE p.id = r.product_id
            ) END AS products
          FROM public.reports r
          LEFT JOIN public.profiles rp ON rp.id = r.reporter_user_id
         WHERE r.target_type = v_type
           AND (p_date_from IS NULL OR r.created_at >= p_date_from)
         ORDER BY r.created_at DESC
         LIMIT v_limit OFFSET v_offset
      ) x;

    RETURN jsonb_build_object('success', true, 'total', v_total, 'list', v_list);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_list_reports(text, text, timestamptz, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_reports(text, text, timestamptz, integer, integer) TO anon;


-- ------------------------------------------------------------
-- 1.2 待认证公司列表
-- ------------------------------------------------------------
-- 「哪家公司在申请认证」属于内部信息，不该让外面随便筛出来。
CREATE OR REPLACE FUNCTION public.admin_list_pending_companies(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_list jsonb;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '管理员会话无效或已过期,请重新登录');
    END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id',           uc.id,
               'company_name', uc.company_name,
               'created_at',   uc.created_at,
               'user_id',      uc.user_id,
               'profiles',     jsonb_build_object('username', coalesce(up.username, '未知')))
             ORDER BY uc.created_at DESC), '[]'::jsonb)
      INTO v_list
      FROM public.user_companies uc
      LEFT JOIN public.profiles up ON up.id = uc.user_id
     WHERE uc.verification_status = 'pending';

    RETURN jsonb_build_object('success', true, 'list', v_list);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_list_pending_companies(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_pending_companies(text) TO anon;


-- ------------------------------------------------------------
-- 1.3 评论区「我是否已经举报过这条评论」
-- ------------------------------------------------------------
-- 原来也是直连查 reports 表（查自己的那一行）。撤了表权限之后它会失效，
-- 所以一并改成 RPC —— 顺便修掉「user_id 由前端传、可以伪造」的弱点。
CREATE OR REPLACE FUNCTION public.check_my_report(
    p_user_id    uuid,
    p_comment_id bigint,
    p_session    text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'reason', '请先登录');
    END IF;
    RETURN jsonb_build_object('ok', true, 'exists',
        EXISTS (SELECT 1 FROM public.reports
                 WHERE comment_id = p_comment_id
                   AND reporter_user_id = p_user_id));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.check_my_report(uuid, bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_my_report(uuid, bigint, text) TO anon;


-- ---------- 验收：三个函数都在 ----------
SELECT p.proname AS 新增的函数
  FROM pg_proc p
  JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public'
   AND p.proname IN ('admin_list_reports', 'admin_list_pending_companies', 'check_my_report')
   AND p.prokind = 'f'
 ORDER BY 1;
-- 应该返回 3 行


-- ============================================================
-- SECTION 2 · 等新前端上线、后台确认正常之后，再跑这一段
-- ============================================================
-- ⚠️ 跑之前先确认：打开后台，举报列表 / 公司认证审核 都还能正常显示。
--    如果那两处已经改成调 RPC 了，再往下跑；否则后台会读不到数据。
--
-- 跑完的效果：外面拿公开 key 再也读不到举报内容，
--             克隆站打开就是一个空壳。

-- REVOKE SELECT ON public.reports   FROM anon, authenticated;
-- REVOKE SELECT ON public.api_logs  FROM anon, authenticated;

-- ---------- 验收：应该全部显示 permission denied ----------
-- SELECT * FROM public.reports LIMIT 1;

-- 万一撤错了想恢复（比如后台还没改好）：
-- GRANT SELECT ON public.reports  TO anon, authenticated;
-- GRANT SELECT ON public.api_logs TO anon, authenticated;
