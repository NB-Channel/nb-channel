-- ============================================================
--  删掉 update_support_rule 的旧重载（5 参数版）
--
--  【为什么会剩一个】
--    PostgreSQL 的 CREATE OR REPLACE FUNCTION 只在
--    【函数名 + 参数列表完全一样】时才替换。
--
--    上一次我改了参数：
--        旧：update_support_rule(uuid, text, bigint, numeric, numeric)
--              (p_user_id, p_session, p_rule_id, p_threshold, p_amount)
--        新：update_support_rule(uuid, text, bigint, numeric, numeric, numeric)
--              (p_user_id, p_session, p_rule_id, p_price_target, p_amount, p_daily_limit)
--
--    参数个数不一样 → PostgreSQL 认为这是【另一个函数】，
--    于是新建了一个重载，旧的 5 参数版原封不动留在库里。
--
--    验证查询因此返回两行，其中一行仍然是「❌ 还在写 threshold」。
--
--  【为什么要删】
--    旧的还在写 support_rules.threshold（那个 AMM 之后的死字段）。
--    前端现在传的是 6 个参数（p_price_target / p_daily_limit），
--    PostgREST 会匹配到新的 6 参数版 —— 但旧的留着是个隐患：
--      · 万一有别的代码按老签名调用，就会又写进死字段
--      · 而且两份逻辑并存，以后维护容易看错
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 一、先看清楚现在有几个重载
-- ============================================================
SELECT
    p.oid                                     AS 函数id,
    pg_get_function_identity_arguments(p.oid) AS 参数列表,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%SET price_target = p_price_target%'
         THEN '✅ 新（写 price_target）'
         WHEN pg_get_functiondef(p.oid) LIKE '%SET threshold = p_threshold%'
         THEN '❌ 旧（写死字段 threshold）'
         ELSE '—' END                         AS 是哪一版
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'update_support_rule'
 ORDER BY p.oid;


-- ============================================================
-- 二、删掉旧的 5 参数版
-- ============================================================
DROP FUNCTION IF EXISTS public.update_support_rule(uuid, text, bigint, numeric, numeric);


-- ============================================================
-- 三、验证：只剩一个，而且是新的
-- ============================================================
SELECT
    count(*)                                                  AS 还剩几个,
    count(*) FILTER (WHERE pg_get_functiondef(p.oid)
                           LIKE '%SET price_target = p_price_target%') AS 新版个数,
    count(*) FILTER (WHERE pg_get_functiondef(p.oid)
                           LIKE '%SET threshold = p_threshold%')       AS 旧版个数,
    string_agg(pg_get_function_identity_arguments(p.oid), ' | ')       AS 参数列表
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'update_support_rule';

-- 期望：还剩几个 = 1，新版个数 = 1，旧版个数 = 0


-- ============================================================
-- 四、顺便查一下：还有没有别的函数也被这样留了重载
-- ============================================================
-- 最近这轮改过参数个数的函数，都可能踩同一个坑。
SELECT
    p.proname                        AS 函数名,
    count(*)                         AS 重载个数,
    string_agg(pg_get_function_identity_arguments(p.oid), '  |  ') AS 各版本的参数
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('update_support_rule', 'set_auto_buy_rule',
                     'toggle_auto_buy_rule', 'get_my_auto_buy_rules',
                     'extract_company_value', 'collect_company_tax')
 GROUP BY p.proname
 ORDER BY count(*) DESC, p.proname;

-- 期望：每行重载个数都是 1


-- ============================================================
--  改完之后
-- ============================================================
--  · 前端（profile 两个页面）传的是 6 个参数，会匹配到新版 ✅
--  · 「谁在支持我的公司」和「我的自动抄底规则」两块应该就能正常显示了
--
--  ⚠️ 记一条教训：
--    以后凡是【改动函数参数个数】的，不能只用 CREATE OR REPLACE ——
--    必须先 DROP 掉旧签名，否则会留一个重载在库里，
--    而且替换看起来"成功了"，验证却会返回两行。
-- ============================================================
