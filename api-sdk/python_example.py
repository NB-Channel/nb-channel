# -*- coding: utf-8 -*-
"""
NB频道 市值 API - Python 示例
依赖：requests（pip install requests）；不想装 requests 可用标准库 urllib 版本（见文件底部注释）
用法：见 README.md

⚠️ 需要 API Key（2026-09-25 起）
   /api/market、/api/comments、/api/stats 需带 X-API-Key 请求头，否则返回 401。
   向站长申请后这样用：
       nb = NBMarket(api_key="你申请到的 Key")
   /api/bili-fans 与 /api/docs 仍然完全公开，不需要 Key。
"""
import requests

BASE_URL = "https://api.nb-channel.top"


class NBMarket:
    def __init__(self, base_url=BASE_URL, api_key=None, timeout=10):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout

    def _headers(self):
        """需要 Key 的端点用这个；公开端点（bili_fans / docs）不必带。"""
        return {"X-API-Key": self.api_key} if self.api_key else {}

    def _get(self, path, **params):
        resp = requests.get(self.base_url + path, params=params,
                            headers=self._headers(), timeout=self.timeout)
        if resp.status_code == 401:
            raise RuntimeError("API Key 缺失或错误：请用 NBMarket(api_key='...') 传入申请到的 Key")
        resp.raise_for_status()
        return resp.json()

    def market(self, name=None):
        """全市场快照；name 可选，按公司名模糊查询。"""
        return self._get("/api/market", name=name) if name else self._get("/api/market")

    def market_by_id(self, company_id):
        """单家公司市值。"""
        return self._get("/api/market/%s" % company_id)

    def history(self, company_id, days=7):
        """历史K线（市值走势点），days 1~30。"""
        return self._get("/api/market/%s/history" % company_id, days=days)

    def export_csv(self):
        """全市场 CSV 导出，返回 CSV 文本。"""
        # 注意:这个端点也要 Key —— 之前漏了请求头,会直接被 401 挡掉
        resp = requests.get(self.base_url + "/api/market/export",
                            params={"format": "csv"},
                            headers=self._headers(), timeout=self.timeout)
        if resp.status_code == 401:
            raise RuntimeError("API Key 缺失或错误：请用 NBMarket(api_key='...') 传入申请到的 Key")
        resp.raise_for_status()
        return resp.text

    def bili_fans(self):
        """B站实时粉丝数（公开端点，不需要 Key）。"""
        resp = requests.get(self.base_url + "/api/bili-fans", timeout=self.timeout)
        resp.raise_for_status()
        return resp.json()

    def comments(self, page=1, limit=20, page_path=None):
        """最新评论（只读）。"""
        params = {"page": page, "limit": limit}
        if page_path:
            params["page_path"] = page_path
        return self._get("/api/comments", **params)


if __name__ == "__main__":
    nb = NBMarket()
    m = nb.market()
    print("全市场总市值:", m.get("total_market_value"), "公司数:", m.get("count"))
    for c in (m.get("companies") or [])[:5]:
        print("  %s 市值=%s 归属=%s" % (c["name"], c["market_value"], c["owner"]))
    one = nb.market_by_id(3)
    print("单公司:", one)
    k = nb.history(3, days=3)
    print("历史K线点数:", k.get("points_count"))
    cs = nb.comments(limit=3)
    for c in (cs.get("comments") or []):
        print("评论[%s]: %s" % (c["username"], c["content"][:30]))
    print("CSV 前两行:\n" + "\n".join(nb.export_csv().splitlines()[:2]))

# ==================== 标准库 urllib 版本（无第三方依赖） ====================
"""
import json
import urllib.parse
import urllib.request

class NBMarketStd:
    def __init__(self, base_url="https://api.nb-channel.top"):
        self.base_url = base_url.rstrip("/")

    def get_json(self, path, **params):
        url = self.base_url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        with urllib.request.urlopen(url, timeout=10) as r:
            return json.loads(r.read().decode("utf-8"))

    def market(self, name=None):
        return self.get_json("/api/market", name=name) if name else self.get_json("/api/market")

    def market_by_id(self, company_id):
        return self.get_json("/api/market/%s" % company_id)

    def history(self, company_id, days=7):
        return self.get_json("/api/market/%s/history" % company_id, days=days)

    def comments(self, page=1, limit=20, page_path=None):
        params = {"page": page, "limit": limit}
        if page_path:
            params["page_path"] = page_path
        return self.get_json("/api/comments", **params)
"""
