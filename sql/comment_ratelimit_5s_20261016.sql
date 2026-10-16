-- ============================================================
--  评论限频：改成只有「5 秒 1 条」，去掉「1 小时 20 条」
--
--  站长要：「把评论区的发评论频率限制从30秒改成5秒」
--          「不要加1小时的限制，就加5秒的即可」
--
--  【改哪儿】
--      public.comments_guard —— 它是个【触发器函数】，
--      挂在 public.comments 的 BEFORE INSERT 上（触发器名 trg_comments_guard）。
--      里面有两条限频：
--
--        ④ 限频：30 秒内只能发 1 条
--             IF v_last > now() - interval '30 seconds' THEN
--                 RAISE EXCEPTION '发得太快了，请 30 秒后再试';
--
--        ⑤ 限频：1 小时最多 20 条
--             IF v_hour >= 20 THEN
--                 RAISE EXCEPTION '一小时内最多发 20 条评论，请稍后来';
--
--  【改成什么】
--      ④ 30 seconds → 5 seconds，提示语里的「30 秒」也换成「5 秒」
--         ⚠️ 不换提示语的话，用户会看到「请 30 秒后再试」但实际 5 秒就能发
--      ⑤ 整条取消 —— 把 IF v_hour >= 20 THEN 改成 IF false THEN
--
--  【为什么用 IF false 而不是删掉整段】
--      删整段要精确匹配多行（含缩进和换行），这个函数的定义从
--      pg_get_functiondef() 里取出来，空白字符不一定和仓库里那份一模一样，
--      匹配失败就会【静默什么都不做】。
--      改条件那一行是精确匹配，改不上一眼就能看出来。
--      v_hour 那句 SELECT 留着不碍事（只是一个没人用的计数）。
--
--  【保留不动的】
--      ⑥ 同样内容 24 小时内不能重复发   —— 这条是防刷，留着
--      ⑦ 敏感词拦截                    —— 留着
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步：改之前先看现状
-- ============================================================
SELECT (regexp_matches(pg_get_functiondef(p.oid), 'interval ''[^'']+''', 'g'))[1] AS 现在的间隔,
       (pg_get_functiondef(p.oid) LIKE '%v_hour >= 20%')                       AS 有1小时上限,
       (pg_get_functiondef(p.oid) LIKE '%1 hour%')                             AS 有1小时窗口
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'comments_guard';


-- ============================================================
-- 第 2 步：改
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_n    integer;
    v_hit  text[] := ARRAY[]::text[];
BEGIN
    FOR r IN
        SELECT pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'comments_guard'
    LOOP
        v_src := r.def;
        v_new := v_src;

        -- ④ 30 秒 → 5 秒
        v_n := (length(v_new) - length(replace(v_new, 'interval ''30 seconds''', '')))
               / length('interval ''30 seconds''');
        IF v_n > 0 THEN
            v_new := replace(v_new, 'interval ''30 seconds''', 'interval ''5 seconds''');
            v_hit := v_hit || ('间隔 30→5 秒（' || v_n || ' 处）');
        END IF;

        -- ④ 提示语里的「30 秒」也要换
        IF position('30 秒' in v_new) > 0 THEN
            v_new := replace(v_new, '请 30 秒后再试', '请 5 秒后再试');
            v_new := replace(v_new, '30 秒后再试',   '5 秒后再试');
            v_new := replace(v_new, '请30秒后再试',  '请5秒后再试');
            v_new := replace(v_new, '30秒后再试',    '5秒后再试');
            v_hit := v_hit || '提示语 30 秒→5 秒';
        END IF;

        -- ⑤ 去掉 1 小时 20 条
        IF position('v_hour >= 20' in v_new) > 0 THEN
            v_new := replace(v_new, 'v_hour >= 20', 'false');
            v_hit := v_hit || '1 小时上限已停用';
        END IF;

        IF v_new <> v_src THEN
            EXECUTE v_new;
            RAISE NOTICE '改了：%', array_to_string(v_hit, ' / ');
        ELSE
            RAISE NOTICE '⚠️ 一处都没替换上 —— 函数写法和脚本假设的不一样，别当成成功';
        END IF;
    END LOOP;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
-- 3.1 期望：间隔只有 5 seconds（没有 30 seconds）；
--          有1小时上限 = false；有1小时窗口 = false
SELECT (regexp_matches(pg_get_functiondef(p.oid), 'interval ''[^'']+''', 'g'))[1] AS 现在的间隔,
       (pg_get_functiondef(p.oid) LIKE '%v_hour >= 20%')              AS 还有1小时上限,
       (pg_get_functiondef(p.oid) LIKE '%1 hour%')                    AS 还有1小时窗口,
       (pg_get_functiondef(p.oid) LIKE '%请 5 秒后再试%')              AS 提示语是5秒
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'comments_guard';

-- 3.2 触发器还在不在（改函数不该动触发器，确认一下）
SELECT tgname AS 触发器, tgenabled AS 启用
  FROM pg_trigger
 WHERE tgrelid = 'public.comments'::regclass AND NOT tgisinternal;

-- 3.3 顺便看别人最近发得多不多（限频放松之后会不会有人刷屏）
SELECT p.username AS 用户名, count(*) AS 近1小时条数
  FROM public.comments c JOIN public.profiles p ON p.id = c.user_id
 WHERE c.created_at > now() - interval '1 hour'
 GROUP BY p.username ORDER BY 2 DESC LIMIT 10;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 发评论最短间隔 5 秒
--  · 不再有「一小时内最多发 20 条」的限制
--  · 防刷还剩两道：同样内容 24 小时内不能重复、敏感词拦截
--
--  ⚠️ 前端文案也要跟着改（已改，不在这个脚本里）：
--      js/science-tips.js 里的小贴士原写着「30 秒内只能发 1 条，1 小时最多 20 条」
--
--  ⚠️ 顺带一提：这个触发器是 RAISE EXCEPTION，
--     前端会收到一条数据库错误。如果前端没做友好提示，
--     玩家可能只看到「提交失败」而不是「发得太快了，请 5 秒后再试」。
-- ============================================================
