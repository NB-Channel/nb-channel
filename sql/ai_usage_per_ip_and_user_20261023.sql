-- ============================================================
--  AI 限额改成「每 IP + 每用户，各自每天 5 次」
--
--  站长说：「改成每IP每用户一天5次」
--
--  ── 和上一版的差别 ──
--  上一版：只看 IP 哈希，每 IP 每天 5 次
--  这一版：两个维度都算，都要满足
--
--      ① user_id（登录了才有）  每天 5 次
--      ② ip_hash                每天 5 次
--      ③ 全站总闸              每天 60 次
--      ④ 内存限频              60 秒 3 次（在 SCF 里，不在库里）
--
--  ── 为什么要两个维度都算 ──
--      只按 IP  → 换个网就重置 ✗（手机切流量）
--      只按用户 → 一个人注册一堆小号，每个号 5 次 ✗
--      两个都算 → 换网也受用户限制，注册小号也受 IP 限制 ✓
--
--  ── ⚠️ 没登录怎么办 ──
--      没登录 = 只算 IP（每天 5 次）。
--      ⚠️ 但绝不能不验 session 就认 user_id：
--         随便传个 uuid 就能骗到一份新额度 ✗
--      所以：带了 user_id 就必须带对 session，验不过直接拒。
--
--  ── ⚠️ 一个实际代价（要你自己权衡） ──
--      学校 / 家里共用一条网的学生，IP 是同一个。
--      IP 那道 5 次是他们【共享】的 —— 5 个人一共只有 5 次。
--      如果觉得太紧，把 AI_PER_IP_PER_DAY 调大（比如 20），
--      用户那道仍然是 5，两个各管各的。
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：确认上一份脚本已经跑过
--   这个脚本第 1 步要 ALTER 一张表，表不存在的话 Postgres 只会
--   吐一句 "relation public.ai_usage does not exist"，看不出该干什么。
--   这里提前拦一下，把话说清楚。
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'public' AND table_name = 'ai_usage'
    ) THEN
        RAISE EXCEPTION '先跑 ai_usage_limit_20261023.sql 建表，再跑这一份';
    END IF;
END $$;


-- ============================================================
-- 第 1 步：给 ai_usage 加 user_id 列
-- ============================================================
ALTER TABLE public.ai_usage
    ADD COLUMN IF NOT EXISTS user_id uuid;      -- 登录用户；NULL = 匿名，只按 IP 算

CREATE INDEX IF NOT EXISTS ai_usage_day_user_idx ON public.ai_usage (day, user_id);

COMMENT ON COLUMN public.ai_usage.user_id IS '登录用户的 id；NULL 表示匿名（只按 IP 计数）';


-- ============================================================
-- 第 2 步：删掉旧签名的 bump_ai_usage
-- ------------------------------------------------------------
-- ⚠️ 必须先删。
--    新版参数变多了，直接 CREATE OR REPLACE 会【多出一个重载】，
--    而 PostgREST 是按参数名匹配的 —— 两个重载同时存在时，
--    它可能挑中旧的那个，参数被静默丢掉，限流直接失效。
--    这个坑在本站已经踩过一次（use_checkin_fix），这里显式删掉。
-- ============================================================
DROP FUNCTION IF EXISTS public.bump_ai_usage(text, int, int, text, text);


