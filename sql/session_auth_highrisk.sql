-- ============================================================
-- NB频道 - 高危函数会话校验包裹(修复冒仿漏洞 · 第二层)
-- 前置:先执行 session_auth.sql
-- 说明:原函数改名 _orig_*,新同名函数增加 p_session 校验后转调原函数
-- 只执行一次;如需重新生成,先删除对应 _orig_* 与新同名函数再跑
-- ============================================================

-- ----- update_bio -----
ALTER FUNCTION public.update_bio(uuid, text) RENAME TO _orig_update_bio;
CREATE OR REPLACE FUNCTION public.update_bio(p_user_id uuid, p_bio text, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_update_bio(p_user_id, p_bio);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.update_bio(uuid, text, text) TO anon;

-- ----- bankrupt_company -----
ALTER FUNCTION public.bankrupt_company(uuid) RENAME TO _orig_bankrupt_company;
CREATE OR REPLACE FUNCTION public.bankrupt_company(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_bankrupt_company(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.bankrupt_company(uuid, text) TO anon;

-- ----- transfer_nb -----
ALTER FUNCTION public.transfer_nb(uuid, uuid, integer) RENAME TO _orig_transfer_nb;
CREATE OR REPLACE FUNCTION public.transfer_nb(p_from uuid, p_to uuid, p_amount integer, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_from, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_transfer_nb(p_from, p_to, p_amount);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.transfer_nb(uuid, uuid, integer, text) TO anon;

-- ----- claim_redpacket -----
ALTER FUNCTION public.claim_redpacket(bigint, uuid) RENAME TO _orig_claim_redpacket;
CREATE OR REPLACE FUNCTION public.claim_redpacket(p_transfer_id bigint, p_user uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_claim_redpacket(p_transfer_id, p_user);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.claim_redpacket(bigint, uuid, text) TO anon;

-- ----- do_check_in -----
ALTER FUNCTION public.do_check_in(uuid) RENAME TO _orig_do_check_in;
CREATE OR REPLACE FUNCTION public.do_check_in(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_do_check_in(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.do_check_in(uuid, text) TO anon;

-- ----- do_lottery -----
ALTER FUNCTION public.do_lottery(uuid) RENAME TO _orig_do_lottery;
CREATE OR REPLACE FUNCTION public.do_lottery(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_do_lottery(p_user_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.do_lottery(uuid, text) TO anon;

-- ----- buy_shop_item -----
ALTER FUNCTION public.buy_shop_item(uuid, text) RENAME TO _orig_buy_shop_item;
CREATE OR REPLACE FUNCTION public.buy_shop_item(p_user_id uuid, p_item_key text, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_buy_shop_item(p_user_id, p_item_key);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.buy_shop_item(uuid, text, text) TO anon;

-- ----- sell_shop_item -----
ALTER FUNCTION public.sell_shop_item(uuid, text, integer) RENAME TO _orig_sell_shop_item;
CREATE OR REPLACE FUNCTION public.sell_shop_item(p_user_id uuid, p_item_key text, p_quantity integer DEFAULT 1, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_sell_shop_item(p_user_id, p_item_key, p_quantity);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.sell_shop_item(uuid, text, integer, text) TO anon;

-- ----- use_shop_item -----
ALTER FUNCTION public.use_shop_item(uuid, bigint) RENAME TO _orig_use_shop_item;
CREATE OR REPLACE FUNCTION public.use_shop_item(p_user_id uuid, p_item_id bigint, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_use_shop_item(p_user_id, p_item_id);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.use_shop_item(uuid, bigint, text) TO anon;

-- ----- set_item_settings -----
ALTER FUNCTION public.set_item_settings(uuid, bigint, jsonb) RENAME TO _orig_set_item_settings;
CREATE OR REPLACE FUNCTION public.set_item_settings(p_user_id uuid, p_item_id bigint, p_settings jsonb, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RAISE EXCEPTION '鉴权失败:会话无效或无权操作,请重新登录';
    END IF;
    RETURN public._orig_set_item_settings(p_user_id, p_item_id, p_settings);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.set_item_settings(uuid, bigint, jsonb, text) TO anon;

