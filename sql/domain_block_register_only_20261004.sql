-- ============================================================
-- 临时邮箱域名黑名单：改成【只挡注册，不挡登录】
-- ============================================================
--
-- 【为什么要改】
-- 登录是三步：
--     ① login_user2(用户名, 密码)      只回答密码对不对，不给令牌
--     ② store_email_code(邮箱, 'login') 发验证码   ← 这里查域名黑名单
--     ③ login_finish(用户名, 验证码)    才签发令牌
--
-- 如果 store_email_code 对所有 purpose 都查域名黑名单，那么：
--     已经用临时邮箱注册的老账号 →
--         第一步密码能过，第二步发不出验证码 → 卡死
--         → 登不进去 → 也换不了邮箱 → 【永久锁死】
--
-- 实际会中招的账号（截至 2026-10-04）：
--     Utw小号                utwxh@ozsaip.com
--     Utw的小NB肉餐厅官号      utwnb@ozsaip.com
--     Utvv                   utvv@ozsaip.com
--     Utw的3ty肉餐厅官号       utw3ty@ozsaip.com
--     Utw的皓宸肉餐厅官号       utwhc@ozsaip.com
--     小NB3                  jv3injt2hu@ozsaip.com
--     氟19                    awm@ozsaip.com
--     NB科技小琪官号           m2un9zaaqr@yzcalo.com
--     NB科技小琪官方           cf7zzlmbnk@ozsaip.com
--   → Utw 那五个号加起来持有「Utw」公司的绝大部分股份，
--     锁死了等于把公司也锁死了。
--
-- 【改成什么】
--     purpose = 'register'  →  查黑名单（挡住用临时邮箱新注册）
--     purpose = 'login'     →  不查（老用户还能进来）
--     purpose = 'bind'      →  不查（他们能换成常用邮箱）
--     purpose = 'admin'     →  不查
--
-- 代价：已经用临时邮箱的老账号，在换邮箱之前【仍然可能被人登进去】。
--       但比"把号主本人也锁在外面"好 —— 至少他们能进去自救。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第 1 步：确认现在的 store_email_code 长什么样
-- ============================================================
SELECT pg_get_functiondef(p.oid) AS store_email_code定义
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'store_email_code';


-- ============================================================
-- 第 2 步：改成按 purpose 区分
-- ------------------------------------------------------------
-- ⚠️ 注意：这个函数里还有「总闸」(mail_secret_required) 和
--    「转交 _orig_store_email_code」两段逻辑，必须【原样保留】，
--    否则邮件就发不出去了。
-- ============================================================
CREATE OR REPLACE FUNCTION public.store_email_code(
    p_email     text,
    p_purpose   text,
    p_code_hash text,
    p_ip        text DEFAULT NULL,
    p_secret    text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_secret text;
    v_need   boolean;
BEGIN
    SELECT value INTO v_secret FROM public.admin_settings WHERE key = 'mail_secret';
    SELECT coalesce(value, '0') = '1' INTO v_need
      FROM public.admin_settings WHERE key = 'mail_secret_required';

    -- 总闸：只有拿得出密钥的调用方（腾讯 SCF）才能发码
    IF coalesce(v_need, false) THEN
        IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
            INSERT INTO public.mail_code_rejects (email, purpose, ip_address, reason)
            VALUES (left(coalesce(p_email, ''), 120), left(coalesce(p_purpose, ''), 20),
                    left(coalesce(p_ip, ''), 60),
                    CASE WHEN p_secret IS NULL THEN '没带密钥' ELSE '密钥不对' END);
            RETURN jsonb_build_object('ok', false, 'message', '未授权的发码请求');
        END IF;
    END IF;

    -- ⭐ 域名黑名单：只对【注册】生效
    --    登录 / 换绑邮箱 都放行 —— 否则用临时邮箱的老账号会被永久锁死
    IF p_purpose = 'register' AND public._email_domain_banned(p_email) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该邮箱域名属于一次性临时邮箱，请使用常用邮箱注册');
    END IF;

    -- 转交原来那个带全部限频逻辑的函数
    RETURN public._orig_store_email_code(p_email, p_purpose, p_code_hash, p_ip);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;


-- ============================================================
-- 第 3 步：验收
-- ============================================================
SELECT CASE
         WHEN pg_get_functiondef(p.oid) LIKE '%p_purpose = ''register'' AND public._email_domain_banned%'
           THEN '✅ 已改成只挡注册'
         WHEN pg_get_functiondef(p.oid) LIKE '%IF public._email_domain_banned(p_email) THEN%'
           THEN '❌ 还是旧版（所有 purpose 都查）'
         ELSE '❓ 认不出，把定义发我'
       END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='store_email_code';

-- 确认总闸那两段还在（不能丢）
SELECT
    (pg_get_functiondef(p.oid) LIKE '%mail_secret_required%')      AS 总闸逻辑还在,
    (pg_get_functiondef(p.oid) LIKE '%mail_code_rejects%')         AS 拒绝记录还在,
    (pg_get_functiondef(p.oid) LIKE '%_orig_store_email_code%')    AS 转交逻辑还在
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public' AND p.proname='store_email_code';


-- ============================================================
-- 第 4 步：现在可以导入域名黑名单了
-- ------------------------------------------------------------
-- 跑 sql/import_disposable_domains_20261004.sql
-- 导入之后：
--     新注册用临时邮箱  →  被挡 ✅
--     老账号登录        →  通 ✅（还能自救换邮箱）
-- ============================================================


-- ============================================================
-- 第 5 步：把受影响的老账号列出来，发个公告提醒他们换邮箱
-- ============================================================
SELECT p.id, p.username, p.email,
       lower(split_part(p.email, '@', 2)) AS 域名,
       p.created_at,
       (SELECT count(*) FROM public.user_companies c WHERE c.founder_id = p.id) AS 名下公司数,
       p.nb_balance AS 余额
  FROM public.profiles p
 WHERE p.email ~* '@(ozsaip|yzcalo|tanpony|bagss)\.'
 ORDER BY p.created_at;

-- ⚠️ 这张表里 Utw 那五个号加起来持有「Utw」公司绝大部分股份 ——
--    提醒他的时候说清楚"换邮箱不影响任何资产，只是把门锁上"。


-- ============================================================
-- 附：如果想一次性帮某个号换掉邮箱（需要他先告诉你新邮箱）
-- ------------------------------------------------------------
-- UPDATE public.profiles SET email = '新邮箱@qq.com', updated_at = now()
--  WHERE id = '要改的号uuid';
--
-- ⚠️ 改完他下次登录就走新邮箱收码了，务必确认邮箱是对的。
-- ============================================================
