# -*- coding: utf-8 -*-
"""一条命令同步更新日志 / Beta 版 / 关于页。

用法：
    python sync_changelog.py          # 同步
    python sync_changelog.py --check  # 只看会改什么，不写文件

做的事：
    1. 从 changelog.html 解析出所有版本条目（版本号 / 日期 / 标题 / 条目列表）
    2. 把 Beta/changelog-Beta.html 里的 var CHANGES = [...] 整块重写成同样的内容
    3. 把 about.html 里的版本号更新成最新版本，并重写「最近更新」区块
       （区块用 <!-- AUTO:recent --> ... <!-- /AUTO:recent --> 标记，可以反复跑）
"""
import io
import json
import os
import re
import sys

ROOT = r"D:\工作区\nb-channel-main"
MAIN = os.path.join(ROOT, "changelog.html")
BETA = os.path.join(ROOT, "Beta", "changelog-Beta.html")
ABOUT = os.path.join(ROOT, "about.html")

HEAD_RE = re.compile(r"<p><strong>NB频道 V ([\d.]+)（(\d{4}-\d{2}-\d{2})）·([^<]*)</strong></p>")
LI_RE = re.compile(r"<li>([^<]*)</li>")


def parse_main():
    s = io.open(MAIN, encoding="utf-8", errors="replace").read()
    hits = list(HEAD_RE.finditer(s))
    out = []
    for i, m in enumerate(hits):
        ver, date, title = m.group(1), m.group(2), m.group(3).strip()
        start = m.end()
        end = hits[i + 1].start() if i + 1 < len(hits) else s.find("</div>", start)
        if end < 0:
            end = len(s)
        seg = s[start:end]
        ul = re.search(r"<ul>([\s\S]*?)</ul>", seg)
        lines = [x.strip() for x in LI_RE.findall(ul.group(1))] if ul else []
        out.append({"ver": ver, "date": date, "id": ver.replace(".", "-"),
                    "title": title, "lines": [("%s · %s" % (title, lines[0])) if lines else title] + lines[1:]})
    return out


def sync_beta(entries, check):
    s = io.open(BETA, encoding="utf-8", errors="replace").read()
    m = re.search(r"var CHANGES = \[[\s\S]*?\]\s*;", s)
    if not m:
        return "❌ Beta 里找不到 var CHANGES = [...]"
    payload = []
    for e in entries:
        payload.append({"ver": e["ver"], "date": e["date"], "id": e["id"],
                        "lines": [e["title"]] + e["lines"] if e["title"] not in e["lines"][:1] else e["lines"]})
    body = json.dumps(payload, ensure_ascii=False, indent=4)
    # 去掉最外层 [ ]，只替换中间内容
    newblock = "var CHANGES = " + body.replace("\n", "\n    ") + ";"
    old_n = s.count('"ver"')
    if check:
        return "Beta：%d 条 → %d 条（会重写整块）" % (old_n, len(entries))
    s = s[:m.start()] + newblock + s[m.end():]
    io.open(BETA, "w", encoding="utf-8").write(s)
    return "✅ Beta：%d 条 → %d 条" % (old_n, len(entries))


def sync_about(entries, check):
    if not entries:
        return "⚠️ 没有版本条目，跳过关于页"
    latest = entries[0]
    s = io.open(ABOUT, encoding="utf-8", errors="replace").read()

    block = ["<!-- AUTO:recent -->",
             "<p><strong>最近更新（%s · V%s）</strong></p>" % (latest["date"], latest["ver"]),
             ""]
    for ln in latest["lines"][:12]:
        block.append("<p>%s</p>" % ln)
    block.append("<!-- /AUTO:recent -->")
    newblock = "\n".join(block)

    changed = []
    # ① 版本号
    m = re.search(r"<h2>关于 NB频道（[^）]*）</h2>", s)
    if m:
        newh = "<h2>关于 NB频道（V%s）</h2>" % latest["ver"]
        if newh != m.group(0):
            s = s[:m.start()] + newh + s[m.end():]
            changed.append("版本号 → V%s" % latest["ver"])
    else:
        changed.append("⚠️ 找不到关于页版本标题")

    # ② 最近更新区块
    if "<!-- AUTO:recent -->" in s:
        s = re.sub(r"<!-- AUTO:recent -->[\s\S]*?<!-- /AUTO:recent -->", newblock, s, count=1)
        changed.append("重写最近更新区块")
    else:
        m2 = re.search(r"<h2>关于 NB频道（[^）]*）</h2>", s)
        if m2:
            s = s[:m2.end()] + "\n\n" + newblock + s[m2.end():]
            changed.append("插入最近更新区块")

    if check:
        return "关于页：" + "、".join(changed)
    io.open(ABOUT, "w", encoding="utf-8").write(s)
    return "✅ 关于页：" + "、".join(changed)


if __name__ == "__main__":
    check = "--check" in sys.argv
    entries = parse_main()
    print("  主站更新日志：%d 个版本（最新 V%s）" % (len(entries), entries[0]["ver"] if entries else "?"))
    for e in entries[:3]:
        print("     V%-6s %s  %s（%d 条）" % (e["ver"], e["date"], e["title"][:30], len(e["lines"])))
    print()
    print("  " + sync_beta(entries, check))
    print("  " + sync_about(entries, check))
    if check:
        print("\n  （--check 模式，没有写文件）")
