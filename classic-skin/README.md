# classic-skin/ —— 方案 C：新 DOM + 旧配色

**思路**：保留现在的页面结构和业务 JS（功能零风险），只把外观调成
8/23 之前的旧版观感。

**做法**：
1. `ui-nav.js` 的 `getVer()` 在 classic 模式返回 `'old'` → 走空的 `initOldUI()`，
   不再替换导航、不再注入光斑特效
2. `ui-new.css` 在 classic 模式 `disabled`
3. `css/dark.css` 从 `ui-new.css` 抽出 44 条深色规则，classic 模式启用
4. `css/classic.css` 只留一条（隐藏后加的导航第二排）

**适用页面**：结构没变的 5 个（index / achievements / lottery_records /
profile / register_company）—— 这几个和 legacy 完全一致。

**⚠️ 不适用**：结构变过的 11 个页面（APP / Virtual stock / about / changelog /
chat / comments / comments-beta / messages / product / product_share / videos）。
它们的 DOM 换成了 top-nav + quick-nav + hero，样式全在 ui-new.css 里，
禁用它之后结构会裸奔 —— **实测确认做不到"旧观感"**。

**怎么看**：`classic-skin/index.html?ui=classic`
（`?ui=` 是页面本来就支持的参数，用来临时覆盖 localStorage）