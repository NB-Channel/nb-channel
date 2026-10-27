-- ============================================================
-- 评论区 AI 机器人：扫描窗口修复
--
-- 站长，2026-10-27
--
-- 【为什么机器人不回复】
--   原来的函数里写死了窗口上限：
--       v_m int := greatest(1, least(coalesce(p_minutes, 10), 120));
--                                              ↑ 最多 120 分钟
--   云函数传 1440（24 小时）或 10080（7 天），到数据库就被夹成 120 分钟。
--   所以超过 2 小时的 @ 永远扫不到 → found: 0 → 机器人不回复。
--
-- 【这个脚本做什么】
--   只重建 bot_pending_mentions 一个函数，窗口上限改成 10080（7 天），
--   @ 的匹配也收紧成「@NB频道AI助手」或「@AI助手」（不再匹配裸 @AI，
--   避免误抓「@AWM1111」这种别人家的 @）。
--
--   ⚠️ 不动表结构、不动数据、不动 bot_insert_comment。
--
-- 【怎么跑】
--   Supabase → SQL Editor → 整段粘贴 → Run。
--   跑完在页面上 @NB频道AI助手 说一句话，等下一次定时任务（15 分钟）就会回复。
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
    -- ⭐ 关键修复：上限从 120 分钟改成 10080（7 天）
    v_m   int  := greatest(1, least(coalesce(p_minutes, 10), 10080));
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

grant execute on function public.bot_pending_mentions(int, text) to anon;
grant execute on function public.bot_pending_mentions(int, text) to authenticated;

-- ---------- 自检 ----------
-- 跑完之后，把「返回值」贴给 AI 就能确认：
--   {"ok": true, "window_minutes": 10080, "count": N, "items": [...]}
--   window_minutes 是 10080 → 修复成功
--   还是 120             → 这段没跑成功，重跑
