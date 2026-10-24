-- ============================================================
--  AI 问答的用量计数（每 IP 每天 5 次 + 全站每天总额度）
--
--  为什么要落库：
--      SCF 里的内存限频（_rt_check）是【进程内】的 ——
--      冷启动就清零、多实例之间也不共享。
--      用它挡「每分钟 N 次」可以，但挡不了「每 IP 每天 5 次」：
--      换个实例、或者等冷启动，计数就没了。
--
--      而 NVIDIA NIM 的免费额度是【1,000 次总量】，
--      被人钻一次空子就烧掉一截，烧完就是烧完了。
--
--      所以按天的计数必须写进数据库。
--
--  设计：
--      ai_usage 每调一次插一行（存 IP 的哈希，不存明文）
--      bump_ai_usage   先查再插，原子化（按 IP 加 advisory lock）
--      refund_ai_usage 调用失败时把这行标记成已退款 —— 不占额度
--                      ⚠️ 这条是吸取「发验证码失败也吃额度」那个教训：
--                         失败的调用不该算在用户头上。
--
--  ⚠️⚠️ 这份脚本【只建表】。三个函数在下一份里：
--        ai_usage_per_ip_and_user_20261023.sql
--      原来这里也定义了一份 bump_ai_usage（5 个参数的旧签名），
--      后来限额改成「每 IP + 每用户」双维度，签名变成 8 个参数。
--      如果两份都保留定义，重跑这一份就会【多出一个 5 参数的重载】，
--      而 PostgREST 是按参数名匹配的 —— 两个重载并存时可能挑中旧的，
--      p_user_id 被静默丢掉，「每用户 5 次」那道限制就悄悄失效了。
--      （这个坑本站踩过一次：use_checkin_fix 的补签卡被别人用掉。）
--      所以这里把旧签名整个删掉，只保留建表部分。
--
--  跑的顺序：先这一份，再 ai_usage_per_ip_and_user_20261023.sql。
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步：建表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_usage (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    day          date        NOT NULL,               -- 按北京时间算的日期
    ip_hash      text        NOT NULL,               -- sha256(ip + 盐) 前 24 位，不存明文 IP
    model        text,                               -- 用的哪个模型
    question_len int,                                -- 问题多少字（便于以后看用量）
    answer_len   int,                                -- 回答多少字
    created_at   timestamptz NOT NULL DEFAULT now(),
    refunded_at  timestamptz                         -- 非空 = 这次不算额度（调用失败的）
);

CREATE INDEX IF NOT EXISTS ai_usage_day_ip_idx ON public.ai_usage (day, ip_hash);
CREATE INDEX IF NOT EXISTS ai_usage_day_idx    ON public.ai_usage (day);

COMMENT ON TABLE  public.ai_usage             IS 'AI 问答用量：每调一次一行，用于按 IP/按天限流';
COMMENT ON COLUMN public.ai_usage.ip_hash     IS 'IP 的哈希，不是明文 —— 只用于计数，不用于追踪';
COMMENT ON COLUMN public.ai_usage.refunded_at IS '非空表示这次调用失败了，不计入额度';

-- 锁死：只允许 SECURITY DEFINER 的函数读写，anon / authenticated 直接访问一律失败
ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ai_usage_no_public ON public.ai_usage;
CREATE POLICY ai_usage_no_public ON public.ai_usage
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);


-- ============================================================
-- 第 3 步：refund_ai_usage —— 调用失败就还回去
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
    SELECT value INTO v_val FROM public.admin_settings WHERE key = 'mail_secret';
    IF v_val IS NULL OR p_secret IS NULL OR v_val <> p_secret THEN
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
-- 第 4 步：只读的用量查询（给自己看，看额度还剩多少）
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
BEGIN
    SELECT value INTO v_val FROM public.admin_settings WHERE key = 'mail_secret';
    IF v_val IS NULL OR p_secret IS NULL OR v_val <> p_secret THEN
        RETURN jsonb_build_object('ok', false, 'message', '密钥不匹配');
    END IF;

    SELECT count(*) FILTER (WHERE refunded_at IS NULL),
           count(*) FILTER (WHERE refunded_at IS NOT NULL),
           count(DISTINCT ip_hash) FILTER (WHERE refunded_at IS NULL)
      INTO v_total, v_refund, v_ips
      FROM public.ai_usage
     WHERE day = v_day;

    RETURN jsonb_build_object('ok', true, 'day', v_day,
                              'used', v_total, 'refunded', v_refund, 'unique_ips', v_ips);
END
$fn$;


-- ============================================================
-- 第 5 步：权限 —— 只让服务端角色调
-- ============================================================
REVOKE ALL ON FUNCTION public.refund_ai_usage(bigint, text)               FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_ai_usage_today(text)                    FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.refund_ai_usage(bigint, text)             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_ai_usage_today(text)                  TO anon, authenticated;
-- ⚠️ 虽然给了 anon 执行权，但三个函数都要 p_secret 才能动 —— 
--    密钥只在 SCF 的环境变量里，浏览器拿不到。


-- ============================================================
-- 第 6 步：验收
-- ============================================================
-- 6.1 表建好了吗
SELECT column_name AS 列名, data_type AS 类型, is_nullable AS 可空
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'ai_usage'
 ORDER BY ordinal_position;

-- 6.2 两个函数都在吗
--     ⚠️ 这一份只建 refund_ai_usage 和 get_ai_usage_today。
--        bump_ai_usage 在下一份（ai_usage_per_ip_and_user_20261023.sql）里，
--        所以这里现在只会查出 2 行 —— 是正常的。
--        两份都跑完之后再查，应该是 3 行。
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('bump_ai_usage', 'refund_ai_usage', 'get_ai_usage_today')
 ORDER BY 1;

-- 6.3 今天的用量（刚建表，应该是 0）
SELECT * FROM public.get_ai_usage_today(
    (SELECT value FROM public.admin_settings WHERE key = 'mail_secret'));


-- ============================================================
--  跑完之后
-- ============================================================
--  · 每人（每 IP）每天 5 次
--  · 全站每天 60 次封顶 —— ⚠️ 这是保护那 1,000 次免费额度用的
--      1,000 ÷ 60 ≈ 16 天就能烧完，如果有人天天来问
--      ⚠️ 觉得太猛就把 60 调小，或者把 p_global 改成 30
--  · 调用失败（NIM 报错、超时）会自动退款，不占用户额度
--  · 存的是 IP 哈希，不是明文
--
--  ⚠️ 改额度：
--      每 IP 每天 5 次  → SCF 里的 AI_PER_IP_PER_DAY
--      全站每天 60 次   → SCF 里的 AI_GLOBAL_PER_DAY
--      两个都在代码里，改完重新部署
-- ============================================================
