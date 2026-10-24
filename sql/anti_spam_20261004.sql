-- ============================================================
-- 防刷屏操作手册
-- ============================================================
--
-- 背景：Utw 的小号扬言要用小号刷屏。
--
-- 站上现成的工具（不用新写）：
--     admin_batch_delete_comments(p_comment_ids bigint[], p_token text)   批量删评论
--     admin_batch_ban_users(p_user_ids uuid[], p_token text)              批量封号
--     admin_unban_user(p_user_id uuid, p_token text)                      解封
--     banned_ips 表                                                       IP 黑名单
--
-- 缺的东西：
--     评论【没有】服务端限频 —— 只找到举报有限频（10 分钟一次）。
--     所以他能一直发。这个要另外加（见最后一步）。
--
-- ⚠️ 每一步都先查后改。看清楚再动手。
-- ============================================================


-- ============================================================
-- 第一步：看清他在干什么（只查不改）
-- ============================================================

-- 1.1 所有 Utw 系账号
SELECT id, username, email, created_at,
       (SELECT count(*) FROM public.comments c WHERE c.user_id = p.id) AS 发过评论数,
       (SELECT max(created_at) FROM public.comments c WHERE c.user_id = p.id) AS 最后发言
  FROM public.profiles p
 WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%'
 ORDER BY 最后发言 DESC NULLS LAST;

-- 1.2 最近 24 小时所有评论（看刷屏了没有）
SELECT c.id AS 评论id, c.created_at AS 时间, p.username AS 用户名,
       c.page_path AS 页面,
       left(c.content, 60) AS 内容开头
  FROM public.comments c
  LEFT JOIN public.profiles p ON p.id = c.user_id
 WHERE c.created_at > now() - interval '24 hours'
 ORDER BY c.created_at DESC
 LIMIT 100;

-- 1.3 按人统计最近 24 小时发了多少（找出刷屏的人）
SELECT p.username, count(*) AS 条数,
       min(c.created_at) AS 最早, max(c.created_at) AS 最晚
  FROM public.comments c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE c.created_at > now() - interval '24 hours'
 GROUP BY p.username
 HAVING count(*) >= 5
 ORDER BY 条数 DESC;

-- 1.4 ⭐ 查他们的 IP（IP 记在 email_codes 里 —— 发验证码时后端记的，可信）
SELECT p.username, p.email,
       ec.ip_address AS IP,
       count(*) AS 次数,
       max(ec.created_at) AS 最近
  FROM public.profiles p
  JOIN public.email_codes ec ON lower(ec.email) = lower(p.email)
 WHERE p.username ILIKE '%utw%' OR p.username ILIKE '%3ty%'
 GROUP BY p.username, p.email, ec.ip_address
 ORDER BY 次数 DESC;

-- 1.5 这些 IP 是不是同一个人（如果几个号共用一个 IP，基本可以确定）
SELECT ec.ip_address AS IP,
       count(DISTINCT p.id) AS 关联账号数,
       string_agg(DISTINCT p.username, ', ') AS 账号
  FROM public.email_codes ec
  JOIN public.profiles p ON lower(p.email) = lower(ec.email)
 WHERE ec.ip_address IS NOT NULL
 GROUP BY ec.ip_address
 HAVING count(DISTINCT p.id) >= 2
 ORDER BY 关联账号数 DESC
 LIMIT 20;


-- ============================================================
-- 第二步：批量删评论
-- ------------------------------------------------------------
-- 先查出要删的评论 id（比如某个号在 24 小时内发的全部）
-- ============================================================
-- 2.1 把要删的 id 查出来看一眼
SELECT c.id, c.created_at, p.username, left(c.content, 50) AS 内容
  FROM public.comments c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.username = '要删的那个用户名'
   AND c.created_at > now() - interval '24 hours'
 ORDER BY c.created_at DESC;

-- 2.2 删掉（把 p_token 换成你的管理员令牌）
--     令牌在后台页面里 —— 浏览器控制台执行 localStorage.getItem('nb_session')
--     或者看后台页面请求里的 p_token 参数
--
-- SELECT public.admin_batch_delete_comments(
--     ARRAY(SELECT c.id FROM public.comments c
--             JOIN public.profiles p ON p.id = c.user_id
--            WHERE p.username = '要删的那个用户名'
--              AND c.created_at > now() - interval '24 hours'),
--     '你的管理员令牌');

