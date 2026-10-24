# 根目录「新潮 / 经典」股票页 + 注册页 · 对接 AMM 资金池模型

改动人：AI 助手　　时间：2026-10-04
目标文件：`Virtual stock.html`（主股票页）、`register_company.html`（注册公司页）
改前备份：`Virtual stock.html.ammbak`（114,934 字节）、`register_company.html.ammbak`（14,214 字节）

> 参考实现：`Beta/stock-Beta.html`、`Beta/register_company-Beta.html`（已改完的官网版）
> **`Beta/` 下的任何文件都没有动**；`preview/` `legacy/` `classic-skin/` `classic-legacy/` 也没动
> （已核实：这四个目录里 4×3 个页面仍用旧接口，但**没有任何活页面链接到它们**，是死页）。

---

## 零、结论

| 项 | 结果 |
|---|---|
| 页面能打开、**零 JS 报错** | ✅ `window.onerror` + `unhandledrejection` 全程 0 条；`<script>` 标签 13/13、11/11 配对；14 段内联脚本全部 `node --check` 通过 |
| 新潮皮肤渲染 | ✅ 截图确认（默认 `nb_ui_mode` 新潮） |
| 经典皮肤渲染 | ✅ 截图确认（`nb_classic=1`），颜色全走 CSS 变量，没有写死颜色 |
| 主列表 | ✅ 92 家真实数据，股价全 `1.0000`，资金池 `1.49 亿 / 6457.45 万 / 2.00 万` |
| 交易预览 / 分红 / 自动抄底 / 注册出资 | ✅ 用假数据层实测过（详见第八节） |
| 导航栏 / 用户信息 / 余额显示 | ✅ 与备份**逐行完全一致**（用 `Compare-Object` 比对过） |
| K 线图代码（`get_company_kline` + echarts 部分） | ✅ 只改了标题文案里的「市值」→「账面市值」，逻辑一行未动 |

---

## 一、第一刀：主列表

**表头 5 列 → 7 列**

```
虚拟股票名称 | 股价 | 资金池 | 归属用户 | 我的持股 | 股价涨跌 | 操作
```

- 数据源换成 `get_market_list(p_user_id)`（新增 `fetchMarketList()`）。
  取不到时**自动退回直接读 `user_companies`**（`pool_cash`/`pool_shares`/`total_shares`），
  这样数据库没跑 `amm_part4` 时页面也不会空白 —— 这条兜底路径实测有效。
- `fetchAllCompanies()` 内部字段统一映射成 `company_id / price / pool_cash / pool_shares /
  total_shares / market_cap / my_shares / my_value / verified / founder`。
- 新增 `formatPrice()`：固定 4 位小数 → `1.0000`。
- 新增 `formatLarge()`：`1.49 亿` / `6457.45 万` / `1,234.57`（表格里几十亿不缩写会撑爆列）。
- 新增 `safeDiv()`：池子股份为 0 时不让页面出现 `NaN`。
- **涨跌幅改成股价涨跌**：新增 `prevPrices`（`company_id → 上一轮股价`）与 `lastStockChanges`，
  每轮刷新对比一次；首轮没有基准就显示 `—`。
- 新增「我的持股」列：`张数 / 当前价值`。
- 空数据占位 `colspan` 从 5 改成 7。
- 图表口径：用 `market_cap`（账面市值 = 股价 × 总股本）当等价量，图表代码不用改；
  顺手把直方图分箱改成**等比递增**（否则 92 家会挤成一根柱子），并把大数字文案改成「亿/万」缩写。

## 二、第二刀：交易面板

弹窗里 `#tradeModal / #tradeBuyBtn / #tradeSellBtn / #tradeShares / #tradeAmountPreview /
#tradeBalance / #tradePrice / #tradeCapHint` 这些 id 全部保留。

**买入**：输入仍是「投入多少 NB币」，**280ms 防抖**后调 `preview_buy`，面板显示

```
投入 5,000 NB币
当前股价      1.0000 NB币/张
预计成交均价   1.2500 NB币/张
滑点          +25.00%   ← >5% 标红并附「本次交易会明显推动价格」
预计得到      4000.00 张
手续费        250 NB币 / 实际支付 5,250 NB币
成交后股价     1.5625 NB币/张
```

**卖出**：输入语义改成「**卖多少张股份**」（原来是金额），调 `preview_sell`，
显示到账 / 均价 / 滑点 / 成交后价格，并提示「AMM 下能套现的上限就是池子里的现金」。

其他细节：

- 请求带序号 `tradePreviewSeq`，打字快时旧结果不会覆盖新结果
- `executeTrade('sell')` 的 `p_amount` 现在传的是**张数**（原来是金额）—— 这是最容易踩的语义坑
- 输入期间先用本地估算给即时反馈（「预计能得到约 X 张…正在要精确预览」），不会看着像卡住
- 新增**快捷填充按钮**：买入给 `1,000 / 5,000 / 10,000 / 全部余额`，卖出给
  `25% / 50% / 75% / 全部`，点一下直接出预览
