-- ============================================================
-- 修复:恢复两个定时任务所需 RPC 的匿名执行权限
-- 背景:lock_system_rpcs.sql 把一批系统函数对匿名封锁了,但其中两个
--       是被 GitHub Actions 定时任务调用的(用 anon key):
--         .github/workflows/market_open.yml    → record_daily_kline()      每天 08:00
--         .github/workflows/market_sample.yml  → sample_market_snapshot()  每小时
--       封锁后这两个任务会返回 401 而静默失败 → K线/历史市值会断档。
-- 说明:这两个函数是幂等且无害的(按当前真实数据聚合/采样,不改变行情),
--       放行匿名调用没有安全风险;真正危险的 random_fluctuate_market_values
--       (能手动操纵市值)没有出现在任何定时任务里,保持封锁。
-- ============================================================

GRANT EXECUTE ON FUNCTION public.record_daily_kline() TO anon;
GRANT EXECUTE ON FUNCTION public.sample_market_snapshot() TO anon;

-- ---------- 验收 ----------
SELECT p.proname AS 函数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_可调用,
       CASE WHEN p.proname IN ('record_daily_kline', 'sample_market_snapshot')
            THEN '定时任务需要 → 应为 true'
            ELSE '应保持封锁 → 应为 false' END AS 期望
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('record_daily_kline', 'sample_market_snapshot',
                     'random_fluctuate_market_values', 'bank_daily_settle',
                     'renew_shop_items', 'run_auto_support',
                     'refund_expired_redpackets', 'delete_old_history_full')
 ORDER BY p.proname;

-- ---------- 顺手确认:那两个定时任务现在能不能通(在 SQL Editor 里直接调一次) ----------
-- 如果返回成功(不报 401/权限错),说明修好了:
SELECT public.record_daily_kline() AS 日K线聚合结果;
