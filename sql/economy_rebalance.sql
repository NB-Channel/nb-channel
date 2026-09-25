-- ============================================================
-- 经济再平衡:均值回归 / 公司税 / 签到封顶 / 自动支持日限额
--
-- 背景:全站总市值 5 天涨了 9.7 倍(0.79亿 → 7.66亿),87 家公司里
--       Utw 一家占 97.4%(16.66 亿),67 家市值不到 10 万。
--       根因:① 波动函数在 v7 删掉了均值回归,涨上去就没人拉回来
--             ② 签到奖励 = 连续天数 × 100 且无上限,币一直增发
--             ③ 自动支持规则一设就不用管,系统每天自动投钱推高市值
--
-- 本文件实施四项调控(参数按你给的数值):
--   ① 波动函数恢复均值回归(偏离市场均值越多,被拉回的力越大)
--   ② 公司税:按市值分段每日征收,从市值里扣除(不流入任何人,直接销毁)
--   ③ 签到奖励封顶(原来连续天数无上限)
--   ④ 自动支持每用户每天最多投 50 万
--
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

-- ============================================================
-- ① 波动函数:恢复均值回归
-- ============================================================
-- ⚠️ 关键:回归力度必须「按真实经过的时间」缩放,不能按「调用轮数」。
--   踩过的坑:一开始按「15 分钟采样一次 ≈ 48 轮/天」定了 k = 0.00047,
--   但实际驱动波动的 pg_cron 任务 market-10s-tick(见 market_10s.sql)是
--   每分钟 6 轮、每轮间隔 10 秒 → 每天 4320 轮,是假设值的 90 倍。
--   照那样上线,(1-0.002088)^4320 ≈ exp(-9) ≈ 0.0001,
--   偏离 85 倍的 Utw 会在一天内从 16.66 亿跌到 2 万,直接崩盘。
--   现在改成:每轮回归量 = -K_DAY × (本次距上次波动的秒数 / 86400) × ln(市值/均值)
--   —— 调度是 10 秒一轮还是 15 分钟一轮,一天的总回归幅度完全一样,不再耦合调度频率。
--
-- 参数说明:
--   随机部分仍是对称的 ±1%(原来 ±2%,收紧一半,减少无意义的剧烈波动)
--   回归部分 = -K_DAY × (dt/86400) × ln(市值 / 市场平均市值)
--     · 市值 = 平均值 → ln(1)=0 → 不拉
--     · 市值 = 2 倍平均 → 负向拉动,慢慢回落
--     · 市值 = 0.5 倍平均 → 正向拉动,慢慢抬升
--   K_DAY = 0.0474(按「交易时段」折算,即一天实际只波动 12 小时):
--     · 偏离 2 倍平均的公司   → 一天约回落 1.6%
--     · 偏离 85 倍(Utw 现状) → 一天约回落 10%,一周左右腰斩,平稳归位
--   想更快/更慢就调 K_DAY(每翻一倍,回归速度翻倍)。
CREATE OR REPLACE FUNCTION public.random_fluctuate_market_values()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    company        RECORD;
    change_percent FLOAT;
    new_value      BIGINT;
    v_day_open     NUMERIC;
    v_last         timestamptz;
    v_avg          NUMERIC;
    v_ratio        NUMERIC;
    v_pull         FLOAT;
    v_dt           FLOAT;                        -- 本次距上次波动经过的秒数
    v_k_day        CONSTANT FLOAT := 0.0474;     -- 每日回归强度,可调
