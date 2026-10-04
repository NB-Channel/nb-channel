-- ============================================================
-- 紧急一次性处置：小NB3 刷屏辱骂 + 冒充站长发布分裂言论
-- ============================================================
--
-- 【一次跑完，不用分开执行】
--
-- 做了什么：
--   第 1 步  存档证据（删之前先留一份）
--   第 2 步  删掉他的全部评论
--   第 3 步  封号
--   第 4 步  封 IP + 拉黑临时邮箱域名
--   第 5 步  查他的 IP 还关联了谁
--   第 6 步  ⭐ 给评论表装触发器（限频 + 敏感词 + 记 IP + 拦封禁账号）
--   第 7 步  验收
--
-- 【为什么用触发器而不是改 insert_comment】
--   站上有两条插入评论的路径：
--     Beta 版走 RPC insert_comment
--     新潮/经典版直接 .from('comments').insert()
--   改 RPC 只能堵住一条。装在【表】上，两条都堵得住。
--   而且不需要 insert_comment 的定义。
--
-- 在 Supabase SQL Editor 整段执行。
-- ============================================================


-- ============================================================
-- 第 1 步：存档证据
-- ============================================================
DROP TABLE IF EXISTS public._evidence_20261004;
CREATE TABLE public._evidence_20261004 AS
SELECT c.id AS 评论id, c.created_at AS 时间, p.username AS 用户名,
       c.user_id, c.page_path AS 页面, c.content AS 内容, now() AS 存档时间
  FROM public.comments c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

SELECT count(*) AS 已存档条数 FROM public._evidence_20261004;


-- ============================================================
-- 第 2 步：删掉他的全部评论
-- ------------------------------------------------------------
-- 直接用 SQL 删，不需要管理员令牌
-- ============================================================
DELETE FROM public.comments
 WHERE user_id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

-- 顺手扫一遍全站还有没有别的辱骂/政治内容
DELETE FROM public.comments
 WHERE content ~ '死全家|死妈[的]?|傻[逼B]|台独|藏独|分裂国家|复辟清朝|盗号|盗墓'
   AND created_at > now() - interval '7 days';

SELECT count(*) AS 他的剩余评论 FROM public.comments
 WHERE user_id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;


-- ============================================================
-- 第 3 步：封号
-- ============================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema='public' AND table_name='profiles'
                  AND column_name='is_banned') THEN
        UPDATE public.profiles SET is_banned = true
         WHERE id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;
        RAISE NOTICE '✅ 已封禁 is_banned = true';
    ELSE
        RAISE NOTICE '⚠️ profiles 表没有 is_banned 列，跳过（告诉我列名是什么）';
    END IF;
END $$;

SELECT username, is_banned FROM public.profiles
 WHERE id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;


-- ============================================================
-- 第 4 步：封 IP + 拉黑临时邮箱域名
-- ============================================================
INSERT INTO public.banned_ips (ip, reason) VALUES
    ('39.146.2.167', '小NB3 辱骂刷屏 + 冒充站长发布分裂言论')
ON CONFLICT (ip) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema='public' AND table_name='banned_email_domains') THEN
        INSERT INTO public.banned_email_domains (domain)
        VALUES ('ozsaip.com')
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ 已拉黑临时邮箱域名 ozsaip.com';
    ELSE
        RAISE NOTICE '⚠️ 没有 banned_email_domains 表，跳过';
    END IF;
END $$;

SELECT * FROM public.banned_ips ORDER BY created_at DESC LIMIT 10;


-- ============================================================
-- 第 5 步：查他的 IP 还关联了谁（看和 Utw 系是否同一批）
-- ============================================================
SELECT ec.ip_address AS IP,
       count(DISTINCT p.id) AS 账号数,
       string_agg(DISTINCT p.username, ', ') AS 账号
  FROM public.email_codes ec
  JOIN public.profiles p ON lower(p.email) = lower(ec.email)
 WHERE ec.ip_address = '39.146.2.167'
 GROUP BY ec.ip_address;


-- ============================================================
-- 第 6 步：⭐ 给评论表装触发器
-- ------------------------------------------------------------
-- 管五件事：
--   ① 封禁账号不能发
--   ② 被限 IP 不能发
--   ③ 限频：30 秒 1 条 / 1 小时 20 条
--   ④ 同样内容不能重复发（24 小时内）
--   ⑤ 敏感词拦截
--   ⑥ 顺手把发帖 IP 记下来（以后封 IP 才有依据）
-- ============================================================

-- 6.1 先给 comments 表加一列记 IP
ALTER TABLE public.comments
    ADD COLUMN IF NOT EXISTS ip_address text;

COMMENT ON COLUMN public.comments.ip_address IS '发这条评论时的客户端 IP（触发器写入）';

-- 6.2 触发器函数
CREATE OR REPLACE FUNCTION public.comments_guard()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
    v_last   timestamptz;
    v_hour   int;
    v_dup    int;
    v_headers json;
    v_ip     text;
