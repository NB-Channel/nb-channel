-- ============================================================
-- audit_accounts.sql —— 账号审计 + 批量封禁删除
-- 第 1 段:只读审计,输出「注册设备(精确IP) → 账号」对照,供站长过目
-- 第 2 段:勾选后执行的批量封禁+删除(默认注释掉,确认后再开)
-- ============================================================

-- ---------- 1) 精确 IP → 账号(同一精确 IP = 同一台设备注册) ----------
WITH m AS (
    SELECT p.username, p.created_at, p.is_banned,
           (SELECT r.ip_address FROM public.registration_attempts r
             WHERE r.created_at BETWEEN p.created_at - interval '2 minutes'
                                     AND p.created_at + interval '2 minutes'
             ORDER BY abs(extract(epoch from (r.created_at - p.created_at))) LIMIT 1) AS ip
      FROM public.profiles p
)
SELECT ip,
       count(*) AS 号数,
       string_agg(username || ' @ ' ||
                  to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'),
                  '  |  ' ORDER BY created_at) AS 账号
  FROM m
 WHERE ip IS NOT NULL
 GROUP BY ip
HAVING count(*) >= 2
 ORDER BY 号数 DESC;

-- ---------- 2) 网段(/64 或 /24)汇总 ----------
WITH m AS (
    SELECT p.username, p.created_at,
           (SELECT r.ip_address FROM public.registration_attempts r
             WHERE r.created_at BETWEEN p.created_at - interval '2 minutes'
                                     AND p.created_at + interval '2 minutes'
             ORDER BY abs(extract(epoch from (r.created_at - p.created_at))) LIMIT 1) AS ip
      FROM public.profiles p
)
SELECT CASE WHEN ip LIKE '%:%'
            THEN regexp_replace(ip, '^(([0-9a-fA-F]+:){4}).*$', '\1::/64')
            ELSE regexp_replace(ip, '^([0-9]+\.[0-9]+\.[0-9]+)\..*$', '\1.0/24')
       END AS 网段,
       count(*) AS 号数,
       string_agg(username || ' @ ' ||
                  to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'MM-DD HH24:MI'),
                  '  |  ' ORDER BY created_at) AS 账号
  FROM m
 WHERE ip IS NOT NULL
 GROUP BY 1
 ORDER BY 号数 DESC;

-- ---------- 3) 当前全部账号(按注册时间,北京时间) ----------
SELECT username, id, to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS 注册时间,
       is_banned AS 已封, banned_reason AS 封禁原因
  FROM public.profiles
 ORDER BY created_at;

-- ============================================================
-- 4) 批量封禁 + 删除(把要处理的用户名填进 v_names 再执行)
--    先看第 1~3 段的输出,确认哪些该删,再取消下面的注释
-- ============================================================
-- DO $$
-- DECLARE
--     v_names text[] := ARRAY['用户名1', '用户名2'];
--     v_ids uuid[];
--     v_company_ids bigint[];
--     v_keep uuid[] := ARRAY[]::uuid[];   -- 千万别删的账号(留空即可)
-- BEGIN
--     SELECT array_agg(id) INTO v_ids FROM public.profiles WHERE username = ANY(v_names);
--     IF v_ids IS NULL THEN RAISE EXCEPTION '没找到任何匹配的用户名'; END IF;
--     IF array_length(v_keep, 1) > 0 THEN
--         v_ids := array(SELECT unnest(v_ids) EXCEPT SELECT unnest(v_keep));
--     END IF;
--     RAISE NOTICE '将处理 % 个账号', array_length(v_ids, 1);
--
--     SELECT array_agg(id) INTO v_company_ids FROM public.user_companies WHERE user_id = ANY(v_ids);
--
--     UPDATE public.profiles SET is_banned = true, banned_reason = '盗号案/仿冒账号,管理员批量清理'
--      WHERE id = ANY(v_ids);
--
--     DELETE FROM public.support_logs WHERE supporter_id = ANY(v_ids)
--         OR company_id = ANY(COALESCE(v_company_ids, ARRAY[]::bigint[]));
--     DELETE FROM public.support_rules WHERE user_id = ANY(v_ids)
--         OR company_id = ANY(COALESCE(v_company_ids, ARRAY[]::bigint[]));
--     DELETE FROM public.holdings WHERE user_id = ANY(v_ids)
--         OR company_id = ANY(COALESCE(v_company_ids, ARRAY[]::bigint[]));
--     DELETE FROM public.transactions WHERE user_id = ANY(v_ids)
--         OR company_id = ANY(COALESCE(v_company_ids, ARRAY[]::bigint[]));
--     DELETE FROM public.stock_daily_kline WHERE company_id = ANY(COALESCE(v_company_ids, ARRAY[]::bigint[]));
--     DELETE FROM public.user_companies WHERE user_id = ANY(v_ids);
--
--     DELETE FROM public.reports WHERE comment_id IN (SELECT id FROM public.comments WHERE user_id = ANY(v_ids));
--     DELETE FROM public.comments WHERE parent_id IN (SELECT id FROM public.comments WHERE user_id = ANY(v_ids));
--     DELETE FROM public.comments WHERE user_id = ANY(v_ids);
--     DELETE FROM public.comment_reactions WHERE user_id = ANY(v_ids);
--
--     DELETE FROM public.notifications WHERE user_id = ANY(v_ids) OR from_user_id = ANY(v_ids);
--     DELETE FROM public.reports WHERE reporter_user_id = ANY(v_ids);
--     DELETE FROM public.product_purchases WHERE buyer_id = ANY(v_ids) OR seller_id = ANY(v_ids);
--     DELETE FROM public.product_downloads WHERE user_id = ANY(v_ids);
--     DELETE FROM public.products WHERE author_id = ANY(v_ids);
--     DELETE FROM public.user_achievements WHERE user_id = ANY(v_ids);
--     DELETE FROM public.user_checkins WHERE user_id = ANY(v_ids);
--     DELETE FROM public.check_in_records WHERE user_id = ANY(v_ids);
--     DELETE FROM public.verified_users WHERE user_id = ANY(v_ids);
--     DELETE FROM public.bank_logs WHERE user_id = ANY(v_ids);
--     DELETE FROM public.bank_accounts WHERE user_id = ANY(v_ids);
--     DELETE FROM public.user_titles WHERE user_id = ANY(v_ids);
--     DELETE FROM public.user_balance_counts WHERE user_id = ANY(v_ids);
--     DELETE FROM public.lottery_records WHERE user_id = ANY(v_ids);
--     DELETE FROM public.transfers WHERE from_user = ANY(v_ids) OR to_user = ANY(v_ids);
--     DELETE FROM public.coin_claims WHERE user_id = ANY(v_ids);
--     DELETE FROM public.messages WHERE sender_id = ANY(v_ids);
--     DELETE FROM public.conversations WHERE user_low = ANY(v_ids) OR user_high = ANY(v_ids);
--     DELETE FROM public.blocked_users WHERE user_id = ANY(v_ids) OR blocked_id = ANY(v_ids);
--     DELETE FROM public.friend_requests WHERE from_user_id = ANY(v_ids) OR to_user_id = ANY(v_ids);
--     DELETE FROM public.friendships WHERE user_a = ANY(v_ids) OR user_b = ANY(v_ids);
--     DELETE FROM public.user_sessions WHERE user_id = ANY(v_ids);
--     DELETE FROM storage.objects WHERE owner = ANY(v_ids);
--
--     RAISE NOTICE '封禁并删除完成(profiles 保留封禁标记)';
-- END $$;