BEGIN
    -- 交易时段(北京时间 8:00 ~ 20:00),收盘后冻结
    IF (now() AT TIME ZONE 'Asia/Shanghai')::time < time '08:00'
       OR (now() AT TIME ZONE 'Asia/Shanghai')::time >= time '20:00' THEN
        RETURN;
    END IF;

    -- 全局节流:8 秒内已波动过就跳过
    SELECT value::timestamptz INTO v_last FROM public.market_meta WHERE key = 'last_fluctuate';
    IF v_last IS NOT NULL AND v_last > now() - interval '8 seconds' THEN
        RETURN;
    END IF;

    -- 距上次波动经过了多少秒 —— 回归力度按它缩放(见文件头说明)。
    -- 上限 15 分钟:调度停摆很久后重启时,不让单轮一次性拉太狠。
    v_dt := LEAST(
                GREATEST(
                    EXTRACT(EPOCH FROM (now() - coalesce(v_last, now() - interval '10 seconds')))::float,
                    0),
                900);

    -- 均值回归的锚点:全市场平均市值
    SELECT avg(market_value) INTO v_avg FROM public.user_companies;
    IF v_avg IS NULL OR v_avg <= 0 THEN v_avg := 20000; END IF;

    FOR company IN SELECT id, market_value FROM user_companies LOOP
        -- 当日开盘价基准
        SELECT open INTO v_day_open
          FROM public.stock_daily_kline
         WHERE company_id = company.id AND trade_date = current_date;

        -- 涨跌停冻结:相对当日开盘价超过 ±50% 就停止波动(第二天开盘自动恢复)
        IF v_day_open IS NOT NULL THEN
            IF company.market_value > v_day_open * 1.50
               OR company.market_value < v_day_open * 0.50 THEN
                CONTINUE;
            END IF;
        END IF;

        -- 随机部分:±1%(对称)
        change_percent := (random() - 0.5) * 0.02;

        -- 均值回归:偏离平均市值越多,拉的力越大
        IF company.market_value > 0 THEN
            v_ratio := company.market_value::numeric / v_avg;
            IF v_ratio > 0 THEN
                -- 高于均值 → 负;低于均值 → 正。乘 (v_dt/86400) 按真实时间缩放
                v_pull := -v_k_day * (v_dt / 86400.0) * ln(v_ratio);
                -- 单轮最多贡献 ±0.5%,安全护栏(按时间缩放后正常远小于它)
                v_pull := GREATEST(-0.005, LEAST(0.005, v_pull));
                change_percent := change_percent + v_pull;
            END IF;
        END IF;

        new_value := company.market_value + (company.market_value * change_percent);

        -- 涨跌停边界
        IF v_day_open IS NOT NULL THEN
            IF new_value > v_day_open * 1.50 THEN
                new_value := floor(v_day_open * 1.50);
            ELSIF new_value < v_day_open * 0.50 THEN
                new_value := GREATEST(floor(v_day_open * 0.50), 10000);
            END IF;
        END IF;

        -- 最低市值保底
        IF new_value < 10000 THEN new_value := 10000; END IF;

        UPDATE user_companies SET market_value = new_value WHERE id = company.id;
    END LOOP;

    -- 记录本次波动时间(节流用)
    INSERT INTO public.market_meta(key, value) VALUES ('last_fluctuate', now()::text)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
END;
$$;

-- ============================================================
-- ② 公司税:按市值分段,每日征收,直接销毁
-- ============================================================
-- 分段(你给的数值):
--   < 30 万         免征
--   30 万 ~ 100 万   每日 0.2%
--   100 万 ~ 2000 万 每日 0.5%
--   2000 万 ~ 5000 万 每日 1%
--   > 5000 万        每日 2%
-- 扣的是公司市值(等于缩水),钱不进入任何账户 —— 净效果是回收市场上的虚高市值。
CREATE OR REPLACE FUNCTION public.collect_company_tax()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    r       RECORD;
    v_rate  numeric;
    v_tax   numeric;
    v_total numeric := 0;
    v_count int := 0;
