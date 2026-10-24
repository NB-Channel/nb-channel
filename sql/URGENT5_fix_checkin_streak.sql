-- ============================================================
-- 🔴 紧急修复:补签后连续签到天数被算错(69 天 → 29 天)
--
-- 两个叠加的 bug:
--
--  bug 1(天数算错):use_checkin_fix 里这样算连续天数 ——
--        v_new_consecutive := 1;
--        WHILE ... WHERE check_in_date = p_target_date - v_idx ...   -- 只从「补签日」往前数
--      · 只从补签日往前数,**补签日之后已经签到的天数全丢了**
--      · 而且只查 check_in_records(真实签到),**不算补签记录**,中间补过签就会断
--      · 最后 consecutive_days = v_new_consecutive **直接覆盖**,原值永久丢失
--      例:连续 69 天,中间漏 1 天,补签那天 → 算成"那天之前连续了几天"= 29
--
--  bug 2(记录表停止增长):do_check_in 里本来就该写 check_in_records(签到历史,
--      热力图和补签都依赖它),但 checkin_tz_fix.sql 那版漏了这句,后来又覆盖执行过它,
--      于是签到历史从那时起就不再新增 —— 补签函数基于这张表算,自然越算越短。
--
-- 修法:
--   ① do_check_in 补回写 check_in_records
--   ② use_checkin_fix 的连续天数改成「从今天(或昨天)往前数,真实签到和补签都算」
--   ③ 提供重算函数,把被写坏的历史数据修回来
--
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

-- ============================================================
-- ① do_check_in:补回签到历史记录 + 保留每日奖励封顶
-- ============================================================
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

    reward := LEAST(new_consecutive * 100, v_cap);

    UPDATE profiles SET nb_balance = nb_balance + reward WHERE id = p_user_id;

    INSERT INTO user_checkins (user_id, last_checkin_date, consecutive_days)
    VALUES (p_user_id, v_today, new_consecutive)
    ON CONFLICT (user_id) DO UPDATE
    SET last_checkin_date = EXCLUDED.last_checkin_date,
        consecutive_days = EXCLUDED.consecutive_days;

    -- ⚠️ 这一句之前丢了:签到历史(热力图 + 补签天数计算都依赖它),必须写
    INSERT INTO check_in_records (user_id, check_in_date)
    VALUES (p_user_id, v_today)
    ON CONFLICT (user_id, check_in_date) DO NOTHING;

    RETURN jsonb_build_object('success', true, 'reward', reward, 'consecutive', new_consecutive,
                              'capped', (new_consecutive * 100) > v_cap);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$function$;

-- ============================================================
-- ② use_checkin_fix:连续天数改成从今天往前数
-- ============================================================
CREATE OR REPLACE FUNCTION public.use_checkin_fix(
    p_user_id uuid, p_target_date date, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_today date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_card_id bigint;
    v_new_consecutive integer;
    v_idx integer;
    v_month_count integer;
    v_start date;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;

    IF p_target_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '请选择要补签的日期');
    END IF;
    IF p_target_date >= v_today OR p_target_date < v_today - 5 THEN
        RETURN jsonb_build_object('success', false, 'message', '只能补签前 5 天内的漏签');
    END IF;

    -- 每个自然月最多补签 5 次
    SELECT count(*) INTO v_month_count FROM public.checkin_fix_records
     WHERE user_id = p_user_id
       AND date_trunc('month', check_in_date) = date_trunc('month', p_target_date);
    IF v_month_count >= 5 THEN
        RETURN jsonb_build_object('success', false, 'message', '本月补签次数已达上限(5 次),下个月再来吧');
    END IF;

    IF EXISTS (SELECT 1 FROM public.check_in_records WHERE user_id = p_user_id AND check_in_date = p_target_date) THEN
        RETURN jsonb_build_object('success', false, 'message', '该日期已签到,无需补签');
    END IF;
    IF EXISTS (SELECT 1 FROM public.checkin_fix_records WHERE user_id = p_user_id AND check_in_date = p_target_date) THEN
        RETURN jsonb_build_object('success', false, 'message', '该日期已补签过,不能重复补');
    END IF;

    -- 消耗一张补签卡
    SELECT id INTO v_card_id FROM public.user_items
     WHERE user_id = p_user_id AND item_key = 'checkin_fix'
       AND used = false AND (expires_at IS NULL OR expires_at > now())
     ORDER BY id LIMIT 1;
    IF v_card_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '没有可用的补签卡');
    END IF;

    -- 写入补签记录
    INSERT INTO public.checkin_fix_records (user_id, check_in_date)
    VALUES (p_user_id, p_target_date);

    -- ===== 重新计算连续天数 =====
    -- 起点:今天有记录就用今天;今天还没签到但昨天有,就用昨天(不判为断签);
    --       都没有才算真的断,这时连续天数从这次补签重新算起。
    IF EXISTS (SELECT 1 FROM public.check_in_records WHERE user_id = p_user_id AND check_in_date = v_today)
       OR EXISTS (SELECT 1 FROM public.checkin_fix_records WHERE user_id = p_user_id AND check_in_date = v_today) THEN
        v_start := v_today;
    ELSIF EXISTS (SELECT 1 FROM public.check_in_records WHERE user_id = p_user_id AND check_in_date = v_today - 1)
       OR EXISTS (SELECT 1 FROM public.checkin_fix_records WHERE user_id = p_user_id AND check_in_date = v_today - 1) THEN
        v_start := v_today - 1;
    ELSE
        v_start := NULL;
    END IF;

    IF v_start IS NULL THEN
        v_new_consecutive := 1;
    ELSE
        v_new_consecutive := 0;
        v_idx := 0;
        WHILE v_idx <= 365 LOOP
            -- 真实签到 与 补签 都算连续
            IF EXISTS (SELECT 1 FROM public.check_in_records
                        WHERE user_id = p_user_id AND check_in_date = v_start - v_idx)
               OR EXISTS (SELECT 1 FROM public.checkin_fix_records
                           WHERE user_id = p_user_id AND check_in_date = v_start - v_idx) THEN
                v_new_consecutive := v_new_consecutive + 1;
                v_idx := v_idx + 1;
            ELSE
                EXIT;
            END IF;
        END LOOP;
    END IF;

    UPDATE public.user_checkins
       SET last_checkin_date = GREATEST(coalesce(last_checkin_date, p_target_date), p_target_date),
           consecutive_days = v_new_consecutive
     WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        INSERT INTO public.user_checkins (user_id, last_checkin_date, consecutive_days)
        VALUES (p_user_id, p_target_date, v_new_consecutive);
    END IF;

    UPDATE public.user_items SET used = true WHERE id = v_card_id;

    RETURN jsonb_build_object('success', true, 'message',
        format('补签成功:%s(消耗 1 张补签卡,连续 %s 天)', p_target_date::text, v_new_consecutive),
        'consecutive', v_new_consecutive);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;

