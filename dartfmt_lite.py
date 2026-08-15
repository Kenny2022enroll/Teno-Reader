#!/usr/bin/env python3
"""dartfmt-lite: add trailing commas to Dart argument lists / collection literals.

Approach (rough heuristic tuned for Flutter widget patterns).
"""
import sys
import re


def add_trailing_commas(text):
    lines = text.split('\n')
    n = len(lines)
    out = list(lines)

    changed = True
    passes = 0
    while changed and passes < 4:
        changed = False
        passes += 1
        for i in range(n - 1):
            cur = out[i]
            nxt = out[i + 1]
            stripped = cur.rstrip()
            if not stripped.strip():
                continue
            if stripped.lstrip().startswith('//'):
                continue
            if stripped.endswith((',', '(', '[', '{')):
                continue
            if re.search(r'[+\-*/%=<>?:&|.]\s*$', stripped):
                continue
            cur_indent = len(cur) - len(cur.lstrip(' '))
            closer_match = re.match(r'^(\s*)([)\]}])', nxt)
            if not closer_match:
                continue
            closer_indent = len(closer_match.group(1))
            if closer_indent > cur_indent:
                continue
            if re.search(r'=>\s+[^\s,;]+$', stripped):
                continue
            out[i] = stripped + ','
            changed = True
    return '\n'.join(out)


if __name__ == '__main__':
    for path in sys.argv[1:]:
        with open(path, 'r', encoding='utf-8') as f:
            src = f.read()
        new_src = add_trailing_commas(src)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_src)
        diff = sum(1 for a, b in zip(src.split('\n'), new_src.split('\n')) if a != b)
        print('{}: {} lines tweaked'.format(path, diff))
