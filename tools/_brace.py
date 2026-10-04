# -*- coding: utf-8 -*-
"""抽出根目录页面主脚本块，定位我新加片段里的花括号不平衡。"""
import io
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = r'D:\工作区\nb-channel-main'
PAT = re.compile(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', re.S | re.I)
src = io.open(ROOT + r'\Virtual stock.html', 'r', encoding='utf-8', newline='').read()
block = PAT.findall(src)[2]

start = block.find('    // 增资（创始人专属）')
end = block.find('    async function refreshStockDataFromDB()')
frag = block[start:end]
print('fragment chars:', len(frag))

# 粗略统计：跳过字符串/模板/注释后再数括号
def scan(t):
    i = 0
    n = len(t)
    depth = 0
    line = 1
    mins = []
    while i < n:
        c = t[i]
        if c == '\n':
            line += 1
            i += 1
            continue
        if c == '/' and i + 1 < n and t[i + 1] == '/':
            while i < n and t[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and t[i + 1] == '*':
            i += 2
            while i + 1 < n and not (t[i] == '*' and t[i + 1] == '/'):
                if t[i] == '\n':
                    line += 1
                i += 1
            i += 2
            continue
        if c == "'" or c == '"':
            q = c
            i += 1
            while i < n and t[i] != q:
                if t[i] == '\\':
                    i += 1
                i += 1
            i += 1
            continue
        if c == '`':
            i += 1
            while i < n and t[i] != '`':
                if t[i] == '\\':
                    i += 1
                elif t[i] == '\n':
                    line += 1
                i += 1
            i += 1
            continue
        if c in '({[':
            depth += 1
        elif c in ')}]':
            depth -= 1
            mins.append((depth, line))
        i += 1
    return depth, mins


d, mins = scan(frag)
print('final depth (should be 0):', d)
neg = [m for m in mins if m[0] < 0]
print('first negative depth events:', neg[:5])
