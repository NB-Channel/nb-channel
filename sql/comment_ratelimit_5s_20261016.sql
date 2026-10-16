-- ============================================================
--  评论限频：只留「5 秒 1 条」
--     去掉 ①「1 小时最多 20 条」
--     去掉 ②「同样内容 24 小时内不能重复发」
--
--  站长要：「把评论区的发评论频率限制从30秒改成5秒」
--          「不要加1小时的限制，就加5秒的即可」
--          「24小时的限制也去掉」
--
--  【改哪儿】
--      public.comments_guard —— 它是个【触发器函数】，
--      挂在 public.comments 的 BEFORE INSERT 上（触发器名 trg_comments_guard）。
--
--        ④ 限频：30 秒内只能发 1 条          → 改成 5 秒
--        ⑤ 限频：1 小时最多 20 条            → 取消
--        ⑥ 同样内容 24 小时内不能重复发        → 取消
--        ⑦ 敏感词拦截                        → 保留
--
--  【怎么取消一整条】
--      把条件改成 IF false THEN。不删整段，因为整段要精确匹配多行
--      （含缩进和换行），而函数定义是从 pg_get_functiondef() 取的，
--      空白不一定和仓库里那份一样 —— 匹配失败会【静默什么都不做】。
--      改条件那一行是精确匹配，改不上一眼能看出来。
--
--  ⚠️ 上一版这里有个 bug：用 v_hit := v_hit || '字符串' 往 text[] 里加元素，
--     PostgreSQL 会把右边的字符串当成【数组字面量】，报
--        22P02: malformed array literal
--     现在改成 array_append(v_hit, '字符串')。
--
--  幂等。用法：整段复制到 Supabase → SQL Editor → Run
-- ============================================================


-- ============================================================
-- 第 1 步：改之前先看现状
-- ============================================================
SELECT (regexp_matches(pg_get_functiondef(p.oid), 'interval ''[^'']+''', 'g'))[1] AS 现在的间隔,
       (pg_get_functiondef(p.oid) LIKE '%v_hour >= 20%')  AS 有1小时上限,
       (pg_get_functiondef(p.oid) LIKE '%v_dup > 0%')     AS 有24小时重复检查
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
        v_hit := ARRAY[]::text[];

        -- ④ 30 秒 → 5 秒
        v_n := (length(v_new) - length(replace(v_new, 'interval ''30 seconds''', '')))
               / length('interval ''30 seconds''');
        IF v_n > 0 THEN
            v_new := replace(v_new, 'interval ''30 seconds''', 'interval ''5 seconds''');
            -- ⚠️ 必须用 array_append，不能用 || 拼字符串（会当成数组字面量报 22P02）
            v_hit := array_append(v_hit, '间隔 30→5 秒（' || v_n || ' 处）');
        END IF;

        -- ④ 提示语里的「30 秒」也要换
        IF position('30 秒' in v_new) > 0 OR position('30秒' in v_new) > 0 THEN
            v_new := replace(v_new, '请 30 秒后再试', '请 5 秒后再试');
            v_new := replace(v_new, '30 秒后再试',   '5 秒后再试');
            v_new := replace(v_new, '请30秒后再试',  '请5秒后再试');
            v_new := replace(v_new, '30秒后再试',    '5秒后再试');
            v_hit := array_append(v_hit, '提示语 30 秒→5 秒');
        END IF;

        -- ⑤ 去掉 1 小时 20 条
        IF position('v_hour >= 20' in v_new) > 0 THEN
            v_new := replace(v_new, 'v_hour >= 20', 'false');
            v_hit := array_append(v_hit, '1 小时上限已停用');
        END IF;

        -- ⑥ 去掉 24 小时重复内容检查
        IF position('v_dup > 0' in v_new) > 0 THEN
            v_new := replace(v_new, 'v_dup > 0', 'false');
            v_hit := array_append(v_hit, '24 小时重复检查已停用');
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
-- 3.1 期望：
--       现在的间隔        = 5 seconds
--       还有1小时上限      = false
--       还有24小时重复检查  = false
--       提示语是5秒        = true
SELECT (regexp_matches(pg_get_functiondef(p.oid), 'interval ''[^'']+''', 'g'))[1] AS 现在的间隔,
       (pg_get_functiondef(p.oid) LIKE '%v_hour >= 20%')   AS 还有1小时上限,
       (pg_get_functiondef(p.oid) LIKE '%v_dup > 0%')      AS 还有24小时重复检查,
       (pg_get_functiondef(p.oid) LIKE '%请 5 秒后再试%')   AS 提示语是5秒,
       (pg_get_functiondef(p.oid) LIKE '%违禁词%')          AS 敏感词还在
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'comments_guard';

-- 3.2 触发器还在不在（改函数不该动触发器）
SELECT tgname AS 触发器, tgenabled AS 启用
  FROM pg_trigger
 WHERE tgrelid = 'public.comments'::regclass AND NOT tgisinternal;


-- ============================================================
--  跑完之后
-- ============================================================
--  现在发评论只剩两道约束：
--      · 两条之间至少隔 5 秒
--      · 不能含敏感词
--
--  ⚠️ 也就是说：同一句话可以连发、一小时内发多少条都行。
--     如果以后被人刷屏，回来把 v_dup > 0 或 v_hour >= 20 改回去就行，
--     这两句 SELECT 都还在函数里，只是条件恒假。
--
--  ⚠️ 前端小贴士（js/science-tips.js）已经同步改成「5 秒内只能发 1 条」。
-- ============================================================
