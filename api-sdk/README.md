# NB频道 市值 API - 官方 SDK 示例

使用 `api.nb-channel.top` 统一入口调用 NB频道 虚拟股票公开接口。

## ⚠️ 需要 API Key（2026-09-25 起）

`/api/market`、`/api/comments`、`/api/stats` 需要带 **`X-API-Key`** 请求头，否则返回
`401 UNAUTHORIZED`。`/api/bili-fans` 与 `/api/docs` 仍然完全公开。

**申请**：邮件 `nbchannel@163.com` 或站内评论区 @NB频道官方，说明用途与大致调用频率。

```bash
curl -H "X-API-Key: 你的Key" "https://api.nb-channel.top/api/market"
```

```python
nb = NBMarket(api_key="你的Key")      # Python
```
```javascript
NBMarket.setApiKey('你的Key');         // JavaScript
```

> 请用请求头而不是 `?key=` 参数 —— URL 会进日志和 referrer。
> 也不要把 Key 提交到公开代码仓库。

## 接口速览

| 端点 | 鉴权 | 说明 |
|---|---|---|
| `GET /api/market` | 需 Key | 全市场快照（支持 `?name=` 模糊查询） |
| `GET /api/market/<company_id>` | 需 Key | 单家公司市值 |
| `GET /api/market/<company_id>/history?days=7` | 需 Key | 历史K线（市值走势点） |
| `GET /api/market/export?format=csv` | 需 Key | 全市场 CSV 导出 |
| `GET /api/comments?page=1&limit=20` | 需 Key | 最新评论（只读） |
| `GET /api/stats` | 需 Key | 接口用量统计（开发用） |
| `GET /api/bili-fans` | 公开 | B站实时粉丝数 |
| `GET /api/docs` | 公开 | 接口文档 |

统一响应：成功 `{"success": true, "code": "OK", ...}`；失败 `{"success": false, "code": "错误码", "message": "..."}`。
限流：每 IP 每分钟 60 次。

## 示例文件

- `python_example.py` — Python 3（requests 库，无第三方依赖可选 urllib 版）
- `js_example.js` — 浏览器 / Node.js（fetch）

## Python 用法

```python
from python_example import NBMarket

nb = NBMarket(api_key="你申请到的 Key")   # Key 必需

market = nb.market()                    # 全市场
found  = nb.market(name="NB")           # 按名模糊查
one    = nb.market_by_id(3)             # 单公司
kline  = nb.history(3, days=7)          # 历史K线
export = nb.export_csv()                # CSV 文本
comments = nb.comments(page=1, limit=10)  # 最新评论
fans   = nb.bili_fans()                 # 公开接口，不需要 Key
```

## Node.js / 浏览器用法

```javascript
const nb = require('./js_example');   // Node；浏览器里直接 <script> 后 window.NBMarket

NBMarket.setApiKey('你申请到的 Key');  // 先填 Key

const market = await NBMarket.market();
const one = await NBMarket.marketById(3);
const kline = await NBMarket.history(3, 7);
const comments = await NBMarket.comments(1, 10);
const fans = await NBMarket.biliFans();   // 公开接口，不需要 Key
```

## 常见错误码

| code | 含义 |
|---|---|
| `UNAUTHORIZED` | API Key 缺失/错误 —— 请带上 `X-API-Key` 请求头 |
| `RATE_LIMITED` | 请求过频（60次/分钟/IP） |
| `NOT_FOUND` | 公司不存在 |
| `INVALID_PARAM` | 参数不合法 |
| `DB_ERROR` | 后端异常（稍后重试） |

## 注意

- 数据只读，请勿批量爬取或高频轮询（有每分钟限流，且 Key 可随时吊销）
- 有疑问联系站长：nbchannel@163.com
