# NB频道 · 安卓客户端(APK)

官网的安卓客户端外壳 —— 用 [Capacitor](https://capacitorjs.com/) 把线上网站包成一个可安装的 APP。

## 特点

- **不是离线拷贝**:APP 内部直接加载线上官网(`github.nb-channel.top/Beta/index-Beta.html`),
  所以**网站更新后 APP 自动就是最新版**,不用重新打包发版
- 安装后桌面有独立图标、全屏运行(没有浏览器地址栏),体验接近原生
- APK 极小(约 3~5MB),因为不含网站文件

## 怎么拿到 APK

**不用在本地装 Android 环境** —— 用 GitHub Actions 云端构建:

1. 打开仓库的 **Actions** 页面 → 左侧选 **Build Android APK** → 点 **Run workflow**
2. 等约 3~5 分钟(第一次会久一点,要下载 Android 依赖)
3. 构建完成后,去 **Releases** 页面下载最新 APK:
   `https://github.com/NB-Channel/nb-channel/releases/latest`
4. 手机上点开 APK 安装,提示"未知来源"时允许一次

> 改动 `app/` 目录下的任何文件并推送,也会自动触发构建。

## 目录说明

```
app/
├── package.json            Capacitor 依赖
├── capacitor.config.json   APP 配置(名称/包名/加载的网址)
├── resources/              图标与启动图(从 images/NB频道LOGO.png 生成)
│   ├── icon.png            应用图标 1024×1024
│   ├── splash.png          启动画面 2732×2732
│   └── icon-only.png       纯图标版(备用)
└── www/index.html          兜底页(server.url 未生效时短暂显示)
```

## 本地构建(可选,需要 Android 环境)

```bash
cd app
npm install
npx cap add android
npx cap sync android
cd android && ./gradlew assembleDebug
# 产物:android/app/build/outputs/apk/debug/app-debug.apk
```

需要:JDK 17+、Android SDK(platform 34 + build-tools 34)。

## 想改的地方

| 想改什么 | 改哪里 |
|---|---|
| APP 名称 | `capacitor.config.json` 的 `appName` |
| 包名(安装后唯一标识) | `capacitor.config.json` 的 `appId` |
| 加载的网址 | `capacitor.config.json` 的 `server.url` |
| 图标 / 启动图 | 换掉 `resources/icon.png`、`resources/splash.png` 后重新构建 |
| 允许 APP 内跳转的域名 | `capacitor.config.json` 的 `server.allowNavigation` |

## 说明

- 当前构建的是 **debug 版 APK**(用 Android 默认调试证书签名),可以正常安装使用,
  但不能上架应用商店。要上架需要正式签名证书,而且国内商店还要求软著与备案。
- APP 内所有数据仍来自官网与 Supabase,与网页版**完全同源**,账号通用。
