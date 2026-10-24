-- ============================================================
-- 通用投票系统（2026-10-01）
-- ============================================================
-- 用途：常驻功能。以后站里遇到需要听大家意见的抉择，就建一个投票。
--     不是一次性的 —— 可以同时存在多个投票，历史的也一直留着能查。
--
-- 特性：
--   · 票数【实时公开】—— 打开页面就能看到当前票数，不藏着
--   · 必须登录才能投（防止刷票），一人一票，投完不能改
--   · 可以设截止时间，到点自动关闭（服务端判断，改前端没用）
--   · 也可以手动提前关闭
--   · 支持单选 / 多选
--
-- 怎么建投票：见文件末尾的「建投票」一节，改几个字跑一下就行。
-- ============================================================


-- ============================================================
-- ① 三张表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.polls (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug        text UNIQUE NOT NULL,          -- 短标识，如 'mode-2026-10'
    title       text NOT NULL,
    description text,
    multi       boolean NOT NULL DEFAULT false, -- true=可多选
    ends_at     timestamptz,                    -- 截止时间，NULL=不限
    closed      boolean NOT NULL DEFAULT false, -- 手动关闭
    sort        integer NOT NULL DEFAULT 0,     -- 排序，大的在前
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.poll_options (
    id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    poll_id bigint NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    idx     integer NOT NULL,
    label   text NOT NULL,
    UNIQUE (poll_id, idx)
);

CREATE TABLE IF NOT EXISTS public.poll_votes (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    poll_id    bigint NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    option_id  bigint NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    -- ⚠️ 唯一键带上 option_id：多选时一个用户要插多行，
    --    只写 (poll_id, user_id) 会把第二行挡掉。
    --    "一人一票"由 poll_vote() 开头那句 EXISTS 判断保证，不靠这个约束。
    UNIQUE (poll_id, user_id, option_id)
);
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll ON public.poll_votes (poll_id);

-- 内部表，客户端一律不许直接碰（只能走下面的 RPC）
REVOKE ALL ON public.polls,        public.poll_options, public.poll_votes FROM PUBLIC, anon, authenticated;
ALTER TABLE public.polls        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes   ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- ② 列表（含实时票数）
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


-- ============================================================
-- ③ 投票
-- ============================================================
CREATE OR REPLACE FUNCTION public.poll_vote(
    p_slug      text,
    p_user_id   uuid,
    p_session   text,
    p_option    bigint,
    p_option2   bigint DEFAULT NULL)     -- 多选时最多两个，够用了
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_poll   record;
    v_n      int;
    v_need   int;
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '请先登录再投票');
    END IF;

    SELECT * INTO v_poll FROM public.polls WHERE slug = p_slug;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', '找不到这个投票');
    END IF;
    IF v_poll.closed THEN
        RETURN jsonb_build_object('success', false, 'message', '这个投票已经关闭了');
    END IF;
    IF v_poll.ends_at IS NOT NULL AND v_poll.ends_at <= now() THEN
        RETURN jsonb_build_object('success', false, 'message', '这个投票已经截止了');
    END IF;

    IF EXISTS (SELECT 1 FROM public.poll_votes WHERE poll_id = v_poll.id AND user_id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'message', '你已经投过票了');
    END IF;

    IF NOT v_poll.multi AND p_option2 IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '这个投票只能选一项');
    END IF;

    -- 校验选项属于这个投票
    -- ⚠️ 原来这里写的是 IF v_n < CASE WHEN ... END THEN，PostgreSQL 报
    --    42601 syntax error —— CASE 表达式放在比较里要加括号，干脆拆成变量更清楚。
    SELECT count(*) INTO v_n FROM public.poll_options
     WHERE poll_id = v_poll.id AND id IN (p_option, coalesce(p_option2, p_option));

    v_need := 1;
    IF p_option2 IS NOT NULL AND p_option2 <> p_option THEN
        v_need := 2;
    END IF;

    IF v_n < v_need THEN
        RETURN jsonb_build_object('success', false, 'message', '选项不对');
    END IF;

    INSERT INTO public.poll_votes (poll_id, option_id, user_id)
    VALUES (v_poll.id, p_option, p_user_id);

    IF p_option2 IS NOT NULL AND p_option2 <> p_option THEN
        INSERT INTO public.poll_votes (poll_id, option_id, user_id)
        VALUES (v_poll.id, p_option2, p_user_id)
        ON CONFLICT DO NOTHING;   -- 同选项重复投就忽略
    END IF;

    RETURN jsonb_build_object('success', true, 'message', '投票成功，谢谢参与');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.poll_vote(text, uuid, text, bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.poll_vote(text, uuid, text, bigint, bigint) TO anon;


-- ============================================================
-- ④ 后台：管理投票
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_poll_create(
    p_token  text,
    p_slug   text,
    p_title  text,
    p_desc   text,
    p_opts   text[],                  -- 选项文字，按顺序
    p_multi  boolean DEFAULT false,
    p_ends   timestamptz DEFAULT NULL,
    p_sort   integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_id bigint; v_i int := 0; v_o text;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;
    IF p_opts IS NULL OR array_length(p_opts, 1) < 2 THEN
        RETURN jsonb_build_object('success', false, 'message', '至少要有两个选项');
    END IF;

    INSERT INTO public.polls (slug, title, description, multi, ends_at, sort)
    VALUES (p_slug, p_title, p_desc, coalesce(p_multi, false), p_ends, coalesce(p_sort, 0))
    ON CONFLICT (slug) DO UPDATE
       SET title = EXCLUDED.title, description = EXCLUDED.description,
           multi = EXCLUDED.multi, ends_at = EXCLUDED.ends_at, sort = EXCLUDED.sort,
           closed = false
    RETURNING id INTO v_id;

    -- 覆盖式：先清掉旧选项（连带旧票），再按新顺序写入
    DELETE FROM public.poll_options WHERE poll_id = v_id;
    FOREACH v_o IN ARRAY p_opts LOOP
        INSERT INTO public.poll_options (poll_id, idx, label) VALUES (v_id, v_i, v_o);
        v_i := v_i + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'id', v_id, 'slug', p_slug, 'options', v_i);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_poll_create(text, text, text, text, text[], boolean, timestamptz, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_poll_create(text, text, text, text, text[], boolean, timestamptz, integer) TO anon;


CREATE OR REPLACE FUNCTION public.admin_poll_close(p_token text, p_slug text, p_closed boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_n int;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;
    UPDATE public.polls SET closed = coalesce(p_closed, true) WHERE slug = p_slug;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n = 0 THEN RETURN jsonb_build_object('success', false, 'message', '找不到这个投票'); END IF;
    RETURN jsonb_build_object('success', true, 'closed', coalesce(p_closed, true));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_poll_close(text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_poll_close(text, text, boolean) TO anon;


CREATE OR REPLACE FUNCTION public.admin_poll_delete(p_token text, p_slug text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_n int;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;
    DELETE FROM public.polls WHERE slug = p_slug;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN jsonb_build_object('success', true, 'deleted', v_n);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_poll_delete(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_poll_delete(text, text) TO anon;


-- ============================================================
-- ⑤ 建第一个投票：官网模式是否保留「新潮 / 简单模式」
-- ============================================================
-- ends_at 用北京时间写，这里转成 UTC 存（10 月 7 日 20:00 +08 = 12:00 UTC）
INSERT INTO public.polls (slug, title, description, multi, ends_at, sort)
VALUES (
    'mode-2026-10',
    '官网模式投票：「新潮模式」和「简单模式」要不要保留？',
    'Beta 版官网化页面已经完善。我们认为目前的官网模式已经十分完善，不必再保留「新潮模式」和「简单模式」，但最终还是尊重大家的选择。',
    false,
    timestamptz '2026-10-07 20:00:00+08',
    10
)
ON CONFLICT (slug) DO UPDATE
   SET title = EXCLUDED.title, description = EXCLUDED.description,
       ends_at = EXCLUDED.ends_at, sort = EXCLUDED.sort;

DELETE FROM public.poll_options
 WHERE poll_id = (SELECT id FROM public.polls WHERE slug = 'mode-2026-10');

INSERT INTO public.poll_options (poll_id, idx, label)
SELECT (SELECT id FROM public.polls WHERE slug = 'mode-2026-10'), v.idx, v.label
  FROM (VALUES
        (0, '保留「新潮模式」和「简单模式」'),
        (1, '不必保留，现在的官网模式就够了'),
        (2, '无所谓 / 都行')
       ) AS v(idx, label);


-- ============================================================
-- ⑥ 以后怎么建新投票
-- ============================================================
-- 方式一（推荐）：在 SQL Editor 里跑下面这段，改改字就行
--
--   SELECT public.admin_poll_create(
--       '<你的后台管理token>',                    -- 从后台登录后 F12 里拿，或直接用下面的方式二
--       'your-slug-here',                        -- 唯一标识，只能用一次
--       '投票标题',
--       '补充说明，可以留空',
--       ARRAY['选项一', '选项二', '选项三'],       -- 2 个以上
--       false,                                   -- true = 可多选
--       timestamptz '2026-10-15 20:00:00+08',    -- 截止时间，NULL = 不限
--       20                                       -- 排序，大的显示在前
--   );
--
-- 方式二：不想用 token 就照抄第 ⑤ 节那几行 SQL，改 slug / 标题 / 选项 / 时间。
--
-- 关闭投票：  SELECT public.admin_poll_close('<token>', 'your-slug-here');
-- 删除投票：  SELECT public.admin_poll_delete('<token>', 'your-slug-here');


-- ============================================================
-- 验收
-- ============================================================
SELECT p.slug AS 标识, p.title AS 标题, p.multi AS 多选, p.closed AS 已关闭,
       to_char(p.ends_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS 截止,
       (SELECT count(*) FROM public.poll_options o WHERE o.poll_id = p.id) AS 选项数,
       (SELECT count(*) FROM public.poll_votes v WHERE v.poll_id = p.id)   AS 已投票数
  FROM public.polls p ORDER BY p.sort DESC, p.created_at DESC;

SELECT o.idx AS 序号, o.label AS 选项, o.id AS 选项id
  FROM public.poll_options o
  JOIN public.polls p ON p.id = o.poll_id
 WHERE p.slug = 'mode-2026-10' ORDER BY o.idx;

-- 匿名读不到底层表（应该三个都返回 f）
SELECT has_table_privilege('anon', 'public.polls', 'SELECT')        AS polls_匿名可读,
       has_table_privilege('anon', 'public.poll_options', 'SELECT') AS options_匿名可读,
       has_table_privilege('anon', 'public.poll_votes', 'SELECT')   AS votes_匿名可读;

-- 列表 RPC 能匿名调（票数实时公开）
SELECT public.poll_list() -> 'list' -> 0 ->> 'title' AS 第一个投票标题;
