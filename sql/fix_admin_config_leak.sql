-- ============================================================
-- 紧急:admin_config 表匿名可读 + 可改 + 可删 → 后台密码明文外泄
-- 已证实(用公开 anon key 实测):
--   GET    /admin_config            → 200,能读到 {"key":"admin_password","value":"..."}
--   PATCH  /admin_config?key=eq.x   → 204(能改)
--   DELETE /admin_config?key=eq.x   → 204(能删)
-- 后果:任何人不用登录就能拿到后台密码 → 登录管理后台 → 删号/改数据/清余额
-- 这很可能就是盗号事件的入口!
-- ============================================================

-- ---------- 第 0 步:先看现在的密码是什么(跑完把它改成新的) ----------
SELECT key, value FROM public.admin_config ORDER BY key;

-- ---------- 第 1 步:行级安全 —— 匿名只能读「公告」这一行 ----------
ALTER TABLE public.admin_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_config_public_read ON public.admin_config;
CREATE POLICY admin_config_public_read ON public.admin_config
    FOR SELECT TO anon, authenticated
    USING (key = 'announcement');

-- ---------- 第 2 步:收回写权限(改/删/增全部禁止) ----------
REVOKE INSERT, UPDATE, DELETE ON public.admin_config FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.admin_config FROM authenticated;

-- ---------- 第 3 步:立刻换后台密码(必须做,旧密码已经泄露) ----------
-- 把 '换成新的强密码' 替换掉,再执行:
-- UPDATE public.admin_config SET value = '换成新的强密码' WHERE key = 'admin_password';

-- ---------- 第 4 步:验收 ----------
-- 期望:只返回 announcement 一行(密码行读不到了)
SELECT key, value FROM public.admin_config ORDER BY key;

-- 如果第 4 步还能看到 admin_password,说明 RLS 没生效,把结果发我。

-- ============================================================
-- 回滚(万一后台登录不上,执行下面两行恢复原状,然后找我)
-- ============================================================
-- DROP POLICY IF EXISTS admin_config_public_read ON public.admin_config;
-- ALTER TABLE public.admin_config DISABLE ROW LEVEL SECURITY;
