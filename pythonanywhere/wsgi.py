# -*- coding: utf-8 -*-
"""
PythonAnywhere WSGI 入口。
在 PythonAnywhere Web 面板中把 WSGI 配置文件路径指向本文件。
"""
import sys
import os

# 把当前目录加入模块搜索路径
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# ============ API Key(必须在 import app 之前设置) ============
# app.py 在【模块加载时】读取 os.environ['API_KEY'](见 app.py 里那行),
# 所以环境变量一定要在下面 import app 之前就位。
# 配好之后 /api/market、/api/comments、/api/stats 需带 X-API-Key 头,
# 否则返回 401;/api/bili-fans 与 /api/docs 不受影响。
#
# ⚠️ 本文件在【公开仓库】里 —— 真实 Key 不要写在这里,也不要提交上来,
#    否则 Key 就公开了,等于没设。
#
# 推荐做法:用 PythonAnywhere 的 Web 面板 → Environment variables 新增
#     Name  = API_KEY
#     Value = <你的 Key>
#   然后点 Reload。Key 不进仓库,也不会和 git pull 冲突。
#
# 只有在无法使用面板时才用下面这行(且务必不要提交):
# os.environ['API_KEY'] = '在这里填真实 Key'
# =============================================================

from app import app as application  # noqa: E402
