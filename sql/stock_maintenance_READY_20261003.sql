-- ============================================================
-- 股票系统维护模式 —— 可直接执行版
-- ============================================================
-- 站长 ID：22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c（NB频道官方）
-- 目标：重构 AMM 模型期间，只放行站长，其他人买卖注资全部拒绝
--
-- 【整段一起执行，不要拆开跑】
--   第 4 步（改名）和第 5 步（建包装）之间有个极短窗口期，
--   挪动的只是函数名，数据一条不动。
--
-- 【原理】
--   把现有实现改名为 xxx_v2（内容一字未动），
--   再用同名的新函数包一层：先查白名单，通过了再转给 _v2。
--
-- 【出问题怎么自救】
--   如果跑完发现连你自己也进不去：
--     UPDATE public.stock_settings SET value='0' WHERE key='maintenance';
--   这一句就能立刻恢复所有人访问。
-- ============================================================


-- ============================================================
-- 第 0 步：备份函数定义（要回滚靠它）
-- ============================================================
DROP TABLE IF EXISTS public._func_backup_20261003;
CREATE TABLE public._func_backup_20261003 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock', '_orig_sell_stock',
                     '_orig_support_company', '_orig_bankrupt_company',
                     '_orig_register_company', 'withdraw_company_value');

SELECT 函数名, length(定义) AS 定义长度 FROM public._func_backup_20261003 ORDER BY 函数名;
-- 预期 6 行。如果少于 6 行，说明有函数名跟预期不一样，停下来告诉我。


