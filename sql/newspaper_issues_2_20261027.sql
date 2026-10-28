-- ============================================================
-- NB报刊社 · 新增两期（都是免费刊）
--
--   第 N 期：Utw 要求把「U星」改名成「U系」
--   第 N+1 期：AI 页面改版 + 评论区 AI 机器人
--
-- 在 Supabase → SQL Editor 整段跑一次即可。
-- 期号自动取「当前最大期号 + 1」「+ 2」，跑两次不会重号。
-- ============================================================

do $$
declare
    v_no    int;
    v_id    bigint;
    v_has_kind boolean;
    v_has_cover boolean;
    v_title text;
    v_sum   text;
begin
    select exists(select 1 from information_schema.columns
                   where table_schema='public' and table_name='news_issues' and column_name='kind')
      into v_has_kind;
    select exists(select 1 from information_schema.columns
                   where table_schema='public' and table_name='news_issues' and column_name='cover')
      into v_has_cover;

    -- ========================================================
    --  第 1 期：U星 → U系
    -- ========================================================
    select coalesce(max(issue_no), 0) + 1 into v_no from public.news_issues;
    v_title := 'Utw 要求把「U星」改名成「U系」';
    v_sum   := '一封来信，一条改名要求。本报核对了来龙去脉，也把 NB频道的答复原文登在这里。';

    if v_has_kind and v_has_cover then
        execute format('insert into public.news_issues
            (issue_no, title, summary, publish_date, price, published, kind, cover)
            values (%s, %L, %L, current_date, 0, true, %L, %L) returning id',
            v_no, v_title, v_sum, 'free', '') into v_id;
    elsif v_has_kind then
        execute format('insert into public.news_issues
            (issue_no, title, summary, publish_date, price, published, kind)
            values (%s, %L, %L, current_date, 0, true, %L) returning id',
            v_no, v_title, v_sum, 'free') into v_id;
    else
        insert into public.news_issues
            (issue_no, title, summary, publish_date, price, published)
            values (v_no, v_title, v_sum, current_date, 0, true)
            returning id into v_id;
    end if;

    insert into public.news_articles (issue_id, section, kind, tag, headline, subhead, body, sort)
    values
    (v_id, 'free', 'article', '头条',
     'Utw 来信：请把「U星」改成「U系」',
     '来信很短，要求很明确 —— 改一个字。',
     E'本报收到 Utw 方面的来信，核心诉求只有一条：把 NB频道 在相关页面里使用的「U星」一词，统一改成「U系」。\n\n'
     '来信没有说明理由，也没有附带任何依据。本报照登来意，不代表本报立场。\n\n'
     '需要说明的是：「U星」这个词在 NB频道 出现的位置并不多，主要集中在社区讨论和历史存档里，属于早期用语。改与不改，不影响任何功能，也不影响任何人的使用。',
     10),

    (v_id, 'free', 'article', '回应',
     'NB频道 的答复：名字不改，理由三条',
     '不是不尊重来信，是这三个理由站得住。',
     E'本报就此事询问 NB频道，得到的答复可以概括为三点。\n\n'
     '第一，历史存档不能改。已经发出去的报纸、评论、存档里写着「U星」，那是当时的事实，改了就等于伪造记录。\n\n'
     '第二，改一个词的收益为零。这个词只存在于讨论中，不涉及任何产品名、域名、频道标识。改了不会让谁用得更好。\n\n'
     '第三，改名权在社区，不在某一个人。如果将来社区普遍改口叫「U系」，NB频道 会跟着改；但不会因为一封来信就改。\n\n'
     '一句话总结：不接这个要求，但也不拉黑任何人。',
     20),

    (v_id, 'free', 'brief', '短讯',
     '社区怎么反应',
     '',
     E'本报在评论区随手看了看，意见分三派：\n\n'
     '· 「改就改呗，一个字而已」—— 少数，理由是不值得吵。\n\n'
     '· 「凭什么你让改就改」—— 多数，理由是要求没有依据。\n\n'
     '· 「U星是什么？我才知道有这个词」—— 意外地不少，说明这个词本来就不重要。',
     30),

    (v_id, 'free', 'service', '便民',
     '「U星」这个词是怎么来的',
     '',
     E'早期社区在讨论相关话题时，用「U星」指代某个对象，后来被沿用下来。\n\n'
     '它不是任何官方名称，也没有出现在 NB频道 的产品、域名或正式文档里。\n\n'
     '换句话说：这是一个民间叫法。民间叫法怎么变，看的是大家怎么叫，不是谁发一封信。',
     40);

    -- ========================================================
    --  第 2 期：AI 页面 + 评论区机器人（免费刊）
    -- ========================================================
    select coalesce(max(issue_no), 0) + 1 into v_no from public.news_issues;
    v_title := 'AI 助手大改版，评论区机器人上岗';
    v_sum   := '21 个模型、五档定价、能看图、能画图；评论区多了一个会自己回话的 AI。本期全部免费。';

    if v_has_kind and v_has_cover then
        execute format('insert into public.news_issues
            (issue_no, title, summary, publish_date, price, published, kind, cover)
            values (%s, %L, %L, current_date, 0, true, %L, %L) returning id',
            v_no, v_title, v_sum, 'free', '') into v_id;
    elsif v_has_kind then
        execute format('insert into public.news_issues
            (issue_no, title, summary, publish_date, price, published, kind)
            values (%s, %L, %L, current_date, 0, true, %L) returning id',
            v_no, v_title, v_sum, 'free') into v_id;
    else
        insert into public.news_issues
            (issue_no, title, summary, publish_date, price, published)
            values (v_no, v_title, v_sum, current_date, 0, true)
            returning id into v_id;
    end if;

    insert into public.news_articles (issue_id, section, kind, tag, headline, subhead, body, sort)
    values
    (v_id, 'free', 'article', '头条',
     'AI 助手改版：21 个模型，五档价格，还能画图',
     '以前只有 7 个模型，现在翻了三倍。',
     E'这次改版，AI 助手页面变了四处。\n\n'
     '【一、模型从 7 个变成 21 个】\n'
     '新增两家渠道：OpenRouter（8 个模型，全部免费）和 Cloudflare Workers AI（7 个模型，免费额度内）。'
     '加上原来的 NVIDIA 和魔搭，一共四个渠道。\n\n'
     '【二、价格分成五档】\n'
     '旗舰 400 NB/1K、强 300、主力 240、标准 200、轻量 160。'
     '最低档比原来还便宜，最高档贵一倍 —— 贵的模型确实更强，便宜的也确实够用。\n\n'
     '【三、能看图了】\n'
     'DeepSeek V4.1 Flash、Nemotron 3.5 VL、Nemotron 3 Omni、Llama 3.2 Vision 这四个模型可以直接读图片。'
     '在输入框旁边点「📎 图片」，选一张图发过去就行。\n\n'
     '【四、多了一个「画图」标签页】\n'
     '跟「对话」并排。写一句话，几秒出一张图。SDXL Lightning 400 NB/张，Dreamshaper 250 NB/张，'
     '生成失败不扣费。',
     10),

    (v_id, 'free', 'article', '新功能',
     '评论区机器人上岗：@NB频道AI助手',
     '它不会主动说话，但你叫它，它会答。',
     E'评论区多了一个账号，名字叫「NB频道AI助手」，名字后面有蓝标。\n\n'
     '【怎么叫它】\n'
     '在评论里写「@NB频道AI助手」或者「@AI助手」，然后问你的问题。'
     '别的写法它不认 —— 这是故意的，免得把别人的 @ 也当成叫它。\n\n'
     '【它什么时候回】\n'
     '每 15 分钟扫一次，最多一次回 3 条。所以不是秒回，等几分钟是正常的。\n\n'
     '【它会怎么答】\n'
     '答得短，一般 40 到 120 个字；你要求详细，它会写长一点。'
     '它会用表格、代码块、链接这些格式，也能读你给它的网页。\n\n'
     '【它不会什么】\n'
     '看不到图片（评论区没法传图）、不能查实时行情、'
     '对于「不存在的东西」它会直说不存在，而不是编一个给你。',
     20),

    (v_id, 'free', 'brief', '数据',
     '我们真跑了一遍评测，成绩在这',
     '',
     E'本报拿 14 道能自动判分的理科题，把模型都跑了一遍（同一道题、温度 0、逐题判分）。几个结论：\n\n'
     '· DeepSeek V4.1 Flash：满分，平均 1 秒出头，每任务约 36 NB —— 又快又准又便宜。\n\n'
     '· GPT-OSS 120B：low 档满分、35 NB；调到 high 反而掉分、贵一倍、还慢五倍。\n\n'
     '· Nemotron 3 120B：三个档位都满分，费用几乎不变。\n\n'
     '· 档位不是越高越好。有好几个模型，档位调高只是让它想更久，答案并没有更对。\n\n'
     '完整图表在「模型价格 & 用量信息」页面的「用量信息」标签里。',
     30),

    (v_id, 'free', 'service', '便民',
     '钱怎么算（三句话）',
     '',
     E'第一句：按 token 算，200 NB 一千 token，再乘模型档位。系统提示词不收钱。\n\n'
     '第二句：先扣赠金，赠金用完扣充值余额，不动你的 NB币 本金。新用户有 1500 赠金。\n\n'
     '第三句：余额扣到 0 或负数就提不了问，充值或领赠金才能继续。答完才扣，答到一半停了也按已生成的部分扣。',
     40);

    raise notice '两期已插入：第 % 期、第 % 期', v_no - 1, v_no;
end $$;

-- ---------- 自检：看最近三期 ----------
select i.issue_no, i.title, i.kind, i.price, i.published,
       (select count(*) from public.news_articles a where a.issue_id = i.id) as 文章数
  from public.news_issues i
 order by i.issue_no desc
 limit 3;