BEGIN
    FOR r IN
        SELECT id, company_name, market_value
          FROM public.user_companies
         WHERE market_value >= 300000
         ORDER BY market_value DESC
    LOOP
        v_rate := CASE
            WHEN r.market_value <  1000000  THEN 0.002   -- 30 万 ~ 100 万
            WHEN r.market_value <  20000000 THEN 0.005   -- 100 万 ~ 2000 万
            WHEN r.market_value <  50000000 THEN 0.010   -- 2000 万 ~ 5000 万
            ELSE                                 0.020   -- 5000 万以上
        END;

        v_tax := floor(r.market_value * v_rate);
        IF v_tax < 1 THEN CONTINUE; END IF;

        UPDATE public.user_companies
           SET market_value = GREATEST(market_value - v_tax, 10000)
         WHERE id = r.id;

        v_total := v_total + v_tax;
        v_count := v_count + 1;
    END LOOP;

    -- 记录收税日期(防止一天收多次)
    INSERT INTO public.market_meta(key, value)
    VALUES ('last_tax_date', to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    RAISE NOTICE '公司税: 征收 % 家,合计 % NB币(已销毁)', v_count, v_total;
    RETURN jsonb_build_object('ok', true, 'companies', v_count, 'total', v_total);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;

-- ============================================================
-- ③ 把「每日收税」挂到采样流程里
-- ============================================================
-- sample_market_snapshot 每 15 分钟被定时任务调一次,
-- 这里判断"今天还没收过税"就收一次,避免新增定时任务。
-- ⚠️ 保留了之前加的 ids 数组(修复重名公司 K 线用的)
CREATE OR REPLACE FUNCTION public.sample_market_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ids    text[] := ARRAY[]::text[];
    v_names  text[] := ARRAY[]::text[];
    v_values bigint[] := ARRAY[]::bigint[];
    v_total  bigint := 0;
    v_count  integer := 0;
    v_today  text := to_char((now() AT TIME ZONE 'Asia/Shanghai')::date, 'YYYY-MM-DD');
    v_last_tax text;
    v_last_fluct timestamptz;
    r RECORD;
BEGIN
    -- 每天第一次采样时收公司税
    SELECT value INTO v_last_tax FROM public.market_meta WHERE key = 'last_tax_date';
    IF v_last_tax IS DISTINCT FROM v_today THEN
        PERFORM public.collect_company_tax();
    END IF;

    -- 触发一次市值波动(带 10 分钟去重:不管还有没有别的调度在跑,10 分钟内只波动一次)
    -- 这样即使数据库里的 pg_cron 也在调波动函数,也不会叠加成双倍波动。
    SELECT value::timestamptz INTO v_last_fluct FROM public.market_meta WHERE key = 'last_fluctuate';
    IF v_last_fluct IS NULL OR v_last_fluct < now() - interval '10 minutes' THEN
        PERFORM public.random_fluctuate_market_values();
    END IF;

    FOR r IN SELECT id, company_name, market_value FROM public.user_companies ORDER BY id LOOP
        v_ids    := v_ids || r.id::text;
        v_names  := v_names || r.company_name;
        v_values := v_values || r.market_value;
        v_total  := v_total + r.market_value;
        v_count  := v_count + 1;
    END LOOP;

    IF v_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '暂无公司');
    END IF;

    INSERT INTO public.stock_history_full (recorded_at, total_value, snapshot)
    VALUES (now(), v_total, jsonb_build_object(
        'ids',    to_jsonb(v_ids),
        'names',  to_jsonb(v_names),
        'values', to_jsonb(v_values)));

    PERFORM public.record_daily_kline();

    RETURN jsonb_build_object('success', true, 'companies', v_count, 'total', v_total);
END;
$$;

