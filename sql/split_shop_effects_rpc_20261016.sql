-- ============================================================
--  把「查装扮」拆成两个函数 —— 修掉 lock_user_rpcs.sql 的定时炸弹
--
--  ── 问题 ──
--      sql/lock_user_rpcs.sql 打算给 34 个 RPC 套一层会话令牌校验，
--      包装体是：
--          IF NOT public._user_ok(p_user_id, p_session) THEN 鉴权失败 END IF;
--      而 _user_ok 校验的是「这个会话是不是【属于】p_user_id」。
--
--      但前端有 6 处是拿【别人的 id】调 get_active_shop_effects：
--          profile.html:521            viewUid     （看别人主页）
--          profile-Beta.html:1756      viewUid
--          comments-beta.html:3541     uid         （别人的评论装扮）
--          comments-Beta.html:2455     uid
--          chat.html:1265              otherId     （对方的气泡）
--          chat-Beta.html:1343         otherId
--      传进去的会话是【看客自己】的 → _user_ok(别人的id, 看客的session) = false
--      → 那个脚本一旦跑成功，全站的主页/评论/私信装扮整片失效。
--
--  ── 改法：拆成两个 ──
--      ① get_public_shop_effects(p_user_id)      ← 新建
--            逻辑和现在一字不差，只读、不要会话。
--            给「查别人」用，【不进】 lock_user_rpcs 的名单。
--
--      ② get_active_shop_effects(p_user_id, p_session)   ← 保持现状
--            给「查自己」的 10 处用（那些地方传的本来就是自己的 id，
--            套令牌校验是安全的，也确实是想要的）。
--            继续留在 lock_user_rpcs 名单里。
--
--      ⚠️ 为什么可以公开查别人的装扮：
--         它返回的是「某人当前生效的装扮」—— 昵称颜色、评论颜色、
--         私信气泡、粒子特效、展示位称号。这些东西【本来就是给别人看】的，
--         展示在主页和评论区。它不返回余额、邮箱、会话、私信内容。
--         所以「谁都能查」不是漏洞，是它的用途。
--
--      ③ 前端 6 处改成调 get_public_shop_effects（另一个提交里改的）
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步：建 get_public_shop_effects
--   函数体和 get_active_shop_effects 完全一样，只是换个名字、不要求会话。
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_public_shop_effects(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $pub$
DECLARE
    v_result jsonb;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false);
    END IF;
    SELECT jsonb_build_object(
        'success', true,
        -- 评论颜色（取设置值）
        'comment_color', (SELECT settings->>'value' FROM public.user_items
                           WHERE user_id = p_user_id AND item_key = 'comment_color'
                             AND used = false AND expires_at > now()
                           ORDER BY expires_at DESC LIMIT 1),
        -- 昵称颜色
        'nickname_color', (SELECT settings->>'value' FROM public.user_items
                            WHERE user_id = p_user_id AND item_key = 'nickname_color'
                              AND used = false AND expires_at > now()
                            ORDER BY expires_at DESC LIMIT 1),
        -- 私信气泡
        'chat_bubble', (SELECT settings->>'value' FROM public.user_items
                         WHERE user_id = p_user_id AND item_key = 'chat_bubble'
                           AND used = false AND expires_at > now()
                         ORDER BY expires_at DESC LIMIT 1),
        -- 粒子特效
        'particle_fx', (SELECT settings->>'value' FROM public.user_items
                         WHERE user_id = p_user_id AND item_key = 'particle_fx'
                           AND used = false AND expires_at > now()
                         ORDER BY expires_at DESC LIMIT 1),
        -- 主页皮肤（settings 里含 banner 头图）
        'profile_skin', (SELECT settings FROM public.user_items
                          WHERE user_id = p_user_id AND item_key = 'profile_skin'
                            AND used = false AND expires_at > now()
                          ORDER BY expires_at DESC LIMIT 1),
        -- 称号展示位
        'title_slot', (SELECT jsonb_build_object(
                            'count', count(*),
                            'chosen_title_key', (SELECT settings->>'chosen_title_key' FROM public.user_items
                                                  WHERE user_id = p_user_id AND item_key = 'title_slot'
                                                    AND used = false AND expires_at > now()
                                                  ORDER BY expires_at DESC LIMIT 1),
                            'slot_title', coalesce(
                                (SELECT jsonb_build_object(
                                            'title_key', t.key, 'name', t.name,
                                            'image_url', t.image_url, 'icon', t.icon, 'stars', ut.stars)
                                   FROM public.titles t
                                   JOIN public.user_titles ut ON ut.title_key = t.key AND ut.user_id = p_user_id
                                  WHERE t.key = (SELECT settings->>'chosen_title_key' FROM public.user_items
                                                  WHERE user_id = p_user_id AND item_key = 'title_slot'
                                                    AND used = false AND expires_at > now()
                                                  ORDER BY expires_at DESC LIMIT 1)
                                  LIMIT 1),
                                (SELECT jsonb_build_object(
                                            'title_key', t.key, 'name', t.name,
                                            'image_url', t.image_url, 'icon', t.icon, 'stars', ut.stars)
                                   FROM public.user_titles ut
                                   JOIN public.titles t ON t.key = ut.title_key
                                   LEFT JOIN public.profiles p ON p.id = p_user_id
                                  WHERE ut.user_id = p_user_id
                                    AND t.key <> coalesce(p.equipped_title_id, '')
                                  ORDER BY ut.stars DESC, t.key
                                  LIMIT 1)
                            )
                        )
                        FROM public.user_items
                        WHERE user_id = p_user_id AND item_key = 'title_slot'
                          AND used = false AND expires_at > now()),
        -- 签名扩展是否生效
        'bio_extend', EXISTS (SELECT 1 FROM public.user_items
                               WHERE user_id = p_user_id AND item_key = 'bio_extend'
                                 AND used = false AND expires_at > now()),
        -- 可用补签卡数量
        'checkin_fix_count', (SELECT count(*) FROM public.user_items
                               WHERE user_id = p_user_id AND item_key = 'checkin_fix'
                                 AND used = false AND (expires_at IS NULL OR expires_at > now())),
        -- 可用手续费减免券数量
        'fee_discount_count', (SELECT count(*) FROM public.user_items
                                WHERE user_id = p_user_id AND item_key = 'fee_discount'
                                  AND used = false AND (expires_at IS NULL OR expires_at > now())),
        -- 今日抽奖额外次数
        'lottery_extra_today', coalesce((
            SELECT sum((settings->>'lottery_extra')::int)
              FROM public.user_items
             WHERE user_id = p_user_id AND item_key = 'lottery_extra' AND used = true
               AND settings->>'lottery_date' = (now() AT TIME ZONE 'Asia/Shanghai')::date::text), 0)
    ) INTO v_result;
    RETURN v_result;
