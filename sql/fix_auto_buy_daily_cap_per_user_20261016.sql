-- ============================================================
--  修「自动抄底」：每日上限改成【按人】算 + 限制规则数量
--
--  ── 问题 ──
--  有人用 3 个号 × 8 条规则 = 24 条自动买单，全对着自己这一伙的公司：
--
--      规则ID 玩家                  盯着的公司        今天已花
--       193  Utvv                  Utw宿舍           50,000
--       192  Utvv                  Utw小号           50,000
--       ...  （8 条，全部 50,000）
--       181  Utw的小NB肉餐厅官号      Utw宿舍           50,000
--       ...  （8 条）
--       172  Utw的3ty肉餐厅官号       小NB肉餐厅         50,000
--       ...  （8 条）
--
--      一天总共花掉 1,200,000 NB币
--
--  ⚠️ 两个原因：
--      ① daily_limit（每日上限 50,000）是【按每条规则】算的，
--         不是按每个玩家 —— 建 8 条规则 = 一天能花 40 万
--      ② 一个玩家能建的规则数量没有上限 —— 想建多少建多少
--
--  ── 改法 ──
--  ① run_auto_support：每个玩家每天【总额度 50,000】
--        处理每条规则之前，先算「这个人今天所有规则加起来花了多少」，
--        剩余额度 = 50,000 - 已花。
--        单条规则实际能花的 = min(规则自己的 daily_limit, 剩余额度)。
--        剩余额度不够一次买入 → 这条规则本轮跳过。
--        ⚠️ 也就是说：建再多规则，一天也最多花 50,000。
--
--  ② set_auto_buy_rule：每个玩家最多 5 条规则
--        ⚠️ 只拦【新增】—— 对已经盯着的公司改参数不受影响。
--
--  ⚠️ 不动任何已有数据：
--        已经建好的 24 条规则还在，但从今天起它们【共享】50,000 总额度，
--        等价于自动被压缩了 8 倍。
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步（只查）：改之前的样子
-- ============================================================
-- 0.1 每个玩家有几条规则、今天花了多少
SELECT p.username                        AS 玩家,
       count(*)                          AS 规则数,
       count(*) FILTER (WHERE COALESCE(sr.enabled,true)) AS 启用数,
       COALESCE(sum(sr.today_cash), 0)   AS 今天已花合计,
       max(sr.daily_limit)               AS 单条规则上限
  FROM public.support_rules sr
  LEFT JOIN public.profiles p ON p.id = sr.user_id
 GROUP BY p.username
 ORDER BY 4 DESC;

-- 0.2 全站今天一共花了多少
SELECT COALESCE(sum(today_cash), 0) AS 全站今天已花,
       count(*)                     AS 规则总数
  FROM public.support_rules;


-- ============================================================
-- 第 1 步：重写 run_auto_support —— 每日额度按人算
-- ============================================================
CREATE OR REPLACE FUNCTION public.run_auto_support()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    -- ⚠️ 每个玩家每天的总上限（不是每条规则）
    --    改这个数字就能放宽 / 收紧所有人的额度
    c_user_daily_cap CONSTANT numeric := 50000;

    r          RECORD;
    v_price    numeric;
    v_res      jsonb;
    v_user_spent numeric;
    v_left     numeric;
    v_today    date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_count    int := 0;
    v_skip     int := 0;
    v_fail     int := 0;
    v_capped   int := 0;
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

        -- ⑦ 跨天重置：把这个玩家【所有规则】的 today_cash 一起清零
        --    ⚠️ 按人算额度之后，必须一起清 ——
        --       只清这一条的话，别的规则还带着昨天的数，
        --       sum() 一算就把今天的新额度吃掉。
        IF r.today_date IS DISTINCT FROM v_today THEN
            UPDATE public.support_rules
               SET today_cash = 0, today_date = v_today
             WHERE user_id = r.user_id;
        END IF;

        -- ⑧ 【新增】这个人今天跨所有规则已经花了多少
        SELECT COALESCE(sum(today_cash), 0)
          INTO v_user_spent
          FROM public.support_rules
         WHERE user_id = r.user_id
           AND today_date = v_today;

        -- ⑨ 剩余额度 = 每人每天总上限 - 已花
        v_left := c_user_daily_cap - v_user_spent;

        -- ⑩ 单条规则自己的上限也要尊重（取两者较小）
        v_left := LEAST(v_left, COALESCE(r.daily_limit, c_user_daily_cap));

        IF v_left < r.amount THEN
            -- 额度用完了（这次不算 skip，单独计数，方便看日志）
            v_capped := v_capped + 1;
            CONTINUE;
        END IF;

        -- ⑪ 余额够不够（含 5% 手续费）
        IF COALESCE(r.nb_balance, 0) < r.amount * 1.05 THEN
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        -- ⑫ 真正买入（走内部实现，绕开 session 校验）
        BEGIN
            SELECT public._orig_buy_stock(r.user_id, r.company_id, r.amount, false)
              INTO v_res;
        EXCEPTION WHEN OTHERS THEN
            v_res := jsonb_build_object('success', false, 'message', SQLERRM);
        END;

        IF v_res IS NOT NULL AND (v_res->>'success')::boolean IS TRUE THEN
            UPDATE public.support_rules
               SET today_cash  = COALESCE(today_cash, 0) + r.amount,
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

    RAISE NOTICE '自动抄底：成交 % 条，条件不满足跳过 % 条，额度用完 % 条，执行失败 % 条（每人每天上限 %）',
                 v_count, v_skip, v_capped, v_fail, c_user_daily_cap;
