-- ============================================================
--  公司税改成「按市值收」—— 基准和分档都换成市值
--
--  站长要求：「按市值收，扣市值」
--
--  【和原来的区别】
--    原来：基准 = 公司账上的钱（pool_cash）
--          Utw机器店 账上 1.45 亿 → 落「2000万~5000万」档 → 1%
--          税 = 1.45 亿 × 1% = 145 万
--
--    现在：基准 = 市值（= 股价 × 总股数）
--          Utw机器店 市值 2.90 亿 → 落「5000万以上」档 → 2%
--          税 = 2.90 亿 × 2% = 580 万
--
--    同一家公司，税从 145 万变成 580 万（4 倍）。
--    原因有两层：① 档位跳了一级（1% → 2%）
--                ② 基数翻倍（账上 1.45 亿 → 市值 2.90 亿）
--
--  【钱从哪扣】
--    市值本身不是一个「地方」，它是算出来的：
--        股价 = 公司账上的钱 ÷ 池子股份
--        市值 = 股价 × 总股数
--    所以要让市值掉下来，只能减公司账上的钱 —— 股价跟着跌，市值跟着跌。
--    扣完 market_value 那一列会被触发器自动同步（不用管）。
--
--  【⚠️ 必须加的那道保护】
--    市值 ÷ 公司账上 = 总股数 ÷ 池子股份，这个倍数【会变】：
--        新建公司              约 2 倍
--        有人买入（池子股份减少）→ 倍数变大
--        有人卖出（池子股份增加）→ 倍数变小
--
--    如果一家公司被买得池子股份很少了，倍数可能到 20、50 ——
--    那时按市值收 2%，税额就是「公司账上的 100%」，一次把公司抽干。
--
--    所以加两条保护：
--      ① 单次扣款最多 = 公司账上的 20%
--      ② 扣完不能低于 20000
--
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：备份（出问题能退回来）
-- ============================================================
DROP TABLE IF EXISTS public._tax_bak_companies_20261005;
CREATE TABLE public._tax_bak_companies_20261005 AS
SELECT id, company_name, pool_cash, pool_shares, total_shares, market_value
  FROM public.user_companies;

SELECT count(*) AS 已备份公司数 FROM public._tax_bak_companies_20261005;


-- ============================================================
-- 第 1 步：预览 —— 按新规则今晚会收多少（先看再改，只读）
-- ============================================================
WITH m AS (
    SELECT c.id, c.company_name, c.pool_cash::numeric AS cash,
           c.pool_shares::numeric AS pshares,
           c.total_shares::numeric AS tshares,
           round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                 * c.total_shares::numeric, 2) AS mktcap
      FROM public.user_companies c
     WHERE c.pool_shares > 0 AND c.pool_cash > 0
),
site AS (SELECT COALESCE(sum(mktcap), 0) AS total FROM m),
calc AS (
    SELECT m.*,
           CASE
               WHEN m.mktcap <  1000000  THEN 0.002
               WHEN m.mktcap <  20000000 THEN 0.005
               WHEN m.mktcap <  50000000 THEN 0.010
               ELSE                           0.020
           END AS base_rate,
           m.mktcap / NULLIF((SELECT total FROM site), 0) AS share
      FROM m
)
SELECT
    company_name                                        AS 公司,
    round(cash, 0)                                      AS 公司账上,
    round(mktcap, 0)                                    AS 市值,
    round(mktcap / NULLIF(cash, 0), 2)                  AS 倍数,
    (base_rate * 100)::text || '%'
        || CASE WHEN share > 0.40 THEN ' + 5%(垄断)' ELSE '' END AS 税率,
    round(mktcap * (base_rate + CASE WHEN share > 0.40 THEN 0.05 ELSE 0 END), 0)
                                                        AS 按市值该收,
    round(LEAST(
            mktcap * (base_rate + CASE WHEN share > 0.40 THEN 0.05 ELSE 0 END),
            cash * 0.20,
            GREATEST(cash - 20000, 0)), 0)              AS 实际会收,
    CASE WHEN mktcap * (base_rate + CASE WHEN share > 0.40 THEN 0.05 ELSE 0 END)
              > cash * 0.20
         THEN '⚠️ 被 20% 上限截住' ELSE '' END           AS 备注
  FROM calc
 WHERE mktcap >= 300000
 ORDER BY mktcap DESC
 LIMIT 40;


