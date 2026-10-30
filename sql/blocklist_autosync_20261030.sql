-- ============================================================
--  临时邮箱黑名单：自动同步（配套 /__syncblock）
--
--  为什么：
--     站里现在靠 public.banned_email_domains 这张表拦临时邮箱，
--     但表里的域名是手动导入的（2026-10-04 导了 9204 个）。
--     小NB 用 uqu.me 就漏了 —— 这类服务每周都在新增域名。
--
--  做法：
--     GitHub 上有个持续维护的公开列表
--       https://github.com/disposable-email-domains/disposable-email-domains
--     云函数每小时/每周去拉一次，调下面这个函数批量写进表里。
--
--  幂等：重复跑只会更新 reason，不会报错。
-- ============================================================

drop function if exists public.admin_import_banned_domains(text[], text);

create or replace function public.admin_import_banned_domains(
    p_domains text[],
    p_secret  text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val   text;
    v_before bigint;
    v_after  bigint;
    v_n      int := 0;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return jsonb_build_object('ok', false, 'reason', 'secret');
    end if;
    if p_domains is null or array_length(p_domains, 1) is null then
        return jsonb_build_object('ok', false, 'reason', 'empty');
    end if;

    select count(*) into v_before from public.banned_email_domains;

    -- 只接受长得像域名的（防脏数据）
    insert into public.banned_email_domains (domain, reason)
    select distinct lower(btrim(d)), '自动同步 disposable-email-domains'
      from unnest(p_domains) as d
     where d ~ '^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$'
    on conflict (domain) do update
       set reason = case
             when public.banned_email_domains.reason like '自动同步%' then excluded.reason
             else public.banned_email_domains.reason
           end;

    get diagnostics v_n = row_count;
    select count(*) into v_after from public.banned_email_domains;

    return jsonb_build_object('ok', true, 'upserted', v_n,
                              'before', v_before, 'after', v_after,
                              'received', array_length(p_domains, 1));
end;
$$;

grant execute on function public.admin_import_banned_domains(text[], text) to anon;
grant execute on function public.admin_import_banned_domains(text[], text) to authenticated;

-- 验收（跑完同步之后看）
-- select count(*) from public.banned_email_domains;