-- ============================================================
-- 第 3 步：新版 bump_ai_usage —— 双维度
-- ============================================================
CREATE OR REPLACE FUNCTION public.bump_ai_usage(
    p_ip_hash  text,
    p_user_id  uuid DEFAULT NULL,
    p_session  text DEFAULT NULL,
    p_per_ip   int  DEFAULT 5,
    p_per_user int  DEFAULT 5,
    p_global   int  DEFAULT 60,
    p_model    text DEFAULT NULL,
    p_secret   text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_day    date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_val    text;
    v_ip     int := 0;
    v_user   int := 0;
    v_global int := 0;
    v_id     bigint;
    -- ⚠️ 三个额度用【局部变量】而不是直接改参数。
    --    plpgsql 里给 IN 参数赋值虽然一般可以，但没必要冒这个险；
    --    而且写成局部变量之后，下面 COALESCE 读的是参数、不是自己，
    --    不会出现「读到还没赋值的 NULL」这种坑。
    v_per_ip   int;
    v_per_user int;
    v_cap      int;
BEGIN
    -- ① 密钥校验：只有本站后端能调（复用 admin_settings.mail_secret）
    --    ⚠️ 加了 length(v_val) < 8 —— 万一 admin_settings 里 mail_secret 被
    --       清成了空串，原来那句 v_val <> p_secret 会变成 '' <> '' = false，
    --       于是【空密钥也能通过】，任何人都能直接调这个函数烧额度。
    --       现在空串 / 太短的密钥一律拒，fail closed。
    SELECT value INTO v_val FROM public.admin_settings WHERE key = 'mail_secret';
    IF v_val IS NULL OR length(v_val) < 8
       OR p_secret IS NULL OR v_val <> p_secret THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'secret',
                                  'message', '密钥不匹配');
    END IF;

    -- ①.5 把三个额度夹回合理范围
    --     ⚠️ 这三个值是调用方（SCF）传进来的。虽然只有带密钥的人能传，
    --        但万一哪天 SCF 里写错一个数（比如 0 或者 999999），
    --        限流会直接失效或者变成完全不能用。
    --        在这里兜一层，最坏情况也不至于把 1,000 次额度一口气放光。
    v_per_ip   := LEAST(GREATEST(COALESCE(p_per_ip,   5), 1), 200);
    v_per_user := LEAST(GREATEST(COALESCE(p_per_user, 5), 1), 200);
    v_cap   := LEAST(GREATEST(COALESCE(p_global,  60), 1), 100000);

    IF p_ip_hash IS NULL OR length(p_ip_hash) < 8 THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'bad_ip',
                                  'message', '参数错误');
    END IF;

    -- ② 带了 user_id 就必须带对 session
    --    ⚠️ 不验的话，随便传个 uuid 就能骗一份新额度
    IF p_user_id IS NOT NULL THEN
        IF NOT public._user_ok(p_user_id, p_session) THEN
            RETURN jsonb_build_object('ok', false, 'reason', 'auth',
                                      'message', '登录已过期，请重新登录');
        END IF;
    END IF;

    -- ③ 加锁：先 IP、后用户 —— 固定顺序，避免两个请求交叉加锁死锁
    PERFORM pg_advisory_xact_lock(hashtext('ai:' || p_ip_hash));
    IF p_user_id IS NOT NULL THEN
        PERFORM pg_advisory_xact_lock(hashtext('aiu:' || p_user_id::text));
    END IF;

    -- ④ IP 维度
    SELECT count(*) INTO v_ip
      FROM public.ai_usage
     WHERE day = v_day AND ip_hash = p_ip_hash AND refunded_at IS NULL;

    IF v_ip >= v_per_ip THEN
        RETURN jsonb_build_object(
            'ok', false, 'reason', 'ip_limit',
            'ip_used', v_ip, 'ip_limit', v_per_ip, 'left', 0,
            'message', format('这个网络今天已经问了 %s 次（每天上限 %s 次），明天再来', v_ip, v_per_ip));
    END IF;

    -- ⑤ 用户维度（登录了才有这一道）
    IF p_user_id IS NOT NULL THEN
        SELECT count(*) INTO v_user
          FROM public.ai_usage
         WHERE day = v_day AND user_id = p_user_id AND refunded_at IS NULL;

        IF v_user >= v_per_user THEN
            RETURN jsonb_build_object(
                'ok', false, 'reason', 'user_limit',
                'user_used', v_user, 'user_limit', v_per_user, 'left', 0,
                'message', format('你今天已经问了 %s 次（每天上限 %s 次），明天再来', v_user, v_per_user));
        END IF;
    END IF;

    -- ⑥ 全站总闸 —— 保护那 1,000 次免费额度
    --
    --    ⚠️⚠️ 这里【绝对不能】加 `AND refunded_at IS NULL`。
    --
    --    退款的语义是「把用户那 5 次还给他」，不是「这次调用没发生过」。
    --    NIM 那边已经被调用了、credit 已经被扣了。
    --
    --    如果总闸也把退款的不算，攻击者只要让每次调用都失败
    --    （问一个必然触发截断的长问题、或者触发内容过滤），
    --    就能：占名额 → 调 NIM（真扣 credit）→ 失败 → 退款 → 名额回滚，
    --    然后无限重复。按内存限频 3 次/分钟算，一小时就能把
    --    1,000 次免费额度全部烧光，而且全站计数一直是 0 —— 表面上看不出来。
    --
    --    所以两个维度的口径不同：
    --        用户维度  → 只看成功的（refunded_at IS NULL）
    --        全站总闸  → 看【真正发出的调用次数】，退款也算
    SELECT count(*) INTO v_global
      FROM public.ai_usage
     WHERE day = v_day;

    IF v_global >= v_cap THEN
        RETURN jsonb_build_object(
            'ok', false, 'reason', 'global_limit',
            'global_used', v_global, 'global_limit', v_cap,
            'message', '今天站里的 AI 额度用完了，明天再来');
    END IF;

    -- ⑦ 占一个名额
    INSERT INTO public.ai_usage (day, ip_hash, user_id, model)
    VALUES (v_day, p_ip_hash, p_user_id, p_model)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object(
        'ok',          true,
        'usage_id',    v_id,
        'logged_in',   p_user_id IS NOT NULL,
        -- 剩余次数取两个维度里小的那个
        'left',        LEAST(v_per_ip - v_ip - 1,
                             CASE WHEN p_user_id IS NULL THEN 999999
                                  ELSE v_per_user - v_user - 1 END),
        'ip_left',     v_per_ip - v_ip - 1,
        'user_left',   CASE WHEN p_user_id IS NULL THEN NULL
                            ELSE v_per_user - v_user - 1 END,
        'global_left', v_cap - v_global - 1);
