-- ============================================================
-- 扣 NB 币：允许扣成负数
--
-- 站长：直接扣成负的。
--
-- 改法：去掉原来的余额守卫 where coalesce(nb_balance,0) >= p_amount，
--       改成无条件扣款 —— 余额不够就继续往下走成负数。
--       仍然保留 secret 校验和「用户不存在」的判断。
-- ============================================================

drop function if exists public.ai_charge_coins(uuid, int, text);

create or replace function public.ai_charge_coins(
    p_user_id uuid,
    p_amount  int,
    p_secret  text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val text;
    v_bal numeric;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;

    if p_user_id is null then
        return json_build_object('ok', false, 'reason', 'nouser');
    end if;

    -- 0：只查余额
    if coalesce(p_amount, 0) = 0 then
        select coalesce(nb_balance, 0) into v_bal from public.profiles where id = p_user_id;
        if v_bal is null then
            return json_build_object('ok', false, 'reason', 'nouser', 'balance', 0);
        end if;
        return json_build_object('ok', true, 'charged', 0, 'balance', v_bal);
    end if;

    -- 扣款（正数）或退款（负数）都走这一条，不再拦余额，允许变成负数
    update public.profiles
       set nb_balance = coalesce(nb_balance, 0) - p_amount
     where id = p_user_id
    returning coalesce(nb_balance, 0) into v_bal;

    if v_bal is null then
        return json_build_object('ok', false, 'reason', 'nouser', 'balance', 0);
    end if;

    return json_build_object('ok', true, 'charged', p_amount, 'balance', v_bal);
end;
$$;

grant execute on function public.ai_charge_coins(uuid, int, text) to anon, authenticated;

select
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'ai_charge_coins') as overloads,
    (select array_agg(p.parameter_name order by p.ordinal_position)
       from information_schema.parameters p
       join information_schema.routines r on r.specific_name = p.specific_name
      where r.routine_schema = 'public' and r.routine_name = 'ai_charge_coins') as params;
