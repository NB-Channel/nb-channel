-- ============================================================
--  全站安全审计（第二轮）
--
--  上一轮查的是「函数权限」—— 找出了 92 个匿名可调的 _orig_*、
--  6 个无鉴权的旧重载、以及银行定期存款没有额度限制。
--
--  这一轮换几个方向（全部只读）：
--    一、表的 RLS 状态 —— 没开 RLS 的表等于全公开
--    二、⭐ anon 能【直接写】的表 —— 最危险的一类
--    三、⭐ 「SECURITY DEFINER 且 anon 可调、但函数体里没有鉴权」的函数
--        这是上一轮那 6 个和 92 个的通用特征，用规则扫一遍能找出剩下的
--    四、admin 相关：密码是怎么存的、会话表状态
--    五、Storage 桶的读写策略
--
--  跑完把五张表都发我。
-- ============================================================


-- ============================================================
-- 一、所有表的 RLS 状态
--     relrowsecurity = false 的表【任何有表权限的人都能看全部行】
-- ============================================================
SELECT
    c.relname                                        AS 表名,
    c.relrowsecurity                                 AS 开了RLS,
    count(p.policyname)                              AS 策略数,
    CASE WHEN NOT c.relrowsecurity THEN '🔴 没开 RLS'
         WHEN count(p.policyname) = 0 THEN '🟠 开了但没有策略（默认全拒，通常没问题）'
         ELSE '✅ 正常' END                           AS 判断
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_policies p ON p.schemaname = 'public' AND p.tablename = c.relname
 WHERE n.nspname = 'public' AND c.relkind = 'r'
 GROUP BY c.relname, c.relrowsecurity
 ORDER BY c.relrowsecurity, c.relname;


-- ============================================================
-- 二、⭐ anon / authenticated 能【直接写】的表
--     能写就意味着绕过所有 RPC 的检查，直接改数据
-- ============================================================
SELECT
    c.relname AS 表名,
    CASE WHEN has_table_privilege('anon', c.oid, 'INSERT') THEN 'INSERT ' ELSE '' END ||
    CASE WHEN has_table_privilege('anon', c.oid, 'UPDATE') THEN 'UPDATE ' ELSE '' END ||
    CASE WHEN has_table_privilege('anon', c.oid, 'DELETE') THEN 'DELETE ' ELSE '' END
                                                      AS anon能做的写操作,
    CASE WHEN has_table_privilege('authenticated', c.oid, 'INSERT') THEN 'INSERT ' ELSE '' END ||
    CASE WHEN has_table_privilege('authenticated', c.oid, 'UPDATE') THEN 'UPDATE ' ELSE '' END ||
    CASE WHEN has_table_privilege('authenticated', c.oid, 'DELETE') THEN 'DELETE ' ELSE '' END
                                                      AS authenticated能做的写操作,
    CASE WHEN has_table_privilege('anon', c.oid, 'SELECT') THEN 'anon可读' ELSE '—' END AS 读
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
   AND (has_table_privilege('anon', c.oid, 'INSERT')
     OR has_table_privilege('anon', c.oid, 'UPDATE')
     OR has_table_privilege('anon', c.oid, 'DELETE')
     OR has_table_privilege('authenticated', c.oid, 'INSERT')
     OR has_table_privilege('authenticated', c.oid, 'UPDATE')
     OR has_table_privilege('authenticated', c.oid, 'DELETE'))
 ORDER BY 表名;

-- 期望：除了极个别（比如 comments 允许登录用户直接插）之外应该是空的。
-- 如果 profiles / user_companies / bank_accounts 出现在这里，就是大问题。


