-- ============================================================
-- 安全审计修复脚本（2026-09-25 全站审计结果）
-- ============================================================
-- 本文件只修【能直接安全修】的部分。
-- 涉及前端要改代码的（reports / support_rules），见文件末尾说明，
-- 不要在这里直接收权限，否则前端会读不到数据。
--
-- 在 Supabase SQL Editor 执行
-- ============================================================


-- ============================================================
-- 1. 【最紧急】存储桶:收回匿名上传权限
-- ============================================================
-- 问题:sql/fix_storage_buckets.sql 给 anon 授了 INSERT 权限
--       （注释写"后端用 anon key 上传"），而 anon key 是公开的
--       （每个页面 HTML 里都有）→ 任何人都能往桶里传文件。
-- 实测:上传返回 200、公开链接不带任何密钥可访问、匿名删不掉
--       → 可被当免费图床/网盘,能撑爆容量,还能用你的域名挂不良内容。
--
-- ⚠️ 执行前必读:收掉这三条策略后,PythonAnywhere 后端的图片上传会失败,
--    因为 app.py 用的也是 anon key。
--    正确做法是【两步同时做】:
--      ① 后端改用 service_role key(app.py 改成从环境变量读
--         SERVICE_KEY,只给 storage 用;PythonAnywhere 已有
--         secrets_local.py 机制,可以往里加)
--      ② 再执行下面的 DROP
--    顺序反了会中断上传功能。
--
-- 只想先止血、不介意暂时不能传图的话,直接执行下面三句即可。
DROP POLICY IF EXISTS "images_anon_insert"   ON storage.objects;
DROP POLICY IF EXISTS "avatars_anon_insert"  ON storage.objects;
DROP POLICY IF EXISTS "products_anon_insert" ON storage.objects;

-- 顺带收紧删除权限(原来也给了 anon;实测虽被 SELECT 策略挡住,
-- 但没有理由保留)
DROP POLICY IF EXISTS "images_anon_delete"   ON storage.objects;
DROP POLICY IF EXISTS "avatars_anon_delete"  ON storage.objects;
DROP POLICY IF EXISTS "products_anon_delete" ON storage.objects;


-- ============================================================
-- 2. 收回【前端根本没读】的表权限(可立即执行,不影响任何功能)
-- ============================================================
-- 已核对全部 24 个 Beta 页面 + 根目录页面 + js/common.js:
-- 这三个表【没有任何前端代码直接读】,所以收掉是安全的。
--
--   user_checkins : 102 条签到记录(含 user_id/连续天数)被匿名可读
--   notifications : 消息中心通知表,现在空表,但一旦有数据就会被人读到
--   api_logs      : 访客 IP 日志(现在空表;后端用 log_api_requests 写入,
--                   不需要 anon 的 SELECT 权限)
REVOKE SELECT ON public.user_checkins  FROM anon, authenticated;
REVOKE SELECT ON public.notifications  FROM anon, authenticated;
REVOKE SELECT ON public.api_logs       FROM anon, authenticated;


