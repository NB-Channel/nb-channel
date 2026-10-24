-- ============================================================
-- 自动抄底：把「自动支持」改成「自动买入别人的公司」
-- ============================================================
-- 原来的自动支持 = 给自己的公司注资托底。
-- 但新模型禁止买自己的公司，所以改成：
--
--     盯着某家公司，股价跌到你设的价位时，自动买入一笔。
--
-- 语义变化（要跟玩家说清楚）：
--     旧：给【自己的】公司注资，推高市值
--     新：等【别人的】公司跌到目标价，自动买入
--
-- 不造币：买入就是把钱放进池子，池子是封闭的。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 一、规则表加字段
-- ============================================================
ALTER TABLE public.support_rules
    ADD COLUMN IF NOT EXISTS enabled      boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS price_target numeric,          -- 股价跌到这个数以下就买
    ADD COLUMN IF NOT EXISTS daily_limit  numeric NOT NULL DEFAULT 50000,  -- 每天最多花多少
    ADD COLUMN IF NOT EXISTS today_cash   numeric NOT NULL DEFAULT 0,      -- 今天已花
    ADD COLUMN IF NOT EXISTS today_date   date,                            -- 记账日期
    ADD COLUMN IF NOT EXISTS last_run_at  timestamptz,                      -- 上次触发时间
    ADD COLUMN IF NOT EXISTS min_interval integer NOT NULL DEFAULT 60;      -- 两次触发至少隔多少秒

-- 老的 threshold 字段语义是「市值低于此就支持」，现在改成「股价低于此就买」
-- 但老的 threshold 值可能很大（比如 1000000），在股价尺度（1.00 左右）下永远不触发。
-- 所以迁移时把明显不合理的值重置成 NULL，让用户重新设。
UPDATE public.support_rules
   SET price_target = NULL
 WHERE threshold IS NOT NULL AND threshold > 1000;

COMMENT ON COLUMN public.support_rules.price_target IS '目标股价：跌到此价以下就自动买入';
COMMENT ON COLUMN public.support_rules.daily_limit  IS '每天最多花多少钱（NB币）';
COMMENT ON COLUMN public.support_rules.min_interval IS '两次触发的最小间隔（秒）';


-- ============================================================
-- 二、重写 run_auto_support
-- ============================================================
CREATE OR REPLACE FUNCTION public.run_auto_support()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    r          RECORD;
    v_price    numeric;
    v_res      jsonb;
    v_left     numeric;
    v_today    date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_count    int := 0;
    v_skip     int := 0;
    v_fail     int := 0;
BEGIN
    FOR r IN
        SELECT sr.*,
               c.company_name,
               c.user_id   AS founder_uid,
               c.pool_cash::numeric AS pc,
               c.pool_shares::numeric AS ps,
               p.nb_balance
          FROM public.support_rules sr
          JOIN public.user_companies c ON c.id = sr.company_id
          JOIN public.profiles p       ON p.id = sr.user_id
         WHERE COALESCE(sr.enabled, true) = true
    LOOP
        -- ① 不能买自己的公司
        IF r.user_id = r.founder_uid THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ② 金额合法性（单次 10 ~ 10 万）
        IF r.amount IS NULL OR r.amount < 10 OR r.amount > 100000 THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ③ 交易时段（和手动买卖保持一致）
        IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
           OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ④ 间隔限制
        IF r.last_run_at IS NOT NULL
           AND r.last_run_at > now() - make_interval(secs => COALESCE(r.min_interval, 60)) THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ⑤ 当前股价（池子异常就跳过）
        IF r.ps IS NULL OR r.ps <= 0 THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;
        v_price := r.pc / r.ps;

        -- ⑥ 跌到目标价才买
        IF r.price_target IS NULL OR v_price > r.price_target THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ⑦ 每日额度（跨天自动重置）
        IF r.today_date IS DISTINCT FROM v_today THEN
            UPDATE public.support_rules
               SET today_cash = 0, today_date = v_today
             WHERE id = r.id;
            r.today_cash := 0;
        END IF;
        v_left := COALESCE(r.daily_limit, 50000) - COALESCE(r.today_cash, 0);
        IF v_left < r.amount THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ⑧ 余额够不够（含 5% 手续费）
        IF COALESCE(r.nb_balance, 0) < r.amount * 1.05 THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ⑨ 真正买入（走内部实现，绕开 session 校验）
        BEGIN
            SELECT public._orig_buy_stock(r.user_id, r.company_id, r.amount, false)
              INTO v_res;
        EXCEPTION WHEN OTHERS THEN
            v_res := jsonb_build_object('success', false, 'message', SQLERRM);
        END;

        IF v_res IS NOT NULL AND (v_res->>'success')::boolean IS TRUE THEN
            UPDATE public.support_rules
               SET today_cash  = COALESCE(today_cash,0) + r.amount,
                   today_date  = v_today,
                   last_run_at = now()
             WHERE id = r.id;
            v_count := v_count + 1;
        ELSE
            -- 失败也记一下时间，避免每条规则每轮都重试
            UPDATE public.support_rules SET last_run_at = now() WHERE id = r.id;
            v_fail := v_fail + 1;
        END IF;
    END LOOP;

    RAISE NOTICE '自动抄底：成交 % 条，条件不满足跳过 % 条，执行失败 % 条',
                 v_count, v_skip, v_fail;
END
$fn$;


