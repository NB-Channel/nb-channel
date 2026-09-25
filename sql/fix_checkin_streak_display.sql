-- ============================================================
-- 修复:「连续签到」显示不准(断签后仍显示旧值)
--
-- 现状:get_user_home_profile 里是这样取连续天数的 ——
--         'checkin', coalesce((SELECT consecutive_days FROM user_checkins WHERE user_id=...), 0)
--       而 consecutive_days 只在「签到那一刻」更新:
--         IF last_checkin = 昨天 THEN 天数+1 ELSE 1
--       一旦断签且不再签到,这个字段就永远停在旧值。
--       实际案例:「一颗小星」最后签到 9-09(16 天前),页面上却还显示「连续 9 天」。
--
-- 修法:新增一个「当前连续天数」函数,断签超过 1 天就算 0;
--       把 get_user_home_profile 和 get_checkin_status 都改成用它。
--       只改显示,不动任何数据 —— 他下次签到时本来也会自动重置为 1。
--
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

-- ============================================================
-- ① 新增:当前连续签到天数(断签则算 0)
-- ============================================================
CREATE OR REPLACE FUNCTION public.current_checkin_streak(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_days int;
    v_last date;
    v_today date := (now() AT TIME ZONE 'Asia/Shanghai')::date;
BEGIN
    SELECT consecutive_days, last_checkin_date INTO v_days, v_last
      FROM public.user_checkins WHERE user_id = p_user_id;

    IF v_days IS NULL OR v_last IS NULL THEN
        RETURN 0;
    END IF;
    -- 最后签到是今天或昨天 → 连续有效;更早 → 已经断了,当前连续为 0
    IF v_last >= v_today - 1 THEN
        RETURN v_days;
    END IF;
    RETURN 0;
END
$fn$;

-- 这个函数是给「公开的主页资料」(get_user_home_profile,匿名可读)内部调用的,
-- 而连续签到天数本来就在别人主页上公开展示,不泄露任何新东西。
-- 所以刻意「不」锁:万一两个函数 owner 不一致,SECURITY DEFINER 嵌套调用会被拒,
-- 那样所有人的主页都会挂。给它普通读权限最稳。
GRANT EXECUTE ON FUNCTION public.current_checkin_streak(uuid) TO anon, authenticated;

-- ============================================================
-- ② get_user_home_profile:把 checkin 统计换成新函数
-- ============================================================
-- 这个函数有两个历史版本(profile_enhance.sql 5752 字符 / user_home_profile.sql 3893 字符),
-- 直接手抄容易漏东西,所以用 pg_get_functiondef 拿出线上真实定义,只替换那一行。
DO $$
DECLARE
    r record;
    v_def text;
    v_new text;
    v_cnt int := 0;
BEGIN
    FOR r IN
        SELECT p.oid
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.prokind = 'f'
           AND p.proname = 'get_user_home_profile'
    LOOP
        v_def := pg_get_functiondef(r.oid);
        -- 宽松匹配:不管中间空格怎么排都能命中
        v_new := regexp_replace(
            v_def,
            '''checkin'',\s*coalesce\(\(SELECT consecutive_days FROM public\.user_checkins WHERE user_id = p_user_id\),\s*0\)',
            '''checkin'', public.current_checkin_streak(p_user_id)',
            'g');
        -- 已经改过的就跳过
        IF v_new <> v_def THEN
            BEGIN
                EXECUTE v_new;
                v_cnt := v_cnt + 1;
                RAISE NOTICE '✅ get_user_home_profile 已改为使用 current_checkin_streak';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '⚠️ 替换失败: %', SQLERRM;
            END;
        ELSIF v_def LIKE '%current_checkin_streak%' THEN
            RAISE NOTICE 'ℹ️ get_user_home_profile 已经是新版,跳过';
        ELSE
            RAISE NOTICE '⚠️ 没匹配到 checkin 那一行,请人工检查函数定义';
        END IF;
    END LOOP;
    IF v_cnt = 0 THEN
        RAISE NOTICE 'ℹ️ 没有需要修改的 get_user_home_profile';
    END IF;
END $$;

-- ============================================================
-- ③ get_checkin_status:补上 continuous 字段(断签归零)+ 保留令牌校验
-- ============================================================
-- 原来它只返回 can_checkin / next_bonus,没有当前连续天数,顺手补上。
-- (线上是带 p_session 的包装版,这里用同名同签名重新实现,内部自己做鉴权)
CREATE OR REPLACE FUNCTION public.get_checkin_status(p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    last_checkin DATE;
    consecutive INT;
    can_checkin BOOLEAN;
    next_bonus INT;
    v_cur INT;
    v_cap CONSTANT INT := 3000;   -- 与 do_check_in 的封顶保持一致
    v_today DATE := (now() AT TIME ZONE 'Asia/Shanghai')::date;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;

    v_cur := public.current_checkin_streak(p_user_id);   -- 断签自动算 0
    can_checkin := true;
    next_bonus := LEAST((v_cur + 1) * 100, v_cap);
    last_checkin := NULL;

    SELECT c.last_checkin_date, c.consecutive_days INTO last_checkin, consecutive
      FROM public.user_checkins c WHERE c.user_id = p_user_id;

    IF last_checkin = v_today THEN
        can_checkin := false;
        -- 今天已签到,再签就是明天的事
        next_bonus := LEAST((consecutive + 1) * 100, v_cap);
    ELSIF last_checkin = v_today - 1 THEN
        next_bonus := LEAST((consecutive + 1) * 100, v_cap);
    ELSE
        next_bonus := 100;   -- 断了/从未签到,明天从 100 重新起
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'can_checkin', can_checkin,
        'today_bonus', CASE WHEN can_checkin THEN next_bonus ELSE NULL END,
        'next_bonus', next_bonus,
        'consecutive', v_cur,          -- 当前连续天数(断签为 0)
        'last_checkin_date', last_checkin,
        'capped', next_bonus >= v_cap
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_checkin_status(uuid, text) TO anon;

-- ============================================================
-- 验收
-- ============================================================
-- 1) 三个函数是否都就位
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%current_checkin_streak%') AS 已用新逻辑
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('current_checkin_streak', 'get_user_home_profile', 'get_checkin_status')
 ORDER BY 1;

-- 2) 对照:数据库中存的值 vs 实际应该显示的值
--    「应该显示」为 0 的,就是断签后被旧值误导的用户
SELECT p.username AS 用户名,
       u.last_checkin_date AS 最后签到,
       u.consecutive_days AS 库里的值,
       public.current_checkin_streak(u.user_id) AS 实际应显示,
       (u.last_checkin_date IS NULL OR u.last_checkin_date < (now() AT TIME ZONE 'Asia/Shanghai')::date - 1) AS 已断签
  FROM public.user_checkins u
  LEFT JOIN public.profiles p ON p.id = u.user_id
 WHERE u.consecutive_days > 0
 ORDER BY u.consecutive_days DESC
 LIMIT 20;