-- ============================================================
-- 三、⭐ 通用规则扫描：SECURITY DEFINER + anon 可调 + 函数体里没有鉴权
--
--   上一轮靠人肉找出了 _orig_* 和 6 个旧重载。
--   这一轮用规则扫：函数体里【既没有】_user_ok / _admin_token_valid，
--   【也没有】p_session / p_token 参数 —— 那它多半不验身份。
-- ============================================================
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    length(pg_get_functiondef(p.oid))             AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%_user_ok%'         THEN '有_user_ok ' ELSE '' END ||
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%_admin_token_valid%' THEN '有admin校验 ' ELSE '' END ||
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%_session_token%'   THEN '有session ' ELSE '' END
                                                  AS 找到的鉴权痕迹,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN 'anon 能调' ELSE '' END        AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN 'authenticated 能调' ELSE '' END AS authenticated
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'
   AND p.prosecdef                                    -- SECURITY DEFINER
   AND has_function_privilege('anon', p.oid, 'EXECUTE')
   -- 函数体里没有任何鉴权痕迹
   AND pg_get_functiondef(p.oid) NOT LIKE '%_user_ok%'
   AND pg_get_functiondef(p.oid) NOT LIKE '%_admin_token_valid%'
   -- 参数里也没有令牌
   AND position('p_session' in pg_get_function_identity_arguments(p.oid)) = 0
   AND position('p_token'   in pg_get_function_identity_arguments(p.oid)) = 0
 ORDER BY p.proname;

-- 这张表要人工过一遍。有些是设计上就该公开的
-- （比如 get_market_status、排行榜之类的只读函数），
-- 但凡是【写操作】出现在这里，都是漏洞。


-- ============================================================
-- 四、admin 相关
-- ============================================================

-- 4.1 管理员密码怎么存的（这个函数不在仓库里，只能从库里看）
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    pg_get_functiondef(p.oid)                     AS 源码
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname LIKE '%admin_password%'
 ORDER BY p.proname;

-- 4.2 admin_create_session 谁能调（能调就能靠传假 IP 绕限频）
SELECT
    p.proname                                     AS 函数,
    pg_get_function_identity_arguments(p.oid)     AS 参数,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN 'anon 能调' ELSE '—' END        AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN 'authenticated 能调' ELSE '—' END AS authenticated
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('admin_create_session','admin_check_session','_admin_token_valid')
 ORDER BY p.proname;

-- 4.3 现在有几个有效的管理员会话（应该只有你自己正在用的那一个）
SELECT
    count(*)                                                  AS 会话总数,
    count(*) FILTER (WHERE expires_at > now())                AS 还有效的,
    min(created_at)                                           AS 最早创建,
    max(created_at)                                           AS 最近创建
  FROM public.admin_sessions;

-- 4.4 登录尝试记录（如果某个 IP 有一堆记录，说明有人在试密码）
SELECT
    ip_address,
    count(*)                       AS 尝试次数,
    max(created_at)                AS 最近一次
  FROM public.admin_login_attempts
 GROUP BY ip_address
 ORDER BY count(*) DESC
 LIMIT 20;


-- ============================================================
-- 五、Storage 桶的读写策略（作品分享用的那个）
-- ============================================================
SELECT
    id            AS 桶,
    name          AS 名称,
    public        AS 公开,
    file_size_limit,
    allowed_mime_types
  FROM storage.buckets
 ORDER BY id;

-- 5.2 桶上的策略
SELECT
    schemaname, tablename, policyname, cmd, roles, qual
  FROM pg_policies
 WHERE schemaname = 'storage'
 ORDER BY tablename, policyname;


-- ============================================================
--  怎么读
-- ============================================================
--  · 第一张表：出现「🔴 没开 RLS」的表要立刻处理。
--  · 第二张表：⭐ 最要紧。profiles / user_companies / bank_accounts
--    这些表如果 anon 能写，那前面所有的 RPC 加固都是白做的。
--  · 第三张表：函数名列出来之后，凡是【写操作】的都值得逐个看。
--  · 第四张表 4.1 会把管理员密码校验的源码直接打出来 ——
--    如果是明文比较，建议改成哈希（bcrypt 或至少 sha256+盐）。
--    4.2 如果 anon 能调 admin_create_session，限频就是纸糊的。
--  · 第五张表：桶是 public 的话，任何人都能拿到文件 URL
--    （作品分享如果是公开下载那没问题）。
-- ============================================================
