# NB频道 · 安卓客户端(APK)

官网的安卓客户端外壳 —— 用 [Capacitor](https://capacitorjs.com/) 把线上网站包成一个可安装的 APP。

## 核心设计:两层结构

```
┌─────────────────────────────────────────┐
│  APK 外壳(约 5MB) ← 装在用户手机里       │
│  · 图标 / 名称 / 包名 / 启动画面          │
│  · 自定义 MainActivity(下载接管等原生能力)│
│  · 一个 WebView                          │
└──────────────┬──────────────────────────┘
               │ 启动时加载
               ↓
┌─────────────────────────────────────────┐
│  线上网站 ← 在 GitHub 上                 │
│  github.nb-channel.top/Beta/index-Beta.html
│  · 所有页面、功能、样式                  │
│  · 数据来自 Supabase                     │
└─────────────────────────────────────────┘
```

**关键结论:网站改动 99% 不需要重装 APP** —— 因为 APP 加载的就是线上站点,
改完网站用户打开就是最新的。**只有改动外壳**(图标、名称、包名、原生功能)才需要重新构建。

## 版本管理

版本号只有一个来源:

```
app/version.txt     ← 想升版本,改这个文件(内容就是一行,如 1.0.1)
```

构建时会自动:
- `versionName` = `version.txt` 的内容(给人看的,如 `1.0.1`)
- `versionCode` = GitHub Actions 的 `run_number`(给系统判断新旧用,**必须单调递增**)
- UA 里注入 `NBChannelApp/<versionName>`(网页据此识别"当前 APP 版本")

## 怎么拿到 APK

**不用在本地装 Android 环境** —— 全部在 GitHub Actions 云端构建:

1. 打开仓库 **Actions** → 左侧 **Build Android APK** → **Run workflow**
2. 等 3~10 分钟(首次较久,要下载 Android 依赖)
3. 构建完成后有两条下载途径:
   - **国内直连**(推荐):`https://github.nb-channel.top/download/NBChannel.apk`
   - GitHub Release:`https://github.com/NB-Channel/nb-channel/releases/latest`

> 改动 `app/` 或本 workflow 文件并推送,也会自动触发构建。

## Release 机制

- **tag 固定为 `app-latest`** → Releases 列表**永远只有一条**,不会每次构建堆积
- 版本号写在 Release 标题与说明里
- 构建时**自动清理**历史 Release 与 tag(见 workflow 的 "Clean old APP releases")

## 自更新

三层配合,已安装的用户点一下就能升级,不需要来网页找链接:

| 层 | 做什么 |
|---|---|
| **原生**(`android-overrides/MainActivity.java`) | 挂 `DownloadListener`:网页里任何下载请求 → 系统下载管理器 → 下完自动调系统安装器 |
| **构建**(workflow) | 产出 `download/version.json`,记录最新版本号与 APK 地址 |
| **网页**(23 个页面里的自更新脚本) | 从 UA 读出本地版本 → 与 `version.json` 比对 → 有新版弹底部更新条;导航「更多功能」下拉与 ☰ 抽屉里还有手动「检查更新」入口 |

## 目录说明

```
app/
├── version.txt              ← 版本号唯一来源
├── package.json             Capacitor 依赖
├── capacitor.config.json    APP 配置(名称/包名/加载网址/允许跳转的域名)
├── android-overrides/
│   ├── MainActivity.java    自定义原生代码(下载接管 + 自动安装)
│   └── apply.mjs            构建时注入:覆盖 MainActivity、补权限、写版本号、生成 version.json
├── resources/               图标与启动图(从 images/NB频道LOGO.png 生成)
│   ├── icon.png             应用图标 1024×1024
│   ├── splash.png           启动画面 2732×2732
│   └── icon-only.png        纯图标版(备用)
└── www/index.html           兜底页(server.url 未生效时短暂显示)
```

## 构建流程(workflow 里做了什么)

1. 装 Node / JDK 21 / Android SDK
2. `npm install` → `cap add android` 生成安卓工程
3. **`node android-overrides/apply.mjs`** ← 注入自定义原生代码、补 `REQUEST_INSTALL_PACKAGES` 权限、写版本号、生成 `version.json`
4. 生成图标与启动图
5. `cap sync android` → `gradlew assembleDebug` 出包
6. 发布到 Release(固定 tag)+ 提交到 `download/` 供网站直连下载

## 本地构建(可选,需要 Android 环境)

```bash
cd app
npm install
npx cap add android
node android-overrides/apply.mjs
npx cap sync android
cd android && ./gradlew assembleDebug
# 产物:android/app/build/outputs/apk/debug/app-debug.apk
```
需要:JDK 17+、Android SDK(platform 34 + build-tools 34)。

## 常见问题

**Q: 网页里点安装包没反应?**
A: 那是旧版 APK(没有原生下载接管)。装上 v1.0.1 之后就不会了。

**Q: 网站更新了,APP 要重装吗?**
A: 不用。APP 加载的就是线上站点,打开即最新。

**Q: iOS 怎么办?**
A: 用 Safari 打开官网 → 分享 → 添加到主屏幕,得到独立图标 + 全屏运行,效果接近原生。

**Q: 能上应用商店吗?**
A: 当前是 debug 版(Android 默认调试证书签名),不能上架国内商店 ——
   国内商店要求软著 + APP 备案,而备案又要求域名先有 ICP 备案(需境内服务器)。
