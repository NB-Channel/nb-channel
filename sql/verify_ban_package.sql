-- ============================================================
-- 验证:封禁礼包到底装上了没、拦不拦得住
--
-- 分三层,从快到慢:
--   ① 组件自检     —— 纯 SQL,立刻出结果,一张表看全部 ✅/❌
--   ② 逻辑自测     —— 临时插测试数据、验证拦截函数、再删掉(不留痕迹)
--   ③ 端到端实测   —— 真去注册页走一遍,这是唯一能证明「真拦得住」的
--   ④ 后续监控     —— 以后每天跑一次,看他有没有再来
--
-- 在 Supabase SQL Editor 整段执行
-- ============================================================


-- ============================================================
-- ① 组件自检
-- ============================================================
-- 13 项全 true 才算装齐。有 false 的把名字告诉我就行。
SELECT '01 域名黑名单表已建'          AS 检查项,
       (to_regclass('public.banned_email_domains') IS NOT NULL)::text AS 结果
UNION ALL
SELECT '02 ruutukf.com 已收录',
       (EXISTS (SELECT 1 FROM public.banned_email_domains WHERE domain = 'ruutukf.com'))::text
UNION ALL
SELECT '03 _email_domain_banned 函数存在',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = '_email_domain_banned'))::text
UNION ALL
SELECT '04 _client_ips 函数存在',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = '_client_ips'))::text
UNION ALL
SELECT '05 _ip_banned 函数存在',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = '_ip_banned'))::text
UNION ALL
SELECT '06 store_email_code 已套壳(原函数已改名)',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = '_orig_store_email_code'))::text
UNION ALL
SELECT '07 store_email_code 壳里已查域名',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = 'store_email_code'
                   AND pg_get_functiondef(p.oid) LIKE '%_email_domain_banned%'))::text
UNION ALL
SELECT '08 register_finish 已查域名',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = 'register_finish'
                   AND pg_get_functiondef(p.oid) LIKE '%_email_domain_banned%'))::text
UNION ALL
SELECT '09 register_finish 已查 IP',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = 'register_finish'
                   AND pg_get_functiondef(p.oid) LIKE '%_ip_banned%'))::text
UNION ALL
SELECT '10 36.4.58.101 已封',
       (EXISTS (SELECT 1 FROM public.banned_ips WHERE ip = '36.4.58.101'))::text
UNION ALL
SELECT '11 _user_ok 已查封禁(前面那步)',
       (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.prokind = 'f'
                   AND p.proname = '_user_ok'
                   AND pg_get_functiondef(p.oid) LIKE '%is_banned%'))::text
UNION ALL
SELECT '12 小NB2 已封',
       (EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = '7c112908-8e5e-487a-885a-49a2f318aeec' AND is_banned IS TRUE))::text
UNION ALL
SELECT '13 注册接口 anon 权限没被搞坏(必须 true)',
       (SELECT has_function_privilege('anon', p.oid, 'EXECUTE')::text
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND p.proname = 'register_finish' LIMIT 1)
UNION ALL
SELECT '14 发码接口 anon 权限没被搞坏(必须 true)',
       (SELECT has_function_privilege('anon', p.oid, 'EXECUTE')::text
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND p.proname = 'store_email_code' LIMIT 1)
 ORDER BY 1;
-- 13/14 必须是 true。若是 false,注册/发码会直接 404 或被拒,立刻告诉我。


-- ============================================================
-- ② 逻辑自测(临时插数据 → 验证 → 删掉,不留痕迹)
-- ============================================================
-- 用 RFC 5737 保留的测试网段 203.0.113.x 和保留 TLD .example,
-- 保证不会撞到任何真实用户。

-- 2.1 域名拦截
INSERT INTO public.banned_email_domains (domain, reason)
VALUES ('selftest.example', '自检临时,马上删除')
ON CONFLICT (domain) DO UPDATE SET reason = EXCLUDED.reason;

SELECT public._email_domain_banned('someone@selftest.example') AS 域名_黑名单应true,
       public._email_domain_banned('someone@ruutukf.com')      AS 域名_小NB2的应true,
       public._email_domain_banned('someone@qq.com')           AS 域名_正常邮箱应false,
       public._email_domain_banned('someone@163.com')          AS 域名_163应false,
       public._email_domain_banned('乱七八糟没有at符号')        AS 域名_格式错应false;

DELETE FROM public.banned_email_domains WHERE domain = 'selftest.example';

-- 2.2 IP 拦截(精确 + IPv6 /64 网段)
INSERT INTO public.banned_ips (ip, reason)
VALUES ('203.0.113.9', '自检临时,马上删除')
ON CONFLICT (ip) DO UPDATE SET reason = '自检临时,马上删除';