-- ============================================================
-- 第 2 步：替换 collect_company_tax（改成按市值）
-- ============================================================
CREATE OR REPLACE FUNCTION public.collect_company_tax()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    r            RECORD;
    v_rate       numeric;
    v_tax        numeric;
    v_total      numeric := 0;
    v_count      int := 0;
    v_site_mv    numeric := 0;      -- 全站市值之和（算垄断线用）
    v_share      numeric;
    v_mono_cnt   int := 0;
    v_mono_total numeric := 0;
    v_mono_rate  CONSTANT numeric := 0.05;
    v_mono_line  CONSTANT numeric := 0.40;
    v_cap_pct    CONSTANT numeric := 0.20;   -- ⭐ 单次最多扣公司账上的 20%
    v_floor      CONSTANT numeric := 20000;  -- 扣完保底

    -- 再分配
    v_pool       numeric;
    v_give       numeric;
    v_given      numeric := 0;
    v_give_cnt   int := 0;
    v_small_cnt  int := 0;
    v_give_pct   CONSTANT numeric := 0.02;   -- 每家每天最多涨自己账上的 2%
    v_small_line CONSTANT numeric := 1000000;-- 账上不足 100 万的才算中小公司
BEGIN
    -- 全站市值之和（垄断线的分母）
    SELECT COALESCE(sum(round(pool_cash::numeric / NULLIF(pool_shares::numeric, 0)
                              * total_shares::numeric, 2)), 0)
      INTO v_site_mv
      FROM public.user_companies
     WHERE pool_shares > 0 AND pool_cash > 0;

    -- ---------- ① 收税：基准是市值 ----------
    FOR r IN
        SELECT * FROM (
            SELECT c.id,
                   c.company_name,
                   c.pool_cash::numeric AS cash,
                   round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric, 0)
                         * c.total_shares::numeric, 2) AS mktcap
              FROM public.user_companies c
             WHERE c.pool_shares > 0 AND c.pool_cash > 0
        ) x
        WHERE x.mktcap >= 300000              -- 门槛也按市值
        ORDER BY x.mktcap DESC
    LOOP
        -- 分档按市值
        v_rate := CASE
            WHEN r.mktcap <  1000000  THEN 0.002
            WHEN r.mktcap <  20000000 THEN 0.005
            WHEN r.mktcap <  50000000 THEN 0.010
            ELSE                           0.020
        END;

        -- 垄断线：这家市值 ÷ 全站市值之和
        IF v_site_mv > 0 THEN
            v_share := r.mktcap / v_site_mv;
            IF v_share > v_mono_line THEN
                v_rate := v_rate + v_mono_rate;
                v_mono_cnt := v_mono_cnt + 1;
            END IF;
        END IF;

        -- 税额 = 市值 × 税率
        v_tax := floor(r.mktcap * v_rate);

        -- ⭐ 保护：单次最多扣账上的 20%，且扣完不低于 20000
        v_tax := LEAST(v_tax, floor(r.cash * v_cap_pct));
        v_tax := LEAST(v_tax, GREATEST(r.cash - v_floor, 0));

        IF v_tax < 1 THEN CONTINUE; END IF;

        -- 从公司账上扣 —— 股价跟着跌，市值跟着跌
        -- （market_value 那一列由 trg_sync_market_value 触发器自动同步）
        UPDATE public.user_companies
           SET pool_cash = pool_cash - v_tax
         WHERE id = r.id;

        v_total := v_total + v_tax;
        v_count := v_count + 1;

        IF v_share > v_mono_line THEN
            v_mono_total := v_mono_total + v_tax;
        END IF;
    END LOOP;

    -- ---------- ② 再分配：发给中小公司 ----------
    v_pool := v_total;

    IF v_pool >= 1 THEN
        SELECT count(*) INTO v_small_cnt
          FROM public.user_companies
         WHERE pool_cash > 0 AND pool_cash < v_small_line;

        IF v_small_cnt > 0 THEN
            FOR r IN
                SELECT id, pool_cash
                  FROM public.user_companies
                 WHERE pool_cash > 0 AND pool_cash < v_small_line
                 ORDER BY pool_cash ASC
            LOOP
                EXIT WHEN v_pool - v_given < 1;

                v_give := LEAST(
                    floor(v_pool / v_small_cnt),
                    floor(r.pool_cash * v_give_pct)
                );
                IF v_give < 1 THEN CONTINUE; END IF;

                UPDATE public.user_companies
                   SET pool_cash = pool_cash + v_give
                 WHERE id = r.id;

                v_given := v_given + v_give;
                v_give_cnt := v_give_cnt + 1;
            END LOOP;
        END IF;
    END IF;

    -- ---------- ③ 记账 ----------
    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date',
            to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    RETURN jsonb_build_object(
        'ok', true,
        '基准', '市值',
        '全站市值', v_site_mv,
        '收税_公司数', v_count,
        '收税_合计', v_total,
        '垄断税_公司数', v_mono_cnt,
        '垄断税_合计', v_mono_total,
        '发放_公司数', v_give_cnt,
        '发放_合计', v_given,
        '销毁_合计', GREATEST(v_total - v_given, 0)
    );
