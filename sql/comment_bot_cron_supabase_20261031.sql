-- ============================================================
--  用 Supabase 自己跑定时任务：每 10 分钟叫一次评论机器人
--
--  为什么：
--     GitHub Actions 的 cron 在免费仓库上会被严重降频
--     （实测：写的是每 15 分钟，实际 4 小时才跑一次）
--     → 评论发出后可能几小时都没人回
--
--  做法：
--     pg_cron  定时（数据库自带，不用额外服务）
--     pg_net   在数据库里发 HTTP 请求（异步，不等返回）
--     机器人密钥存在 admin_settings 里，不写死在这段 SQL 里
--
--  ⚠️ 前提：项目里能开 pg_cron 和 pg_net 两个扩展
--     先跑「第 0 步」看结果：
--       · 两行都出来 → 能开
--       · 少了某个 → 你的套餐不支持，那就还是用 GitHub Actions + 外部 cron
-- ============================================================


-- ============================================================
-- 第 0 步：先看这两个扩展能不能用（只查，不改）
-- ============================================================
SELECT name, default_version, installed_version
  FROM pg_available_extensions
 WHERE name IN ('pg_cron', 'pg_net');


-- ============================================================
-- 第 1 步：开扩展（两行都成功才行）
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;


-- ============================================================
-- 第 2 步：把机器人密钥存进配置表（存在就更新）
--   ⚠️ 把 <你的COMMENT_BOT_KEY> 换成真值，跑完这句就删掉明文记录
-- ============================================================
INSERT INTO public.admin_settings (key, value)
VALUES ('comment_bot_key', '<你的COMMENT_BOT_KEY>')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;


-- ============================================================
-- 第 3 步：建一个「叫一次机器人」的函数
-- ============================================================
CREATE OR REPLACE FUNCTION public.bot_ping()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_key text;
    v_url text;
    v_req bigint;
BEGIN
    SELECT value INTO v_key FROM public.admin_settings WHERE key = 'comment_bot_key';
    IF v_key IS NULL OR length(v_key) < 8 THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'no-bot-key');
    END IF;

    v_url := 'https://1404832368-3y4ud8ufi1.ap-guangzhou.tencentscf.com/api/comment_bot?k=' || v_key;

    -- pg_net 是异步的：发出去就返回，不等云函数跑完
    SELECT net.http_get(url := v_url, timeout_milliseconds := 30000) INTO v_req;

    RETURN jsonb_build_object('ok', true, 'request_id', v_req,
                              'at', to_char(now(), 'YYYY-MM-DD HH24:MI:SS'));
END;
$$;

REVOKE ALL ON FUNCTION public.bot_ping() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bot_ping() TO postgres;


-- ============================================================
-- 第 4 步：排上定时任务（每 10 分钟）
-- ============================================================
SELECT cron.unschedule('comment-bot-ping')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'comment-bot-ping');

SELECT cron.schedule(
    'comment-bot-ping',
    '*/10 * * * *',
    $$SELECT public.bot_ping();$$
);


-- ============================================================
-- 第 5 步：验收
-- ============================================================
-- 5.1 任务排上了没（应该有一条 comment-bot-ping，schedule = */10 * * * *）
SELECT jobid, jobname, schedule, active FROM cron.job;

-- 5.2 手动跑一次看会不会发出去
SELECT public.bot_ping();

-- 5.3 看 pg_net 收到的响应（status_code 200 就是通了；可能要等几秒）
SELECT id, status_code, left(content, 200) AS 返回前200字, created
  FROM net._http_response
 ORDER BY id DESC
 LIMIT 5;

-- 5.4 看定时任务历史（有没有按时跑）
SELECT jobname, status, return_message,
       to_char(start_time, 'MM-DD HH24:MI') AS 开始时间
  FROM cron.job_run_details
 WHERE jobname = 'comment-bot-ping'
 ORDER BY start_time DESC
 LIMIT 10;


-- ============================================================
-- 附：不想要了怎么取消
-- ============================================================
-- SELECT cron.unschedule('comment-bot-ping');
-- DELETE FROM public.admin_settings WHERE key = 'comment_bot_key';
