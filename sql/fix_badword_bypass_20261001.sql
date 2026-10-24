-- ============================================================
-- 修复：编辑评论可以绕过违禁词（2026-10-01）
-- ============================================================
-- 站长发现：先发一条正常评论，再编辑它，就能把违禁词写进去。
--
-- 原因分析：
--   harass_cleanup.sql 里建的触发器是 BEFORE INSERT OR UPDATE，
--   定义本身没问题。所以线上很可能是下面某一种情况：
--     · 触发器还是更早那版（只有 INSERT），后来那次 harass_cleanup
--       没有重新执行过
--     · 或者触发器压根没建成（当时 SQL Editor 里没跑到那一段）
--     · 另外 check_comment_bad_words() 没有 SECURITY DEFINER，
--       而 bad_words 表对 anon/authenticated 做过权限收紧，
--       如果读不到词库，函数会抛错或空转
--
-- 修法：不猜线上是什么状态，直接做两件事 ——
--   ① 把触发器重建一遍（明确 INSERT + UPDATE 都拦）
--   ② 在 update_comment 里【显式】再查一遍词库
--      这样即使触发器因为任何原因失效，编辑这条路也堵死
-- ============================================================


-- ============================================================
-- ① 词库表（确保存在，且 anon 只读得到、改不了）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.bad_words (
    word text PRIMARY KEY
);

-- 原有词库保持不动，这里只补几个跟本次事件相关的
INSERT INTO public.bad_words (word) VALUES
    ('吃屎'), ('傻逼'), ('操你妈'), ('nmsbl'), ('滚你妈')
ON CONFLICT (word) DO NOTHING;

-- anon 不需要直接读词库（检查都在函数里做）
REVOKE ALL ON public.bad_words FROM anon, authenticated;


-- ============================================================
-- ② 检查函数：加 SECURITY DEFINER，确保一定能读到词库
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_comment_bad_words()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_word text;
    v_text text;
BEGIN
    -- content 可能是 NULL（理论上不会，但防一手）
    v_text := lower(coalesce(NEW.content, ''));
    IF v_text = '' THEN
        RETURN NEW;
    END IF;

    FOR v_word IN SELECT word FROM public.bad_words LOOP
        IF v_word IS NOT NULL AND v_word <> ''
           AND position(lower(v_word) in v_text) > 0 THEN
            RAISE EXCEPTION '您的评论包含违禁词，禁止发布';
        END IF;
    END LOOP;

    RETURN NEW;
END
$fn$;


-- ============================================================
-- ③ 重建触发器：插入和更新都拦
-- ============================================================
-- OF content 表示只在 content 字段被改时触发，
-- 这样别人改 like_count 之类的不会被误拦。
DROP TRIGGER IF EXISTS trg_check_bad_words ON public.comments;
CREATE TRIGGER trg_check_bad_words
BEFORE INSERT OR UPDATE OF content ON public.comments
FOR EACH ROW EXECUTE FUNCTION public.check_comment_bad_words();


-- ============================================================
-- ④ 重建 update_comment：在函数里显式检查一遍（不依赖触发器）
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_comment(
    p_user_id    uuid,
    p_comment_id bigint,
    p_content    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_updated integer;
    v_word    text;
    v_text    text;
BEGIN
    IF p_content IS NULL OR length(trim(p_content)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '内容不能为空');
    END IF;
    IF length(p_content) > 200 THEN
        RETURN jsonb_build_object('success', false, 'message', '内容不能超过200字');
    END IF;

    -- ⚠️ 关键补丁：编辑时也要过一遍违禁词。
    --    这里显式检查，不依赖触发器 —— 触发器万一没建或版本旧，
    --    "先发正常评论再编辑"这条路就走不通了。
    v_text := lower(trim(p_content));
    FOR v_word IN SELECT word FROM public.bad_words LOOP
        IF v_word IS NOT NULL AND v_word <> ''
           AND position(lower(v_word) in v_text) > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', '您的评论包含违禁词，禁止发布');
        END IF;
    END LOOP;

    UPDATE public.comments
       SET content = trim(p_content)
     WHERE id = p_comment_id AND user_id = p_user_id;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '只能编辑自己的评论');
    END IF;
    RETURN jsonb_build_object('success', true);
END
$fn$;
REVOKE ALL ON FUNCTION public.update_comment(uuid, bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_comment(uuid, bigint, text) TO anon;


-- ============================================================
-- ⑤ 顺手：把已有的违规评论扫出来（只查不删）
-- ============================================================
SELECT c.id, left(c.content, 50) AS 内容预览, c.created_at
  FROM public.comments c
 WHERE EXISTS (
     SELECT 1 FROM public.bad_words w
      WHERE position(lower(w.word) in lower(c.content)) > 0
 )
 ORDER BY c.created_at DESC
 LIMIT 50;


-- ============================================================
-- 验收
-- ============================================================
-- 应该看到触发器的定义里包含 UPDATE
SELECT tgname AS 触发器名,
       CASE WHEN tgtype & 4 > 0 THEN 'INSERT ✅' ELSE 'INSERT ❌' END AS 拦插入,
       CASE WHEN tgtype & 16 > 0 THEN 'UPDATE ✅' ELSE 'UPDATE ❌' END AS 拦更新,
       pg_get_triggerdef(oid) AS 完整定义
  FROM pg_trigger
 WHERE tgrelid = 'public.comments'::regclass
   AND NOT tgisinternal;

-- 确认两个函数都是 SECURITY DEFINER
SELECT proname AS 函数, prosecdef AS 是SECURITY_DEFINER
  FROM pg_proc
 WHERE proname IN ('check_comment_bad_words', 'update_comment')
   AND pronamespace = 'public'::regnamespace;
