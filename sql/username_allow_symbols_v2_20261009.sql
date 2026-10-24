-- ============================================================
--  用户名放宽（修正版）—— 按内容找函数，不再按名字找
--
--  【上一版为什么失败】
--  我按函数名找了 register_user 和 update_username，
--  但库里 update_username 是个【鉴权壳】：
--
--      CREATE FUNCTION update_username(..., p_session text DEFAULT NULL)
--      AS $function$
--      BEGIN
--          IF p_session IS NULL OR NOT public._user_ok(user_id, p_session) THEN
--              RETURN ...'鉴权失败...';
--          END IF;
--          RETURN public._orig_update_username(user_id, new_username, old_password);
--      END
--      $function$
--
--  壳里没有白名单逻辑，真正的实现在 _orig_update_username。
--  所以匹配不上就 RAISE EXCEPTION 了 —— 而且 DO 块是原子的，
--  报错把 register_user 那部分也一起回滚了，等于两个都没改。
--
--  （这是第三次栽在同一件事上：拿函数名当锚点。前两次是银行函数和
--    update_support_rule，都是同一类问题。以后一律按内容找。）
--
--  【这一版怎么改】
--  不再按名字找，改成按【函数体里有没有白名单逻辑】找：
--      函数体里有 !~ 的才处理
--  这样壳会被自动跳过，实体（不管叫 _orig_ 还是别的）都能找到。
--
--  而且一个匹配不上【只跳过它自己】，不会中断整批。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看清有哪些候选、各自什么情况
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    length(pg_get_functiondef(p.oid))             AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%!~%'
         THEN '有白名单' ELSE '（壳，无白名单）' END AS 类型,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '❌ 还是旧的' END     AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname LIKE '%register\_user%'
     OR p.proname LIKE '%update\_username%'
     OR p.proname LIKE '%register\_finish%')
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：把【函数体里有白名单】的那几个都放宽
-- ============================================================
DO $$
DECLARE
    r record;
    v_src text;
    v_new text;
    v_ok  int := 0;
    v_skip text := '';
    -- 新白名单的字符集部分。[] 里的转义点：
    --   [ 和 ] 在正则字符类里要转义；这里写 \\[ \\] 是因为
    --   regexp_replace 的【替换串】里 \\ 代表一个字面反斜杠。
    --   末尾那个 - 放最后，就是字面减号（放中间会被当区间）
    --
    -- ⚠️ 替换串用 \1 把【原来的变量名】接回来 ——
    --    不能写死 clean_name：万一实体函数里变量叫别的名字，
    --    写死就会把变量名也换掉，函数直接跑不起来。
    v_pat CONSTANT text :=
        '\1(''^[一-龥a-zA-Z0-9_.+~!?,:;#%^*()\\[\\]='
     || '★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$'') THEN';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS ident,
               pg_get_functiondef(p.oid) AS src
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND (p.proname LIKE '%register\_user%'
             OR p.proname LIKE '%update\_username%')
           -- ⭐ 关键：只处理函数体里真的有白名单的（壳会被自动排除）
           AND position('!~' in pg_get_functiondef(p.oid)) > 0
         ORDER BY p.proname
    LOOP
        v_src := r.src;

        IF v_src LIKE '%★%' THEN
            RAISE NOTICE '跳过 %（已经放宽过了）', r.proname;
            CONTINUE;
        END IF;

        -- 把「IF 变量名 !~ (...一串...) THEN」整体换掉，
        -- 用 \1 保留「IF 变量名 !~ 」这一段（变量名原样不动）
        v_new := regexp_replace(v_src,
            '(IF\s+\w+\s*!~\s*)[\s\S]{0,200}?THEN',
            v_pat);

        IF v_new = v_src THEN
            v_skip := v_skip || r.proname || '(' || r.ident || ') ';
            RAISE NOTICE '⚠️ % 匹配不上，跳过（不影响其它函数）', r.proname;
            CONTINUE;
        END IF;

        EXECUTE v_new;
        v_ok := v_ok + 1;
        RAISE NOTICE '✅ % 已放宽', r.proname;
    END LOOP;

    RAISE NOTICE '---- 成功 % 个 ----', v_ok;
    IF v_skip <> '' THEN
        RAISE NOTICE '⚠️ 下面这些匹配不上，请把第 0 步的结果发我：%', v_skip;
    END IF;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '（不用改）' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname LIKE '%register\_user%' OR p.proname LIKE '%update\_username%')
   AND position('!~' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;

-- 期望：凡是「有白名单」的函数，状态都是「✅ 已放宽」


-- ============================================================
-- 第 3 步：把放宽后的那一句原样打出来
-- ============================================================
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('!~' in pg_get_functiondef(p.oid)) - 60, 1)
              for 300) AS 白名单那句
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname LIKE '%register\_user%' OR p.proname LIKE '%update\_username%')
   AND position('!~' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;


-- ============================================================
--  如果第 1 步报「匹配不上」
-- ============================================================
--  把第 0 步和第 3 步的结果发我。第 3 步会把实际那一句打出来，
--  我照着它改锚点 —— 不再靠猜。
--
--  ⚠️ 注意：注册路径走的是 register_finish → register_user，
--     所以真正要放宽的是 register_user（如果它是实体不是壳）
--     以及 _orig_update_username。
-- ============================================================
