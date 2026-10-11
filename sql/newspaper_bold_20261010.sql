-- ============================================================
--  NB报刊社 · 正文恢复加粗
--
--  站长说：改之前的报刊内容里，「」里好像是加粗的。
--  翻 git 历史（e22b062）确认了 —— 旧版正文里确实有 8 处 <b>：
--
--      1                                    ← dateline 的期号，不是正文
--      nb-channel.top                       ← 正文：域名证书那篇
--      「这个不用给大家看。」                  ← 正文：域名证书那篇
--      NB频道总部、U星、AWM市…（十二座城市名）  ← 正文：天气瞎报那篇
--      你和朋友同时打开，看到的数字是一样的。    ← 正文：天气瞎报那篇
--      市值 / NB频道 ×2                       ← 短讯标题里的，短讯本来就是粗体
--
--  我改成数据驱动之后正文是纯文本，esc() 把这些标签全转义掉了 —— 加粗丢了。
--
--  现在前端正文支持 **文字** 这种写法（先转义再套 <b>，安全），
--  这个脚本负责把上面那几处补回 ** 。
--
--  用法：整段复制到 Supabase → SQL Editor → Run（幂等）
-- ============================================================


-- ============================================================
-- 第 1 步：先看看现在这两篇正文长什么样
-- ============================================================
SELECT id, left(headline, 26) AS 标题,
       CASE WHEN position('**' in body) > 0 THEN '已经有 **' ELSE '还没有 **' END AS 状态
  FROM public.news_articles
 WHERE kind = 'article' AND body <> ''
 ORDER BY sort;


-- ============================================================
-- 第 2 步：补上加粗（按文章标题定位，认准才改）
-- ============================================================
DO $$
DECLARE
    v_n integer := 0;
    v_b text;
BEGIN
    -- 2.1 域名证书那篇：nb-channel.top 和 「这个不用给大家看。」
    SELECT body INTO v_b FROM public.news_articles
     WHERE kind = 'article' AND headline LIKE '%关于域名%' LIMIT 1;
    IF v_b IS NOT NULL AND position('**' in v_b) = 0 THEN
        v_b := replace(v_b, 'nb-channel.top', '**nb-channel.top**');
        v_b := replace(v_b, '「这个不用给大家看。」', '**「这个不用给大家看。」**');
        UPDATE public.news_articles SET body = v_b
         WHERE kind = 'article' AND headline LIKE '%关于域名%';
        v_n := v_n + 1;
    END IF;

    -- 2.2 天气瞎报那篇：十二座城市名 和 「你和朋友同时打开，看到的数字是一样的。」
    SELECT body INTO v_b FROM public.news_articles
     WHERE kind = 'article' AND headline LIKE '%天气瞎报%开张%' LIMIT 1;
    IF v_b IS NOT NULL AND position('**' in v_b) = 0 THEN
        v_b := replace(v_b, 'NB频道总部、U星、AWM市、Lemon市、Oganesson市、Fafat市、GC3市、UVS市、UWSF市、PTC市、5U市、Ubn市',
                            '**NB频道总部、U星、AWM市、Lemon市、Oganesson市、Fafat市、GC3市、UVS市、UWSF市、PTC市、5U市、Ubn市**');
        v_b := replace(v_b, '你和朋友同时打开，看到的数字是一样的。',
                            '**你和朋友同时打开，看到的数字是一样的。**');
        UPDATE public.news_articles SET body = v_b
         WHERE kind = 'article' AND headline LIKE '%天气瞎报%开张%';
        v_n := v_n + 1;
    END IF;

    RAISE NOTICE '改了 % 篇', v_n;
END $$;


-- ============================================================
-- 第 3 步：验证
-- ============================================================
SELECT id, left(headline, 26) AS 标题,
       (length(body) - length(replace(body, '**', ''))) / 2 AS 加粗对数,
       left(body, 60) AS 正文开头
  FROM public.news_articles
 WHERE kind = 'article' AND body <> ''
 ORDER BY sort;


-- ============================================================
--  跑完之后
-- ============================================================
--  · 报纸上「**文字**」会显示成加粗
--  · 站长以后在后台写正文时，想让哪句话粗体，就用两个星号包起来：
--        **这句话会加粗**
--    换行照旧：空一行分段
--  · 注意：星号要成对，别写单个 *
-- ============================================================