- 切换买入/卖出时**先清空预览面板**，否则会残留上一次模式的数字（这是实测中发现的真 bug，已修）
- 成交后的「这笔卖出 / 全部持仓」汇总改成 `成本均价 / 现价 / 净收益` 口径
- `buy_stock` / `sell_stock` 保留 `p_session` → 无 `p_session` 的自动回退

## 三、第三刀：我的持仓

数据源 `get_my_holdings`，表头：

```
公司 | 持股张数 | 成本均价 | 现价 | 当前价值 | 浮动盈亏 | 操作
```

- ⚠️ **必须传两个参数** `{ p_user_id, p_session }`：线上有两个重载 `(uuid)` 和 `(uuid, text)`，
  只传一个会报 `PGRST203 无法在两个候选函数间选择`。新增 `fetchMyHoldingsRaw()` 封装，
  并保留退回不带 `p_session` 的分支。
- 「占公司比例」在 AMM 下口径不对（分子含池子股份），换成「占我持仓 X%」
- 创始人自己的公司带 👑 标记（用 `is_founder`）
- 底部汇总：`总成本 X · 当前价值 Y · 浮动盈亏 ▲/▼ Z (+n%)`

## 四、第四刀：清理 / 新增

**删掉的（函数体也删了，只留注释说明，避免以后被误加回来）：**

- 💖 支持虚拟公司（注资）→ `supportCompany`、`showSupportDialog` 整体删除
- 自动支持规则 → `setAutoSupportRule`、`checkAutoSupportRules` 删除，
  不再引用 `set_support_rule` / `delete_support_rule` / `support_rules` 表
- 自动刷新里的 `random_fluctuate_market_values` 调用删除（数据库里它已改成空函数）
- 遗留的 `autoSupportTimer` 变量删除

**破产 → 清算**：按钮改成「🧹 清算公司」，确认框明确写

> ⚠️ 资金池里的钱会按持股比例分给所有股东，不是创始人独吞。
> · 资金池剩余：X NB币　· 你持有 N 张，占 n%　· 预计你能分到约 Y NB币

**新增分红**：`#dividendBtn`（💸 分红），只有 `myCompany` 存在时才渲染（即只有创始人看得到），
走 `pay_dividend(p_user_id, p_company_id, p_amount)`。
弹窗里显示资金池、总股本、你的持股占比，以及「池子里的钱少了股价会自动下跌（等于除息）」；
金额超过池子现金会本地拦下。为此新增了一个 `showPrompt()`（带输入框的弹窗）。

**自动支持 → 自动抄底**：

- 入口按钮文案改 `🎯 自动抄底`，绑定新增的 `showAutoBuyDialog`
- 列表：`get_my_auto_buy_rules(p_user_id)` → 每行「公司名 / 目标价 / 当前价 / 每次买入 /
  每日上限 / 今日已用 / 启用开关」，当前价 ≤ 目标价时标红「✅ 已低于目标价（可触发）」
- 新增/编辑：`set_auto_buy_rule(p_user_id, p_company_id, p_session, p_price_target, p_amount, p_daily_limit)`
  （`p_daily_limit` 留空就不传，交给数据库默认 50000）
- 启停：`toggle_auto_buy_rule(p_user_id, p_session, p_rule_id, p_enabled)`
- **下拉里排除了自己的公司**（实测只有「别人家的公司 / 大池子公司」，自己的「测试科技」不在）
- 本地校验：目标价 > 0、金额 10~100000、每日上限 ≥ 每次金额

**我的公司区块**：`市值` → `股价 / 资金池 / 总股本` 三个数字。

## 五、第五刀：注册页出资额

`register_company.html`：

- 「免费/付费」两档 → 单个「**出资额（建公司资金池）**」输入框，**默认 20000，min 20000**
- 四个快捷按钮：**最低 2万 / 5万 / 10万 / 20万**
- 说明文字：「这笔钱会作为公司的**初始资金池**。你会获得**等量股份**（股价 1.00），
  另一半留在池子里供别人购买。」下面实时显示余额 / 将扣除 / 你会拿到多少张 / 总股本
- 提交调用：

```js
supabaseClient.rpc('register_company_funded', {
    p_user_id:      currentUser.id,
    p_session:      getSessionToken(),   // localStorage.getItem('nb_session')
    p_company_name: name,
    p_need_verify:  needVerify,
    p_fund:         capital
})
```

