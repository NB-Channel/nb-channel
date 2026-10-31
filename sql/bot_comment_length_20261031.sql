-- ============================================================
--  修「机器人回复被截断」
--
--  问题：
--    bot_insert_comment 里写死了：
--        if length(v_txt) > 600 then v_txt := substr(v_txt, 1, 600);
--    超过 600 字直接砍掉，而且是在句子中间砍 → 看起来像话说到一半断掉。
--
--  这个脚本做两件事：
--    1. 把上限从 600 提到 4000（够放一条长回复）
--    2. 超长时不再硬砍，而是在最后一个句号/问号/感叹号处收尾，
--       并补一句「（完整回答可在站内 AI 页面问）」
--
--  云函数那边也会先做一次「按句子收尾」，两层都不硬切。
-- ============================================================

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
    v_val  text;
    v_bot  uuid := '11111111-2222-3333-4444-555555555555'::uuid;
    v_txt  text;
    v_id   bigint;
    v_max  int := 4000;          -- ⭐ 原来是 600
    v_cut  int;
begin
    select value into v_val from public.admin_settings where key = 'mail_secret';
    if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
        -- 迁移期：bot_secret 也认
        begin
            select value into v_val from public.admin_settings where key = 'bot_secret';
        exception when others then
            v_val := null;
        end;
        if v_val is null or length(v_val) < 8 or p_secret is null or v_val <> p_secret then
            return jsonb_build_object('ok', false, 'reason', 'secret');
        end if;
    end if;

    v_txt := btrim(coalesce(p_content, ''));
    if v_txt = '' then
        return jsonb_build_object('ok', false, 'reason', 'empty');
    end if;

    -- 超长：退到最后一个句末标点收尾，而不是生硬切断
    if length(v_txt) > v_max then
        v_cut := greatest(
            coalesce(length(v_txt) - position('。' in reverse(v_txt)) + 1, 0),
            coalesce(length(v_txt) - position('！' in reverse(v_txt)) + 1, 0),
            coalesce(length(v_txt) - position('？' in reverse(v_txt)) + 1, 0),
            coalesce(length(v_txt) - position('；' in reverse(v_txt)) + 1, 0)
        );
        if v_cut between 200 and v_max then
            v_txt := substr(v_txt, 1, v_cut);
        else
            v_txt := substr(v_txt, 1, v_max);
        end if;
        v_txt := v_txt || E'\n\n（这条太长了，完整回答可以在站内 AI 页面问～）';
    end if;

    if p_page_path is null or p_page_path = '' then
        return jsonb_build_object('ok', false, 'reason', 'nopage');
    end if;

    insert into public.comments (page_path, user_id, content, parent_id)
    values (p_page_path, v_bot, v_txt, p_parent_id)
    returning id into v_id;

    return jsonb_build_object('ok', true, 'id', v_id, 'length', length(v_txt));
end;
$$;

grant execute on function public.bot_insert_comment(text, text, bigint, text) to anon;
grant execute on function public.bot_insert_comment(text, text, bigint, text) to authenticated;

-- 验收：随便发一条 700 字的内容试试（跑完记得删掉测试评论）
-- select public.bot_insert_comment('nb_comments', repeat('测试。', 200), null, '<mail_secret>');
