-- ============================================================
--  NB报刊社 · 加「刊物类别」（免费刊 / 付费刊）
--
--  【站长的意思】
--      把报刊社分成两类：
--          免费刊    里面每一期都全部免费看
--          付费刊    里面每一期【单期】付 20 NB币才能看全部内容（买了永久拥有）
--
--      注意是【单期】收费，不是整类收费 —— 买第 3 期只解锁第 3 期。
--
--  【和之前那版的区别】
--      上一版我做成了「每一期内部再分免费栏/付费栏」—— 方向不对。
--      这一版在【期】上加一个 kind 字段：
--          news_issues.kind = 'free' | 'paid'
--
--      news_articles.section 保留不动，含义变成：
--          免费刊    里所有文章都直接可读（section 不影响）
--          付费刊    里 section='free' 的是【试读】，section='paid' 的要买了才给
--      —— 这样付费刊也能放一两篇免费的当引子，不算浪费。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：加字段
-- ============================================================
ALTER TABLE public.news_issues ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'free';

-- 已有的第 1 期里本来就有付费内容，标成付费刊更贴切
UPDATE public.news_issues SET kind = 'paid'
 WHERE kind = 'free'
   AND EXISTS (SELECT 1 FROM public.news_articles a
                WHERE a.issue_id = news_issues.id AND a.section = 'paid');

COMMENT ON COLUMN public.news_issues.kind IS
    '刊物类别：free = 免费刊（整期免费）；paid = 付费刊（单期付 price 个 NB币解锁）';


-- ============================================================
-- 第 2 步：期列表 —— 多返回一个 kind
-- ============================================================
DROP FUNCTION IF EXISTS public.get_news_issues(uuid, text);
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
        SELECT i.issue_no,
               i.title,
               i.summary,
               i.cover,
               i.kind,                                    -- ← 新增
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               i.price,
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
-- 第 3 步：读某一期 —— 免费刊整期放开；付费刊按 section 分试读/锁
-- ============================================================
DROP FUNCTION IF EXISTS public.get_news_issue(uuid, text, integer);
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
    v_issue record;
    v_ok    boolean := false;
    v_owned boolean := false;
    v_free  jsonb;
    v_paid  jsonb;
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

    -- 免费刊：整期都算「可读」，不管 section 是什么
    SELECT COALESCE(jsonb_agg(y ORDER BY y.sort, y.id), '[]'::jsonb) INTO v_free
      FROM (
        SELECT id, kind, tag, headline, subhead, body, sort
          FROM public.news_articles
         WHERE issue_id = v_issue.id
           AND (v_issue.kind = 'free' OR section = 'free')
      ) y;

    -- 付费刊的锁住部分；免费刊这一块是空的
    SELECT COALESCE(jsonb_agg(z ORDER BY z.sort, z.id), '[]'::jsonb) INTO v_paid
      FROM (
        SELECT id, kind, tag, headline, subhead, sort,
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
        'publish_date', to_char(v_issue.publish_date, 'YYYY-MM-DD'),
        'price', v_issue.price,
        'owned', v_owned OR v_issue.kind = 'free',   -- 免费刊直接算已解锁
        'logged_in', v_ok,
        'free', v_free,
        'paid', v_paid
    );
END;
$fn$;


-- ============================================================
-- 第 4 步：买一期 —— 免费刊不该走到这儿，顺手挡一下
-- ============================================================
DROP FUNCTION IF EXISTS public.buy_newspaper(uuid, text, integer);
CREATE OR REPLACE FUNCTION public.buy_newspaper(
    p_user_id uuid,
    p_session text,
    p_issue_no integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_issue record;
    v_bal   bigint;
    v_price bigint;
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '请先登录');
    END IF;
    IF NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;

    SELECT * INTO v_issue FROM public.news_issues
     WHERE issue_no = p_issue_no AND published = true;
    IF v_issue.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '没有这一期');
    END IF;
    IF v_issue.kind = 'free' THEN
        RETURN jsonb_build_object('success', true, 'message', '这是免费刊，直接看就行', 'already', true);
    END IF;
    IF EXISTS (SELECT 1 FROM public.news_owned
                WHERE user_id = p_user_id AND issue_id = v_issue.id) THEN
        RETURN jsonb_build_object('success', true, 'message', '这一期你已经有啦', 'already', true);
    END IF;

    v_price := COALESCE(v_issue.price, 20);

    SELECT nb_balance INTO v_bal FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    IF v_bal IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '账号不存在');
    END IF;
    IF v_bal < v_price THEN
        RETURN jsonb_build_object('success', false, 'message',
            'NB币不够，还差 ' || (v_price - v_bal) || ' 个', 'balance', v_bal);
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - v_price WHERE id = p_user_id;
    INSERT INTO public.news_owned (user_id, issue_id) VALUES (p_user_id, v_issue.id);

    RETURN jsonb_build_object('success', true,
        'message', '购买成功，第 ' || p_issue_no || ' 期归你了',
        'balance', v_bal - v_price, 'spent', v_price);
END;
$fn$;


-- ============================================================
-- 第 5 步：我拥有的报纸 —— 也带上 kind
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
-- 第 6 步：后台 —— 列表和保存都带上 kind
-- ============================================================
DROP FUNCTION IF EXISTS public.admin_news_list_issues(text);
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
               (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS article_count
          FROM public.news_issues i
      ) x;
    RETURN jsonb_build_object('success', true, 'issues', v_out);
END;
$fn$;

DROP FUNCTION IF EXISTS public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text);
DROP FUNCTION IF EXISTS public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text, text);
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
    p_kind text DEFAULT 'free'                -- free 免费刊 / paid 付费刊
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
        INSERT INTO public.news_issues (issue_no, title, summary, publish_date, price, published, cover, kind)
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


-- ============================================================
-- 第 7 步：权限
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_news_issues(uuid, text)         TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_news_issue(uuid, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.buy_newspaper(uuid, text, integer)  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_newspapers(uuid, text)       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_list_issues(text)        TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text, text) TO anon, authenticated;


-- ============================================================
-- 第 8 步：验证
-- ============================================================
SELECT issue_no AS 期号, kind AS 类别, title AS 标题, price AS 价格,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS 文章数,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id AND a.section='free') AS 免费篇,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id AND a.section='paid') AS 付费篇,
       published AS 已出刊
  FROM public.news_issues i ORDER BY issue_no DESC;

SELECT 'kind 字段' AS 项目,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns
                          WHERE table_schema='public' AND table_name='news_issues' AND column_name='kind')
            THEN '✅ 有' ELSE '❌ 没有' END AS 状态
UNION ALL
SELECT 'get_news_issue 认 kind',
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                          WHERE n.nspname='public' AND p.proname='get_news_issue'
                            AND position('v_issue.kind' in pg_get_functiondef(p.oid)) > 0)
            THEN '✅ 认' ELSE '❌ 不认' END;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 第 1 期会被自动标成【付费刊】（因为它本来就有付费内容）
--  · 报刊社页面顶部会变成三个标签：
--        🆓 免费刊   💰 付费刊   🔖 我拥有的报纸
--  · 后台「📰 报刊社」面板里新建期时多一个「刊物类别」下拉
-- ============================================================
