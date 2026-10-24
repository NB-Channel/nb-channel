-- ============================================================
-- 市场调度体检 —— 一次性回答三个问题:
--   ① 市值到底还在不在波动?
--   ② 波动是谁在驱动(pg_cron 自循环 还是 GitHub Actions 兜底)?
--   ③ 公司税是什么时候收的、今晚 20:00 会不会正常收?
--
-- 用法:整段复制到 Supabase SQL Editor 跑,把结果全部贴回来。
-- 最后两条涉及 pg_cron,没启用的话会报错 —— 没关系,前面的结果已经出来了。
-- ============================================================

-- ---------- ① 现在几点 ----------
SELECT now() AS "UTC时间",
       (now() AT TIME ZONE 'Asia/Shanghai') AS "北京时间",
       CASE WHEN (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '08:00'
             AND (now() AT TIME ZONE 'Asia/Shanghai')::time <  time '20:00'
            THEN '交易时段(波动应该在跑)'
            ELSE '休市时段(波动本来就该停)' END AS "当前时段";

-- ---------- ② 心跳:波动 / 采样 各自多久没动了 ----------
-- 判定依据:
--   pg_cron 的 market-tick 每 10 秒波动一次 → last_fluctuate 应该在 2 分钟内
--   只剩每小时 Actions 兜底          → last_fluctuate 会停在 1 小时上下
--   完全没在跑                        → 停在几小时 / 几天前
SELECT h.项目,
       coalesce(m.value, '(没有这条记录)') AS "记录时间",
       CASE WHEN m.value IS NULL THEN '—'
            ELSE round(EXTRACT(EPOCH FROM (now() - m.value::timestamptz)))::text || ' 秒前'
       END AS "距现在",
       CASE
         WHEN m.value IS NULL AND h.键 = 'last_sample'
              THEN '❌ 从未采样 → market_tick_loop 从没成功跑过'
         WHEN m.value IS NULL
              THEN '❌ 没有记录 → 波动函数从没被调用'
         WHEN now() - m.value::timestamptz < interval '2 minutes'
              THEN '✅ 在跑'
         WHEN now() - m.value::timestamptz < interval '20 minutes'
              THEN '⚠️ 偏慢(像是 15 分钟采样在驱动)'
         WHEN now() - m.value::timestamptz < interval '90 minutes'
              THEN '⚠️ 只有每小时兜底在跑'
         ELSE '❌ 早就停了'
       END AS "判定"
  FROM (VALUES ('波动 last_fluctuate', 'last_fluctuate'),
               ('采样 last_sample',    'last_sample')) AS h(项目, 键)
  LEFT JOIN public.market_meta m ON m.key = h.键;

-- ---------- ③ 公司税 ----------
SELECT m.value AS "上次收税日期",
       to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD') AS "今天(北京)",
       CASE
         WHEN m.value = to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD')
              THEN '今天已收过 → 今晚 20:00 不会再收(想验证新逻辑就执行文件末尾的 DELETE)'
         ELSE '今天还没收 → 今晚 20:00 后由采样自动收'
       END AS "说明"
  FROM public.market_meta m
 WHERE m.key = 'last_tax_date';

-- ---------- ④ 市值现状(收税后应该能看到大公司开始回落) ----------
SELECT count(*)                                        AS "公司数",
       round(sum(market_value) / 1e8, 2)               AS "总市值(亿)",
       round(max(market_value) / 1e8, 2)               AS "最大(亿)",
       count(*) FILTER (WHERE market_value >= 300000)  AS "需缴税家数",
       count(*) FILTER (WHERE market_value >= 50000000) AS "2%档家数"
  FROM public.user_companies;

-- ---------- ⑤ pg_cron 装了没 ----------
SELECT extname AS "已启用扩展" FROM pg_extension WHERE extname = 'pg_cron';

-- ---------- ⑥ pg_cron 任务清单(没启用会报错,忽略) ----------
SELECT jobid, schedule, jobname, active, command FROM cron.job ORDER BY jobid;

-- ---------- ⑦ 最近调度执行记录(重点看 status / return_message) ----------
SELECT jobid, status, left(return_message, 150) AS "返回信息", start_time
  FROM cron.job_run_details
 ORDER BY start_time DESC
 LIMIT 15;

-- ============================================================
-- 【可选】想让今晚 20:00 立刻验证「休市后收税」的新逻辑,执行这一句:
--   删掉"今天已收过"的标记,今晚 20:00 后的第一次采样就会收税。
--   不执行也行,明天自然就走上新逻辑了。
-- ============================================================
-- DELETE FROM public.market_meta WHERE key = 'last_tax_date';
