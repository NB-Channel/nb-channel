-- ============================================================
-- 更新全站公告(V0.9.2:安卓 APP 上线 + 移动端适配)
-- 在 Supabase SQL Editor 执行
-- ============================================================

UPDATE public.admin_config
   SET value = '📱 NB频道安卓 APP 上线
桌面独立图标 · 全屏运行 · 与网页版数据完全同步
下载:软件/APP 页面 → NB频道 APP
iPhone:用 Safari 打开官网 → 分享 → 添加到主屏幕

📐 移动端体验优化
图表不再被压扁 · 输入框不再放大页面 · 刘海屏适配

🚫 评论区新增「小黑屋」
违规账号公示,欢迎围观

V0.9.2 详情见更新日志
——NB频道官方'
 WHERE key = 'announcement';

-- 确认
SELECT key, left(value, 100) AS 公告开头 FROM public.admin_config WHERE key = 'announcement';
