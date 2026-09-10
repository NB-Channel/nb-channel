-- ============================================================
-- 补漏:verified_users 与 reports 的 UPDATE 权限还开着
-- 实测:PATCH verified_users / reports → 204(匿名可改)
--   verified_users 被改 = 谁都能给自己加"官方蓝标"冒充认证
--   reports 被改 = 举报内容/状态可被篡改
-- 处理:作品举报改成令牌 RPC;两张表写权限全收
-- 执行顺序:先让前端上线(已推送),再跑本文件
-- ============================================================

-- ---------- 1) 作品举报 RPC(令牌校验 + 去重 + 限频) ----------
CREATE OR REPLACE FUNCTION public.submit_product_report(
    p_user_id uuid, p_session text, p_product_id bigint, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_n int;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('ok', false, 'message', '鉴权失败:请重新登录');
    END IF;
    p_reason := trim(coalesce(p_reason, ''));
    IF length(p_reason) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '请填写举报原因');
    END IF;
    IF length(p_reason) > 100 THEN
        RETURN jsonb_build_object('ok', false, 'message', '举报原因不能超过100字');
    END IF;

    -- 同一作品只能举报一次
    SELECT count(*) INTO v_n FROM public.reports
     WHERE product_id = p_product_id AND reporter_user_id = p_user_id;
    IF v_n > 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', '你已经举报过该作品,管理员会尽快处理');
    END IF;

    -- 每人每天最多 20 次举报(表里没有 created_at 就自动跳过)
    BEGIN
        SELECT count(*) INTO v_n FROM public.reports
         WHERE reporter_user_id = p_user_id AND created_at > now() - interval '1 day';
        IF v_n >= 20 THEN
            RETURN jsonb_build_object('ok', false, 'message', '今日举报次数已达上限');
        END IF;
    EXCEPTION WHEN undefined_column THEN
        NULL;
    END;

    INSERT INTO public.reports (target_type, product_id, reporter_user_id, reason)
    VALUES ('product', p_product_id, p_user_id, p_reason);

    RETURN jsonb_build_object('ok', true, 'message', '举报已提交,感谢维护社区环境');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'message', SQLERRM);
END
$fn$;
GRANT EXECUTE ON FUNCTION public.submit_product_report(uuid, text, bigint, text) TO anon;

-- ---------- 2) 收口这两张表的写权限(读保持) ----------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.verified_users FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.reports        FROM anon, authenticated;

-- ---------- 3) 权威验收:全库 anon 权限总表(增/改/删三列应全 false) ----------
SELECT c.relname AS 表名,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'SELECT') AS 读,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'INSERT') AS 增,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'UPDATE') AS 改,
       has_table_privilege('anon', 'public.' || quote_ident(c.relname), 'DELETE') AS 删
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public'
   AND c.relkind IN ('r', 'p')
 ORDER BY 增 DESC, 改 DESC, 删 DESC, c.relname;
