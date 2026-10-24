-- ============================================================
-- NB频道 - 匿名权限紧急止血 v2(只禁写,不动读,立即执行安全)
-- 1) 禁止匿名直接 增/改/删 核心资金与账号表(写必须走 RPC)
-- 2) 不碰 SELECT/读取(商店、排行榜、主页等公开读不受影响)
-- 3) 若执行后个别功能报 403(如个人中心改名),把功能告诉我,我补 RPC
-- 注意:RLS 完整收口与 SELECT 字段白名单在下一步(勿手动放开权限)
-- ============================================================

REVOKE INSERT, UPDATE, DELETE ON
    public.profiles,          -- 账号/余额/头像/简介/邮箱(核心!)
    public.user_companies,    -- 公司(防删/防伪造)
    public.bank_accounts,     -- 银行存款
    public.bank_logs,
    public.holdings,          -- 股票持仓
    public.transactions,      -- 股票/交易流水
    public.transfers,         -- 转账/红包
    public.lottery_records,   -- 抽奖记录(防伪造中奖)
    public.user_titles,       -- 称号(防伪造)
    public.user_achievements  -- 成就(防伪造)
FROM anon;
