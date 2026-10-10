-- ============================================================
--  NB报刊社 · 把「假图片」加回第 1 期 + 支持插图类型
--
--  站长问：改之前第一期里那个「假图片」呢？
--  翻了一下改写前的版本，它是这一段：
--
--      <figure class="np-figure">
--          <div class="box">此处应有证书照片 —— 不过你往上看「关于」页就能看到真图</div>
--          <figcaption>图示：顶级国际域名证书（真图见「关于」页面）</figcaption>
--      </figure>
--
--  我改写时把它丢了。这一版把它当成一种【文章类型】加回来：
--
--      kind = 'figure'  插图（假图片）
--          headline → 图注（figcaption）
--          body     → 框里那句话
--          tag      → 框里的小角标（可留空）
--
--  这样站长以后在后台也能自己加「此处应有照片」这种占位框。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看看现在第 1 期有哪些文章
-- ============================================================
SELECT sort AS 排序, kind AS 类型, left(headline, 30) AS 标题
  FROM public.news_articles
 WHERE issue_id = (SELECT id FROM public.news_issues WHERE issue_no = 1)
 ORDER BY sort, id;


-- ============================================================
-- 第 2 步：把「假图片」插回第 1 期
--   放在第一篇正文（那个讲域名证书的）后面 —— 它本来就是给那篇配的图。
--   已经存在就不重复插（按 headline 认）。
-- ============================================================
DO $$
DECLARE
    v_issue bigint;
    v_after integer;
    v_slot  integer;
BEGIN
    SELECT id INTO v_issue FROM public.news_issues WHERE issue_no = 1;
    IF v_issue IS NULL THEN
        RAISE NOTICE '没有第 1 期，跳过';
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM public.news_articles
                WHERE issue_id = v_issue AND kind = 'figure') THEN
        RAISE NOTICE '插图已经在了，跳过';
        RETURN;
    END IF;

    -- 找第一篇带副标题的正文（就是那篇域名证书的），插在它后面
    SELECT COALESCE(max(sort), 0) INTO v_after
      FROM public.news_articles
     WHERE issue_id = v_issue AND kind = 'article' AND subhead <> ''
       AND sort = (SELECT min(sort) FROM public.news_articles
                    WHERE issue_id = v_issue AND kind = 'article' AND subhead <> '');

    IF v_after = 0 THEN
        v_after := 1;      -- 找不到就放在最前面那篇后面
    END IF;

    -- 后面的往后挪一格，腾出位置
    UPDATE public.news_articles SET sort = sort + 1
     WHERE issue_id = v_issue AND sort > v_after;

    v_slot := v_after + 1;

    INSERT INTO public.news_articles
        (issue_id, section, kind, tag, headline, subhead, body, sort, page)
    VALUES
        (v_issue, 'free', 'figure', '',
         '图示：顶级国际域名证书（真图见「关于」页面）',
         '',
         '此处应有证书照片 —— 不过你往上看「关于」页就能看到真图',
         v_slot, 1);

    RAISE NOTICE '插图已插回第 1 期，sort=%', v_slot;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
SELECT sort AS 排序, kind AS 类型, page AS 页,
       left(headline, 34) AS 标题
  FROM public.news_articles
 WHERE issue_id = (SELECT id FROM public.news_issues WHERE issue_no = 1)
 ORDER BY sort, id;

SELECT '插图条数' AS 项目,
       (SELECT count(*) FROM public.news_articles WHERE kind = 'figure') AS 数量,
       '应为 1' AS 说明;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 第 1 期第一篇正文下面会出现那个虚线占位框 + 图注
--  · 后台文章表单的「类型」下拉会多一个「插图（假图片）」
--      · 标题     → 图注
--      · 正文     → 框里那句话
--      · 角标     → 框里的小角标（可留空）
--  · 便民信息里的 xxx.html 现在可以点了（前端改好了）
-- ============================================================
