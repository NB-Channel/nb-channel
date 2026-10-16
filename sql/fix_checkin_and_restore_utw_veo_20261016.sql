-- ============================================================
--  修签到 / 补签 —— 并恢复 Utw 的 85 天、Veo 的 10 天
--
--  ── 站长反馈 ──
--  「补签完只有签到天数+1，把大号85，小号10还一下」
--      大号 = Utw   ea24ed9e-6584-4d8b-84b6-36f594200888
--      小号 = Veo   633685cd-57c3-4659-a588-5915af9d5136
--
--  ── 诊断结果（跑过 DIAGNOSE 那个脚本）──
--      Utw  连续天数 4（应为 85）
--           真实签到记录 73 条，但最晚只到 2026-09-25
--           而 last_checkin_date 已经是 10-16 —— 说明 10-15、10-16
--           签到了却没写进 check_in_records
--      Veo  连续天数 2（应为 10）
--           真实签到记录 0 条（一条都没有）
--
--  ── 三个叠加的原因 ──
--   ① do_check_in 漏了写 check_in_records
--      （checkin_tz_fix.sql 那版漏了这句，而它在 URGENT5 之后又执行过，
--        把补回记录的那版覆盖掉了 → 签到历史停止增长）
--
--   ② use_checkin_fix 有两个 bug：
--        · 算连续天数时不算 checkin_fix_records（补签记录）
--        · 算出来的值【直接覆盖】consecutive_days
--
--   ③ ⚠️ 真正让 bug 一直活着的原因：函数签名对不上
--        URGENT5 建的是   use_checkin_fix(uuid, date, text)   ← 3 参数，修好的
--        shop.sql 建的是  use_checkin_fix(uuid, date)         ← 2 参数，旧的坏的
--        前端调的是【2 个参数】那个 → 一直走旧逻辑
--        两个同名函数同时存在，修好的那个没人调
--
--  ── 这个脚本做什么 ──
--    第 1 步  修 do_check_in（补回写签到历史）
--    第 2 步  修 use_checkin_fix —— 【两个签名都修】，前端调的那个也修
--    第 3 步  重算函数 + 批量重算（只增不减，不会把对的改小）
--    第 4 步  补 Utw / Veo 缺的签到历史
--    第 5 步  给这两个号重算连续天数
--    第 6 步  验收
--
--  幂等，可以重复跑。
--  用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 0 步：先记下改之前的样子（跑完对比）
-- ============================================================
SELECT p.username AS 用户名, u.last_checkin_date AS 最后签到,
       u.consecutive_days AS 改前连续天数
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',
                '633685cd-57c3-4659-a588-5915af9d5136')
 ORDER BY p.username;


-- ============================================================
-- 第 1 步：do_check_in —— 补回「写签到历史」那一句
--   这一句不写，热力图和补签天数都会算错，而且历史越攒越少。
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

    -- ⚠️ 关键的一句：签到历史（热力图 + 补签天数计算都依赖它）
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
-- 第 2 步：use_checkin_fix —— 两个签名都修
--   前端调的是 2 参数那个，所以那个必须修；
--   3 参数那个（URGENT5 建的）也重建成同一套逻辑，免得以后再打架。
-- ============================================================

-- 2.1 先删掉旧的 2 参数版（旧逻辑就在它里面）
DROP FUNCTION IF EXISTS public.use_checkin_fix(uuid, date);

-- 2.2 建 2 参数版（前端调这个）—— 逻辑和 3 参数版一致，只是不校验会话
CREATE OR REPLACE FUNCTION public.use_checkin_fix(p_user_id uuid, p_target_date date)
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
    IF p_target_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '请选择要补签的日期');
    END IF;
    IF p_target_date >= v_today OR p_target_date < v_today - 5 THEN
        RETURN jsonb_build_object('success', false, 'message', '只能补签前 5 天内的漏签');
    END IF;

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

    SELECT id INTO v_card_id FROM public.user_items
     WHERE user_id = p_user_id AND item_key = 'checkin_fix'
       AND used = false AND (expires_at IS NULL OR expires_at > now())
     ORDER BY id LIMIT 1;
    IF v_card_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', '没有可用的补签卡');
    END IF;

    INSERT INTO public.checkin_fix_records (user_id, check_in_date)
    VALUES (p_user_id, p_target_date);

    -- ===== 重新计算连续天数 =====
    -- 起点：今天有记录就用今天；今天没有但昨天有，就用昨天（不判为断签）
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
            -- ⚠️ 真实签到和补签【都算】连续
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

    -- ⚠️ 取【较大值】，不直接覆盖 —— 补签一个老日期不应该把现在的大连续打回去
    UPDATE public.user_checkins
       SET last_checkin_date = GREATEST(coalesce(last_checkin_date, p_target_date), p_target_date),
           consecutive_days  = GREATEST(coalesce(consecutive_days, 0), v_new_consecutive)
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

GRANT EXECUTE ON FUNCTION public.use_checkin_fix(uuid, date) TO anon, authenticated;


