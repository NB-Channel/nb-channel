# 数据库权限注意事项（务必先读）

> 这份文档是 **2026-09-12 一次真实安全事件** 的复盘产物，请每次新增数据库函数前扫一眼。

## ⚠️ 最大的坑：Supabase 上 `REVOKE ... FROM PUBLIC` 等于没锁

**Supabase 会给 `anon` 和 `authenticated` 角色单独授权**，不走 `PUBLIC` 这个伪角色。
所以下面这种写法**完全没有效果**：

```sql
-- ❌ 错的：anon 的独立授权原封不动，函数依然对全网开放
REVOKE ALL ON FUNCTION public.create_user_session(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_user_session(uuid) TO service_role;
```

**必须显式列出角色**：

```sql
-- ✅ 对的
REVOKE ALL ON FUNCTION public.create_user_session(uuid) FROM PUBLIC, anon, authenticated;
```

### 这次事件的后果

`create_user_session`（签发登录令牌的内部函数）当时就是这样写的，于是：

```
POST /rest/v1/rpc/create_user_session  {"p_user_id":"任意用户ID"}
→ 直接返回 32 位会话令牌 → 拿它就能以该用户身份操作
```

不需要密码、不需要邮箱验证码。而 `user_id` 在评论区、公司列表、好友列表里都是公开的。
**实测确认可读该账号余额，属于完整账号接管。**

同一批还漏了（都已于 2026-09-12 修复）：

| 函数 | 可被匿名拿去做 |
|---|---|
| `create_user_session` | 伪造任意账号登录态 🔴 |
| `_verify_email_code` | 消耗／试探别人的邮箱验证码 |
| `_admin_token_valid` | 试探后台令牌 |
| `admin_ban_user(uuid,text)` | 封禁任意账号 🔴 |
| `admin_verify_company` / `admin_ignore_report` / `admin_rename_company` | 认证任意公司 / 忽略举报 / 改公司名 |
| `claim_coin` / `consume_fee_discount` / `delete_verified_user` / `delete_old_history` | 领币 / 消耗券 / 删认证用户 / 删行情 |

**共性**：都是「旧版本函数」——新版加了令牌参数并把前端切过去了，但旧版没删也没锁，
而权限从来没人收过。

## ✅ 新增函数时的检查清单

1. **该不该给 `anon`？**
   - 前端要直接调的 → 给，但**必须带 `p_session` / `p_token` 并在函数内校验**
   - 只是内部用的（下划线开头、`create_user_session` 这类）→ **一律不给**
2. **内部函数权限写法**：
   ```sql
   REVOKE ALL ON FUNCTION public.你的函数(参数类型) FROM PUBLIC, anon, authenticated;
   ```
   注意 `SECURITY DEFINER` 的函数**以所有者身份运行**，内部互相调用不受这个 REVOKE 影响。
3. **改版老函数时，别只加新版本**：要么把旧签名 `DROP` 掉，要么把它的权限一并收回，
   否则旧版就是个后门。
4. **加完跑一次审计**（见下）。

## 🔍 定期审计查询（建议每次改完数据库都跑一遍）

### 1) 列出所有匿名可调用的函数，人工过一遍

```sql
SELECT p.proname AS 匿名可调用的函数,
       pg_get_function_identity_arguments(p.oid) AS 参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND has_function_privilege('anon', p.oid, 'EXECUTE')
 ORDER BY 1;
```

**判断标准**：没有 `p_session` / `p_token` 参数、名字又像管理或私有操作的，
就是漏网的。

### 2) 确认关键内部函数已锁（应全部 false）

```sql
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS 参数,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS 匿名还能调用
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
   AND (p.proname LIKE '\_%' OR p.proname IN ('create_user_session'))
 ORDER BY 1;
```

### 3) 检查有没有"同名但签名不同"的新旧版本并存

```sql
SELECT p.proname, count(*) AS 版本数,
       string_agg(pg_get_function_identity_arguments(p.oid), ' || ') AS 各版本参数
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f'
 GROUP BY p.proname HAVING count(*) > 1
 ORDER BY 1;
```

同名多版本 = 大概率有旧版后门，逐个确认。

## 📌 易错点：改函数前必须先核对表结构

重写已有函数时**不要凭印象写列名**。2026-09-12 踩过一次：
重写 `store_email_code` 时把 `ip_address` 写成了 `ip`，
结果发验证码直接报 `column "ip" does not exist` —— **登录和注册全部收不到验证码**。

```sql
-- 改任何函数前先核对列名
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = '要改的表名'
 ORDER BY ordinal_position;
```

## 📌 易错点：重写函数前，先把同名函数的**所有版本**找出来

2026-09-12 踩的坑：重写 `do_check_in` 时只看了 `checkin_tz_fix.sql` 里的版本，
没注意 `profile_enhance.sql` 里还有一个**更完整**的版本 —— 后者会写 `check_in_records`
（签到历史，热力图和补签天数计算都依赖它），前者漏了那句。

结果：我基于"漏掉的那句"重写，签到历史继续不增长，补签算出来的连续天数越来越短
（实际案例：连续签到 69 天的用户，补签一次变成 29 天）。

