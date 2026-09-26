-- ============================================================
-- 【安全修复】login_user2 用「密码」直接换令牌 —— 绕过邮箱验证码
-- ============================================================
-- 发现的经过:对方(Utw)发来一个"U币↔NB币 互换"的页面,页面上有
--     <input id="account"> 账号
--     <input id="password" type="text"> 密码(type="text",明文显示)
-- 而前端代码里写着:
--     const S = () => localStorage.getItem('nb_session');
--     NB.改 = (uid, bal) => rpc('set_balance', {p_user_id:uid, p_balance:bal, p_session:S()})
--     window.NB = NB;
-- 也就是:在他域名上收集账号密码 → 换到会话令牌 → 用令牌操作你的账号。
--
-- 实测确认:
--   · set_balance 不存在(他调不通)
--   · profiles.balance 列不存在(他调不通)
--   · 但 login_user2 存在,且【只要密码就签发令牌】← 这个是真的能用
--
-- 根因:session_auth.sql 里的 login_user2 ——
--     v_uid := public.login_user(username, password);
--     RETURN jsonb_build_object('ok', true, 'id', v_uid,
--                               'token', public.create_user_session(v_uid));
--   只要密码正确就签发会话,完全跳过邮箱验证码。
--
-- 这直接违背全站已声明的安全策略(0.9.1 更新日志原文):
--   「新增邮箱验证码:登录、注册、更换绑定邮箱均需邮箱验证码确认,
--     即使密码泄露他人也无法登录」
--
-- ⚠️ 一旦密码泄露(在别人页面上输过一次就算),对方就能拿到完整会话,
--    之后转账、交易、破产公司、改简介……全部可以做。
--
-- 【修法】
--   ① login_user2 不再返回 token,只回答"密码对不对"
--      —— 保留原有的"5 次失败锁 10 分钟"限流(不能覆盖掉)
--   ② 令牌改由 register_finish 签发(注册流程本来就已经验过邮箱验证码,
--      所以那里签发是安全的),这样注册后的自动登录不受影响
--
-- 【影响面】登录页注册后的自动登录已同步改好,不受影响。
--   但【经典模式】的评论区内联登录(根目录 comments.html /
--   comments-beta.html)原本依赖这个令牌,修完会登录不上 ——
--   它们必须改成跳转到登录页(与 Beta 版评论区的做法一致,见末尾说明)。
--
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================


-- ============================================================
-- ① login_user2:保留限流,但不再签发令牌
-- ============================================================
CREATE OR REPLACE FUNCTION public.login_user2(input_username text, input_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $w$
DECLARE
    v_key   text := lower(trim(coalesce(input_username, '')));
    v_fails int;
    v_res   jsonb;
BEGIN
    -- 失败次数限流(保留原有逻辑:10 分钟内错 5 次锁住)
    SELECT count(*) INTO v_fails FROM public.login_attempts
     WHERE lower(username) = v_key AND created_at > now() - interval '10 minutes';
    IF v_fails >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'message', '密码错误次数过多,请 10 分钟后再试');
    END IF;

    v_res := public._orig_login_user2(input_username, input_password);

    IF v_res IS NULL OR (v_res->>'ok') IS DISTINCT FROM 'true' THEN
        INSERT INTO public.login_attempts (username) VALUES (v_key);
        -- 密码错误:照原样返回
        RETURN coalesce(v_res, jsonb_build_object('ok', false, 'message', '用户名或密码错误'));
    END IF;

    DELETE FROM public.login_attempts WHERE lower(username) = v_key;

    -- ✅ 密码正确,但【不再返回 token】
    -- 只告诉前端"密码没问题,请继续走邮箱验证码",由 login_finish 签发令牌。
    RETURN jsonb_build_object(
        'ok', true,
        'id', v_res->>'id',
        'need_code', true,
        'message', '密码正确,请完成邮箱验证码后登录');
