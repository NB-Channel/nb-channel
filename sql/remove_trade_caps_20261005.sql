-- ============================================================
--  去掉股票交易的「每日额度」和过紧的「单笔上限」
--
--  背景
--    2026-10-04 为了防止刷币，给买入和加钱加了两个限制：
--      ① 单笔买入 ≤ 公司账上现金的 50%
--      ② 【每家公司每天】的买入总额 ≤ 当日开盘现金的 50%（上限 5000 万）
--    其中第 ② 条是挂在【公司】上、不是挂在账号上的 ——
--    意思是热门公司被几个人买满之后，今天谁也别想再买进去，
--    只会看到一句「今天已经被买入 XXX，达到每日上限」。
--
--    站长反馈：「太复杂了，都不会用」。这条是交易被拒的主因，去掉。
--
--  为什么去掉是安全的
--    这个市场是 AMM（公司账上的钱 ÷ 公司总股数），它自己会纠偏：
--      · 想拉高价格，得真金白银买进去；想把钱拿回来就得卖，
--        一卖价格立刻跌回去 —— 拉盘砸盘赚不到钱
--      · 一笔钱买进去再全卖掉，公司账上精确回到原样，只损失手续费
--    所以不需要靠额度来防操纵，AMM 的数学本身就防住了。
--    （2026-10-04 Utw 那次 532 亿拉盘就是这么自己崩掉的。）
--
--  保留了什么
--    · 单笔上限【还在】，但放宽到公司账上现金的 100 倍 ——
--      等于没有限制，只用来挡住「手滑多打几个 9」这种误输入
--    · 交易时段（8:00-20:00）、手续费、增资后 7 天锁定 等等，全部不动
--    · 防刷屏、限频那些也全部不动
--
--  怎么做
--    不去重写整个函数（几百行，容易抄错），
--    而是用 pg_get_functiondef 取出数据库里【当前的】函数源码，
--    做几处字符串替换，再执行回去。这样函数里其它逻辑一个字都不会变。
--
--  用法：整段复制到 Supabase → SQL Editor → Run
--        （注意：这里不能用 psql 的 \set 之类的元命令，SQL Editor 不认）
-- ============================================================

-- ------------------------------------------------------------
-- 一、买入函数 _orig_buy_stock
-- ------------------------------------------------------------
DO $$
DECLARE
    v_src   text;
    v_new   text;
    v_n     int := 0;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = '_orig_buy_stock'
    LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public._orig_buy_stock —— 请先确认函数名，别继续往下跑';
    END IF;

    v_new := v_src;

    -- ① 每日买入额度 → 放到极大（等于没有）
    v_new := regexp_replace(
        v_new,
        'v_buy_pct\s+CONSTANT\s+numeric\s*:=\s*0\.5',
        'v_buy_pct    CONSTANT numeric := 1000000000');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;

    -- ② 绝对上限 5000 万 → 放到极大
    v_new := regexp_replace(
        v_new,
        'v_abs_cap\s+CONSTANT\s+numeric\s*:=\s*50000000',
        'v_abs_cap    CONSTANT numeric := 999999999999');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    -- ③ 单笔上限：公司账上现金的 50% → 100 倍（只挡误输入）
    v_new := regexp_replace(
        v_new,
        'v_cap\s*:=\s*floor\(v_cash\s*\*\s*0\.5\)',
        'v_cap := floor(v_cash * 100)');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    -- ④ 报错文案也改掉，别再提"一半""每日上限"
    v_new := replace(v_new,
        '单笔买入不能超过池子现金的一半（当前池子 %s NB币，单笔最多买 %s）。想买更多请分几笔。',
        '这一笔金额太大了（公司账上只有 %s NB币）。确认一下是不是多打了几位数字？');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;

    IF v_n = 0 THEN
        RAISE EXCEPTION '一处都没替换成功 —— 函数源码和预期不一样，请把 pg_get_functiondef 的输出贴出来看看，别硬改';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ _orig_buy_stock 改好了，替换了 % 处', v_n;
END $$;


-- ------------------------------------------------------------
-- 二、加钱函数 inject_company_capital
-- ------------------------------------------------------------
DO $$
DECLARE
    v_src   text;
    v_new   text;
    v_n     int := 0;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'inject_company_capital'
    LIMIT 1;

    IF v_src IS NULL THEN
        RAISE EXCEPTION '找不到 public.inject_company_capital';
    END IF;

    v_new := v_src;

    v_new := regexp_replace(
        v_new,
        'v_inj_pct\s+CONSTANT\s+numeric\s*:=\s*1\.0',
        'v_inj_pct CONSTANT numeric := 1000000000');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    v_new := regexp_replace(
        v_new,
        'v_abs_cap\s+CONSTANT\s+numeric\s*:=\s*50000000',
        'v_abs_cap CONSTANT numeric := 999999999999');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    v_new := regexp_replace(
        v_new,
        'v_cap\s*:=\s*floor\(v_pc\s*\*\s*2\)',
        'v_cap := floor(v_pc * 100)');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;
    v_src := v_new;

    v_new := replace(v_new,
        '单笔增资不能超过池子现金的 2 倍（当前池子 %s NB币，单笔最多 %s）。想加更多请分几次。',
        '这一笔金额太大了（公司账上只有 %s NB币）。确认一下是不是多打了几位数字？');
    IF v_new <> v_src THEN v_n := v_n + 1; END IF;

    IF v_n = 0 THEN
        RAISE EXCEPTION 'inject_company_capital 一处都没替换成功，请先检查函数源码';
    END IF;

    EXECUTE v_new;
    RAISE NOTICE '✅ inject_company_capital 改好了，替换了 % 处', v_n;
END $$;


-- ------------------------------------------------------------
-- 三、验证：确认改完了
-- ------------------------------------------------------------
SELECT
    p.proname                                        AS 函数,
    CASE
      WHEN pg_get_functiondef(p.oid) LIKE '%1000000000%' THEN '✅ 额度已放开'
      ELSE '❌ 还是老样子'
    END                                              AS 每日额度,
    CASE
      WHEN pg_get_functiondef(p.oid) LIKE '%v_cash * 100%'
        OR pg_get_functiondef(p.oid) LIKE '%v_pc * 100%' THEN '✅ 单笔放宽到 100 倍'
      WHEN pg_get_functiondef(p.oid) LIKE '%v_cash * 0.5%'
        OR pg_get_functiondef(p.oid) LIKE '%v_pc * 2%'   THEN '❌ 还是 50% / 2 倍'
      ELSE '— 没有单笔上限'
    END                                              AS 单笔上限
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('_orig_buy_stock', 'inject_company_capital')
ORDER BY p.proname;