```sql
-- 改任何函数前先列出所有同名版本，对比函数体长度
SELECT pg_get_function_identity_arguments(p.oid) AS 参数,
       length(pg_get_functiondef(p.oid)) AS 函数体长度,
       pg_get_functiondef(p.oid) AS 定义
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = '要改的函数名';
```

**函数体最长的那个通常是最新的**（后续修复是累加的）。照着某个文件里的版本直接重写，
很容易把后面的修复覆盖掉。

## 📌 另一个易错点：NULL 比较短路

```sql
IF v_row.code_hash <> md5(coalesce(p_code,'')) THEN   -- ❌ 若 code_hash 是 NULL，结果是 NULL
    RETURN '验证码错误';                              --    不是 true → 跳过 → 直接放行
END IF;
```

SQL 里 `NULL <> 任何值` 的结果是 `NULL`，而 `IF` 只在 `true` 时进入分支。
**凡是拿字段和输入做比较，都要先判空**：

```sql
IF v_row.code_hash IS NULL OR v_row.code_hash <> md5(...) THEN   -- ✅
```

已知受影响的函数（2026-09-12 已修）：`_verify_email_code`、`update_username`、`update_password`。
（当时线上数据里没有空值，所以没被真正利用，但写法必须改掉。）

## 🧹 相关文件

| 文件 | 作用 |
|---|---|
| `URGENT_fix_session_forgery.sql` | 收回所有内部函数权限（含 create_user_session） |
| `URGENT2_lock_legacy_admin.sql` | 锁定 9 个无令牌的旧版管理函数 |
| `fix_code_null_check.sql` | 验证码校验的空值短路 |
| `fix_null_password_check.sql` | 旧密码校验的空值短路 |

---

## ⚠️ 第二个坑：权限改动，**不能在自己的地盘验**（2026-09-28）

在 Supabase SQL Editor 里跑完

```sql
REVOKE SELECT ON public.reports FROM anon, authenticated;
```

就地跑一句 `SELECT * FROM public.reports LIMIT 1;` —— **它照样吐出数据**，
看上去像"没生效"。其实**已经生效了**：

> **SQL Editor 是以 `postgres`（表所有者）身份执行的。**
> `REVOKE ... FROM anon` 撤的是**匿名角色**的权限，
> 而**超级用户 / 表所有者不受任何表权限限制**。

### 唯一正确的验证方式：用被限制的那个身份，从外面打

拿网页里写死的那把公开 key 直接请求 PostgREST：

```bash
curl -s "https://<项目>.supabase.co/rest/v1/reports?select=*&limit=1" \
  -H "apikey: sb_publishable_xxx" -H "Authorization: Bearer sb_publishable_xxx"
```

| 返回 | 结论 |
|---|---|
| `{"code":"42501","message":"permission denied for table reports"}` | ✅ 撤成功了 |
| 一堆举报数据 | ❌ 没撤掉 |

⚠️ 别在 URL 里加 `&_=时间戳` 之类的缓存破坏参数 —— PostgREST 会把它当成**过滤条件**，
报 `PGRST100 unexpected "1" expecting ...`，看起来像出了别的问题。

**顺带一条**：表权限撤了之后，`SECURITY DEFINER` 的函数**仍然读得到**
（它以函数所有者的身份运行）。所以「后台改用 RPC」之后再撤表的 SELECT，
后台不会受影响 —— 这正是 2026-09-28 那次修复敢撤权限的前提。

---

## ⚠️ 第三个坑：后台前端「直连查表」= 那张表就得对全网开放（2026-09-28 实际漏洞）

有人把 `Website backend.html` 下载下来、部署到自己的 `pages.dev`，
就看到了后台的举报列表和公司认证申请（只能看不能操作，写操作有 token 挡着）。

**根因**：后台是「纯网页 + 公开 anon key」，而它读举报列表用的是 PostgREST 嵌套查询：

```js
supabaseClient.from('reports').select(`comments!inner( ... profiles!inner(username) )`)
```

**匿名要能查，`reports` 表就必须对所有匿名用户开放。** 于是任何人拿网页里
那把公开 key 都能读走举报内容（谁举报了谁 `reporter_user_id`、举报原因、被举报的评论/公司/作品）。
实测确认当时**全列可读**。

### 规矩

> 凡是**不该让外人看**的数据，一律走**带鉴权的 RPC**；
> **永远不要**在网页里直接 `from('表名').select()`。
> 只有公开数据（评论、作品、公司列表、公告）才允许直连。

修复时新增的三个 RPC（`admin_list_reports` / `admin_list_pending_companies` / `check_my_report`）
见 `sql/fix_admin_data_leak_20260928.sql`；撤权限见同目录的
`fix_admin_data_leak_第二步_撤权限.sql`。

**另一条经验**：改这种「前端 + 数据库」联动的东西要**分两步上线** ——
先建 RPC（纯新增，不影响现有功能）→ 前端上线 → 确认没问题 → 最后才撤表的权限。
顺序反了，后台会当场读不到数据。
