#!/usr/bin/env python3
"""
fix_data_tables.py — Reformat fragmented data/truth/measurement tables
into clean pipe-separated rows that render properly.

Handles:
  1. Truth tables: A B Y / 0 0 0 / 0 1 1 / ...
  2. Measurement tables: header header / val val / ...
  3. Generic N-column tables where each cell is on a separate line
"""

import json, re


def detect_grid(lines):
    """Try to detect a grid pattern: N consecutive short lines repeating
    with a fixed column count. Returns (n_cols, header_start, data_start, data_end)
    or None if no grid found."""
    
    # Find runs of short non-empty lines (< 30 chars, no math blocks)
    short_runs = []
    current_run = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped and len(stripped) < 30 and not stripped.startswith('$$'):
            current_run.append((i, stripped))
        else:
            if len(current_run) >= 4:
                short_runs.append(current_run)
            current_run = []
    if len(current_run) >= 4:
        short_runs.append(current_run)
    
    if not short_runs:
        return None
    
    # For each run, try column counts 2-6
    best = None
    for run in short_runs:
        items = [s for _, s in run]
        for n_cols in range(2, 7):
            if len(items) % n_cols == 0:
                n_rows = len(items) // n_cols
                if n_rows >= 2:  # at least header + 1 data row
                    best = (n_cols, run[0][0], run)
                    break
        if best:
            break
    
    return best


def reformat_grid_question(text):
    """Try to detect and reformat a grid table in the question text."""
    lines = text.split('\n')
    stripped_lines = [l.strip() for l in lines]
    
    result = detect_grid(stripped_lines)
    if not result:
        return text
    
    n_cols, start_idx, run = result
    items = [s for _, s in run]
    first_idx = run[0][0]
    last_idx = run[-1][0]
    
    # Build table rows
    rows = []
    for r in range(0, len(items), n_cols):
        row = items[r:r + n_cols]
        # For truth tables, merge multi-word headers (e.g. "Object" "Pin" -> "Object Pin")
        rows.append(row)
    
    # Special case: if header cells look like split words, merge them
    # e.g. ["Object", "Pin", "Convex", "Lens", "Convex", "Mirror", "Image", "Pin"]
    # might be 4 headers with 2 words each
    if n_cols >= 4 and all(len(w) <= 10 and w.isalpha() for w in items[:n_cols * 2]):
        n_cols_merged = n_cols // 2
        if len(items) % n_cols_merged == 0 and n_cols >= 4:
            # Try merging pairs
            merged_items = []
            for i in range(0, len(items), 2):
                if i + 1 < len(items):
                    merged_items.append(f"{items[i]} {items[i+1]}")
                else:
                    merged_items.append(items[i])
            
            new_n_cols = n_cols_merged
            if len(merged_items) % new_n_cols == 0:
                rows = []
                for r in range(0, len(merged_items), new_n_cols):
                    rows.append(merged_items[r:r + new_n_cols])
                n_cols = new_n_cols
    
    # Format as pipe-separated table
    table_lines = []
    for row in rows:
        table_lines.append(' | '.join(row))
    
    # Reconstruct: before + table + after
    before = '\n'.join(lines[:first_idx]).strip()
    after = '\n'.join(lines[last_idx + 1:]).strip()
    
    parts = []
    if before:
        parts.append(before)
    parts.append('\n'.join(table_lines))
    if after:
        parts.append(after)
    
    return '\n\n'.join(parts)


def fix_bank(path):
    with open(path) as f:
        data = json.load(f)

    fixed = 0
    for q in data:
        qt = q.get('question_latex', '')
        lines = [l.strip() for l in qt.split('\n') if l.strip()]
        
        # Only try questions that have many short fragmented lines
        if len(lines) < 5:
            continue
        short = sum(1 for l in lines if len(l) < 20 and not l.startswith('$'))
        if short < 5:
            continue
        
        # Skip if already has pipe separators (already fixed)
        if any(' | ' in l for l in lines):
            continue
        
        # Skip match-list questions (handled by fix_match_lists.py)
        match_pats = [r'Match List', r'Match the.*Column', r'Match Column']
        if any(re.search(p, qt, re.IGNORECASE) for p in match_pats):
            continue
        
        result = detect_grid([l.strip() for l in qt.split('\n')])
        if result:
            new_qt = reformat_grid_question(qt)
            if new_qt != qt:
                q['question_latex'] = new_qt
                fixed += 1

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

    return fixed


if __name__ == '__main__':
    # Test on the two reported questions first
    with open('assets/jee.json') as f:
        data = json.load(f)
    
    for q in data:
        if q['id'] in ('JEE_Main_2016_Apr09_S1_Phy_10', 'JEE_Main_2016_Apr09_S1_Phy_14'):
            print(f'=== {q["id"]} ===')
            result = reformat_grid_question(q['question_latex'])
            print(result)
            print()
    
    # Now fix all
    jee = fix_bank('assets/jee.json')
    neet = fix_bank('assets/neet.json')
    print(f'Fixed {jee} JEE + {neet} NEET = {jee + neet} data-table questions')
