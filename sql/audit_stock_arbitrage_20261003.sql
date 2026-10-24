-- ============================================================
-- 刷币漏洞善后：普查 + 清理
-- ============================================================
--
-- 前提：fix_stock_arbitrage_20261003.sql 已经跑过，漏洞已堵。
-- 这份脚本只做【查】和【清】，不再改任何函数。
--
-- 建议顺序：
--   第一步 跑「一、全站体检」     —— 看清现在什么状况
--   第二步 跑「二、逐个账号画像」 —— 判断哪些是刷的
--   第三步 跑「三、清理」         —— 想清楚了再执行，默认注释掉
--   第四步 跑「四、复验」
--
-- ⚠️ 清理前先备份：
--      CREATE TABLE profiles_backup_20261003 AS SELECT * FROM public.profiles;
-- ============================================================


-- ============================================================
-- 一、全站体检
-- ============================================================
SELECT
    (SELECT count(*) FROM public.profiles)                          AS 账号数,
    (SELECT count(*) FROM public.user_companies)                    AS 公司数,
    (SELECT count(*) FROM public.holdings)                          AS 持仓数,
    (SELECT COALESCE(sum(market_value), 0) FROM public.user_companies) AS 全站总市值,
    (SELECT COALESCE(sum(nb_balance), 0) FROM public.profiles)      AS 全站总余额,
    (SELECT COALESCE(sum(amount), 0) FROM public.support_logs)      AS 历史注资总额,
    (SELECT count(*) FROM public.transactions)                      AS 交易笔数;


-- ============================================================
-- 二、账号画像
-- ------------------------------------------------------------
-- 把余额异常的账号和它的「可疑行为」一起列出来：
--   · 注资次数/总额    —— 刷币的核心动作
--   · 破产次数         —— 每次破产换一笔 reward（如果 transactions 里有记录）
--   · 买卖次数与盈亏   —— 看是不是小号在配合
-- ============================================================
WITH sup AS (
    SELECT supporter_id AS uid,
           count(*)      AS 注资次数,
           sum(amount)   AS 注资总额
      FROM public.support_logs
     GROUP BY supporter_id
),
tx AS (
    SELECT user_id AS uid,
           count(*) FILTER (WHERE type = 'buy')  AS 买入次数,
           count(*) FILTER (WHERE type = 'sell') AS 卖出次数,
           COALESCE(sum(fee), 0)                 AS 累计手续费
      FROM public.transactions
     GROUP BY user_id
),
co AS (
    SELECT user_id AS uid, count(*) AS 建公司次数
      FROM public.user_companies
     GROUP BY user_id
)
SELECT
    p.username                                   AS 用户名,
    p.nb_balance                                 AS 余额,
    COALESCE(sup.注资次数, 0)                     AS 注资次数,
    COALESCE(sup.注资总额, 0)                     AS 注资总额,
    COALESCE(tx.买入次数, 0)                      AS 买入次数,
    COALESCE(tx.卖出次数, 0)                      AS 卖出次数,
    COALESCE(co.建公司次数, 0)                    AS 现有公司数,
    p.id                                         AS user_id
FROM public.profiles p
LEFT JOIN sup ON sup.uid = p.id
LEFT JOIN tx  ON tx.uid  = p.id
LEFT JOIN co  ON co.uid  = p.id
WHERE p.nb_balance > 10000000                    -- 只看余额一千万以上的
ORDER BY p.nb_balance DESC
LIMIT 40;