- **会话 token 的取法确认过**：根目录这套和 Beta 完全一样，都是 `localStorage.getItem('nb_session')`。
  注意站内那段「会话令牌自动注入」补丁只覆盖一个固定 RPC 名单，`register_company_funded`
  **不在名单里**，所以必须显式传 `p_session`（页面里已显式传）。
- **后端 `message` 直接展示**（余额不足 / 低于 20000 / 超 1 亿 / 重名 / 违禁词 / 已注册过 /
  登录过期…都由后端覆盖），前端不再自己拼错误文案，也不再自己猜股份数
- 本地只挡最基本的四种：名称非空、≤20 字、出资额 ≥ 20000、出资额 ≤ 余额
- 提交中按钮禁用 + 文案「提交中…」，出错时复位

`Virtual stock.html` 里的 `createCompany()` 也顺手改成新接口 + `p_fund`
（这个函数在本页没有调用点，页面上的注册入口是跳转到 `register_company.html`，
但留着旧签名迟早会被误用）。

---

## 六、样式：为什么没有照抄 Beta

两套 UI 的 CSS 体系不同，所以**只搬了逻辑和文案，样式全部沿用根目录自己的体系**：

| | Beta | 根目录（本次） |
|---|---|---|
| CSS | `css/themes.css`（`--bg` `--card` `--ink` `--brand`） | `css/style.css` + `css/ui-new.css` + `css/classic.css` |
| 变量 | `var(--brand)` 等 | `var(--card-bg)` `var(--card-border)` `var(--count-bg)` `var(--count-text)` `var(--nav-btn-bg)` `var(--nav-btn-hover-bg)` `var(--status-border)` `var(--text-color)` `var(--bg-color)` |
| 类名 | `.rc-*` | `.register-card` `.form-group` `.company-btn` `.custom-modal` `.data-table` |

新增的 CSS 只有注册页那一小块（`.quick-amounts` / `.capital-hint`），
颜色**全部走上面这些变量**，所以新潮 / 经典两套皮肤都正常（已分别截图确认）。
红涨绿跌这种语义色（`#f44336` / `#4caf50`）是原页面本来就写死的，保持一致没有动。

---

## 七、改动统计

```
Virtual stock.html      114,934 → 150,069 字节   （2191 → 2754 行）
register_company.html    14,214 →  21,621 字节   （ 316 →  453 行）
```

---

## 八、自测方式与结果

用 **Edge headless + CDP**（等价于 Beta 那次的验法）：

1. `Page.addScriptToEvaluateOnNewDocument` 在**导航之前**装好
   `window.onerror` / `unhandledrejection` 钩子，以及一个**假数据层**
   （劫持 `window.fetch`，把 Supabase 的 REST/RPC 请求换成固定返回，
   预览接口按真实 AMM 公式算：买入 `shares−k/(cash+amount)`、卖出 `k/(shares+n)`）。
2. 注入 localStorage 会话 → 让页面走「已登录」分支。
3. 在页面里跑断言，把 DOM 文本打回来。

**踩到的坑（第一条对线上也有意义）：**

- ⚠️ **`127.0.0.1:10080` 被 Chromium 列为不安全端口**（`net::ERR_UNSAFE_PORT`），
  浏览器直接拒绝加载，返回 `chrome-error://chromewebdata/`。
  任务里给的 `python -m http.server 10080` 自测命令**在浏览器里跑不通**
  （`python` 自己起得来，`Invoke-WebRequest` 也取得到，但 Edge 打不开）。
  换成 `18080` 才正常。**这条自测命令建议改成 18080。**

  ```powershell
  Start-Process -FilePath "python" -ArgumentList "-m","http.server","18080","--bind","127.0.0.1","--directory","D:\工作区\nb-channel-main" -PassThru -WindowStyle Hidden
  & "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --no-sandbox --disable-extensions --hide-scrollbars --user-data-dir="$env:TEMP\_mk1" --no-first-run --virtual-time-budget=14000 --window-size=1440,1600 --screenshot="$env:TEMP\mk.png" "http://127.0.0.1:18080/Virtual%20stock.html"
  ```
- ⚠️ **`register_company.html` 在 `<body>` 后立刻检查 `localStorage.nb_user`，没有就秒跳登录页**，
  所以「先导航、再注入会话、再 reload」的老套子来不及（4 秒后已经在 `Beta/login-Beta.html` 了）。
  改成导航前装 `addScriptToEvaluateOnNewDocument` 才验到。
  这**不是本次改动引入的**，是页面原本的行为。
- ⚠️ 空 `<input type=number>` 上直接 `.value = 'x'` 再 `dispatchEvent('input')`，
  在 headless 里会被清空 —— 是**测试脚本自己的坑**，不是页面 bug（改成先 `dispatchEvent` 再赋值就对了）。
  一开始误判成「卖出预览不工作」，查清了才继续。

**实测到的结果（摘要）：**

