-- ============================================================
--  NB报刊社 · 报纸真正分页
--
--  站长要求：
--      「报纸也要分页，就按分页的页数填，
--        比如第一期的报纸只有一页，就显示共一页」
--
--  也就是说：页数不是估出来的，是【文章实际排在第几页】决定的。
--
--  做法：news_articles 加 page 字段。
--      后台里每篇文章填「第几页」，页面就按页渲染，可以翻页。
--      一期的总页数 = 该期所有文章里最大的那个 page（没有文章就是 1 页）。
--      所以第 1 期 9 篇文章全填第 1 页 → 「共 1 页」。
--
--  ⚠️ 上一版我在 news_issues 上加了 pages 字段按内容估算 —— 方向不对，
--     这一版把它去掉，改成按文章页码算。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：文章加 page 字段
-- ============================================================
ALTER TABLE public.news_articles ADD COLUMN IF NOT EXISTS page integer NOT NULL DEFAULT 1;

COMMENT ON COLUMN public.news_articles.page IS
    '排在第几页（从 1 开始）。一期的总页数 = 该期所有文章里最大的 page，没有文章算 1 页';

CREATE INDEX IF NOT EXISTS idx_news_articles_page ON public.news_articles (issue_id, page, sort);


-- ============================================================
-- 第 2 步：把上一版加的 news_issues.pages 去掉
--   （它对几处函数有依赖，先删函数再删字段，最后重建）
-- ============================================================
DROP FUNCTION IF EXISTS public.get_news_issues(uuid, text);
DROP FUNCTION IF EXISTS public.get_news_issue(uuid, text, integer);
DROP FUNCTION IF EXISTS public.get_my_newspapers(uuid, text);
DROP FUNCTION IF EXISTS public.admin_news_list_issues(text);
DROP FUNCTION IF EXISTS public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text, text);
DROP FUNCTION IF EXISTS public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text, text, integer);
DROP FUNCTION IF EXISTS public._news_pages(bigint);
DROP FUNCTION IF EXISTS public._news_pages_of(bigint, integer);

ALTER TABLE public.news_issues DROP COLUMN IF EXISTS pages;


-- ============================================================
-- 第 3 步：算总页数
-- ============================================================
CREATE OR REPLACE FUNCTION public._news_page_count(p_issue_id bigint)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT GREATEST(1, COALESCE(max(page), 0))::integer
      FROM public.news_articles WHERE issue_id = p_issue_id;
$fn$;


