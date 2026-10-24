-- ============================================================
-- 紧急处置：小NB3 评论区辱骂刷屏 + 冒充站长发布分裂言论
-- ============================================================
--
-- 【他做了什么】
-- 账号：小NB3   user_id: 59788e5a-290d-4f94-a6ef-8dd51f81a3d4
-- 页面：nb_comments
-- 时间：2026-10-04 02:24 ~ 05:11（约 3 小时，30+ 条）
--
-- 内容分四类：
--   ① 辱骂刷屏     「Nb频道是给他全家都死了」×4、傻B、死妈的给…
--   ② 政治造谣     「Nb频道说要给台湾、海南独立」「把钓鱼岛送给日本」
--                  「宣称复辟清朝」「藏南不属于中国」
--                  ⚠️ 冒充站长发布分裂国家言论 —— 这个最严重
--   ③ 自认盗号     「我的大号其实也是盗来的」「我打算盗取这个号」
--   ④ 索要漏洞     「把提取股份重新加出来，还有增值也重新加出来，
--                  还有原版破产」
--                  ⚠️ 这三样正是被我们修掉的造币功能 —— 就是他刷币用的
--
-- 【处置顺序】
--   第 0 步 存档证据（万一要走法律途径）
--   第 1 步 删评论（立刻，尤其是政治造谣那几条）
--   第 2 步 封号
--   第 3 步 查 IP 并封禁
--   第 4 步 加敏感词 + 限频（防复发）
--
-- 在 Supabase SQL Editor 执行。
-- ============================================================


-- ============================================================
-- 第 0 步：存档证据（先做这个，删了就没了）
-- ============================================================
DROP TABLE IF EXISTS public._evidence_xiaonb3_20261004;
CREATE TABLE public._evidence_xiaonb3_20261004 AS
SELECT c.id AS 评论id, c.created_at AS 时间, p.username AS 用户名,
       c.user_id, c.page_path AS 页面, c.content AS 内容, now() AS 存档时间
  FROM public.comments c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE p.id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

SELECT count(*) AS 已存档条数 FROM public._evidence_xiaonb3_20261004;
-- 记下这个数字，后面核对


-- ============================================================
-- 第 1 步：删掉他的全部评论
-- ------------------------------------------------------------
-- ⚠️ 需要管理员令牌。令牌获取方式：
--    浏览器打开后台页面 → F12 控制台 → localStorage.getItem('nb_session')
--    或者看后台页面网络请求里的 p_token 参数
--
-- 最省事的办法：直接用后台管理页面的「批量删除评论」功能
-- （后台页面在 https://github.nb-channel.main 或你本地的 __admin__.html）
--
-- 如果要用 SQL：
-- ============================================================
SELECT public.admin_batch_delete_comments(
    ARRAY(SELECT 评论id FROM public._evidence_xiaonb3_20261004),
    '你的管理员令牌');

-- 删完核对
SELECT count(*) AS 剩余条数 FROM public.comments
 WHERE user_id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;
-- 应该是 0


