-- ============================================================
--  管理员会话：30 分钟 → 2 小时
--
--  【改哪儿】
--      admin_create_session 里有【两处】发会话的地方：
--          ① 本地直通那条通道（密码 + 本地密钥）
--          ② 邮箱验证码那条通道
--      两处都是 now() + interval '30 minutes'，一起改成 2 hours。
--
--  【怎么改】
--      不去整段重写函数 —— 那要贴几百行，容易抄错。
--      用 replace() 把 pg_get_functiondef() 里的
--          now() + interval '30 minutes'
--      换成
--          now() + interval '2 hours'
--      再 EXECUTE 回去。
--
--      ⚠️ 锚点特意带上前后文（now() + interval …）——
--         只写 '30 minutes' 的话，万一将来函数里别处也用到 30 分钟
--         （比如限频窗口），会被一起改掉。
--
--  【附带】
--      admin_check_session 不用动 —— 它是拿 expires_at 和 now() 比，
--      会话能活多久只取决于签发时写进去的那个时间。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：改之前，看现在写的是多久
-- ============================================================
SELECT (regexp_matches(pg_get_functiondef(p.oid),
                       'now\(\) \+ interval ''[^'']+''', 'g'))[1] AS 现在发会话的写法
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'admin_create_session';


-- ============================================================
-- 第 2 步：把 30 minutes 换成 2 hours
-- ============================================================
DO $$
DECLARE
    r      record;
    v_src  text;
    v_new  text;
    v_hit  integer := 0;
    v_n    integer;
BEGIN
    FOR r IN
        SELECT p.oid, pg_get_functiondef(p.oid) AS def
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.prokind = 'f'
           AND p.proname = 'admin_create_session'
    LOOP
        v_src := r.def;

        IF position('now() + interval ''2 hours''' in v_src) > 0
           AND position('now() + interval ''30 minutes''' in v_src) = 0 THEN
            RAISE NOTICE '已经是 2 小时了，跳过';
            CONTINUE;
        END IF;

        -- 数一下有几处，好知道改对没有
        v_n := (length(v_src) - length(replace(v_src, 'now() + interval ''30 minutes''', '')))
               / length('now() + interval ''30 minutes''');

        v_new := replace(v_src,
                         'now() + interval ''30 minutes''',
                         'now() + interval ''2 hours''');

        IF v_new <> v_src THEN
            EXECUTE v_new;
            v_hit := v_hit + 1;
            RAISE NOTICE '改了 % 处（期望 2 处：本地直通 + 邮箱验证码两条通道）', v_n;
        ELSE
            RAISE NOTICE '⚠️ 一处都没替换上 —— 函数的写法和脚本假设的不一样，别当成成功';
        END IF;
    END LOOP;
    RAISE NOTICE '处理了 % 个 admin_create_session', v_hit;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
SELECT (regexp_matches(pg_get_functiondef(p.oid),
                       'now\(\) \+ interval ''[^'']+''', 'g'))[1] AS 改完之后的写法
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.proname = 'admin_create_session';

-- 期望看到两行，都是：now() + interval '2 hours'


-- ============================================================
--  跑完之后
-- ============================================================
--  · 后台登录一次，能用 2 小时
--  · 已经签发的老会话不受影响（它们的 expires_at 早就写好了）
--  · 想改别的时长：把上面那段 SQL 里的 2 hours 换掉重跑
--
--  ⚠️ 还有两处【只是文字】，要改的话在 __admin__.html 里：
--      行 789   注释「30分钟有效」
--      行 2393  '已登录(30 分钟有效)'
--     这两处不影响功能，只影响显示。
-- ============================================================
