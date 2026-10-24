-- ============================================================
-- 修复：后端查"是否已购买"被权限挡住（2026-10-01）
-- ============================================================
-- 报错原文：
--   后端数据库连接失败: {'message': 'permission denied for table
--   product_purchases', 'code': '42501'}
--
-- 原因：批次 2 的安全加固里我 REVOKE 了 product_purchases 的 anon 权限
--      （当时是为了堵"交易记录匿名可读"），但没注意到
--      pythonanywhere/app.py L837 还在用它 —— 后端用的是 ANON_KEY，
--      于是"卖作品时选加市值支持"这条路就断了。
--
-- 修法：不改权限（打开就等于把漏洞放回来），改成走 SECURITY DEFINER 的 RPC。
--      后端那一处 select 换成调这个函数。
-- ============================================================


-- ============================================================
-- ① 查是否已购买
-- ============================================================
-- 参数用 text 而不是 bigint/uuid：
--   后端传过来的 product_id 可能来自 JSON，类型不稳定，
--   在函数里再转，比在 SQL 签名上卡死更稳。
CREATE OR REPLACE FUNCTION public.check_product_purchased(
    p_product_id text,
    p_user_id    uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
    IF p_product_id IS NULL OR p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '参数不完整');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'purchased', EXISTS (
            SELECT 1 FROM public.product_purchases
             WHERE product_id::text = p_product_id
               AND buyer_id = p_user_id
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;

REVOKE ALL ON FUNCTION public.check_product_purchased(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_product_purchased(text, uuid) TO anon;


-- ============================================================
-- ② 顺便：把批次 2 撤权限时可能漏掉的同类用法也补上
-- ============================================================
-- get_my_purchased_ids 是批次 2 一起建的，确认它还在
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'get_my_purchased_ids'
    ) THEN
        RAISE NOTICE '⚠️ get_my_purchased_ids 不存在，前端 product_share 会报错，需要重建';
    ELSE
        RAISE NOTICE '✅ get_my_purchased_ids 在';
    END IF;
END $$;


-- ============================================================
-- 验收
-- ============================================================
-- 应该返回 success=true 和 purchased=false（不存在的购买记录）
SELECT public.check_product_purchased('0', '00000000-0000-0000-0000-000000000000') AS 测试不存在;

-- 确认 anon 能调
SELECT has_function_privilege('anon',
       'public.check_product_purchased(text,uuid)', 'EXECUTE') AS anon_可调_应为t;

-- 确认 product_purchases 表本身仍然对 anon 关闭（安全没退步）
SELECT has_table_privilege('anon', 'public.product_purchases', 'SELECT')
       AS 表仍对anon关闭_应为f;
