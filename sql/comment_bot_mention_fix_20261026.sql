-- ============================================================
-- 收紧触发条件：只认正式写法
--
-- 站长：不应该 @NB频道AI助手 吗？
--
-- 原来认「@AI」或「@NB频道AI助手」，但裸的「@AI」太容易误触发
-- （有人在评论里聊「@AI 是什么意思」也会被当成召唤）。
--
-- 现在只认这两种：
--     @NB频道AI助手      ← 正式写法（评论框 @ 会自动补全出这个名字）
--     @AI助手            ← 简写
--
-- 在 Supabase SQL Editor 里整段跑一次（会覆盖原来那个函数）。
-- ============================================================

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
           -- 只认 @NB频道AI助手 和 @AI助手
           and (c.content ilike '%@NB频道AI助手%' or c.content ilike '%@AI助手%')
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

-- 确认改成功（应该输出函数名）
select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and proname = 'bot_pending_mentions';