-- ============================================================
-- 第 1 步：建开关表 + 白名单表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.stock_whitelist (
    user_id    uuid PRIMARY KEY,
    note       text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_settings (
    key        text PRIMARY KEY,
    value      text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- ⭐ 先把站长放进白名单，再开维护模式 —— 顺序反了会把自己关在外面
INSERT INTO public.stock_whitelist (user_id, note) VALUES
    ('22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c', '站长 · NB频道官方')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.stock_settings (key, value) VALUES
    ('maintenance',        '1'),
    ('maintenance_notice', '股票系统正在升级为新版交易模型，你的持仓和资金都不会受影响。请稍后再来。')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

SELECT * FROM public.stock_settings;
SELECT w.user_id, p.username, w.note
  FROM public.stock_whitelist w LEFT JOIN public.profiles p ON p.id = w.user_id;


-- ============================================================
-- 第 2 步：判定函数
-- ============================================================
CREATE OR REPLACE FUNCTION public._stock_allowed(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_maint text;
BEGIN
    SELECT value INTO v_maint FROM public.stock_settings WHERE key = 'maintenance';
    IF v_maint IS NULL OR v_maint = '0' THEN
        RETURN true;
    END IF;
    RETURN EXISTS (SELECT 1 FROM public.stock_whitelist WHERE user_id = p_user_id);
END
$fn$;

GRANT EXECUTE ON FUNCTION public._stock_allowed(uuid) TO anon;

-- 自测：站长的返回 true，其他人 false
SELECT public._stock_allowed('22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c') AS 站长_应该true,
       public._stock_allowed(NULL::uuid)                              AS 空值_应该false;


-- ============================================================
-- 第 3 步：先看有没有别的函数在调这些 _orig_*
-- ------------------------------------------------------------
-- 这一步【只看不改】。把结果记下来，如果出现预期外的函数名，告诉我。
-- ============================================================
SELECT p.proname AS 调用者,
       (pg_get_functiondef(p.oid) LIKE '%_orig_buy_stock%')::int
     + (pg_get_functiondef(p.oid) LIKE '%_orig_sell_stock%')::int
     + (pg_get_functiondef(p.oid) LIKE '%_orig_support_company%')::int
     + (pg_get_functiondef(p.oid) LIKE '%_orig_bankrupt_company%')::int
     + (pg_get_functiondef(p.oid) LIKE '%_orig_register_company%')::int AS 命中数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (pg_get_functiondef(p.oid) LIKE '%_orig_buy_stock%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_sell_stock%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_support_company%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_bankrupt_company%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_register_company%')
 ORDER BY 1;
-- 预期看到：buy_stock / sell_stock / support_company / bankrupt_company /
--           _orig_nodup_register_company / run_auto_support


-- ============================================================
-- 第 4 步：改名（现有实现搬到 _v2，内容一字未动）
-- ============================================================
ALTER FUNCTION public._orig_buy_stock(uuid, bigint, numeric, boolean)
    RENAME TO _orig_buy_stock_v2;
ALTER FUNCTION public._orig_sell_stock(uuid, bigint, numeric, boolean)
    RENAME TO _orig_sell_stock_v2;
ALTER FUNCTION public._orig_support_company(uuid, bigint, integer)
    RENAME TO _orig_support_company_v2;
ALTER FUNCTION public._orig_bankrupt_company(uuid)
    RENAME TO _orig_bankrupt_company_v2;
ALTER FUNCTION public._orig_register_company(uuid, text, boolean)
    RENAME TO _orig_register_company_v2;
ALTER FUNCTION public.withdraw_company_value(uuid, text, bigint, numeric)
    RENAME TO _withdraw_company_value_v2;


-- ============================================================
-- 第 5 步：建包装（同名的门卫）
-- ============================================================
CREATE OR REPLACE FUNCTION public._orig_buy_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    RETURN public._orig_buy_stock_v2(p_user_id, p_company_id, p_amount, p_use_discount);
END $fn$;

CREATE OR REPLACE FUNCTION public._orig_sell_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    RETURN public._orig_sell_stock_v2(p_user_id, p_company_id, p_amount, p_use_discount);
END $fn$;

CREATE OR REPLACE FUNCTION public._orig_support_company(
    p_user_id uuid, p_company_id bigint, p_amount integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN public._orig_support_company_v2(p_user_id, p_company_id, p_amount);
END $fn$;

CREATE OR REPLACE FUNCTION public._orig_bankrupt_company(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN public._orig_bankrupt_company_v2(p_user_id);
END $fn$;

CREATE OR REPLACE FUNCTION public._orig_register_company(
    p_user_id uuid, p_company_name text, p_need_verify boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法注册公司');
    END IF;
    RETURN public._orig_register_company_v2(p_user_id, p_company_name, p_need_verify);
END $fn$;

CREATE OR REPLACE FUNCTION public.withdraw_company_value(
    p_user_id uuid, p_session text, p_company_id bigint, p_amount numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN public._withdraw_company_value_v2(p_user_id, p_session, p_company_id, p_amount);
END $fn$;


-- ============================================================
-- 第 6 步：验收
-- ============================================================
-- 6.1 六个 _v2 都在（改名成功）
SELECT p.proname AS 实现函数, length(pg_get_functiondef(p.oid)) AS 定义长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock_v2','_orig_sell_stock_v2',
                     '_orig_support_company_v2','_orig_bankrupt_company_v2',
                     '_orig_register_company_v2','_withdraw_company_value_v2')
 ORDER BY 1;
-- 预期 6 行

-- 6.2 六个包装都在
SELECT p.proname AS 门卫函数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock','_orig_sell_stock',
                     '_orig_support_company','_orig_bankrupt_company',
                     '_orig_register_company','withdraw_company_value')
 ORDER BY 1;
-- 预期 6 行

-- 6.3 ⭐ 关键验证：拿站长和一个普通玩家各试一次
--     站长 → 应该返回正常业务结果（比如"公司不存在"）
SELECT public._orig_buy_stock(
    '22b036dd-6d4d-4b2e-ad9f-5a36dfa2d86c'::uuid, 999999, 100, false) AS 站长_应正常;

--     换一个别人的 uuid（下面这行把 id 换成任何非白名单账号）
-- SELECT public._orig_buy_stock(
--     '这里填别人的-uuid'::uuid, 999999, 100, false) AS 别人_应显示维护中;

-- 6.4 用组装的 uuid 测更省事：随便造一个没注册过的
SELECT public._orig_buy_stock(
    '00000000-0000-0000-0000-000000000001'::uuid, 999999, 100, false) AS 陌生人_应显示维护中;
-- 预期：{"ok": false, "success": false, "message": "股票系统正在升级维护，…"}


-- ============================================================
-- 第 7 步：重构完成后的恢复（现在别跑）
-- ============================================================
-- UPDATE public.stock_settings SET value='0', updated_at=now()
--  WHERE key='maintenance';


-- ============================================================
-- 紧急回滚（万一出问题）
-- ============================================================
-- 最快的一招：关掉维护模式，所有人立刻恢复访问
--   UPDATE public.stock_settings SET value='0' WHERE key='maintenance';
--
-- 彻底回滚（把实现改回原名）：
--   DROP FUNCTION IF EXISTS public._orig_buy_stock(uuid,bigint,numeric,boolean);
--   ALTER FUNCTION public._orig_buy_stock_v2(uuid,bigint,numeric,boolean)
--       RENAME TO _orig_buy_stock;
--   （其余五个同理，或者从 _func_backup_20261003 取出原定义重跑）
