-- ============================================================
-- 注册公司支持自定义出资额
-- ============================================================
-- 【问题】
--   Part 1 里我重写的 _orig_register_company 只有三个参数
--   (p_user_id, p_company_name, p_need_verify)，
--   出资额 v_fund 写死 20000 —— 前端就算加了输入框也传不进来。
--
--   前端现在这样调：
--       rpc('register_company', {p_user_id, p_company_name, p_need_verify})
--
-- 【修法】
--   1. 把现有实现改名成 _orig_register_company_v3（内容一字不动）
--   2. 新建同名函数，多一个 p_fund 参数（默认 20000）
--      —— 因为带默认值，原来那个三参数的外壳调用它【照样能用】
--   3. 新建 register_company_funded 给前端调，带 p_fund
--
--   ⚠️ 为什么不直接改外壳：外壳的线上定义我没拿到，
--      不动它最安全。带默认值的第四个参数不会破坏它的调用。
--
-- 关于登录态校验：这个代码库的约定是「外壳校验、_orig_* 干活」，
-- 所以 _orig_register_company 里不重复校验，保持一致。
-- 新加的 register_company_funded 在开头自己做一次 verify_session。
-- ============================================================


-- ============================================================
-- 第一步：看现在的状况（只查不改）
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_arguments(p.oid) AS 参数,
       length(pg_get_functiondef(p.oid)) AS 定义长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('register_company','_orig_register_company',
                     '_orig_register_company_v2','_orig_register_company_v3')
 ORDER BY p.proname;


-- ============================================================
-- 第二步：把现有实现改名（内容一字不动）
-- ============================================================
-- 注意：如果 _orig_register_company_v3 已经存在（比如重复跑本脚本），
-- 先删掉再改名。
DROP FUNCTION IF EXISTS public._orig_register_company_v3(uuid, text, boolean);

ALTER FUNCTION public._orig_register_company(uuid, text, boolean)
    RENAME TO _orig_register_company_v3;


-- ============================================================
-- 第三步：新建带出资额的版本
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_register_company(
    p_user_id     uuid,
    p_company_name text,
    p_need_verify boolean,
    p_fund        numeric DEFAULT 20000)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_clean TEXT;
    v_word  TEXT;
    v_fund  numeric;
    v_bal   numeric;
    v_cid   bigint;
    v_max   CONSTANT numeric := 100000000;   -- 单次出资上限 1 亿，防止误输入
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法注册公司');
    END IF;

    -- 出资额校验
    v_fund := COALESCE(p_fund, 20000);
    IF v_fund < 20000 THEN
        RETURN jsonb_build_object('success', false,
            format('注册公司最少需要出资 20000 NB币（你填的是 %s）', v_fund));
    END IF;
    IF v_fund > v_max THEN
        RETURN jsonb_build_object('success', false,
            format('单次出资不能超过 %s NB币', v_max));
    END IF;

    -- 名称清洗
    v_clean := regexp_replace(
        coalesce(p_company_name, ''),
        '[' || chr(8203)||chr(8204)||chr(8205)||chr(8206)||chr(8207)
             || chr(65279)||chr(173)||chr(8288)||chr(12288)
             || chr(9)||chr(10)||chr(13)||chr(32) || ']', '', 'g');
    v_clean := btrim(v_clean);

    IF v_clean = '' THEN
        RETURN jsonb_build_object('success', false, 'message', '请填写公司名称');
    END IF;
    IF v_clean !~ ('^[' || chr(19968) || '-' || chr(40869) || 'a-zA-Z0-9]+$') THEN
        RETURN jsonb_build_object('success', false, 'message', '公司名称只能包含中文、字母和数字');
    END IF;
    IF length(v_clean) < 1 OR length(v_clean) > 20 THEN
        RETURN jsonb_build_object('success', false, 'message', '公司名称需在 1~20 字之间');
    END IF;

    BEGIN
        FOR v_word IN SELECT word FROM public.bad_words LOOP
            IF position(lower(v_word) in lower(v_clean)) > 0 THEN
                RETURN jsonb_build_object('success', false, 'message', '公司名称包含违禁词，请更换名称');
            END IF;
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        NULL;   -- bad_words 表不存在就跳过检查
    END;

    IF EXISTS (SELECT 1 FROM public.user_companies
                WHERE lower(btrim(company_name)) = lower(v_clean)) THEN
        RETURN jsonb_build_object('success', false,
            'message', '公司名「' || v_clean || '」已被占用，请换一个名字');
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_companies WHERE user_id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'message', '您已经注册过公司');
    END IF;

    -- 余额校验
    SELECT COALESCE(nb_balance, 0) INTO v_bal FROM public.profiles WHERE id = p_user_id;
    IF COALESCE(v_bal, 0) < v_fund THEN
        RETURN jsonb_build_object('success', false,
            format('注册公司需要出资 %s NB币建初始资金池，你的余额是 %s',
                   v_fund, COALESCE(v_bal, 0)));
    END IF;

    -- 扣钱
    UPDATE public.profiles SET nb_balance = nb_balance - v_fund WHERE id = p_user_id;

    -- 建公司
    INSERT INTO public.user_companies
        (user_id, founder_id, company_name, market_value,
         pool_cash, pool_shares, total_shares,
         verified, verification_status)
    VALUES
        (p_user_id, p_user_id, v_clean, v_fund * 2,
         v_fund, v_fund, v_fund * 2,
         false, CASE WHEN p_need_verify THEN 'pending' ELSE 'none' END)
    RETURNING id INTO v_cid;

    -- 创始人拿一半股份
    INSERT INTO public.holdings
        (user_id, company_id, principal, base_market_value, shares, cost, updated_at)
    VALUES
        (p_user_id, v_cid, v_fund, v_fund, v_fund, v_fund, now())
    ON CONFLICT (user_id, company_id) DO UPDATE
        SET shares = EXCLUDED.shares, cost = EXCLUDED.cost, updated_at = now();

    INSERT INTO public.stock_trades (user_id, company_id, side, cash, shares, price_after)
    VALUES (p_user_id, v_cid, 'buy', v_fund, v_fund, 1.0);

    RETURN jsonb_build_object(
        'success', true,
        'message', format('公司「%s」注册成功！你出资 %s NB币建了初始资金池，获得 %s 张股份（占总股本一半），股价 1.00',
                          v_clean, v_fund, v_fund),
        'company_id', v_cid,
        'shares', v_fund,
        'price', 1.0,
        'fund', v_fund,
        'need_verify', p_need_verify);
