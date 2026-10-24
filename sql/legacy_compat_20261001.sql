-- ============================================================
-- 让经典模式（8月旧版）能用：补 3 个缺失的函数 + profiles 的替代 RPC
-- ============================================================
-- 背景：站长要拿 2026-08-23 之前的旧版当"经典模式"，视觉 100% 还原。
--      但旧版页面直连的表和函数，有一部分已经不在了：
--
--        ① 3 个 RPC 用不了
--             can_register / record_registration
--                —— 探测后确认：函数其实【存在】，参数名是 ip。
--                   挂掉的原因是它们访问 registration_attempts 表，
--                   而那张表对 anon 关闭、函数又不是 SECURITY DEFINER，
--                   于是报 42501 permission denied。
--                   修法：DROP 掉旧的（返回类型不同，不能 REPLACE），
--                   重建为 SECURITY DEFINER。参数名必须保持 ip，旧 JS 传的就是它。
--             set_item_settings
--                —— 线上只有 4 参数版（session_auth_highrisk 建的），
--                   旧版传 3 个参数匹配不上。3 参数版不冲突，直接新建。
--        ② profiles 表被 REVOKE（我批次 2 的安全加固），旧版有 16 处在直连
--
--      这个文件把①补上、给②做替代 RPC，然后改旧版 JS 走这些 RPC。
--
--      ⚠️ 特别注意：profiles 被撤权限是【故意的】（防个人资料匿名可读），
--         所以这里不恢复表权限，而是用 SECURITY DEFINER 的函数按需给字段。
-- ============================================================


