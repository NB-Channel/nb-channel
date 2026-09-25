-- ============================================================
-- 封禁状态体检(纯只读:不插数据、不删数据、不改任何东西)
-- 跑完把结果贴回来即可
--
-- 结构:
--   块 A  一定能跑,不会报错
--   块 B  依赖「域名黑名单表」—— 若报 relation "banned_email_domains"
--         does not exist,那就等于告诉我:ban_xiaonb2_final.sql 还没跑
--   块 C  最近发码记录(用来核对 IP 抓取是否正常)
-- ============================================================


-- ============================================================
-- 块 A:组件自检(只查系统表,不碰任何业务数据)
-- ============================================================
SELECT '01 域名黑名单表已建' AS 项目,
       CASE WHEN to_regclass('public.banned_email_domains') IS NOT NULL
            THEN '✅' ELSE '❌ 表不存在' END AS 结果
UNION ALL
SELECT '02 _email_domain_banned 函数',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = '_email_domain_banned') > 0
            THEN '✅' ELSE '❌ 不存在' END
UNION ALL
SELECT '03 _client_ips 函数',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = '_client_ips') > 0
            THEN '✅' ELSE '❌ 不存在' END
UNION ALL
SELECT '04 _ip_banned 函数',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = '_ip_banned') > 0
            THEN '✅' ELSE '❌ 不存在' END
UNION ALL
SELECT '05 store_email_code 已套壳',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = '_orig_store_email_code') > 0
            THEN '✅ 原函数已改名' ELSE '❌ 没套壳,发码处拦不住' END
UNION ALL
SELECT '06 store_email_code 壳里查域名',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = 'store_email_code'
                     AND pg_get_functiondef(p.oid) LIKE '%_email_domain_banned%') > 0
            THEN '✅' ELSE '❌' END
UNION ALL
SELECT '07 register_finish 查域名',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = 'register_finish'
                     AND pg_get_functiondef(p.oid) LIKE '%_email_domain_banned%') > 0
            THEN '✅' ELSE '❌' END
UNION ALL
SELECT '08 register_finish 查IP',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = 'register_finish'
                     AND pg_get_functiondef(p.oid) LIKE '%_ip_banned%') > 0
            THEN '✅' ELSE '❌' END
UNION ALL
SELECT '09 _user_ok 查封禁(最早那步)',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = '_user_ok'
                     AND pg_get_functiondef(p.oid) LIKE '%is_banned%') > 0
            THEN '✅' ELSE '❌ 封号会形同虚设' END
UNION ALL
SELECT '10 小NB2 的IP 36.4.58.101 已封',
       CASE WHEN (SELECT count(*) FROM public.banned_ips WHERE ip = '36.4.58.101') > 0
            THEN '✅' ELSE '❌ 没封' END
UNION ALL
SELECT '11 攻击者老网段 4e21 已封',
       CASE WHEN (SELECT count(*) FROM public.banned_ips
                   WHERE ip = '2409:8a30:9c84:4e21::/64') > 0
            THEN '✅' ELSE '❌ 没封' END
UNION ALL
SELECT '12 小NB2 账号已封',
       CASE WHEN (SELECT count(*) FROM public.profiles
                   WHERE id = '7c112908-8e5e-487a-885a-49a2f318aeec'
                     AND is_banned IS TRUE) > 0
            THEN '✅' ELSE '❌' END
UNION ALL
SELECT '13 注册接口 anon 权限正常(必须✅)',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = 'register_finish'
                     AND has_function_privilege('anon', p.oid, 'EXECUTE')) > 0
            THEN '✅' ELSE '❌ 注册会挂,赶紧告诉我' END
UNION ALL
SELECT '14 发码接口 anon 权限正常(必须✅)',
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.prokind = 'f'
                     AND p.proname = 'store_email_code'
                     AND has_function_privilege('anon', p.oid, 'EXECUTE')) > 0
            THEN '✅' ELSE '❌ 发码会挂,赶紧告诉我' END
UNION ALL
SELECT '15 自检残留 203.0.113.9 已清',
       CASE WHEN (SELECT count(*) FROM public.banned_ips WHERE ip = '203.0.113.9') = 0
            THEN '✅' ELSE '❌ 还留着,跑 DELETE 清掉' END
UNION ALL
SELECT '16 黑名单总条数',
       (SELECT count(*)::text FROM public.banned_ips)
UNION ALL
SELECT '17 封禁账号总数',
       (SELECT count(*)::text FROM public.profiles WHERE is_banned IS TRUE)
 ORDER BY 1;


-- ============================================================
-- 块 B:域名黑名单内容(依赖块 A 的 01)
-- ⚠️ 如果这一段报 relation "public.banned_email_domains" does not exist,
--    就说明 ban_xiaonb2_final.sql 还没跑 —— 那本身就是答案,不用再查了。
-- ============================================================
SELECT public._email_domain_banned('test@ruutukf.com') AS 小NB2的域名应true,
       public._email_domain_banned('test@qq.com')      AS qq应false,
       public._email_domain_banned('test@163.com')     AS 一六三应false,
       (SELECT count(*)::text FROM public.banned_email_domains) AS 黑名单域名条数;


-- ============================================================
-- 块 C:最近发码记录(核对 IP 抓取)
-- ============================================================
-- 你自己去注册页用真实邮箱要一次验证码,再跑这条,
-- 看最新一条的 IP 是不是你真实公网 IP(浏览器开 https://ipwho.is 可查)。
SELECT email AS 邮箱, ip_address AS 记录IP, purpose AS 用途, created_at AS 时间
  FROM public.email_codes
 ORDER BY created_at DESC
 LIMIT 8;

-- 小NB2 当时的三条记录(应为 36.4.58.101)
SELECT email AS 邮箱, ip_address AS 记录IP, created_at AS 时间
  FROM public.email_codes
 WHERE lower(email) = 'eyir59ii21@ruutukf.com'
 ORDER BY created_at;
