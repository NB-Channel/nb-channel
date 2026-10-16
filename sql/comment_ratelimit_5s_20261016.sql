-- ============================================================
--  评论限频：30 秒 → 5 秒
--
--  站长要「把评论区的发评论频率限制从30秒改成5秒」。
--
--  【改哪儿】
--      public.comments_guard 里有这么一句：
--          IF v_last IS NOT NULL AND v_last > now() - interval '30 seconds' THEN
--              RAISE EXCEPTION '发得太快了，请 30 秒后再试';
--
--      把 30 seconds 换成 5 seconds，提示语里的「30 秒」也要跟着换，
--      不然用户看到「请 30 秒后再试」但实际 5 秒就能发。
--
--  【怎么改】
--      不整段重写函数 —— 那要贴一百多行，容易抄错。
--      用 replace() 改 pg_get_functiondef() 再 EXECUTE 回去。
--      锚点带上前后文，避免误伤别处的 30 秒（股票节流那边也有 30 秒）。
--
--  ⚠️ 一小时最多 20 条那条【不动】—— 站长只说了 30 秒这个。
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步：改之前先看一眼现在写的是什么
-- ============================================================
SELECT (regexp_matches(pg_get_functiondef(p.oid), 'interval ''[^'']+''', 'g'))[1] AS 现在的间隔
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'comments_guard';


-- ============================================================
-- 第 2 步：把 30 秒换成 5 秒
-- ============================================================
DO $$
DECLARE
    r     record;
    v_src text;
    v_new text;
    v_n   integer;
BEGIN
    FOR r IN
        SELECT pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'comments_guard'
    LOOP
        v_src := r.def;

        IF position('interval ''5 seconds''' in v_src) > 0
           AND position('interval ''30 seconds''' in v_src) = 0 THEN
            RAISE NOTICE '已经是 5 秒了，跳过';
            CONTINUE;
        END IF;

        v_n := (length(v_src) - length(replace(v_src, 'interval ''30 seconds''', '')))
               / length('interval ''30 seconds''');

        v_new := v_src;
        -- ① 间隔
        v_new := replace(v_new, 'interval ''30 seconds''', 'interval ''5 seconds''');
        -- ② 提示语里的「30 秒」（用户看得见的那句）
        v_new := replace(v_new, '请 30 秒后再试',  '请 5 秒后再试');
        v_new := replace(v_new, '30 秒后再试',    '5 秒后再试');
        v_new := replace(v_new, '请30秒后再试',   '请5秒后再试');
        v_new := replace(v_new, '30秒后再试',     '5秒后再试');

        IF v_new <> v_src THEN
            EXECUTE v_new;
            RAISE NOTICE '改了：间隔 % 处（期望 1 处），提示语也一起换了', v_n;
        ELSE
            RAISE NOTICE '⚠️ 一处都没替换上 —— 函数写法和脚本假设的不一样，别当成成功';
        END IF;
    END LOOP;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
-- 3.1 现在的间隔（期望：只有 5 seconds，没有 30 seconds）
SELECT (regexp_matches(pg_get_functiondef(p.oid), 'interval ''[^'']+''', 'g'))[1] AS 改完之后的间隔
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'comments_guard';

-- 3.2 提示语换没换
SELECT (pg_get_functiondef(p.oid) LIKE '%30 秒%')  AS 还残留30秒,
       (pg_get_functiondef(p.oid) LIKE '%5 秒%')   AS 有5秒提示
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'comments_guard';


-- ============================================================
--  ⚠️ 还有两处【只是文案】，要改的话在前端：
--      js/science-tips.js  行 809  ← 小贴士里写着「30 秒内只能发 1 条」
--      （这个我另外改，不在这个脚本里）
-- ============================================================
