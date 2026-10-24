-- ============================================================
--  NB报刊社 · 数据驱动改造
--
--  【做了什么】
--  把报刊社从「一期一页的静态文件」改成数据库驱动：
--      news_issues     一期
--      news_articles   一期的文章（免费栏 / 付费栏）
--      news_owned      谁买了哪一期（买了就永久拥有）
--  站长可以在本地后台自己发稿，页面自动出刊。
--
--  【价格】
--  付费栏固定 20 NB币，买下之后永久拥有（news_owned 一行，不会再扣）。
--
--  【鉴权】
--  用户侧：两层壳 _user_ok(p_user_id, p_session) → _orig_xxx
--  后台侧：public._admin_token_valid(p_token)（沿用现有那套）
--  站点用的是自定义登录，Supabase 一律看到 anon，所以 GRANT 给 anon。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：建表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.news_issues (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    issue_no     integer     NOT NULL UNIQUE,          -- 第几期
    title        text        NOT NULL,                 -- 该期主题
    summary      text        NOT NULL DEFAULT '',      -- 列表上的一句话
    publish_date date        NOT NULL DEFAULT CURRENT_DATE,
    price        bigint      NOT NULL DEFAULT 20,      -- 付费栏价格（NB币）
    published    boolean     NOT NULL DEFAULT false,   -- 是否已出刊
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.news_articles (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    issue_id   bigint  NOT NULL REFERENCES public.news_issues(id) ON DELETE CASCADE,
    section    text    NOT NULL DEFAULT 'free',        -- free / paid
    kind       text    NOT NULL DEFAULT 'article',     -- article(正文) / brief(短讯) / service(便民)
    tag        text    NOT NULL DEFAULT '',            -- 头条角标，如「新栏目」
    headline   text    NOT NULL,
    subhead    text    NOT NULL DEFAULT '',
    body       text    NOT NULL DEFAULT '',            -- 段落用空行分隔
    sort       integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_news_articles_issue ON public.news_articles (issue_id, section, sort);

CREATE TABLE IF NOT EXISTS public.news_owned (
    user_id   uuid   NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    issue_id  bigint NOT NULL REFERENCES public.news_issues(id) ON DELETE CASCADE,
    bought_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, issue_id)
);

-- 三张表都不直接给前端读，全部走 RPC
ALTER TABLE public.news_issues   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_owned    ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.news_issues   FROM anon, authenticated;
REVOKE ALL ON public.news_articles FROM anon, authenticated;
REVOKE ALL ON public.news_owned    FROM anon, authenticated;

-- 封面图（报刊亭列表上那张图；站长在后台填图片地址）
ALTER TABLE public.news_issues ADD COLUMN IF NOT EXISTS cover text NOT NULL DEFAULT '';

COMMENT ON TABLE public.news_issues   IS 'NB报刊社 · 期';
COMMENT ON TABLE public.news_articles IS 'NB报刊社 · 文章（section: free 免费栏 / paid 付费栏）';
COMMENT ON TABLE public.news_owned    IS 'NB报刊社 · 已购买（买了永久拥有）';


-- ============================================================
-- 第 2 步：用户侧 RPC
-- ============================================================

-- 2.1 期列表（含免费/付费篇数、我买没买）
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
    -- 没登录也允许看列表（免费栏是公开的），所以这里不强制鉴权
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
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               i.price,
               (SELECT count(*) FROM public.news_articles a
                 WHERE a.issue_id = i.id AND a.section = 'free') AS free_count,
               (SELECT count(*) FROM public.news_articles a
                 WHERE a.issue_id = i.id AND a.section = 'paid') AS paid_count,
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

-- 2.2 读某一期（免费栏永远给；付费栏买了才给全文，没买只给标题）
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

    -- 免费栏：全文
    SELECT COALESCE(jsonb_agg(y ORDER BY y.sort, y.id), '[]'::jsonb) INTO v_free
      FROM (
        SELECT id, kind, tag, headline, subhead, body, sort
          FROM public.news_articles
         WHERE issue_id = v_issue.id AND section = 'free'
      ) y;

    -- 付费栏：买了给全文，没买只给标题和一个占位
    SELECT COALESCE(jsonb_agg(z ORDER BY z.sort, z.id), '[]'::jsonb) INTO v_paid
      FROM (
        SELECT id, kind, tag, headline, subhead, sort,
               CASE WHEN v_owned THEN body
                    ELSE '' END AS body,
               v_owned AS unlocked
          FROM public.news_articles
         WHERE issue_id = v_issue.id AND section = 'paid'
      ) z;

    RETURN jsonb_build_object(
        'success', true,
        'issue_no', v_issue.issue_no,
        'title', v_issue.title,
        'summary', v_issue.summary,
        'cover', v_issue.cover,
        'publish_date', to_char(v_issue.publish_date, 'YYYY-MM-DD'),
        'price', v_issue.price,
        'owned', v_owned,
        'logged_in', v_ok,
        'free', v_free,
        'paid', v_paid
    );
END;
$fn$;

-- 2.3 买一期（扣 20 NB币，永久拥有）
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
    v_issue   record;
    v_bal     bigint;
    v_price   bigint;
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

    IF EXISTS (SELECT 1 FROM public.news_owned
                WHERE user_id = p_user_id AND issue_id = v_issue.id) THEN
        RETURN jsonb_build_object('success', true, 'message', '这一期你已经有啦', 'already', true);
    END IF;

    v_price := COALESCE(v_issue.price, 20);

    -- 锁一行再读余额，避免并发重复扣
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

-- 2.4 我拥有的报纸
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
        SELECT i.issue_no, i.title, i.summary,
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               to_char(o.bought_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS bought_at,
               (SELECT count(*) FROM public.news_articles a
                 WHERE a.issue_id = i.id AND a.section = 'paid') AS paid_count
          FROM public.news_owned o
          JOIN public.news_issues i ON i.id = o.issue_id
         WHERE o.user_id = p_user_id
      ) y;

    RETURN jsonb_build_object('success', true, 'issues', v_out);
END;
$fn$;


-- ============================================================
-- 第 3 步：后台 RPC（发稿用，走 _admin_token_valid）
-- ============================================================

-- 3.1 列出所有期（含未出刊的）
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
        SELECT i.id, i.issue_no, i.title, i.summary, i.cover,
               to_char(i.publish_date, 'YYYY-MM-DD') AS publish_date,
               i.price, i.published,
               (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS article_count
          FROM public.news_issues i
      ) x;
    RETURN jsonb_build_object('success', true, 'issues', v_out);
END;
$fn$;

-- 3.2 新建 / 修改一期
DROP FUNCTION IF EXISTS public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean);
DROP FUNCTION IF EXISTS public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text);
CREATE OR REPLACE FUNCTION public.admin_news_save_issue(
    p_token text,
    p_id bigint DEFAULT NULL,                 -- NULL = 新建
    p_issue_no integer DEFAULT NULL,          -- 新建时不传就自动取最大+1
    p_title text DEFAULT '',
    p_summary text DEFAULT '',
    p_publish_date text DEFAULT NULL,         -- 'YYYY-MM-DD'
    p_price bigint DEFAULT 20,
    p_published boolean DEFAULT true,
    p_cover text DEFAULT ''                   -- 封面图地址
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_no  integer;
    v_id  bigint;
    v_dt  date;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    IF p_title IS NULL OR btrim(p_title) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', '标题不能为空');
    END IF;

    BEGIN
        v_dt := COALESCE(NULLIF(p_publish_date, '')::date, CURRENT_DATE);
    EXCEPTION WHEN OTHERS THEN
        v_dt := CURRENT_DATE;
    END;

    IF p_id IS NULL THEN
        v_no := COALESCE(p_issue_no, (SELECT COALESCE(max(issue_no), 0) + 1 FROM public.news_issues));
        INSERT INTO public.news_issues (issue_no, title, summary, publish_date, price, published, cover)
        VALUES (v_no, btrim(p_title), COALESCE(p_summary, ''), v_dt,
                COALESCE(p_price, 20), COALESCE(p_published, true), COALESCE(p_cover, ''))
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
               issue_no = COALESCE(p_issue_no, issue_no)
         WHERE id = p_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'message', '没找到这一期');
        END IF;
        RETURN jsonb_build_object('success', true, 'message', '已保存', 'id', p_id);
    END IF;
