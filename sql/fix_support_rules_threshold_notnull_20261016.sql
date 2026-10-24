-- ============================================================
--  修：「自动抄底」建不了规则 —— null value in column "threshold"
--
--  报错原文：
--      null value in column "threshold" of relation "support_rules"
--      violates not-null constraint
--
--  ── 根因 ──
--  建规则的那句 INSERT 长这样（amm_part6_auto_buy_20261003.sql）：
--
--      INSERT INTO public.support_rules
--          (user_id, company_id, threshold, amount, price_target, daily_limit,
--           enabled, today_cash, today_date)
--      VALUES
--          (p_user_id, p_company_id, NULL, p_amount::int, p_price_target, ...)
--                                  ↑
--                        ⚠️ 显式传 NULL
--
--  而 support_rules.threshold 是 NOT NULL 且没有默认值 —— 所以一保存就炸。
--
--  ── 为什么 threshold 是死字段 ──
--  AMM 重构（amm_part6）把语义换了：
--      旧：threshold = 市值低于此就「支持」（给自己的公司注资）
--      新：price_target = 股价低于此就「自动买入」（买别人的公司）
--  新代码只读 price_target，threshold 再也没人看。
--  但那个 NOT NULL 约束忘了去掉。
--
--  ── 改法 ──
--  把 threshold 的 NOT NULL 去掉。就这一句。
--  ⚠️ 不动任何代码逻辑 —— 风险最低。
--  ⚠️ 也不删字段：老数据里还有值，删了不可逆；留着不碍事。
--
--  ⚠️ 顺带说明：这条报错大概率就是「漏洞：自动抄底」那份报告的真实内容 ——
--     他们想用这个功能，一点保存就报错，就当成漏洞报上来了。
--     如果你确认有【真的能刷币】的路子，得给他们要具体的复现步骤，
--     光「自动抄底」三个字我没法定位。
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步（只查）：现在 threshold 是什么约束
-- ============================================================
SELECT column_name        AS 列名,
       data_type          AS 类型,
       is_nullable        AS 可空,
       column_default     AS 默认值
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name   = 'support_rules'
   AND column_name IN ('threshold', 'price_target', 'amount', 'daily_limit')
 ORDER BY column_name;

-- 期望看到 threshold 的「可空」现在是 NO —— 改完之后会变成 YES


-- ============================================================
-- 第 2 步：去掉 threshold 的 NOT NULL
-- ============================================================
ALTER TABLE public.support_rules
    ALTER COLUMN threshold DROP NOT NULL;


-- ============================================================
-- 第 3 步：验收
-- ============================================================
-- 3.1 threshold 现在应该可空了
SELECT column_name  AS 列名,
       is_nullable  AS 可空,
       column_default AS 默认值
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name   = 'support_rules'
   AND column_name = 'threshold';

-- 3.2 看看现有的规则都是什么状态
SELECT count(*)                                              AS 规则总数,
       count(*) FILTER (WHERE price_target IS NOT NULL)      AS 有目标股价的,
       count(*) FILTER (WHERE price_target IS NULL)          AS 没目标股价的,
       count(*) FILTER (WHERE threshold IS NOT NULL)         AS 死字段有值的
  FROM public.support_rules;

-- 3.3 规则明细（看谁设了什么价位、额度用掉多少）
SELECT sr.id                    AS 规则ID,
       p.username               AS 玩家,
       c.company_name           AS 盯着的公司,
       sr.price_target          AS 目标股价,
       sr.amount                AS 每次买入,
       sr.daily_limit           AS 每日上限,
       sr.today_cash            AS 今天已花,
       sr.today_date            AS 记账日期,
       COALESCE(sr.enabled,true) AS 启用,
       sr.last_run_at           AS 上次触发
  FROM public.support_rules sr
  LEFT JOIN public.profiles p        ON p.id = sr.user_id
  LEFT JOIN public.user_companies c  ON c.id = sr.company_id
 ORDER BY sr.id DESC
 LIMIT 30;


-- ============================================================
-- 第 4 步：跑完之后自己试一次
-- ============================================================
--  去股票页 → 某家公司 → 设「自动抄底」→ 保存
--      ✓ 应该提示保存成功
--      ✗ 如果还报 threshold 的错，说明这个约束不是唯一的拦路虎，
--        把报错发我。
--
--  ⚠️ 顺便：run_auto_support 的逻辑我看过了，是严的：
--        · 不能买自己的公司
--        · 金额 10 ~ 10 万
--        · 只在 08:00~20:00 触发
--        · 两次触发有最小间隔
--        · 每天有额度上限（跨天自动重置）
--        · 余额要够（含 5% 手续费）
--        · 最终走 _orig_buy_stock —— 和手动买是同一套函数
--     没看到能刷币的口子。
--
--     真要「刷币」，得靠两个号配合：一个砸盘、一个低价抄底、再拉回去卖。
--     但手续费双向 5% + 5% = 10%，价格波动得超过 10% 才赚 ——
--     那是有风险的正常交易，不是必赚的漏洞。
--     如果你有别的线索，把具体步骤发我。
-- ============================================================
