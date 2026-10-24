-- ============================================================
--  🔧 紧急修复：恢复 Storage 上传（我上一版删策略删过头了）
--
--  【怎么坏的】
--  上一版 URGENT_fix_storage_and_internal 里，我删掉了这几条策略：
--
--      avatars_anon_insert    INSERT  {anon,authenticated}
--      images_anon_insert     INSERT  {anon,authenticated}
--      avatars_anon_delete    DELETE  {anon,authenticated}
--      images_anon_delete     DELETE  {anon,authenticated}
--      products_anon_delete   DELETE  {anon,authenticated}
--      allow_all_*            INSERT/UPDATE/DELETE/SELECT {authenticated}
--
--  但后端（pythonanywhere/app.py）是【用 anon key】操作 Storage 的：
--
--      行 46   SUPABASE_ANON_KEY = 'sb_publishable_...'
--      行 160  supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
--      行 601  supabase.storage.from_('images').upload(...)      ← 评论/反馈图片
--      行 486  supabase.storage.from_('avatars').upload(...)     ← 头像
--      行 544  supabase.storage.from_('avatars').upload(...)     ← 个人主页横幅
--      行 427  supabase.storage.from_('products').upload(...)    ← 作品文件
--
--  删掉策略之后，anon 身份就没有 INSERT 权限了 → RLS 拒绝 → 403：
--      new row violates row-level security policy
--
--  【为什么之前只坏了图片、作品还好的】
--  因为我把 products_anon_insert 留下了（只删了 products_anon_delete）。
--
--  【这个脚本做什么】
--  把三个桶的 INSERT / UPDATE / DELETE 策略恢复回去，
--  但【加了 bucket_id 限制】—— 比原来更严谨一点：
--      原来 allow_all_* 那四条是 {authenticated} 且不限定桶
--      （不过因为本站是自建登录态，Supabase 看到的一律是 anon，
--        所以那四条实际上从来没生效过，删掉无影响）
--
--  ⚠️ 必须写 TO anon, authenticated —— 只写 authenticated 不管用。
--     因为本站用的是自建登录态（不是 Supabase Auth），
--     请求带的是 anon key，Supabase 一律按 anon 角色处理。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现在有哪些策略
-- ============================================================
SELECT policyname, cmd, roles, qual, with_check
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
 ORDER BY cmd, policyname;


-- ============================================================
-- 第 1 步：恢复三个桶的读写策略
-- ============================================================
DO $$
DECLARE
    v_bucket text;
    v_buckets text[] := ARRAY['avatars', 'images', 'products'];
BEGIN
    FOREACH v_bucket IN ARRAY v_buckets LOOP

        -- INSERT：上传
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON storage.objects',
            v_bucket || '_nb_insert');
        EXECUTE format(
            'CREATE POLICY %I ON storage.objects FOR INSERT TO anon, authenticated '
            'WITH CHECK (bucket_id = %L)',
            v_bucket || '_nb_insert', v_bucket);

        -- UPDATE：覆盖（Supabase 存储 upsert 时会走 UPDATE）
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON storage.objects',
            v_bucket || '_nb_update');
        EXECUTE format(
            'CREATE POLICY %I ON storage.objects FOR UPDATE TO anon, authenticated '
            'USING (bucket_id = %L) WITH CHECK (bucket_id = %L)',
            v_bucket || '_nb_update', v_bucket, v_bucket);

        -- DELETE：换头像 / 换横幅时清掉旧文件
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON storage.objects',
            v_bucket || '_nb_delete');
        EXECUTE format(
            'CREATE POLICY %I ON storage.objects FOR DELETE TO anon, authenticated '
            'USING (bucket_id = %L)',
            v_bucket || '_nb_delete', v_bucket);

        -- SELECT：products 是私有桶，下载走 /files 代理，但列文件也要能读
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON storage.objects',
            v_bucket || '_nb_select');
        EXECUTE format(
            'CREATE POLICY %I ON storage.objects FOR SELECT TO anon, authenticated '
            'USING (bucket_id = %L)',
            v_bucket || '_nb_select', v_bucket);

        RAISE NOTICE '已恢复 % 桶的 INSERT/UPDATE/DELETE/SELECT 策略', v_bucket;
    END LOOP;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================
SELECT
    split_part(policyname, '_nb_', 1)              AS 桶,
    string_agg(cmd, ' / ' ORDER BY cmd)            AS 操作,
    string_agg(DISTINCT array_to_string(roles, ','), ' ') AS 角色
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND policyname LIKE '%\_nb\_%'
 GROUP BY 1
 ORDER BY 1;

-- 期望：avatars / images / products 各一行，
--       操作是 DELETE / INSERT / SELECT / UPDATE，角色是 anon,authenticated


-- ============================================================
-- 第 3 步：功能自测（跑完去页面上试）
-- ============================================================
--  ① 评论区 → 点上传图片 → 随便选一张   应该成功
--  ② 漏洞反馈 → 附件 → 添加图片          应该成功
--  ③ 个人中心 → 换头像                   应该成功
--  ④ 我的产品 → 上传作品                  应该成功
--
--  四个都试一遍。有失败的发我报错。


-- ============================================================
--  ⚠️ 必须知道的一件事：这个修法没有真正解决问题
-- ============================================================
--
--  现在的局面是：
--      · 后端用 anon key 传文件
--      · anon key 是【公开的】（就写在前端 JS 里，任何人都能拿到）
--      · Supabase 分不出「这个请求是后端发的」还是「浏览器伪造的」
--      · 所以：只要让后端能传，就等于让任何人都能传
--
--  这意味着恢复策略之后：
--      ✅ 上传正常了
--      ❌ 但任何人拿 anon key 就能删掉全站任何一张图片、任何一个作品文件
--         （这正是我上一版想修的那个问题，现在又回来了）
--
--  【真正的修法：让后端改用 service_role key】
--      service_role 绕过 RLS，所以可以：
--          · 后端的增删改查随便做
--          · anon 只保留 SELECT（甚至完全没有写权限）
--
--      做法（三步）：
--          ① Supabase → Settings → API → 复制 service_role key
--          ② PythonAnywhere → Web → Environment variables 里加
--                 SUPABASE_SERVICE_KEY = <粘贴>
--          ③ app.py 第 160 行改成：
--                 SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', '')
--                 supabase = create_client(SUPABASE_URL, SERVICE_KEY or SUPABASE_ANON_KEY)
--             然后 Reload
--
--      ⚠️ service_role key 【绝对不能】写进代码或仓库 ——
--         它等于数据库的万能钥匙。只放 PythonAnywhere 的环境变量里。
--
--      改完之后，这个文件里第 1 步建的那些策略就可以全删掉，
--      只留 SELECT。那时候我上一版想修的洞才算真正堵上。
--
--  【现在怎么办】
--      先用这个脚本把功能恢复（你截图里的报错先消掉），
--      等你有空做 service_role 那一步，我再写配套的收紧脚本。
-- ============================================================