END;
$fn$;

-- 3.3 删除一期（连同文章，外键 CASCADE 会自动删）
DROP FUNCTION IF EXISTS public.admin_news_delete_issue(text, bigint);
CREATE OR REPLACE FUNCTION public.admin_news_delete_issue(p_token text, p_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    DELETE FROM public.news_issues WHERE id = p_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', '没找到这一期');
    END IF;
    RETURN jsonb_build_object('success', true, 'message', '已删除');
END;
$fn$;

-- 3.4 列出某一期的文章
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
    SELECT COALESCE(jsonb_agg(x ORDER BY x.section, x.sort, x.id), '[]'::jsonb) INTO v_out
      FROM (
        SELECT id, section, kind, tag, headline, subhead, body, sort
          FROM public.news_articles WHERE issue_id = p_issue_id
      ) x;
    RETURN jsonb_build_object('success', true, 'articles', v_out);
END;
$fn$;

-- 3.5 新建 / 修改一篇文章
DROP FUNCTION IF EXISTS public.admin_news_save_article(text, bigint, bigint, text, text, text, text, text, text, integer);
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
    p_sort integer DEFAULT 0
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
            (issue_id, section, kind, tag, headline, subhead, body, sort)
        VALUES (p_issue_id, p_section, COALESCE(NULLIF(p_kind, ''), 'article'),
                COALESCE(p_tag, ''), btrim(p_headline), COALESCE(p_subhead, ''),
                COALESCE(p_body, ''), COALESCE(p_sort, 0))
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
               sort = COALESCE(p_sort, sort)
         WHERE id = p_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'message', '没找到这篇文章');
        END IF;
        RETURN jsonb_build_object('success', true, 'message', '已保存', 'id', p_id);
    END IF;
