-- ============================================================
-- AI 按 token 扣 NB 币
--
-- 站长要求：每次回答之前按 token 扣 NB 币，需要价格表。
--
-- 说明：
--   真实 token 数要等模型答完才知道，所以「回答前」只能按【估算】扣：
--     输入侧（系统提示 + 历史 + 站内资料 + 数据库 + 联网 + 问题）能算得比较准
--     输出侧按档位估（Off≈900 … Max≈4096）
--   不足就拦下来不让问。
--
-- 价格表（在云函数里，可用环境变量改）：
--     基础价 AI_PRICE_PER_1K = 10 NB / 1000 token
--     最低消费 AI_PRICE_MIN  = 1 NB
--     模型倍率：
--         stepfun-ai/step-5-preview                0.7×
--         minimaxai/minimax-m3.1-flash             1.0×
--         nvidia/nemotron-3.5-lightning-30b-a3b    1.5×
--
-- 这个函数只做一件事：原子地加减 profiles.nb_balance，并防扣成负数。
--   p_amount > 0  扣钱，余额不够返回 reason='poor'
--   p_amount < 0  退款（内部取绝对值加回去）
--   p_amount = 0  只查余额
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
    -- 密钥校验（和 ai_usage / ai_site_search 同一套）
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

    -- 正数：扣钱（带余额检查，扣不动就是不够）
    if p_amount > 0 then
        update public.profiles
           set nb_balance = coalesce(nb_balance, 0) - p_amount
         where id = p_user_id
           and coalesce(nb_balance, 0) >= p_amount
        returning coalesce(nb_balance, 0) into v_bal;

        if v_bal is null then
            select coalesce(nb_balance, 0) into v_bal from public.profiles where id = p_user_id;
            return json_build_object(
                'ok', false,
                'reason', 'poor',
                'need', p_amount,
                'balance', coalesce(v_bal, 0));
        end if;

        return json_build_object('ok', true, 'charged', p_amount, 'balance', v_bal);
    end if;

    -- 负数：退款
    update public.profiles
       set nb_balance = coalesce(nb_balance, 0) + (-p_amount)
     where id = p_user_id
    returning coalesce(nb_balance, 0) into v_bal;

    return json_build_object('ok', true, 'charged', p_amount, 'balance', coalesce(v_bal, 0));
end;
$$;

grant execute on function public.ai_charge_coins(uuid, int, text) to anon, authenticated;

-- ------------------------------------------------------------
-- 自检：应该 1 个重载，参数是 p_user_id / p_amount / p_secret
-- ------------------------------------------------------------
select
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'ai_charge_coins') as overloads,
    (select array_agg(p.parameter_name order by p.ordinal_position)
       from information_schema.parameters p
       join information_schema.routines r on r.specific_name = p.specific_name
      where r.routine_schema = 'public' and r.routine_name = 'ai_charge_coins') as params;
