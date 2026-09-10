-- ============================================================
-- delete_bad_names.sql —— 彻底删除 11 个骂人账号(不封禁,直接抹掉)
-- 在 Supabase SQL Editor 整段运行
-- 用 ID 数组锁定(用户可以改名,ID 不会变)
-- ============================================================

-- 目标账号:
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

-- ---------- 第 2 段:删除(先清光关联数据,最后删 profiles 本体) ----------
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
    v_rows bigint;
BEGIN
    SELECT array_agg(id) INTO v_ids FROM public.profiles WHERE id = ANY(v_want);
    IF v_ids IS NULL THEN
        RAISE EXCEPTION '没找到任何匹配的账号,已中止';
    END IF;
    v_ids_t := array(SELECT unnest(v_ids)::text);

    -- 他们持有的公司(公司相关数据一起清)
    IF EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'user_companies') THEN
        SELECT array_agg(id) INTO v_company_ids
          FROM public.user_companies WHERE user_id = ANY(v_ids);
    END IF;

    -- 1) 自动清理:所有外键指向 profiles 的表(一网打尽,不依赖手写清单)
    FOR r IN
        SELECT DISTINCT tc.table_schema AS sch, tc.table_name AS tbl, kcu.column_name AS col
          FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu
            ON kcu.constraint_name = tc.constraint_name
           AND kcu.table_schema = tc.table_schema
          JOIN information_schema.constraint_column_usage ccu
            ON ccu.constraint_name = tc.constraint_name
           AND ccu.table_schema = tc.table_schema
         WHERE tc.constraint_type = 'FOREIGN KEY'
           AND ccu.table_schema = 'public'
           AND ccu.table_name = 'profiles'
    LOOP
        BEGIN
            EXECUTE format('DELETE FROM %I.%I WHERE %I::text = ANY($1)', r.sch, r.tbl, r.col)
              USING v_ids_t;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '跳过 %.%(%) : %', r.sch, r.tbl, r.col, SQLERRM;
        END;
    END LOOP;

    -- 2) 兜底:手写清单(没有外键约束、但按业务归属的数据)
    FOR r IN SELECT * FROM (VALUES
        ('public', 'comments', 'user_id'),
        ('public', 'comments', 'parent_id'),
        ('public', 'reports', 'reporter_user_id'),
        ('public', 'products', 'author_id'),
        ('public', 'support_logs', 'supporter_id'),
        ('public', 'holdings', 'user_id'),
        ('public', 'transactions', 'user_id'),
        ('public', 'user_companies', 'user_id'),
        ('public', 'bank_accounts', 'user_id'),
        ('public', 'bank_logs', 'user_id'),
        ('public', 'user_titles', 'user_id'),
        ('public', 'user_balance_counts', 'user_id'),
        ('public', 'user_items', 'user_id'),
        ('public', 'user_achievements', 'user_id'),
        ('public', 'user_checkins', 'user_id'),
        ('public', 'check_in_records', 'user_id'),
        ('public', 'checkin_fix_records', 'user_id'),
        ('public', 'verified_users', 'user_id'),
        ('public', 'lottery_records', 'user_id'),
        ('public', 'transfers', 'from_user'),
        ('public', 'transfers', 'to_user'),
        ('public', 'coin_claims', 'user_id'),
        ('public', 'messages', 'sender_id'),
        ('public', 'conversations', 'user_low'),
        ('public', 'conversations', 'user_high'),
        ('public', 'blocked_users', 'user_id'),
        ('public', 'blocked_users', 'blocked_id'),
        ('public', 'friend_requests', 'from_user_id'),
        ('public', 'friend_requests', 'to_user_id'),
        ('public', 'friendships', 'user_a'),
        ('public', 'friendships', 'user_b'),
        ('public', 'profile_visits', 'visitor_id'),
        ('public', 'profile_visits', 'user_id'),
        ('public', 'notifications', 'user_id'),
        ('public', 'notifications', 'from_user_id'),
        ('public', 'product_purchases', 'buyer_id'),
        ('public', 'product_purchases', 'seller_id'),
        ('public', 'product_downloads', 'user_id'),
        ('public', 'comment_reactions', 'user_id'),
        ('public', 'user_sessions', 'user_id')
    ) AS v(sch, tbl, col) LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = r.sch AND table_name = r.tbl AND column_name = r.col) THEN
            BEGIN
                EXECUTE format('DELETE FROM %I.%I WHERE %I::text = ANY($1)', r.sch, r.tbl, r.col)
                  USING v_ids_t;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '跳过 %.%(%) : %', r.sch, r.tbl, r.col, SQLERRM;
            END;
        END IF;
    END LOOP;

    -- 3) 他们公司名下的数据
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
                BEGIN
                    EXECUTE format('DELETE FROM public.%I WHERE %I = ANY($1)', r.tbl, r.col)
                      USING v_company_ids;
                EXCEPTION WHEN OTHERS THEN
                    RAISE NOTICE '跳过 %(%) : %', r.tbl, r.col, SQLERRM;
                END;
            END IF;
        END LOOP;
    END IF;

    -- 4) 上传的头像/作品
    IF EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'storage' AND table_name = 'objects') THEN
        BEGIN
            DELETE FROM storage.objects WHERE owner::text = ANY(v_ids_t);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'storage.objects 跳过: %', SQLERRM;
        END;
    END IF;

    -- 5) 最后删账号本体
    DELETE FROM public.profiles WHERE id = ANY(v_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RAISE NOTICE '已彻底删除 % 个账号及其全部数据', v_rows;
END $$;

-- ---------- 第 3 段:确认(应该 0 行) ----------
SELECT username, id FROM public.profiles
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
 );