| 项 | 证据 |
|---|---|
| 零 JS 报错 | `window.__ammErrors` 0 条；CDP `Runtime.exceptionThrown` 0 条；唯一的 `log.error` 是 `favicon.ico 404`（原页面就有） |
| 表头 7 列 | `虚拟股票名称 / 股价 / 资金池 / 归属用户 / 我的持股 / 股价涨跌 / 操作` |
| 真实数据 92 家 | 股价全 `1.0000`；资金池 `1.49 亿 / 1.48 亿 / 6457.45 万 / 446.59 万 / 1.00 万` |
| 格式化函数 | `formatPrice(1)`= `1.0000`；`formatLarge(149000000)`= `1.49 亿`；`formatLarge(64574500)`= `6457.45 万`；`formatLarge(1234.567)`= `1,234.57` |
| 持仓表 | 表头 7 列 + `20000.00 / 1.0000 / 1.0000 / 2.00 万 / ▲ 0.00 (+0.00%)` + 👑 |
| 买入预览 | 投入 5000 → 均价 `1.2500`、滑点 `+25.00%`、得到 `4000.00 张`、成交后 `1.5625` |
| 滑点告警 | 小池子砸 10 万 → `⚠️ 滑点 500.00% —— 本次交易会明显推动价格` 红字出现 |
| 防抖 | 连敲 100→1000→5000，最终只显示「投入 5,000」，旧结果没覆盖新结果 |
| 卖出语义 | 输入 20000 **张** → 均价 `0.5000`、滑点 `+50.00%`、到账 `1.00 万`，按张算 |
| 自动抄底 | 下拉 2 个选项（自己的公司被排除）；两条本地校验都正确弹提示；规则行渲染真实数据 |
| 分红 | 弹窗「资金池 2.00 万 / 总股本 4.00 万 张（你持有 20000.00 张，占 50.00%）」；超池子金额被拦 |
| 清算 | 确认框「会按持股比例分给所有股东，不是创始人独吞」+ 预计能分到多少 |
| 注册出资额 | 默认 20000 / min 20000；+10万 → 100000；低于 20000、超过余额都被红字拦下 |
| 注册 RPC 入参 | 实测发出 `register_company_funded{p_user_id, p_session:'stub-token', p_company_name, p_need_verify, p_fund:20000}` —— 参数名全部命中 |
| 通用部分未动 | 导航栏 / 用户信息 / hero / 页脚 与 `.ammbak` 用 `Compare-Object` 逐行比对：**完全一致** |

---

## 九、注意事项 / 已知情况

1. **`Beta/` 一个文件都没动**（本次只写 `Virtual stock.html` 和 `register_company.html`）。
2. `preview/` `legacy/` `classic-skin/` `classic-legacy/` 四个目录没动。
   已核实它们里面各 3 个页面（`Virtual stock.html` / `register_company.html` / `product_share.html`）
   仍在用旧接口，但**没有任何活页面链接到这四个目录**。如果以后这些页面要上线，得照同样的改法再来一遍。
3. **文件 BOM 去掉了**：原来两个文件带 UTF-8 BOM，现在没有。
   两个文件都有 `<meta charset="UTF-8">`，实测中文渲染正常；
   站内 `index.html` 本来也没有 BOM，所以这是安全的。
   如果在意，可以用 `[System.IO.File]::WriteAllText($f, $c, (New-Object System.Text.UTF8Encoding($true)))` 加回去。
4. K 线图的数据源 `get_company_kline` 返回的是历史采样点，**迁移前后口径不同**，
   所以图上会看到一段「台阶」。按要求这块代码没动。
   另外 K 线弹窗里的文案统一成了「账面市值走势」（因为现在画的是「股价 × 总股本」这个等价量，
   不是旧版的 `market_value` 了）。
5. 休市（20:00–次日 8:00）时交易入口仍然按原样显示「😴 休市」，交易弹窗也会先拦一道
   —— 这一条**保持了根目录原来的行为**，没有学 Beta 那样放开（Beta 是放开让后端拒）。
   如果你希望休市也能打开弹窗看 AMM 预览，改 `showTradeDialog` 开头那两行就行。
6. 图表纵轴 / tooltip 已经换成「亿 / 万」缩写，但 `formatLarge` 只到「亿」——
   如果以后单家公司超过万亿，会显示成很大的「亿」数字（站内现有数据远没到）。
7. 唯一没实测到的路径：**真的提交一笔买入/卖出/分红/清算到线上数据库**。
   数据库现在开着维护模式，且我只有 anon key、没有真实会话令牌，
   所以这些写操作只验到了「参数正确 + 失败分支正常展示 + 按钮状态复位」。
   读接口（`get_market_list` / `get_company_kline` / `get_my_balance`）是**真打到线上**验的。
