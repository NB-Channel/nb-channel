-- ============================================================
--  安全加固总验收 —— 一次跑完，一张表看完
--
--  这一轮从「他钱太多会有什么后果」这个问题出发，陆续修了十来处。
--  这个查询把所有加固项合成一张表，随时可以重跑确认状态。
--
--  全部只读，不改任何东西。跑完把整张表发我即可。
-- ============================================================

SELECT 检查项, 详情, 结论 FROM (

-- 1. Storage 有没有「匿名/任意登录用户能删文件」的策略
SELECT 1 AS 序, '① Storage 危险删除策略' AS 检查项,
       count(*)::text || ' 条' AS 详情,
       CASE WHEN count(*) = 0 THEN '✅ 已清理'
            ELSE '❌ 还能被人删文件' END AS 结论
  FROM pg_policies
 WHERE schemaname = 'storage' AND tablename = 'objects'
   AND cmd IN ('DELETE','UPDATE')
   AND (qual IS NULL OR qual::text = 'true')

UNION ALL

-- 2. _orig_* 内部实现还敞着几个
SELECT 2, '② 匿名可调的 _orig_ 内部函数',
       count(*)::text || ' 个',
       CASE WHEN count(*) = 0 THEN '✅ 全锁住' ELSE '❌ 还有敞开的' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND (p.proname LIKE '\_orig\_%' OR p.proname LIKE '%\_orig\_%')
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))

UNION ALL

-- 3. 无 session 的旧重载还敞着几个
SELECT 3, '③ 无鉴权的旧重载',
       count(*)::text || ' 个',
       CASE WHEN count(*) = 0 THEN '✅ 全锁住' ELSE '❌ 还有敞开的' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND position('p_session' in pg_get_function_identity_arguments(p.oid)) = 0
   AND position('p_token'   in pg_get_function_identity_arguments(p.oid)) = 0
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
   AND EXISTS (SELECT 1 FROM pg_proc q JOIN pg_namespace m ON m.oid = q.pronamespace
                WHERE m.nspname = 'public' AND q.prokind = 'f'
                  AND q.proname = p.proname
                  AND position('p_session' in pg_get_function_identity_arguments(q.oid)) > 0)
   AND p.proname NOT LIKE '\_orig\_%' AND p.proname NOT LIKE '%\_orig\_%'

UNION ALL

-- 4. 内部辅助函数还敞着几个
SELECT 4, '④ 匿名可调的内部辅助函数',
       count(*)::text || ' 个',
       CASE WHEN count(*) = 0 THEN '✅ 全锁住' ELSE '❌ 还有敞开的' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('_credit_gain_on_repay','_holder_ratio','_loan_force_collect',
                     '_stock_allowed','comments_guard','_loan_alert_early',
                     'random_fluctuate_market_values','record_daily_kline',
                     'run_auto_support','sample_market_snapshot')
   AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))

UNION ALL

-- 5. 备份表还敞着几张
SELECT 5, '⑤ 备份表的表级权限',
       count(*)::text || ' 张',
       CASE WHEN count(*) = 0 THEN '✅ 已收回' ELSE '❌ 还有敞开的' END
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
   AND (c.relname LIKE '\_%bak%' OR c.relname LIKE '\_func\_backup%'
        OR c.relname LIKE '\_evidence\_%' OR c.relname LIKE '%\_backup%'
        OR c.relname LIKE '\_policy\_backup%' OR c.relname LIKE '\_credit\_loan\_backup%')
   AND (has_table_privilege('anon', c.oid, 'SELECT')
     OR has_table_privilege('anon', c.oid, 'INSERT')
     OR has_table_privilege('authenticated', c.oid, 'SELECT')
     OR has_table_privilege('authenticated', c.oid, 'INSERT'))

UNION ALL

-- 6. SECURITY DEFINER 缺 search_path 的
SELECT 6, '⑥ SECURITY DEFINER 缺 search_path',
       count(*)::text || ' 个',
       CASE WHEN count(*) = 0 THEN '✅ 全固定了' ELSE '❌ 还有没固定的' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
   AND NOT EXISTS (SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) c
                    WHERE c LIKE 'search\_path=%')

UNION ALL

-- 7. 管理员密码那个函数固定了没
SELECT 7, '⑦ check_admin_password_plain',
       COALESCE((SELECT array_to_string(p.proconfig, ', ')
                   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'public' AND p.proname = 'check_admin_password_plain'
                  LIMIT 1), '（没固定）'),
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname = 'public' AND p.proname = 'check_admin_password_plain'
                            AND EXISTS (SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) c
                                         WHERE c LIKE 'search\_path=%'))
            THEN '✅ 已固定' ELSE '❌ 没固定' END

UNION ALL

-- 8. admin_config 的读策略（密码那个 key 不能被读）
SELECT 8, '⑧ admin_config 读策略',
       COALESCE((SELECT string_agg(polname || ' → ' || COALESCE(pg_get_expr(polqual, polrelid), 'true'), '; ')
                   FROM pg_policy WHERE polrelid = 'public.admin_config'::regclass), '（没有策略）'),
       CASE WHEN EXISTS (SELECT 1 FROM pg_policy
                          WHERE polrelid = 'public.admin_config'::regclass
                            AND (polqual IS NULL OR pg_get_expr(polqual, polrelid) = 'true'))
            THEN '🔴 有人能读全部（含密码）' ELSE '✅ 密码 key 读不到' END

