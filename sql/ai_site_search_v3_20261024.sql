-- ============================================================
-- AI 站内数据库查询 v3 —— 回到 v1 的结构（语法证明过），只换匹配条件
--
-- 历史：
--   v1  能跑，但匹配条件是把【整句话】当子串：
--         where to_jsonb(t)::text ilike '%' || p_q || '%'
--       用户原话「U系现在多少度」在表里不可能整句出现 → 永远 0 条
--   v2  用 execute format() 多行拼接      → 42601 括号不匹配
--       又改成 execute ... into ... using → 42P01 relation "v_rows"
--          does not exist（这版 Postgres 不认那种写法）
--   v3  就是你跑通过的那套 begin/select/if 结构，一张表一块，
--       只把 where 换成「整句命中 或 任意词组命中」，并加上 p_terms 参数。
--
-- 新增参数 p_terms text[]：云函数把原话拆成词组（中文二元组）传进来。
-- 例：「U系现在多少度」→ ['U系']
--
-- ⚠️ 先 DROP 掉旧的 3 参数版本，避免 PostgREST 重载歧义
-- ============================================================

drop function if exists public.ai_site_search(text, text, int);
drop function if exists public.ai_site_search(text, text, int, text[]);

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
    select value into v_val from public.admin_settings where key = 'mail_secret';
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

grant execute on function public.ai_site_search(text, text, int, text[]) to anon, authenticated;

-- ------------------------------------------------------------
-- 自检：search_overloads 应为 1，params 里应有 p_terms
-- ------------------------------------------------------------
select
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'ai_site_search') as search_overloads,
    (select array_agg(p.parameter_name order by p.ordinal_position)
       from information_schema.parameters p
       join information_schema.routines r on r.specific_name = p.specific_name
      where r.routine_schema = 'public' and r.routine_name = 'ai_site_search') as params;
