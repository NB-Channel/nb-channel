-- ============================================================
-- AI 对话历史：把每一轮的「问 / 答 / 思考过程」存进数据库
--
-- 目的：刷新页面、换台电脑、明天再来，之前聊过的还都在。
--
-- 设计要点：
--   · 一轮一行（question + answer + reasoning 放同一行），
--     不是一问一行一答一行 —— 这样取出来就是成对的，前端不用配对。
--   · conv_id 用来区分「同一次对话」。点「新对话」换一个新的 conv_id，
--     老的数据不删（以后想做「历史对话列表」直接就有）。
--   · 表锁死（RLS 全禁），只能通过下面两个 SECURITY DEFINER 的 RPC 进出，
--     而且每个 RPC 都先过 _user_ok() —— 别人拿不到你的对话。
--   · 每个用户只留最近 100 轮，防止无限涨。
--
-- 执行顺序：整个文件一次性跑完即可（不依赖本目录其它文件，
--          但需要 public._user_ok(uuid, text) 已经存在 ——
--          那个在 ban_xiaonb2_gift.sql 里建的）。
-- ============================================================

-- ------------------------------------------------------------
-- ① 建表
-- ------------------------------------------------------------
create table if not exists public.ai_turns (
    id          bigserial primary key,
    user_id     uuid        not null,
    conv_id     uuid        not null,
    question    text        not null,
    answer      text        not null default '',
    reasoning   text        not null default '',
    model       text        not null default '',
    created_at  timestamptz not null default now()
);

comment on table  public.ai_turns            is 'AI 助手的对话历史（一轮一行）';
comment on column public.ai_turns.conv_id    is '同一次对话的 id，点「新对话」会换一个新的';
comment on column public.ai_turns.reasoning  is '这一轮的思考过程（可能是空字符串）';

-- 表说明里也写一下 100 轮上限，免得以后忘了
comment on column public.ai_turns.question   is '问的原文（≤1000 字）；一次对话最多 100 轮，见 add_ai_turn';

create index if not exists ai_turns_user_time_idx
    on public.ai_turns (user_id, created_at desc, id desc);

create index if not exists ai_turns_user_conv_idx
    on public.ai_turns (user_id, conv_id, created_at desc, id desc);

-- ------------------------------------------------------------
-- ② 锁死：anon / authenticated 一律不能直接读写
-- ------------------------------------------------------------
alter table public.ai_turns enable row level security;

drop policy if exists ai_turns_lock on public.ai_turns;
create policy ai_turns_lock on public.ai_turns
    for all
    to anon, authenticated
    using (false)
    with check (false);

-- ------------------------------------------------------------
-- ③ 写入一轮
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
    p_keep      int  default 20   -- 保留最近几次【对话】（不是轮数，见下面的清理逻辑）
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
    -- 登录校验：session 过期 / 账号被封 都在这儿挡住
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

    -- 一次对话的轮数上限。这里是【兜底】—— 前端到 100 轮就不再发请求了，
    -- 但前端能改，所以库里也拦一道。
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
    -- 和前端、云函数那三层限制对齐，这里再兜一次底
    if length(v_q)  > 1000  then v_q := left(v_q, 1000);  end if;
    if length(v_a)  > 20000 then v_a := left(v_a, 20000); end if;
    if length(v_r)  > 20000 then v_r := left(v_r, 20000); end if;

    insert into public.ai_turns (user_id, conv_id, question, answer, reasoning, model)
    values (p_user_id, p_conv_id, v_q, v_a, v_r, left(coalesce(p_model, ''), 80));

    -- 清理老数据：保留这个用户【最近的 v_keep 次对话】，更早的整次删掉。
    --
    -- 这里【不能】按行数删。以前是按「只留最新 N 行」写的，
    -- 结果和「一次对话最多 100 轮」撞上了：
    --     聊满 100 轮 → 点新对话 → 再问一句 → 第 101 行进来
    --     → 最老那一行被删 → 把刚聊完的那次对话从头上啃掉一条
    -- 改成按 conv_id 整次淘汰之后，单次对话不会被打断。
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

    return json_build_object('ok', true);
end;
$$;

-- ------------------------------------------------------------
-- ④ 取最近几轮
--    p_conv_id 传 null 时，取这个用户最近的整体对话
--    （前端刷新页面就是这样恢复的 —— 自动接上刚才那次）
-- ------------------------------------------------------------
drop function if exists public.get_ai_turns(uuid, text, uuid, int);

create or replace function public.get_ai_turns(
    p_user_id uuid,
    p_session text,
    p_conv_id uuid default null,
    p_limit   int  default 5
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_limit int;
    v_list  json;
    v_conv  uuid;
    v_cnt   int;
begin
    if not public._user_ok(p_user_id, p_session) then
        return json_build_object(
            'ok', false, 'reason', 'auth',
            'message', '登录已过期，请重新登录');
    end if;

    v_limit := least(greatest(coalesce(p_limit, 5), 1), 50);

    select coalesce(json_agg(t order by t.created_at asc, t.id asc), '[]'::json)
      into v_list
      from (
          select id, conv_id, question, answer, reasoning, model, created_at
            from public.ai_turns
           where user_id = p_user_id
             and (p_conv_id is null or conv_id = p_conv_id)
           order by created_at desc, id desc
           limit v_limit
      ) t;

    -- 顺手告诉前端「这次对话一共几轮」—— 前端拿它判断有没有到 100 轮上限
    select conv_id into v_conv
      from public.ai_turns
     where user_id = p_user_id
       and (p_conv_id is null or conv_id = p_conv_id)
     order by created_at desc, id desc
     limit 1;

    if v_conv is null then
        v_cnt := 0;
    else
        select count(*) into v_cnt
          from public.ai_turns
         where user_id = p_user_id
           and conv_id = v_conv;
    end if;

    return json_build_object(
        'ok', true,
        'turns', v_list,
        'conv_id', v_conv,
        'conv_count', v_cnt);
end;
$$;

-- ------------------------------------------------------------
-- ⑤ 清掉某一次对话（「新对话」想真的删的时候用得到；
--    不调用也不影响 —— 现在点「新对话」只是换个 conv_id）
-- ------------------------------------------------------------
drop function if exists public.del_ai_conv(uuid, text, uuid);

create or replace function public.del_ai_conv(
    p_user_id uuid,
    p_session text,
    p_conv_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_n int;
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

    delete from public.ai_turns
     where user_id = p_user_id
       and conv_id = p_conv_id;

    get diagnostics v_n = row_count;
    return json_build_object('ok', true, 'deleted', v_n);
end;
$$;

-- ------------------------------------------------------------
-- ⑥ 授权
-- ------------------------------------------------------------
grant execute on function public.add_ai_turn(uuid, text, uuid, text, text, text, text, int) to anon, authenticated;
grant execute on function public.get_ai_turns(uuid, text, uuid, int)                             to anon, authenticated;
grant execute on function public.del_ai_conv(uuid, text, uuid)                                   to anon, authenticated;

-- ------------------------------------------------------------
-- ⑦ 自检
-- ------------------------------------------------------------
select
    (select count(*) from information_schema.tables
      where table_schema = 'public' and table_name = 'ai_turns')      as table_exists,
    (select count(*) from pg_policies
      where schemaname = 'public' and tablename = 'ai_turns')          as policy_count,
    (select count(*) from information_schema.routines
      where routine_schema = 'public'
        and routine_name in ('add_ai_turn', 'get_ai_turns', 'del_ai_conv')) as func_count,
    (select count(*) from information_schema.routines
      where routine_schema = 'public' and routine_name = 'add_ai_turn')  as add_overload_count;
