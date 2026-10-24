-- ============================================================
-- 注册公司查重:公司名已被占用时拒绝注册
-- 说明:只在「新注册」时拦截,已有的重名公司不做处理(保持现状)。
--       比较时忽略大小写和首尾空格(Utw / utw / " Utw " 视为同一个名字)。
-- 在 Supabase SQL Editor 执行(幂等,重复执行会跳过)
-- ============================================================

DO $$
DECLARE
    v_ident text;
    v_args  text;
    v_ret   text;
    v_names text;
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = '_orig_nodup_register_company')
    THEN
        RAISE NOTICE '已加过查重包装,跳过';
        RETURN;
    END IF;

    SELECT pg_get_function_identity_arguments(p.oid),
           pg_get_function_arguments(p.oid),
           pg_get_function_result(p.oid)
      INTO v_ident, v_args, v_ret
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'register_company';

    IF v_ident IS NULL THEN
        RAISE EXCEPTION '没找到 public.register_company 函数';
    END IF;

    SELECT string_agg(split_part(trim(x), ' ', 1), ', ')
      INTO v_names
      FROM unnest(string_to_array(v_args, ',')) AS x
     WHERE trim(x) <> '';

    -- 把现有函数改名保留,新函数在前面加查重
    EXECUTE format('ALTER FUNCTION public.register_company(%s) RENAME TO _orig_nodup_register_company', v_ident);
    EXECUTE format('REVOKE ALL ON FUNCTION public._orig_nodup_register_company(%s) FROM PUBLIC, anon, authenticated', v_ident);

    EXECUTE format(
        'CREATE FUNCTION public.register_company(%s) RETURNS %s '
     || 'LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $w$ '
     || 'BEGIN '
     || '  IF p_company_name IS NULL OR btrim(p_company_name) = '''' THEN '
     || '    RETURN jsonb_build_object(''success'', false, ''message'', ''请填写公司名称''); '
     || '  END IF; '
     || '  IF EXISTS (SELECT 1 FROM public.user_companies '
     || '              WHERE lower(btrim(company_name)) = lower(btrim(p_company_name))) THEN '
     || '    RETURN jsonb_build_object(''success'', false, ''message'', '
     || '      ''公司名「'' || btrim(p_company_name) || ''」已被占用,请换一个名字''); '
     || '  END IF; '
     || '  RETURN public._orig_nodup_register_company(%s); '
     || 'END $w$',
        v_args, v_ret, v_names);

    EXECUTE format('GRANT EXECUTE ON FUNCTION public.register_company(%s) TO anon', v_ident);
    RAISE NOTICE '✅ 公司名查重已启用(忽略大小写与首尾空格)';
END $$;

-- ---------- 验收 ----------
-- 1) 包装后的签名(应保留原来的 p_session 参数)
SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('register_company', '_orig_nodup_register_company')
 ORDER BY 1;

-- 2) 拿一个已存在的名字试一下(把 'Utw' 换成任意已存在的公司名,应返回「已被占用」)
SELECT public.register_company(
    (SELECT id FROM public.profiles LIMIT 1),
    (SELECT company_name FROM public.user_companies LIMIT 1),
    false,
    NULL
) AS 用已存在名字注册的结果;
