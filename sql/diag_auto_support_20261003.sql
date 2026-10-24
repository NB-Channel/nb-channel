-- ============================================================
-- 自动支持（run_auto_support）失效排查
-- ============================================================
-- 用户反馈：「感觉自动支持好像没用」
--
-- 触发链一共有六道关卡，任何一道断了都不工作：
--   ① support_rules 里得有规则，且金额合法（0 < amount <= 10 万）
--   ② 规则对应公司的 market_value 必须【低于】规则的 threshold
--   ③ 用户余额 >= amount + 5% 手续费（自支持）
--   ④ 当前必须在交易时段（北京时间 8:00 ~ 20:00）
--   ⑤ 每日额度没超（自动 50 万 / 手动 200 万，看用的是哪版函数）
--   ⑥ run_auto_support 本身得有人定时调它
--
-- 逐条查，看断在哪。
-- ============================================================


-- ============================================================
-- ① 有哪些规则？参数合不合法？
-- ============================================================
SELECT
    sr.id,
    p.username                AS 用户,
    c.company_name            AS 目标公司,
    sr.amount                 AS 每次金额,
    sr.threshold              AS 触发阈值,
    c.market_value            AS 公司当前市值,
    CASE
        WHEN sr.amount IS NULL OR sr.amount <= 0       THEN '❌ 金额非法（<=0）'
        WHEN sr.amount > 100000                        THEN '❌ 金额超 10 万，会被删规则'
        WHEN c.market_value >= sr.threshold            THEN '⏸ 市值没跌破阈值，不触发'
        WHEN p.nb_balance < sr.amount * 1.05           THEN '❌ 余额不够（含 5% 手续费）'
        ELSE '✅ 条件满足，应该会触发'
    END                       AS 诊断,
    p.nb_balance              AS 用户余额,
    sr.created_at             AS 规则建立时间
FROM public.support_rules sr
LEFT JOIN public.profiles p       ON p.id = sr.user_id
LEFT JOIN public.user_companies c ON c.id = sr.company_id
ORDER BY sr.created_at DESC NULLS LAST;

-- 如果没有输出，说明压根没有规则 —— 那就是①断了
SELECT count(*) AS 规则总数 FROM public.support_rules;


-- ============================================================
-- ② 最近有没有真的支持成功过？
-- ============================================================
SELECT
    (created_at AT TIME ZONE 'Asia/Shanghai')::date AS 日期,
    count(*)      AS 注资笔数,
    count(DISTINCT supporter_id) AS 参与人数,
    sum(amount)   AS 总额
  FROM public.support_logs
 GROUP BY 1
 ORDER BY 1 DESC
 LIMIT 20;

-- 单独看自动支持是不是在跑（如果 support_rules 有记录，
-- 但 support_logs 最近没有新增，说明函数没被调用）
SELECT max(created_at) AS 最后一次注资时间 FROM public.support_logs;


-- ============================================================
-- ③ 定时任务到底有没有挂上？
-- ============================================================
-- pg_cron 的任务列表（需要装了 pg_cron 扩展）
SELECT jobid, schedule, command, active, jobname
  FROM cron.job
 ORDER BY jobid;

-- 最近的任务执行记录（看有没有报错）
SELECT jobid, status, return_message,
       start_time, end_time
  FROM cron.job_run_details
 ORDER BY start_time DESC
 LIMIT 20;

-- 如果 cron.job 是空的，或者没有 run_auto_support 相关的，那就是⑥断了
SELECT count(*) AS cron任务数 FROM cron.job;


-- ============================================================
-- ④ 采样函数里是不是顺手调了它？
-- ============================================================
-- 看 sample_market_snapshot 的正文，确认里面有没有 PERFORM run_auto_support
SELECT pg_get_functiondef(p.oid) AS 定义
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'sample_market_snapshot';


-- ============================================================
-- ⑤ 现在是不是交易时段？
-- ============================================================
SELECT
    now() AT TIME ZONE 'Asia/Shanghai'            AS 北京时间,
    (now() AT TIME ZONE 'Asia/Shanghai')::time    AS 当前时刻,
    CASE WHEN (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '08:00'
          AND (now() AT TIME ZONE 'Asia/Shanghai')::time <  time '20:00'
         THEN '✅ 开市中，可以支持'
         ELSE '⏸ 休市中（8:00~20:00 之外），support_company 会拒绝' END AS 状态;


-- ============================================================
-- ⑥ 手动跑一次，看它报什么
-- ============================================================
-- 直接调用，看 NOTICE 输出（Supabase SQL Editor 会显示在下方 Messages）
-- PERFORM public.run_auto_support();
--
-- 它会打印：
--   run_auto_support: 执行支持 N 条 · 余额不足保留 M 条 · 清理失效 K 条
-- 从这三个数字就能看出到底卡在哪。


-- ============================================================
-- ⑦ 手动模拟一条规则的判断过程
-- ============================================================
-- 把下面公司的 id 换成你关心那个，逐步看每一道关卡：
--
-- SELECT
--     c.id,
--     c.company_name,
--     c.market_value,
--     sr.threshold,
--     sr.amount,
--     p.nb_balance,
--     (c.market_value < sr.threshold)              AS 关卡②市值够低,
--     (p.nb_balance >= sr.amount * 1.05)           AS 关卡③余额够,
--     ((now() AT TIME ZONE 'Asia/Shanghai')::time >= time '08:00'
--      AND (now() AT TIME ZONE 'Asia/Shanghai')::time < time '20:00') AS 关卡④开市中
--   FROM public.support_rules sr
--   JOIN public.user_companies c ON c.id = sr.company_id
--   JOIN public.profiles p ON p.id = sr.user_id;