END
$fn$;


-- ============================================================
-- 第四步：给前端用的新入口（自带登录态校验）
-- ============================================================
CREATE OR REPLACE FUNCTION public.register_company_funded(
    p_user_id      uuid,
    p_session      text,
    p_company_name text,
    p_need_verify  boolean,
    p_fund         numeric DEFAULT 20000)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public.verify_session(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '登录已过期，请重新登录');
    END IF;
    RETURN public._orig_register_company(p_user_id, p_company_name, p_need_verify, p_fund);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.register_company_funded(uuid, text, text, boolean, numeric)
    TO anon, authenticated;


-- ============================================================
-- 第五步：验收
-- ============================================================
-- 5.1 三个函数都在，参数对
SELECT p.proname AS 函数,
       pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_register_company','_orig_register_company_v3',
                     'register_company_funded')
 ORDER BY p.proname;
-- 预期：
--   _orig_register_company      uuid, text, boolean, numeric DEFAULT 20000
--   _orig_register_company_v3   uuid, text, boolean
--   register_company_funded     uuid, text, text, boolean, numeric DEFAULT 20000

-- 5.2 老的调用方式还能用吗（外壳会以三个参数调它）
--     这条会返回"最少需要出资 20000"或"已注册过公司"，总之不该报"函数不存在"
SELECT public._orig_register_company(
    '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid, '测试名字', false);
-- 如果返回 {"message": "注册公司最少需要出资 20000..."} 说明默认值没生效，检查签名

-- 5.3 前端的新调用方式（前端代码照这个改）：
-- SELECT public.register_company_funded(
--     '用户uuid'::uuid, '会话token', '公司名', false, 50000);


-- ============================================================
-- 前端要改成这样调（给分身看的）
-- ============================================================
-- 旧：
--   supabase.rpc('register_company', {
--       p_user_id: currentUserId,
--       p_company_name: companyName,
--       p_need_verify: false
--   })
--
-- 新：
--   supabase.rpc('register_company_funded', {
--       p_user_id: currentUserId,
--       p_session: <当前会话token>,
--       p_company_name: companyName,
--       p_need_verify: false,
--       p_fund: <用户填的出资额，默认 20000>
--   })
--
-- 返回：{success, message, company_id, shares, price, fund, need_verify}
-- 失败时 success=false，message 里有原因（余额不足 / 名称重复 / 少于 2 万 …）


-- ============================================================
-- 回滚（把实现改回三点参数版本）
-- ============================================================
-- DROP FUNCTION IF EXISTS public._orig_register_company(uuid, text, boolean, numeric);
-- DROP FUNCTION IF EXISTS public.register_company_funded(uuid, text, text, boolean, numeric);
-- ALTER FUNCTION public._orig_register_company_v3(uuid, text, boolean)
--     RENAME TO _orig_register_company;
