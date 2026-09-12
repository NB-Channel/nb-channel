-- ============================================================
-- 修复「旧密码校验」的 NULL 短路(和验证码那个是同一类缺陷)
--
-- 问题:update_username / update_password 这类函数里,旧密码是这样校验的:
--         IF encode(sha256(concat(stored_salt, old_password)::bytea),'hex') != stored_hash THEN
--             RETURN '密码错误';
--         END IF;
--       如果某账号的 password_hash 是 NULL(SQL 里 NULL != 任何值 的结果是 NULL,
--       不是 true),PL/pgSQL 的 IF 只在 true 时进入 → **跳过报错分支**,
--       于是「随便输个旧密码」也算通过。
--
--       影响:已登录用户改密码 / 改用户名时不需要输入正确的旧密码。
--       虽然还要有有效会话才能调用,但这条校验形同虚设,必须修。
--
-- 修法:扫描所有引用 stored_hash 的函数,把这种比较统一改成
--       「先判 NULL,再比较」。每个函数单独 try,一个失败不影响其他。
-- 在 Supabase SQL Editor 执行(幂等)
-- ============================================================

DO $$
DECLARE
    r      record;
    v_def  text;
    v_new  text;
    v_cnt  int := 0;
    v_skip int := 0;
    v_keep int := 0;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND pg_get_functiondef(p.oid) LIKE '%stored_hash%'
    LOOP
        v_def := pg_get_functiondef(r.oid);
        v_new := v_def;

        -- ① sha256(salt + 旧密码) != stored_hash
        v_new := regexp_replace(
            v_new,
            'IF\s+encode\(sha256\(concat\(stored_salt,\s*old_password\)::bytea\),\s*''hex''\)\s*!=\s*stored_hash\s+THEN',
            'IF stored_hash IS NULL OR stored_salt IS NULL OR encode(sha256(concat(stored_salt, old_password)::bytea), ''hex'') != stored_hash THEN',
            'gi');

        -- ② 其它形式:xxx != stored_hash(不含上面的)
        v_new := regexp_replace(
            v_new,
            'IF\s+(?!stored_hash IS NULL)([a-zA-Z0-9_\.\(\)'',:\s]+?)\s*!=\s*stored_hash\s+THEN',
            'IF stored_hash IS NULL OR \1 != stored_hash THEN',
            'gi');

        IF v_new <> v_def THEN
            BEGIN
                EXECUTE v_new;
                v_cnt := v_cnt + 1;
                RAISE NOTICE '✅ 已修复: %', r.proname;
            EXCEPTION WHEN OTHERS THEN
                v_skip := v_skip + 1;
                RAISE NOTICE '⚠️ 跳过 %: %', r.proname, SQLERRM;
            END;
        ELSE
            v_keep := v_keep + 1;
            RAISE NOTICE 'ℹ️ % 无需改动(可能已判空,或写法不同,建议人工看一眼)', r.proname;
        END IF;
    END LOOP;
    RAISE NOTICE '---- 完成:修复 % 个,跳过 % 个,无需改动 % 个 ----', v_cnt, v_skip, v_keep;
END $$;

-- ---------- 验收 ----------
-- 每个相关函数的当前状态:已判空 = true 才算修好;还残留旧写法 = true 说明没改到
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%stored_hash IS NULL%') AS 已判空,
       (pg_get_functiondef(p.oid) ~ '!\=\s*stored_hash\s+THEN')  AS 还残留旧写法
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND pg_get_functiondef(p.oid) LIKE '%stored_hash%'
 ORDER BY 1;

-- 顺便看看有没有账号根本没有密码哈希(这些账号就是上面的隐患来源)
SELECT count(*) FILTER (WHERE password_hash IS NULL OR password_hash = '') AS 无密码哈希的账号,
       count(*) FILTER (WHERE salt IS NULL OR salt = '')                    AS 无盐的账号,
       count(*) AS 账号总数
  FROM public.profiles;