SELECT public._ip_banned(ARRAY['203.0.113.9'])                        AS IP_精确命中应true,
       public._ip_banned(ARRAY['36.4.58.101'])                        AS IP_小NB2的应true,
       public._ip_banned(ARRAY['2409:8a30:9c84:4e21:1111:2222:3333:4444']) AS IP_他老网段应true,
       public._ip_banned(ARRAY['8.8.8.8'])                            AS IP_正常应false,
       public._ip_banned(ARRAY[]::text[])                             AS "IP_空数组应false(不能误伤)",
       public._ip_banned(NULL)                                        AS "IP_拿不到IP应false(不能误伤)";

-- ⚠️ 上面那条 SELECT 万一报错(比如别名里有括号),这句就轮不到执行,
--    203.0.113.9 会一直留在黑名单里。所以单独再删一次,保证干净。
DELETE FROM public.banned_ips WHERE ip = '203.0.113.9';

-- 确认自检数据已清干净(这条应返回 0 行)
SELECT ip AS 残留的自检数据 FROM public.banned_ips WHERE ip = '203.0.113.9';

-- 2.3 关键安全检查:拿不到 IP 时绝不能挡住正常用户
--     _client_ips() 在没有请求头时(比如从 SQL Editor 直接调用)应返回空数组,
--     于是 _ip_banned 返回 false → 注册照常。这条是防止「改完注册全挂」的保险。
SELECT public._client_ips() AS 直接调用时的IP数组,
       public._ip_banned(public._client_ips()) AS 此时应false;


-- ============================================================
-- ③ 端到端实测(唯一能证明「真拦得住」的,需要你手动做)
-- ============================================================
-- ── 测试 1:临时邮箱应该被拒 ──────────────────────────────
--   打开注册页(login-Beta.html),邮箱填一个 @ruutukf.com 的地址,点发送验证码。
--   预期:立刻提示「该邮箱域名属于一次性临时邮箱,请使用常用邮箱注册」,
--         且**不会真的发信**(省配额)。
--   若仍提示"发送成功" → 说明 store_email_code 的壳没生效,把 ① 的 07 项结果告诉我。
--
-- ── 测试 2:真实邮箱应该正常 ──────────────────────────────
--   同一个页面,换成你自己的真实邮箱,点发送验证码。
--   预期:正常收到验证码。
--   然后跑下面这句,看最新一条记录的 IP 是不是你的真实公网 IP
--   (浏览器打开 https://ipwho.is 可查你自己的 IP):
SELECT email AS 邮箱, ip_address AS 记录IP, purpose AS 用途, created_at AS 时间
  FROM public.email_codes
 ORDER BY created_at DESC
 LIMIT 5;
--   ✅ 记录IP == 你的真实 IP  → IP 抓取链路正常,封 IP 有效
--   ❌ 不一致 / 为空          → 抓不到真实 IP,封 IP 这条路不可靠,告诉我
--
-- ── 测试 3:被封 IP 应该注册不了(可选,验证 IP 拦截真的在跑)──
--   先把自己 IP 临时加进黑名单:
--     INSERT INTO public.banned_ips (ip, reason)
--     VALUES ('把这里换成测试2查到的你的IP', '自检临时') ON CONFLICT (ip) DO NOTHING;
--   然后去注册页走完整流程(真实邮箱 + 收到的验证码 + 点注册)。
--   预期:提示「该网络已被限制注册,如有疑问请联系管理员」。
--   ⚠️ 测完**立刻删掉**,否则你自己的注册也会被挡:
--     DELETE FROM public.banned_ips WHERE reason = '自检临时';
--   (注意:只影响注册,不影响你已登录的会话和日常使用)


-- ============================================================
-- ④ 后续监控(以后每天跑一次,看他有没有再来)
-- ============================================================
-- 1) 最近 3 天的发码记录:有没有新的可疑邮箱域名 / 可疑 IP
SELECT created_at AT TIME ZONE 'Asia/Shanghai' AS 时间,
       email AS 邮箱,
       split_part(lower(email), '@', 2) AS 域名,
       ip_address AS IP,
       public._email_domain_banned(email) AS 域名已拉黑
  FROM public.email_codes
 WHERE created_at > now() - interval '3 days'
 ORDER BY created_at DESC
 LIMIT 50;

-- 2) 最近 7 天新注册的账号 ← 注册 IP(register_finish 现在会记了)
SELECT p.username AS 用户名,
       to_char(p.created_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI') AS 注册时间,
       p.is_banned AS 已封,
       (SELECT r.ip_address FROM public.registration_attempts r
         WHERE r.created_at BETWEEN p.created_at - interval '3 minutes'
                                AND p.created_at + interval '3 minutes'
         ORDER BY abs(extract(epoch FROM (r.created_at - p.created_at))) LIMIT 1) AS 注册IP
  FROM public.profiles p
 WHERE p.created_at > now() - interval '7 days'
 ORDER BY p.created_at DESC;

-- 3) 一次性邮箱域名黑名单现状
SELECT domain AS 域名, reason AS 原因, created_at AS 加入时间
  FROM public.banned_email_domains
 ORDER BY created_at DESC, domain;
