-- ============================================================
-- 第二步 · 撤销后台数据表的匿名读权限
-- ============================================================
-- 前提：第一步的三个 RPC 已经建好，而且线上后台已经改成调 RPC 了。
--       （验证方式：后台的举报列表 / 公司认证审核 能正常显示。）
--
-- 跑完的效果：外面拿网页里那把公开 key 再也读不到举报内容，
--             别人克隆一份后台页面部署出去，打开就是一个空壳。
--
-- 随时可以回滚：文件末尾有 GRANT 语句，跑一下就能恢复原状。
-- ============================================================

-- 举报表：谁举报了谁、举报原因、被举报的评论/公司/作品，全在这里
REVOKE SELECT ON public.reports  FROM anon, authenticated;

-- API 访问日志：后台走 admin_get_api_logs 读，用不着直连
REVOKE SELECT ON public.api_logs FROM anon, authenticated;


-- ---------- 验收：下面两条都应该报 permission denied ----------
-- （在 SQL Editor 里单独选中执行这两句，看到红色 permission denied 就是成功了）
-- SELECT * FROM public.reports  LIMIT 1;
-- SELECT * FROM public.api_logs LIMIT 1;


-- ============================================================
-- 万一后台读不到数据了，跑这三行恢复（顺序无所谓）
-- ============================================================
-- GRANT SELECT ON public.reports  TO anon, authenticated;
-- GRANT SELECT ON public.api_logs TO anon, authenticated;

-- 注意：举报的「写入」权限没有动过 —— 用户举报评论照常能用。
--       这里只撤了 SELECT（读），INSERT 不受影响。
