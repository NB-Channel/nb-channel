-- ============================================================
--  Storage 权限：先看现状，再决定跑不跑收紧脚本
--
--  背景：后端（pythonanywhere/app.py）一直用【公开的 anon key】操作 Storage。
--       anon key 就写在前端里，谁都能拿到，Supabase 分不出
--       「这是后端发的」还是「浏览器伪造的」——
--       所以只要后端能传能删，就等于任何人都能传能删。
--
--  解法（两步，顺序不能反）：
--       ① 后端换用 service_role key（它绕过 RLS，不用给 anon 任何写权限）
--       ② 再把 anon 的写权限全部收掉
--
--  ⚠️ 反过来的话，上传/换头像/删作品会立刻全挂。
--
--  用法：先跑这个文件看现状，再决定下一步。
-- ============================================================


-- ============================================================
--  第 1 步：storage.objects 上现在有哪些写策略
--
--  这是判断「洞还在不在」的唯一依据。
-- ============================================================
SELECT policyname                  AS 策略名,
       cmd                         AS 操作,
       array_to_string(roles, ',') AS 角色,
       CASE WHEN cmd IN ('INSERT','UPDATE','DELETE')
                 AND (roles && ARRAY['anon','public','authenticated']::name[])   -- ⚠️ roles 是 name[]，必须转一下
            THEN '⚠️ 洞：公开角色能写'
            ELSE '' END            AS 判断
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
 ORDER BY cmd, policyname;


-- ============================================================
--  第 2 步：按桶汇总，看哪些桶还能被公开角色写
-- ============================================================
SELECT split_part(policyname, '_nb_', 1)                          AS 桶,
       string_agg(DISTINCT cmd, ' / ' ORDER BY cmd)               AS 允许的操作,
       string_agg(DISTINCT array_to_string(roles, ','), ' ')      AS 角色,
       CASE WHEN bool_or(cmd IN ('INSERT','UPDATE','DELETE'))
                  AND bool_or(roles && ARRAY['anon','public','authenticated']::name[])
            THEN '❌ 还能被公开角色写删' ELSE '✅ 只读' END        AS 结论
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND policyname LIKE '%\_nb\_%'
 GROUP BY 1
 ORDER BY 1;

-- 期望（弄好之后）：三个桶都是「✅ 只读」
-- 如果看到「❌ 还能被公开角色写删」→ 洞还开着，按下面走


-- ============================================================
--  第 3 步：看看后端到底切没切到 service_role
--
--  这个 SQL 查不出来 —— 得看 PythonAnywhere 的日志：
--      Web → Log files → server log（或 error log）
--      搜 "[NB] Storage 客户端"
--
--      看到「已切换到 service_role（绕过 RLS）」→ 可以跑收紧脚本了
--      看到「未配置 SUPABASE_SERVICE_KEY，继续用 anon key」→ 先配环境变量
-- ============================================================


-- ============================================================
--  【接下来要做的三步 —— 前两步只能你自己在网站上点】
-- ============================================================
--
--  ① Supabase 拿 service_role key
--       控制台 → Project Settings → API → Project API keys
--       找 service_role 那一行（标着 secret，别外传）
--       复制它
--
--       ⚠️ 这个 key 能绕过所有权限，【绝不能】写进前端、
--          不能提交进 git、不能发群里。只放后端环境变量。
--
--  ② PythonAnywhere 配环境变量
--       Web → 你的 web app → Environment variables
--       加一条：
--           SUPABASE_SERVICE_KEY = <刚复制的>
--       然后点 Reload
--
--       代码这边已经准备好了（app.py 第 53/175~180 行）：
--           有 SUPABASE_SERVICE_KEY → Storage 走 service_role
--           没有                     → 退回 anon key（旧行为，不会有副作用）
--
--  ③ 看日志确认切过去了
--       看到「[NB] Storage 客户端已切换到 service_role（绕过 RLS）」
--       才跑 URGENT_tighten_storage_after_service_role_20261005.sql
--
--       跑完立刻自测这四处（都该照常成功）：
--           · 评论区上传图片
--           · 漏洞反馈添加图片
--           · 个人中心换头像 / 换横幅（含删旧文件）
--           · 我的产品上传 / 删除作品
--
--       有一条挂了 → 跑 URGENT_restore_storage_policies_20261005.sql 回滚，
--       然后告诉我日志里那行是什么。
--
-- ============================================================
