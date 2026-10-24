-- ============================================================
--  收尾：把用户名白名单的【报错文案】也改过来
--
--  上一版放宽了字符集，但函数里的提示还是旧的：
--      '用户名只能包含中文、字母和数字'
--  现在符号也允许了，这句会误导玩家 ——
--  有人用「小明☆」注册失败时，看到「只能包含中文、字母和数字」
--  会以为符号都不行，其实只是某个字符不在白名单里。
--
--  前端（Beta/login-Beta.html 等 16 个文件）已经改成
--      '用户名只能包含中文、字母、数字和常用符号'
--  这里把服务端也统一。
--
--  只替换报错文案，字符集、变量名、逻辑一律不动。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现在有几处旧文案
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    (length(pg_get_functiondef(p.oid))
     - length(replace(pg_get_functiondef(p.oid),
                      '用户名只能包含中文、字母和数字', '')))
      / length('用户名只能包含中文、字母和数字') AS 旧文案处数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND pg_get_functiondef(p.oid) LIKE '%用户名只能包含中文、字母和数字%'
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：替换文案
-- ============================================================
DO $$
DECLARE
    r record;
    v_src text;
    v_new text;
    v_cnt int := 0;
    v_fix int := 0;
    v_old CONSTANT text := '用户名只能包含中文、字母和数字';
    v_new_msg CONSTANT text := '用户名只能包含中文、字母、数字和常用符号';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname, pg_get_functiondef(p.oid) AS src
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND position(v_old in pg_get_functiondef(p.oid)) > 0
         ORDER BY p.proname
    LOOP
        v_src := r.src;
        v_new := replace(v_src, v_old, v_new_msg);

        IF v_new = v_src THEN
            RAISE NOTICE '⚠️ % 没替换到', r.proname;
            CONTINUE;
        END IF;

        EXECUTE v_new;
        v_cnt := v_cnt + 1;
        RAISE NOTICE '✅ % 的提示文案已更新', r.proname;
    END LOOP;

    RAISE NOTICE '---- 共改了 % 个函数 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================

-- 2.1 旧文案应该一处都不剩
SELECT
    count(*) AS 还带旧文案的函数数,
    CASE WHEN count(*) = 0 THEN '✅ 全改完'
         ELSE '❌ 还有：' || string_agg(p.proname, ', ') END AS 结论
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND pg_get_functiondef(p.oid) LIKE '%用户名只能包含中文、字母和数字%';

-- 2.2 新文案和字符集都在
SELECT
    p.proname                                 AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%字母、数字和常用符号%'
         THEN '✅ 新文案' ELSE '❌ 旧文案' END  AS 提示文案,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '❌ 未放宽' END  AS 字符集
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND (p.proname LIKE '%register\_user%' OR p.proname LIKE '%update\_username%')
   AND position('!~' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;

-- 期望：两行都是「✅ 新文案 + ✅ 已放宽」


-- ============================================================
-- 第 3 步：自测（可选）
-- ============================================================
-- 去登录页试注册一个【非法】的名字，比如带空格或 @ 的：
--      'a b'     → 应该提示「用户名只能包含中文、字母、数字和常用符号」
--      'a@b'     → 同上
-- 再试一个【合法】的带符号名字：
--      'NB-搞事局'  → 应该能注册
--      '★小明★'    → 应该能注册
-- ============================================================