-- 2.3 把 3 参数版也重建成同一套逻辑（带会话校验）
CREATE OR REPLACE FUNCTION public.use_checkin_fix(
    p_user_id uuid, p_target_date date, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn3$
DECLARE
    v_r jsonb;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    -- 校验过会话之后，直接调 2 参数那版，逻辑只有一份，不会走偏
    SELECT public.use_checkin_fix(p_user_id, p_target_date) INTO v_r;
    RETURN v_r;
END
$fn3$;

GRANT EXECUTE ON FUNCTION public.use_checkin_fix(uuid, date, text) TO anon, authenticated;


-- ============================================================
-- 第 3 步：重算函数 + 批量重算（只增不减）
-- ============================================================
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

REVOKE ALL ON FUNCTION public.recalc_checkin_streak(uuid) FROM PUBLIC, anon, authenticated;

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
    RAISE NOTICE '批量重算完成：修正 % 个用户（只增不减）', v_fixed;
END $$;


-- ============================================================
-- 第 4 步：补 Utw / Veo 缺的签到历史
--   从各自的「最后签到日」往前推 N-1 天，N 就是要恢复的连续天数。
--   已经存在的日期会自动跳过（ON CONFLICT DO NOTHING），不会重复插。
-- ============================================================

-- 4.1 Utw → 连续 85 天（从 2026-10-16 往前 84 天）
INSERT INTO public.check_in_records (user_id, check_in_date)
SELECT 'ea24ed9e-6584-4d8b-84b6-36f594200888'::uuid,
       (SELECT coalesce(last_checkin_date, current_date)
          FROM public.user_checkins
         WHERE user_id = 'ea24ed9e-6584-4d8b-84b6-36f594200888') - gs
  FROM generate_series(0, 84) AS gs
ON CONFLICT (user_id, check_in_date) DO NOTHING;

-- 4.2 Veo → 连续 10 天（从 2026-10-16 往前 9 天）
INSERT INTO public.check_in_records (user_id, check_in_date)
SELECT '633685cd-57c3-4659-a588-5915af9d5136'::uuid,
       (SELECT coalesce(last_checkin_date, current_date)
          FROM public.user_checkins
         WHERE user_id = '633685cd-57c3-4659-a588-5915af9d5136') - gs
  FROM generate_series(0, 9) AS gs
ON CONFLICT (user_id, check_in_date) DO NOTHING;


-- ============================================================
-- 第 5 步：给这两个号重算连续天数
--   ⚠️ 重算 —— 不是直接把 85 / 10 写死。
--      第 4 步补的记录在，重算才会得到 85 / 10。
--      如果重算结果不对，说明记录没补够，看第 6 步的输出。
-- ============================================================
DO $$
DECLARE
    v_id uuid;
    v_n  int;
BEGIN
    FOREACH v_id IN ARRAY ARRAY[
        'ea24ed9e-6584-4d8b-84b6-36f594200888'::uuid,   -- Utw
        '633685cd-57c3-4659-a588-5915af9d5136'::uuid    -- Veo
    ] LOOP
        v_n := public.recalc_checkin_streak(v_id);
        UPDATE public.user_checkins
           SET consecutive_days = GREATEST(coalesce(consecutive_days, 0), v_n)
         WHERE user_id = v_id;
        IF NOT FOUND THEN
            INSERT INTO public.user_checkins (user_id, last_checkin_date, consecutive_days)
            VALUES (v_id, (now() AT TIME ZONE 'Asia/Shanghai')::date, v_n);
        END IF;
        RAISE NOTICE '% 重算后连续 % 天', v_id, v_n;
    END LOOP;
END $$;


-- ============================================================
-- 第 6 步：验收
-- ============================================================

-- 6.1 两个号现在多少天（期望 Utw 85、Veo 10）
SELECT p.username AS 用户名, u.last_checkin_date AS 最后签到,
       u.consecutive_days AS 连续天数
  FROM public.profiles p
  LEFT JOIN public.user_checkins u ON u.user_id = p.id
 WHERE p.id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',
                '633685cd-57c3-4659-a588-5915af9d5136')
 ORDER BY p.username;

-- 6.2 记录数（Utw 应该从 73 涨到 85 以上；Veo 从 0 涨到 10）
SELECT p.username AS 用户名, count(r.*) AS 真实签到记录数,
       min(r.check_in_date) AS 最早, max(r.check_in_date) AS 最晚
  FROM public.profiles p
  LEFT JOIN public.check_in_records r ON r.user_id = p.id
 WHERE p.id IN ('ea24ed9e-6584-4d8b-84b6-36f594200888',
                '633685cd-57c3-4659-a588-5915af9d5136')
 GROUP BY p.username ORDER BY p.username;

-- 6.3 【重点】两个函数是否都修到位
--     期望：do_check_in 的「已写签到历史」= true
--           两个 use_checkin_fix 的「算补签记录」= true、「取大不覆盖」= true
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%check_in_records%')        AS 已写签到历史,
       (pg_get_functiondef(p.oid) LIKE '%checkin_fix_records%')     AS 算补签记录,
       (pg_get_functiondef(p.oid) LIKE '%GREATEST%')                AS 取大不覆盖
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('do_check_in', 'use_checkin_fix')
 ORDER BY 1, 2;

-- 6.4 全站连续天数排行（看有没有别人也被算坏了）
SELECT u.user_id, p.username AS 用户名, u.consecutive_days AS 连续天数
  FROM public.user_checkins u
  LEFT JOIN public.profiles p ON p.id = u.user_id
 ORDER BY u.consecutive_days DESC
 LIMIT 15;


-- ============================================================
--  跑完之后
-- ============================================================
--  · Utw 应该是 85 天、Veo 应该是 10 天
--  · 以后签到会正常写历史了（do_check_in 修好了）
--  · 补签也会正常算了（2 参数那个函数修好了，前端调的就是它）
--  · 补签不会再把你现在的连续天数打回去（改成取大值了）
--
--  ⚠️ 如果 6.1 里 Utw 不是 85、Veo 不是 10：
--      看 6.2 的记录数对不对 —— 记录数不够就是第 4 步没插进去，
--      把 6.1 / 6.2 / 6.3 的结果发我。
-- ============================================================
