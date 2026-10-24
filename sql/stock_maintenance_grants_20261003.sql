-- ============================================================
-- 维护模式：给前端补读权限
-- ============================================================
-- 前端要判断"现在是不是维护中、我是不是白名单"，
-- 就得能读 stock_settings 和 stock_whitelist 这两张表。
--
-- 这两张表里没有敏感信息：
--   stock_settings   只有 maintenance 和一句公告文字
--   stock_whitelist  只有 uuid，而且前端只会查"我自己在不在里面"
--                    （用 eq('user_id', 自己的 id)，查不到别人的）
--
-- 在 Supabase SQL Editor 执行。跑完 stock_maintenance_READY 那份脚本之后跑这个。
-- ============================================================

-- 开 RLS
ALTER TABLE public.stock_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_whitelist ENABLE ROW LEVEL SECURITY;

-- 允许匿名读（前端用的是 anon key）
DROP POLICY IF EXISTS stock_settings_read  ON public.stock_settings;
DROP POLICY IF EXISTS stock_whitelist_read ON public.stock_whitelist;

CREATE POLICY stock_settings_read ON public.stock_settings
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY stock_whitelist_read ON public.stock_whitelist
    FOR SELECT TO anon, authenticated USING (true);

-- 但不允许匿名写（只有 SECURITY DEFINER 的函数能改）
REVOKE INSERT, UPDATE, DELETE ON public.stock_settings  FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.stock_whitelist FROM anon;

GRANT SELECT ON public.stock_settings  TO anon, authenticated;
GRANT SELECT ON public.stock_whitelist TO anon, authenticated;


-- ============================================================
-- 验收：直接查一下，前端应该能拿到这些
-- ============================================================
SELECT * FROM public.stock_settings;
SELECT user_id, note FROM public.stock_whitelist;