-- ============================================================
-- 三、清理（默认整段注释掉，看清楚了再逐条放开）
-- ============================================================
--
-- 【3.1】先把要处理的账号挑出来看一眼
--
-- SELECT id, username, nb_balance
--   FROM public.profiles
--  WHERE nb_balance > 1000000000        -- 十亿以上，基本不可能是正常玩出来的
--  ORDER BY nb_balance DESC;
--
--
-- 【3.2】按用户名重置余额
--        建议留一个「体面」的数字 —— 别清零，
--        清零的人往往会开新号继续，留点钱反而不闹
--
-- UPDATE public.profiles
--    SET nb_balance = 1000000
--  WHERE username IN ('Utw', 'utw', 'Utvv', 'Utw小号',
--                     'Utw的机器店官号', 'Utw宿舍官号',
--                     'Utw的小NB肉餐厅官号', 'Utw的3ty肉餐厅官号');
--
--
-- 【3.3】或者按阈值批量处理（更省事，但要先确认阈值合理）
--
-- UPDATE public.profiles
--    SET nb_balance = 1000000
--  WHERE nb_balance > 1000000000;
--
--
-- 【3.4】他们名下公司的市值也虚高，一起压下来
--
-- UPDATE public.user_companies
--    SET market_value = 20000
--  WHERE user_id IN (SELECT id FROM public.profiles WHERE nb_balance >= 1000000)
--    AND market_value > 20000;
--    -- ⚠️ 注意：这条会把【清完之后】刚被 3.2 重置过的号也一起处理，
--    --    因为它按 nb_balance >= 1000000 筛。执行前先 SELECT 看一眼命中哪些。
--
--
-- 【3.5】清掉注资记录（会影响「今日累计注资上限」的统计）
--        一般不用清 —— 留着正好可以拿来做「他今天已经注过多少」的判断
--
-- -- DELETE FROM public.support_logs WHERE supporter_id IN (...);


-- ============================================================
-- 四、复验
-- ============================================================
SELECT
    (SELECT COALESCE(sum(nb_balance), 0) FROM public.profiles)      AS 全站总余额,
    (SELECT COALESCE(sum(market_value), 0) FROM public.user_companies) AS 全站总市值,
    (SELECT count(*) FROM public.profiles WHERE nb_balance > 1000000000) AS 十亿以上账号数;


-- ============================================================
-- 四点五、找起爆点：漏洞是从哪天开始的
-- ------------------------------------------------------------
-- 刷币必然伴随大量 support_logs（注资），所以按天统计注资总额，
-- 哪天突然暴涨，哪天就是起点 —— 这样能定出回滚的时间线。
-- ============================================================
SELECT
    (created_at AT TIME ZONE 'Asia/Shanghai')::date AS 日期,
    count(*)                          AS 注资笔数,
    sum(amount)                       AS 注资总额,
    count(DISTINCT supporter_id)      AS 参与人数,
    count(DISTINCT company_id)        AS 涉及公司数
  FROM public.support_logs
 GROUP BY 1
 ORDER BY 1 DESC
 LIMIT 60;

-- 单看某一家的注资节奏（把用户名换成你关心那个）
SELECT
    (s.created_at AT TIME ZONE 'Asia/Shanghai')::date AS 日期,
    count(*)      AS 笔数,
    sum(s.amount) AS 总额
  FROM public.support_logs s
  JOIN public.profiles p ON p.id = s.supporter_id
 WHERE p.username = 'Utw'
 GROUP BY 1
 ORDER BY 1 DESC
 LIMIT 30;

-- 交易流水按天（买卖各有几次，正常玩家一天几次）
SELECT
    (created_at AT TIME ZONE 'Asia/Shanghai')::date AS 日期,
    count(*) FILTER (WHERE type = 'buy')  AS 买入,
    count(*) FILTER (WHERE type = 'sell') AS 卖出,
    count(DISTINCT user_id)               AS 参与人数
  FROM public.transactions
 GROUP BY 1
 ORDER BY 1 DESC
 LIMIT 60;


-- ============================================================
-- 五、以后怎么早发现
-- ------------------------------------------------------------
-- 这三个指标放一个定时任务里，超阈值就告警：
--   · 全站总余额增长 —— 正常应该随签到/任务缓慢上升，突然暴涨就是有问题
--   · 单个账号余额   —— 超过某个数（比如 1 亿）就该人工看一眼
--   · support_logs 的当日笔数 —— 正常玩家一天注资几次，几百次就是脚本
-- ============================================================
SELECT
    (now() AT TIME ZONE 'Asia/Shanghai')::date AS 日期,
    count(*)     AS 今日注资笔数,
    sum(amount)  AS 今日注资总额,
    count(DISTINCT supporter_id) AS 参与人数
  FROM public.support_logs
 WHERE (created_at AT TIME ZONE 'Asia/Shanghai')::date
       = (now() AT TIME ZONE 'Asia/Shanghai')::date;
