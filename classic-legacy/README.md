# classic-legacy/ —— 方案 A+B：原封不动的旧版

**思路**：整站换成 2026-08-23「高级感升级」之前的版本 —— 旧 HTML + 旧 JS + 旧 CSS。
**视觉 100% 还原**，代价是功能待验证。

**来源**：`git archive d5afd4f^`，提取 `*.html` / `css` / `js` / `data`。

**这里只有 1 个 CSS（css/style.css）和 2 个 JS（common.js / videos.js）** ——
没有 ui-nav.js(78KB)、没有 ui-new.css / premium.css / beta.css。

**几个补充说明**：
- `admin-*.html`（旧后台管理页）**提取时就删掉了**，绝不能跟着部署公开
- `bank` / `shop` / `titles` / `backpack` / `tools` 这 5 个页面 legacy 时代还不存在，
  用的是现在的 HTML（它们没有"旧版"可参照）
- `preview/` 和 `archive/` 也去掉了

**要验证的功能**（旧 JS 对现在的后端还能不能用）：
  登录注册 · 评论区发帖 · 股票买卖 · 发消息 / 好友 · 个人中心 · 上传

**怎么看**：`classic-legacy/index.html`