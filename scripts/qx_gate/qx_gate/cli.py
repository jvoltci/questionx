"""qx-gate command line.

    qx-gate check   --baseline <ref|file> [--current <file>] [--path P] [--overrides F] [--json]
    qx-gate history [--path P]            # scan every commit that touched the bundle

`--baseline` is loaded as a file if it exists on disk, otherwise treated as a git
ref and read via `git show <ref>:<path>`. Exit code: 0 = clean or fully
acknowledged, 1 = a real regression blocks the merge.
"""

import argparse
import json
import os
import subprocess

from .diff import snapshot, diff_snapshots, FAIL
from .gate import evaluate

DEFAULT_PATH = "assets/neet.json"


def _load_bundle_text(text):
    data = json.loads(text)
    if isinstance(data, dict):  # tolerate {"questions": [...]} wrappers
        for v in data.values():
            if isinstance(v, list):
                return v
        return []
    return data


def resolve_source(source, path, repo="."):
    """Load a bundle from a file path, or from a git ref via `git show ref:path`."""
    if os.path.isfile(source):
        with open(source, encoding="utf-8") as f:
            return _load_bundle_text(f.read())
    out = subprocess.check_output(["git", "-C", repo, "show", f"{source}:{path}"], text=True)
    return _load_bundle_text(out)


def load_overrides(path):
    if not path or not os.path.isfile(path):
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, dict) else {k: "" for k in data}


def run_check(baseline, current, path=DEFAULT_PATH, overrides_path=None, repo="."):
    old = resolve_source(baseline, path, repo)
    cur_source = current or os.path.join(repo, path)
    new = resolve_source(cur_source, path, repo)
    changes = diff_snapshots(snapshot(old), snapshot(new))
    return evaluate(changes, load_overrides(overrides_path))


def format_report(result):
    lines = [f"qx-gate: {'PASS' if result.passed else 'FAIL'}"]
    lines.append(
        f"  blocking {len(result.blocking)} | acknowledged {len(result.acknowledged)} | "
        f"warnings {len(result.warnings)} | info {len(result.info)}"
    )
    if result.blocking:
        lines.append("  --- BLOCKING (real regressions, must fix or override) ---")
        for c in result.blocking:
            arrow = f"  {c.old!r} -> {c.new!r}" if c.old is not None or c.new is not None else ""
            lines.append(f"    [{c.kind}] {c.id}{arrow}")
    if result.acknowledged:
        lines.append("  --- acknowledged (in overrides allowlist) ---")
        for c in result.acknowledged:
            lines.append(f"    [{c.kind}] {c.id}")
    if result.warnings:
        lines.append(f"  --- warnings ({len(result.warnings)}) ---")
        for c in result.warnings[:20]:
            lines.append(f"    [{c.kind}] {c.id}")
        if len(result.warnings) > 20:
            lines.append(f"    ... and {len(result.warnings) - 20} more")
    return "\n".join(lines)


def _result_to_dict(result):
    def rows(cs):
        return [{"id": c.id, "kind": c.kind, "old": c.old, "new": c.new} for c in cs]

    return {
        "passed": result.passed,
        "blocking": rows(result.blocking),
        "acknowledged": rows(result.acknowledged),
        "warnings": rows(result.warnings),
        "info_count": len(result.info),
    }


def _commits_touching(path, repo="."):
    out = subprocess.check_output(
        ["git", "-C", repo, "log", "--reverse", "--format=%h\t%s", "--", path], text=True
    )
    return [line.split("\t", 1) for line in out.strip().splitlines() if line]


def cmd_history(path=DEFAULT_PATH, repo="."):
    commits = _commits_touching(path, repo)
    print(f"qx-gate history: scanning {len(commits)} commits that touched {path}\n")
    prev = prev_label = None
    total_blocking = 0
    for sha, subj in commits:
        bundle = resolve_source(sha, path, repo)
        snap = snapshot(bundle)
        if prev is not None:
            result = evaluate(diff_snapshots(prev, snap))
            n = len(result.blocking)
            total_blocking += n
            flag = "  <-- REGRESSIONS" if n else ""
            print(f"{prev_label[:32]:32}  ->  {sha} {subj[:34]:34}  blocking={n}{flag}")
            for c in result.blocking[:8]:
                arrow = f"  {c.old!r} -> {c.new!r}" if (c.old or c.new) else ""
                print(f"        [{c.kind}] {c.id}{arrow}")
        prev, prev_label = snap, f"{sha} {subj}"
    print(f"\nTotal blocking regressions found across history: {total_blocking}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="qx-gate", description="questionx content-regression gate")
    sub = parser.add_subparsers(dest="cmd", required=True)

    pc = sub.add_parser("check", help="gate current content against a baseline")
    pc.add_argument("--baseline", required=True, help="git ref or file to compare against")
    pc.add_argument("--current", default=None, help="file to check (default: --path on disk)")
    pc.add_argument("--path", default=DEFAULT_PATH)
    pc.add_argument("--overrides", default=None)
    pc.add_argument("--repo", default=".")
    pc.add_argument("--json", action="store_true")

    ph = sub.add_parser("history", help="scan every commit that touched the bundle")
    ph.add_argument("--path", default=DEFAULT_PATH)
    ph.add_argument("--repo", default=".")

    args = parser.parse_args(argv)

    if args.cmd == "history":
        return cmd_history(args.path, args.repo)

    result = run_check(args.baseline, args.current, args.path, args.overrides, args.repo)
    if args.json:
        print(json.dumps(_result_to_dict(result), indent=2))
    else:
        print(format_report(result))
    return 0 if result.passed else 1