UNION ALL

-- 9. pay_dividend 重载数与鉴权
SELECT 9, '⑨ pay_dividend 重载与鉴权',
       (SELECT count(*)::text || ' 个重载，' ||
               CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                  WHERE n.nspname = 'public' AND p.proname = 'pay_dividend'
                                    AND pg_get_functiondef(p.oid) LIKE '%_user_ok%')
                    THEN '带鉴权' ELSE '无鉴权' END
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'pay_dividend'),
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.proname = 'pay_dividend') = 1
             AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname = 'public' AND p.proname = 'pay_dividend'
                            AND pg_get_functiondef(p.oid) LIKE '%_user_ok%')
            THEN '✅ 已加鉴权且无后门' ELSE '❌ 有问题' END

UNION ALL

-- 10. 银行四道闸
SELECT 10, '⑩ 银行：存款/贷款/利息上限',
       (SELECT count(*)::text || ' / 6 道闸'
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('_orig_bank_deposit','_orig_bank_fixed_deposit',
                             '_orig_bank_loan','_orig_bank_credit_loan',
                             '_orig_get_bank_account','bank_daily_settle')
           AND (pg_get_functiondef(p.oid) LIKE '%存款总额上限%'
             OR pg_get_functiondef(p.oid) LIKE '%绝对上限%'
             OR pg_get_functiondef(p.oid) LIKE '%利息基数封顶%'
             OR pg_get_functiondef(p.oid) LIKE '%display_cap%')),
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public'
                     AND p.proname IN ('_orig_bank_deposit','_orig_bank_fixed_deposit',
                                       '_orig_bank_loan','_orig_bank_credit_loan',
                                       '_orig_get_bank_account','bank_daily_settle')
                     AND (pg_get_functiondef(p.oid) LIKE '%存款总额上限%'
                       OR pg_get_functiondef(p.oid) LIKE '%绝对上限%'
                       OR pg_get_functiondef(p.oid) LIKE '%利息基数封顶%'
                       OR pg_get_functiondef(p.oid) LIKE '%display_cap%')) = 6
            THEN '✅ 6 道闸全装好' ELSE '❌ 有缺失' END

UNION ALL

-- 11. update_support_rule 是不是新版
SELECT 11, '⑪ update_support_rule',
       (SELECT count(*)::text || ' 个重载，' ||
               CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                  WHERE n.nspname = 'public' AND p.proname = 'update_support_rule'
                                    AND pg_get_functiondef(p.oid) LIKE '%SET price_target = p_price_target%')
                    THEN '写 price_target' ELSE '还在写 threshold' END
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'update_support_rule'),
       CASE WHEN (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.proname = 'update_support_rule') = 1
             AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname = 'public' AND p.proname = 'update_support_rule'
                            AND pg_get_functiondef(p.oid) LIKE '%SET price_target = p_price_target%')
            THEN '✅ 已是新版' ELSE '❌ 还是旧版' END

UNION ALL

-- 12. 收税是不是按市值
SELECT 12, '⑫ collect_company_tax 收税基准',
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname = 'public' AND p.proname = 'collect_company_tax'
                            AND pg_get_functiondef(p.oid) LIKE '%total_shares%')
            THEN '按市值（公式里有 total_shares）' ELSE '按公司账上' END,
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname = 'public' AND p.proname = 'collect_company_tax'
                            AND pg_get_functiondef(p.oid) LIKE '%total_shares%')
            THEN '✅ 已改成市值' ELSE '⚠️ 还是按账上' END

) t ORDER BY 序;


-- ============================================================
--  每行该是什么样
-- ============================================================
--  ① Storage 危险删除策略        0 条          ✅ 已清理
--  ② 匿名可调的 _orig_ 内部函数    0 个          ✅ 全锁住
--  ③ 无鉴权的旧重载              0 个          ✅ 全锁住
--  ④ 匿名可调的内部辅助函数        0 个          ✅ 全锁住
--  ⑤ 备份表的表级权限            0 张          ✅ 已收回
--  ⑥ SECURITY DEFINER 缺 search_path  0 个     ✅ 全固定了
--  ⑦ check_admin_password_plain   search_path=public, pg_temp   ✅ 已固定
--  ⑧ admin_config 读策略          admin_config_public_read → (key='announcement')   ✅ 密码 key 读不到
--  ⑨ pay_dividend 重载与鉴权      1 个重载，带鉴权   ✅ 已加鉴权且无后门
--  ⑩ 银行：存款/贷款/利息上限      6 / 6 道闸     ✅ 已装好
--  ⑪ update_support_rule         1 个重载，写 price_target   ✅ 已是新版
--  ⑫ collect_company_tax 收税基准  按市值        ✅ 已改成市值
--
--  哪一行不是 ✅，把那一行的「详情」发我，我针对性处理。
-- ============================================================
