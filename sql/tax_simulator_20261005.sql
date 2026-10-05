-- ============================================================
--  收税 + 再分配 参数试算器
--
--  已知（站长实测）：
--      现在收 3051 万/天，但最多只能发出去 571 万（18.7%），
--      剩下 81% 直接销毁。
--      全站公司账上合计只有 8.07 亿 —— 每天烧 2480 万 = 3.1%/天，
--      一个月经济缩水 61%。
--
--      根子：接收方体量太小。3000 万分给 89 家 = 每家 34.3 万，
--      而大多数公司账上只有 2 万 —— 要接住得一天涨 1700%，不可能。
--
--  所以税率必须降，同时把发放上限放开。这个脚本让你直接看候选效果。
--
--  三个可调参数（改下面 grid 里的值就行）：
--      税率倍数  rate_mul   1 = 现在的税率（0.2/0.5/1/2%）
--                           0.125 = 降到八分之一（0.025/0.0625/0.125/0.25%）
--      接收门槛  line_wan   账上不足多少万的公司能领钱
--      发放上限  give_pct   每家每天最多涨自己账上的百分之几
--
--  全部只读。
-- ============================================================


-- ============================================================
-- 试算：税率倍数 × 接收门槛 × 发放上限
-- ============================================================
WITH m AS (
    -- 每家公司：账上、市值、倍数
    SELECT c.id,
           c.pool_cash::numeric AS cash,
           round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                 * c.total_shares::numeric, 2) AS mktcap
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
),
site AS (SELECT COALESCE(sum(mktcap), 0) AS total FROM m),

-- 可调参数表：改这三列就行
cfg AS (
    SELECT * FROM (VALUES
        -- 税率倍数, 接收门槛(万), 发放上限(%)
        (1.0,   100,    2),      -- 现状
        (0.125, 100,  100),      -- 只降税率
        (0.125, 5000,  50),      -- 降税率 + 提门槛 + 放上限
        (0.125, 5000, 100),
        (0.125, 10000, 50),
        (0.0625,5000, 100),      -- 税率降到十六分之一
        (0.0625,10000,100),
        (0.25,  10000,100)       -- 税率只降到四分之一
    ) AS v(rate_mul, line_wan, give_pct)
),

-- 按每个配置算收税
taxed AS (
    SELECT cfg.rate_mul, cfg.line_wan, cfg.give_pct,
           LEAST(
               m.mktcap * cfg.rate_mul * (
                   CASE WHEN m.mktcap <  1000000  THEN 0.002
                        WHEN m.mktcap <  20000000 THEN 0.005
                        WHEN m.mktcap <  50000000 THEN 0.010
                        ELSE                           0.020 END
                 + CASE WHEN m.mktcap / NULLIF((SELECT total FROM site), 0) > 0.40
                        THEN 0.05 ELSE 0 END),
               m.cash * 0.20,
               GREATEST(m.cash - 20000, 0)) AS tax
      FROM cfg CROSS JOIN m
     WHERE m.mktcap >= 300000
),
budget AS (
    SELECT rate_mul, line_wan, give_pct,
           COALESCE(sum(tax), 0)::numeric AS b
      FROM taxed
     GROUP BY rate_mul, line_wan, give_pct
),

-- 接收方
small AS (
    SELECT b.rate_mul, b.line_wan, b.give_pct, b.b,
           m.cash
      FROM budget b
      JOIN m ON m.cash > 0 AND m.cash < b.line_wan * 10000
),
cnt AS (
    SELECT rate_mul, line_wan, give_pct, b,
           count(*)::numeric AS n,
           COALESCE(sum(cash), 0)::numeric AS pool
      FROM small
     GROUP BY rate_mul, line_wan, give_pct, b
),
calc AS (
    SELECT s.rate_mul, s.line_wan, s.give_pct, s.cash,
           LEAST(floor(s.b / NULLIF(cc.n, 0)),
                 floor(s.cash * s.give_pct / 100.0)) AS want,
           cc.b, cc.n, cc.pool
      FROM small s JOIN cnt cc
        ON cc.rate_mul = s.rate_mul AND cc.line_wan = s.line_wan
       AND cc.give_pct = s.give_pct
),
tot AS (
    SELECT rate_mul, line_wan, give_pct,
           COALESCE(sum(want), 0)::numeric AS w,
           max(b) AS b, max(n) AS n, max(pool) AS pool
      FROM calc
     GROUP BY rate_mul, line_wan, give_pct
)
SELECT
    (rate_mul * 100)::text || '%'                              AS 税率倍数,
    CASE rate_mul
        WHEN 1.0    THEN '0.2/0.5/1/2%'
        WHEN 0.25   THEN '0.05/0.125/0.25/0.5%'
        WHEN 0.125  THEN '0.025/0.0625/0.125/0.25%'
        WHEN 0.0625 THEN '0.0125/0.031/0.0625/0.125%'
        ELSE '—' END                                           AS 各档税率,
    line_wan || ' 万'                                          AS 接收门槛,
    give_pct || '%'                                            AS 发放上限,
    round(b, 0)                                                AS 收税合计,
    round(LEAST(b, w), 0)                                      AS 实发,
    round(GREATEST(b - w, 0), 0)                               AS 销毁,
    round(LEAST(b, w) / NULLIF(b, 0) * 100, 1) || '%'          AS 发放率,
    round(LEAST(b, w) / NULLIF(pool, 0) * 100, 2) || '%'       AS 接收方平均涨幅,
    round(GREATEST(b - w, 0) / 807000000.0 * 100, 3) || '%'    AS 全站缩水_每天
  FROM tot
 ORDER BY rate_mul DESC, line_wan, give_pct;


-- ============================================================
--  怎么读
-- ============================================================
--  「收税合计」≈「实发」时最好 —— 收上来的钱刚好发完，
--  总量不变，只是从大公司转移给小公司。
--
--  「销毁」是白白烧掉的钱。对应最后一列「全站缩水_每天」：
--      0.01% 以内  →  基本无感
--      0.05% 左右  →  一个月缩 1.5%，可以接受
--      0.1% 以上   →  一个月缩 3% 以上，偏快
--      0.3% 以上   →  一个月缩 9%，太快
--
--  「接收方平均涨幅」控制在 1~3% 比较理想：
--      一天 1~3%   玩家感觉明显但不夸张
--      一天 10%    已经很快
--      一天 50%+   太疯
--
--  看完把最合适的那一行发我，我写对应的改参数 SQL。
-- ============================================================