-- 2.3 更狠一点：把这个号发过的【全部】评论删掉
-- SELECT public.admin_batch_delete_comments(
--     ARRAY(SELECT c.id FROM public.comments c
--             JOIN public.profiles p ON p.id = c.user_id
--            WHERE p.username ILIKE '%utw%'),
--     '你的管理员令牌');


-- ============================================================
-- 第三步：批量封号
-- ============================================================
-- 3.1 先看要封谁
SELECT id, username, is_banned
  FROM public.profiles
 WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%'
 ORDER BY username;

-- 3.2 封掉（p_token 换成你的管理员令牌）
-- SELECT public.admin_batch_ban_users(
--     ARRAY(SELECT id FROM public.profiles
--            WHERE username ILIKE '%utw%' OR username ILIKE '%3ty%'),
--     '你的管理员令牌');

-- 3.3 只封某一个
-- SELECT public.admin_ban_user('用户uuid'::uuid, '刷屏', '你的管理员令牌');

-- 3.4 解封（封错了用）
-- SELECT public.admin_unban_user('用户uuid'::uuid, '你的管理员令牌');


-- ============================================================
-- 第四步：IP 封禁（**最有效**）
-- ------------------------------------------------------------
-- 封号他还能注册新号，封 IP 才是根治。
-- 而且 email_codes 里的 IP 是【后端】记的，前端伪造不了。
-- ============================================================
-- 4.1 先看这些 IP 现在封了没
SELECT b.ip, b.reason, b.created_at AS 封禁时间
  FROM public.banned_ips b
 ORDER BY b.created_at DESC LIMIT 30;

-- 4.2 封 IP
-- INSERT INTO public.banned_ips (ip, reason) VALUES
--     ('1.2.3.4',   'Utw 系账号刷屏'),
--     ('5.6.7.8',   'Utw 系账号刷屏')
-- ON CONFLICT (ip) DO NOTHING;

-- 4.3 ⚠️ IPv6 要封 /64 段（一个 IPv6 地址能变出无数个）
--     格式：前四段 + '::/64'
--     比如 2409:8a00:1234:5678:abcd:ef01:2345:6789
--     要封成 2409:8a00:1234:5678::/64
--
-- INSERT INTO public.banned_ips (ip, reason) VALUES
--     ('2409:8a00:1234:5678::/64', 'Utw 系账号刷屏')
-- ON CONFLICT (ip) DO NOTHING;

-- 4.4 某人的 IP 是动态的（重启路由器就换）怎么办
--     → 那就得靠限频 + 封号，IP 封禁只能挡住一部分

-- 4.5 解封
-- DELETE FROM public.banned_ips WHERE ip = '1.2.3.4';


-- ============================================================
-- 第五步：加评论限频（**需要先拿到 insert_comment 的定义**）
-- ------------------------------------------------------------
-- 现在评论【没有】频率限制，这是他敢扬言刷屏的底气。
--
-- 修法：在 insert_comment 里加两道闸
--     ① 同一账号：30 秒内最多发 1 条
--     ② 同一账号：1 小时内最多发 20 条
--     ③ 同一账号：同一条内容不能重复发（防复制粘贴刷屏）
--
-- ⚠️ insert_comment 是线上才有的函数，仓库里没有。
--    先把它导出来：
--
--     SELECT p.proname AS 函数, pg_get_functiondef(p.oid) AS 定义
--       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--      WHERE n.nspname = 'public'
--        AND p.proname IN ('insert_comment', 'insert_comment_v2')
--      ORDER BY p.proname;
--
--    把定义发我，我把限频那段加进去给你。


-- ============================================================
-- 建议的处理顺序（针对这次威胁）
-- ============================================================
-- 1. 跑第一步的 1.1 ~ 1.5，看清他有几个号、发了多少、IP 是什么
-- 2. 如果已经在刷 → 立刻删评论（第二步）+ 封号（第三步）
-- 3. 封 IP（第四步）—— 让他注册新号也进不来
-- 4. 加评论限频（第五步）—— 根治，但需要 insert_comment 的定义
--
-- ⚠️ 提醒：他现在只是"扬言"，还没真刷。
--    可以先准备好脚本，等真刷了立刻执行 —— 别提前封，免得被说"没证据就封人"。
