# stock-Beta.html 对接 AMM 新模型 · 改动说明

改动人：AI 助手　　时间：2026-10-04　　目标文件：`Beta/stock-Beta.html`（顺带改了 `Beta/register_company-Beta.html`）

原文件备份：`Beta/stock-Beta.html.ammbak`（改前 3580 行 / 186KB）

---

## 零、先说结论

页面已完全切到 **AMM 做市池模型**，并且：

- 打开正常、**没有任何 JS 报错**（用 Edge headless + CDP 实测，`window.onerror` / `unhandledrejection` 全程为 0）
- 92 家公司全部显示 `股价 1.0000`、资金池按「亿 / 万」缩写
- 维护横幅（`NB-STOCK-MAINTENANCE-BANNER`）内容一字未改
- K 线图（`get_company_kline`）代码一行未动
- 导航栏 / 用户信息 / 余额显示未动
- 沿用页面原有的 `supabaseClient`（第 1168 行 `supabase.createClient(...)`），没有新引入 client

---

## 一、五刀各自做到哪了

| # | 内容 | 状态 |
|---|---|---|
| 1 | 主列表：市值 → 股价 + 资金池，数据源换 `get_market_list` | ✅ 完成 |
| 2 | 交易面板：`preview_buy` / `preview_sell` 实时预览 + 滑点告警 | ✅ 完成 |
| 3 | 我的持仓：持股张数 / 成本均价 / 现价 / 浮动盈亏，数据源 `get_my_holdings` | ✅ 完成 |
| 4 | 清理失效入口 + 破产改清算 + 新增分红 + 自动支持改「自动抄底」 | ✅ 完成 |
| 5 | 注册公司加「出资额」输入框 → 走 `register_company_funded` | ✅ 完成 |

---

## 二、第一刀：主列表

**表头**（原来 5 列 → 现在 7 列）

```
虚拟股票名称 | 股价 | 资金池 | 归属用户 | 我的持股 | 涨跌幅 | 操作
```

- 数据源：新增 `fetchMarketList()` 调 `get_market_list(p_user_id)`，失败自动退回直接读
  `user_companies(pool_cash/pool_shares/total_shares)`，保证数据库没跑 `amm_part4` 时页面也不会空白
- `fetchAllCompanies()` 现在统一返回 AMM 口径，字段名做了内部映射（`company_id` → 内部 `id` 等）
- 股价：新增 `formatPrice()`，固定 4 位小数 → `1.0000`
- 资金池：新增 `formatLarge()`，`1.49 亿` / `6457.45 万` / `1,234.57`
- **涨跌幅改成股价涨跌**：新增 `prevPrices`（`company_id → 上一轮股价`）和 `lastStockChanges`，
  每轮刷新对比一次；首次加载没有上一轮数据，显示 `0%`
- 「我的持股」列显示 `张数 / 当前价值`（`get_market_list` 的 `my_shares` / `my_value`）
- 空数据占位 `colspan` 从 5 改成 7

## 三、第二刀：交易面板

弹窗里 `#tradeModal / #tradeBuyBtn / #tradeSellBtn / #tradeShares / #tradeAmountPreview /
#tradeBalance / #tradePrice` 这些 id 全部保留（维护脚本的锁定列表还认它们）。

**买入**：输入仍是「投入多少 NB币」，输入后 **280ms 防抖**调 `preview_buy`，面板显示

```
当前股价 1.0000 NB币/张
预计成交均价 1.0500 NB币/张
滑点 +5.00%              ← >5% 标红并附「本次交易会明显推动价格」
预计得到 952.38 张
手续费 50 NB币 / 实际支付 1,050 NB币
成交后股价 1.1025 NB币/张
```

**卖出**：输入语义改成「卖掉多少张股份」，调 `preview_sell` 显示到账 / 均价 / 滑点 / 成交后价格。
提示行额外写了一句「AMM 下能套现的上限就是池子里的现金：现在池子里只有 X」。

其他细节：

- 请求带**序号 `tradePreviewSeq`**，打字快时旧结果不会覆盖新结果
- `executeTrade('sell')` 的 `p_amount` 现在传的是**张数**（原来是金额）——这是最容易踩的语义坑，
  已按新后端 `LEAST(p_amount, 持仓份额)` 的行为改了本地校验和提示
- 成交后的「这笔卖出 / 全部持仓」汇总改成 `成本均价 / 现价 / 净收益` 口径
- **休市不再直接挡在门外**（后端 `buy_stock` 本来就会按 8:00-20:00 拒绝并给提示），
  这样休市时玩家也能打开看 AMM 预览
- `buy_stock` / `sell_stock` 保留原有的 `p_session` → 无 `p_session` 的自动回退逻辑

## 四、第三刀：我的持仓

数据源 `get_my_holdings`，表头：

```
公司 | 持股张数 | 成本均价 | 现价 | 当前价值 | 浮动盈亏 | 操作
```

