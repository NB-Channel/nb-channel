-- ============================================================
--  第二批：把剩下那 4 条写策略也收掉
--
--  【为什么还有第二批】
--  上一个脚本 URGENT_tighten_storage_after_service_role_20261005.sql 只删了
--  它自己那套命名（*_nb_insert / *_nb_update / *_nb_delete）。
--  跑完之后站长按脚本里第 2.2 步复查，发现还有 4 条【别的来源】的写策略：
--
--      allow_upload            INSERT  {authenticated}        ← 面板上点的？
--      products_anon_insert    INSERT  {anon,authenticated}   ← storage_setup.sql
--      avatars_anon_update     UPDATE  {anon,authenticated}   ← 面板上点的？
--      products_anon_update    UPDATE  {anon,authenticated}   ← 面板上点的？
--
--  他没自己删、发来问我 —— 对的。不是自己建的东西不要随手 DROP。
--
--  【为什么现在可以删】
--  已经确认过两件事：
--      ① 后端 04:27:26 的日志出现
--             [NB] Storage 客户端已切换到 service_role（绕过 RLS）
--         service_role 绕过 RLS，不需要任何策略
--      ② 前端【没有】直接往 Storage 传文件的地方 ——
--         全站搜 .storage.from(...).upload( 一处都没有；
--         那几处 /storage/v1/object/public/... 都是【读】公开链接。
--         所有上传都走后端接口：
--             /upload-avatar  /upload-banner  /upload-image  /upload-video
--
--  所以：storage.objects 上一个写策略都不需要留。
--        公开读（public 桶）不受影响，策略删的是写。
--
--  ⚠️ 删之前先跑第 1 步看看 with_check ——
--    上一个检查脚本只选了 qual，而 INSERT 策略的条件在 with_check 里，
--    所以那四条看着都是 null，看不出限制在哪个桶。
--    这次一起选出来。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：把现在所有写策略连 with_check 一起列出来
-- ============================================================
SELECT policyname                  AS 策略名,
       cmd                         AS 操作,
       array_to_string(roles, ',') AS 角色,
       coalesce(qual, '-')         AS using条件,
       coalesce(with_check, '-')   AS with_check条件
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
 ORDER BY cmd, policyname;

-- 跑之前应该看到那 4 条；跑完之后这个查询应该返回空。


-- ============================================================
-- 第 2 步：按名字删掉这 4 条
--
--   ⚠️ 这里【按名字逐个删】，不用通配符扫 ——
--      万一将来还有别的来源的策略，这种写法不会误伤，
--      而且会把它列在 NOTICE 里让人看见。
-- ============================================================
DO $$
DECLARE
    v_names text[] := ARRAY[
        'allow_upload',
        'products_anon_insert',
        'avatars_anon_update',
        'products_anon_update',
        -- 下面几条是早年 storage_setup.sql / fix_storage_buckets.sql 建的，
        -- 上一批可能没删干净，一并兜住（存在就删，不存在就跳过）
        'avatars_anon_insert',
        'images_anon_insert',
        'avatars_anon_delete',
        'images_anon_delete',
        'products_anon_delete',
        'products_anon_update_2'
    ];
    v_n    text;
    v_cnt  int := 0;
    v_left text;
BEGIN
    FOREACH v_n IN ARRAY v_names LOOP
        IF EXISTS (SELECT 1 FROM pg_policies
                    WHERE schemaname = 'storage' AND tablename = 'objects'
                      AND policyname = v_n) THEN
            EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', v_n);
            RAISE NOTICE '已删除: %', v_n;
            v_cnt := v_cnt + 1;
        END IF;
    END LOOP;
    RAISE NOTICE '---- 共删除 % 条 ----', v_cnt;

    -- 删完再看看还有没有漏网的写策略
    SELECT string_agg(policyname || '(' || cmd || ')', ', ')
      INTO v_left
      FROM pg_policies
     WHERE schemaname = 'storage' AND tablename = 'objects'
       AND cmd IN ('INSERT', 'UPDATE', 'DELETE');

    IF v_left IS NULL THEN
        RAISE NOTICE '✅ storage.objects 上已经没有写策略了';
    ELSE
        RAISE NOTICE '⚠️ 还剩这些写策略（不是这个脚本建的，先别动，发我看）: %', v_left;
    END IF;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
-- 3.1 还剩哪些写策略 —— 期望【空】
SELECT policyname AS 策略名, cmd AS 操作, array_to_string(roles, ',') AS 角色
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
 ORDER BY cmd, policyname;

-- 3.2 读权限还在不在 —— 期望三个桶都还有 SELECT
SELECT split_part(policyname, '_', 1) AS 桶_粗看,
       policyname                     AS 策略名,
       cmd                            AS 操作,
       array_to_string(roles, ',')    AS 角色
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND cmd = 'SELECT'
 ORDER BY policyname;

-- 3.3 桶本身还是不是 public（公开读靠这个 + SELECT 策略）
SELECT id AS 桶, public AS 是否公开
  FROM storage.buckets
 WHERE id IN ('avatars', 'images', 'products')
 ORDER BY id;


-- ============================================================
-- 第 4 步：立刻自测这四处（后端走 service_role，都该成功）
-- ============================================================
--  ① 评论区 → 上传图片
--  ② 漏洞反馈 → 添加图片
--  ③ 个人中心 → 换头像 / 换横幅（会删旧文件，最考验权限）
--  ④ 我的产品 → 上传 / 删除作品
--
--  另外随手确认【读】没坏：刷一下评论区，看历史图片还显示不显示。
--
--  有一处挂了 → 跑 URGENT_restore_storage_policies_20261005.sql 回滚，
--  然后把「哪一处 + 报错内容 + 那段时间的 error log」发我。
-- ============================================================


-- ============================================================
--  跑完之后是什么状态
-- ============================================================
--  · storage.objects 上 0 条写策略
--      → 拿公开的 anon key 一个字节也传不进去、删不掉
--      → 登录用户的 token 也一样（authenticated 也没写权限了）
--  · 后端不受影响（service_role 绕过 RLS）
--  · 公开读不受影响（bucket 是 public + SELECT 策略还在）
--
--  ⚠️ 唯一要记住的：以后【新增】任何上传功能，都必须走后端接口。
--     前端直接 sb.storage.from(...).upload(...) 会 403 ——
--     这是设计如此，不是 bug。
-- ============================================================