END
$w$;

GRANT EXECUTE ON FUNCTION public.login_user2(text, text) TO anon;


-- ============================================================
-- ② register_finish:注册流程已验过邮箱验证码,由它签发令牌
-- ============================================================
-- 原逻辑一字未改,只在成功分支里补一个 token。
-- 这样登录页"注册成功后自动登录"不用再去调 login_user2。
CREATE OR REPLACE FUNCTION public.register_finish(p_username text, p_password text, p_email text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_chk  jsonb;
    v_uid  uuid;
    v_exist uuid;
    v_ips  text[];
    v_last text;
BEGIN
    -- 拦截 1:一次性邮箱域名
    IF public._email_domain_banned(p_email) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该邮箱域名属于一次性临时邮箱,请使用常用邮箱注册');
    END IF;

    -- 拦截 2:被封 IP
    v_ips  := public._client_ips();
    v_last := CASE WHEN array_length(v_ips, 1) IS NULL THEN NULL
                   ELSE v_ips[array_length(v_ips, 1)] END;

    IF v_last IS NOT NULL THEN
        BEGIN
            INSERT INTO public.registration_attempts (ip_address) VALUES (v_last);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '注册IP记录失败(不影响注册): %', SQLERRM;
        END;
    END IF;

    IF public._ip_banned(v_ips) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该网络已被限制注册,如有疑问请联系管理员');
    END IF;

    -- ---------- 原逻辑 ----------
    v_chk := public._verify_email_code(p_email, 'register', p_code);
    IF NOT (v_chk ->> 'ok')::boolean THEN
        RETURN v_chk;
    END IF;
    SELECT id INTO v_exist FROM public.profiles WHERE email = lower(p_email);
    IF v_exist IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱已被注册');
    END IF;
    v_uid := public.register_user(p_username, p_password);
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '用户名已存在或不符合规则');
    END IF;
    BEGIN
        UPDATE public.profiles SET email = lower(p_email) WHERE id = v_uid;
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('ok', false, 'message', '该邮箱已被注册');
    END;

    -- ✅ 新增:注册时已经验过邮箱验证码,这里签发令牌供自动登录
    RETURN jsonb_build_object('ok', true, 'id', v_uid,
                              'token', public.create_user_session(v_uid));
END
$fn$;

REVOKE ALL ON FUNCTION public.register_finish(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_finish(text, text, text, text) TO anon;


-- ============================================================
-- 验收
-- ============================================================
-- 1) login_user2 不应再出现 create_user_session(应返回 false)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%create_user_session%') AS 仍会签发令牌,
       (pg_get_functiondef(p.oid) LIKE '%login_attempts%')      AS 仍有限流
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname = 'login_user2';
-- 期望:仍会签发令牌 = false,仍有限流 = true

-- 2) register_finish 应该会签发令牌(应返回 true)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%create_user_session%') AS 会签发令牌
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname = 'register_finish';
-- 期望:true

-- 3) 实际试一下:用错误密码调 login_user2,确认不再有 token 字段
--    (在 SQL Editor 里直接执行)
SELECT public.login_user2('__不存在的用户__', '__错的密码__') AS 返回值;
-- 期望:{"ok": false, "message": "用户名或密码错误"} —— 没有任何 token


-- ============================================================
-- ⚠️ 还要改前端(不改的话经典模式登录会失效)
-- ============================================================
-- · Beta/login-Beta.html
--     注册成功后的自动登录原本调 login_user2 拿令牌 —— 已改为直接用
--     register_finish 返回的 token。
--
-- · 根目录 comments.html / comments-beta.html(经典模式)
--     它们的内联登录原本靠 login_user2 的 token。修完拿不到令牌了,
--     必须改成跳转到登录页:
--         location.href = 'login-Beta.html?redirect=' + encodeURIComponent(location.href);
--     这与 Beta 版评论区的做法一致(那边早就改过了)。
