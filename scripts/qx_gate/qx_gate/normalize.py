"""Answer-key normalization.

Collapses presentation differences ('1' vs 'A', case, whitespace, ordering) into
a single canonical form so the gate's diff only ever sees *meaning*. A raw value
that is not composed purely of option tokens (e.g. 'NA' or a human note) is
treated as UNRESOLVED (None) rather than cleverly parsed — a later resolution is
a GAIN, never a silent flip.
"""

import re

_NUM2LET = {"1": "A", "2": "B", "3": "C", "4": "D"}
_LETTERS = {"A", "B", "C", "D"}
_SEP = re.compile(r"[\s,;/&]+")


def normalize_answer(raw):
    """Return canonical answer (e.g. 'A' or 'A,C') or None if unresolved."""
    if raw is None:
        return None
    s = str(raw).strip().upper()
    if not s:
        return None

    tokens = []
    for part in _SEP.split(s):
        if not part:
            continue
        if part in _NUM2LET:
            tokens.append(_NUM2LET[part])
        elif part in _LETTERS:
            tokens.append(part)
        elif all(ch in _LETTERS for ch in part):  # 'AC' -> A, C
            tokens.extend(part)
        elif all(ch in _NUM2LET for ch in part):  # '13' -> A, C
            tokens.extend(_NUM2LET[ch] for ch in part)
        else:
            return None  # contains non-option text -> unresolved

    if not tokens:
        return None
    return ",".join(sorted(set(tokens)))
