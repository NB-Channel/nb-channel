# -*- coding: utf-8 -*-
"""对比改动前(.injectbak)与改动后，确认脚本语法错误是不是我引入的。"""
import io
import os
import re
import subprocess
import sys
import tempfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = r'D:\工作区\nb-channel-main'
PAT = re.compile(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', re.S | re.I)


def check(path, tag):
    src = io.open(path, 'r', encoding='utf-8', newline='').read()
    blocks = PAT.findall(src)
    print('--- %s (%d blocks) %s' % (tag, len(blocks), path))
    for i, code in enumerate(blocks):
        if not code.strip():
            continue
        fd, tmp = tempfile.mkstemp(suffix='.js', dir=tempfile.gettempdir())
        os.close(fd)
        with io.open(tmp, 'w', encoding='utf-8') as f:
            f.write(code)
        r = subprocess.run(['node', '--check', tmp], capture_output=True, text=True, encoding='utf-8', errors='replace')
        os.unlink(tmp)
        status = 'OK  ' if r.returncode == 0 else 'FAIL'
        first_err = ''
        if r.returncode != 0:
            lines = [l for l in (r.stderr or '').split('\n') if l.strip()]
            first_err = ' | ' + lines[1].strip() if len(lines) > 1 else ''
        print('   [%2d] %-4s %8d chars%s' % (i + 1, status, len(code), first_err))


for rel in ('Virtual stock.html', r'Beta\stock-Beta.html'):
    check(os.path.join(ROOT, rel + '.injectbak'), 'BEFORE')
    check(os.path.join(ROOT, rel), 'AFTER ')
    print()
