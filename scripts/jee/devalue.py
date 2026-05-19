"""Decoder for SvelteKit `__data.json` (devalue) format.

The endpoint returns: `{"type":"data","nodes":[{"type":"data","data":[v0, v1, ...], "uses":...}, ...]}`

Within `data`:
  - Index 0 is the root value.
  - Each entry is either a primitive (str/num/null/bool) OR a structural value:
      - An object `{key: idx, ...}` whose values are indices into `data`.
      - An array of indices `[idx1, idx2, ...]`.
  - Special negative ints encode primitives: -1 = undefined, -2 = null, -3 = NaN,
    -4 = +Inf, -5 = -Inf, -6 = -0. (Per devalue spec.)
"""
from __future__ import annotations
import json
from typing import Any


def decode(payload: dict) -> list[Any]:
    """Return one decoded value per SSR node in `payload['nodes']`.

    Nodes without `data` (e.g. `{"type":"skip"}`) become None.
    """
    out: list[Any] = []
    for node in payload.get("nodes", []):
        if node.get("type") != "data":
            out.append(None)
            continue
        out.append(_deref(node["data"], 0, {}))
    return out


def _deref(arr: list, idx: int, memo: dict[int, Any]) -> Any:
    if idx == -1:
        return None  # undefined
    if idx == -2:
        return None
    if idx == -3:
        return float("nan")
    if idx == -4:
        return float("inf")
    if idx == -5:
        return float("-inf")
    if idx == -6:
        return -0.0
    if idx in memo:
        return memo[idx]
    v = arr[idx]
    if isinstance(v, (str, int, float, bool)) or v is None:
        return v
    if isinstance(v, list):
        # Array of indices.
        out: list[Any] = []
        memo[idx] = out
        for child in v:
            out.append(_deref(arr, child, memo))
        return out
    if isinstance(v, dict):
        # devalue tags wrapped objects with a leading sentinel string in some cases.
        # Standard SvelteKit shape is `{key: idx, ...}`.
        # Detect tagged forms: {"k":"Date","v":idx}, {"k":"Map","v":idx}, etc.
        # In practice for examside SSR we only encounter plain objects.
        out_obj: dict[str, Any] = {}
        memo[idx] = out_obj
        for k, child_idx in v.items():
            out_obj[k] = _deref(arr, child_idx, memo)
        return out_obj
    raise ValueError(f"unknown devalue entry at {idx}: {v!r}")


if __name__ == "__main__":
    import sys
    payload = json.load(open(sys.argv[1]))
    decoded = decode(payload)
    for i, node in enumerate(decoded):
        print(f"=== node {i} ===")
        if node is None:
            print("(skip)")
            continue
        # Print top-level keys for orientation
        if isinstance(node, dict):
            for k, v in node.items():
                snippet = repr(v)
                if len(snippet) > 120:
                    snippet = snippet[:120] + "..."
                print(f"  {k}: {snippet}")
        else:
            print(repr(node)[:400])
