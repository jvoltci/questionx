# qx-gate — content-regression gate for questionx

A tiny, **zero-dependency** (stdlib-only Python) gate that protects the one thing
that makes questionx defensible: **trusted content.** On every change to
`assets/neet.json` it asserts that no human-verified answer key silently flipped
and no question's diagram was silently dropped — turning *"did this commit break
a verified question?"* from an after-ship user bug report into a pre-merge red ✗
with the exact list of questions that changed.

It is **semantic**, not a text diff. It normalizes away presentation noise
(the historical `1 → A` answer-format rewrite, case, ordering) so it only ever
fires on a change in *meaning*.

## Why it exists

Running it across questionx's own git history (`qx-gate history`) found, in a
single commit (`9adc5ee "diagrams + pdf rendering"`):

- **257 diagrams silently dropped** from questions that still existed, and
- a handful of **genuine answer-key flips** (`C→D`, `B→C`, …),

all buried under a **2,095-question benign `1→A` format migration** that made the
raw JSON diff impossible to review by eye. qx-gate stays silent on the 2,095
format changes and on the later intentional 1,200-question trust-trim, and blocks
only on the real regressions.

## Severity model

| Severity | Kinds | Behavior |
|----------|-------|----------|
| **FAIL** (blocks) | `ANSWER_FLIPPED`, `ANSWER_LOST`, `DIAGRAM_DROPPED` | Blocks the merge/commit unless the id is in the overrides allowlist |
| **WARN** | `DIAGRAM_CHANGED`, `SOLUTION_DRIFT`, `REMOVED_ID` | Shown, never blocks (removals are usually intentional trims) |
| **INFO** | `ANSWER_GAINED`, `DIAGRAM_ADDED`, `ADDED_ID` | Shown, never blocks (improvements) |

## Usage

Run from this directory (`scripts/qx_gate`), pointing `--repo` at the repo root:

```bash
# Gate the working tree against the last commit
python3 -m qx_gate check --baseline HEAD --repo ../.. --path assets/neet.json

# Gate a PR against its base branch (what CI does)
python3 -m qx_gate check --baseline origin/main --repo ../.. --path assets/neet.json

# Scan the whole history and report every regression (the dogfood demo)
python3 -m qx_gate history --repo ../.. --path assets/neet.json

# Machine-readable output
python3 -m qx_gate check --baseline HEAD --repo ../.. --json
```

Exit code: **0** = clean or fully acknowledged, **1** = a real regression blocks.

## Acknowledging an intentional change

When a FAIL is a deliberate, reviewed correction, add the question id to
`qx_gate_overrides.json` (copy from `qx_gate_overrides.example.json`) with a
reason. Overrides are per-id, so acknowledging one never weakens the gate for any
other question — the reason string is your audit trail.

## Install the pre-commit hook

```bash
sh scripts/qx_gate/install-hook.sh
```

## CI

`.github/workflows/qx-gate.yml` runs the gate on every PR that touches
`assets/neet.json`, comparing against the base branch.

## Tests

```bash
cd scripts/qx_gate && python3 -m unittest discover -s tests -t .
```

33 tests, no third-party dependencies.

## What's deliberately out of scope (v0)

- Scoring against the frozen 500-Q holdout / any model — this gate checks content
  *integrity* (did a verified field change), not content *correctness*.
- A Cloudflare Workers shared run-cache.
- Staged-content checking in the hook (v0 checks the working tree vs HEAD).