-- ============================================================
-- ③ 重算连续天数(把被写坏的数据修回来)
-- ============================================================
-- 按「从今天往前数、真实签到+补签都算」重算,返回重算后的天数。
-- 注意:如果签到历史记录本身缺失(受 bug 2 影响),算出来的值会偏小,
--       那种情况需要手工指定天数(见文件最后的语句)。
CREATE OR REPLACE FUNCTION public.recalc_checkin_streak(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_today date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
    v_start date;
    v_idx integer;
    v_n integer;
BEGIN
    IF EXISTS (SELECT 1 FROM public.check_in_records WHERE user_id = p_user_id AND check_in_date = v_today)
       OR EXISTS (SELECT 1 FROM public.checkin_fix_records WHERE user_id = p_user_id AND check_in_date = v_today) THEN
        v_start := v_today;
    ELSIF EXISTS (SELECT 1 FROM public.check_in_records WHERE user_id = p_user_id AND check_in_date = v_today - 1)
       OR EXISTS (SELECT 1 FROM public.checkin_fix_records WHERE user_id = p_user_id AND check_in_date = v_today - 1) THEN
        v_start := v_today - 1;
    ELSE
        v_start := NULL;
    END IF;

    IF v_start IS NULL THEN RETURN 0; END IF;

    v_n := 0;
    v_idx := 0;
    WHILE v_idx <= 365 LOOP
        IF EXISTS (SELECT 1 FROM public.check_in_records
                    WHERE user_id = p_user_id AND check_in_date = v_start - v_idx)
           OR EXISTS (SELECT 1 FROM public.checkin_fix_records
                       WHERE user_id = p_user_id AND check_in_date = v_start - v_idx) THEN
            v_n := v_n + 1;
            v_idx := v_idx + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    RETURN v_n;
END
$fn$;

-- 对所有用户批量重算(只增不减,避免把本来对的数据改小)
DO $$
DECLARE
    r record;
    v_new int;
    v_old int;
    v_fixed int := 0;
BEGIN
    FOR r IN SELECT u.user_id, u.consecutive_days AS old_days FROM public.user_checkins u LOOP
        v_old := coalesce(r.old_days, 0);
        v_new := public.recalc_checkin_streak(r.user_id);
        IF v_new > v_old THEN
            UPDATE public.user_checkins SET consecutive_days = v_new WHERE user_id = r.user_id;
            v_fixed := v_fixed + 1;
        END IF;
    END LOOP;
    RAISE NOTICE '连续签到天数重算完成:修正 % 个用户', v_fixed;
END $$;

GRANT EXECUTE ON FUNCTION public.do_check_in(uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.use_checkin_fix(uuid, date, text) TO anon;
REVOKE ALL ON FUNCTION public.recalc_checkin_streak(uuid) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 验收 + 诊断
-- ============================================================
-- 1) 两个函数是否都改到位
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%check_in_records%') AS 已写签到历史,
       (pg_get_functiondef(p.oid) LIKE '%v_start%')          AS 按今天起点算天数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('do_check_in', 'use_checkin_fix')
 ORDER BY 1;

-- 2) 连续天数排行(受影响的用户应该在这里)
SELECT u.user_id, p.username, u.last_checkin_date AS 最后签到, u.consecutive_days AS 连续天数
  FROM public.user_checkins u
  LEFT JOIN public.profiles p ON p.id = u.user_id
 ORDER BY u.consecutive_days DESC
 LIMIT 15;

-- 3) 签到历史记录到底有多少(判断 bug 2 影响了多长时间)
SELECT count(*) AS 真实签到记录数, count(DISTINCT user_id) AS 涉及用户, max(check_in_date) AS 最新记录
  FROM public.check_in_records;
SELECT count(*) AS 补签记录数, max(check_in_date) AS 最新补签 FROM public.checkin_fix_records;

-- ============================================================
-- 4) 如果某人的记录本身缺失、重算不准,手工指定天数(按需执行)
-- ============================================================
-- 把 <用户ID> 和 69 换成实际值:
-- UPDATE public.user_checkins SET consecutive_days = 69 WHERE user_id = '<用户ID>';
-- SELECT * FROM public.user_checkins WHERE user_id = '<用户ID>';
