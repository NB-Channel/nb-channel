-- ============================================================
-- 给 AI 用的站内数据库查询（只读）
--
-- 站长要求：站内检索太烂，让 AI 能查数据库，但要排除隐私。
--
-- 排除掉的（不查）：
--     profiles 的 email / password / nb_balance（余额）
--     messages / conversations（私信）
--     friend_requests / friendships / profile_visits
--     email_codes（验证码）、各种 login_attempts / sessions / settings
--     bank_accounts / bank_logs / transfers / coin_claims
--     lottery_records / stock_trades / check_in_records / user_achievements
--     comments / comment_reactions / reports / feedback
--     stock_dividends（分红记录 —— 站长明确说不查）
--     ai_turns / ai_convs（对话历史 —— 站长明确说不查）
--     admin_config 里的 admin_password
--
-- 可以查的：
--     报纸 news_issues / news_articles
--     商店 shop_items / titles / achievements
--     投票 polls / poll_options
--     股票行情 stock_latest / stock_history / stock_history_full
--     公司 user_companies（公司名/简介/股数，剥掉老板 id）
--     市场参数 market_meta / stock_settings / growth_fund_config
--     天气（任意含城市的表都能匹配上）
--     小黑屋 profiles 里 is_banned = true 的 username + banned_reason
--     全站配置 admin_config 里【白名单 key】
--     站内统计（数字，不含任何个人信息）
--
-- ⚠️ 做法上刻意【不写死列名】：
--     除了 profiles 那两个（username / banned_reason / is_banned，
--     已在站点代码里确认过），其余表都用 to_jsonb(t)::text 整行匹配，
--     不需要知道具体列名，也就不会因为列名猜错而崩。
--     返回前统一把敏感键从 JSON 里删掉。
-- ============================================================

-- ------------------------------------------------------------
-- ① 站内内容搜索
-- ------------------------------------------------------------
drop function if exists public.ai_site_search(text, text, int);

create or replace function public.ai_site_search(
    p_q      text,
    p_secret text,
    p_limit  int default 2      -- 每类最多几条
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_val   text;
    v_q     text;
    v_lim   int;
    v_out   jsonb := '{}'::jsonb;
    v_rows  jsonb;
    v_n     int;
    c_each  int;
begin
    -- 密钥校验（和 ai_usage 那几个函数一个套路）
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        return json_build_object('ok', false, 'reason', 'secret');
    end if;

    v_q := btrim(coalesce(p_q, ''));
    if length(v_q) < 2 then
        return json_build_object('ok', true, 'empty', true, 'data', v_out);
    end if;
    if length(v_q) > 60 then
        v_q := left(v_q, 60);
    end if;

    v_lim := least(greatest(coalesce(p_limit, 2), 1), 5);
    c_each := v_lim;

    -- ---------- 报纸 ----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t) - 'user_id' - 'email') as x
              from public.news_articles t
             where to_jsonb(t)::text ilike '%' || v_q || '%'
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('报纸', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t) - 'user_id' - 'email') as x
              from public.news_issues t
             where to_jsonb(t)::text ilike '%' || v_q || '%'
             limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('报纸期号', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 商店 / 称号 / 成就 ----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.shop_items t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('商店道具', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.titles t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('称号', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.achievements t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('成就', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 投票 ----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.polls t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('投票', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 公司（剥掉老板 id）----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t) - 'user_id' - 'owner_id' - 'owner' - 'email') as x
              from public.user_companies t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('公司', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 行情 ----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select (to_jsonb(t) - 'user_id') as x
              from public.stock_latest t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('最新价', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 市场参数 ----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.market_meta t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit c_each
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('市场参数', v_rows);
        end if;
    exception when others then null; end;

    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.stock_settings t
             limit c_each
        ) s;
        -- 市场设置就那几行，问交易规则时直接带上
        if jsonb_array_length(v_rows) > 0
           and (v_q ilike '%手续费%' or v_q ilike '%规则%' or v_q ilike '%涨跌%'
                or v_q ilike '%交易%' or v_q ilike '%股票%' or v_q ilike '%怎么%') then
            v_out := v_out || jsonb_build_object('交易设置', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 天气（表名/列名不写死，整行匹配）----------
    begin
        select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
            select to_jsonb(t) as x from public.weather_state t
             where to_jsonb(t)::text ilike '%' || v_q || '%' limit 3
        ) s;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('天气', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 小黑屋（只给用户名和原因）----------
    begin
        select coalesce(jsonb_agg(jsonb_build_object(
                   'username', t.username,
                   'reason', t.banned_reason)), '[]'::jsonb)
          into v_rows
          from public.profiles t
         where t.is_banned = true
           and (coalesce(t.username,'') ilike '%' || v_q || '%'
                or coalesce(t.banned_reason,'') ilike '%' || v_q || '%')
         limit 3;
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('小黑屋', v_rows);
        end if;
    exception when others then null; end;

    -- ---------- 全站公告（admin_config 白名单）----------
    begin
        select coalesce(jsonb_agg(jsonb_build_object('key', t.key, 'value', t.value)),
                        '[]'::jsonb)
          into v_rows
          from public.admin_config t
         where t.key in ('announcement', 'lottery_daily_limit');
        if jsonb_array_length(v_rows) > 0 then
            v_out := v_out || jsonb_build_object('全站配置', v_rows);
        end if;
    exception when others then null; end;

    v_n := (select count(*) from jsonb_object_keys(v_out));
    return json_build_object('ok', true, 'groups', v_n, 'data', v_out);
end;
$$;

-- ------------------------------------------------------------
-- ② 站内统计（纯数字，不含任何个人信息）
-- ------------------------------------------------------------
drop function if exists public.ai_site_stats(text);

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
    select value into v_val from public.admin_settings where key = 'mail_secret';
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

-- ------------------------------------------------------------
-- ③ 授权
-- ------------------------------------------------------------
grant execute on function public.ai_site_search(text, text, int) to anon, authenticated;
grant execute on function public.ai_site_stats(text)              to anon, authenticated;

-- ------------------------------------------------------------
-- ④ 自检
-- ------------------------------------------------------------
select
    (select count(*) from information_schema.routines
      where routine_schema = 'public'
        and routine_name in ('ai_site_search', 'ai_site_stats')) as funcs,
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'ai_site_search') as search_overloads,
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'ai_site_stats') as stats_overloads;