END
$fn$;


-- ============================================================
-- 第 3.5 步：refund_ai_usage 也补上空密钥的防护
--   （它定义在 ai_usage_limit_20261023.sql 里，这里覆盖一遍）
-- ============================================================
CREATE OR REPLACE FUNCTION public.refund_ai_usage(
    p_id     bigint,
    p_secret text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_val text;
    v_n   int;
BEGIN
    -- ⚠️ 加 length(v_val) < 8 —— 空密钥一律拒（理由见 bump_ai_usage 那段）
    SELECT value INTO v_val FROM public.admin_settings WHERE key = 'mail_secret';
    IF v_val IS NULL OR length(v_val) < 8
       OR p_secret IS NULL OR v_val <> p_secret THEN
        RETURN jsonb_build_object('ok', false, 'message', '密钥不匹配');
    END IF;

    UPDATE public.ai_usage
       SET refunded_at = now()
     WHERE id = p_id AND refunded_at IS NULL;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN jsonb_build_object('ok', true, 'refunded', v_n);
END
$fn$;


-- ============================================================
-- 第 4 步：get_ai_usage_today 顺便把「有几个人用过」也算上
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_ai_usage_today(p_secret text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_val    text;
    v_day    date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_total  int;
    v_refund int;
    v_ips    int;
    v_users  int;
    v_anon   int;
BEGIN
    -- ⚠️ 同样要挡空密钥（见 bump_ai_usage 里那段说明）
    SELECT value INTO v_val FROM public.admin_settings WHERE key = 'mail_secret';
    IF v_val IS NULL OR length(v_val) < 8
       OR p_secret IS NULL OR v_val <> p_secret THEN
        RETURN jsonb_build_object('ok', false, 'message', '密钥不匹配');
    END IF;

    SELECT count(*) FILTER (WHERE refunded_at IS NULL),
           count(*) FILTER (WHERE refunded_at IS NOT NULL),
           count(DISTINCT ip_hash) FILTER (WHERE refunded_at IS NULL),
           count(DISTINCT user_id) FILTER (WHERE refunded_at IS NULL AND user_id IS NOT NULL),
           count(*) FILTER (WHERE refunded_at IS NULL AND user_id IS NULL)
      INTO v_total, v_refund, v_ips, v_users, v_anon
      FROM public.ai_usage
     WHERE day = v_day;

    -- ⚠️ 两个口径不一样，别混：
    --    used     = 成功计入用户额度的次数
    --    calls    = 真正发出过的调用次数（含退款的）—— 这个才对应 NIM 扣了多少 credit
    --    refunded = 调了但失败了、已经把额度还给用户的次数
    RETURN jsonb_build_object('ok', true, 'day', v_day,
                              'used', v_total,
                              'refunded', v_refund,
                              'calls', v_total + v_refund,
                              'unique_ips', v_ips,
                              'unique_users', v_users,
                              'anonymous_calls', v_anon);
END
$fn$;


-- ============================================================
-- 第 5 步：权限
-- ============================================================
REVOKE ALL ON FUNCTION public.bump_ai_usage(text, uuid, text, int, int, int, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bump_ai_usage(text, uuid, text, int, int, int, text, text) TO anon, authenticated;
-- ⚠️ 虽然 anon 能执行，但必须带对 p_secret 才能动


-- ============================================================
-- 第 6 步：验收
-- ============================================================
-- 6.1 确认只有一个 bump_ai_usage 重载（多一个就是坑）
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('bump_ai_usage', 'refund_ai_usage', 'get_ai_usage_today')
 ORDER BY 1, 2;

-- 6.2 ai_usage 的列
SELECT column_name AS 列名, data_type AS 类型, is_nullable AS 可空
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'ai_usage'
 ORDER BY ordinal_position;

-- 6.3 今天的用量
SELECT * FROM public.get_ai_usage_today(
    (SELECT value FROM public.admin_settings WHERE key = 'mail_secret'));


-- ============================================================
--  跑完之后
-- ============================================================
--  · 登录用户：用户维度 5 次/天 + IP 维度 5 次/天，都要满足
--  · 匿名用户：只算 IP 维度 5 次/天
--  · 全站：60 次/天
--
--  ⚠️ 学校 / 家里共用一条网的，IP 那 5 次是共享的。
--     觉得紧就把 SCF 里的 AI_PER_IP_PER_DAY 调大（用户那道仍是 5）。
--
--  ⚠️ 前端要跟着改：
--     调 /api/ai 的时候把 user_id 和 session 一起传上来，
--     不传就是匿名，只受 IP 限制。
-- ============================================================