-- ============================================================
-- 第 4 步：期列表 —— 返回总页数
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_news_issues(
    p_user_id uuid DEFAULT NULL,
    p_session text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_ok  boolean := false;
    v_out jsonb;
BEGIN
    IF p_user_id IS NOT NULL AND p_session IS NOT NULL THEN
        BEGIN
            v_ok := public._user_ok(p_user_id, p_session);
        EXCEPTION WHEN OTHERS THEN
            v_ok := false;
        END;
    END IF;

    SELECT COALESCE(jsonb_agg(x ORDER BY x.issue_no DESC), '[]'::jsonb) INTO v_out
      FROM (
        SELECT i.issue_no, i.title, i.summary, i.cover, i.kind, i.price,
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               public._news_page_count(i.id) AS pages,
               (SELECT count(*) FROM public.news_articles a
                 WHERE a.issue_id = i.id AND a.section = 'free') AS free_count,
               (SELECT count(*) FROM public.news_articles a
                 WHERE a.issue_id = i.id AND a.section = 'paid') AS paid_count,
               (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS total_count,
               CASE WHEN v_ok THEN EXISTS (
                        SELECT 1 FROM public.news_owned o
                         WHERE o.issue_id = i.id AND o.user_id = p_user_id)
                    ELSE false END AS owned
          FROM public.news_issues i
         WHERE i.published = true
      ) x;

    RETURN jsonb_build_object('success', true, 'issues', v_out, 'logged_in', v_ok);
END;
$fn$;


-- ============================================================
-- 第 5 步：读某一期 —— 按页分组返回
--   返回结构：
--       pages       总页数
--       by_page     { "1": [文章…], "2": [文章…] }   ← 可读的
--       locked      [锁住的文章…]（付费刊没买时才有）
--       free        / paid 保留旧字段，兼容没更新的页面
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_news_issue(
    p_user_id uuid DEFAULT NULL,
    p_session text DEFAULT NULL,
    p_issue_no integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_issue  record;
    v_ok     boolean := false;
    v_owned  boolean := false;
    v_pages  integer;
    v_bypage jsonb;
    v_free   jsonb;
    v_paid   jsonb;
BEGIN
    SELECT * INTO v_issue FROM public.news_issues
     WHERE issue_no = p_issue_no AND published = true;
    IF v_issue.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '没有这一期');
    END IF;

    IF p_user_id IS NOT NULL AND p_session IS NOT NULL THEN
        BEGIN
            v_ok := public._user_ok(p_user_id, p_session);
        EXCEPTION WHEN OTHERS THEN
            v_ok := false;
        END;
    END IF;
    IF v_ok THEN
        SELECT EXISTS (SELECT 1 FROM public.news_owned
                        WHERE issue_id = v_issue.id AND user_id = p_user_id) INTO v_owned;
    END IF;

    v_pages := public._news_page_count(v_issue.id);

    -- 可读的文章（免费刊是全部；付费刊是 section='free' 的那些）
    SELECT COALESCE(jsonb_agg(y ORDER BY y.sort, y.id), '[]'::jsonb) INTO v_free
      FROM (
        SELECT id, kind, tag, headline, subhead, body, sort, page
          FROM public.news_articles
         WHERE issue_id = v_issue.id
           AND (v_issue.kind = 'free' OR section = 'free')
      ) y;

    -- 按页分组（第 1 页 … 第 N 页，没有文章的页给空数组，保证页码连续）
    SELECT COALESCE(jsonb_object_agg(p.n::text, COALESCE(pg.arr, '[]'::jsonb)), '{}'::jsonb)
      INTO v_bypage
      FROM generate_series(1, v_pages) AS p(n)
      LEFT JOIN LATERAL (
        SELECT jsonb_agg(a ORDER BY a.sort, a.id) AS arr
          FROM (
            SELECT id, kind, tag, headline, subhead, body, sort, page
              FROM public.news_articles
             WHERE issue_id = v_issue.id
               AND page = p.n
               AND (v_issue.kind = 'free' OR section = 'free')
          ) a
      ) pg ON true;

    -- 锁住的（付费刊没买时）
    SELECT COALESCE(jsonb_agg(z ORDER BY z.page, z.sort, z.id), '[]'::jsonb) INTO v_paid
      FROM (
        SELECT id, kind, tag, headline, subhead, sort, page,
               CASE WHEN v_owned THEN body ELSE '' END AS body,
               v_owned AS unlocked
          FROM public.news_articles
         WHERE issue_id = v_issue.id
           AND v_issue.kind = 'paid'
           AND section = 'paid'
      ) z;

    RETURN jsonb_build_object(
        'success', true,
        'issue_no', v_issue.issue_no,
        'title', v_issue.title,
        'summary', v_issue.summary,
        'cover', v_issue.cover,
        'kind', v_issue.kind,
        'pages', v_pages,
        'by_page', v_bypage,
        'publish_date', to_char(v_issue.publish_date, 'YYYY-MM-DD'),
        'price', v_issue.price,
        'owned', v_owned OR v_issue.kind = 'free',
        'logged_in', v_ok,
        'free', v_free,
        'paid', v_paid
    );
END;
$fn$;


-- ============================================================
-- 第 6 步：我拥有的报纸
-- ============================================================
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
               to_char(o.bought_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS bought_at,
               (SELECT count(*) FROM public.news_articles a
                 WHERE a.issue_id = i.id AND a.section = 'paid') AS paid_count,
               (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS total_count
          FROM public.news_owned o
          JOIN public.news_issues i ON i.id = o.issue_id
         WHERE o.user_id = p_user_id
      ) y;

    RETURN jsonb_build_object('success', true, 'issues', v_out);
END;
$fn$;


-- ============================================================
-- 第 7 步：后台 —— 列表带 pages，保存文章多一个 p_page
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_news_list_issues(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_out jsonb;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    SELECT COALESCE(jsonb_agg(x ORDER BY x.issue_no DESC), '[]'::jsonb) INTO v_out
      FROM (
        SELECT i.id, i.issue_no, i.title, i.summary, i.cover, i.kind,
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               i.price, i.published,
               public._news_page_count(i.id) AS pages,
               (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS article_count
          FROM public.news_issues i
      ) x;
    RETURN jsonb_build_object('success', true, 'issues', v_out);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_news_save_issue(
    p_token text,
    p_id bigint DEFAULT NULL,
    p_issue_no integer DEFAULT NULL,
    p_title text DEFAULT '',
    p_summary text DEFAULT '',
    p_publish_date text DEFAULT NULL,
    p_price bigint DEFAULT 20,
    p_published boolean DEFAULT true,
    p_cover text DEFAULT '',
    p_kind text DEFAULT 'free'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_no integer;
    v_id bigint;
    v_dt date;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    IF p_title IS NULL OR btrim(p_title) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', '标题不能为空');
    END IF;
    IF p_kind NOT IN ('free', 'paid') THEN
        RETURN jsonb_build_object('success', false, 'message', '刊物类别只能是 free 或 paid');
    END IF;

    BEGIN
        v_dt := COALESCE(NULLIF(p_publish_date, '')::date, CURRENT_DATE);
    EXCEPTION WHEN OTHERS THEN
        v_dt := CURRENT_DATE;
    END;

    IF p_id IS NULL THEN
        v_no := COALESCE(p_issue_no, (SELECT COALESCE(max(issue_no), 0) + 1 FROM public.news_issues));
        INSERT INTO public.news_issues
            (issue_no, title, summary, publish_date, price, published, cover, kind)
        VALUES (v_no, btrim(p_title), COALESCE(p_summary, ''), v_dt,
                COALESCE(p_price, 20), COALESCE(p_published, true),
                COALESCE(p_cover, ''), COALESCE(p_kind, 'free'))
        RETURNING id INTO v_id;
        RETURN jsonb_build_object('success', true, 'message', '第 ' || v_no || ' 期已创建', 'id', v_id);
    ELSE
        UPDATE public.news_issues
           SET title = btrim(p_title),
               summary = COALESCE(p_summary, ''),
               publish_date = v_dt,
               price = COALESCE(p_price, price),
               published = COALESCE(p_published, published),
               cover = COALESCE(p_cover, cover),
               kind = COALESCE(p_kind, kind),
               issue_no = COALESCE(p_issue_no, issue_no)
         WHERE id = p_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'message', '没找到这一期');
        END IF;
        RETURN jsonb_build_object('success', true, 'message', '已保存', 'id', p_id);
    END IF;
END;
$fn$;

-- 文章：列表带 page，保存多一个 p_page
DROP FUNCTION IF EXISTS public.admin_news_list_articles(text, bigint);
CREATE OR REPLACE FUNCTION public.admin_news_list_articles(p_token text, p_issue_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_out jsonb;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    SELECT COALESCE(jsonb_agg(x ORDER BY x.page, x.section, x.sort, x.id), '[]'::jsonb) INTO v_out
      FROM (
        SELECT id, section, kind, tag, headline, subhead, body, sort, page
          FROM public.news_articles WHERE issue_id = p_issue_id
      ) x;
    RETURN jsonb_build_object('success', true, 'articles', v_out);
END;
$fn$;

DROP FUNCTION IF EXISTS public.admin_news_save_article(text, bigint, bigint, text, text, text, text, text, text, integer);
DROP FUNCTION IF EXISTS public.admin_news_save_article(text, bigint, bigint, text, text, text, text, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.admin_news_save_article(
    p_token text,
    p_id bigint DEFAULT NULL,
    p_issue_id bigint DEFAULT NULL,
    p_section text DEFAULT 'free',
    p_kind text DEFAULT 'article',
    p_tag text DEFAULT '',
    p_headline text DEFAULT '',
    p_subhead text DEFAULT '',
    p_body text DEFAULT '',
    p_sort integer DEFAULT 0,
    p_page integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_id bigint;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    IF p_headline IS NULL OR btrim(p_headline) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', '标题不能为空');
    END IF;
    IF p_section NOT IN ('free', 'paid') THEN
        RETURN jsonb_build_object('success', false, 'message', '栏目只能是 free 或 paid');
    END IF;

    IF p_id IS NULL THEN
        IF p_issue_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', '没指定是哪一期');
        END IF;
        INSERT INTO public.news_articles
            (issue_id, section, kind, tag, headline, subhead, body, sort, page)
        VALUES (p_issue_id, p_section, COALESCE(NULLIF(p_kind, ''), 'article'),
                COALESCE(p_tag, ''), btrim(p_headline), COALESCE(p_subhead, ''),
                COALESCE(p_body, ''), COALESCE(p_sort, 0), GREATEST(COALESCE(p_page, 1), 1))
        RETURNING id INTO v_id;
        RETURN jsonb_build_object('success', true, 'message', '已添加', 'id', v_id);
    ELSE
        UPDATE public.news_articles
           SET section = p_section,
               kind = COALESCE(NULLIF(p_kind, ''), kind),
               tag = COALESCE(p_tag, ''),
               headline = btrim(p_headline),
               subhead = COALESCE(p_subhead, ''),
               body = COALESCE(p_body, ''),
               sort = COALESCE(p_sort, sort),
               page = GREATEST(COALESCE(p_page, page), 1)
         WHERE id = p_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'message', '没找到这篇文章');
        END IF;
        RETURN jsonb_build_object('success', true, 'message', '已保存', 'id', p_id);
    END IF;
END;
$fn$;


-- ============================================================
-- 第 8 步：权限
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_news_issues(uuid, text)         TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_news_issue(uuid, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_newspapers(uuid, text)       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_list_issues(text)        TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_list_articles(text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_save_article(text, bigint, bigint, text, text, text, text, text, text, integer, integer) TO anon, authenticated;
REVOKE ALL ON FUNCTION public._news_page_count(bigint) FROM anon, authenticated;


-- ============================================================
-- 第 9 步：现有文章全排到第 1 页（第 1 期就只有一页）
-- ============================================================
UPDATE public.news_articles SET page = 1 WHERE page IS NULL OR page < 1;


-- ============================================================
-- 第 10 步：验证
-- ============================================================
SELECT issue_no AS 期号, kind AS 类别, title AS 标题,
       public._news_page_count(i.id) AS 总页数,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS 文章数
  FROM public.news_issues i ORDER BY issue_no DESC;

-- 每页各几篇
SELECT a.issue_id, a.page AS 第几页, count(*) AS 篇数,
       string_agg(left(a.headline, 22), ' | ' ORDER BY a.sort) AS 内容
  FROM public.news_articles a GROUP BY a.issue_id, a.page ORDER BY a.issue_id, a.page;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 第 1 期 9 篇文章都在第 1 页 → 卡片和报头都显示「共 1 页」
--  · 期详情变成一页一页翻：「第 1 / N 页」+ 上一页 / 下一页
--  · 后台文章表单多一个「第几页」输入框
-- ============================================================
