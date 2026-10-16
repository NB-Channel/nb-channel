-- ============================================================
--  跑 lock_user_rpcs.sql 之前必须先做的三件事
--
--  子代理审计了 lock_user_rpcs.sql 名单里那 34 个函数，
--  逐个查了「前端传的到底是谁的 id」。结论是：那层令牌包装
--  （_user_ok(p_user_id, p_session)）会把下面三处弄坏。
--
--  ⚠️ 其中第 ① 条不是「会不会坏」，是【现在就有的安全漏洞】。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- ① 【安全漏洞，最要紧】use_checkin_fix 的 2 参数版不校验会话
--
--  现状：
--      use_checkin_fix(uuid, date)               ← 不校验会话 ✗
--      use_checkin_fix(uuid, date, text)         ← 校验了，但只是转调上面那个
--
--  前端调的时候是带 p_session 的（index.html:914 / lottery-Beta.html:1619），
--  但 PostgREST 是【按参数名】匹配函数的：
--      传 {p_user_id, p_target_date, p_session}
--      → 2 参数版的形参里没有 p_session，本该匹配 3 参数版
--      → 可是 2 参数版多出来的那个 p_session 会被【静默丢弃】而仍然匹配上
--      → 实际打的就是不校验的那个
--
--  后果：任何知道别人 uuid 的人，都能冒名消费对方的补签卡。
--
--  改法：只留一个版本，就必须带会话校验。
--       DROP 掉两个旧签名，重建一个 use_checkin_fix(uuid, date, text)。
--       前端本来就是按【参数名】调的，三个名字都对得上，不用改前端。
-- ============================================================
DROP FUNCTION IF EXISTS public.use_checkin_fix(uuid, date);
DROP FUNCTION IF EXISTS public.use_checkin_fix(uuid, date, text);

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
    -- ⚠️ 这一句是本次补上的：以前没有，谁都能拿别人的 uuid 来补签
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;

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
            -- 真实签到和补签都算连续
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

    -- 取较大值，不直接覆盖
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

GRANT EXECUTE ON FUNCTION public.use_checkin_fix(uuid, date, text) TO anon, authenticated;


-- ============================================================
-- ② get_checkin_heatmap —— 拆一个公开版出来
--
--  问题：前端有 2 处是拿【被看的人】的 id 调的（看别人主页时画签到热力图）：
--      profile.html:739            uid = viewUid
--      Beta/profile-Beta.html:1985 uid = viewUid
--  包装一上就会「鉴权失败」→ 热力图整块空白。
--
--  和「装扮」那个同理：签到日历本来就是公开信息（谁哪天签到了），
--  而且它不返回任何隐私。所以拆一个不要会话的公开版。
--
--  ⚠️ get_checkin_heatmap 本体【不动】，继续留在 lock_user_rpcs 名单里，
--     给「查自己」用（如果以后有这种调用）。
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_public_checkin_heatmap(
    p_user_id uuid, p_days integer DEFAULT 365)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $pub$
DECLARE
    v_dates date[];
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'dates', '[]'::jsonb);
    END IF;
    SELECT array_agg(check_in_date ORDER BY check_in_date)
      INTO v_dates
      FROM public.check_in_records
     WHERE user_id = p_user_id
       AND check_in_date >= (now() AT TIME ZONE 'Asia/Shanghai')::date - (p_days - 1);
    RETURN jsonb_build_object('success', true, 'dates', coalesce(to_jsonb(v_dates), '[]'::jsonb));
END;
$pub$;

GRANT EXECUTE ON FUNCTION public.get_public_checkin_heatmap(uuid, integer) TO anon, authenticated;


-- ============================================================
-- ③ 【跑 lock_user_rpcs.sql 之前必查】get_my_holdings 的重载
--
--  Virtual stock.html:2970-2973 的注释写着：库里 get_my_holdings 有
--      (uuid) 和 (uuid, text) 两个重载，只传 p_user_id 会报 PGRST203。
--
--  如果真是这样，那 lock_user_rpcs 包装 (uuid) 那版之后会变成：
--      get_my_holdings(uuid)        带 p_session
--      get_my_holdings(uuid, text)  也带 p_session
--      → 前端传 {p_user_id, p_session} 会【同时匹配两个】→ PGRST203
--      → 持仓页整页报错
--
--  ⚠️ 下面这条只是查询，先看清楚库里有几个、哪个 anon 能调。
-- ============================================================
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon可调
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'get_my_holdings'
 ORDER BY 2;

-- ⚠️ 如果上面出现【两行 anon可调 = true】，且其中一行的参数里没有 p_session，
--    那跑 lock_user_rpcs 之前要先把那一行 REVOKE 掉：
--
--    REVOKE ALL ON FUNCTION public.get_my_holdings(uuid) FROM PUBLIC, anon, authenticated;
--
--    （把 (uuid) 换成上面查出来的那个不带 p_session 的签名）


-- ============================================================
-- ④ 验收
-- ============================================================
-- 4.1 use_checkin_fix 现在只剩一个签名，而且带会话校验
SELECT p.proname AS 函数,
       pg_get_function_identity_arguments(p.oid) AS 参数,
       (pg_get_functiondef(p.oid) LIKE '%_user_ok%') AS 校验会话
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'use_checkin_fix'
 ORDER BY 2;

-- 4.2 热力图两个版本都在
SELECT p.proname AS 函数, pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('get_checkin_heatmap', 'get_public_checkin_heatmap')
 ORDER BY 1;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 补签接口不再是「知道 uuid 就能冒名」了
--  · 看别人主页的签到热力图有公开版可调（前端已改，在另一个提交里）
--  · get_my_holdings 的重载情况看 ③ 的结果，有问题先 REVOKE 再跑 lock
--
--  ⚠️ 还有两处【本次没动】，你自己定：
--      · visit_profile（profile.html:624）也是拿别人的 id 调，
--        但它有 if (!isOwner) 守卫，坏的只是「访问量 +1」。
--        它是【写操作】，不适合做成公开版。建议从 lock_user_rpcs 名单里去掉。
--      · update_username 其实【已经被更早的迁移包过一层】了
--        （sql/username_allow_symbols_v2_20261009.sql 里有 _orig_update_username），
--        lock_user_rpcs 的 EXISTS guard 会让它整个跳过 —— 已经是安全的，
--        但建议从名单里显式摘出来，别靠「巧合跳过」。
-- ============================================================
