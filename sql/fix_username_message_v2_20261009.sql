-- ============================================================
--  收尾：把用户名白名单的【报错文案】也改过来（修正版）
--
--  【上一版为什么报 42809】
--      ERROR: 42809: "array_agg" is an aggregate function
--
--  原因：pg_get_functiondef() 只能用于【普通函数】，碰到聚合函数就报错。
--  上一版的筛法完全依赖它：
--
--      WHERE n.nspname = 'public'
--        AND pg_get_functiondef(p.oid) LIKE '%用户名只能包含中文、字母和数字%'
--
--  这句会对 public 下的【每一个】函数求值 —— 包括聚合函数 array_agg，
--  一撞上就 42809。
--
--  （其它脚本也用了 pg_get_functiondef，但它们都先用 proname 过滤，
--    比如 proname IN (...) 或 proname LIKE 'bank%'，
--    所以轮不到在聚合上求值。只有这一版是纯按内容筛的，才踩到。）
--
--  【改法】
--  所有查 pg_proc 的地方都加上 p.prokind = 'f' ——
--  只取普通函数，把聚合函数、窗口函数、存储过程都排除掉。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看有几处旧文案
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    (length(pg_get_functiondef(p.oid))
     - length(replace(pg_get_functiondef(p.oid),
                      '用户名只能包含中文、字母和数字', '')))
      / length('用户名只能包含中文、字母和数字') AS 旧文案处数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'                                    -- ⭐ 排除聚合
   AND pg_get_functiondef(p.oid) LIKE '%用户名只能包含中文、字母和数字%'
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：替换文案
-- ============================================================
DO $$
DECLARE
    r record;
    v_src text;
    v_new text;
    v_cnt int := 0;
    v_old CONSTANT text := '用户名只能包含中文、字母和数字';
    v_new_msg CONSTANT text := '用户名只能包含中文、字母、数字和常用符号';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname, pg_get_functiondef(p.oid) AS src
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.prokind = 'f'                            -- ⭐ 排除聚合
           AND position(v_old in pg_get_functiondef(p.oid)) > 0
         ORDER BY p.proname
    LOOP
        v_src := r.src;
        v_new := replace(v_src, v_old, v_new_msg);

        IF v_new = v_src THEN
            RAISE NOTICE '⚠️ % 没替换到', r.proname;
            CONTINUE;
        END IF;

        EXECUTE v_new;
        v_cnt := v_cnt + 1;
        RAISE NOTICE '✅ % 的提示文案已更新', r.proname;
    END LOOP;

    RAISE NOTICE '---- 共改了 % 个函数 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================

-- 2.1 旧文案应该一处都不剩
SELECT
    count(*) AS 还带旧文案的函数数,
    CASE WHEN count(*) = 0 THEN '✅ 全改完'
         ELSE '❌ 还有' END AS 结论
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'                                    -- ⭐ 排除聚合
   AND pg_get_functiondef(p.oid) LIKE '%用户名只能包含中文、字母和数字%';

-- 2.2 新文案和字符集都在
SELECT
    p.proname                                 AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%字母、数字和常用符号%'
         THEN '✅ 新文案' ELSE '❌ 旧文案' END  AS 提示文案,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '❌ 未放宽' END  AS 字符集
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'f'                                    -- ⭐ 排除聚合
   AND (p.proname LIKE '%register\_user%' OR p.proname LIKE '%update\_username%')
   AND position('!~' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;

-- 期望：两行都是「✅ 新文案 + ✅ 已放宽」


-- ============================================================
-- 第 3 步：顺手确认 public 下的函数类型分布
-- ============================================================
-- 看看除了普通函数，还有没有别的类型（这就是 42809 的来源）
SELECT
    CASE p.prokind
        WHEN 'f' THEN 'f 普通函数'
        WHEN 'a' THEN 'a 聚合函数 ← pg_get_functiondef 对它无效'
        WHEN 'w' THEN 'w 窗口函数 ← 同上'
        WHEN 'p' THEN 'p 存储过程'
        ELSE p.prokind::text
    END                          AS 类型,
    count(*)                     AS 个数,
    string_agg(p.proname, ', ' ORDER BY p.proname) AS 举例
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
 GROUP BY p.prokind
 ORDER BY p.prokind;

-- 期望：大部分是 f；如果看到 a 那一行，就是这次报错的来源


-- ============================================================
-- 第 4 步：自测（可选）
-- ============================================================
-- 去登录页试注册【非法】的名字：
--      'a b'   → 应提示「用户名只能包含中文、字母、数字和常用符号」
--      'a@b'   → 同上
-- 再试【合法】的带符号名字：
--      'NB-搞事局'   '★小明★'   → 应能注册
-- ============================================================
