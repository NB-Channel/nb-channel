-- ============================================================
--  🔴 pay_dividend 加鉴权 —— 原来靠「参数对得上」冒充身份
--
--  【问题】
--  现在的 pay_dividend(p_user_id, p_company_id, p_amount) 是 anon 可调的，
--  它唯一的身份检查是这一句：
--
--      SELECT founder_id, pool_cash, company_name INTO v_founder, v_cash, v_name
--        FROM public.user_companies WHERE id = p_company_id FOR UPDATE;
--      ...
--      IF v_founder <> p_user_id THEN
--          RETURN ... '只有创始人可以发起分红';
--      END IF;
--
--  它比的是「参数里的 uuid 是不是这家公司的创始人」——
--  但【没有验证调用者就是那个 uuid 本人】。
--
--  攻击方式（service_role/anon key 都在前端，任何人都有）：
--      POST /rest/v1/rpc/pay_dividend
--      {"p_user_id":"<创始人的uuid>","p_company_id":1,"p_amount":999999999}
--  → 通过校验。反复调就能把公司账上掏空、股价砸下来。
--
--  【为什么这个洞特别要紧】
--  分红是把 pool_cash 直接分给所有股东。池子钱少了，股价立刻跌 ——
--  攻击者不需要持有股份也能反复触发，纯粹是破坏性攻击。
--
--  【修法 —— 沿用库里已有的两层结构】
--  这个库对写操作本来就是「鉴权壳 + _orig_ 实体」两层：
--      xxx(p_user_id, p_session, ...)  →  验会话  →  _orig_xxx(p_user_id, ...)
--  pay_dividend 是少数几个漏掉壳的。这次给它补上：
--
--    ① 把现有实现【改名】成 _orig_pay_dividend（实现一个字都不改）
--       并收回 anon/authenticated 的权限
--    ② 新建 4 参数的 pay_dividend 做鉴权，通过后转发给 _orig_
--
--  这样：
--    · 不用重写那 2800 字节的实现 —— 不用担心漏掉某个分支
--    · 前端【一个字都不用改】：它本来就先试带 p_session 的调用，
--      只是因为库里没有这个签名才退回。现在第一次调用就能成
--
--  ⚠️ 关键一步是 DROP / RENAME 掉旧签名。
--     上次 update_support_rule 就是只 CREATE OR REPLACE 没删旧的，
--     结果两个重载并存、旧的还在写死字段。
--     这次用 RENAME 而不是 DROP —— 实现留着，改名后就是内部函数。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 0 步：先看现状
-- ============================================================
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN '🔴 anon 能调' ELSE '—' END AS anon,
    CASE WHEN pg_get_functiondef(p.oid) LIKE '%_user_ok%'
              THEN '有鉴权' ELSE '🔴 没有鉴权' END AS 鉴权
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('pay_dividend', '_orig_pay_dividend')
 ORDER BY p.proname;


-- ============================================================
-- 第 1 步：把现有实现改名成 _orig_pay_dividend
-- ============================================================
DO $$
DECLARE
    v_exists_old boolean;
    v_exists_new boolean;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'public' AND p.proname = 'pay_dividend'
                      AND pg_get_function_identity_arguments(p.oid)
                          = 'p_user_id uuid, p_company_id bigint, p_amount numeric')
      INTO v_exists_old;

    SELECT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'public' AND p.proname = '_orig_pay_dividend')
      INTO v_exists_new;

    IF v_exists_new THEN
        RAISE NOTICE '_orig_pay_dividend 已经存在，跳过改名';

        -- 万一旧的 3 参数版本还在（上次没删干净），这里补删
        IF v_exists_old THEN
            DROP FUNCTION public.pay_dividend(uuid, bigint, numeric);
            RAISE NOTICE '发现残留的旧签名，已删除';
        END IF;
        RETURN;
    END IF;

    IF NOT v_exists_old THEN
        RAISE EXCEPTION '找不到 pay_dividend(uuid, bigint, numeric) —— 先把它的签名发我看看';
    END IF;

    -- 改名（实现完全不动）
    ALTER FUNCTION public.pay_dividend(uuid, bigint, numeric)
        RENAME TO _orig_pay_dividend;

    -- 收回所有人的调用权限（只有壳能调它）
    REVOKE ALL ON FUNCTION public._orig_pay_dividend(uuid, bigint, numeric)
        FROM PUBLIC, anon, authenticated;

    RAISE NOTICE '✅ 原实现已改名成 _orig_pay_dividend 并收回权限';
