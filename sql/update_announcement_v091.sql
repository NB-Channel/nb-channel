-- ============================================================
-- 更新全站公告(V0.9.1 安全升级)
-- 在 Supabase SQL Editor 执行
-- 说明:admin_config 之前被收口为"匿名只读公告行",写入只能在这里做
-- ============================================================

UPDATE public.admin_config
   SET value = '🛡️ 全站安全升级已完成
1. 登录/注册新增邮箱验证码,账号更安全
2. 所有涉及账号的操作改为服务端身份校验,他人无法再冒用你的身份
3. 若你的密码与其他网站相同,建议尽快到「个人中心 → 修改密码」更换
4. 官方绝不会索要密码或验证码,谨防冒充客服
账号如出现异常(头像/简介/公司/余额被改动),请邮件 nbchannel@163.com,我们协助核实处理

🎉 NB频道官网 Beta 版内测进行中
22 个页面完成官网化,数据与经典版完全互通
入口:https://github.nb-channel.top/Beta/index-Beta.html

📢 网站开放公开 API
股票市值、历史K线、评论等数据开放只读访问
接口文档:https://api.nb-channel.top/api/docs

V0.9.1 更新详情见更新日志
——NB频道官方'
 WHERE key = 'announcement';

-- 确认
SELECT key, left(value, 120) AS 公告开头 FROM public.admin_config WHERE key = 'announcement';
