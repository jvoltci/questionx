#!/usr/bin/env python3
import json, re

def is_structural_line(line):
    l = line.strip()
    if not l: return True
    if ' | ' in l or l.startswith('|'): return True
    if '\\hline' in l or '\\begin{tabular}' in l or '\\end{tabular}' in l or '\\begin{array}' in l or '\\end{array}' in l: return True
    if ' & ' in l or l.endswith('\\\\'): return True
    if l.startswith('$$') or l.endswith('$$'): return True
    if l.startswith('\\[') or l.endswith('\\]'): return True
    if re.match(r'^\([a-zA-Z0-9ivIV]+\)', l): return True
    if re.match(r'^[0-9ivIV]+\)', l): return True
    if re.match(r'^[0-9]+\.', l): return True
    if re.match(r'^(List|Column|Statement)[\s-]*[0-9IV]+', l, re.IGNORECASE): return True
    return False

def unwrap_text(text):
    lines = text.split('\n')
    if len(lines) <= 1: return text
    out_lines = []
    current_para = []
    for i, line in enumerate(lines):
        l = line.strip()
        if is_structural_line(l):
            if current_para:
                out_lines.append(' '.join(current_para))
                current_para = []
            out_lines.append(line)
            continue
        if current_para:
            last_word = current_para[-1].strip()
            if re.match(r'^(Which of the following|Choose the|The correct|Match the)', l, re.IGNORECASE) and last_word.endswith(('.', ':', '?', '!')):
                out_lines.append(' '.join(current_para))
                current_para = [l]
                continue
        current_para.append(l)
    if current_para:
        out_lines.append(' '.join(current_para))
    return '\n'.join(out_lines)

def fix_bank(path):
    with open(path) as f:
        data = json.load(f)
    fixed = 0
    for q in data:
        orig = q.get('question_latex', '')
        if not orig: continue
        match_pats = [r'Match List', r'Match the.*Column', r'Match Column']
        if any(re.search(p, orig, re.IGNORECASE) for p in match_pats): continue
        new_text = unwrap_text(orig)
        if new_text != orig:
            q['question_latex'] = new_text
            fixed += 1
    if fixed > 0:
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
    return fixed

if __name__ == '__main__':
    jee = fix_bank('assets/jee.json')
    neet = fix_bank('assets/neet.json')
    print(f'Unwrapped {jee} JEE + {neet} NEET = {jee + neet} questions')