-- ============================================================
-- ④ 签到奖励封顶
-- ============================================================
-- 原来是 reward := 连续天数 × 100,连续 100 天就是每天 1 万,无上限 —— 币的主要来源之一。
-- 现在封顶 3000(连续 30 天到顶,之后每天固定 3000)。
-- 想更宽松/更紧就改这个 3000。
CREATE OR REPLACE FUNCTION public.do_check_in(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    last_checkin DATE;
    consecutive INT;
    reward INT;
    new_consecutive INT;
    v_cap CONSTANT INT := 3000;   -- 每日签到收益上限
    v_today DATE := (now() AT TIME ZONE 'Asia/Shanghai')::date;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;

    SELECT last_checkin_date, consecutive_days INTO last_checkin, consecutive
      FROM user_checkins WHERE user_id = p_user_id;

    IF last_checkin = v_today THEN
        RETURN jsonb_build_object('success', false, 'message', '今日已签到', 'reward', 0);
    END IF;

    IF last_checkin = v_today - 1 THEN
        new_consecutive := consecutive + 1;
    ELSE
        new_consecutive := 1;
    END IF;

    -- 封顶:连续天数 × 100,最高 v_cap
    reward := LEAST(new_consecutive * 100, v_cap);

    UPDATE profiles SET nb_balance = nb_balance + reward WHERE id = p_user_id;

    INSERT INTO user_checkins (user_id, last_checkin_date, consecutive_days)
    VALUES (p_user_id, v_today, new_consecutive)
    ON CONFLICT (user_id) DO UPDATE
    SET last_checkin_date = EXCLUDED.last_checkin_date,
        consecutive_days = EXCLUDED.consecutive_days;

    RETURN jsonb_build_object('success', true, 'reward', reward, 'consecutive', new_consecutive,
                              'capped', (new_consecutive * 100) > v_cap);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$function$;

-- ============================================================
-- ⑤ 自动支持:每用户每天最多投 50 万
-- ============================================================
-- 给 support_rules 加两列记录"今天已自动投了多少",按用户汇总算额度。
-- (不查流水表,避免依赖它的列名;每天自动重置)
ALTER TABLE public.support_rules ADD COLUMN IF NOT EXISTS today_supported numeric NOT NULL DEFAULT 0;
ALTER TABLE public.support_rules ADD COLUMN IF NOT EXISTS today_date date;

CREATE OR REPLACE FUNCTION public.run_auto_support()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    r          RECORD;
    v_res      jsonb;
    v_count    integer := 0;
    v_deleted  integer := 0;
    v_skipped  integer := 0;
    v_capped   integer := 0;
    v_used     numeric;
    v_left     numeric;
    v_amt      numeric;
    v_today    date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_daily_cap CONSTANT numeric := 500000;   -- 每用户每天自动支持总额上限
BEGIN
    FOR r IN
        SELECT sr.id, sr.user_id, sr.company_id, sr.threshold, sr.amount,
               uc.market_value, p.nb_balance
          FROM public.support_rules sr
          JOIN public.user_companies uc ON uc.id = sr.company_id
          JOIN public.profiles p ON p.id = sr.user_id
    LOOP
        -- ① 金额非法(<=0 或超 10 万) → 删除规则
        IF r.amount <= 0 OR r.amount > 100000 THEN
            DELETE FROM public.support_rules WHERE id = r.id;
            v_deleted := v_deleted + 1;
            CONTINUE;
        END IF;

        -- ② 余额不足 → 保留规则,等充钱后再支持
        IF r.nb_balance < r.amount THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        -- ③ 市值低于阈值才支持
        IF r.market_value < r.threshold THEN
            -- 计算该用户今天已用掉的自动支持额度(跨该用户所有规则累加)
            SELECT coalesce(sum(CASE WHEN today_date = v_today THEN today_supported ELSE 0 END), 0)
              INTO v_used
              FROM public.support_rules
             WHERE user_id = r.user_id;

            v_left := v_daily_cap - v_used;
            IF v_left <= 0 THEN
                v_capped := v_capped + 1;
                CONTINUE;   -- 今日额度用完,保留规则,明天继续
            END IF;

            v_amt := LEAST(r.amount, v_left);

            -- 调用真正的支持逻辑。
            -- 注意:support_company 已被令牌包装,内部调用它会被鉴权拦下,
            -- 所以优先调原始版 _orig_support_company;万一没有再退回包装版。
            BEGIN
                SELECT public._orig_support_company(r.user_id, r.company_id, v_amt) INTO v_res;
            EXCEPTION WHEN undefined_function THEN
                BEGIN
                    SELECT public.support_company(r.user_id, r.company_id, v_amt) INTO v_res;
                EXCEPTION WHEN OTHERS THEN
                    v_res := NULL;
                END;
            WHEN OTHERS THEN
                v_res := NULL;
            END;

            IF v_res IS NOT NULL AND v_res->>'success' = 'true' THEN
                v_count := v_count + 1;
                -- 记账(按规则累加,用于按用户汇总)
                UPDATE public.support_rules
                   SET today_supported = CASE WHEN today_date = v_today THEN today_supported ELSE 0 END + v_amt,
                       today_date = v_today
                 WHERE id = r.id;
            END IF;
        END IF;
    END LOOP;

    RAISE NOTICE 'run_auto_support: 成功 % 条 · 余额不足保留 % 条 · 超出日额度 % 条 · 清理无效 % 条',
        v_count, v_skipped, v_capped, v_deleted;
END
$fn$;

-- 权限说明:
--   · sample_market_snapshot → 必须给 anon(数据库 pg_cron 与 GitHub Actions
--     定时任务都在用它,锁了就断采样)
--   · collect_company_tax / random_fluctuate_market_values → **保持锁定**,
--     只由 sample_market_snapshot(SECURITY DEFINER)内部调用。
--     尤其 random_fluctuate 能直接操纵市值,一旦对匿名开放就是新的操纵入口。
GRANT EXECUTE ON FUNCTION public.sample_market_snapshot() TO anon;
REVOKE ALL ON FUNCTION public.collect_company_tax() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.random_fluctuate_market_values() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.do_check_in(uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.run_auto_support() TO anon;

-- ============================================================
-- 验收
-- ============================================================
-- 1) 波动函数里应该有均值回归,且必须是「按时间缩放」的新版
--    重点看 按时间缩放 这一列:false = 装的是旧版(力度绑死轮数,会崩盘),必须重跑本文件
SELECT '波动函数' AS 项目,
       (pg_get_functiondef(p.oid) LIKE '%v_pull%')   AS 已含均值回归,
       (pg_get_functiondef(p.oid) LIKE '%v_k_day%')  AS 按时间缩放
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'random_fluctuate_market_values';

-- 1b) 预演:按当前市值算,各家「一天」的预期回归幅度
--     (交易时段 12 小时 = 一天的总缩放系数 0.5;随机部分是零均值,这里只看回归)
--     大公司那一列应该是负的、且 5000 万以上的大概 -10% 上下;
--     小公司那一列是正的(往均值抬)。数量级对了才算装对。
SELECT c.company_name AS 公司,
       c.market_value  AS 当前市值,
       round(c.market_value / a.avg_mv, 1) AS 相对均值倍数,
       round((exp(-0.0474 * ln(c.market_value / a.avg_mv) * 0.5) - 1) * 100, 2) AS 预期日涨跌百分比
  FROM public.user_companies c
  CROSS JOIN (SELECT avg(market_value) AS avg_mv FROM public.user_companies) a
 WHERE c.market_value > 0 AND a.avg_mv > 0
 ORDER BY c.market_value DESC
 LIMIT 10;

