-- ============================================================
-- 评论区 AI 自动回复 —— 数据库部分
--
-- 站长：机器人账号名用「NB频道AI助手」。
--
-- 这个脚本做三件事：
--   1. 建机器人账号（profiles 里一行）
--   2. bot_pending_mentions：查「最近 N 分钟里 @ 了 AI、还没被回」的评论
--   3. bot_insert_comment：让机器人以自己身份插入一条回复（用 mail_secret 验证，
--      不需要 session —— 机器人没有 session）
--
-- ⚠️ 机器人用户的固定 uuid：11111111-2222-3333-4444-555555555555
--    以后所有 AI 回复都挂在这个 id 上，前端显示成「NB频道AI助手」。
--
-- 在 Supabase SQL Editor 里整段跑一次。
-- ============================================================

-- ---------- 1. 机器人账号 ----------
-- password_hash 是 NOT NULL，机器人没有密码，给一个「不存在对应明文」的占位哈希：
-- 64 个 0 不是任何常见密码的 sha256，所以这个账号登不进去（也不需要登录）。
insert into public.profiles (id, username, password_hash)
values ('11111111-2222-3333-4444-555555555555'::uuid, 'NB频道AI助手', repeat('0', 64))
on conflict (id) do nothing;

-- ---------- 2. 查待回复的 @ ----------
drop function if exists public.bot_pending_mentions(int, text);

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
    v_m   int  := greatest(1, least(coalesce(p_minutes, 10), 120));
    v_out jsonb;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
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
               c.created_at
          from public.comments c
          left join public.profiles p on p.id = c.user_id
         where c.created_at > now() - (v_m || ' minutes')::interval
           and c.user_id <> v_bot
           and (c.content ilike '%@AI%' or c.content ilike '%@NB频道AI助手%')
           -- 已经回过的就不再回（同一条评论下已有机器人回复）
           and not exists (
                select 1 from public.comments r
                 where r.parent_id = c.id and r.user_id = v_bot
           )
         order by c.id
         limit 5
      ) t;

    return jsonb_build_object('ok', true, 'items', v_out);
end;
$$;
grant execute on function public.bot_pending_mentions(int, text) to anon, authenticated;

-- ---------- 3. 机器人发回复 ----------
drop function if exists public.bot_insert_comment(text, text, bigint, text);

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
    select value into v_val from public.admin_settings where key = 'mail_secret';
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
grant execute on function public.bot_insert_comment(text, text, bigint, text) to anon, authenticated;

-- ---------- 4. 查一下机器人账号建成功没有 ----------
select id, username from public.profiles
 where id = '11111111-2222-3333-4444-555555555555'::uuid;
