-- ============================================================
-- 给现有规则批量设默认目标价
-- ============================================================
-- 现状：41 条规则，35 条启用，但【0 条有目标价】——
--       因为 Part 6 里那条 UPDATE 把 threshold > 1000 的都置空了
--       （旧阈值是"市值"尺度，新模型是"股价"尺度，1.00 左右，对不上）。
--
-- 不设目标价的话，规则永远不会触发（run_auto_support 里
-- IF r.price_target IS NULL ... THEN CONTINUE）。
--
-- 这里按「当前股价 × 0.9」给一个默认值 —— 意思"
--     "股价跌 10% 就自动抄底"
-- 玩家以后可以自己在页面上改。
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：预览（只查不改）
-- ============================================================
SELECT
    sr.id,
    p.username                        AS 规则主人,
    c.company_name                    AS 盯的公司,
    round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0), 4) AS 当前股价,
    round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0) * 0.9, 4) AS 将设为目标价,
    sr.amount                         AS 每次买入,
    sr.daily_limit                    AS 每日上限,
    COALESCE(sr.enabled,true)         AS 启用
  FROM public.support_rules sr
  LEFT JOIN public.profiles       p ON p.id = sr.user_id
  LEFT JOIN public.user_companies c ON c.id = sr.company_id
 WHERE sr.price_target IS NULL
   AND c.pool_shares > 0
 ORDER BY p.username, c.company_name;

-- 统计一下涉及多少钱
SELECT
    count(*)                                  AS 待设规则数,
    count(DISTINCT sr.user_id)                AS 涉及用户数,
    sum(sr.amount)                            AS 单轮最多花费,
    sum(sr.daily_limit)                       AS 每日最多花费
  FROM public.support_rules sr
  JOIN public.user_companies c ON c.id = sr.company_id
 WHERE sr.price_target IS NULL AND c.pool_shares > 0;


-- ============================================================
-- 第二步：正式设置
-- ============================================================
UPDATE public.support_rules sr
   SET price_target = round(
           c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0) * 0.9, 4),
       today_cash   = 0,
       today_date   = (now() AT TIME ZONE 'Asia/Shanghai')::date,
       last_run_at  = NULL
  FROM public.user_companies c
 WHERE sr.company_id = c.id
   AND sr.price_target IS NULL
   AND c.pool_shares > 0
   AND c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0) > 0;


-- ============================================================
-- 第三步：验收
-- ============================================================
SELECT
    count(*)                                        AS 规则总数,
    count(*) FILTER (WHERE COALESCE(enabled,true))  AS 启用中的,
    count(*) FILTER (WHERE price_target IS NOT NULL) AS 已设目标价的,
    min(price_target)                               AS 最低目标价,
    max(price_target)                               AS 最高目标价
  FROM public.support_rules;
-- 预期：41 / 35 / 41

-- 逐条看看
SELECT sr.id, p.username, c.company_name,
       sr.price_target,
       round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0), 4) AS 当前股价,
       CASE WHEN c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0) <= sr.price_target
            THEN '⚡ 已跌破，下轮会买'
            ELSE '⏸ 等待中' END AS 状态,
       sr.amount, sr.daily_limit
  FROM public.support_rules sr
  LEFT JOIN public.profiles       p ON p.id = sr.user_id
  LEFT JOIN public.user_companies c ON c.id = sr.company_id
 ORDER BY 状态, p.username;


-- ============================================================
-- 第四步：手动跑一次看效果
-- ------------------------------------------------------------
-- 会打印「自动抄底：成交 N 条，条件不满足跳过 M 条，执行失败 K 条」
-- ⚠️ 注意：现在是维护模式，只有站长白名单里的操作会被放行。
--    其他人的自动买入会被 _orig_buy_stock 里的维护检查拦下，
--    表现为"执行失败"。这是【预期行为】，等关掉维护模式就正常了。
-- ============================================================
-- CALL 不行（run_auto_support 是函数不是过程），用 SELECT：
-- SELECT public.run_auto_support();


-- ============================================================
-- 补充：这批规则值不值得留
-- ------------------------------------------------------------
-- 现状是「同一人的不同账号互相托底」——
--   单次 2000，每日封顶 5 万，池子却是上亿。
--   5 万扔进 1.5 亿的池子，价格几乎不动（滑点约 0.007%）。
--
-- 也就是说：这些规则在新模型下【基本没有实际效果】，
-- 但也不造成危害（不造币、金额被限额卡死）。
--
-- 如果你想让它们更有意义，可以考虑：
--   ① 提高 daily_limit 上限（但会放大操纵风险）
--   ② 或者干脆清掉这批旧规则，让玩家按新逻辑重设
--
-- 清掉的语句（确认要清再放开）：
-- DELETE FROM public.support_rules
--  WHERE user_id IN (SELECT id FROM public.profiles WHERE username ILIKE '%utw%');
