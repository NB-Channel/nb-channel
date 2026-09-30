-- ============================================================
-- 一批修复 · 第 2 批（2026-09-30）
-- ============================================================
-- 内容：收紧几张「不该对外公开」的交易/记录表的读取权限。
--
-- 背景：这些表目前是【所有列匿名可读】的 —— 任何人拿网页里那把公开 key
--       就能把内容整表拉走。它们不影响资金安全（不能改数），但属于隐私泄露：
--         product_purchases  : 谁买了哪个作品、付了多少钱
--         product_downloads  : 谁下载了什么、什么时候下的
--         support_logs       : 谁给哪家公司投了多少钱
--         user_checkins      : 每个人的签到记录
--
-- 处理原则：前端不再直连查表的，直接撤权限；
--           前端确实要用的（「我买过哪些作品」），改成一个带登录校验的 RPC。
--
-- ⚠️ support_rules（自动支持规则）这次先不动 —— 前端对它是读+改+删三套操作
--    散在 4 个页面里，改动面太大，单独一批做，免得把自动支持功能弄坏。
-- ============================================================


-- ============================================================
-- ① 三张前端用不到的表：直接撤读权限
-- ============================================================
-- 这三个都只被 SECURITY DEFINER 的 RPC 在内部使用（purchase_product /
-- download_product / 签到相关），而 SECURITY DEFINER 以函数所有者身份运行，
-- 不受表权限影响 —— 所以撤掉匿名读不会影响任何功能。
REVOKE SELECT ON public.product_downloads FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.support_logs      FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.user_checkins     FROM PUBLIC, anon, authenticated;


-- ============================================================
-- ② 购买记录：改成 RPC
-- ============================================================
-- 前端唯一的用途是「在我买过的作品上打个标记」，需要的就是一串 product_id。
-- 注意它必须带登录校验 —— 不能让 A 传 B 的 id 去查 B 买过什么。
CREATE OR REPLACE FUNCTION public.get_my_purchased_ids(
    p_user_id uuid,
    p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_ids jsonb;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'reason', '请先登录');
    END IF;

    SELECT coalesce(jsonb_agg(DISTINCT product_id), '[]'::jsonb)
      INTO v_ids
      FROM public.product_purchases
     WHERE buyer_id = p_user_id;

    RETURN jsonb_build_object('ok', true, 'ids', v_ids);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.get_my_purchased_ids(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_purchased_ids(uuid, text) TO anon;

-- 撤掉直连读；顺手把 INSERT 也收掉 —— 购买是走 purchase_product RPC 的，
-- 前端本来就不该直接往这张表里写。
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.product_purchases FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 验收
-- ============================================================
-- 这四张表现在匿名都应该读不到（期望全是 f）
SELECT 'product_purchases' AS 表, has_table_privilege('anon','public.product_purchases','SELECT') AS 匿名可读_应为f
UNION ALL SELECT 'product_downloads', has_table_privilege('anon','public.product_downloads','SELECT')
UNION ALL SELECT 'support_logs',      has_table_privilege('anon','public.support_logs','SELECT')
UNION ALL SELECT 'user_checkins',     has_table_privilege('anon','public.user_checkins','SELECT');

-- 新 RPC 在不在
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public' AND p.proname = 'get_my_purchased_ids' AND p.prokind = 'f';
-- 应该 1 行：p_user_id uuid, p_session text
