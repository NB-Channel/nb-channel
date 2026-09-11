-- ============================================================
-- 存储桶恢复脚本（备用，出问题时才需要跑）
-- 说明:图片传不上去的真正原因是后端 CORS 白名单里没有 X-Session,
--       浏览器预检直接拦掉了带该头的请求(已在 pythonanywhere/app.py 修好)。
--       线上 images / avatars / products 三个桶和策略经实测均正常
--       (anon key 直接上传返回 200),所以本文件平时不用跑。
-- 用途:万一将来桶或策略被误删,跑一次即可恢复(幂等,重复执行无副作用)。
-- 在 Supabase SQL Editor 执行
-- ============================================================

-- ---------- 1) 重建存储桶 ----------
INSERT INTO storage.buckets (id, name, public)
VALUES ('images',   'images',   true),    -- 评论区 / 私信 图片、视频(公开读)
       ('avatars',  'avatars',  true),    -- 头像(公开读)
       ('products', 'products', false)    -- 作品文件(私有,走后端代理下载)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- ---------- 2) 上传权限(后端用 anon key 上传) ----------
DROP POLICY IF EXISTS "images_anon_insert" ON storage.objects;
CREATE POLICY "images_anon_insert" ON storage.objects
    FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'images');

DROP POLICY IF EXISTS "avatars_anon_insert" ON storage.objects;
CREATE POLICY "avatars_anon_insert" ON storage.objects
    FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "products_anon_insert" ON storage.objects;
CREATE POLICY "products_anon_insert" ON storage.objects
    FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'products');

-- ---------- 3) 删除权限(清理图片/覆盖头像时需要) ----------
DROP POLICY IF EXISTS "images_anon_delete" ON storage.objects;
CREATE POLICY "images_anon_delete" ON storage.objects
    FOR DELETE TO anon, authenticated USING (bucket_id = 'images');

DROP POLICY IF EXISTS "avatars_anon_delete" ON storage.objects;
CREATE POLICY "avatars_anon_delete" ON storage.objects
    FOR DELETE TO anon, authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "products_anon_delete" ON storage.objects;
CREATE POLICY "products_anon_delete" ON storage.objects
    FOR DELETE TO anon, authenticated USING (bucket_id = 'products');

-- ---------- 验收 ----------
-- 1) 三个桶都在,且 public 标志正确
SELECT id AS 桶, public AS 公开读 FROM storage.buckets
 WHERE id IN ('images', 'avatars', 'products') ORDER BY id;

-- 2) 匿名可上传的策略都在(应看到 6 行)
SELECT policyname AS 策略, cmd AS 操作
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND policyname LIKE '%anon_%'
 ORDER BY policyname;
