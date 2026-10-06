-- ============================================================
--  修：评论修改能超过 10 行
--
--  【站长报的问题】
--      ① 打开评论区
--      ② 发一条正常评论
--      ③ 点修改
--      ④ 改成超过 10 行
--      ⑤ 保存 → 一条评论占满半个屏幕
--
--  【为什么能绕过】
--  前端【只在发表框上】挂了行数校验（Beta/comments-Beta.html 行 1159~1180）：
--      commentText.addEventListener('input', ...)   // 超过 10 行就截断
--      commentText.addEventListener('keydown', ...) // 第 10 行之后拦回车
--
--  而修改评论用的是【临时创建的另一个 textarea】（行 2182），
--  保存时只查了字数和空值（行 2204~2205）：
--      if (!newContent) ...                    '内容不能为空'
--      if (newContent.length > 200) ...        '内容不能超过200字'
--      ← 没有行数检查
--
--  但真正的问题在服务端：_orig_insert_comment / _orig_update_comment
--  都只校验了长度，没有行数上限：
--      IF length(p_content) > 200 THEN ... '内容不能超过200字';
--  也就是说，就算前端堵住了，直接调 REST 接口一样能塞进 100 行。
--
--  【修法】
--  ① 服务端（这个脚本）—— 给 insert 和 update 两个实现都加上行数上限。
--     这是真正的修复，前端绕不过去。
--  ② 前端（跟着一起改）—— 给修改框和回复框也挂上同样的检查，
--     让玩家当场看到提示，而不是提交完才被拒。
--
--  行数怎么算：数换行符个数。
--      0 个换行 = 1 行；9 个换行 = 10 行（允许）；10 个换行 = 11 行（拒绝）
--  用 char(10) 而不是 E'\n' —— 免得在这个 DO 块里嵌套转义。
--  这样 \n 和 \r\n 都能数到（\r\n 里的 \n 一样会被计数）。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%最多只能有 10 行%'
              OR pg_get_functiondef(p.oid) LIKE '%最多只能有10行%'
         THEN '✅ 已有行数检查' ELSE '❌ 没有行数检查' END AS 行数校验
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_insert_comment', '_orig_update_comment',
                     'insert_comment', 'update_comment')
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：给两个实现加上行数上限
-- ============================================================
DO $$
DECLARE
    r record;
    v_src text;
    v_new text;
    v_cnt int := 0;
    v_check CONSTANT text :=
        E'\\&\n\n'
     || E'    -- ⭐ 行数上限 10 行。前端只在发表框上做过限制，\n'
     || E'    --    修改评论和直接调 REST 接口都能绕过，所以这里补上服务端校验。\n'
     || E'    IF (length(p_content) - length(replace(p_content, chr(10), ''''))) >= 10 THEN\n'
     || E'        RETURN jsonb_build_object(''success'', false,\n'
     || E'            ''message'', ''评论最多只能有 10 行'');\n'
     || E'    END IF;';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('_orig_insert_comment', '_orig_update_comment')
    LOOP
        v_src := pg_get_functiondef(r.oid);

        -- 已经有了就跳过（幂等）
        IF v_src LIKE '%最多只能有 10 行%' THEN
            RAISE NOTICE '% 已经有行数检查了，跳过', r.proname;
            CONTINUE;
        END IF;

        -- 挂在「内容不能超过200字」那段检查后面
        v_new := regexp_replace(
            v_src,
            'IF\s+length\(p_content\)\s*>\s*200\s+THEN[\s\S]{0,220}?END\s+IF;',
            v_check);

        IF v_new = v_src THEN
            RAISE EXCEPTION E'% 里没找到「内容不能超过200字」那段检查，不敢硬改。\n'
                '请把下面这段源码发给我：\n%',
                r.proname,
                substring(v_src from GREATEST(position('p_content' in v_src) - 400, 1) for 1400);
        END IF;

        EXECUTE v_new;
        v_cnt := v_cnt + 1;
        RAISE NOTICE '✅ % 已加上 10 行上限', r.proname;
    END LOOP;

    RAISE NOTICE '---- 共改了 % 个函数 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%最多只能有 10 行%'
         THEN '✅ 有行数检查' ELSE '❌ 还是没有' END AS 状态,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%chr(10)%'
         THEN '✅ 用 chr(10) 数换行' ELSE '—' END  AS 实现方式
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_orig_insert_comment', '_orig_update_comment')
 ORDER BY p.proname;

-- 期望：两行都是「✅ 有行数检查」


-- ============================================================
-- 第 3 步：功能自测
-- ============================================================
-- 下面这句用假的 session 调，会先被鉴权拦下（说明壳是好的）：
--
--   SELECT public.update_comment(
--       (SELECT id FROM public.profiles LIMIT 1),
--       (SELECT id FROM public.comments LIMIT 1),
--       repeat('x', 5) || chr(10) || repeat('y', 5) || chr(10) || repeat('z', 5) || chr(10) ||
--       repeat('a', 5) || chr(10) || repeat('b', 5) || chr(10) || repeat('c', 5) || chr(10) ||
--       repeat('d', 5) || chr(10) || repeat('e', 5) || chr(10) || repeat('f', 5) || chr(10) ||
--       repeat('g', 5) || chr(10) || repeat('h', 5),
--       'fake-session'
--   );
--
-- 期望：{"success": false, "message": "登录状态已过期，请重新登录"}
--
-- ⚠️ 想单独验行数那段，得用真 session。更简单的办法是去页面上试：
--    发一条评论 → 点修改 → 粘贴 11 行 → 保存 → 应该被拒。


-- ============================================================
--  前端也要改（跟着这次提交一起上）
-- ============================================================
--  Beta/comments-Beta.html 和 comments-beta.html 两处：
--
--   ① 修改评论的保存按钮（约 2202 行）
--      现在只查了空值和 200 字，要补一条行数检查。
--
--   ② 回复框（.reply-form 里的 textarea，约 2228 行）
--      那里只挂了字数统计，没挂行数检查 —— 顺手一起补。
--
--  前端加了之后，玩家当场就能看到提示；
--  但【真正兜底的是服务端】—— 这个脚本第 1 步做的那件事。
-- ============================================================