END $$;


-- ============================================================
-- 第 2 步：新建带鉴权的 pay_dividend
-- ============================================================
CREATE OR REPLACE FUNCTION public.pay_dividend(
    p_user_id    uuid,
    p_company_id bigint,
    p_amount     numeric,
    p_session    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
    IF p_session IS NULL OR NOT public._user_ok(p_user_id, p_session) THEN
        RETURN jsonb_build_object('success', false,
            'message', '登录状态已过期，请重新登录');
    END IF;

    RETURN public._orig_pay_dividend(p_user_id, p_company_id, p_amount);
END
$fn$;

GRANT EXECUTE ON FUNCTION public.pay_dividend(uuid, bigint, numeric, text)
    TO anon, authenticated;


-- ============================================================
-- 第 3 步：验证
-- ============================================================

-- 3.1 结构对不对
SELECT
    p.proname                                 AS 函数,
    pg_get_function_identity_arguments(p.oid) AS 参数,
    length(pg_get_functiondef(p.oid))         AS 源码长度,
    CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE')
              THEN 'anon 能调' ELSE 'anon 不能调' END AS anon,
    CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE')
              THEN 'auth 能调' ELSE 'auth 不能调' END AS authenticated,
    CASE WHEN EXISTS (SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) c
                       WHERE c LIKE 'search\_path=%')
              THEN '✅ 已固定' ELSE '⚠️ 未固定' END AS search_path
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('pay_dividend', '_orig_pay_dividend')
 ORDER BY p.proname;

-- 期望：
--   _orig_pay_dividend  3 参数   anon 不能调  auth 不能调   ← 内部实现，锁死
--   pay_dividend        4 参数   anon 能调    auth 能调     ← 对外的壳，能调

-- 3.2 pay_dividend 应该只有一个重载（防止又留一个后门）
SELECT
    count(*)                                  AS pay_dividend重载个数,
    string_agg(pg_get_function_identity_arguments(p.oid), '  |  ') AS 各版本参数,
    CASE WHEN count(*) = 1 THEN '✅ 只有一个' ELSE '❌ 有多个，要清' END AS 结论
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'pay_dividend';


-- ============================================================
-- 第 4 步：功能自测（可选，跑一下确认没坏）
-- ============================================================
-- 下面这句用一个【假 session】去调，应该返回「登录状态已过期」——
-- 证明鉴权生效了。
--
--   SELECT public.pay_dividend(
--       (SELECT founder_id FROM public.user_companies LIMIT 1),
--       (SELECT id FROM public.user_companies LIMIT 1),
--       1,
--       'this-is-a-fake-session'
--   );
--
-- 期望结果： {"success": false, "message": "登录状态已过期，请重新登录"}
--
-- ⚠️ 如果返回的是「只有创始人可以发起分红」或者别的业务报错，
--    说明鉴权那一段没生效，把结果发我。


-- ============================================================
--  前端要不要改？—— 不用
-- ============================================================
--  两个股票页（Beta/stock-Beta.html、Virtual stock.html）里已经是这样写的：
--
--      const r = await supabaseClient.rpc('pay_dividend', {
--          p_user_id: currentUserId, p_company_id: cid, p_amount: amount,
--          p_session: localStorage.getItem('nb_session')     ← 先试带 session 的
--      });
--      // 后端只接受 3 参数签名时自动退回
--      if (error && /p_session|Could not find the function|PGRST202/i.test(error.message)) {
--          const r2 = await supabaseClient.rpc('pay_dividend', {
--              p_user_id: currentUserId, p_company_id: cid, p_amount: amount
--          });
--      }
--
--  以前库里只有 3 参数版本，所以每次都走了退回分支。
--  现在 4 参数版本建好了，第一次调用就成功，退回分支永远走不到。
--
--  （那段退回代码以后可以删掉，但留着也无害 —— 它只在
--    「函数签名不存在」时才触发，现在不会触发了。）
-- ============================================================
