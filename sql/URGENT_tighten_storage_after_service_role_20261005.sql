-- ============================================================
--  Storage 权限收紧（⚠️ 先把后端切到 service_role 再跑这个）
--
--  【什么时候跑】
--  只有做完下面两步之后才跑，否则上传/删除会全部失败：
--
--      ① Supabase → Settings → API → 复制 service_role key
--      ② PythonAnywhere → Web → Environment variables 加
--             SUPABASE_SERVICE_KEY = <粘贴>
--         然后 Reload
--         成功的话日志里会出现：
--             [NB] Storage 客户端已切换到 service_role（绕过 RLS）
--
--  ⚠️ 如果日志里是
--         [NB] 未配置 SUPABASE_SERVICE_KEY，Storage 继续用 anon key
--     说明第 ② 步没生效 —— 这时候【不要跑这个脚本】。
--
--  【为什么现在才收紧】
--  后端一直是用 anon key 操作 Storage 的，而 anon key 是公开的
--  （就写在前端 JS 里，谁都能拿到）。Supabase 分不出
--  「这个请求是后端发的」还是「浏览器伪造的」，所以：
--      只要让后端能传，就等于让任何人都能传、也能删。
--
--  后端切到 service_role 之后，这个前提就没了：
--      · 后端绕过 RLS，增删改查随便做
--      · anon 就可以一个写权限都不给
--
--  【这个脚本做什么】
--  把 avatars / images / products 三个桶上 anon 和 authenticated 的
--  INSERT / UPDATE / DELETE 全部收掉，只留 SELECT。
--
--  跑完之后：
--      ✅ 普通人拿 anon key 不能往桶里传东西
--      ✅ 不能删、不能覆盖任何文件
--      ✅ 后端的传/删照常（它走 service_role）
--      ✅ 文件的公开读取照常（这几个桶是 public 的）
--
--  用法：确认第 ①② 步都做好、后端 Reload 过了，再整段复制执行。
-- ============================================================


-- ============================================================
-- 第 0 步：先确认后端真的切过去了
-- ============================================================
-- 打开 PythonAnywhere 的日志（Web → Log files → error log 或 server log），
-- 搜 "[NB] Storage 客户端"：
--     看到「已切换到 service_role」→ 继续往下跑
--     看到「继续用 anon key」      → 停，第 ② 步没生效
--
-- 顺便看一眼现在的策略：
SELECT split_part(policyname, '_nb_', 1)                AS 桶,
       string_agg(cmd, ' / ' ORDER BY cmd)              AS 操作,
       string_agg(DISTINCT array_to_string(roles, ','), ' ') AS 角色
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND policyname LIKE '%\_nb\_%'
 GROUP BY 1
 ORDER BY 1;


-- ============================================================
-- 第 1 步：收掉写权限，只留 SELECT
-- ============================================================
DO $$
DECLARE
    v_bucket text;
    v_cmd text;
    v_buckets text[] := ARRAY['avatars', 'images', 'products'];
    v_cmds text[] := ARRAY['INSERT', 'UPDATE', 'DELETE'];
    v_cnt int := 0;
BEGIN
    FOREACH v_bucket IN ARRAY v_buckets LOOP
        FOREACH v_cmd IN ARRAY v_cmds LOOP
            EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects',
                           v_bucket || '_nb_' || lower(v_cmd));
            v_cnt := v_cnt + 1;
            RAISE NOTICE '已删除策略: %_nb_%', v_bucket, lower(v_cmd);
        END LOOP;
    END LOOP;
    RAISE NOTICE '---- 共删除 % 条写权限策略 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    split_part(policyname, '_nb_', 1)                AS 桶,
    string_agg(cmd, ' / ' ORDER BY cmd)              AS 剩余操作,
    CASE WHEN string_agg(cmd, '') LIKE '%INSERT%'
              OR string_agg(cmd, '') LIKE '%DELETE%'
              OR string_agg(cmd, '') LIKE '%UPDATE%'
         THEN '❌ 还有写权限' ELSE '✅ 只读' END       AS 结论
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND policyname LIKE '%\_nb\_%'
 GROUP BY 1
 ORDER BY 1;

-- 期望：三个桶都只剩 SELECT，结论都是「✅ 只读」

-- 2.2 全库再扫一遍：storage.objects 上还有没有别的写策略
SELECT policyname, cmd, roles, qual
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
 ORDER BY cmd, policyname;

-- 期望：空。如果还有别的策略，说明不是我这个脚本建的 ——
--       发我看，别自己删。


-- ============================================================
-- 第 3 步：功能自测（收紧之后）
-- ============================================================
--  ① 评论区 → 上传图片        应该还是成功的（走 service_role）
--  ② 漏洞反馈 → 添加图片       应该还是成功的
--  ③ 个人中心 → 换头像 / 换横幅 应该还是成功的（含删旧文件）
--  ④ 我的产品 → 上传 / 删除作品 应该还是成功的
--
--  有一条失败就说明 service_role 那步没弄好，
--  跑回滚（见下）再检查。


-- ============================================================
--  出问题怎么回滚
-- ============================================================
--  和 URGENT_restore_storage_policies_20261005.sql 一样，
--  再跑一遍那个文件就能把写权限恢复回去。
--
--  ⚠️ 那个文件会把 INSERT/UPDATE/DELETE/SELECT 四条都重建，
--     所以回滚之后写权限是全开的（等于回到「任何人能删全站文件」的状态）。
--     回滚只是为了让功能先能用，之后还是要找时间把 service_role 配好。


-- ============================================================
--  备注：更彻底的做法
-- ============================================================
--  上面这套（后端 service_role + anon 只读）已经能挡住
--  「任何人拿 anon key 删全站文件」。
--
--  想更严的话还有一个方向：把 products 桶也改成 public = false，
--  下载全部走 /files/<key> 那个带签名直链的代理（后端已经在做了）。
--  那样连「知道文件名就能直接下载」都挡掉。
--  这个要动 storage.buckets，风险稍大，等你说了再弄。
-- ============================================================
