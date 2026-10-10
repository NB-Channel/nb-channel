-- ============================================================
--  发布 V1.0.8 公告
--
--  公告存在数据库 admin_config 表的 announcement 键里，
--  前端从两个地方读它渲染：
--      1. js/ui-nav.js 的 .beta-announce —— 一行无缝滚动
--      2. Beta/comments-Beta.html 的 .announcement-bar —— pre-line
--  所以必须【单段】，不能换行。
--
--  另外两个硬要求（都是踩过的坑）：
--      · 不能含 @   —— 会和「@某人」的提及语法打架
--      · 不能含 < >  —— 是网页标记字符
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- 第 0 步：看现在的公告
SELECT
    key,
    left(value, 120) AS 现在的内容,
    length(value)    AS 长度,
    updated_at
  FROM public.admin_config
 WHERE key = 'announcement';


-- 第 1 步：写入新公告
UPDATE public.admin_config
   SET value = 'V1.0.8 上线 ① 关于页新增「关于域名」，放上了 nb-channel.top 的顶级国际域名证书 ② 用户名放宽 —— 现在能带 - _ . + ★ ☆ ♥ 这类常用符号，空格仍然不行 ③ 评论最多 10 行的限制前后端都补齐了 ④ 个人中心右下角重复的那组按钮删掉了',
       updated_at = now()
 WHERE key = 'announcement';

-- 如果这一行没更新到任何记录（说明这个键还不存在），用下面这句补一条：
INSERT INTO public.admin_config (key, value, updated_at)
SELECT 'announcement', 'V1.0.8 上线 ① 关于页新增「关于域名」，放上了 nb-channel.top 的顶级国际域名证书 ② 用户名放宽 —— 现在能带 - _ . + ★ ☆ ♥ 这类常用符号，空格仍然不行 ③ 评论最多 10 行的限制前后端都补齐了 ④ 个人中心右下角重复的那组按钮删掉了', now()
 WHERE NOT EXISTS (SELECT 1 FROM public.admin_config WHERE key = 'announcement');


-- 第 2 步：确认
SELECT
    key,
    value     AS 新公告,
    length(value) AS 长度,
    CASE WHEN position('@' in value) > 0 THEN '❌ 含 @'
         WHEN position('<' in value) > 0 OR position('>' in value) > 0 THEN '❌ 含尖括号'
         WHEN position(E'\n' in value) > 0 THEN '❌ 含换行'
         ELSE '✅ 单段、无 @、无尖括号' END AS 检查,
    updated_at
  FROM public.admin_config
 WHERE key = 'announcement';


-- ============================================================
--  第 3 步：去页面上看一眼
-- ============================================================
--  · 官网模式任意页面顶部那条滚动公告
--  · 评论页顶部的公告栏
--  两边都刷新一下，确认显示的是 V1.0.8 这条。
--
--  ⚠️ 如果滚动太快或太慢：滚动时长是按文字宽度算的（宽度 / 45 秒），
--     不是固定值，所以不用手调。这条 100 多字，大约 20 秒滚完一轮。
-- ============================================================
