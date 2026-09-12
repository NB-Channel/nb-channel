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
