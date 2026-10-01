# classic-test/ —— 经典模式改造原型

**这是原型，不影响主站。** 投票结果出来之前不动正式页面。

## 目标
让「经典模式」真正回到 2026-08-23「高级感升级」之前的观感
（对照物：`legacy/index.html`）。

## 原来的问题
`classic.css` 是"打补丁"式的 —— 加载 `style.css` + `ui-new.css`(31KB)
+ `classic.css`(7.7KB 的 !important 覆盖)。用 7.7KB 去盖 31KB，盖不干净
就成了半新半旧，比纯新版还难看。

## 这次的做法：不加载，而不是覆盖
1. `js/ui-nav.js` 里的 `getVer()` 原来写死 `return 'new'`，
   导致经典模式也照跑新版逻辑（替换导航、注入光斑特效）。
   改成按 `nb_ui_mode` 返回：classic/beta → `'old'`，
   于是它走空的 `initOldUI()`，什么也不注入。
2. `index.html` 给静态的 `ui-new.css` 加了 `id="uiNewCss"`，
   紧跟其后同步执行一段脚本，classic/beta 模式下直接 `disabled = true`。
   写在 `<head>` 里、渲染前执行，所以不会闪。
3. 页面和业务 JS **一行没改**，功能不受影响。

## 怎么看
- 默认（新潮）：https://github.nb-channel.top/classic-test/index.html
- 经典模式：同上加 `?ui=classic`
- 官网模式：同上加 `?ui=beta`

`?ui=` 参数是页面本来就支持的（守卫脚本里有），用来临时覆盖 localStorage。