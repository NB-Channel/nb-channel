-- ============================================================
-- 漏洞 / 建议 反馈系统
-- 功能:
--   1) 新表 public.feedback(只允许通过 RPC 读写,anon 不能直接访问)
--   2) submit_feedback  提交反馈(漏洞/建议两类,支持匿名)
--   3) get_my_feedback  查看自己提交过的反馈及处理状态
-- 附件:图片走 Supabase Storage 的 images 桶(前端先上传拿到 key,再把 key 传进来)
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

-- ---------- 1) 表 ----------
CREATE TABLE IF NOT EXISTS public.feedback (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind           text NOT NULL CHECK (kind IN ('vuln', 'suggestion')),  -- 漏洞 / 建议
    title          text NOT NULL,
    reporter_id    uuid REFERENCES public.profiles(id) ON DELETE SET NULL, -- 登录用户(匿名也会记,便于追溯)
    reporter_name  text NOT NULL,            -- 展示名(匿名时存「匿名」)
    is_anonymous   boolean NOT NULL DEFAULT false,
    vuln_type      text,                     -- 漏洞类型
    summary        text,                     -- 漏洞简介
    repro          text,                     -- 复现方式
    content        text,                     -- 建议内容
    attach_text    text,                     -- 文字附件
    attach_images  jsonb NOT NULL DEFAULT '[]'::jsonb,  -- 图片附件 key 数组
    contact_email  text,
    status         text NOT NULL DEFAULT 'pending',     -- pending / processing / fixed / ignored
    admin_note     text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    handled_at     timestamptz
);

CREATE INDEX IF NOT EXISTS feedback_created_idx  ON public.feedback (created_at DESC);
CREATE INDEX IF NOT EXISTS feedback_status_idx   ON public.feedback (status, created_at DESC);
CREATE INDEX IF NOT EXISTS feedback_reporter_idx ON public.feedback (reporter_id, created_at DESC);

-- 只允许通过 SECURITY DEFINER 函数访问
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.feedback FROM PUBLIC, anon, authenticated;