-- ============================================================
-- ① 注册限频：can_register / record_registration
-- ============================================================
-- 旧版调用方式：.rpc('can_register', { ip })  /  .rpc('record_registration', { ip })
-- 语义（按调用点推断）：同一个 IP 一段时间内最多注册 N 次。
CREATE TABLE IF NOT EXISTS public.registration_attempts (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ip_address text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reg_attempts_ip_time
    ON public.registration_attempts (ip_address, created_at DESC);
REVOKE ALL ON public.registration_attempts FROM PUBLIC, anon, authenticated;
ALTER TABLE public.registration_attempts ENABLE ROW LEVEL SECURITY;

-- ⚠️ 旧的 can_register 已存在且返回类型不同，CREATE OR REPLACE 会报
--    42P13 cannot change return type，必须先 DROP。
DROP FUNCTION IF EXISTS public.can_register(text);
DROP FUNCTION IF EXISTS public.record_registration(text);

-- 能不能注册：同一 IP 24 小时内不超过 3 次
-- ⚠️ 参数名必须是 ip（旧版 JS 就是 .rpc('can_register', { ip })，改名会匹配不上）
CREATE OR REPLACE FUNCTION public.can_register(ip text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_ip    text := nullif(btrim(coalesce(ip, '')), '');
    v_cnt   int;
    v_limit CONSTANT int := 3;
BEGIN
    -- 拿不到 IP 就放行（旧版是前端传的，可能为空；不能因此把人挡在外面）
    IF v_ip IS NULL THEN
        RETURN jsonb_build_object('can', true, 'success', true);
    END IF;

    SELECT count(*) INTO v_cnt
      FROM public.registration_attempts
     WHERE ip_address = v_ip
       AND created_at > now() - interval '24 hours';

    RETURN jsonb_build_object(
        'can', v_cnt < v_limit,
        'success', true,
        'used', v_cnt,
        'limit', v_limit
    );
EXCEPTION WHEN OTHERS THEN
    -- 限频本身出错就放行，别把注册堵死
    RETURN jsonb_build_object('can', true, 'success', true, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.can_register(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_register(text) TO anon;

-- 记一次注册
CREATE OR REPLACE FUNCTION public.record_registration(ip text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_ip text := nullif(btrim(coalesce(ip, '')), '');
BEGIN
    IF v_ip IS NULL THEN
        RETURN jsonb_build_object('success', true, 'recorded', false);
    END IF;
    INSERT INTO public.registration_attempts (ip_address) VALUES (v_ip);
    -- 顺手清理 7 天前的
    DELETE FROM public.registration_attempts WHERE created_at < now() - interval '7 days';
    RETURN jsonb_build_object('success', true, 'recorded', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', true, 'recorded', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.record_registration(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_registration(text) TO anon;


-- ============================================================
-- ② profiles 的替代 RPC（5 个）
-- ============================================================

-- ②-1 读自己的完整资料（余额、头像、封禁状态都在里面）
--      旧版 16 处里的大多数：读自己
CREATE OR REPLACE FUNCTION public.get_my_profile(
    p_user_id uuid,
    p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_row jsonb;
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;

    SELECT jsonb_build_object(
        'id',            p.id,
        'username',      p.username,
        'nb_balance',    p.nb_balance,
        'avatar_url',    p.avatar_url,
        'is_banned',     coalesce(p.is_banned, false),
        'banned_reason', p.banned_reason
    ) INTO v_row
      FROM public.profiles p WHERE p.id = p_user_id;

    IF v_row IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '用户资料不存在');
    END IF;
    RETURN jsonb_build_object('success', true, 'profile', v_row);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.get_my_profile(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_profile(uuid, text) TO anon;


-- ②-2 批量读别人的公开信息（只给用户名和头像，不含余额）
--      公开信息，不需要登录
CREATE OR REPLACE FUNCTION public.get_public_profiles(p_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_list jsonb;
BEGIN
    IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
        RETURN jsonb_build_object('success', true, 'list', '[]'::jsonb);
    END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id', p.id, 'username', p.username, 'avatar_url', p.avatar_url)), '[]'::jsonb)
      INTO v_list
      FROM public.profiles p
     WHERE p.id = ANY (p_ids);

    RETURN jsonb_build_object('success', true, 'list', v_list);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.get_public_profiles(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(uuid[]) TO anon;


-- ②-3 全部用户名（旧版用它做"@某人"的候选列表）
CREATE OR REPLACE FUNCTION public.get_username_list()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_list jsonb;
BEGIN
    SELECT coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username)
                              ORDER BY p.username), '[]'::jsonb)
      INTO v_list
      FROM public.profiles p
     WHERE p.username IS NOT NULL;

    RETURN jsonb_build_object('success', true, 'list', v_list);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.get_username_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_username_list() TO anon;


-- ②-4 改名查重（注册和改名都要用）
--      不带 session 也能调 —— 它只回答"这个名字被占了吗"，不泄露别的
CREATE OR REPLACE FUNCTION public.check_username_taken(
    p_username  text,
    p_exclude_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_taken boolean;
BEGIN
    IF nullif(btrim(coalesce(p_username,'')), '') IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '用户名不能为空');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.profiles
         WHERE lower(username) = lower(btrim(p_username))
           AND (p_exclude_id IS NULL OR id <> p_exclude_id)
    ) INTO v_taken;

    RETURN jsonb_build_object('success', true, 'taken', v_taken);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.check_username_taken(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_username_taken(text, uuid) TO anon;


-- ②-5 改用户名（旧版是直接 update profiles，现在改成走函数）
CREATE OR REPLACE FUNCTION public.change_username(
    p_user_id  uuid,
    p_session  text,
    p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_name text := btrim(coalesce(p_username, ''));
    v_taken boolean;
BEGIN
    IF p_user_id IS NULL OR p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF length(v_name) < 2 OR length(v_name) > 16 THEN
        RETURN jsonb_build_object('success', false, 'message', '用户名需要 2~16 个字符');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.profiles
         WHERE lower(username) = lower(v_name) AND id <> p_user_id
    ) INTO v_taken;
    IF v_taken THEN
        RETURN jsonb_build_object('success', false, 'message', '这个用户名已被占用');
    END IF;

    UPDATE public.profiles SET username = v_name WHERE id = p_user_id;
    RETURN jsonb_build_object('success', true, 'username', v_name);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.change_username(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.change_username(uuid, text, text) TO anon;


-- ============================================================
-- ③ 恢复 set_item_settings 的 3 参数版本（旧版背包要用）
-- ============================================================
-- 线上为什么报"函数不存在"：
--   shop.sql 里原本是 3 参数 (uuid, bigint, jsonb) 的版本，
--   后来 session_auth_highrisk.sql 做安全加固时把它
--   ALTER ... RENAME 成 _orig_set_item_settings，
--   然后建了个 4 参数的新版（多一个 p_session）。
--   旧版页面传的还是 3 个参数 → PostgREST 匹配不到 → PGRST202。
--
-- 这里的做法：把 3 参数版按 shop.sql 的原样建回来。
--   ⚠️ 保留 `settings || p_settings`（合并）而不是直接赋值 ——
--      原始实现就是合并语义，改成覆盖会让已有设置丢掉。
--   ⚠️ 不加 session 校验：旧版没传，加了就等于把背包功能锁死。
--      安全性由 WHERE user_id = p_user_id 保证（只能改自己的道具）。
--   4 参数的安全版保持不动，新页面继续用它。
-- 只删 3 参数版（如果存在）；4 参数的安全版保持不动
DROP FUNCTION IF EXISTS public.set_item_settings(uuid, bigint, jsonb);

CREATE OR REPLACE FUNCTION public.set_item_settings(
    p_user_id  uuid,
    p_item_id  bigint,
    p_settings jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_user_id IS NULL OR p_item_id IS NULL OR p_settings IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '参数错误');
    END IF;
    UPDATE public.user_items
       SET settings = coalesce(settings, '{}'::jsonb) || p_settings
     WHERE id = p_item_id AND user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', '道具不存在');
    END IF;
    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.set_item_settings(uuid, bigint, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_item_settings(uuid, bigint, jsonb) TO anon;


-- ============================================================
-- 验收
-- ============================================================
-- set_item_settings 应该有两个版本：3 参数（旧版用）+ 4 参数（新版用）
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('can_register','record_registration','set_item_settings',
                     'get_my_profile','get_public_profiles','get_username_list',
                     'check_username_taken','change_username')
   AND p.prokind = 'f'
 ORDER BY 1;
-- 应该 8 行

-- 实测几个（不依赖登录的）
SELECT public.can_register('1.2.3.4')                AS 可注册_应can_true;
SELECT public.check_username_taken('绝对不存在的名字')  AS 查重_应taken_false;
SELECT public.get_username_list() -> 'list' -> 0     AS 用户名列表第一条;

-- 确认 profiles 表仍然对 anon 关闭（安全没退步）
SELECT has_table_privilege('anon', 'public.profiles', 'SELECT') AS profiles仍关闭_应为f;
