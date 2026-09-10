-- ============================================================
-- purge_bad_names.sql —— 批量封禁 + 删除 11 个骂人账号
-- 在 Supabase SQL Editor 整段运行
-- 用 ID 数组锁定(用户可以改名,ID 不会变)
-- ============================================================

-- 目标账号(先看一遍确认):
--   一个死妈的用户 / 号主已私募 / 号主私募了 / 号主私募 / 假的Utw号主眉目
--   nb-anxiaoke GaoHanTu=gaygaygaysbsbsb / qxisgay / qxshigay / gay
--   nbchannelgay111 / 勾石作业

-- ---------- 第 1 段:确认这 11 个 ID 就是那 11 个号 ----------
SELECT username, id,
       to_char(created_at AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS 注册时间,
       is_banned AS 已封
  FROM public.profiles
 WHERE id IN (
   '572ec91f-757b-43e3-aa48-d540ce6d17b0',  -- 一个死妈的用户
   '32be6910-86bd-429e-982f-cec390e82704',  -- 号主已私募
   '8b4bd3bd-c7a5-4681-b2a4-ae89a39ce243',  -- 号主私募了
   '604f3d80-4afa-475e-bd9d-2abcc0b39f69',  -- 号主私募
   '83970099-5886-4305-b466-097ce40cb946',  -- 假的Utw号主眉目
   '708484e5-d7fd-4fcc-9156-461b3d03c72d',  -- nb-anxiaoke GaoHanTu=gaygaygaysbsbsb
   'a61acac7-5f23-444f-8773-1c35d2e9b83e',  -- qxisgay
   'da1c1a49-3237-46c2-b403-ad8b8f5bad1b',  -- qxshigay
   '184f956c-a129-43bf-87c2-5e3ccd41c77b',  -- gay
   '67530cdb-259d-4767-9226-cc9bf637e30a',  -- nbchannelgay111
   '80bcae43-ad01-423e-9279-4231e97fcdf4'   -- 勾石作业
 )
 ORDER BY created_at;

-- ---------- 第 2 段:封禁 + 删除 ----------
DO $$
DECLARE
    v_want uuid[] := ARRAY[
        '572ec91f-757b-43e3-aa48-d540ce6d17b0',
        '32be6910-86bd-429e-982f-cec390e82704',
        '8b4bd3bd-c7a5-4681-b2a4-ae89a39ce243',
        '604f3d80-4afa-475e-bd9d-2abcc0b39f69',
        '83970099-5886-4305-b466-097ce40cb946',
        '708484e5-d7fd-4fcc-9156-461b3d03c72d',
        'a61acac7-5f23-444f-8773-1c35d2e9b83e',
        'da1c1a49-3237-46c2-b403-ad8b8f5bad1b',
        '184f956c-a129-43bf-87c2-5e3ccd41c77b',
        '67530cdb-259d-4767-9226-cc9bf637e30a',
        '80bcae43-ad01-423e-9279-4231e97fcdf4'
    ]::uuid[];
    v_ids uuid[];
    v_company_ids bigint[];
    v_ids_t text[];
    r record;
    v_banned int;
BEGIN
    SELECT array_agg(id) INTO v_ids FROM public.profiles WHERE id = ANY(v_want);
    IF v_ids IS NULL THEN
        RAISE EXCEPTION '没找到任何匹配的账号,已中止';
    END IF;
    v_ids_t := array(SELECT unnest(v_ids)::text);

    -- 他持有的公司(这些公司的数据也要一起清)
    IF EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'user_companies') THEN
        SELECT array_agg(id) INTO v_company_ids
          FROM public.user_companies WHERE user_id = ANY(v_ids);
    END IF;

    -- 1) 先封禁,防止删除期间继续操作
    UPDATE public.profiles
       SET is_banned = true,
           banned_reason = '用户名/简介含辱骂内容,管理员清理'
     WHERE id = ANY(v_ids);

    -- 2) 按「用户 ID」归属的数据
    FOR r IN SELECT * FROM (VALUES
        ('support_logs', 'supporter_id'),
        ('support_rules', 'user_id'),
        ('holdings', 'user_id'),
        ('transactions', 'user_id'),
        ('user_companies', 'user_id'),
        ('comment_reactions', 'user_id'),
        ('notifications', 'user_id'),
        ('notifications', 'from_user_id'),
        ('reports', 'reporter_user_id'),
        ('product_purchases', 'buyer_id'),
        ('product_purchases', 'seller_id'),
        ('product_downloads', 'user_id'),
        ('products', 'author_id'),
        ('user_achievements', 'user_id'),
        ('user_checkins', 'user_id'),
        ('check_in_records', 'user_id'),
        ('checkin_fix_records', 'user_id'),
        ('verified_users', 'user_id'),
        ('bank_logs', 'user_id'),
        ('bank_accounts', 'user_id'),
        ('user_titles', 'user_id'),
        ('user_balance_counts', 'user_id'),
        ('user_items', 'user_id'),
        ('lottery_records', 'user_id'),
        ('transfers', 'from_user'),
        ('transfers', 'to_user'),
        ('coin_claims', 'user_id'),
        ('messages', 'sender_id'),
        ('conversations', 'user_low'),
        ('conversations', 'user_high'),
        ('blocked_users', 'user_id'),
        ('blocked_users', 'blocked_id'),
        ('friend_requests', 'from_user_id'),
        ('friend_requests', 'to_user_id'),
        ('friendships', 'user_a'),
        ('friendships', 'user_b'),
        ('profile_visits', 'visitor_id'),
        ('profile_visits', 'user_id'),
        ('user_sessions', 'user_id')
    ) AS v(tbl, col) LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = r.tbl AND column_name = r.col) THEN
            EXECUTE format('DELETE FROM public.%I WHERE %I = ANY($1)', r.tbl, r.col) USING v_ids;
        END IF;
    END LOOP;

    -- 3) 按「他公司 ID」归属的数据
    IF v_company_ids IS NOT NULL THEN
        FOR r IN SELECT * FROM (VALUES
            ('support_logs', 'company_id'),
            ('support_rules', 'company_id'),
            ('holdings', 'company_id'),
            ('transactions', 'company_id'),
            ('stock_daily_kline', 'company_id')
        ) AS v(tbl, col) LOOP
            IF EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_schema = 'public' AND table_name = r.tbl AND column_name = r.col) THEN
                EXECUTE format('DELETE FROM public.%I WHERE %I = ANY($1)', r.tbl, r.col) USING v_company_ids;
            END IF;
        END LOOP;
    END IF;

    -- 4) 评论:先删相关举报,再删回复,最后删本人评论
    IF EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'comments') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'reports' AND column_name = 'comment_id') THEN
            DELETE FROM public.reports
             WHERE comment_id IN (SELECT id FROM public.comments WHERE user_id = ANY(v_ids));
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'comments' AND column_name = 'parent_id') THEN
            DELETE FROM public.comments
             WHERE parent_id IN (SELECT id FROM public.comments WHERE user_id = ANY(v_ids));
        END IF;
        DELETE FROM public.comments WHERE user_id = ANY(v_ids);
    END IF;

    -- 5) 上传的文件(头像/作品)
    IF EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'storage' AND table_name = 'objects') THEN
        DELETE FROM storage.objects WHERE owner::text = ANY(v_ids_t);
    END IF;

    SELECT count(*) INTO v_banned FROM public.profiles WHERE id = ANY(v_ids) AND is_banned;
    RAISE NOTICE '已封禁 % 个账号并清空其数据(profiles 保留封禁标记,便于追溯)', v_banned;
END $$;

-- ---------- 第 3 段:确认结果 ----------
SELECT username, id, is_banned, banned_reason
  FROM public.profiles
 WHERE id IN (
   '572ec91f-757b-43e3-aa48-d540ce6d17b0',
   '32be6910-86bd-429e-982f-cec390e82704',
   '8b4bd3bd-c7a5-4681-b2a4-ae89a39ce243',
   '604f3d80-4afa-475e-bd9d-2abcc0b39f69',
   '83970099-5886-4305-b466-097ce40cb946',
   '708484e5-d7fd-4fcc-9156-461b3d03c72d',
   'a61acac7-5f23-444f-8773-1c35d2e9b83e',
   'da1c1a49-3237-46c2-b403-ad8b8f5bad1b',
   '184f956c-a129-43bf-87c2-5e3ccd41c77b',
   '67530cdb-259d-4767-9226-cc9bf637e30a',
   '80bcae43-ad01-423e-9279-4231e97fcdf4'
 )
 ORDER BY created_at;
