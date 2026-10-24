-- ============================================================
--  NB报刊社 · 「我可以直接读的报纸」
--
--  站长要求：把「我拥有的报纸」改成
--            「我可以直接读的报纸（包含免费和付过费的报纸）」
--
--  所以这个列表的含义变了：
--      原来  只列 news_owned 里买过的
--      现在  免费刊的全部（本来就能直接读）+ 付费刊里买过的
--
--  函数名还叫 get_my_newspapers（前端已经在调它，改名字要两边一起动，
--  没必要）—— 只改它返回什么。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：重写这个函数
-- ============================================================
DROP FUNCTION IF EXISTS public.get_my_newspapers(uuid, text);
CREATE OR REPLACE FUNCTION public.get_my_newspapers(
    p_user_id uuid,
    p_session text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_out jsonb;
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '请先登录', 'issues', '[]'::jsonb);
    END IF;
    IF NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录', 'issues', '[]'::jsonb);
    END IF;

    SELECT COALESCE(jsonb_agg(y ORDER BY y.issue_no DESC), '[]'::jsonb) INTO v_out
      FROM (
        SELECT i.issue_no, i.title, i.summary, i.cover, i.kind,
               public._news_page_count(i.id) AS pages,
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               -- 为什么能读：free = 免费刊 / bought = 买过
               CASE WHEN i.kind = 'free' THEN 'free' ELSE 'bought' END AS why,
               CASE WHEN i.kind = 'free' THEN NULL
                    ELSE to_char(o.bought_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI')
               END AS bought_at,
               (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS total_count
          FROM public.news_issues i
          LEFT JOIN public.news_owned o
                 ON o.issue_id = i.id AND o.user_id = p_user_id
         WHERE i.published = true
           -- 免费刊一律能读；付费刊得买过
           AND (i.kind = 'free' OR o.user_id IS NOT NULL)
      ) y;

    RETURN jsonb_build_object('success', true, 'issues', v_out);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.get_my_newspapers(uuid, text) TO anon, authenticated;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
-- 各期分别属于哪一类（未登录视角，只看数据本身）
SELECT issue_no AS 期号, kind AS 类别, title AS 标题,
       CASE kind WHEN 'free' THEN '所有人都能直接读'
                 ELSE '要买过才出现在这个列表里' END AS 进不进这个列表
  FROM public.news_issues WHERE published = true ORDER BY issue_no DESC;

-- 函数在不在、认不认 kind
SELECT '函数存在' AS 项目,
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname='public' AND p.proname='get_my_newspapers')
            THEN '✅ 有' ELSE '❌ 没有' END AS 状态
UNION ALL
SELECT '已认免费刊',
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname='public' AND p.proname='get_my_newspapers'
                            AND position('i.kind = ''free''' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 认' ELSE '❌ 不认' END;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 页面标签变成「📖 我可以直接读的报纸」
--  · 里面会列出：免费刊的全部 + 付费刊里买过的
--  · 每条会标明「免费刊」或「已购买」
-- ============================================================
