-- ============================================================
-- 兑换记录「可以删掉（只是不显示）」（2026-09-30）
-- ============================================================
-- 需求：后台能删掉某条兑换记录，但它只是从列表里消失，数据本身留着
--       （万一以后要查账、要追溯，还能捞回来）。
--
-- 做法：给两张记录表都加一个 hidden 标记，不是真删。
--   · 用户自己的「我的兑换记录」不再显示已隐藏的
--   · 后台列表照常显示，但会带上标记，并多一个筛选：显示/隐藏/全部
--   · 后台可以随时「恢复显示」
--
-- 两张表都加：exchange_codes（NB币→U币 的提货码）、
--             u_exchange_requests（U币→NB币 的入账记录）
-- ============================================================


-- ============================================================
-- ① 加字段（不是真删，所以只是加个标记）
-- ============================================================
ALTER TABLE public.u_exchange_requests
    ADD COLUMN IF NOT EXISTS hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.exchange_codes
    ADD COLUMN IF NOT EXISTS hidden boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_u_ex_req_hidden  ON public.u_exchange_requests (hidden);
CREATE INDEX IF NOT EXISTS idx_ex_codes_hidden  ON public.exchange_codes (hidden);


-- ============================================================
-- ② 用户自己的兑换记录：已隐藏的不再返回
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_u_exchange(
    p_user_id uuid, p_session text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_rows jsonb;
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false, 'message', '鉴权失败:会话无效或无权操作,请重新登录');
    END IF;
    SELECT coalesce(jsonb_agg(x), '[]'::jsonb) INTO v_rows FROM (
        SELECT id, u_code, u_amount, nb_amount, status,
               verified, verify_note, reversed,
               to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS created_at
          FROM public.u_exchange_requests
         WHERE user_id = p_user_id
           AND hidden IS NOT TRUE          -- ⭐ 后台隐藏掉的不再显示给用户
         ORDER BY created_at DESC LIMIT 20) x;
    RETURN jsonb_build_object('success', true, 'list', v_rows);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.get_my_u_exchange(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_u_exchange(uuid, text) TO anon;


-- ============================================================
-- ③ 后台列表：多返回一个 hidden 标记 + 支持按它筛选
-- ============================================================
-- ⚠️ 这是在原来那版基础上改的，两个 UNION 分支必须同时加 hidden 列，
--    否则 UNION ALL 会因为列数不一致直接报错。
CREATE OR REPLACE FUNCTION public.admin_list_exchange(
    p_token  text,
    p_kind   text    DEFAULT NULL,   -- 'nb2u' / 'u2nb' / NULL=全部
    p_state  text    DEFAULT NULL,
    p_days   integer DEFAULT 7,
    p_limit  integer DEFAULT 50,
    p_offset integer DEFAULT 0,
    p_hidden text    DEFAULT NULL)   -- ⭐ 新增：'0'=只看未隐藏 '1'=只看已隐藏 NULL=全部
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
    v_days  integer := greatest(1, least(coalesce(p_days, 7), 365));
    v_lim   integer := greatest(1, least(coalesce(p_limit, 50), 200));
    v_off   integer := greatest(0, coalesce(p_offset, 0));
    v_hid   text    := nullif(btrim(coalesce(p_hidden, '')), '');
    v_rows  jsonb;
    v_total integer;
    v_cnt   jsonb;
    v_sum   jsonb;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;

    WITH all_rows AS (
        SELECT 'nb2u'::text AS kind, c.id, p.username, c.code,
               c.nb_amount, c.u_amount, c.fee,
               CASE WHEN c.status = 'cancelled' THEN 'cancelled'
                    WHEN c.status = 'used'      THEN 'used'
                    WHEN c.expires_at < now()   THEN 'expired'
                    ELSE 'pending' END AS state,
               nullif(c.utw_name, '') AS note,
               c.created_at,
               coalesce(c.hidden, false) AS hidden      -- ⭐
          FROM public.exchange_codes c
          LEFT JOIN public.profiles p ON p.id = c.user_id
         WHERE c.created_at >= now() - (v_days || ' days')::interval

        UNION ALL

        SELECT 'u2nb'::text, r.id, p.username, r.u_code,
               (-1) * r.nb_amount, r.u_amount, 0,
               CASE WHEN r.reversed THEN 'reversed'
                    WHEN r.verified THEN 'verified'
                    ELSE 'credited' END,
               r.verify_note,
               r.created_at,
               coalesce(r.hidden, false)                -- ⭐
          FROM public.u_exchange_requests r
          LEFT JOIN public.profiles p ON p.id = r.user_id
         WHERE r.created_at >= now() - (v_days || ' days')::interval
    ),
    filtered AS (
        SELECT * FROM all_rows
         WHERE (p_kind  IS NULL OR kind  = p_kind)
           AND (p_state IS NULL OR state = p_state)
           AND (v_hid IS NULL
                OR (v_hid = '1' AND hidden)
                OR (v_hid = '0' AND NOT hidden))
    )
    SELECT
        (SELECT count(*) FROM filtered),

        (SELECT jsonb_build_object(
            'nb2u',      count(*) FILTER (WHERE kind = 'nb2u'),
            'u2nb',      count(*) FILTER (WHERE kind = 'u2nb'),
            'pending',   count(*) FILTER (WHERE state = 'pending'),
            'used',      count(*) FILTER (WHERE state = 'used'),
            'cancelled', count(*) FILTER (WHERE state = 'cancelled'),
            'expired',   count(*) FILTER (WHERE state = 'expired'),
            'credited',  count(*) FILTER (WHERE state = 'credited'),
            'verified',  count(*) FILTER (WHERE state = 'verified'),
            'reversed',  count(*) FILTER (WHERE state = 'reversed'),
            'hidden',    count(*) FILTER (WHERE hidden)
         ) FROM all_rows),

        (SELECT jsonb_build_object(
            'nb_out', coalesce(sum(nb_amount) FILTER (WHERE kind = 'nb2u' AND state <> 'cancelled'), 0),
            'nb_in',  coalesce(-sum(nb_amount) FILTER (WHERE kind = 'u2nb' AND state <> 'reversed'), 0),
            'fee',    coalesce(sum(fee)       FILTER (WHERE kind = 'nb2u' AND state <> 'cancelled'), 0),
            'u_out',  coalesce(sum(u_amount)  FILTER (WHERE kind = 'nb2u' AND state <> 'cancelled'), 0),
            'u_in',   coalesce(sum(u_amount)  FILTER (WHERE kind = 'u2nb' AND state <> 'reversed'), 0)
         ) FROM all_rows),

        (SELECT coalesce(jsonb_agg(x ORDER BY x.created_at DESC), '[]'::jsonb)
           FROM (SELECT * FROM filtered ORDER BY created_at DESC
                  LIMIT v_lim OFFSET v_off) x)
    INTO v_total, v_cnt, v_sum, v_rows;

    RETURN jsonb_build_object(
        'success', true,
        'days', v_days,
        'total', v_total,
        'counts', v_cnt,
        'sums', v_sum,
        'list', v_rows);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
-- 参数变了，旧签名要删掉，免得留下两个重载
DROP FUNCTION IF EXISTS public.admin_list_exchange(text, text, text, integer, integer, integer);
REVOKE ALL ON FUNCTION public.admin_list_exchange(text, text, text, integer, integer, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_exchange(text, text, text, integer, integer, integer, text) TO anon;


-- ============================================================
-- ④ 隐藏 / 恢复（不是真删）
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_hide_exchange(
    p_kind   text,
    p_id     bigint,
    p_token  text,
    p_hidden boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_n int;
BEGIN
    IF NOT public._admin_token_valid(p_token) THEN
        RETURN jsonb_build_object('success', false, 'message', '无效或过期的管理会话');
    END IF;
    IF p_kind NOT IN ('nb2u', 'u2nb') THEN
        RETURN jsonb_build_object('success', false, 'message', 'kind 只能是 nb2u / u2nb');
    END IF;

    IF p_kind = 'nb2u' THEN
        UPDATE public.exchange_codes SET hidden = coalesce(p_hidden, true) WHERE id = p_id;
    ELSE
        UPDATE public.u_exchange_requests SET hidden = coalesce(p_hidden, true) WHERE id = p_id;
    END IF;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    IF v_n = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '找不到这条记录');
    END IF;
    RETURN jsonb_build_object('success', true, 'hidden', coalesce(p_hidden, true));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_hide_exchange(text, bigint, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_hide_exchange(text, bigint, text, boolean) TO anon;


-- ============================================================
-- 验收
-- ============================================================
SELECT column_name AS 新增字段, data_type, column_default
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name IN ('u_exchange_requests','exchange_codes')
   AND column_name = 'hidden';

SELECT p.proname AS 函数, pg_get_function_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public'
   AND p.proname IN ('get_my_u_exchange','admin_list_exchange','admin_hide_exchange')
   AND p.prokind = 'f'
 ORDER BY 1;
-- 应该是 3 行，且 admin_list_exchange 最后一个参数是 p_hidden text

-- 试试隐藏/恢复（把 p_id 换成真实 id；跑完记得改回去）
-- SELECT public.admin_hide_exchange('u2nb', 1, '<你的管理token>', true);