-- 2) 公司税分段是否正确(照抄参数核对)
SELECT '公司税' AS 项目,
       (pg_get_functiondef(p.oid) LIKE '%0.002%') AS 有0_2档,
       (pg_get_functiondef(p.oid) LIKE '%0.005%') AS 有0_5档,
       (pg_get_functiondef(p.oid) LIKE '%0.010%') AS 有1档,
       (pg_get_functiondef(p.oid) LIKE '%0.020%') AS 有2档
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'collect_company_tax';

-- 3) 签到封顶是否生效
SELECT '签到' AS 项目,
       (pg_get_functiondef(p.oid) LIKE '%v_cap%') AS 已封顶
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'do_check_in';

-- 4) 自动支持日限额是否生效 + 新列是否加上
SELECT '自动支持' AS 项目,
       (pg_get_functiondef(p.oid) LIKE '%v_daily_cap%') AS 已加日限额
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'run_auto_support';

SELECT column_name AS support_rules新增列
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name='support_rules'
   AND column_name IN ('today_supported','today_date');

-- 5) 当前市值分布(执行后可以对照看效果)
SELECT count(*) AS 公司数,
       round(sum(market_value)/1e8, 2) AS 总市值亿,
       round(max(market_value)/1e8, 2) AS 最大亿,
       count(*) FILTER (WHERE market_value >= 300000) AS 需缴税家数
  FROM public.user_companies;

-- 6) 手动试跑一次公司税(可选,想立刻看到效果就跑;平时由定时任务自动收)
-- SELECT public.collect_company_tax();
