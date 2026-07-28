#!/usr/bin/env python3
"""
fix_match_lists.py — Reformat fragmented match-list/column-matching questions
into clean, readable 2-column text that renders properly in the app and web renderer.

This is a DATA-LEVEL fix: updating question_latex in the JSON so existing app
installs get the fix via OTA sync (no APK update needed).

Handles 3 structural variants:
  1. Interleaved: (a)\\n desc\\n (i)\\n desc\\n ...
  2. Sequential: List-I items, then List-II items
  3. Inline pairs: (a) desc\\n (i) desc\\n ...
"""

import json, re, sys

LABEL_RE = re.compile(r'^\(([a-eA-E])\)\s*(.*)')
ROMAN_RE = re.compile(r'^\(([iv]+|[IV]+)\)\s*(.*)')
LIST_HDR_RE = re.compile(r'^(List[\s-]*I{1,2}|Column[\s-]*I{1,2})$', re.IGNORECASE)
FOOTER_RE = re.compile(r'Choose|most appropriate|option.*given|correct answer', re.IGNORECASE)
MATCH_PATS = [
    re.compile(r'Match List.*with List', re.IGNORECASE),
    re.compile(r'Match the.*Column', re.IGNORECASE),
    re.compile(r'Match Column', re.IGNORECASE),
    re.compile(r'List[\s-]*I.*List[\s-]*II', re.IGNORECASE),
    re.compile(r'Column[\s-]*I.*Column[\s-]*II', re.IGNORECASE),
]
ROMAN_ORDER = ['i', 'ii', 'iii', 'iv', 'v', 'vi']


def is_match_list(text):
    return any(p.search(text) for p in MATCH_PATS)


def needs_reformat(text):
    """True if the text has raw table structure that needs reformatting."""
    if not is_match_list(text):
        return False
    return bool(re.search(r'\n\s*\(a\)', text, re.IGNORECASE) and re.search(r'\(i\)', text, re.IGNORECASE))


def reformat_match_list(text):
    """Convert fragmented match-list table text into clean 2-column format."""
    lines = text.split('\n')
    non_empty = [(i, l.strip()) for i, l in enumerate(lines) if l.strip()]

    if not non_empty:
        return text

    header_lines = []
    footer_lines = []
    body_tokens = []

    phase = 'header'
    pending_key = None
    pending_type = None

    for _, line in non_empty:
        if phase == 'footer' or FOOTER_RE.search(line):
            phase = 'footer'
            footer_lines.append(line)
            continue

        if LIST_HDR_RE.match(line):
            continue

        lm = LABEL_RE.match(line)
        rm = ROMAN_RE.match(line)

        if lm:
            if pending_key:
                body_tokens.append((pending_type, pending_key, ''))
            key = lm.group(1).lower()
            desc = lm.group(2).strip()
            if desc:
                body_tokens.append(('label', key, desc))
                pending_key = None
            else:
                pending_key = key
                pending_type = 'label'
            phase = 'body'
        elif rm:
            if pending_key:
                body_tokens.append((pending_type, pending_key, ''))
            key = rm.group(1).lower()
            desc = rm.group(2).strip()
            if desc:
                body_tokens.append(('roman', key, desc))
                pending_key = None
            else:
                pending_key = key
                pending_type = 'roman'
            phase = 'body'
        elif phase == 'body' and pending_key:
            body_tokens.append((pending_type, pending_key, line))
            pending_key = None
        elif phase == 'header':
            header_lines.append(line)

    if pending_key:
        body_tokens.append((pending_type, pending_key, ''))

    left = {}
    right = {}
    for typ, key, desc in body_tokens:
        if typ == 'label':
            left[key] = desc
        else:
            right[key] = desc

    if len(left) < 2 or len(right) < 2:
        return text

    left_keys = sorted(left.keys())
    right_keys = sorted(right.keys(),
                        key=lambda x: ROMAN_ORDER.index(x) if x in ROMAN_ORDER else 99)

    result = []
    if header_lines:
        result.append('\n'.join(header_lines))
    result.append('')
    result.append('List-I | List-II')

    for lk, rk in zip(left_keys, right_keys):
        result.append(f'({lk}) {left[lk]}  |  ({rk}) {right[rk]}')

    for i in range(min(len(left_keys), len(right_keys)),
                   max(len(left_keys), len(right_keys))):
        if i < len(left_keys):
            result.append(f'({left_keys[i]}) {left[left_keys[i]]}  |')
        if i < len(right_keys):
            result.append(f'  |  ({right_keys[i]}) {right[right_keys[i]]}')

    if footer_lines:
        result.append('')
        result.extend(footer_lines)

    return '\n'.join(result)


def fix_bank(path):
    with open(path) as f:
        data = json.load(f)

    fixed = 0
    for q in data:
        qt = q.get('question_latex', '')
        if needs_reformat(qt):
            new_qt = reformat_match_list(qt)
            if new_qt != qt:
                q['question_latex'] = new_qt
                fixed += 1

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

    return fixed


if __name__ == '__main__':
    jee = fix_bank('assets/jee.json')
    neet = fix_bank('assets/neet.json')
    print(f'Fixed {jee} JEE + {neet} NEET = {jee + neet} match-list questions')
