-- ============================================================
-- trace_attacker.sql —— 用 SQL 把攻击者(小NB官号)留下的所有痕迹挖出来
-- 在 Supabase SQL Editor 整段运行(会创建 2 个临时排查函数,最后有 DROP)
-- ============================================================

-- ---------- A) 全库哪些字段可能存 IP ----------
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (column_name ILIKE '%ip%' OR column_name ILIKE '%addr%'
       OR column_name ILIKE '%agent%' OR column_name ILIKE '%device%')
ORDER BY table_name, column_name;

-- ---------- B) 排查函数:某 ID 出现在哪些表/字段 ----------
CREATE OR REPLACE FUNCTION public.debug_find_uuid(p_id text)
RETURNS TABLE(tbl text, col text, n bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE r record; c bigint;
BEGIN
    FOR r IN
        SELECT c2.table_name AS t, c2.column_name AS cn
        FROM information_schema.columns c2
        JOIN information_schema.tables t2
          ON t2.table_schema = c2.table_schema AND t2.table_name = c2.table_name
         AND t2.table_type = 'BASE TABLE'
        WHERE c2.table_schema = 'public'
          AND c2.data_type IN ('uuid', 'text', 'character varying', 'jsonb', 'json')
    LOOP
        BEGIN
            EXECUTE format('SELECT count(*) FROM public.%I WHERE %I::text ILIKE %L',
                           r.t, r.cn, '%' || p_id || '%') INTO c;
            IF c > 0 THEN
                tbl := r.t; col := r.cn; n := c; RETURN NEXT;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL;   -- 跳过没有权限/类型不兼容的表
        END;
    END LOOP;
END
$fn$;

-- ---------- C) 排查函数:某 ID 关联到的 IP ----------
CREATE OR REPLACE FUNCTION public.debug_find_ip_for_user(p_id text)
RETURNS TABLE(tbl text, col text, ip text, n bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE r record; ic record; c bigint;
BEGIN
    -- 外层:每个「含 ip 字段的表 + 那个 ip 字段名」
    FOR r IN
        SELECT c2.table_name AS t, c2.column_name AS ipcol
        FROM information_schema.columns c2
        JOIN information_schema.tables t2
          ON t2.table_schema = c2.table_schema AND t2.table_name = c2.table_name
         AND t2.table_type = 'BASE TABLE'
        WHERE c2.table_schema = 'public' AND c2.column_name ILIKE '%ip%'
          AND c2.data_type IN ('text', 'character varying', 'inet')
    LOOP
        -- 内层:表里其它能装 UUID 的字段,拿它去匹配目标 ID
        FOR ic IN
            SELECT c3.column_name AS cn
            FROM information_schema.columns c3
            WHERE c3.table_schema = 'public' AND c3.table_name = r.t
              AND c3.data_type IN ('uuid', 'text', 'character varying')
              AND c3.column_name <> r.ipcol
        LOOP
            BEGIN
                EXECUTE format(
                    'SELECT %I::text, count(*) FROM public.%I WHERE %I::text ILIKE %L GROUP BY 1 ORDER BY 2 DESC LIMIT 20',
                    r.ipcol, r.t, ic.cn, '%' || p_id || '%') INTO ip, c;
                IF c IS NOT NULL THEN
                    tbl := r.t; col := r.t || '.' || r.ipcol || ' via ' || ic.cn;
                    n := c; RETURN NEXT;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END LOOP;
    END LOOP;
END
$fn$;

-- 调试函数绝对不能给匿名用户执行(否则任何人都能反查 IP)
REVOKE ALL ON FUNCTION public.debug_find_uuid(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.debug_find_ip_for_user(text) FROM PUBLIC, anon, authenticated;

-- ---------- 1) 攻击者的 ID 在库里留过痕的所有位置 ----------
SELECT * FROM public.debug_find_uuid('593b7c94-2829-401e-980c-55c9257ff8cd');

-- ---------- 2) 攻击者的 ID 关联到的 IP(有就说明挖到了) ----------
SELECT * FROM public.debug_find_ip_for_user('593b7c94-2829-401e-980c-55c9257ff8cd');

-- ---------- 3) 可疑关联账号一起查 ----------
SELECT * FROM public.debug_find_ip_for_user('ea24ed9e-6584-4d8b-84b6-36f594200888');
SELECT * FROM public.debug_find_uuid('ea24ed9e-6584-4d8b-84b6-36f594200888');

-- ---------- 4) 库里有史以来见过的所有 IP(全表汇总) ----------
SELECT 'registration_attempts' AS src, ip_address AS ip, created_at FROM public.registration_attempts
UNION ALL
SELECT 'api_logs', ip, ts FROM public.api_logs
UNION ALL
SELECT 'email_codes', ip_address, created_at FROM public.email_codes
UNION ALL
SELECT 'admin_login_attempts', ip_address, created_at FROM public.admin_login_attempts
ORDER BY created_at DESC
LIMIT 300;

-- ---------- 5) 账号 ← 注册 IP 对照表(用注册时间近似匹配) ----------
SELECT p.username, p.id, p.created_at, p.is_banned,
       (SELECT r.ip_address FROM public.registration_attempts r
         WHERE r.created_at <= p.created_at
           AND r.created_at > p.created_at - interval '5 minutes'
         ORDER BY r.created_at DESC LIMIT 1) AS likely_ip
FROM public.profiles p
ORDER BY p.created_at DESC
LIMIT 100;

-- ---------- 6) 攻击者 / 高相似账号的对照 ----------
SELECT p.username, p.id, p.created_at, p.is_banned, p.banned_reason,
       (SELECT r.ip_address FROM public.registration_attempts r
         WHERE r.created_at <= p.created_at
           AND r.created_at > p.created_at - interval '5 minutes'
         ORDER BY r.created_at DESC LIMIT 1) AS likely_ip
FROM public.profiles p
WHERE p.id IN ('593b7c94-2829-401e-980c-55c9257ff8cd',
               'ea24ed9e-6584-4d8b-84b6-36f594200888')
   OR p.username ILIKE '%小NB%'
   OR p.username ILIKE '%小Na%'
ORDER BY p.created_at DESC;

-- ============================================================
-- 排查完删掉临时函数(下次要查再跑本文件即可)
-- DROP FUNCTION IF EXISTS public.debug_find_uuid(text);
-- DROP FUNCTION IF EXISTS public.debug_find_ip_for_user(text);
-- ============================================================