END;
$pub$;

-- 公开只读，谁都能调 —— 它返回的东西本来就是公开展示的
GRANT EXECUTE ON FUNCTION public.get_public_shop_effects(uuid) TO anon, authenticated;


-- ============================================================
-- 第 2 步：确认 get_active_shop_effects 还在（给「查自己」用）
--   这个不动。它在 lock_user_rpcs 名单里，将来会被套上令牌校验 ——
--   而调它的 10 处传的都是自己的 id，套上是安全的。
-- ============================================================
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('get_active_shop_effects', 'get_public_shop_effects')
 ORDER BY 1;


-- ============================================================
-- 第 3 步：验收 —— 两个函数对同一个用户返回的东西应该一样
--   拿一个真实用户比一下（这里用 Utw 举例，可以换成任意 id）
-- ============================================================
DO $$
DECLARE
    v_uid  uuid := 'ea24ed9e-6584-4d8b-84b6-36f594200888';   -- Utw
    v_a    jsonb;
    v_b    jsonb;
BEGIN
    v_a := public.get_active_shop_effects(v_uid);
    v_b := public.get_public_shop_effects(v_uid);
    IF v_a = v_b THEN
        RAISE NOTICE '✅ 两个函数返回完全一致';
    ELSE
        RAISE NOTICE '⚠️ 返回不一致，差别如下：';
        RAISE NOTICE '   get_active_shop_effects: %', v_a;
        RAISE NOTICE '   get_public_shop_effects: %', v_b;
    END IF;
END $$;


-- ============================================================
--  跑完之后还要做两件事（不在这个脚本里）
-- ============================================================
--  ① 前端那 6 处改成调 get_public_shop_effects（已改，在另一个提交里）：
--         profile.html / profile-Beta.html
--         comments-beta.html / comments-Beta.html
--         chat.html / chat-Beta.html
--
--  ② lock_user_rpcs.sql 的名单【不用动】：
--         get_active_shop_effects 继续留在里面（查自己，安全）
--         get_public_shop_effects 本来就不在名单里，以后也别加
--
--  ⚠️ 顺序很重要：先跑这个脚本 + 前端上线（强刷），
--     再跑 lock_user_rpcs.sql。反了的话那 6 处会先坏一阵。
-- ============================================================
