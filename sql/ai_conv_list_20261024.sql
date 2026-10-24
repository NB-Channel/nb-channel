-- ============================================================
-- AI 对话列表 + 标题
--
-- 目的：页面左边加一个侧边栏，列出「几次对话」，可以点着切换。
--       新对话默认叫「新对话」，问完第一句之后让 AI 起个标题。
--
-- 前置：sql/ai_chat_history_20261024.sql 已经跑过（ai_turns 表在）。
--
-- 本文件做四件事：
--   ① 建 ai_convs 表（每次对话一行：conv_id / user_id / title / 时间）
--   ② 重建 add_ai_turn —— 原来的逻辑全部保留（100 轮上限、按对话整次淘汰），
--                           额外在写 turn 的时候顺手建/更新 ai_convs
--   ③ 新增 list_ai_convs —— 侧边栏用
--   ④ 新增 set_ai_conv_title —— 只允许【从空标题写一次】，之后不能改
-- ============================================================

-- ------------------------------------------------------------
-- ① 表
-- ------------------------------------------------------------
create table if not exists public.ai_convs (
    conv_id    uuid        primary key,
    user_id    uuid        not null,
    title      text        not null default '',
    turns      int         not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

comment on table  public.ai_convs        is 'AI 对话的列表信息（一次对话一行），侧边栏用';
comment on column public.ai_convs.title  is 'AI 起的标题；空字符串表示还没起（前端显示「新对话」）';
comment on column public.ai_convs.turns  is '这次对话已经聊了几轮（冗余计数，省得每次 count）';

create index if not exists ai_convs_user_time_idx
    on public.ai_convs (user_id, updated_at desc);

alter table public.ai_convs enable row level security;

drop policy if exists ai_convs_lock on public.ai_convs;
create policy ai_convs_lock on public.ai_convs
    for all
    to anon, authenticated
    using (false)
    with check (false);

-- ------------------------------------------------------------
-- ② 重建 add_ai_turn（多一件事：顺手建/更新 ai_convs）
-- ------------------------------------------------------------
drop function if exists public.add_ai_turn(uuid, text, uuid, text, text, text, text, int);

create or replace function public.add_ai_turn(
    p_user_id   uuid,
    p_session   text,
    p_conv_id   uuid,
    p_question  text,
    p_answer    text,
    p_reasoning text default '',
    p_model     text default '',
    p_keep      int  default 20   -- 保留最近几次【对话】（不是轮数）
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_q    text;
    v_a    text;
    v_r    text;
    v_keep int;
    v_have int;
    c_max  int := 100;     -- 一次对话最多 100 轮，到顶就要求开新对话
begin
    if not public._user_ok(p_user_id, p_session) then
        return json_build_object(
            'ok', false, 'reason', 'auth',
            'message', '登录已过期，请重新登录');
    end if;

    if p_conv_id is null then
        return json_build_object(
            'ok', false, 'reason', 'bad_conv',
            'message', '会话 id 不对');
    end if;

    select count(*) into v_have
      from public.ai_turns
     where user_id = p_user_id
       and conv_id = p_conv_id;

    if v_have >= c_max then
        return json_build_object(
            'ok', false, 'reason', 'conv_full',
            'message', '这次对话已经 ' || c_max || ' 轮了，点「新对话」重新开始吧');
    end if;

    v_q := btrim(coalesce(p_question, ''));
    v_a := btrim(coalesce(p_answer, ''));
    v_r := coalesce(p_reasoning, '');

    if length(v_q) = 0 then
        return json_build_object(
            'ok', false, 'reason', 'bad_q', 'message', '问题是空的');
    end if;
    if length(v_q)  > 1000  then v_q := left(v_q, 1000);  end if;
    if length(v_a)  > 20000 then v_a := left(v_a, 20000); end if;
    if length(v_r)  > 20000 then v_r := left(v_r, 20000); end if;

    insert into public.ai_turns (user_id, conv_id, question, answer, reasoning, model)
    values (p_user_id, p_conv_id, v_q, v_a, v_r, left(coalesce(p_model, ''), 80));

    -- 顺手把这个对话登记到 ai_convs（没有就建，有就更新轮数和时间）
    insert into public.ai_convs (conv_id, user_id, turns, updated_at)
    values (p_conv_id, p_user_id, 1, now())
    on conflict (conv_id) do update
       set turns      = public.ai_convs.turns + 1,
           updated_at = now()
     where public.ai_convs.user_id = p_user_id;   -- 只让自己更新自己的

    -- 清理老数据：保留最近的 v_keep 次对话，更早的整次删掉。
    -- ⚠️ 不能按行数删 —— 会把聊满的那次对话从头上啃掉（这坑踩过）。
    v_keep := least(greatest(coalesce(p_keep, 20), 1), 100);

    delete from public.ai_turns
     where user_id = p_user_id
       and conv_id not in (
           select conv_id
             from (
                 select conv_id, max(created_at) as last_at
                   from public.ai_turns
                  where user_id = p_user_id
                  group by conv_id
                  order by last_at desc
                  limit v_keep
             ) keep
       );

    delete from public.ai_convs
     where user_id = p_user_id
       and conv_id not in (
           select conv_id
             from public.ai_turns
            where user_id = p_user_id
       );

    return json_build_object('ok', true);
end;
$$;

-- ------------------------------------------------------------
-- ③ 侧边栏：列出这个用户最近的几次对话
-- ------------------------------------------------------------
drop function if exists public.list_ai_convs(uuid, text, int);

create or replace function public.list_ai_convs(
    p_user_id uuid,
    p_session text,
    p_limit   int default 20
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_limit int;
    v_list  json;
begin
    if not public._user_ok(p_user_id, p_session) then
        return json_build_object(
            'ok', false, 'reason', 'auth',
            'message', '登录已过期，请重新登录');
    end if;

    v_limit := least(greatest(coalesce(p_limit, 20), 1), 100);

    select coalesce(json_agg(t order by t.updated_at desc), '[]'::json)
      into v_list
      from (
          select c.conv_id,
                 c.title,
                 c.turns,
                 c.updated_at,
                 (select count(*) from public.ai_turns a
                   where a.user_id = c.user_id and a.conv_id = c.conv_id) as real_turns
            from public.ai_convs c
           where c.user_id = p_user_id
             and exists (select 1 from public.ai_turns a
                          where a.user_id = c.user_id and a.conv_id = c.conv_id)
           order by c.updated_at desc
           limit v_limit
      ) t;

    return json_build_object('ok', true, 'convs', v_list);
end;
$$;

-- ------------------------------------------------------------
-- ④ 存标题：只允许从【空】写成有，写过就不能再改
--    （避免前端被改成随便乱写，也避免每轮都让 AI 重新起名）
-- ------------------------------------------------------------
drop function if exists public.set_ai_conv_title(uuid, text, uuid, text);

create or replace function public.set_ai_conv_title(
    p_user_id uuid,
    p_session text,
    p_conv_id uuid,
    p_title   text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_t   text;
    v_old text;
begin
    if not public._user_ok(p_user_id, p_session) then
        return json_build_object(
            'ok', false, 'reason', 'auth',
            'message', '登录已过期，请重新登录');
    end if;

    if p_conv_id is null then
        return json_build_object(
            'ok', false, 'reason', 'bad_conv', 'message', '会话 id 不对');
    end if;

    v_t := btrim(coalesce(p_title, ''));
    if length(v_t) = 0 then
        return json_build_object(
            'ok', false, 'reason', 'bad_title', 'message', '标题是空的');
    end if;
    if length(v_t) > 20 then v_t := left(v_t, 20); end if;

    select title into v_old
      from public.ai_convs
     where conv_id = p_conv_id and user_id = p_user_id;

    if not found then
        return json_build_object(
            'ok', false, 'reason', 'no_conv', 'message', '这次对话还没开始');
    end if;

    if v_old is not null and length(btrim(v_old)) > 0 then
        return json_build_object(
            'ok', false, 'reason', 'has_title',
            'message', '这次对话已经有标题了', 'title', v_old);
    end if;

    update public.ai_convs
       set title = v_t
     where conv_id = p_conv_id and user_id = p_user_id;

    return json_build_object('ok', true, 'title', v_t);
end;
$$;

-- ------------------------------------------------------------
-- ⑤ 授权
-- ------------------------------------------------------------
grant execute on function public.add_ai_turn(uuid, text, uuid, text, text, text, text, int) to anon, authenticated;
grant execute on function public.list_ai_convs(uuid, text, int)                                 to anon, authenticated;
grant execute on function public.set_ai_conv_title(uuid, text, uuid, text)                       to anon, authenticated;

-- ------------------------------------------------------------
-- ⑥ 自检
-- ------------------------------------------------------------
select
    (select count(*) from information_schema.tables
      where table_schema = 'public' and table_name = 'ai_convs')        as table_exists,
    (select count(*) from pg_policies
      where schemaname = 'public' and tablename = 'ai_convs')            as policy_count,
    (select count(*) from information_schema.routines
      where routine_schema = 'public'
        and routine_name in ('list_ai_convs', 'set_ai_conv_title'))      as new_funcs,
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'add_ai_turn')  as add_overloads;