END
$fn$;


-- ============================================================
-- 第 2 步：重写 set_auto_buy_rule —— 每个玩家最多 5 条规则
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_auto_buy_rule(
    p_user_id uuid, p_company_id bigint, p_session text,
    p_price_target numeric, p_amount numeric, p_daily_limit numeric DEFAULT 50000)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    -- ⚠️ 每个玩家最多能同时盯几家公司
    c_max_rules CONSTANT int := 5;

    v_founder uuid;
    v_name    text;
    v_rules   int;
    v_exists  boolean;
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

    -- 【新增】规则数量上限
    -- ⚠️ 只拦【新增】—— 对已经盯着的公司改参数不该被挡
    SELECT EXISTS (SELECT 1 FROM public.support_rules
                    WHERE user_id = p_user_id AND company_id = p_company_id)
      INTO v_exists;

    IF NOT v_exists THEN
        SELECT count(*) INTO v_rules
          FROM public.support_rules
         WHERE user_id = p_user_id;
        IF v_rules >= c_max_rules THEN
            RETURN jsonb_build_object('success', false,
                'message', format('最多同时盯 %s 家公司，你现在已经 %s 条了。'
                                  '先删掉几条再来设新的。', c_max_rules, v_rules));
        END IF;
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
        'message', format('已设置自动抄底：%s 股价跌破 %s 时，自动买入 %s NB币/次'
                          '（每人每天总共最多 50000，多条规则共享）',
                          v_name, p_price_target, p_amount));
END
$fn$;


-- ============================================================
-- 第 3 步：验收
-- ============================================================
-- 3.1 两个函数都装上了吗
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%c_user_daily_cap%') AS 每人额度,
       (pg_get_functiondef(p.oid) LIKE '%c_max_rules%')       AS 规则数上限
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('run_auto_support', 'set_auto_buy_rule')
 ORDER BY 1;

-- 3.2 现在每个人几条规则（超过 5 条的只是不能再新增，已有的不动）
SELECT p.username AS 玩家, count(*) AS 规则数
  FROM public.support_rules sr
  LEFT JOIN public.profiles p ON p.id = sr.user_id
 GROUP BY p.username
 ORDER BY 2 DESC;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 那些建了 8 条规则的号，从今天起【共享】50,000 额度 ——
--    实际每天最多花 5 万，而不是 40 万
--  · 他们不能再新增规则了（已经超过 5 条的，只能删不能加）
--  · 已有数据一条没动
--
--  ⚠️ 两件事你可能还想做（我没做，等你决定）：
--     ① 把那些规则的 enabled 改成 false（立刻停掉）
--        —— 那是改他们的数据，我会先列清单给你确认
--     ② 把每人上限从 50,000 调成别的数
--        —— 改 run_auto_support 里的 c_user_daily_cap 一个数字就行
-- ============================================================
