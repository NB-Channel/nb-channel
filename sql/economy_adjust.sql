-- ============================================================
-- 建议 ⑧⑨:经济系统调整
--   ⑨-1 单次买入无上限
--   ⑨-2 单次支持上限 2000 → 100000
--   ⑨-3 自动支持:余额不足时【保留规则】(原来会直接删掉)
--   ⑧   新增"付费提升公司市值" RPC(注册公司时可选付费提高初始市值)
-- 在 Supabase SQL Editor 整段执行
-- ============================================================

-- ---------- ⑨-1 去除单次买入上限 ----------
-- 用 pg_get_functiondef 取出线上函数源码,做一次精确替换后回写。
-- 这样不用手抄上百行函数体,也不会漏改其它分支。
DO $$
DECLARE
    r record;
    v_def text;
BEGIN
    FOR r IN
        SELECT p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('_orig_buy_stock', 'buy_stock')
    LOOP
        SELECT pg_get_functiondef(p.oid) INTO v_def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = r.proname;

        IF v_def LIKE '%p_amount > 500000%' THEN
            v_def := replace(v_def, 'p_amount > 500000', 'false');
            EXECUTE v_def;
            RAISE NOTICE '✅ 已去除 % 的单次买入上限', r.proname;
        ELSIF v_def LIKE '%p_amount > 10000%' THEN
            v_def := replace(v_def, 'p_amount > 10000', 'false');
            EXECUTE v_def;
            RAISE NOTICE '✅ 已去除 % 的单次买入上限(旧版 10000)', r.proname;
        ELSE
            RAISE NOTICE 'ℹ️ % 里没找到买入上限判断', r.proname;
        END IF;
    END LOOP;
END $$;

-- ---------- ⑨-2 单次支持上限 2000 → 100000 ----------
DO $$
DECLARE
    r record;
    v_def text;
    v_hit int := 0;
BEGIN
    FOR r IN
        SELECT p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('_orig_support_company', 'support_company')
    LOOP
        SELECT pg_get_functiondef(p.oid) INTO v_def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = r.proname;

        IF v_def LIKE '%p_amount > 2000%' THEN
            v_def := replace(v_def, 'p_amount > 2000', 'p_amount > 100000');
            v_def := replace(v_def, '2000 NB币', '100000 NB币');
            EXECUTE v_def;
            v_hit := v_hit + 1;
            RAISE NOTICE '✅ 已把 % 的单次支持上限改为 100000', r.proname;
        ELSE
            RAISE NOTICE 'ℹ️ % 里没找到 2000 上限判断', r.proname;
        END IF;
    END LOOP;
    RAISE NOTICE '支持上限调整完成,共 % 个函数', v_hit;
END $$;

-- ---------- ⑨-3 自动支持:余额不足不再删规则 ----------
CREATE OR REPLACE FUNCTION public.run_auto_support()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    r RECORD;
    v_res jsonb;
    v_count integer := 0;
    v_deleted integer := 0;
    v_skipped integer := 0;
BEGIN
    FOR r IN
        SELECT sr.id, sr.user_id, sr.company_id, sr.threshold, sr.amount,
               uc.market_value, p.nb_balance
          FROM public.support_rules sr
          JOIN public.user_companies uc ON uc.id = sr.company_id
          JOIN public.profiles p ON p.id = sr.user_id
    LOOP
        -- ① 金额非法(<=0 或超过 10万上限) → 删除规则
        IF r.amount <= 0 OR r.amount > 100000 THEN
            DELETE FROM public.support_rules WHERE id = r.id;
            v_deleted := v_deleted + 1;
            CONTINUE;
        END IF;

        -- ② 余额不足 → 【保留规则】,等充值后再支持(旧逻辑会直接删掉规则)
        IF r.nb_balance < r.amount THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        -- ③ 市值低于阈值才支持
        IF r.market_value < r.threshold THEN
            SELECT public.support_company(r.user_id, r.company_id, r.amount) INTO v_res;
            IF v_res IS NOT NULL AND v_res->>'success' = 'true' THEN
                v_count := v_count + 1;
            END IF;
            -- 失败(如休市)不删规则,下轮再试
        END IF;
    END LOOP;
    RAISE NOTICE 'run_auto_support: 执行支持 % 条 · 余额不足保留 % 条 · 清理失效 % 条',
        v_count, v_skipped, v_deleted;
END
$fn$;

-- 自动支持规则的金额上限同步放宽到 10 万(原来校验 2000)
DO $$
DECLARE v_def text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'set_support_rule';
    IF v_def IS NOT NULL AND v_def LIKE '%p_amount > 2000%' THEN
        v_def := replace(v_def, 'p_amount > 2000', 'p_amount > 100000');
        v_def := replace(v_def, '1~2000 NB币', '1~100000 NB币');
        EXECUTE v_def;
        RAISE NOTICE '✅ set_support_rule 上限已放宽到 100000';
    ELSE
        RAISE NOTICE 'ℹ️ set_support_rule 无需调整(或没找到)';
    END IF;
END $$;

-- ---------- ⑧ 新增:付费提升公司市值 ----------
-- 免费注册公司仍是初始市值 20000;想更高市值就调这个 RPC 花钱加值。
-- 前端流程:先 register_company 注册 → 再调本 RPC 提升(一次调用完成扣款 + 加值)
CREATE OR REPLACE FUNCTION public.upgrade_company_value(
    p_user_id uuid, p_session text, p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_bal   numeric;
    v_owner uuid;
    v_new   numeric;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    IF p_amount IS NULL OR p_amount < 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '提升金额无效');
    END IF;
    IF p_amount = 0 THEN
        RETURN jsonb_build_object('ok', true, 'message', '按基础市值 20000 注册', 'added', 0);
    END IF;
    IF p_amount > 100000000 THEN
        RETURN jsonb_build_object('ok', false, 'message', '单次提升不能超过 1 亿 NB币');
    END IF;

    SELECT user_id INTO v_owner FROM public.user_companies WHERE id = p_company_id;
    IF v_owner IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', '公司不存在');
    END IF;
    IF v_owner <> p_user_id THEN
        RETURN jsonb_build_object('ok', false, 'message', '只能提升自己公司的市值');
    END IF;

    SELECT nb_balance INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF v_bal IS NULL OR v_bal < p_amount THEN
        RETURN jsonb_build_object('ok', false, 'message',
            'NB币不足(需要 ' || p_amount || ',当前 ' || coalesce(v_bal, 0) || ')');
    END IF;

    UPDATE public.profiles SET nb_balance = nb_balance - p_amount WHERE id = p_user_id;
    UPDATE public.user_companies SET market_value = market_value + p_amount
     WHERE id = p_company_id
     RETURNING market_value INTO v_new;

    RETURN jsonb_build_object('ok', true,
        'message', '已花费 ' || p_amount || ' NB币,公司市值提升至 ' || v_new,
        'added', p_amount, 'market_value', v_new);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.upgrade_company_value(uuid, text, bigint, numeric) TO anon;

-- ---------- 验收 ----------
-- 1) 买入上限应已消失(应看到 false)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%p_amount > 500000%') AS 还有500000上限,
       (pg_get_functiondef(p.oid) LIKE '%p_amount > 2000%')   AS 还有2000上限
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock', 'buy_stock', '_orig_support_company', 'support_company')
 ORDER BY p.proname;

-- 2) 新 RPC 是否就位
SELECT p.proname AS 新函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'upgrade_company_value';
