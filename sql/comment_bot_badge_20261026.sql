-- ============================================================
-- 给机器人账号加「认证蓝标」
--
-- 站长的蓝标是这张表管的：verified_users
--   评论页会 fetchVerifiedUsers() → select profiles(username) from verified_users
--   然后在名字后面贴那张蓝标图
--
-- 前端写死的名单会被这里的查询结果覆盖，所以必须往表里插。
--
-- 在 Supabase SQL Editor 里跑一次。
-- ============================================================

-- 先看一眼这表长什么样（列名是 user_id 还是别的）
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'verified_users';

-- 插入机器人
insert into public.verified_users (user_id)
values ('11111111-2222-3333-4444-555555555555'::uuid)
on conflict do nothing;

-- 确认（应该输出一行，username = NB频道AI助手）
select v.user_id, p.username
  from public.verified_users v
  left join public.profiles p on p.id = v.user_id
 where v.user_id = '11111111-2222-3333-4444-555555555555'::uuid;
