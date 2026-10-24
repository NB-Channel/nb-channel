-- ============================================================
-- 大礼包:封禁「小NB2」
--   user_id : 7c112908-8e5e-487a-885a-49a2f318aeec
--   2026-09-25 09:52(北京) 注册 → 09:59 起在评论区刷屏辱骂
--   行为与已封禁的「小NB官号」(593b7c94-2829-401e-980c-55c9257ff8cd) 完全一致,
--   判定为同一人的小号。
--
-- ⚠️ 为什么不能只改 is_banned:
--    全站所有写操作的守门函数 _user_ok() 只校验会话令牌,**不看 is_banned**。
--    所以封了号之后,他只要手里还有旧令牌,照样能发评论 / 转账 / 交易。
--    以前能封住「小NB官号」是因为顺手删了他的会话(见 ③),不是靠 is_banned。
--    所以本文件第 ① 步先把根因堵上 —— 补完之后,以后封号当场生效。
--
-- 在 Supabase SQL Editor 整段执行(幂等,可重复跑)
-- ============================================================


-- ============================================================
-- ① 【根因修复】_user_ok 拒绝已封禁账号
-- ============================================================
-- 补上封禁校验,并且不给封禁账号续期。
-- 影响面:所有走 _user_ok 的 RPC(评论/转账/交易/签到/改资料…)一次性全部生效。
-- 安全性:全站目前只有「小NB官号」一个封禁账号,不涉及误伤。
CREATE OR REPLACE FUNCTION public._user_ok(p_user_id uuid, p_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_hash text := md5(coalesce(p_token, ''));
    v_ok   boolean;
BEGIN
    IF p_user_id IS NULL OR coalesce(p_token, '') = '' THEN
        RETURN false;
    END IF;

    -- 1) 校验:令牌存在、属于该用户、且未过期
    SELECT true INTO v_ok
      FROM public.user_sessions
     WHERE token_hash = v_hash
       AND user_id = p_user_id
       AND expires_at > now()
     LIMIT 1;

    IF v_ok IS NOT TRUE THEN
        RETURN false;
    END IF;

    -- 2) 【本次新增】已封禁账号一律拒绝 —— 放在续期之前,不给封禁账号续命
    --    注意用 IS TRUE:is_banned 为 NULL 时 <> 判断会短路,是踩过的坑
    IF EXISTS (SELECT 1 FROM public.profiles
                WHERE id = p_user_id AND is_banned IS TRUE) THEN
        RETURN false;
    END IF;

    -- 3) 自动续期:剩余不足 25 天时续满 30 天
    UPDATE public.user_sessions
       SET expires_at = now() + interval '30 days'
     WHERE token_hash = v_hash
       AND expires_at < now() + interval '25 days';

    RETURN true;
END
$fn$;

-- 权限保持原样不动(原来就是只 REVOKE FROM PUBLIC)。
-- 这里刻意「不」扩大到 anon/authenticated:所有 RPC 包装函数都是 SECURITY DEFINER
-- 且由同一个角色创建,owner 有隐式权限,所以扩不扩大都不影响内部调用;
-- 但万一有谁不是同一个 owner 建的,扩大 REVOKE 会让全站写操作一起失效 —— 不值当。
REVOKE ALL ON FUNCTION public._user_ok(uuid, text) FROM PUBLIC;


-- ============================================================
-- ② 封号前先留档(把要删的内容打出来,SQL Editor 里有记录)
-- ============================================================
SELECT id, username, created_at AS 注册时间, is_banned AS 已封, banned_reason
  FROM public.profiles
 WHERE id = '7c112908-8e5e-487a-885a-49a2f318aeec';

SELECT id, content AS 内容, page_path, created_at
  FROM public.comments
 WHERE user_id = '7c112908-8e5e-487a-885a-49a2f318aeec'
 ORDER BY created_at;