END
$fn$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================

-- 3.1 函数换上了没
SELECT
    p.proname AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%基准%市值%'
         THEN '✅ 已改成按市值收'
         ELSE '❌ 还是按公司账上的钱' END AS 状态,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%v_cap_pct%'
         THEN '✅ 有 20% 扣款上限' ELSE '❌ 没上限' END AS 保护
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'collect_company_tax';

-- 3.2 全站倍数分布（看有没有倍数特别大的公司，那些会被上限截住）
SELECT
    round(min(mktcap / NULLIF(cash, 0)), 2)   AS 最小倍数,
    round(avg(mktcap / NULLIF(cash, 0)), 2)   AS 平均倍数,
    round(max(mktcap / NULLIF(cash, 0)), 2)   AS 最大倍数,
    count(*) FILTER (WHERE mktcap / NULLIF(cash, 0) > 5)  AS 倍数超5倍的,
    count(*) FILTER (WHERE mktcap / NULLIF(cash, 0) > 10) AS 倍数超10倍的
  FROM (
      SELECT c.pool_cash::numeric AS cash,
             round(c.pool_cash::numeric / NULLIF(c.pool_shares::numeric,0)
                   * c.total_shares::numeric, 2) AS mktcap
        FROM public.user_companies c
       WHERE c.pool_shares > 0 AND c.pool_cash > 0
  ) t;

-- 3.3 触发器还在不在（它负责把 market_value 同步成新市值）
SELECT tgname AS 触发器,
       CASE WHEN tgenabled = 'O' THEN '✅ 已启用' ELSE '❌ 未启用' END AS 状态
  FROM pg_trigger
 WHERE tgrelid = 'public.user_companies'::regclass
   AND tgname = 'trg_sync_market_value';


-- ============================================================
-- 第 4 步：想立刻试一次（可选，不要在一天里跑多次）
-- ============================================================
-- 跑之前记一下：
--     SELECT company_name, pool_cash, market_value FROM public.user_companies
--      ORDER BY pool_cash DESC LIMIT 10;
-- 跑一次：
--     SELECT public.collect_company_tax();
-- 再查一次对比 —— 大公司账上会少、市值跟着少；小公司账上会多一点。


-- ============================================================
-- 第 5 步：回滚（万一要退）
-- ============================================================
-- 函数：把 sql/stock_plan_c_20261005.sql 第 3 步那段 collect_company_tax
--       重新跑一遍即可（那份是按公司账上的钱收的版本）。
-- 数据：备份表 _tax_bak_companies_20261005 留着，但它只备份了
--       pool_cash 等几列，真要回滚建议直接用数据库的时间点恢复。
--       ⚠️ 所以第 4 步手动试跑之前，先确认备份还在。
-- ============================================================
