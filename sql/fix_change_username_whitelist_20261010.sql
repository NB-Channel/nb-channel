-- ============================================================
--  补洞：change_username 没有字符白名单
--
--  【问题】
--     public.change_username(p_user_id, p_session, p_username)
--     只检查了三件事：
--         ① 会话有效        NOT public._user_ok(...)
--         ② 长度 2~16       length(v_name) < 2 OR > 16
--         ③ 有没有重名      lower(username) = lower(v_name)
--     然后直接：
--         UPDATE public.profiles SET username = v_name WHERE id = p_user_id;
--
--     ⚠️ 完全没有字符白名单 —— 登录用户可以把名字改成
--        <script>alert(1)</script>、@admin、官方 等任意字符串。
--        这是绕过用户名白名单的后门。
--
--  【谁会用到它】
--     前端只有 classic-legacy/js/legacy-shim.js 调用 rpc('change_username')。
--     但它是 SECURITY DEFINER 且 anon 可调的 RPC ——
--     任何人拿着 anon key + 自己的会话，可以直接打 REST 接口调用，
--     不经过前端。所以不管前端用不用，这个洞都得堵。
--
--  【怎么堵】
--     用和 register_user / _orig_update_username 完全一样的字符集，
--     插在 UPDATE 那一行【前面】。
--
--     为什么拿 UPDATE 那行当锚点：
--     函数里的长度判断、报错文案都可能被改过，
--     但「UPDATE public.profiles SET username = v_name」这句是它的本职，
--     最不可能变。而且即使变了，脚本也只是【跳过并打印原文】，
--     不会改错东西。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看它现在长什么样
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%!~%'
         THEN '✅ 已有白名单' ELSE '❌ 没有白名单（要补）' END AS 现状
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'                       -- 排除聚合函数（上次 42809 的教训）
   AND p.proname = 'change_username';


-- ============================================================
-- 第 1 步：补上白名单
-- ============================================================
DO $$
DECLARE
    r record;
    v_src text;
    v_new text;
    v_pat CONSTANT text :=
        '    -- 白名单：只允许中文（CJK基本区 一-龥）、字母、数字和常用符号' || E'\n'
     || '    IF v_name !~ (''^[一-龥a-zA-Z0-9_.+~!?,:;#%^*()\\[\\]='
     || '★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$'') THEN' || E'\n'
     || '        RETURN jsonb_build_object(''success'', false, '
     || '''message'', ''用户名只能包含中文、字母、数字和常用符号'');' || E'\n'
     || '    END IF;' || E'\n\n';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname, pg_get_functiondef(p.oid) AS src
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.prokind = 'f'
           AND p.proname = 'change_username'
    LOOP
        v_src := r.src;

        IF v_src LIKE '%!~%' THEN
            RAISE NOTICE '跳过：change_username 已经有白名单了';
            CONTINUE;
        END IF;

        -- 把白名单插在「UPDATE public.profiles SET username」前面
        v_new := regexp_replace(v_src,
            '(UPDATE\s+public\.profiles\s+SET\s+username)',
            v_pat || '\1');

        IF v_new = v_src THEN
            RAISE NOTICE '⚠️ 匹配不上 UPDATE 那句，没改动。请把第 0 步和第 3 步的结果发我。';
            CONTINUE;
        END IF;

        EXECUTE v_new;
        RAISE NOTICE '✅ change_username 已补上字符白名单';
    END LOOP;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%!~%'
         THEN '✅ 已有白名单' ELSE '❌ 还是没补上' END AS 状态,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 字符集一致' ELSE '⚠️ 字符集不同' END AS 字符集
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname = 'change_username';

-- 期望：状态「✅ 已有白名单」、字符集「✅ 字符集一致」


-- ============================================================
-- 第 3 步：把改完的整个函数打出来，肉眼核对
-- ============================================================
SELECT pg_get_functiondef(p.oid) AS change_username完整定义
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname = 'change_username';


-- ============================================================
-- 第 4 步：三个改名 / 注册函数应该用同一套字符集
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 新字符集' ELSE '❌ 旧字符集' END AS 字符集,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%字母、数字和常用符号%'
         THEN '✅ 新文案'
         WHEN pg_get_functiondef(p.oid) LIKE '%用户名只能包含%'
         THEN '⚠️ 旧文案' ELSE '—' END          AS 提示文案,
    pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.proname IN ('change_username', 'register_user', '_orig_update_username')
 ORDER BY p.proname;

-- 期望：三个都是「✅ 新字符集 + ✅ 新文案」


-- ============================================================
-- 第 5 步：自测（可选）
-- ============================================================
-- 登录后，在浏览器控制台打（把两个值换成自己的）：
--
--   await supabase.rpc('change_username', {
--       p_user_id: '你的uuid',
--       p_session: '你的会话令牌',
--       p_username: '<script>x</script>'
--   })
--   → 应该返回 {"success": false, "message": "用户名只能包含中文、字母、数字和常用符号"}
--
--   p_username: 'NB-搞事局'
--   → 应该返回 {"success": true, "username": "NB-搞事局"}
-- ============================================================