-- ============================================================
-- ③ 封号 + 踢下线(两件事缺一不可)
-- ============================================================
UPDATE public.profiles
   SET is_banned = true,
       banned_reason = '盗号案涉案人小号:注册后立即在评论区刷屏辱骂,管理员封禁'
 WHERE id = '7c112908-8e5e-487a-885a-49a2f318aeec';

-- 清掉它的所有登录会话 —— 这是真正把它踢出去的一步
DELETE FROM public.user_sessions
 WHERE user_id = '7c112908-8e5e-487a-885a-49a2f318aeec';


-- ============================================================
-- ④ 删掉它的评论(先删回复再删主评论,避免留下孤儿回复)
-- ============================================================
DELETE FROM public.comments
 WHERE parent_id IN (SELECT id FROM public.comments
                      WHERE user_id = '7c112908-8e5e-487a-885a-49a2f318aeec');

DELETE FROM public.comments
 WHERE user_id = '7c112908-8e5e-487a-885a-49a2f318aeec';


-- ============================================================
-- ⑤ 查它的注册 IP(顺便自动生成封禁语句)
-- ============================================================
-- 注册时间 = 2026-09-25 01:52:37 UTC,取前后 20 分钟窗口。
-- 最后一列直接给出可复制的封禁语句:
--   · IPv6 自动收敛成 /64 整段(单地址封不禁,他换个后缀就回来了)
--   · ⚠️ 如果命中你自己的网段 7241,会明确警告,别手滑封掉自己
SELECT r.ip_address AS 注册IP,
       r.created_at  AS 时间,
       EXISTS (SELECT 1 FROM public.banned_ips b WHERE b.ip = r.ip_address) AS 已在黑名单,
       CASE
         WHEN r.ip_address LIKE '2409:8a30:9c84:7241:%'
              THEN '⚠️ 这是你自己的网段(7241),不要封!'
         WHEN r.ip_address LIKE '%:%'
              THEN format('INSERT INTO public.banned_ips (ip, reason) VALUES (%L, %L) ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;',
                          split_part(r.ip_address, ':', 1) || ':' || split_part(r.ip_address, ':', 2) || ':'
                       || split_part(r.ip_address, ':', 3) || ':' || split_part(r.ip_address, ':', 4) || '::/64',
                          '小NB2 注册来源网段')
         ELSE format('INSERT INTO public.banned_ips (ip, reason) VALUES (%L, %L) ON CONFLICT (ip) DO UPDATE SET reason = EXCLUDED.reason;',
                     r.ip_address, '小NB2 注册来源IP')
       END AS 封禁语句
  FROM public.registration_attempts r
 WHERE r.created_at BETWEEN timestamptz '2026-09-25 01:32:37+00'
                         AND timestamptz '2026-09-25 02:12:37+00'
 ORDER BY r.created_at;

-- 同一时间段还注册了哪些账号(找他的其它小号)
SELECT id, username, created_at AS 注册时间, is_banned AS 已封
  FROM public.profiles
 WHERE created_at BETWEEN timestamptz '2026-09-25 01:32:37+00'
                       AND timestamptz '2026-09-25 02:12:37+00'
 ORDER BY created_at;


-- ============================================================
-- ⑥ 验收
-- ============================================================
-- 1) 封禁状态 + 会话是否清干净(会话数应为 0)
SELECT p.username, p.is_banned AS 已封, p.banned_reason AS 原因,
       (SELECT count(*) FROM public.user_sessions s WHERE s.user_id = p.id) AS 剩余会话数,
       (SELECT count(*) FROM public.comments c WHERE c.user_id = p.id) AS 剩余评论数
  FROM public.profiles p
 WHERE p.id = '7c112908-8e5e-487a-885a-49a2f318aeec';

-- 2) 全站封禁名单
SELECT id, username, created_at AS 注册时间, banned_reason AS 原因
  FROM public.profiles
 WHERE is_banned IS TRUE
 ORDER BY created_at;

-- 3) 确认 _user_ok 已补上封禁校验(应返回 true)
SELECT p.proname AS 函数,
       (pg_get_functiondef(p.oid) LIKE '%is_banned%') AS 已检查封禁
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '_user_ok';