-- ============================================================
-- 第 2 步：封号
-- ============================================================
SELECT public.admin_batch_ban_users(
    ARRAY['59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid],
    '你的管理员令牌');

-- 确认
SELECT username, is_banned FROM public.profiles
 WHERE id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;


-- ============================================================
-- 第 3 步：查 IP 并封禁
-- ============================================================

-- 3.1 查他的 IP
SELECT p.username, p.email, ec.ip_address AS IP,
       count(*) AS 次数, min(ec.created_at) AS 最早, max(ec.created_at) AS 最近
  FROM public.profiles p
  LEFT JOIN public.email_codes ec ON lower(ec.email) = lower(p.email)
 WHERE p.id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid
 GROUP BY p.username, p.email, ec.ip_address
 ORDER BY 次数 DESC;

-- 3.2 这个 IP 还关联了哪些账号（**关键** —— 看他和 Utw 系是不是同一批人）
SELECT ec.ip_address AS IP,
       count(DISTINCT p.id) AS 账号数,
       string_agg(DISTINCT p.username, ', ') AS 账号
  FROM public.email_codes ec
  JOIN public.profiles p ON lower(p.email) = lower(ec.email)
 WHERE ec.ip_address IN (
       SELECT ec2.ip_address FROM public.email_codes ec2
        WHERE lower(ec2.email) = (SELECT lower(email) FROM public.profiles
                                   WHERE id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid)
 )
 GROUP BY ec.ip_address
 ORDER BY 账号数 DESC;

-- 3.3 封 IP（把上面查到的填进来）
-- INSERT INTO public.banned_ips (ip, reason) VALUES
--     ('这里填IP', '小NB3 辱骂刷屏 + 冒充站长发布分裂言论')
-- ON CONFLICT (ip) DO NOTHING;
--
-- IPv6 要封 /64 段：前四段 + '::/64'
-- 例如 2409:8a00:1234:5678:abcd:ef01:2345:6789
-- 写成 2409:8a00:1234:5678::/64

-- 3.4 确认封禁列表
SELECT ip, reason, created_at FROM public.banned_ips ORDER BY created_at DESC LIMIT 20;


-- ============================================================
-- 第 4 步：防复发
-- ------------------------------------------------------------
-- 他的 bad word 过滤显然没拦住「死全家」「傻B」这些，也没拦政治内容。
-- 两件事要做：
--   ① 扩充敏感词表
--   ② 给评论加服务端限频
-- ============================================================

-- 4.1 先看现在的敏感词表里有什么
SELECT * FROM public.bad_words ORDER BY word LIMIT 100;

-- 4.2 补充这次出现的词（先看 4.1 里有没有重复，避免主键冲突）
-- INSERT INTO public.bad_words (word) VALUES
--     ('死全家'), ('死妈'), ('死母'), ('傻B'), ('傻逼'),
--     ('盗号'), ('盗墓'), ('复辟'), ('台独'), ('藏独'),
--     ('钓鱼岛'), ('分裂国家'), ('不爱国')
-- ON CONFLICT DO NOTHING;

-- 4.3 ⭐ 评论限频（**这个必须做**）
--     现在评论没有任何服务端频率限制，所以他能在 3 小时里发 30+ 条。
--     把 insert_comment 的定义导出来发我，我加三道闸：
--        · 同账号 30 秒内最多 1 条
--        · 同账号 1 小时内最多 20 条
--        · 同样内容不能重复发
--
-- SELECT p.proname AS 函数, pg_get_functiondef(p.oid) AS 定义
--   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--  WHERE n.nspname = 'public' AND p.proname IN ('insert_comment','insert_comment_v2');


-- ============================================================
-- 第 5 步：验收
-- ============================================================
-- 5.1 评论清干净了吗
SELECT count(*) AS 他的剩余评论 FROM public.comments
 WHERE user_id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

-- 5.2 号封了吗
SELECT username, is_banned FROM public.profiles
 WHERE id = '59788e5a-290d-4f94-a6ef-8dd51f81a3d4'::uuid;

-- 5.3 全站还有没有类似的辱骂/政治内容
SELECT c.id, p.username, c.created_at, left(c.content, 60) AS 内容
  FROM public.comments c
  JOIN public.profiles p ON p.id = c.user_id
 WHERE c.content ~ '死全家|死妈|傻[逼B]|台独|藏独|分裂|盗号|复辟'
 ORDER BY c.created_at DESC LIMIT 50;
-- 如果有别的账号也在发，一起处理


-- ============================================================
-- ⚠️ 三件你要知道的事
-- ============================================================
--
-- ① 政治造谣那几条【必须优先删】
--    「Nb频道说要给台湾、海南独立」「把钓鱼岛送给日本」
--    这些是【冒充你】发布的分裂国家言论。
--    挂在公开评论区，任何人都能看到，风险极大。
--
-- ② 他自己承认盗号
--    「我的大号其实也是盗来的」「只要被我盗号的人服务就会[死]」
--    如果属实，说明站上有【账号安全问题】—— 建议检查一下登录/会话机制。
--    但他也可能只是在吹牛。
--
-- ③ 他索要的那三样功能
--    「把提取股份重新加出来，还有增值也重新加出来，还有原版破产」
--    —— 提取公司价值 / 注资 / 原版破产，正是被我们修掉的三个造币口。
--    这条基本确认了他就是刷币的人。
--    **绝对不要恢复这三个功能。**
-- ============================================================
