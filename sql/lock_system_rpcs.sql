-- ============================================================
-- 系统/定时任务类 RPC 封锁
-- 这些函数本来是给定时任务或内部逻辑用的,但匿名也能调用:
--   bank_daily_settle        手动触发银行日结(反复调=刷利息)
--   random_fluctuate_market_values  手动触发全站市值波动(能操纵行情)
--   renew_shop_items         手动触发道具续期
--   refund_expired_redpackets 手动触发红包退款
--   sample_market_snapshot   手动触发快照
--   record_daily_kline       手动触发日K线聚合
--   delete_old_history_full  删除历史快照
--   run_auto_support         手动触发自动支持
--   check_comment_bad_words  批量扫描违禁词
--   compute_title_stars / compute_title_value  称号计算(内部用)
-- 前端完全不调用它们,直接收掉执行权限即可(定时任务以数据库身份运行,不受影响)
-- ============================================================

DO $$
DECLARE
    fns text[] := ARRAY[
        'bank_daily_settle', 'record_daily_kline', 'random_fluctuate_market_values',
        'renew_shop_items', 'run_auto_support', 'sample_market_snapshot',
        'refund_expired_redpackets', 'delete_old_history_full', 'check_comment_bad_words',
        'compute_title_stars', 'compute_title_value'
    ];
    r record;
    n int := 0;
BEGIN
    FOR r IN
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS ident
          FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
         WHERE ns.nspname = 'public' AND p.proname = ANY(fns)
    LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated', r.proname, r.ident);
        RAISE NOTICE '已封锁: %(%)', r.proname, r.ident;
        n := n + 1;
    END LOOP;
    RAISE NOTICE '共封锁 % 个系统函数', n;
END $$;

-- ---------- 验收:这些函数匿名应全部不可执行(false) ----------
SELECT p.proname AS 函数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_可调用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('bank_daily_settle','record_daily_kline','random_fluctuate_market_values',
                     'renew_shop_items','run_auto_support','sample_market_snapshot',
                     'refund_expired_redpackets','delete_old_history_full','check_comment_bad_words',
                     'compute_title_stars','compute_title_value','check_admin_password_plain')
 ORDER BY 1;
