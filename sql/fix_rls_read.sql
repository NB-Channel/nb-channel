-- ============================================================
-- NB频道 - profiles 读取收口 v3(匿名只能读公开列)
-- 前置:已执行 fix_rls_emergency.sql
-- 效果:
--   email / nb_balance 等敏感列匿名不可读(SELECT * 也不返回)
--   公开列(头像/昵称/注册时间/简介/封禁标记)保持可读,主页不坏
-- 预期影响:顶部"💰 NB币"余额栏显示 --(页面 catch 忽略),
--   余额将改用 get_my_balance RPC 后恢复;其它功能不受影响。
-- ============================================================

-- 1) 撤销 profiles 表级匿名读
REVOKE SELECT ON public.profiles FROM anon;

-- 2) 只放行公开列(白名单;email/余额等一律不外泄)
GRANT SELECT (id, username, avatar_url, created_at, bio, is_banned, banned_reason)
    ON public.profiles TO anon;

-- 3) 余额读取专用 RPC(需登录令牌;替代前端直查 nb_balance)
CREATE OR REPLACE FUNCTION public.get_my_balance(p_user_id uuid, p_session text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_balance numeric;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:请重新登录');
    END IF;
    SELECT nb_balance INTO v_balance FROM public.profiles WHERE id = p_user_id;
    RETURN jsonb_build_object('ok', true, 'balance', v_balance);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.get_my_balance(uuid, text) TO anon;

-- ============================================================
-- (待办,勿执行)敏感表整表 SELECT 收口 + 读函数令牌化,
-- 将随 session_auth_highrisk_read.sql 一起下发,不要手动执行!
-- ============================================================
-- REVOKE SELECT ON public.bank_accounts, public.bank_logs, public.holdings,
--     public.transfers, public.lottery_records, public.user_titles,
--     public.user_achievements, public.transactions, public.product_purchases,
--     public.conversations, public.messages FROM anon;

