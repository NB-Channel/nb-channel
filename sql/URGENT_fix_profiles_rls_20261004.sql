-- ============================================================
-- 🚨 紧急：修 profiles 表的 RLS 越权漏洞
-- ============================================================
--
-- 【问题】
-- profiles 表上有一条 UPDATE 策略，条件是 true（匹配所有行）：
--
--     策略名            操作     角色        条件      写入检查
--     允许更新封禁状态   UPDATE   {public}   true      true
--
-- 而 authenticated 角色拥有 profiles 【全部 15 列】的 UPDATE 权限，
-- 包括 password_hash / salt / nb_balance / is_banned / email。
--
-- 结果：任何【已登录的普通用户】都能
--     · 改掉任何人的密码（包括站长）
--     · 改掉任何人的余额
--     · 给自己解封
--     · 改掉任何人的邮箱
--
-- 另外 "允许插入 profiles" 的 with_check 也是 true —— 谁都能直接建号。
--
-- 【怎么发现的】
--   小NB3 的号被"盗"了，追查登录机制时查出来的。
--   这解释了 9 月 7 日「小NB官号」说的"我们研究出了盗号方法"。
--
-- 【修法】
--   删掉那条 qual = true 的 UPDATE 策略，只保留「只能改自己」。
--   封禁/解封走 admin_ban_user / admin_batch_ban_users（SECURITY DEFINER，
--   不受 RLS 限制），所以删掉不影响管理后台。
--
-- 【执行顺序】
--   第一步 检查现状 → 第二步 备份 → 第三步 修复 → 第四步 验收
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第一步：检查现状（只查不改）
-- ============================================================

-- 1.1 profiles 上所有策略
SELECT policyname AS 策略, cmd AS 操作, roles AS 角色,
       qual AS 读取条件, with_check AS 写入条件
  FROM pg_policies WHERE tablename = 'profiles' ORDER BY cmd, policyname;

-- 1.2 ⭐ 那个发码总闸开了没有
SELECT key, value, updated_at FROM public.admin_settings
 WHERE key ILIKE '%mail%' OR key ILIKE '%secret%'
 ORDER BY key;

-- 1.3 最近有没有人已经用过这个洞（看有没有别的号被改过密码）
--     没法直接看密码改动历史，但可以看有没有异常的封禁状态变更
SELECT id, username, is_banned, banned_reason, updated_at
  FROM public.profiles
 WHERE updated_at > now() - interval '30 days'
 ORDER BY updated_at DESC LIMIT 30;

-- 1.4 有没有人给自己解过封（被封但 is_banned 是 false 的痕迹查不到，
--     但可以看 banned_reason 有值而 is_banned 为 false 的）
SELECT id, username, is_banned, banned_reason, updated_at
  FROM public.profiles
 WHERE banned_reason IS NOT NULL AND banned_reason <> '' AND is_banned IS NOT TRUE;
-- 如果这条有结果 → 说明有人把 is_banned 改回 false 了（或者你手动解的）


-- ============================================================
-- 第二步：备份现有策略（万一要回滚）
-- ============================================================
DROP TABLE IF EXISTS public._policy_backup_profiles_20261004;
CREATE TABLE public._policy_backup_profiles_20261004 AS
SELECT policyname, cmd, roles, qual, with_check, now() AS 备份时间
  FROM pg_policies WHERE tablename = 'profiles';

SELECT * FROM public._policy_backup_profiles_20261004;


-- ============================================================
-- 第三步：修复
-- ============================================================

-- 3.1 ⭐ 删掉那条"匹配所有行"的 UPDATE 策略
--     这是最致命的一条
DROP POLICY IF EXISTS "允许更新封禁状态" ON public.profiles;
DROP POLICY IF EXISTS "允许插入 profiles" ON public.profiles;

-- 3.2 确保「只能改自己」那条在（如果名字不一样，按第一步的实际名字改）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
         WHERE tablename = 'profiles' AND cmd = 'UPDATE'
           AND qual LIKE '%auth.uid()%'
    ) THEN
        CREATE POLICY "只能改自己的 profile" ON public.profiles
            FOR UPDATE TO public
            USING (auth.uid() = id)
            WITH CHECK (auth.uid() = id);
        RAISE NOTICE '✅ 已补上「只能改自己」策略';
    ELSE
        RAISE NOTICE '✅ 「只能改自己」策略已存在';
    END IF;
END $$;

-- 3.3 ⭐ 收回 authenticated 对敏感列的写权限
--     即使策略改回宽松，列权限也拦着
REVOKE UPDATE (password_hash, salt, nb_balance, is_banned, banned_reason,
               warning_count, email, id, created_at, updated_at, username,
               equipped_title_id, ui_version, avatar_url)
    ON public.profiles FROM authenticated, anon;

-- 只留 bio 给用户自己改
GRANT UPDATE (bio, avatar_url) ON public.profiles TO authenticated;

-- 3.4 收回 authenticated 读 email 的权限
REVOKE SELECT (email, password_hash, salt) ON public.profiles FROM authenticated, anon;

-- 3.5 ⭐ 打开发码总闸（让 store_email_code 必须带密钥）
--     ⚠️ 先看第一步 1.2 的结果！
--     如果 mail_secret 是空的，先设一个随机值，并且【同步改 SCF 的配置】
--     否则邮件就发不出去了！
--
-- UPDATE public.admin_settings SET value = '1', updated_at = now()
--  WHERE key = 'mail_secret_required';

-- 3.6 收回 login_finish 的 anon 权限（登录走 login_user 就够了）
--     ⚠️ 先确认前端哪里在用 login_finish！
--     （邮箱验证码登录会用到它，如果它还留着，就别收）
--
-- REVOKE EXECUTE ON FUNCTION public.login_finish(text, text) FROM anon;


-- ============================================================
-- 第四步：验收
-- ============================================================

-- 4.1 策略列表（"允许更新封禁状态" 应该没了）
SELECT policyname AS 策略, cmd AS 操作, roles AS 角色,
       qual AS 读取条件, with_check AS 写入条件
  FROM pg_policies WHERE tablename = 'profiles' ORDER BY cmd, policyname;

-- 4.2 authenticated 现在能改哪些列（应该只剩 bio / avatar_url）
SELECT grantee, privilege_type, column_name
  FROM information_schema.column_privileges
 WHERE table_schema='public' AND table_name='profiles'
   AND grantee IN ('anon','authenticated')
   AND privilege_type IN ('UPDATE','SELECT','INSERT')
 ORDER BY grantee, privilege_type, column_name;

-- 4.3 发码总闸
SELECT key, value FROM public.admin_settings WHERE key LIKE '%mail%' OR key LIKE '%secret%';


-- ============================================================
-- ⚠️ 跑完之后必须测这几件事（坏了要立刻回滚）
-- ============================================================
-- 1. 注册新号 —— 能不能走通（注册可能依赖 INSERT profiles，如果坏了告诉我）
-- 2. 登录 —— 用户名密码登录
-- 3. 邮箱验证码登录 —— 如果前端在用
-- 4. 改昵称 / 头像 / 签名 —— 走 "只能改自己" 那条策略
-- 5. 管理后台封人 / 解封 —— 走 admin_ban_user，应该不受影响
--
-- 回滚：
--   DROP POLICY IF EXISTS "只能改自己的 profile" ON public.profiles;
--   -- 然后按 _policy_backup_profiles_20261004 重建
--   -- 列权限的回滚：GRANT ALL ON public.profiles TO authenticated, anon;
