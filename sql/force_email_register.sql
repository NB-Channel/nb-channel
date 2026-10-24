-- ============================================================
-- 强制邮箱验证注册:停用老的免验证注册接口
-- 背景:站上有两条注册通道 ——
--   新登录页 register_finish(用户名+密码+邮箱验证码) ✓ 安全
--   老接口   register_user(只要用户名+密码)          ✗ 攻击者删号后可立刻注册新号
-- 前端已把评论页/个人中心的注册按钮统一改为跳转新注册流程,这里把老接口关掉。
-- register_finish 是 SECURITY DEFINER,内部调用不受影响。
-- ============================================================

-- 停用老注册接口(匿名不可再调用)
REVOKE EXECUTE ON FUNCTION public.register_user(text, text) FROM PUBLIC, anon, authenticated;

-- ---------- 验收 ----------
SELECT p.proname AS 函数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_可调用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('register_user', 'register_finish', 'login_user', 'login_user2')
 ORDER BY p.proname;
-- 期望:register_user = false(已停用);register_finish/login_user2 = true(还要用)
--      login_user = true(评论页改资料时验证旧密码仍需它)
