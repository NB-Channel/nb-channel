-- ============================================================
-- NB频道 - 读取/检查类函数令牌化(修复冒仿 · 第二批包裹)
-- 前置:session_auth.sql + session_auth_highrisk.sql
-- 只执行一次;重新生成前先删除 _orig_* 与新同名函数
-- ============================================================

-- ----- get_bank_account -----
ALTER FUNCTION public.get_bank_account(uuid) RENAME TO _orig_get_bank_account;
CREATE OR REPLACE FUNCTION public.get_bank_account(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_get_bank_account(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_bank_account(uuid, text) TO anon;

-- ----- get_bank_logs -----
ALTER FUNCTION public.get_bank_logs(uuid, integer) RENAME TO _orig_get_bank_logs;
CREATE OR REPLACE FUNCTION public.get_bank_logs(p_user_id uuid, p_limit integer DEFAULT 30, p_session text DEFAULT NULL)
RETURNS TABLE (type text, amount bigint, detail text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN QUERY SELECT * FROM public._orig_get_bank_logs(p_user_id, p_limit);
    RETURN;
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_bank_logs(uuid, integer, text) TO anon;

-- ----- get_my_items -----
ALTER FUNCTION public.get_my_items(uuid) RENAME TO _orig_get_my_items;
CREATE OR REPLACE FUNCTION public.get_my_items(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_get_my_items(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_my_items(uuid, text) TO anon;

-- ----- get_my_titles -----
ALTER FUNCTION public.get_my_titles(uuid) RENAME TO _orig_get_my_titles;
CREATE OR REPLACE FUNCTION public.get_my_titles(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS TABLE (title_key text, name text, icon text, image_url text, acquire_type text, acquire_desc text, price bigint, star_prices bigint[], star_thresholds bigint[], stars integer, owned boolean, purchased boolean, equipped boolean, equipped_stars integer, current_value bigint, spent bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN QUERY SELECT * FROM public._orig_get_my_titles(p_user_id);
    RETURN;
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_my_titles(uuid, text) TO anon;

-- ----- sync_my_titles -----
ALTER FUNCTION public.sync_my_titles(uuid) RENAME TO _orig_sync_my_titles;
CREATE OR REPLACE FUNCTION public.sync_my_titles(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_sync_my_titles(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.sync_my_titles(uuid, text) TO anon;

-- ----- get_my_achievements -----
ALTER FUNCTION public.get_my_achievements(uuid) RENAME TO _orig_get_my_achievements;
CREATE OR REPLACE FUNCTION public.get_my_achievements(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS TABLE (key text, name text, description text, reward integer, icon text, unlocked boolean, claimed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN QUERY SELECT * FROM public._orig_get_my_achievements(p_user_id);
    RETURN;
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_my_achievements(uuid, text) TO anon;

-- ----- check_achievements -----
ALTER FUNCTION public.check_achievements(uuid) RENAME TO _orig_check_achievements;
CREATE OR REPLACE FUNCTION public.check_achievements(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_check_achievements(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.check_achievements(uuid, text) TO anon;

-- ----- get_my_lottery_records -----
ALTER FUNCTION public.get_my_lottery_records(uuid) RENAME TO _orig_get_my_lottery_records;
CREATE OR REPLACE FUNCTION public.get_my_lottery_records(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS TABLE (id bigint, result text, amount integer, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN QUERY SELECT * FROM public._orig_get_my_lottery_records(p_user_id);
    RETURN;
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_my_lottery_records(uuid, text) TO anon;

-- ----- get_my_transfers -----
ALTER FUNCTION public.get_my_transfers(uuid) RENAME TO _orig_get_my_transfers;
CREATE OR REPLACE FUNCTION public.get_my_transfers(p_user uuid, p_session text DEFAULT NULL)
RETURNS TABLE (direction text, other_username text, amount integer, status text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN QUERY SELECT * FROM public._orig_get_my_transfers(p_user);
    RETURN;
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_my_transfers(uuid, text) TO anon;

-- ----- get_checkin_status -----
ALTER FUNCTION public.get_checkin_status(uuid) RENAME TO _orig_get_checkin_status;
CREATE OR REPLACE FUNCTION public.get_checkin_status(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_get_checkin_status(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_checkin_status(uuid, text) TO anon;