- 「占公司比例」在 AMM 下不再等于 `持仓价值 ÷ 市值`（分子含池子股份，口径不对），
  换成了「占我持仓 X%」，避免误导
- 创始人自己的公司带 👑 标记（用 `is_founder`）
- 底部汇总：`总成本 X · 当前价值 Y · 浮动盈亏 ▲/▼ Z (+n%)`

## 五、第四刀：入口清理 / 清算 / 分红 / 自动抄底

**删掉的**（真的取消了，函数体也删了，只剩注释说明）：

- 💖 支持虚拟公司（注资）→ `supportCompany`、`showSupportDialog` 整体删除
- 💎 提升市值 → `upgradeCompanyValue` 删除
- 💰 提取公司资金 → `withdrawCompanyValue` 删除（改用分红）
- 自动刷新里的 `random_fluctuate_market_values` 调用也删了（数据库里它已改成空函数）

**破产 → 清算**：按钮文案改成「🧹 清算公司」，确认框明确写

> ⚠️ 资金池里的钱会按持股比例分给所有股东，不是创始人独吞。
> · 资金池剩余：X NB币　· 你持有 N 张，占 n%　· 预计你能分到约 Y NB币

**新增分红**：`id="dividendBtn"`（💸 分红），只有 `myCompany` 存在时才渲染（即只有创始人看得到），
走 `pay_dividend(p_user_id, p_company_id, p_amount)`，弹窗里显示资金池、总股本、你的持股占比，
以及「池子钱少了股价会自动下跌（等于除息）」的提醒。

**自动支持 → 自动抄底**（按你后来的更正重做）：

- 入口按钮恢复，文案 `🎯 自动抄底`，绑定 `showAutoBuyDialog`
- 列表：`get_my_auto_buy_rules(p_user_id)` → 每行「公司名 / 目标价 / 当前价 / 每次买入 / 每日已用 / 启用开关」，
  当前价 ≤ 目标价时标红「✅ 已低于目标价（可触发）」
- 新增/编辑：`set_auto_buy_rule(p_user_id, p_company_id, p_session, p_price_target, p_amount, p_daily_limit)`
  （`p_daily_limit` 留空就不传，交给数据库默认 50000）
- 开关：`toggle_auto_buy_rule(p_user_id, p_session, p_rule_id, p_enabled)`
- **下拉里排除了自己的公司**
- 本地校验：目标价 > 0、金额 10~100000、每日上限 ≥ 每次金额（都实测过会弹提示）
- 旧文案/旧函数 `setAutoSupportRule`、`checkAutoSupportRules` 已删除，不再引用 `set_support_rule` / `delete_support_rule`

**顶部新增说明页入口**（后加的需求）：

- 位置：`</header>` 之后、`.home-card` 之前，居中胶囊按钮，文案 `📖 股票改版怎么玩 →`，
  `href="stock-Beta-help.html"`
- 颜色全部走主题变量：`var(--brand)` / `var(--card-border)` / `var(--card-bg)` / `var(--brand-deep)`，
  每个都带 fallback，7 套主题下都不会看不见

**维护横幅**：`#nbStockMaintBar` 的结构和 CSS 一字未改，只往 `lockButtons()` 的选择器数组里
补了 `#dividendBtn`、`#registerCompanyBtn`（不然维护模式下这两个新按钮锁不住）。

## 六、第五刀：注册出资额（已接通 `register_company_funded`）

### `Beta/register_company-Beta.html`

- 「免费/付费注册」两档 → 单个「出资额（建公司资金池）」输入框，**默认 20000，min 20000**
- 快捷按钮：最低 2万 / +3万 / +8万 / +18万
- 说明文字：「这笔钱会成为公司的**初始资金池**，你获得**等量股份**（价格 1.00）。
  你的 NB币余额:X；本次将扣除:Y。公司资金池:Y · 你拿到:Y 张 · 总股本:2Y 张（剩下的股份留在池子里供别人买入）」
  —— 余额实时显示，低于 20000 / 超过余额都会红字提示
- 提交调用：

```js
supabaseClient.rpc('register_company_funded', {
    p_user_id:      currentUser.id,
    p_session:      localStorage.getItem('nb_session'),   // 沿用站内取会话的方式
    p_company_name: name,
    p_need_verify:  needVerify,
    p_fund:         capital
})
```

- **后端 `message` 直接展示**（余额不足 / 低于 20000 / 超 1 亿 / 重名 / 违禁词 / 登录过期 都由后端覆盖），
  前端不再自己拼错误文案，也不再用 `d.shares` 兜底猜数字
- 删掉了原来注册后调 `upgrade_company_value` 的「提升市值」流程（该 RPC 已停用）
- 顺手把页面里过时的「初始市值 20000」文案改成「自己出资建公司资金池（最低 20000 NB币），股价 1.00」
  （hero 副标题、右侧信息行、meta description 三处）

### `Beta/stock-Beta.html`