-- ============================================================
-- 三、写入/修改规则的前端接口
-- ------------------------------------------------------------
-- 原来的 set_support_rule 参数语义是旧的，这里换一个新名字，
-- 避免前端改到一半出现"参数对不上"的混乱。
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_auto_buy_rule(
    p_user_id uuid, p_company_id bigint, p_session text,
    p_price_target numeric, p_amount numeric, p_daily_limit numeric DEFAULT 50000)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_founder uuid;
    v_name    text;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败，请重新登录');
    END IF;

    SELECT user_id, company_name INTO v_founder, v_name
      FROM public.user_companies WHERE id = p_company_id;
    IF v_founder IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '公司不存在');
    END IF;
    IF v_founder = p_user_id THEN
        RETURN jsonb_build_object('success', false,
            'message', '不能对自己的公司设自动买入（新版不允许买自己公司）');
    END IF;
    IF p_price_target IS NULL OR p_price_target <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '目标股价必须大于 0');
    END IF;
    IF p_amount IS NULL OR p_amount < 10 OR p_amount > 100000 THEN
        RETURN jsonb_build_object('success', false, 'message', '每次买入金额需在 10 ~ 100000 之间');
    END IF;
    IF p_daily_limit IS NULL OR p_daily_limit < p_amount THEN
        RETURN jsonb_build_object('success', false, 'message', '每日上限不能小于单次金额');
    END IF;

    INSERT INTO public.support_rules
        (user_id, company_id, threshold, amount, price_target, daily_limit,
         enabled, today_cash, today_date)
    VALUES
        (p_user_id, p_company_id, NULL, p_amount::int, p_price_target, p_daily_limit,
         true, 0, (now() AT TIME ZONE 'Asia/Shanghai')::date)
    ON CONFLICT DO NOTHING;

    -- 一个用户对一家公司只留一条规则
    UPDATE public.support_rules
       SET amount       = p_amount::int,
           price_target = p_price_target,
           daily_limit  = p_daily_limit,
           enabled      = true
     WHERE user_id = p_user_id AND company_id = p_company_id;

    RETURN jsonb_build_object('success', true,
        'message', format('已设置自动抄底：%s 股价跌破 %s 时，自动买入 %s NB币/次，每日最多 %s',
                          v_name, p_price_target, p_amount, p_daily_limit));
END
$fn$;

GRANT EXECUTE ON FUNCTION public.set_auto_buy_rule(uuid, bigint, text, numeric, numeric, numeric)
    TO anon, authenticated;


-- ============================================================
-- 四、删除规则 / 切换开关
-- ============================================================
CREATE OR REPLACE FUNCTION public.toggle_auto_buy_rule(
    p_user_id uuid, p_session text, p_rule_id bigint, p_enabled boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败，请重新登录');
    END IF;
    UPDATE public.support_rules
       SET enabled = p_enabled
     WHERE id = p_rule_id AND user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', '规则不存在或不属于你');
    END IF;
    RETURN jsonb_build_object('success', true,
        'message', CASE WHEN p_enabled THEN '已启用' ELSE '已暂停' END);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.toggle_auto_buy_rule(uuid, text, bigint, boolean)
    TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_auto_buy_rules(p_user_id uuid)
RETURNS TABLE(
    rule_id      bigint,
    company_id   bigint,
    company_name text,
    price_target numeric,
    cur_price    numeric,
    amount       numeric,
    daily_limit  numeric,
    today_cash   numeric,
    enabled      boolean,
    last_run_at  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    RETURN QUERY
    SELECT sr.id, sr.company_id, c.company_name,
           sr.price_target,
           round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0), 4),
           sr.amount::numeric, sr.daily_limit,
           COALESCE(sr.today_cash,0),
           COALESCE(sr.enabled, true),
           sr.last_run_at
      FROM public.support_rules sr
      JOIN public.user_companies c ON c.id = sr.company_id
     WHERE sr.user_id = p_user_id
     ORDER BY sr.id DESC;
END
$fn$;

GRANT EXECUTE ON FUNCTION public.get_my_auto_buy_rules(uuid) TO anon, authenticated;


-- ============================================================
-- 五、清掉不符合新规则的旧数据
-- ============================================================
-- 把「对自己公司」的旧规则停用（新规则不允许）
UPDATE public.support_rules sr
   SET enabled = false
  FROM public.user_companies c
 WHERE sr.company_id = c.id AND sr.user_id = c.user_id;

-- 看看还剩多少条有效规则
SELECT
    count(*) AS 规则总数,
    count(*) FILTER (WHERE COALESCE(enabled,true)) AS 启用中的,
    count(*) FILTER (WHERE price_target IS NOT NULL) AS 已设目标价的
  FROM public.support_rules;


-- ============================================================
-- 六、验收
-- ============================================================
-- 6.1 函数都在
SELECT p.proname AS 函数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('run_auto_support','set_auto_buy_rule',
                     'toggle_auto_buy_rule','get_my_auto_buy_rules')
 ORDER BY 1;

-- 6.2 手动跑一次看输出（现在应该全是"跳过"，因为还没人设规则）
-- PERFORM public.run_auto_support();

-- 6.3 看看规则表现在的样子
SELECT sr.id, p.username, c.company_name,
       sr.price_target, sr.amount, sr.daily_limit,
       COALESCE(sr.enabled,true) AS 启用
  FROM public.support_rules sr
  LEFT JOIN public.profiles p ON p.id = sr.user_id
  LEFT JOIN public.user_companies c ON c.id = sr.company_id
 LIMIT 20;


-- ============================================================
-- 补充：定时任务
-- ------------------------------------------------------------
-- run_auto_support 需要有定时任务调它。之前的 cron 配置不用动
-- （函数名没变，还是 run_auto_support），只是内部逻辑换了。
-- 确认一下任务还在：
SELECT jobid, schedule, command, active FROM cron.job;
