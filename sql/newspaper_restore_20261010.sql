-- ============================================================
--  NB报刊社 · 补回旧版丢失的五处内容
--
--  站长比对 git 历史（e22b062）后确认要补的：
--      ① 头条标题应该是两行（旧版有 <br>）
--      ② 正文里有两段不缩进（旧版是 <p class="noindent">）
--      ③ 短讯里「市值」是加粗的
--      ④ 便民信息第二条右边应该是「行情与交易」，不是文件名
--      ⑤ 「天气瞎报」那篇少了一句 —— 补回来，季节改成现在的「深秋·寒露」
--
--  前端对应的写法（这一版新加的）：
--      **文字**   →  加粗
--      换行       →  <br>（标题里直接换行就行）
--      段首 ::    →  这段不缩进
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看现在的样子
-- ============================================================
SELECT id, kind AS 类型, left(headline, 30) AS 标题,
       length(body) AS 正文长
  FROM public.news_articles
 WHERE issue_id = (SELECT id FROM public.news_issues WHERE issue_no = 1)
 ORDER BY sort, id;


-- ============================================================
-- 第 2 步：逐条补
-- ============================================================
DO $$
DECLARE
    v_b text;
    v_n integer := 0;
BEGIN
    -- ── ① 头条标题改成两行 ──
    UPDATE public.news_articles
       SET headline = E'官网 1.0.8 上线\n「关于域名」挂出域名证书'
     WHERE kind = 'article' AND headline LIKE '官网 1.0.8 上线%'
       AND position(E'\n' in headline) = 0;
    IF FOUND THEN v_n := v_n + 1; RAISE NOTICE '① 头条标题改成两行'; END IF;

    -- ── ② + ⑤ 域名证书那篇：两段加 :: 不缩进 ──
    SELECT body INTO v_b FROM public.news_articles
     WHERE kind = 'article' AND headline LIKE '%关于域名%' LIMIT 1;
    IF v_b IS NOT NULL AND position('::' in v_b) = 0 THEN
        v_b := replace(v_b, E'\n\n据站长介绍', E'\n\n::据站长介绍');
        v_b := replace(v_b, E'\n\n另据观察',   E'\n\n::另据观察');
        UPDATE public.news_articles SET body = v_b
         WHERE kind = 'article' AND headline LIKE '%关于域名%';
        v_n := v_n + 1; RAISE NOTICE '② 两段改成不缩进';
    END IF;

    -- ── ⑤ 天气瞎报那篇：补回季节那句，改成「深秋·寒露」 ──
    SELECT body INTO v_b FROM public.news_articles
     WHERE kind = 'article' AND headline LIKE '%天气瞎报%开张%' LIMIT 1;
    IF v_b IS NOT NULL AND position('时节' in v_b) = 0 THEN
        v_b := replace(v_b,
            '栏目按真实季节走，数据每十秒刷新一次，由数据库统一计算 ——',
            E'栏目按真实季节走 —— 现在这个时节显示的是「深秋·寒露」。数据每十秒刷新一次，并且由数据库统一计算：');
        UPDATE public.news_articles SET body = v_b
         WHERE kind = 'article' AND headline LIKE '%天气瞎报%开张%';
        v_n := v_n + 1; RAISE NOTICE '⑤ 补回季节那句（深秋·寒露）';
    END IF;

    -- ── ③ 短讯里「市值」加粗 ──
    UPDATE public.news_articles
       SET headline = replace(headline, '公司税改按市值征收', '公司税改按**市值**征收')
     WHERE kind = 'brief' AND headline LIKE '%公司税改按市值征收%'
       AND position('**' in headline) = 0;
    IF FOUND THEN v_n := v_n + 1; RAISE NOTICE '③ 短讯「市值」加粗'; END IF;

    -- ── ④ 便民信息第二条右边改回「行情与交易」 ──
    UPDATE public.news_articles
       SET body = replace(body, 'Virtual stock.html', '行情与交易')
     WHERE kind = 'service' AND position('Virtual stock.html' in body) > 0;
    IF FOUND THEN v_n := v_n + 1; RAISE NOTICE '④ 便民信息改成「行情与交易」'; END IF;

    RAISE NOTICE '一共改了 % 处', v_n;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
SELECT sort AS 排序, kind AS 类型,
       CASE WHEN position(E'\n' in headline) > 0 THEN '两行标题'
            WHEN position('**' in headline) > 0 THEN '标题有加粗'
            ELSE '' END AS 标题标记,
       replace(headline, E'\n', ' ⏎ ') AS 标题
  FROM public.news_articles
 WHERE issue_id = (SELECT id FROM public.news_issues WHERE issue_no = 1)
 ORDER BY sort, id;

SELECT '正文里的 ** 对数' AS 项目,
       sum((length(body) - length(replace(body, '**', ''))) / 2)::text AS 值
  FROM public.news_articles
 WHERE issue_id = (SELECT id FROM public.news_issues WHERE issue_no = 1)
UNION ALL
SELECT '不缩进的段落（::）',
       sum((length(body) - length(replace(body, '::', ''))) / 2)::text
  FROM public.news_articles
 WHERE issue_id = (SELECT id FROM public.news_issues WHERE issue_no = 1)
UNION ALL
SELECT '便民信息里还剩几个文件名',
       count(*)::text
  FROM public.news_articles
 WHERE kind = 'service' AND position('.html' in body) > 0;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 头条标题分两行
--  · 那两段不缩进（和后两段形成对比）
--  · 短讯里「市值」加粗
--  · 便民信息第二条右边是「行情与交易」
--  · 天气瞎报那篇恢复「现在这个时节显示的是「深秋·寒露」」
--
--  以后站长写正文可以用的三个写法：
--      **这句话加粗**
--      段首写 :: 这一段就不缩进
--      标题里直接换行（回车）就会断成两行
-- ============================================================
