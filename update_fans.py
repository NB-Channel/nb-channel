# update_fans.py
# ============================================================
# 把 B站 粉丝数写进 data/fans.json(静态文件)
#
# 为什么要有这个:
#   首页原先直接请求 https://nbchannel.pythonanywhere.com/api/bili-fans,
#   等于把 PythonAnywhere 的后端暴露成一个"可以被无限刷"的公开端点
#   (该端点不能加 Key —— 首页要调它;加了 Key 就得把 Key 写进公开的 HTML)。
#   改成静态文件后,请求打到 GitHub Pages 的 CDN,被刷也不消耗任何后端资源。
#
# 由 .github/workflows/update-fans.yml 定时调用,也支持本地手动跑:
#     python update_fans.py
# ============================================================
import json
import os
import sys
from datetime import datetime, timezone, timedelta

BILIBILI_UID = 3493259582114264        # 与 update_videos.py 保持一致
OUT_PATH = os.path.join('data', 'fans.json')


def fetch_follower():
    """取粉丝数。优先用 bilibili-api-python(与 update_videos.py 同依赖);
    拿不到就退回直连 B站 公开接口(无需登录)。"""
    # --- 方式一:bilibili-api-python ---
    try:
        from bilibili_api import user, sync
        u = user.User(uid=BILIBILI_UID)
        info = sync(u.get_relation_info())
        n = info.get('follower')
        if n:
            print('通过 bilibili-api 取到粉丝数: %s' % n)
            return int(n)
        print('bilibili-api 返回里没有 follower 字段: %r' % (info,))
    except Exception as e:
        print('bilibili-api 取数失败,改用直连接口: %s' % e)

    # --- 方式二:直连公开接口 ---
    try:
        import urllib.request
        url = 'https://api.bilibili.com/x/relation/stat?vmid=%d' % BILIBILI_UID
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (compatible; NBChannel-fans-bot/1.0)',
            'Referer': 'https://space.bilibili.com/%d' % BILIBILI_UID,
        })
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read().decode('utf-8', 'ignore'))
        if data.get('code') == 0:
            n = data.get('data', {}).get('follower')
            if n:
                print('通过直连接口取到粉丝数: %s' % n)
                return int(n)
        print('直连接口返回异常: %r' % (data,))
    except Exception as e:
        print('直连接口也失败: %s' % e)

    return None


def main():
    n = fetch_follower()
    if not n:
        # 关键:取不到就【保留旧文件、直接成功退出】。
        # 不能让 workflow 失败,更不能写 0 —— 否则首页会显示 0(比不更新更糟)。
        print('未能取到粉丝数,保留现有 %s 不变,退出码 0' % OUT_PATH)
        return 0

    bj = timezone(timedelta(hours=8))
    payload = {
        'follower': n,
        'updated_at': datetime.now(bj).strftime('%Y-%m-%d %H:%M:%S'),
        'updated_at_iso': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    }

    # 读旧值,没变化就不写(避免 workflow 每次提交空改动)
    old = None
    if os.path.exists(OUT_PATH):
        try:
            with open(OUT_PATH, 'r', encoding='utf-8') as f:
                old = json.load(f)
        except Exception:
            old = None
    if old and old.get('follower') == n:
        print('粉丝数没变化(%s),跳过写入' % n)
        return 0

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print('已写入 %s: %s' % (OUT_PATH, payload))
    return 0


if __name__ == '__main__':
    sys.exit(main())
