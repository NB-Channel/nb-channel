-- ============================================================
-- 股票系统维护模式：只允许白名单账号访问
-- ============================================================
-- 用途：重构 AMM 模型期间，把股票功能对所有人关掉，只留站长自己。
--
-- 【两层拦截】
--   第一层（本脚本）  数据库层 —— 买卖注资全部拒绝，前端绕不过去
--   第二层（另一步）  页面层   —— 打开股票页显示"维护中"，给玩家看的
--
-- 【原理】
--   把现有的实现函数改名为 xxx_v2（保留原样，一行没动），
--   然后用同名的新函数包一层：先查白名单，通过了再转给 _v2。
--   这样不用改实现代码，风险最小。
--
-- 【执行顺序很重要】
--   第 4 步（改名）必须在第 5 步（建包装）之前。
--   中间有个极短的窗口期调用会失败，但整段脚本一起提交，实际察觉不到。
--   顺序错了也不会丢数据，只是调用报"函数不存在"。
--
-- ⚠️ 执行前先做第 0 步备份。
-- ============================================================


-- ============================================================
-- 第 0 步：备份这几个函数的定义（万一要回滚）
-- ============================================================
CREATE TABLE IF NOT EXISTS public._func_backup_20261003 AS
SELECT p.proname AS 函数名, pg_get_functiondef(p.oid) AS 定义, now() AS 备份时间
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock', '_orig_sell_stock',
                     '_orig_support_company', '_orig_bankrupt_company',
                     '_orig_register_company', 'withdraw_company_value',
                     'buy_stock', 'sell_stock', 'support_company',
                     'bankrupt_company', 'register_company');

SELECT 函数名, length(定义) AS 定义长度 FROM public._func_backup_20261003 ORDER BY 函数名;


-- ============================================================
-- 第 1 步：建开关和白名单
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

INSERT INTO public.stock_settings (key, value) VALUES
    ('maintenance',        '1'),
    ('maintenance_notice', '股票系统正在升级为新版交易模型，你的持仓和资金都不会受影响。请稍后再来。')
ON CONFLICT (key) DO NOTHING;


-- ============================================================
-- 第 2 步：找出你的 user_id
-- ============================================================
SELECT id, username, nb_balance
  FROM public.profiles
 ORDER BY nb_balance DESC NULLS LAST
 LIMIT 20;

-- ⚠️ 把下面那句的 uuid 换成你自己的，然后执行（可以加多个号）
--    注意：白名单为空 + 维护模式开启 = 你自己也进不去
--
-- INSERT INTO public.stock_whitelist (user_id, note) VALUES
--     ('你的-uuid-1', '站长主号'),
--     ('你的-uuid-2', '站长小号')
-- ON CONFLICT (user_id) DO NOTHING;


