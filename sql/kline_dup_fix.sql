-- ============================================================
-- 修复 K 线「串数据」:重名公司显示的是同一份走势
--
-- 现象:两家公司重名时(如两家「Utw」),它们的 K 线完全一样,
--       而且都显示成第一家(市值大的那家)的走势。
--
-- 原因:采样快照 stock_history_full.snapshot 里只有 names + values 两个数组,
--       而 get_company_kline 用 array_position(names, 公司名) 找位置 ——
--       公司重名时它永远返回第一个同名的位置,于是第二家拿到了第一家的数据。
--       目前库里有 6 组重名:Utw / 微软 / 10V公司 / Uue / 3ty / NB
--
-- 修法:
--   ① 采样时额外存一份 ids 数组(与 values 同顺序),K线直接按公司 id 定位 —— 彻底准确
--   ② 老快照(没有 ids)回退:按「同名里第几家」取第 k 个匹配位置,不再永远取第一个
--
-- 在 Supabase SQL Editor 执行(幂等,可重复执行)
-- ============================================================

-- ---------- 1) 采样函数:快照里加上 ids ----------
CREATE OR REPLACE FUNCTION public.sample_market_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ids    text[] := ARRAY[]::text[];
    v_names  text[] := ARRAY[]::text[];
    v_values bigint[] := ARRAY[]::bigint[];
    v_total  bigint := 0;
    v_count  integer := 0;
    r RECORD;
BEGIN
    -- 全天采样（不再限制交易时段）：交易时段记真实走势，休市时段记平线
    FOR r IN SELECT id, company_name, market_value FROM public.user_companies ORDER BY id LOOP
        v_ids    := v_ids || r.id::text;
        v_names  := v_names || r.company_name;
        v_values := v_values || r.market_value;
        v_total  := v_total + r.market_value;
        v_count  := v_count + 1;
    END LOOP;

    IF v_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', '暂无公司');
    END IF;

    INSERT INTO public.stock_history_full (recorded_at, total_value, snapshot)
    VALUES (now(), v_total, jsonb_build_object(
        'ids',    to_jsonb(v_ids),
        'names',  to_jsonb(v_names),
        'values', to_jsonb(v_values)));

    -- 同步聚合当日K线（open 首次插入，close/high/low 逐步更新）
    PERFORM public.record_daily_kline();

    RETURN jsonb_build_object('success', true, 'companies', v_count, 'total', v_total);
END;
$$;

-- ---------- 2) K线取数:优先按公司 id 定位 ----------
CREATE OR REPLACE FUNCTION public.get_company_kline(p_company_id bigint)
RETURNS TABLE (t timestamptz, v bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name text;
    v_rank int;
BEGIN
    SELECT company_name INTO v_name FROM public.user_companies WHERE id = p_company_id;
    IF v_name IS NULL THEN
        RETURN;
    END IF;

    -- 同名公司按 id 升序,算出自己是第几家(0 基),用于给老快照对号入座
    SELECT count(*) INTO v_rank
      FROM public.user_companies
     WHERE company_name = v_name AND id < p_company_id;

    RETURN QUERY
    SELECT h.recorded_at,
           ((h.snapshot->'values')->(h.pos - 1)::int)::text::bigint AS v
    FROM (
        SELECT h2.recorded_at, h2.snapshot,
               COALESCE(
                   -- ① 新快照:直接按公司 id 找位置(最准,改名/重名/增删都不受影响)
                   CASE WHEN h2.snapshot ? 'ids' THEN
                       array_position(
                           ARRAY(SELECT jsonb_array_elements_text(h2.snapshot->'ids')),
                           p_company_id::text)
                   END,
                   -- ② 老快照(只有 names/values):取「同名里第 v_rank+1 家」的位置,
                   --    这样第二家同名公司也能拿到自己的数据,不再串成第一家的
                   (array_positions(
                       ARRAY(SELECT jsonb_array_elements_text(h2.snapshot->'names')),
                       v_name))[v_rank + 1]
               ) AS pos
          FROM public.stock_history_full h2
    ) h
    WHERE h.pos IS NOT NULL
    ORDER BY h.recorded_at DESC;
END;
$$;

-- ---------- 3) 授权 ----------
GRANT EXECUTE ON FUNCTION public.get_company_kline(bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.sample_market_snapshot() TO anon;

-- ---------- 4) 验收 ----------
-- 4.1 重名公司现在应该拿到各自的数据(两家最新值应不同)
SELECT u.id AS 公司ID, u.company_name AS 公司名, u.market_value AS 当前市值,
       k.t AS 最新K线时间, k.v AS 最新K线值
  FROM public.user_companies u
  LEFT JOIN LATERAL (
      SELECT * FROM public.get_company_kline(u.id) LIMIT 1
  ) k ON TRUE
 WHERE u.company_name IN (
     SELECT company_name FROM public.user_companies GROUP BY company_name HAVING count(*) > 1)
 ORDER BY u.company_name, u.id;

-- 4.2 采样函数已带上 ids(下一次采样后,快照里就能看到 ids 字段)
SELECT (snapshot ? 'ids') AS 最新快照已含ids, jsonb_array_length(snapshot->'names') AS 公司数
  FROM public.stock_history_full ORDER BY recorded_at DESC LIMIT 1;