-- ---------- 2) 提交反馈 ----------
CREATE OR REPLACE FUNCTION public.submit_feedback(
    p_kind          text,
    p_title         text,
    p_reporter_name text,
    p_is_anonymous  boolean,
    p_vuln_type     text,
    p_summary       text,
    p_repro         text,
    p_content       text,
    p_attach_text   text DEFAULT NULL,
    p_attach_images jsonb DEFAULT '[]'::jsonb,
    p_contact_email text DEFAULT NULL,
    p_user_id       uuid DEFAULT NULL,
    p_session       text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_kind   text := lower(coalesce(trim(p_kind), ''));
    v_title  text := trim(coalesce(p_title, ''));
    v_name   text := trim(coalesce(p_reporter_name, ''));
    v_mail   text := trim(coalesce(p_contact_email, ''));
    v_anon   boolean := coalesce(p_is_anonymous, false);
    v_type   text := trim(coalesce(p_vuln_type, ''));
    v_sum    text := trim(coalesce(p_summary, ''));
    v_repro  text := trim(coalesce(p_repro, ''));
    v_content text := trim(coalesce(p_content, ''));
    v_atext  text := nullif(trim(coalesce(p_attach_text, '')), '');
    v_imgs   jsonb := coalesce(p_attach_images, '[]'::jsonb);
    v_recent int;
    v_hour   int;
    v_id     bigint;
BEGIN
    -- 带了 user_id 就必须验令牌,否则等于允许冒充别人提交
    IF p_user_id IS NOT NULL THEN
        IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
            RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
        END IF;
    END IF;

    -- 类型
    IF v_kind NOT IN ('vuln', 'suggestion') THEN
        RETURN jsonb_build_object('ok', false, 'message', '反馈类型不正确');
    END IF;

    -- 标题
    IF length(v_title) < 2 THEN
        RETURN jsonb_build_object('ok', false, 'message', '请填写标题(至少 2 个字)');
    END IF;
    IF length(v_title) > 100 THEN
        RETURN jsonb_build_object('ok', false, 'message', '标题不能超过 100 字');
    END IF;

    -- 反馈人:匿名则统一存「匿名」,否则必须填昵称
    IF v_anon THEN
        v_name := '匿名';
    ELSE
        IF v_name = '' THEN
            RETURN jsonb_build_object('ok', false, 'message', '请填写反馈人,或勾选「匿名提交」');
        END IF;
        IF length(v_name) > 30 THEN
            RETURN jsonb_build_object('ok', false, 'message', '反馈人昵称不能超过 30 字');
        END IF;
    END IF;

    -- 两类各自的必填项
    IF v_kind = 'vuln' THEN
        IF v_type = '' THEN RETURN jsonb_build_object('ok', false, 'message', '请选择漏洞类型'); END IF;
        IF length(v_type) > 40 THEN RETURN jsonb_build_object('ok', false, 'message', '漏洞类型过长'); END IF;
        IF v_sum = '' THEN RETURN jsonb_build_object('ok', false, 'message', '请填写漏洞简介'); END IF;
        IF v_repro = '' THEN RETURN jsonb_build_object('ok', false, 'message', '请填写复现方式'); END IF;
        IF length(v_sum) > 2000 OR length(v_repro) > 5000 THEN
            RETURN jsonb_build_object('ok', false, 'message', '漏洞简介或复现方式过长(简介 ≤2000 字,复现 ≤5000 字)');
        END IF;
        v_content := NULL;
    ELSE
        IF v_content = '' THEN RETURN jsonb_build_object('ok', false, 'message', '请填写建议内容'); END IF;
        IF length(v_content) > 5000 THEN
            RETURN jsonb_build_object('ok', false, 'message', '建议内容不能超过 5000 字');
        END IF;
        v_type := NULL; v_sum := NULL; v_repro := NULL;
    END IF;

    -- 附件
    IF v_atext IS NOT NULL AND length(v_atext) > 5000 THEN
        RETURN jsonb_build_object('ok', false, 'message', '文字附件不能超过 5000 字');
    END IF;
    IF jsonb_typeof(v_imgs) <> 'array' THEN
        v_imgs := '[]'::jsonb;
    END IF;
    IF jsonb_array_length(v_imgs) > 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '图片附件最多 5 张');
    END IF;

    -- 联系方式(选填,填了就得像个邮箱)
    IF v_mail <> '' THEN
        IF length(v_mail) > 120 OR position('@' IN v_mail) = 0 THEN
            RETURN jsonb_build_object('ok', false, 'message', '联系邮箱格式不正确');
        END IF;
    END IF;

    -- 限频(登录用户)
    IF p_user_id IS NOT NULL THEN
        SELECT count(*) INTO v_recent FROM public.feedback
         WHERE reporter_id = p_user_id AND created_at > now() - interval '60 seconds';
        IF v_recent > 0 THEN
            RETURN jsonb_build_object('ok', false, 'message', '提交太频繁了,请 1 分钟后再试');
        END IF;
        SELECT count(*) INTO v_hour FROM public.feedback
         WHERE reporter_id = p_user_id AND created_at > now() - interval '1 hour';
        IF v_hour >= 5 THEN
            RETURN jsonb_build_object('ok', false, 'message', '1 小时内最多提交 5 条,请稍后再来');
        END IF;
    END IF;

    -- 防重复刷屏(未登录也挡):10 分钟内同样的标题 + 同样的类型视为重复提交
    SELECT count(*) INTO v_recent FROM public.feedback
     WHERE kind = v_kind AND lower(title) = lower(v_title)
       AND created_at > now() - interval '10 minutes';
    IF v_recent > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '这条反馈刚才已经提交过了,请勿重复提交');
    END IF;

    INSERT INTO public.feedback (
        kind, title, reporter_id, reporter_name, is_anonymous,
        vuln_type, summary, repro, content,
        attach_text, attach_images, contact_email)
    VALUES (
        v_kind, v_title, p_user_id, v_name, v_anon,
        v_type, v_sum, v_repro, v_content,
        v_atext, v_imgs, nullif(v_mail, ''))
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('ok', true, 'id', v_id,
        'message', CASE WHEN v_kind = 'vuln'
            THEN '漏洞已提交,感谢你帮我们变得更安全!我们会尽快核实。'
            ELSE '建议已提交,感谢你的反馈!' END);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

-- ---------- 3) 我的反馈记录 ----------
CREATE OR REPLACE FUNCTION public.get_my_feedback(
    p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_out jsonb;
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN '[]'::jsonb;
    END IF;
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id',         f.id,
               'kind',       f.kind,
               'title',      f.title,
               'vuln_type',  f.vuln_type,
               'status',     f.status,
               'created_at', f.created_at,
               'admin_note', f.admin_note
           ) ORDER BY f.created_at DESC), '[]'::jsonb)
      INTO v_out
      FROM public.feedback f
     WHERE f.reporter_id = p_user_id;
    RETURN coalesce(v_out, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN '[]'::jsonb;
END
$fn$;

-- ---------- 4) 授权 ----------
GRANT EXECUTE ON FUNCTION public.submit_feedback(text, text, text, boolean, text, text, text, text, text, jsonb, text, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_feedback(uuid, text) TO anon;

-- ---------- 5) 验收 ----------
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('submit_feedback', 'get_my_feedback')
 ORDER BY 1;

-- ============================================================
-- 管理员查看(在 SQL Editor 里直接跑):
--   待处理清单:SELECT id, kind, title, reporter_name, is_anonymous, contact_email, created_at
--                 FROM public.feedback WHERE status = 'pending' ORDER BY created_at DESC;
--   看单条详情:SELECT * FROM public.feedback WHERE id = 1;
--   标记处理:UPDATE public.feedback SET status='fixed', handled_at=now(), admin_note='已修复'
--                WHERE id = 1;
--   状态取值:pending 待处理 / processing 处理中 / fixed 已修复 / ignored 不处理
-- ============================================================