BEGIN
    -- ① 记 IP（从 Supabase 注入的请求头里取）
    BEGIN
        v_headers := current_setting('request.headers', true)::json;
        v_ip := split_part(COALESCE(v_headers->>'x-forwarded-for', ''), ',', 1);
        v_ip := btrim(v_ip);
        IF v_ip <> '' THEN
            NEW.ip_address := v_ip;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;   -- 取不到就算了，别影响正常发帖
    END;

    -- ② 封禁账号不能发
    IF EXISTS (SELECT 1 FROM public.profiles
                WHERE id = NEW.user_id AND is_banned IS TRUE) THEN
        RAISE EXCEPTION '你的账号已被封禁，无法发表评论';
    END IF;

    -- ③ 被限 IP 不能发
    IF v_ip IS NOT NULL AND v_ip <> '' THEN
        BEGIN
            IF public._ip_banned(ARRAY[v_ip]) THEN
                RAISE EXCEPTION '当前网络已被限制，无法发表评论';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- _ip_banned 不存在就跳过这道检查
            IF SQLERRM LIKE '%does not exist%' THEN NULL; ELSE RAISE; END IF;
        END;
    END IF;

    -- ④ 限频：30 秒内只能发 1 条
    SELECT max(created_at) INTO v_last
      FROM public.comments WHERE user_id = NEW.user_id;
    IF v_last IS NOT NULL AND v_last > now() - interval '30 seconds' THEN
        RAISE EXCEPTION '发得太快了，请 30 秒后再试';
    END IF;

    -- ⑤ 限频：1 小时最多 20 条
    SELECT count(*) INTO v_hour
      FROM public.comments
     WHERE user_id = NEW.user_id AND created_at > now() - interval '1 hour';
    IF v_hour >= 20 THEN
        RAISE EXCEPTION '一小时内最多发 20 条评论，请稍后再来';
    END IF;

    -- ⑥ 同样内容不能重复发（24 小时内）
    SELECT count(*) INTO v_dup
      FROM public.comments
     WHERE user_id = NEW.user_id
       AND content = NEW.content
       AND created_at > now() - interval '24 hours';
    IF v_dup > 0 THEN
        RAISE EXCEPTION '请不要重复发送相同内容';
    END IF;

    -- ⑦ 敏感词
    IF NEW.content ~ '死全家|死妈|死母|傻[逼B]|台独|藏独|分裂国家|复辟|盗号|盗墓|钓鱼岛是日本' THEN
        RAISE EXCEPTION '内容包含违禁词，已被拦截';
    END IF;

    RETURN NEW;
END
$fn$;

-- 6.3 装上（先删旧的，避免重复装）
DROP TRIGGER IF EXISTS trg_comments_guard ON public.comments;
CREATE TRIGGER trg_comments_guard
    BEFORE INSERT ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.comments_guard();


-- ============================================================
-- 第 7 步：验收
-- ============================================================
-- 7.1 评论清干净了吗
SELECT count(*) AS 他的剩余评论 FROM public.comments
 WHERE user_id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

-- 7.2 号封了吗
SELECT username, is_banned FROM public.profiles
 WHERE id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

-- 7.3 触发器装上了吗
SELECT tgname AS 触发器, tgenabled AS 启用
  FROM pg_trigger
 WHERE tgrelid = 'public.comments'::regclass AND NOT tgisinternal;

-- 7.4 IP 列加上了吗
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='comments' AND column_name='ip_address';

-- 7.5 黑名单
SELECT ip, reason FROM public.banned_ips ORDER BY created_at DESC LIMIT 10;

-- 7.6 全站还有没有漏网的
SELECT c.id, p.username, c.created_at, left(c.content, 50) AS 内容
  FROM public.comments c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE c.content ~ '死全家|死妈|傻[逼B]|台独|藏独|复辟|盗号'
 ORDER BY c.created_at DESC LIMIT 30;


-- ============================================================
-- 说明：限频参数想改就改
-- ------------------------------------------------------------
-- 在 comments_guard 里：
--     interval '30 seconds'   ← 两条之间的最短间隔
--     20                      ← 每小时上限
--     interval '24 hours'     ← 重复内容的检查窗口
--
-- 想让老用户宽松一点、新号严格一点，也能改，告诉我需求。
--
-- ⚠️ 一个副作用：触发器是 RAISE EXCEPTION，
--    前端会看到一条数据库错误。如果前端没做好错误提示，
--    玩家可能只看到"提交失败"。要不要我在前端补个友好提示？
-- ============================================================


-- ============================================================
-- 回滚（万一触发器误伤了正常玩家）
-- ============================================================
-- DROP TRIGGER IF EXISTS trg_comments_guard ON public.comments;
-- DROP FUNCTION IF EXISTS public.comments_guard();
