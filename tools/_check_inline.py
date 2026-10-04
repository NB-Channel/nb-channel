# -*- coding: utf-8 -*-
"""把两个页面里的内联 <script> 抽出来，逐个交给 node --check 语法校验。"""
import io
import os
import re
import subprocess
import sys
import tempfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = r'D:\工作区\nb-channel-main'
FILES = [
    os.path.join(ROOT, 'Virtual stock.html'),
    os.path.join(ROOT, 'Beta', 'stock-Beta.html'),
]

# 匹配 <script ...> ... </script>（跳过带 src 的外链）
PAT = re.compile(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', re.S | re.I)

fail = 0
for path in FILES:
    src = io.open(path, 'r', encoding='utf-8', newline='').read()
    blocks = PAT.findall(src)
    print('=== %s' % path)
    print('    inline <script> blocks: %d' % len(blocks))
    # 开闭标签配对
    opens = len(re.findall(r'<script\b', src, re.I))
    closes = len(re.findall(r'</script>', src, re.I))
    print('    <script> tags: %d open / %d close  %s' % (opens, closes, 'OK' if opens == closes else 'MISMATCH!'))
    if opens != closes:
        fail += 1
    for i, code in enumerate(blocks):
        if not code.strip():
            continue
        fd, tmp = tempfile.mkstemp(suffix='.js', dir=tempfile.gettempdir())
        os.close(fd)
        with io.open(tmp, 'w', encoding='utf-8') as f:
            f.write('(async function(){\n' + code + '\n})();\n')
        r = subprocess.run(['node', '--check', tmp], capture_output=True, text=True, encoding='utf-8', errors='replace')
        os.unlink(tmp)
        if r.returncode != 0:
            fail += 1
            print('    [BLOCK %2d] node --check FAILED' % (i + 1))
            print('      ' + (r.stderr or '').strip().replace('\n', '\n      ')[:900])
        else:
            print('    [BLOCK %2d] OK  (%d chars)' % (i + 1, len(code)))
    print()
print('FAILURES:', fail)
sys.exit(1 if fail else 0)
