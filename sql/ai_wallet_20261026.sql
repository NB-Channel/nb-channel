-- ============================================================
-- AI 钱包：赠金 + 充值余额 + 消费记录
--
-- 站长的规则：
--   · 每人一次性送 1500 NB 赠金，要自己在「用量信息」页面点领取
--   · 充值余额只能用 NB币 余额充，每人每天最多充 100000 NB币
--   · 用 AI 只扣「赠金」和「充值余额」，优先扣赠金，不再直接扣 NB币
--
-- 在 Supabase SQL Editor 里整段跑一次即可。
-- ============================================================

-- ---------- 表 ----------
create table if not exists public.ai_wallet (
    user_id       uuid primary key,
    bonus_balance numeric not null default 0,   -- 赠金余额
    topup_balance numeric not null default 0,   -- 充值余额
    total_spent   numeric not null default 0,   -- 累计消费
    bonus_claimed boolean not null default false,-- 有没有领过赠金
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create table if not exists public.ai_spend_log (
    id         bigserial primary key,
    user_id    uuid not null,
    model      text,
    cost       numeric not null default 0,
    bonus_part numeric not null default 0,
    topup_part numeric not null default 0,
    day        date not null default (now() at time zone 'Asia/Shanghai')::date,
    created_at timestamptz not null default now()
);
create index if not exists ai_spend_log_user_day on public.ai_spend_log (user_id, day);

create table if not exists public.ai_topup_log (
    id         bigserial primary key,
    user_id    uuid not null,
    amount     numeric not null default 0,
    day        date not null default (now() at time zone 'Asia/Shanghai')::date,
    created_at timestamptz not null default now()
);
create index if not exists ai_topup_log_user_day on public.ai_topup_log (user_id, day);

-- ---------- 1. 查钱包（带图表数据） ----------
drop function if exists public.ai_wallet_get(uuid, text);
create or replace function public.ai_wallet_get(
    p_user_id uuid,
    p_secret  text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val     text;
    v_bonus   numeric;
    v_topup   numeric;
    v_spent   numeric;
    v_claimed boolean;
    v_today   numeric;
    v_days    json;
    v_models  json;
    v_today_d date;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;
    if p_user_id is null then
        return json_build_object('ok', false, 'reason', 'nouser');
    end if;

    insert into public.ai_wallet(user_id) values (p_user_id)
    on conflict (user_id) do nothing;

    select bonus_balance, topup_balance, total_spent, bonus_claimed
      into v_bonus, v_topup, v_spent, v_claimed
      from public.ai_wallet where user_id = p_user_id;

    v_today_d := (now() at time zone 'Asia/Shanghai')::date;

    select coalesce(sum(amount), 0) into v_today
      from public.ai_topup_log where user_id = p_user_id and day = v_today_d;

    select coalesce(json_agg(row_to_json(t)), '[]'::json) into v_days
      from (
        select day as d, sum(cost)::numeric as c, count(*) as n
          from public.ai_spend_log
         where user_id = p_user_id and day > v_today_d - 30
         group by day order by day
      ) t;

    select coalesce(json_agg(row_to_json(t)), '[]'::json) into v_models
      from (
        select coalesce(model, '(未知)') as m, sum(cost)::numeric as c, count(*) as n
          from public.ai_spend_log
         where user_id = p_user_id
         group by 1 order by 2 desc limit 12
      ) t;

    return json_build_object(
        'ok', true,
        'bonus', coalesce(v_bonus, 0),
        'topup', coalesce(v_topup, 0),
        'spent', coalesce(v_spent, 0),
        'claimed', coalesce(v_claimed, false),
        'today_topup', coalesce(v_today, 0),
        'days', v_days,
        'models', v_models
    );
end;
$$;
grant execute on function public.ai_wallet_get(uuid, text) to anon, authenticated;

-- ---------- 2. 领赠金（每人一次 1500） ----------
drop function if exists public.ai_bonus_claim(uuid, text, int);
create or replace function public.ai_bonus_claim(
    p_user_id uuid,
    p_secret  text,
    p_amount  int default 1500
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val     text;
    v_claimed boolean;
    v_bonus   numeric;
    v_amt     int;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;
    if p_user_id is null then
        return json_build_object('ok', false, 'reason', 'nouser');
    end if;

    v_amt := coalesce(p_amount, 1500);
    if v_amt <= 0 or v_amt > 100000 then
        return json_build_object('ok', false, 'reason', 'amount');
    end if;

    insert into public.ai_wallet(user_id) values (p_user_id)
    on conflict (user_id) do nothing;

    select bonus_claimed, bonus_balance into v_claimed, v_bonus
      from public.ai_wallet where user_id = p_user_id for update;

    if coalesce(v_claimed, false) then
        return json_build_object('ok', false, 'reason', 'already',
                                 'bonus', coalesce(v_bonus, 0));
    end if;

    update public.ai_wallet
       set bonus_balance = coalesce(bonus_balance, 0) + v_amt,
           bonus_claimed = true,
           updated_at = now()
     where user_id = p_user_id
    returning bonus_balance into v_bonus;

    return json_build_object('ok', true, 'granted', v_amt, 'bonus', v_bonus);
end;
$$;
grant execute on function public.ai_bonus_claim(uuid, text, int) to anon, authenticated;

-- ---------- 3. 用 NB币 充值（每天上限 100000） ----------
drop function if exists public.ai_wallet_topup(uuid, int, text);
create or replace function public.ai_wallet_topup(
    p_user_id uuid,
    p_amount  int,
    p_secret  text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val     text;
    v_nb      numeric;
    v_topup   numeric;
    v_used    numeric;
    v_today   date;
    v_cap     int := 100000;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;
    if p_user_id is null then
        return json_build_object('ok', false, 'reason', 'nouser');
    end if;
    if coalesce(p_amount, 0) <= 0 then
        return json_build_object('ok', false, 'reason', 'amount');
    end if;

    v_today := (now() at time zone 'Asia/Shanghai')::date;

    select coalesce(sum(amount), 0) into v_used
      from public.ai_topup_log where user_id = p_user_id and day = v_today;
    if coalesce(v_used, 0) + p_amount > v_cap then
        return json_build_object('ok', false, 'reason', 'daily_limit',
                                 'used', coalesce(v_used, 0), 'cap', v_cap);
    end if;

    -- NB币 余额够不够
    select coalesce(nb_balance, 0) into v_nb from public.profiles where id = p_user_id;
    if v_nb is null then
        return json_build_object('ok', false, 'reason', 'nouser');
    end if;
    if v_nb < p_amount then
        return json_build_object('ok', false, 'reason', 'poor', 'nb', v_nb);
    end if;

    insert into public.ai_wallet(user_id) values (p_user_id)
    on conflict (user_id) do nothing;

    update public.profiles
       set nb_balance = coalesce(nb_balance, 0) - p_amount
     where id = p_user_id;

    update public.ai_wallet
       set topup_balance = coalesce(topup_balance, 0) + p_amount,
           updated_at = now()
     where user_id = p_user_id
    returning topup_balance into v_topup;

    insert into public.ai_topup_log(user_id, amount, day)
    values (p_user_id, p_amount, v_today);

    select coalesce(nb_balance, 0) into v_nb from public.profiles where id = p_user_id;

    return json_build_object('ok', true, 'topped', p_amount,
                             'topup', coalesce(v_topup, 0),
                             'nb', coalesce(v_nb, 0),
                             'today_used', coalesce(v_used, 0) + p_amount,
                             'cap', v_cap);
end;
$$;
grant execute on function public.ai_wallet_topup(uuid, int, text) to anon, authenticated;

-- ---------- 4. 扣费（先赠金，后充值余额） ----------
drop function if exists public.ai_wallet_charge(uuid, int, text, text);
create or replace function public.ai_wallet_charge(
    p_user_id uuid,
    p_amount  int,
    p_model   text,
    p_secret  text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val    text;
    v_bonus  numeric;
    v_topup  numeric;
    v_left   numeric;
    v_from_b numeric := 0;
    v_from_t numeric := 0;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;
    if p_user_id is null then
        return json_build_object('ok', false, 'reason', 'nouser');
    end if;

    insert into public.ai_wallet(user_id) values (p_user_id)
    on conflict (user_id) do nothing;

    select coalesce(bonus_balance, 0), coalesce(topup_balance, 0)
      into v_bonus, v_topup
      from public.ai_wallet where user_id = p_user_id for update;

    -- p_amount = 0：只查余额
    if coalesce(p_amount, 0) = 0 then
        return json_build_object('ok', true, 'charged', 0,
                                 'bonus', v_bonus, 'topup', v_topup);
    end if;

    v_left := p_amount;

    -- 先扣赠金
    if v_bonus > 0 then
        v_from_b := least(v_bonus, v_left);
        v_bonus := v_bonus - v_from_b;
        v_left := v_left - v_from_b;
    end if;

    -- 剩下的扣充值余额（允许扣成负数，跟原来 NB币 的规则一致）
    if v_left > 0 then
        v_from_t := v_left;
        v_topup := v_topup - v_from_t;
        v_left := 0;
    end if;

    update public.ai_wallet
       set bonus_balance = v_bonus,
           topup_balance = v_topup,
           total_spent   = coalesce(total_spent, 0) + p_amount,
           updated_at    = now()
     where user_id = p_user_id;

    insert into public.ai_spend_log(user_id, model, cost, bonus_part, topup_part)
    values (p_user_id, p_model, p_amount, v_from_b, v_from_t);

    return json_build_object('ok', true, 'charged', p_amount,
                             'bonus', v_bonus, 'topup', v_topup,
                             'from_bonus', v_from_b, 'from_topup', v_from_t);
end;
$$;
grant execute on function public.ai_wallet_charge(uuid, int, text, text) to anon, authenticated;
