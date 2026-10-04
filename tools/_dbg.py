# -*- coding: utf-8 -*-
import io
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.path.insert(0, 'tools')
import _apply_inject as m

total_bad = 0
for v in ('root', 'beta'):
    p, prs = m.build_pairs(v)
    with io.open(p, 'r', encoding='utf-8', newline='') as f:
        s = f.read()
    print('===', v, p)
    print('    %d replacements' % len(prs))
    bad = 0
    for i, (o, n) in enumerate(prs):
        c = s.count(o)
        if c != 1:
            bad += 1
            print('  [FAIL %2d] match=%d  %r' % (i + 1, c, o[:170]))
    print('    bad anchors:', bad)
    total_bad += bad
print('TOTAL BAD:', total_bad)
