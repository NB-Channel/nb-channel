-- ============================================================
-- 让 IP 封禁重新生效 + 恢复注册 IP 日志
--
-- 【问题】小NB2 查不到注册 IP(推测注册IP = null),追下去发现:
--   · registration_attempts(注册 IP 日志)是 PythonAnywhere 后端写的
--     —— 全仓 SQL 里没有任何一条 INSERT 到这张表。
--   · 但 09-09 前后注册流程换成了「邮箱验证码」:前端直接调 Supabase 的
--     register_finish,不再经过后端 → 后端没机会记 IP → 日志从那天起就断了。
--   证据:09-09 之后注册的账号(小NB2 / NBZyh / 1111 / xxm555 / 小NB3ty行政区…)
--         推测注册 IP 全是 null;09-09 之前的(Zhr / Zyh / NB公司 / 穿山甲…)
--         全都有 IP。
--
--   ⚠️ 连带后果:IP 黑名单只由后端在 /api/* 上执行,而注册已经不走后端了
--      → banned_ips 里那 7 条(含攻击者的 4e21::/64)对注册**完全无效**。
--      他 05-17 就被封了网段,今天(09-25)照样注册成功,正是这个原因。
--
-- 【修法】注册 IP 改成在 Supabase 函数内部自己抓:
--   PostgREST 会把请求头放在 request.headers,客户端 IP 在 x-forwarded-for 里。
--   于是 register_finish 现在能自己「记录 IP + 查黑名单」,不再依赖后端。
--
-- 在 Supabase SQL Editor 整段执行(幂等)
-- ============================================================


-- ============================================================
-- ① 取客户端 IP
-- ============================================================
-- x-forwarded-for 可能是 "客户端, 代理1, 代理2" 这样的链。
-- 取法:
--   · 记录时取「最后一个」—— 那是最近一跳代理附加的,最接近真实来源
--   · 拦截时检查「全部元素」—— 客户端可以伪造前面几段,但真实 IP 一定在链里,
--     只查一段会被伪造头绕过
-- 整个函数用异常包住:请求头解析出问题也只是返回空数组,绝不影响注册。
CREATE OR REPLACE FUNCTION public._client_ips()
RETURNS text[]
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    v_h   jsonb;
    v_raw text;
    v_out text[] := ARRAY[]::text[];
    v_x   text;
BEGIN
    BEGIN
        v_h := current_setting('request.headers', true)::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RETURN v_out;
    END;

    IF v_h IS NULL THEN
        RETURN v_out;
    END IF;

    v_raw := coalesce(v_h ->> 'x-forwarded-for', v_h ->> 'cf-connecting-ip');
    IF v_raw IS NULL OR btrim(v_raw) = '' THEN
        RETURN v_out;
    END IF;

    FOREACH v_x IN ARRAY string_to_array(v_raw, ',') LOOP
        v_x := btrim(v_x);
        IF v_x <> '' THEN
            v_out := v_out || v_x;
        END IF;
    END LOOP;

    RETURN v_out;
END
$fn$;

REVOKE ALL ON FUNCTION public._client_ips() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ② 判断 IP 是否被禁(精确匹配 + IPv6 /64 网段匹配)
-- ============================================================
CREATE OR REPLACE FUNCTION public._ip_banned(p_ips text[])
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_ip  text;
    v_p64 text;
BEGIN
    IF p_ips IS NULL OR array_length(p_ips, 1) IS NULL THEN
        RETURN false;   -- 拿不到 IP 时一律放行,绝不误伤正常用户
    END IF;

    FOREACH v_ip IN ARRAY p_ips LOOP
        -- 1) 精确匹配
        IF EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = v_ip) THEN
            RETURN true;
        END IF;

        -- 2) IPv6 /64 网段匹配(黑名单里存成 "2409:8a30:9c84:4e21::/64")
        IF v_ip LIKE '%:%' THEN
            v_p64 := split_part(v_ip, ':', 1) || ':' || split_part(v_ip, ':', 2) || ':'
                  || split_part(v_ip, ':', 3) || ':' || split_part(v_ip, ':', 4);
            IF EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = v_p64 || '::/64') THEN
                RETURN true;
            END IF;
        END IF;
    END LOOP;

    RETURN false;
END
$fn$;

REVOKE ALL ON FUNCTION public._ip_banned(text[]) FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ③ 自检工具:看一眼 Supabase 实际拿到的你的 IP
-- ============================================================
-- 建好后在浏览器控制台(任意 NB频道 页面按 F12)执行:
--     fetch('https://pbaafgjkwdbwcmsikcmg.supabase.co/rest/v1/rpc/debug_my_ip', {
--       method:'POST',
--       headers:{ 'apikey':'sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg',
--                 'Authorization':'Bearer sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg',
--                 'Content-Type':'application/json' },
--       body:'{}'
--     }).then(r=>r.json()).then(console.log)
-- 应该返回你真实的公网 IP。若返回空数组,说明取不到头,先别继续,告诉我。
CREATE OR REPLACE FUNCTION public.debug_my_ip()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_ips text[] := public._client_ips();
BEGIN
    RETURN jsonb_build_object(
        'ips',  to_jsonb(v_ips),
        'last', CASE WHEN array_length(v_ips,1) IS NULL THEN NULL ELSE v_ips[array_length(v_ips,1)] END,
        'banned', public._ip_banned(v_ips)
    );
END
$fn$;

GRANT EXECUTE ON FUNCTION public.debug_my_ip() TO anon;


-- ============================================================
-- ④ 重建 register_finish:记录 IP + 拦截被封 IP
-- ============================================================
-- 原逻辑一字未改,只在最前面插了「记 IP」和「查黑名单」两步。
-- 记 IP 那步用异常包住:表结构若有别的 NOT NULL 列导致写不进去,
-- 只打 WARNING,不影响注册本身。
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
    -- ---------- 新增 1:抓客户端 IP ----------
    v_ips  := public._client_ips();
    v_last := CASE WHEN array_length(v_ips, 1) IS NULL THEN NULL
                   ELSE v_ips[array_length(v_ips, 1)] END;

    -- ---------- 新增 2:记录注册 IP(以前这步是后端做的) ----------
    IF v_last IS NOT NULL THEN
        BEGIN
            INSERT INTO public.registration_attempts (ip_address) VALUES (v_last);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '注册IP记录失败(不影响注册): %', SQLERRM;
        END;
    END IF;

    -- ---------- 新增 3:封禁 IP 直接拒绝 ----------
    IF public._ip_banned(v_ips) THEN
        RETURN jsonb_build_object('ok', false,
               'message', '该网络已被限制注册,如有疑问请联系管理员');
    END IF;

    -- ---------- 以下为原逻辑,未改动 ----------
    v_chk := public._verify_email_code(p_email, 'register', p_code);
    IF NOT (v_chk ->> 'ok')::boolean THEN
        RETURN v_chk;
    END IF;
    -- 邮箱占用
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
    RETURN jsonb_build_object('ok', true, 'id', v_uid);
END
$fn$;

REVOKE ALL ON FUNCTION public.register_finish(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_finish(text, text, text, text) TO anon;


-- ============================================================
-- ⑤ 验收
-- ============================================================
-- 1) 三个函数是否就位(都应返回 true)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%_client_ips%') AS 已抓IP,
       (pg_get_functiondef(p.oid) LIKE '%banned_ips%')  AS 已查黑名单
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('register_finish', '_client_ips', '_ip_banned')
 ORDER BY 1;

-- 2) registration_attempts 表结构(万一第 ④ 步刷出 WARNING,把这里的结果贴我)
SELECT column_name AS 列, data_type AS 类型, is_nullable AS 可空, column_default AS 默认值
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'registration_attempts'
 ORDER BY ordinal_position;

-- 3) 日志是否恢复:现在这张表最新一条是什么时候
--    (跑完本文件后,你自己去注册页走一遍,再跑这条应该能看到新记录)
SELECT count(*) AS 总条数, max(created_at) AS 最新一条
  FROM public.registration_attempts;

-- 4) 确认注册接口没被改坏(仍有 anon 执行权限)
SELECT has_function_privilege('anon', 'public.register_finish(text,text,text,text)', 'EXECUTE') AS anon可注册;

-- 5) 当前黑名单(封禁语句由第 ⑥ 步生成)
SELECT id, ip, reason, created_at FROM public.banned_ips ORDER BY id;


-- ============================================================
-- ⑥ 补封小NB2 的网段(等他下次注册失败时,日志里就能看到他的 IP 了)
-- ============================================================
-- 说明:小NB2 的注册 IP 已经无从考证(日志当时就是断的),所以只能等下次。
-- 他再来注册时:会被 ④ 的拦截挡住吗?
--   · 若他用的是已经被封的 4e21::/64  → 这次直接就注册不成了 ✓
--   · 若他用新网段                    → 注册能过,但 ⑤-3 的日志会记下 IP,
--                                        你把它贴我(或自己按下面格式加一条)即可
--
-- 加一条网段封禁的格式(把 <前缀> 换成查到的前 4 段,例如 2409:8a30:9c84:abcd):
-- INSERT INTO public.banned_ips (ip, reason)
-- VALUES ('<前缀>::/64', '小NB2 注册来源网段')
-- ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;
