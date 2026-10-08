-- ============================================================
--  用户名放宽：允许一批常用符号
--
--  【原来是什么样】
--  只允许中文（CJK基本区）、字母、数字：
--
--      IF clean_name !~ ('^[' || chr(19968) || '-' || chr(40869) || 'a-zA-Z0-9]+$') THEN
--          ... '用户名只能包含中文、字母和数字'
--
--  这么严是有原因的（changelog 里写着）：
--      「从根源杜绝一切仿冒字符（希腊/西里尔/科普特/全角等变体）」
--  也就是防止有人用 а（西里尔 a）冒充 admin 这种。
--
--  【这次放开什么】
--  放的是一批【不会造成仿冒】的符号。仿冒靠的是「长得像字母的字符」，
--  符号不解决这个问题，所以放开符号不会重新打开仿冒口子。
--
--  放开：
--      - _ . + ~ ! ? , : ; # % ^ * ( ) [ ] =
--      ★ ☆ ♪ ♫ ♥ ❤ ✿ ❀ ※ · × ÷ ± ≈ ≠ ≤ ≥ ∞ °
--      ← → ↑ ↓ ▲ △ ▼ ▽ ● ○ ◆ ◇ ■ □
--
--  仍然禁止（每条都有理由）：
--      @        会破坏「@某人」的提及解析（@a@b 会被拆错）
--      空格     前后空格会让「查找用户」和「唯一性判断」出问题
--      < > & " '   HTML 注入 / XSS 风险 ——
--                 站里绝大多数地方用了 escapeHtml，但只要有【一处】漏了，
--                 带这些字符的用户名就是一个存储型 XSS
--      ` $ { }   JavaScript 模板字符串（` 和 ${ 会被当语法）
--      / \ |     路径分隔符 / 转义字符
--
--  【改哪两个函数】
--      register_user(input_username, input_password)             注册
--      update_username(user_id, new_username, old_password)      改名
--
--  注：实际注册走的是 register_finish(p_username, p_password, p_email, p_code)，
--      但它内部会调 register_user：
--          v_uid := public.register_user(p_username, p_password);
--      所以改 register_user 就等于覆盖了注册路径。
--
--  【做法】
--  用 pg_get_functiondef 取出数据库里【当前的】函数源码，
--  把那条白名单判断整句替换掉，再 EXECUTE 回去。
--  函数里其它逻辑一个字不动。
--
--  ⚠️ 匹配不上会 RAISE EXCEPTION 并把实际源码打出来 —— 不会出现
--     「跑完了但其实没改到」。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：看现状
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '❌ 还是旧白名单' END AS 状态
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('register_user', 'update_username')
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：替换白名单
-- ============================================================
DO $$
DECLARE
    r record;
    v_src text;
    v_new text;
    v_cnt int := 0;
    -- 新白名单。注意 [] 里的几个转义点：
    --   [ 和 ] 在正则字符类里要转义；这里写 \\[ \\] 是因为
    --   regexp_replace 的【替换串】里 \\ 代表一个字面反斜杠，
    --   到了函数源码里就变成 \[ \] 两个字面字符。
    --   末尾那个 - 放在最后，就是字面减号（不放最后会被当区间）
    v_pat CONSTANT text :=
        'IF clean_name !~ (''^[一-龥a-zA-Z0-9_.+~!?,:;#%^*()\\[\\]='
     || '★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$'') THEN';
BEGIN
    FOR r IN
        SELECT p.oid, p.proname
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname IN ('register_user', 'update_username')
    LOOP
        v_src := pg_get_functiondef(r.oid);

        IF v_src LIKE '%★%' THEN
            RAISE NOTICE '% 已经放宽过了，跳过', r.proname;
            CONTINUE;
        END IF;

        -- 把整条白名单判断（IF ... !~ ... THEN）换掉
        -- ⚠️ 重复次数上界必须 ≤ 255 —— PostgreSQL 的 regex 引擎里
        --    #define DUPMAX 255，超过就报
        --        ERROR: invalid repetition count(s)   (REG_BADBR)
        --    这里实际间隔不到 100 字，200 绰绰有余。
        --    之前把上界写成 400 就是踩了这个，报 invalid repetition count(s)。
        v_new := regexp_replace(v_src,
            'IF\s+clean_name\s*!~\s*[\s\S]{0,200}?THEN',
            v_pat);

        IF v_new = v_src THEN
            RAISE EXCEPTION E'% 里没找到白名单那句，不敢硬改。\n'
                '请把下面这段发给我：\n%',
                r.proname,
                substring(v_src from GREATEST(position('clean_name' in v_src) - 200, 1) for 900);
        END IF;

        EXECUTE v_new;
        v_cnt := v_cnt + 1;
        RAISE NOTICE '✅ % 已放宽白名单', r.proname;
    END LOOP;

    RAISE NOTICE '---- 共改了 % 个函数 ----', v_cnt;
END $$;


-- ============================================================
-- 第 2 步：验证
-- ============================================================

-- 2.1 两个函数都改到了
SELECT
    p.proname                                 AS 函数,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%★%'
         THEN '✅ 已放宽' ELSE '❌ 还是旧的' END AS 状态,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%chr(19968)%'
         THEN '⚠️ 旧白名单还在' ELSE '✅ 旧的已替换' END AS 旧白名单
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('register_user', 'update_username')
 ORDER BY p.proname;

-- 2.2 把替换后的那一句原样打出来看看
SELECT
    p.proname AS 函数,
    substring(pg_get_functiondef(p.oid)
              from GREATEST(position('!~' in pg_get_functiondef(p.oid)) - 60, 1)
              for 320) AS 白名单那句
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('register_user', 'update_username')
   AND position('!~' in pg_get_functiondef(p.oid)) > 0
 ORDER BY p.proname;


-- ============================================================
-- 第 3 步：自测（可选，跑完去页面上试更直接）
-- ============================================================
-- 下面这些【应该】通过（返回 true）：
--
--   SELECT regexp_matches('小明',    '^[一-龥a-zA-Z0-9_.+~!?,:;@#%^*()\[\]=★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$') IS NOT NULL;
--   SELECT regexp_matches('NB-搞事局', '^[一-龥a-zA-Z0-9_.+~!?,:;@#%^*()\[\]=★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$') IS NOT NULL;
--   SELECT regexp_matches('★小明★',  '^[一-龥a-zA-Z0-9_.+~!?,:;@#%^*()\[\]=★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$') IS NOT NULL;
--   SELECT regexp_matches('[NB]小明', '^[一-龥a-zA-Z0-9_.+~!?,:;@#%^*()\[\]=★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$') IS NOT NULL;
--   SELECT regexp_matches('A.B_C+D',  '^[一-龥a-zA-Z0-9_.+~!?,:;@#%^*()\[\]=★☆♪♫♥❤✿❀※·×÷±≈≠≤≥∞°←→↑↓▲△▼▽●○◆◇■□-]+$') IS NOT NULL;
--
-- 下面这些【应该】被拒（返回 false）：
--
--   SELECT regexp_matches('a@b',   '...') IS NOT NULL;   -- @ 仍然禁止
--   SELECT regexp_matches('a b',   '...') IS NOT NULL;   -- 空格仍然禁止
--   SELECT regexp_matches('<b>x',  '...') IS NOT NULL;   -- 尖括号仍然禁止
--   SELECT regexp_matches('a/b',   '...') IS NOT NULL;   -- 斜杠仍然禁止
--
-- 最直接的办法：去登录页试着注册一个带符号的名字。


-- ============================================================
--  前端也要同步（跟着这次提交一起上了）
-- ============================================================
--  前端有 20 处同样的正则（活跃页 5 处 + 归档文件夹 15 处）：
--      /^[\u4e00-\u9fa5a-zA-Z0-9]+$/
--  全部换成放宽后的版本，并把提示文案从
--      「用户名只能包含中文、字母和数字」
--  改成
--      「用户名只能包含中文、字母、数字和常用符号」
--
--  服务端这一步才是真兜底 —— 前端那道只是为了当场给提示。
--
--  ⚠️ 公司名那一套白名单（register_company 里的）这次【没动】，
--     要放开的话另说。
-- ============================================================
