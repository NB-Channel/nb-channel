-- ============================================================
--  更新全站公告（key = announcement）
--  执行位置：Supabase 控制台 → SQL Editor
--  说明：公告条在首页和更新日志页顶部，内容从 admin_config 表读取
-- ============================================================

insert into admin_config (key, value)
values ('announcement', '🎨 主题系统大升级：新增赛博朋克、墨韵、像素、护眼四个主题，每个主题还配了专属内容 —— 像素主题能玩贪吃蛇，赛博朋克能自己做霓虹灯牌，墨韵是一笔一画写出来的毛笔站名，护眼带 20-20-20 计时器。入口在「个人中心 → 界面主题」，国庆主题限时 10 月 1 日 ~ 7 日。')
on conflict (key) do update set value = excluded.value;

-- 执行完可以查一下确认：
-- select key, value from admin_config where key = 'announcement';
