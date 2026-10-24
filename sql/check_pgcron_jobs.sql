-- ============================================================
-- 先跑这个:确认数据库里的 pg_cron 到底调度了什么
--
-- 为什么需要:market_sample.yml 的注释说"数据库自循环(pg_cron)是主力,
-- 交易时段 15 分钟一次",但看代码 random_fluctuate_market_values
-- (真正让市值波动的函数)并没有出现在任何 GitHub Actions 定时任务里。
-- 需要确认它是否被 pg_cron 调用 —— 这决定波动到底还在不在跑。
-- ============================================================

-- 1) pg_cron 的任务清单(重点看 command 列里有没有 random_fluctuate)
SELECT jobid, schedule, command, active, jobname
  FROM cron.job
 ORDER BY jobid;

-- 2) 如果上面的表不存在(没启用 pg_cron),这里会报错,那就说明只有 Actions 在采样
SELECT extname AS 已启用扩展 FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net');

-- 3) 最近几次调度执行记录(能看到实际跑了什么、有没有失败)
SELECT jobid, status, return_message, start_time
  FROM cron.job_run_details
 ORDER BY start_time DESC
 LIMIT 20;

-- 4) 上一次市值波动 / 采样 / 收税 是什么时候
--    注意 last_sample 只有 market_tick_loop 成功跑过才会有 —— 没有它基本可以断定
--    pg_cron 自循环没在跑(Actions 的兜底采样不写这个键)。
--    ⚠️ 本文件已被 check_market_scheduler.sql 取代,那个更全,建议直接跑那个。
SELECT key AS 项目, value AS 值
  FROM public.market_meta
 WHERE key IN ('last_fluctuate', 'last_sample', 'last_tax_date')
 ORDER BY key;