-- ============================================================
-- 第 3 步：判定函数
-- ============================================================
CREATE OR REPLACE FUNCTION public._stock_allowed(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_maint text;
BEGIN
    SELECT value INTO v_maint FROM public.stock_settings WHERE key = 'maintenance';
    IF v_maint IS NULL OR v_maint = '0' THEN
        RETURN true;                    -- 正常模式，所有人放行
    END IF;
    RETURN EXISTS (SELECT 1 FROM public.stock_whitelist WHERE user_id = p_user_id);
END
$fn$;

GRANT EXECUTE ON FUNCTION public._stock_allowed(uuid) TO anon;

-- 自测（把 uuid 换掉）：
-- SELECT public._stock_allowed('你的-uuid')   AS 应该true,
--        public._stock_allowed(null)         AS 应该false;


-- ============================================================
-- 第 3.5 步：先看看有没有别的函数在调这些 _orig_*
-- ------------------------------------------------------------
-- 如果有，改名之后它们也得跟着改，所以先查清楚。
-- ============================================================
SELECT p.proname AS 调用者,
       CASE
         WHEN pg_get_functiondef(p.oid) LIKE '%_orig_buy_stock%'       THEN '_orig_buy_stock'
         WHEN pg_get_functiondef(p.oid) LIKE '%_orig_sell_stock%'      THEN '_orig_sell_stock'
         WHEN pg_get_functiondef(p.oid) LIKE '%_orig_support_company%' THEN '_orig_support_company'
         WHEN pg_get_functiondef(p.oid) LIKE '%_orig_bankrupt_company%'THEN '_orig_bankrupt_company'
         WHEN pg_get_functiondef(p.oid) LIKE '%_orig_register_company%'THEN '_orig_register_company'
       END AS 被调用者
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (pg_get_functiondef(p.oid) LIKE '%_orig_buy_stock%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_sell_stock%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_support_company%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_bankrupt_company%'
     OR pg_get_functiondef(p.oid) LIKE '%_orig_register_company%')
 ORDER BY 1;

-- 预期只会看到 buy_stock / sell_stock / support_company / bankrupt_company /
-- _orig_nodup_register_company / run_auto_support 这几个。
-- 如果还有别的，记下来，第 6 步要一起处理。


-- ============================================================
-- 第 4 步：改名（把现有实现挪到 _v2 名下，内容一字未动）
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

-- 提取公司价值那个没有 _orig_ 前缀，单独处理
ALTER FUNCTION public.withdraw_company_value(uuid, text, bigint, numeric)
    RENAME TO _withdraw_company_value_v2;


-- ============================================================
-- 第 5 步：建包装（同名的外壳，先查白名单再转发）
-- ============================================================

-- 5.1 买入
CREATE OR REPLACE FUNCTION public._orig_buy_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    RETURN public._orig_buy_stock_v2(p_user_id, p_company_id, p_amount, p_use_discount);
END
$fn$;

-- 5.2 卖出
CREATE OR REPLACE FUNCTION public._orig_sell_stock(
    p_user_id uuid, p_company_id bigint, p_amount numeric,
    p_use_discount boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法交易，请稍后再来');
    END IF;
    RETURN public._orig_sell_stock_v2(p_user_id, p_company_id, p_amount, p_use_discount);
END
$fn$;

-- 5.3 注资
CREATE OR REPLACE FUNCTION public._orig_support_company(
    p_user_id uuid, p_company_id bigint, p_amount integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN public._orig_support_company_v2(p_user_id, p_company_id, p_amount);
END
$fn$;

-- 5.4 破产
CREATE OR REPLACE FUNCTION public._orig_bankrupt_company(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN public._orig_bankrupt_company_v2(p_user_id);
END
$fn$;

-- 5.5 注册公司
CREATE OR REPLACE FUNCTION public._orig_register_company(
    p_user_id uuid, p_company_name text, p_need_verify boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('success', false,
            'message', '股票系统正在升级维护，暂时无法注册公司');
    END IF;
    RETURN public._orig_register_company_v2(p_user_id, p_company_name, p_need_verify);
END
$fn$;

-- 5.6 提取公司价值
CREATE OR REPLACE FUNCTION public.withdraw_company_value(
    p_user_id uuid, p_session text, p_company_id bigint, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
    IF NOT public._stock_allowed(p_user_id) THEN
        RETURN jsonb_build_object('ok', false,
            'message', '股票系统正在升级维护，暂时无法操作，请稍后再来');
    END IF;
    RETURN public._withdraw_company_value_v2(p_user_id, p_session, p_company_id, p_amount);
END
$fn$;

-- 5.7 自动支持也拦一道
--     它是服务端任务，没有"当前用户"的概念，但规则里有 user_id。
--     最省事的做法是让 run_auto_support 自己去过滤 —— 见第 6 步。


-- ============================================================
-- 第 6 步：挡住自动支持（否则维护期间它还在偷偷注资）
-- ------------------------------------------------------------
-- run_auto_support 会逐个规则调用 support_company，
-- support_company 最终走到 _orig_support_company —— 已经被拦了，
-- 所以【不改也不会漏】。
--
-- 但它会产生大量"维护中"的失败日志。想干净的话，
-- 在它循环开头加一句跳过。这需要它的完整定义，先看一下：
-- ============================================================
SELECT pg_get_functiondef(p.oid) AS 定义
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'run_auto_support';


-- ============================================================
-- 第 7 步：验收
-- ============================================================
-- 7.1 开关
SELECT * FROM public.stock_settings;

-- 7.2 白名单
SELECT w.user_id, p.username, w.note
  FROM public.stock_whitelist w
  LEFT JOIN public.profiles p ON p.id = w.user_id;

-- 7.3 拦截生效验证
--     把 uuid 换成别人的（非白名单的），应该返回"维护中"
-- SELECT public._orig_buy_stock('别人的-uuid', 1, 100, false);
--
--     换成你自己的，应该返回正常的业务结果（比如"余额不足""公司不存在"）
-- SELECT public._orig_buy_stock('你的-uuid', 1, 100, false);

-- 7.4 确认 _v2 都还在（改名成功）
SELECT p.proname AS 函数, length(pg_get_functiondef(p.oid)) AS 定义长度
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_buy_stock_v2', '_orig_sell_stock_v2',
                     '_orig_support_company_v2', '_orig_bankrupt_company_v2',
                     '_orig_register_company_v2', '_withdraw_company_value_v2')
 ORDER BY 1;


-- ============================================================
-- 第 8 步：重构完成后恢复正常
-- ============================================================
-- UPDATE public.stock_settings SET value = '0', updated_at = now()
--  WHERE key = 'maintenance';
--
-- 白名单可以留着（不影响），也可以清掉：
-- DELETE FROM public.stock_whitelist;


-- ============================================================
-- 万一要回滚（把实现改回原名、删掉包装）
-- ============================================================
-- DROP FUNCTION IF EXISTS public._orig_buy_stock(uuid, bigint, numeric, boolean);
-- ALTER FUNCTION public._orig_buy_stock_v2(uuid, bigint, numeric, boolean)
--     RENAME TO _orig_buy_stock;
-- （其余几个同理）
--
-- 或者直接从 _func_backup_20261003 里把定义取出来重跑：
-- SELECT 定义 FROM public._func_backup_20261003 WHERE 函数名 = '_orig_buy_stock';
