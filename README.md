# NB频道官网

> 🚀 热爱理科，与作死同行 —— UP主「NB搞事局」的虚拟公司官网。

[![GitHub Pages](https://img.shields.io/badge/hosting-GitHub%20Pages%20%7C%20Cloudflare%20Pages%20%7C%20PythonAnywhere-blue)](https://github.nb-channel.top)
[![Auto Update Videos](https://github.com/NB-Channel/nb-channel/actions/workflows/auto-update.yml/badge.svg)](https://github.com/NB-Channel/nb-channel/actions/workflows/auto-update.yml)

主要分享有趣的化学、物理实验和日常作死小技巧，欢迎关注！

- 🌐 导航页：https://nb-channel.top
- 🟢 GitHub 站：https://github.nb-channel.top
- ⛅ Cloudflare 站：https://cloudflare.nb-channel.top
- 🐍 PythonAnywhere 站：https://pythonanywhere.nb-channel.top

## ✨ 功能

- 🎬 **视频展示**：自动同步 B 站合集视频（GitHub Actions 每日更新）
- 💬 **评论区**：登录 / 注册、@提及、发图片、蓝色链接、点赞 / 点踩、热门 / 最新排序、楼层、举报、违禁词与临时邮箱拦截
- 📈 **NB虚拟股票**：注册虚拟公司、NB币支付、买入 / 卖出 / 持仓、市值排行、破产处理
- 🪙 **NB币体系**：每日签到、随机金币彩蛋、成就徽章、转账
- 🧑‍🤝‍🧑 **好友与私信**：加好友、实时聊天、图片消息、会话管理
- 🧪 **作品分享**：上传 / 下载作品、付费购买（NB币或加市值）、编辑删除
- 🔔 **消息中心**：回复 / 提及通知、私信列表、评论跳转定位
- ✅ **公司认证**：虚拟公司认证（蓝标）、举报与封禁管理
- 🎨 **新版 / 旧版双界面**：玻璃拟态官网风 / 经典卡片风，偏好云端保存
- 🤖 **AI 助手**：多模型对话、推理档位、联网搜索、识图、生图（三档画质）
- 📄 **NB报刊社**：多期报纸、专栏文章、评论区联动

## 🛠️ 技术架构

| 组件 | 用途 |
|------|------|
| GitHub + GitHub Actions | 代码托管、视频数据每日自动更新、APK 构建 |
| Cloudflare Pages / GitHub Pages / PythonAnywhere | 静态站点托管（三站同步） |
| Supabase（PostgreSQL） | 用户、评论、股票、消息、作品等数据 + RPC + pg_cron 定时任务 |
| Supabase Storage | 头像、图片、作品文件存储 |
| 腾讯云函数（Flask） | AI 对话 / 识图 / 生图、计费、评论机器人、黑名单同步 |
| PythonAnywhere（Flask） | 作品上传下载、图片上传、公开 API、GitHub webhook 自动同步 |
| 图床小镇 / 蓝奏云 | 视频 / 产品文件存储 |

## 📁 目录结构（本仓 = 网站 + 安卓壳）

```
├── .github/workflows/   # auto-update（视频）、build-apk（安卓包）
├── css/                 # 样式（通用 / 新版细节 / 静态合并）
├── js/                  # 脚本（common.js 公共、ui-nav.js 新版界面驱动等）
├── data/                # 视频数据（由 update_videos.py 自动生成）
├── images/              # 站点图片、报纸插图
├── Beta/                # 新版（Beta）全套页面
├── classic-legacy/      # 旧版归档页面
├── archive/             # 已废弃页面归档
├── download/            # APK 与 version.json（由 build-apk 自动提交）
├── app/                 # Capacitor 安卓壳（原生底部栏、扫码、下载、通知）
└── *.html               # 各页面
```

### 不在这里的部分

后端与数据库脚本放在私有仓 **`NB-Channel/nb-channel-core`**：

- `sql/` —— 建表、RLS、RPC、限流、黑名单、定时任务
- `pythonanywhere/app.py` —— PythonAnywhere 后端
- `pythonanywhere/scf_mail_sender.py` —— 腾讯云函数

本仓只保留「静态网站 + 安卓壳 + APK 构建流水线」。

## 🔐 安全模型

- 前端只用 **Supabase anon key**（公开设计）：所有写操作走 **SECURITY DEFINER RPC**，权限在数据库层校验
- **密钥永不入仓**：service key、S3 密钥、webhook secret、签名 keystore 全部走服务器环境变量 / GitHub Secrets / 服务器本地文件
- AI 系统提示词存在数据库（`admin_settings.ai_system_prompt`），云函数用密钥读取并缓存，仓库里没有明文
- 匿名 key 实测打不动：`admin_settings` / `user_sessions` / `email_codes` / `banned_*` / `ai_wallet` / `ai_usage` / `bank_accounts` 一律 401

## 📱 安卓版

- `app/` 是 Capacitor 套壳：加载线上站点，网站更新后 APP 自动同步，无需重新发版
- 原生部分：底部导航、扫码、网页下载接管、消息通知、返回键处理、加载看门狗
- 构建：`.github/workflows/build-apk.yml`，产物自动提交到 `download/` 并生成 `version.json` 供 APP 检查更新
- 签名私钥不在仓库里，走 `ANDROID_KEYSTORE_BASE64` Secret

## 🧾 更新日志

见 [changelog.html](changelog.html)。
