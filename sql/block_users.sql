-- ============================================================
-- 补齐「拉黑 / 屏蔽」功能(评论区「举报并屏蔽」+ 好友黑名单)
-- 说明:friend_chat.sql 里的 blocked_users 表与 block_user / unblock_user /
--       get_blocked_users 在当前库上并不存在(只有其余好友私信函数在),
--       所以评论区的「举报后屏蔽该用户」点了没效果。这里单独补齐,并加会话校验。
-- 在 Supabase SQL Editor 执行
-- ============================================================

-- ---------- 1) 表 ----------
CREATE TABLE IF NOT EXISTS public.blocked_users (
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    was_friend boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, blocked_id)
);
ALTER TABLE public.blocked_users ADD COLUMN IF NOT EXISTS was_friend boolean NOT NULL DEFAULT false;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
-- 不给 anon 任何策略:只能通过下面的 SECURITY DEFINER 函数读写
REVOKE ALL ON TABLE public.blocked_users FROM PUBLIC, anon, authenticated;

-- ---------- 2) 拉黑 ----------
CREATE OR REPLACE FUNCTION public.block_user(
    p_user_id uuid, p_target uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_was_friend boolean;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF p_target IS NULL OR p_user_id = p_target THEN
        RETURN jsonb_build_object('ok', false, 'success', false, 'message', '不能屏蔽自己');
    END IF;
    SELECT public.is_friend(p_user_id, p_target) INTO v_was_friend;
    INSERT INTO public.blocked_users (user_id, blocked_id, was_friend)
    VALUES (p_user_id, p_target, coalesce(v_was_friend, false))
    ON CONFLICT (user_id, blocked_id) DO UPDATE SET
        was_friend = blocked_users.was_friend OR EXCLUDED.was_friend;
    -- 屏蔽同时解除好友关系、拒绝双方待处理申请
    DELETE FROM public.friendships
     WHERE user_a = LEAST(p_user_id, p_target) AND user_b = GREATEST(p_user_id, p_target);
    UPDATE public.friend_requests SET status = 'rejected', responded_at = now()
     WHERE status = 'pending'
       AND ((from_user_id = p_user_id AND to_user_id = p_target)
         OR (from_user_id = p_target AND to_user_id = p_user_id));
    RETURN jsonb_build_object('ok', true, 'success', true, 'message', '已屏蔽该用户,TA 的评论不再显示');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'success', false, 'message', SQLERRM);
END
$fn$;

-- ---------- 3) 取消拉黑 ----------
CREATE OR REPLACE FUNCTION public.unblock_user(
    p_user_id uuid, p_target uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_was_friend boolean;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    SELECT was_friend INTO v_was_friend
      FROM public.blocked_users WHERE user_id = p_user_id AND blocked_id = p_target;
    IF coalesce(v_was_friend, false) THEN
        INSERT INTO public.friendships (user_a, user_b)
        VALUES (LEAST(p_user_id, p_target), GREATEST(p_user_id, p_target))
        ON CONFLICT DO NOTHING;
    END IF;
    DELETE FROM public.blocked_users WHERE user_id = p_user_id AND blocked_id = p_target;
    RETURN jsonb_build_object('ok', true, 'success', true, 'message',
        '已取消屏蔽' || CASE WHEN coalesce(v_was_friend, false) THEN ',好友关系已恢复' ELSE '' END);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'success', false, 'message', SQLERRM);
END
$fn$;

-- ---------- 4) 我的屏蔽列表 ----------
-- 返回 jsonb 数组(前端直接 Array.isArray 判断),未登录/会话失效返回空数组
CREATE OR REPLACE FUNCTION public.get_blocked_users(
    p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_out jsonb;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN '[]'::jsonb;
    END IF;
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'blocked_id', bu.blocked_id,
               'username',   pr.username
           ) ORDER BY pr.username), '[]'::jsonb)
      INTO v_out
      FROM public.blocked_users bu
      JOIN public.profiles pr ON pr.id = bu.blocked_id
     WHERE bu.user_id = p_user_id;
    RETURN coalesce(v_out, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
    RETURN '[]'::jsonb;
END
$fn$;

-- ---------- 5) 授权 ----------
GRANT EXECUTE ON FUNCTION public.block_user(uuid, uuid, text)   TO anon;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_blocked_users(uuid, text)  TO anon;

-- ---------- 6) 验收 ----------
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数, pg_get_function_result(p.oid) AS 返回
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('block_user', 'unblock_user', 'get_blocked_users')
 ORDER BY 1;

SELECT to_regclass('public.blocked_users') AS 表是否存在;