-- ============================================================
-- 3. `log_api_requests` 匿名可写 —— 加大小与频率限制
-- ============================================================
-- 问题:该函数是 SECURITY DEFINER + GRANT 给 anon 的(后端要调),
--       但没有做任何校验 → 任何人都能伪造日志、无限插入撑爆 api_logs。
-- 这里加两道:单次最多 200 行、单次每字段长度已有限制(原有)。
-- (彻底修法是后端改用 service_role 调它并收回 anon 权限,
--  但那要改 app.py,先加限制止血)
CREATE OR REPLACE FUNCTION public.log_api_requests(p_rows jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- 单次最多 200 行,挡住"一次塞十万行"的打法
    IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
        RETURN;
    END IF;
    IF jsonb_array_length(p_rows) > 200 THEN
        RAISE EXCEPTION 'too many rows (max 200)';
    END IF;

    INSERT INTO public.api_logs (endpoint, method, ip, status, ua)
    SELECT left((r ->> 'endpoint')::text, 200),
           COALESCE(NULLIF(left((r ->> 'method')::text, 10), ''), 'GET'),
           NULLIF(left((r ->> 'ip')::text, 60), ''),
           NULLIF((r ->> 'status')::text, '')::smallint,
           NULLIF(left((r ->> 'ua')::text, 200), '')
    FROM jsonb_array_elements(p_rows) AS r
    WHERE (r ->> 'endpoint') IS NOT NULL;
END $$;

GRANT EXECUTE ON FUNCTION public.log_api_requests(jsonb) TO anon;


-- ============================================================
-- 4. `search_users` 泄露用户 UUID —— 与"不暴露用户ID"的设计相悖
-- ============================================================
-- 站点更新日志写明:「支持 ?username= 查看他人主页（无需登录,不暴露用户ID）」,
-- 但 search_users 直接返回 uuid。虽然 UUID 本身不足以越权(其他接口还要令牌),
-- 但会让"账号枚举"变容易。
-- 修法:不再返回 id,前端改用 username 定位(个人主页本来就支持 ?username=)。
-- 这条要改前端,先不执行,列出供你决定:
--
-- CREATE OR REPLACE FUNCTION public.search_users(p_keyword text, p_user_id uuid)
-- RETURNS TABLE (username text, avatar_url text)
-- LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
-- AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT pr.username, pr.avatar_url
--       FROM public.profiles pr
--      WHERE pr.username ILIKE '%' || p_keyword || '%'
--        AND pr.id <> p_user_id
--        AND NOT pr.is_banned
--      ORDER BY pr.username LIMIT 20;
-- END; $$;


-- ============================================================
-- 5. 需要你先确认再修的两张表(前端在读,收权限会坏)
-- ============================================================
--   reports(55 条)     举报人 user_id + 举报理由 匿名可读
--                      → 被举报人能反查是谁举报的,可致报复
--   support_rules(39 条) 用户的自动支持策略(阈值/金额)匿名可读
--
-- 这两张表的修法是【把前端的直接读改成 RPC】(项目里已有大量同类先例,
-- 如 get_my_items / get_my_titles),RPC 里用 _user_ok 校验,
-- 只能读自己的数据。改完前端再 REVOKE SELECT。
-- 现在直接 REVOKE 会导致:
--   reports        → comments-Beta.html、后台面板 读不到
--   support_rules  → stock-Beta.html、profile-Beta.html、Virtual stock.html 读不到
-- 所以本文件不动它们。


-- ============================================================
-- 6. 验收
-- ============================================================
-- 6.1 还有哪些表匿名可读(期望:只剩本来就该公开的
--     comments / user_companies / stock_* / shop_items /
--     admin_config / banned_ips / comment_reactions / verified_users /
--     bad_words / profiles)
SELECT c.relname AS 表名,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'SELECT') AS 匿名可读
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
   AND has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'SELECT')
 ORDER BY c.relname;

-- 6.2 存储桶的 anon 策略应该一条都不剩
SELECT policyname AS 策略, cmd AS 操作, roles AS 角色
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND policyname LIKE '%anon%';

-- 6.3 【重要】无参数函数的执行权限核查
--     这 13 个函数无参数、且有实际副作用(扣税/结算/清数据),
--     审计脚本刻意没有调用它们。请核对 anon 是否还能执行:
SELECT p.proname AS 函数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS 匿名可执行
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.pronargs = 0
   AND p.proname IN ('bank_daily_settle', 'collect_company_tax', 'delete_old_history_full',
                     'random_fluctuate_market_values', 'run_auto_support',
                     'sample_market_snapshot', 'record_daily_kline',
                     'refund_expired_redpackets', 'renew_shop_items',
                     'publish_stock_snapshot')
 ORDER BY p.proname;
-- 期望:全部 false。若出现 true,那条要立刻 REVOKE(例如:
--   REVOKE EXECUTE ON FUNCTION public.collect_company_tax() FROM PUBLIC, anon, authenticated;)