END;
$fn$;

-- 3.6 删除一篇文章
DROP FUNCTION IF EXISTS public.admin_news_delete_article(text, bigint);
CREATE OR REPLACE FUNCTION public.admin_news_delete_article(p_token text, p_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    DELETE FROM public.news_articles WHERE id = p_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', '没找到这篇文章');
    END IF;
    RETURN jsonb_build_object('success', true, 'message', '已删除');
END;
$fn$;


-- ============================================================
-- 第 4 步：把现有的第 1 期搬进去（只在表为空时执行）
-- ============================================================
DO $$
DECLARE
    v_id bigint;
BEGIN
    IF EXISTS (SELECT 1 FROM public.news_issues) THEN
        RAISE NOTICE '已经有期了，跳过初始内容';
        RETURN;
    END IF;

    INSERT INTO public.news_issues (issue_no, title, summary, publish_date, price, published)
    VALUES (1, '创刊号', '官网 1.0.8 上线 · 天气瞎报开张', DATE '2026-10-10', 20, true)
    RETURNING id INTO v_id;

    -- 免费栏
    INSERT INTO public.news_articles (issue_id, section, kind, tag, headline, subhead, body, sort) VALUES
    (v_id, 'free', 'article', '', '官网 1.0.8 上线，「关于域名」挂出域名证书',
     '—— 那张证书在抽屉里放了半年',
     E'NB频道官网 V1.0.8 于本月上线。本次更新的重点是「关于」页面新增一节「关于域名」，把 nb-channel.top 的顶级国际域名证书挂了出来。\n\n'
     '该证书由 ICANN 授权机构颁发，记载域名注册于 2026 年 3 月 23 日，到期时间 2027 年 3 月 23 日，注册机构为 DNSPod · 腾讯云。\n\n'
     '据站长介绍，这张证书「早就下来了，一直没往页面上放」。编辑部追问为何拖了半年，站长表示「忘了」。\n\n'
     '另据观察，证书上「注册所有者」一栏已被涂黑。站长回应：「这个不用给大家看。」', 1),
    (v_id, 'free', 'article', '新栏目', '「天气瞎报」开张，十二座城市每十秒报一次', '',
     E'本站新建的《天气瞎报》栏目正式开张，覆盖 NB频道总部、U星、AWM市、Lemon市、Oganesson市、Fafat市、GC3市、UVS市、UWSF市、PTC市、5U市、Ubn市，共十二座城市。\n\n'
     '栏目按真实季节走，数据每十秒刷新一次，由数据库统一计算 —— 你和朋友同时打开，看到的数字是一样的。\n\n'
     '编辑部特别声明：所有气象数据均由随机数生成，与任何真实地点、真实天气无关。看到「Oganesson市 36°C」请不要给当地打电话。', 2),
    (v_id, 'free', 'brief', '', '虚拟股票市场：公司税改按市值征收，单次扣款设上限', '', '', 3),
    (v_id, 'free', 'brief', '', 'NB银行补上四道闸：存款十亿封顶、两类贷款各一亿、计息基数十亿', '', '', 4),
    (v_id, 'free', 'brief', '', '用户名放开一批常用符号，空格与 at 符号仍然不行', '', '', 5),
    (v_id, 'free', 'brief', '', '评论行数限制前后端补齐，最多十行', '', '', 6),
    (v_id, 'free', 'brief', '', '个人中心右下角重复的那组按钮已删除', '', '', 7),
    (v_id, 'free', 'brief', '', '域名 nb-channel.top 注册于 2026-03-23，2027-03-23 到期', '', '', 8),
    (v_id, 'free', 'service', '', '便民信息', '',
     E'天气瞎报 → weather.html\n虚拟股票 → Virtual stock.html\n官网更新日志 → changelog.html\n漏洞与建议 → feedback.html', 9);

    -- 付费栏
    INSERT INTO public.news_articles (issue_id, section, kind, tag, headline, subhead, body, sort) VALUES
    (v_id, 'paid', 'article', '本期特稿', '编辑部手记：一个人维护一座虚拟公司是什么体验',
     '—— 写给愿意花 20 NB币的你',
     E'这一期开始有付费栏了。\n\n'
     '先说清楚：免费栏的内容不会因为付费栏而缩水，该报的新闻照报、该挂的证书照挂。付费栏放的是编辑部的长文 —— '
     '一个人从零把这座虚拟公司搭起来的过程里，那些不太适合放进更新日志的东西。\n\n'
     '这一期聊三件事：为什么要做「天气瞎报」这种明显没有用的功能；'
     '为什么把公司税改成按市值收；以及那个 9×10¹⁸ 的余额到底是怎么回事。\n\n'
     '（全文内容由站长在后台撰写，这里先占个位置。）', 1),
    (v_id, 'paid', 'article', '数据', '本期数据：十二座城市、七套主题、三套界面',
     '',
     E'截至本期付印：\n\n'
     '十二座虚拟城市，每座六项气象指标，每十秒推进一次。\n'
     '七套主题，三套界面（新潮 / 经典 / 官网）。\n'
     '一个公开 API：市值、评论、统计、实时粉丝、天气。\n\n'
     '（完整数据表由站长在后台补充。）', 2);

    RAISE NOTICE '第 1 期内容已写入，id=%', v_id;
END $$;


-- ============================================================
-- 第 5 步：权限
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_news_issues(uuid, text)                 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_news_issue(uuid, text, integer)         TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.buy_newspaper(uuid, text, integer)          TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_newspapers(uuid, text)               TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_list_issues(text)                TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_save_issue(text, bigint, integer, text, text, text, bigint, boolean, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_delete_issue(text, bigint)       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_list_articles(text, bigint)      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_save_article(text, bigint, bigint, text, text, text, text, text, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_news_delete_article(text, bigint)     TO anon, authenticated;


-- ============================================================
-- 第 6 步：验证（结果格子直接看）
-- ============================================================
SELECT '表' AS 项目,
       (SELECT count(*) FROM information_schema.tables
         WHERE table_schema='public' AND table_name IN ('news_issues','news_articles','news_owned')) AS 数量,
       '应为 3' AS 说明
UNION ALL
SELECT '函数',
       (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='public' AND p.proname LIKE '%news%'),
       '应为 10（4 用户 + 6 后台）'
UNION ALL
SELECT '第 1 期已建',
       (SELECT count(*) FROM public.news_issues),
       '应为 1'
UNION ALL
SELECT '第 1 期文章数',
       (SELECT count(*) FROM public.news_articles),
       '应为 11（免费 9 + 付费 2）';

-- 免费/付费各几篇
SELECT section AS 栏目, count(*) AS 篇数
  FROM public.news_articles GROUP BY section ORDER BY section;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 前端报纸页会列出第 1 期，免费栏直接能看，付费栏要花 20 NB币解锁
--  · 站长在本地后台的「📰 报刊社」面板里可以自己发新一期
--    （后台面板要配合 __admin__.html 的改动，见仓库里那份）
-- ============================================================
