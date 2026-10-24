-- ============================================================
--  NB报刊社 · 第 1 期改成免费刊，并删掉里面的付费内容
--
--  站长要求：
--      ① 删掉付费部分
--      ② 把第一期放到免费里去
--
--  理解：「付费部分」=第 1 期里那两篇 section='paid' 的文章；
--        「放到免费里」=把 news_issues.kind 改成 'free'。
--        「付费刊」这个类别本身保留（以后想发收费期还能用）。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看看删之前是什么样（留个记录）
-- ============================================================
SELECT '删之前' AS 阶段, issue_no AS 期号, kind AS 类别,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS 总篇数,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id AND a.section='free') AS 免费篇,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id AND a.section='paid') AS 付费篇
  FROM public.news_issues i ORDER BY issue_no;


-- ============================================================
-- 第 2 步：删掉所有付费文章
--   注意：已经买过的记录（news_owned）保留不动 ——
--         万一以后这期又变回付费刊，买过的人不用再买一次。
-- ============================================================
DELETE FROM public.news_articles WHERE section = 'paid';


-- ============================================================
-- 第 3 步：把所有期改成免费刊
--   （现在只有第 1 期；以后如果还有别的付费刊，这里会一起改掉，
--     不想全改的话把这句的 WHERE 去掉自己挑）
-- ============================================================
UPDATE public.news_issues SET kind = 'free';

-- 既然都是免费刊了，价格栏留着也没意义，顺手归零
UPDATE public.news_issues SET price = 0 WHERE kind = 'free';


-- ============================================================
-- 第 4 步：验证
-- ============================================================
SELECT '删之后' AS 阶段, issue_no AS 期号, kind AS 类别, price AS 价格,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id) AS 总篇数,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id AND a.section='free') AS 免费篇,
       (SELECT count(*) FROM public.news_articles a WHERE a.issue_id = i.id AND a.section='paid') AS 付费篇,
       published AS 已出刊
  FROM public.news_issues i ORDER BY issue_no;

-- 还剩几篇付费文章（应该是 0）
SELECT count(*) AS 剩余付费文章数 FROM public.news_articles WHERE section = 'paid';


-- ============================================================
--  跑完之后
-- ============================================================
--  · 报刊社页面「🆓 免费刊」里会出现第 1 期，9 篇文章全部可读
--  · 「💰 付费刊」里会是空的（这个标签还在，以后想发收费期可以用）
--  · 买过的记录没动，不影响
-- ============================================================
