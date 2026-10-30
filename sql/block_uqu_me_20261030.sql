-- ============================================================
--  小NB 又回来了：处理「uqu.me」这个临时邮箱域名
--
--  查到的情况：
--     账号  小NB新号
--     id    0e876f31-11d4-4959-a825-56e3c38ed7ba
--     邮箱  xnb@uqu.me
--     注册  2026-10-24 12:10:20 UTC
--     域名  uqu.me → MX 指向 smtp.mail.cx  ← 这就是临时邮箱（mail.cx 系）
--
--  为什么能进来：
--     站里的拦截靠 public.banned_email_domains 表（9204 个域名，
--     来自 disposable-email-domains 公开列表），store_email_code 里查这张表。
--     uqu.me 不在那个列表里 → 漏了。
--
--  这个脚本做三件事：
--     1. 查现状（只读）
--     2. 把 uqu.me 和 mail.cx 加进黑名单（幂等）
--     3. 给出处理这个账号的两种做法（默认只查，动手的语句注释掉了）
--
--  在 Supabase → SQL Editor 整段跑。
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状（只查，不改）
-- ============================================================
-- 0.1 这个账号本身
SELECT id, username, email, created_at,
       split_part(email, '@', 2) AS 邮箱域名
  FROM public.profiles
 WHERE id = '0e876f31-11d4-4959-a825-56e3c38ed7ba';

-- 0.2 这两个域名在不在黑名单里
SELECT domain, reason, created_at
  FROM public.banned_email_domains
 WHERE domain IN ('uqu.me', 'mail.cx');

-- 0.3 最近 30 天用临时邮箱域名注册的还有谁（同一家服务通常批量注册）
SELECT split_part(p.email, '@', 2) AS 域名, count(*) AS 人数,
       min(p.created_at) AS 最早, max(p.created_at) AS 最近
  FROM public.profiles p
 WHERE p.created_at > now() - interval '30 days'
   AND split_part(p.email, '@', 2) IN ('uqu.me', 'mail.cx')
 GROUP BY 1 ORDER BY 2 DESC;

-- 0.4 profiles 表有没有「封禁」这类字段（决定第 2 步用哪种做法）
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'profiles'
   AND (column_name ILIKE '%ban%' OR column_name ILIKE '%block%'
        OR column_name ILIKE '%disab%' OR column_name ILIKE '%status%');


-- ============================================================
-- 第 1 步：把这两个域名加进黑名单（幂等，可重复跑）
-- ============================================================
INSERT INTO public.banned_email_domains (domain, reason) VALUES
    ('uqu.me',  '临时邮箱（MX → smtp.mail.cx），小NB 系列使用'),
    ('mail.cx', '临时邮箱服务上游域名')
ON CONFLICT (domain) DO UPDATE SET reason = EXCLUDED.reason;

-- 验收：应该能看到两行
SELECT domain, reason FROM public.banned_email_domains
 WHERE domain IN ('uqu.me', 'mail.cx');


-- ============================================================
-- 第 2 步：处理这个账号（⚠️ 三选一，默认一个都不执行）
-- ============================================================
--
-- 做法 A：只踢下线（保留账号和评论，最小动作）
--   如果 profiles 里有 session 相关字段，清掉即可；下面这句是通用兜底：
--
-- DELETE FROM public.user_sessions WHERE user_id = '0e876f31-11d4-4959-a825-56e3c38ed7ba';
--
-- 做法 B：删号（评论会一起没，慎用；想保留证据就别用这个）
--
-- DELETE FROM public.profiles WHERE id = '0e876f31-11d4-4959-a825-56e3c38ed7ba';
--
-- 做法 C：封 IP（如果第 0 步查到这个号的注册 IP，填进去）
--
-- INSERT INTO public.banned_ips (ip, reason)
-- VALUES ('1.2.3.4', '小NB 系列注册来源IP')
-- ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;


-- ============================================================
-- 第 3 步（可选）：让他以后更难受 —— 加一道「新号观察期」
--   新注册的账号 24 小时内不能发评论。
--   ⚠️ 这会改 register_finish 或评论函数，先看清楚再动。
--   下面只是提示，不执行：
--
--   COMMENT ON TABLE public.profiles IS '新号观察期：created_at < now()-24h 才能评论';
-- ============================================================