- `createCompany(companyName, fund)` 同步改成 `register_company_funded` + `p_fund` + `p_session`
  （这个函数在本页没有调用点，页面上的注册入口是跳转到 `register_company-Beta.html`，
  但留着旧签名迟早会被误用，所以一起改了）

### 参数名验证

用 anon key 实测：

- 带 `p_fund` → 返回 `{success:false, message:"登录已过期，请重新登录"}`（函数命中，走进鉴权分支）
- 不带 `p_fund` → **404 function not found**（PostgREST 按参数名匹配重载）
- 带 `p_capital` → **404**

→ 确认 `p_fund` 就是唯一正确的参数名。

**另外**：仓库里还有 6 个非 Beta 的注册入口仍在用旧的 `register_company`
（`register_company.html` × 4 套皮肤 + `Virtual stock.html` × 4）。
按你的要求「页面」范围是 Beta，我没动它们；如果这些站点还在线，需要一起改（改法完全相同）。

## 七、顺手修掉的两个既有 bug

1. **持仓拉不到数据**：线上 `get_my_holdings` 有 `(uuid)` 和 `(uuid, text)` 两个重载，
   只传 `p_user_id` 会报 `PGRST203 无法在两个候选函数间选择`。改成
   `{ p_user_id, p_session }`，并保留退回不带 `p_session` 的分支。
2. **总市值变化基准是错的**：原来从 `stock_latest` 取基准，而那张表最后一条是
   **2026-09-10 迁移前**的旧数据（`total_value = 442,234,692`），拿它对比会显示
   「总市值 ▲293%」这种荒唐数字。改成用 `stock_history_full` 的最新一条
   （服务端 `publish_stock_snapshot` 每次都按 AMM 口径重算），现在显示 ▼0.03% 是真实值。
   `loadPreviousSnapshot()` 因此变成空实现（保留调用点不动）。

## 八、自测方式与结果

用 Edge headless 起真实页面 + CDP 注入会话，逐项验证：

- **报错**：`window.onerror` + `unhandledrejection` 全程 0 条
- **script 标签**：21 个 `<script>` / 21 个 `</script>`，配对；15 段内联脚本全部 `node --check` 通过
- **主列表**：表头 7 列正确；92 行全部 `1.0000`；资金池 `1.49 亿 / 6457.45 万`；
  搜索「微软」命中 4 家；`展开全部` 92 行
- **预览 RPC**：`preview_buy(208, 1000)` → `{shares:952.381, avg_price:1.05, slippage_pct:5}`；
  `preview_sell(208, 100)` → `slippage_pct:0.5`
- **交易弹窗**：买入输入 200000 → 面板出现红字「⚠️ 滑点 1000.00% —— 本次交易会明显推动价格」；
  卖出输入 3000 张 → 按**张**算，均价 0.8696，滑点 13.04%，红字告警出现
- **持仓表**：注入真实形状数据 → 7 列表头 + `3000.00 / 0.9000 / 1.0000 / ▲ 300 (+11.11%)`；
  行内买卖按钮点击能打开交易弹窗
- **分红**：点 💸 分红 → 弹窗显示「资金池：2.00 万 NB币 · 总股本：4.00 万 张（你持有 20000.00 张，占 49.97%）」
- **清算**：点 🧹 清算公司 → 确认框显示「按持股比例分给所有股东，不是创始人独吞」
- **自动抄底**：按钮存在；对话框打开、规则列表能渲染真实规则（该账号有 1 条）、
  下拉 91 个选项、三条本地校验都正确弹提示；提交和 toggle 在假令牌下返回
  「鉴权失败，请重新登录」（预期，因为我注入的是假 token）
- **注册出资额**：`register_company-Beta.html` 注入会话后实测 —— 出资额输入框默认 20000 / min 20000、
  四个快捷按钮正确（+3万 → 50000）、低于 20000 会红字提示并本地拦下、
  完整提交后后端返回「登录已过期，请重新登录」（假 token，预期），按钮状态正确复位
- **刷新**：`autoRefreshData()` 与 `manualRefresh()` 各跑一轮，无报错

## 九、注意事项 / 已知情况

- `body.classList` 上加的 `nb-maint` 维护态由数据库 `stock_settings.maintenance` 控制；
  这个开关**没动**。数据库侧关掉维护后横幅自动消失，不用改页面
- 图表仍用「账面市值 = 股价 × 总股本」作等价量（各家股价都是 1.0000，所以它等于
  `pool_cash + 股东持股市值`，语义上还是「这家公司值多少钱」），只是把纵轴和 tooltip 的
  大数字也换成了「亿 / 万」缩写；直方图分箱改成等比递增，否则 90 家会挤成一根柱子
- K 线图的数据源 `get_company_kline` 返回的是历史采样点，**迁移前后口径不同**，
  所以图上会看到一段「台阶」。按你的要求那块代码没动，如果需要修数据另说
- 页面本来就有一个多余的 `</div>`（改前改后都是 div 开 107 / 闭 108），是原文件自带的，没动它
