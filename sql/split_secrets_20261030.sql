-- 拆钥匙：mail_secret / bot_secret / admin_secret
-- 跑法：整段执行 → 最后一条 select 打印三把密钥 → 填进云函数环境变量
-- 迁移期 bot/admin 函数写的是 key in ('mail_secret','X_secret')，填错也不影响现有功能

INSERT INTO public.admin_settings (key, value)
SELECT 'bot_secret', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
 WHERE NOT EXISTS (SELECT 1 FROM public.admin_settings WHERE key = 'bot_secret');

INSERT INTO public.admin_settings (key, value)
SELECT 'admin_secret', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
 WHERE NOT EXISTS (SELECT 1 FROM public.admin_settings WHERE key = 'admin_secret');

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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
create or replace function public.ai_site_search(
    p_q      text,
    p_secret text,
    p_limit  int    default 2,
    p_terms  text[] default null
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val  text;
    v_q    text;
    c_each int;
    v_out  jsonb := '{}'::jsonb;
    v_rows jsonb;
begin
    -- 密钥校验
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;

    v_q := btrim(coalesce(p_q, ''));
    if length(v_q) < 1 then
        return json_build_object('ok', true, 'empty', true, 'data', v_out);
    end if;
    if length(v_q) > 80 then
        v_q := left(v_q, 80);
    end if;
    c_each := least(greatest(coalesce(p_limit, 2), 1), 5);

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.news_articles t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('报纸文章', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.news_issues t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('报纸期号', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.shop_items t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('商店道具', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.titles t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('称号', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.achievements t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('成就', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.polls t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('投票', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t) - 'user_id' - 'owner_id' - 'email' - 'owner') as x
              from public.user_companies t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('公司', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t) - 'user_id') as x
              from public.stock_latest t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('最新价', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.market_meta t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('市场参数', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.weather_state t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('天气', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t)) as x
              from public.growth_fund_config t
             where (to_jsonb(t)::text ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where to_jsonb(t)::text ilike '%' || tt || '%')))
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('成长基金', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 交易设置：问交易规则时才带 ----------
    begin
        if v_q ~ '(手续费|规则|涨跌|交易|股票|限制)'
           or coalesce(array_to_string(p_terms, ' '), '') ~ '(手续费|规则|涨跌|交易|股票|限制)' then
            select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows
              from public.stock_settings t limit 4;
            if jsonb_array_length(v_rows) > 0 then
                v_out := v_out || jsonb_build_object('交易设置', v_rows);
            end if;
        end if;
    exception when others then null; end;

    -- ---------- 小黑屋：只给用户名和原因 ----------
    begin
        select coalesce(jsonb_agg(jsonb_build_object('username', t.username,
                                                     'reason', t.banned_reason)), '[]'::jsonb)
          into v_rows
          from public.profiles t
         where t.is_banned = true
           and (coalesce(t.username, '') ilike '%' || v_q || '%'
                or coalesce(t.banned_reason, '') ilike '%' || v_q || '%'
                or (p_terms is not null and exists (
                      select 1 from unnest(p_terms) as tt
                       where coalesce(t.username, '') ilike '%' || tt || '%'
                          or coalesce(t.banned_reason, '') ilike '%' || tt || '%')))
         limit 3;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('小黑屋', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 全站公告：admin_config 只白名单两个 key ----------
    begin
        select coalesce(jsonb_agg(jsonb_build_object('key', t.key, 'value', t.value)), '[]'::jsonb)
          into v_rows
          from public.admin_config t
         where t.key in ('announcement', 'lottery_daily_limit');
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('全站配置', v_rows);
        end if;
    exception when others then null; end;

    return json_build_object(
        'ok', true,
        'groups', (select count(*) from jsonb_object_keys(v_out)),
        'data', v_out);
end;
$$;
create or replace function public.ai_site_stats(p_secret text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val  text;
    v_out  jsonb := '{}'::jsonb;
    v_n    bigint;
    t      text;
    pairs  text[][] := array[
        ['注册用户',   'profiles'],
        ['公司',       'user_companies'],
        ['报纸期数',   'news_issues'],
        ['报纸文章',   'news_articles'],
        ['商店道具',   'shop_items'],
        ['称号',       'titles'],
        ['成就',       'achievements'],
        ['投票',       'polls'],
        ['评论',       'comments']
    ];
    i int;
begin
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;

    for i in 1 .. array_length(pairs, 1) loop
        begin
            -- 表不存在就跳过（to_regclass 返回 null）
            if to_regclass('public.' || pairs[i][2]) is not null then
                execute format('select count(*) from public.%I', pairs[i][2]) into v_n;
                v_out := v_out || jsonb_build_object(pairs[i][1], v_n);
            end if;
        exception when others then null;
        end;
    end loop;

    -- 小黑屋人数
    begin
        select count(*) into v_n from public.profiles where is_banned = true;
        v_out := v_out || jsonb_build_object('小黑屋人数', v_n);
    exception when others then null; end;

    -- 总成交笔数（只数笔数，不涉及任何人）
    begin
        if to_regclass('public.stock_trades') is not null then
            select count(*) into v_n from public.stock_trades;
            v_out := v_out || jsonb_build_object('股票成交笔数', v_n);
        end if;
    exception when others then null; end;

    return json_build_object('ok', true, 'data', v_out);
end;
$$;
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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
    select value into v_val from public.admin_settings where key in ('mail_secret', 'admin_secret');
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
create or replace function public.bot_insert_comment(
    p_page_path text,
    p_content   text,
    p_parent_id bigint default null,
    p_secret    text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val text;
    v_bot uuid := '11111111-2222-3333-4444-555555555555'::uuid;
    v_txt text;
    v_id  bigint;
begin
    select value into v_val from public.admin_settings where key in ('mail_secret', 'bot_secret');
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return jsonb_build_object('ok', false, 'reason', 'secret');
    end if;

    v_txt := btrim(coalesce(p_content, ''));
    if v_txt = '' then
        return jsonb_build_object('ok', false, 'reason', 'empty');
    end if;
    if length(v_txt) > 600 then
        v_txt := substr(v_txt, 1, 600);
    end if;
    if p_page_path is null or p_page_path = '' then
        return jsonb_build_object('ok', false, 'reason', 'nopage');
    end if;

    insert into public.comments (page_path, user_id, content, parent_id)
    values (p_page_path, v_bot, v_txt, p_parent_id)
    returning id into v_id;

    return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
create or replace function public.bot_pending_mentions(
    p_minutes int default 10,
    p_secret  text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val text;
    v_bot uuid := '11111111-2222-3333-4444-555555555555'::uuid;
    -- ⭐ 关键修复：上限从 120 分钟改成 10080（7 天）
    v_m   int  := greatest(1, least(coalesce(p_minutes, 10), 10080));
    v_out jsonb;
begin
    select value into v_val from public.admin_settings where key in ('mail_secret', 'bot_secret');
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return jsonb_build_object('ok', false, 'reason', 'secret');
    end if;

    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_out
      from (
        select c.id,
               c.page_path,
               c.user_id,
               coalesce(p.username, '匿名') as username,
               c.content,
               c.created_at,
               c.parent_id
          from public.comments c
          left join public.profiles p on p.id = c.user_id
         where c.created_at > now() - (v_m || ' minutes')::interval
           and c.user_id <> v_bot
           -- ⭐ 只认这两种写法（不再匹配裸 @AI，避免误抓别人家的 @）
           and (c.content ilike '%@NB频道AI助手%' or c.content ilike '%@AI助手%')
           -- 已经回过的就不再回（同一条评论下已有机器人回复）
           and not exists (
                select 1 from public.comments r
                 where r.parent_id = c.id and r.user_id = v_bot
           )
         order by c.id
         limit 5
      ) t;

    return jsonb_build_object(
        'ok', true,
        'window_minutes', v_m,
        'count', coalesce(jsonb_array_length(v_out), 0),
        'items', coalesce(v_out, '[]'::jsonb)
    );
end;
$$;

SELECT key, value FROM public.admin_settings
 WHERE key IN ('mail_secret', 'bot_secret', 'admin_secret') ORDER BY key;
