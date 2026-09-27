-- ============================================================
-- 修「发送失败：未知用途」
-- ============================================================
-- 原因：数据库里的 store_email_code（实际是 _orig_store_email_code 那一层）
--       有一句 purpose 白名单：
--           IF p_purpose NOT IN ('register', 'login', 'bind') THEN
--               RETURN jsonb_build_object('ok', false, 'message', '未知用途');
--       这个白名单是 URGENT4_limit_email_sending.sql 加的,
--       而 fix_admin_login_2fa.sql 只看了最早的 email_code.sql,没跟上。
--
-- 本文件做「动态打补丁」：把线上那个函数的定义读出来,只把白名单那一句
-- 改成包含 'admin',再原样写回去。这样不管线上是哪个版本
-- (email_code / fix_code_null_check / URGENT3 / URGENT4 / fix_email_code_rate
--  / fix_email_code_interval) 都能改对,也不会覆盖掉别的限频逻辑。
--
-- 在 Supabase SQL Editor 执行（幂等,重复跑只会有 NOTICE）
-- ============================================================


-- ============================================================
-- 1. 打补丁
-- ============================================================
DO $do$
DECLARE
    v_name text;
    v_def  text;
    v_new  text;
BEGIN
    -- 找那个真正做校验的函数：优先 _orig_store_email_code（被套壳的那个），
    -- 没有就退回 store_email_code 本身。
    -- ⚠️ 必须过滤 prokind='f'：不过滤的话 pg_get_functiondef 会因为
    --    聚合函数报 "array_agg is an aggregate function"
    SELECT p.proname, pg_get_functiondef(p.oid)
      INTO v_name, v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prokind = 'f'
       AND p.proname IN ('_orig_store_email_code', 'store_email_code')
       AND pg_get_functiondef(p.oid) LIKE '%未知用途%'
     ORDER BY (p.proname = '_orig_store_email_code') DESC, p.oid DESC
     LIMIT 1;

    IF v_name IS NULL THEN
        RAISE NOTICE 'ℹ️ 没找到带「未知用途」白名单的函数 —— 可能已经改过了,或版本不同';
        RETURN;
    END IF;

    -- 只替换白名单括号里的内容,函数体其余部分原样保留
    v_new := regexp_replace(
        v_def,
        '(p_purpose\s+NOT\s+IN\s*\()([^)]*)(\))',
        '\1''register'', ''login'', ''bind'', ''admin''\3');

    IF v_new = v_def THEN
        RAISE NOTICE '⚠️ 找到了 % 但正则没匹配上,请把下面这段贴给我看：', v_name;
        RAISE NOTICE '%', substring(v_def from position('未知用途' in v_def) - 200 for 260);
        RETURN;
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ 已给 % 的白名单加上 admin', v_name;
END
$do$;


-- ============================================================
-- 2. 验收
-- ============================================================

-- 2.1 两个函数里都应该能看到 'admin'
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%''admin''%') AS 含admin,
       (pg_get_functiondef(p.oid) LIKE '%未知用途%')   AS 仍有白名单
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND p.proname IN ('store_email_code', '_orig_store_email_code')
 ORDER BY 1;
-- 期望：真正做事的那一个显示 含admin = true

-- 2.2 确认 email_codes 表没有 CHECK 约束挡着 purpose='admin'
SELECT con.conname AS 约束名, pg_get_constraintdef(con.oid) AS 定义
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
 WHERE n.nspname = 'public' AND rel.relname = 'email_codes' AND con.contype = 'c';
-- 期望：0 行（有的话 fix_admin_login_2fa.sql 那个 DO 块已经处理过了）


-- ============================================================
-- 3. 打完补丁后立刻验一次（用假 IP，不占你真实 IP 的额度）
-- ============================================================
-- 判读方法：purpose 检查是函数里【最前面】的一道，
--   所以只要不再返回「未知用途」，就说明补丁生效了 ——
--   哪怕返回的是「发送太频繁」之类的限频提示，也算通过。
DO $do$
DECLARE
    v_fn   text;
    v_r    jsonb;
    v_msg  text;
BEGIN
    SELECT p.proname INTO v_fn
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prokind = 'f'
       AND p.proname IN ('_orig_store_email_code', 'store_email_code')
     ORDER BY (p.proname = '_orig_store_email_code') DESC, p.oid DESC
     LIMIT 1;

    IF v_fn IS NULL THEN
        RAISE NOTICE '❌ 找不到发码函数,说明部署有问题';
        RETURN;
    END IF;

    EXECUTE format(
        'SELECT public.%I($1,$2,$3,$4)', v_fn)
      INTO v_r
      USING 'nbchannel-test@example.com', 'admin', md5('000000'), '203.0.113.99';

    v_msg := coalesce(v_r ->> 'message', '');
    RAISE NOTICE '函数 % 返回: %', v_fn, v_r;

    IF v_msg LIKE '%未知用途%' OR v_msg LIKE '%unknown purpose%' THEN
        RAISE NOTICE '❌ 补丁没生效 —— purpose 白名单还是挡着 admin';
    ELSE
        RAISE NOTICE '✅ 通过：purpose 检查已放行 admin（后面的限频提示不算问题）';
    END IF;

    -- 清理测试数据，别占「每天 5 次」的额度
    DELETE FROM public.email_codes
     WHERE purpose = 'admin'
       AND (ip_address = '203.0.113.99' OR email = 'nbchannel-test@example.com');
    RAISE NOTICE '🧹 测试记录已清理';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ 调用出错: %', SQLERRM;
END
$do$;
