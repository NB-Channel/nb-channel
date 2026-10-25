-- ============================================================
-- 读「今天还剩多少次」—— 给 AI 页面那张卡做实时显示
--
-- 站长：「今日额度 & 全站额度」那个不是实时的。
-- 现在补一个只读函数：返回当前用户 / 当前 IP / 全站 今天各用了多少。
-- 不写任何数据，纯 SELECT。
--
-- 在 Supabase SQL Editor 里整段跑一次。
-- ============================================================

drop function if exists public.ai_usage_left(uuid, text, text);

create or replace function public.ai_usage_left(
    p_user_id uuid,
    p_ip_hash text,
    p_secret  text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val    text;
    v_day    date := (now() at time zone 'Asia/Shanghai')::date;
    v_user   int := 0;
    v_ip     int := 0;
    v_global int := 0;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return jsonb_build_object('ok', false, 'reason', 'secret');
    end if;

    if p_user_id is not null then
        select count(*) into v_user
          from public.ai_usage
         where day = v_day and user_id = p_user_id and refunded_at is null;
    end if;

    if p_ip_hash is not null and p_ip_hash <> '' then
        select count(*) into v_ip
          from public.ai_usage
         where day = v_day and ip_hash = p_ip_hash and refunded_at is null;
    end if;

    select count(*) into v_global
      from public.ai_usage
     where day = v_day;

    return jsonb_build_object(
        'ok', true,
        'day', v_day,
        'used_user', v_user,
        'used_ip', v_ip,
        'used_global', v_global
    );
end;
$$;

grant execute on function public.ai_usage_left(uuid, text, text) to anon, authenticated;
