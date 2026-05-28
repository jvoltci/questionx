"""Turn a list of classified changes into a pass/fail verdict.

A FAIL-severity change blocks the merge unless its question id is listed in the
overrides allowlist (a deliberate, reviewed acknowledgement). WARN and INFO never
block. Overrides are per-id, so acknowledging one intentional change never
weakens the gate for any other question.
"""

from dataclasses import dataclass, field

from .diff import FAIL, WARN, INFO


@dataclass
class GateResult:
    passed: bool
    blocking: list = field(default_factory=list)
    acknowledged: list = field(default_factory=list)
    warnings: list = field(default_factory=list)
    info: list = field(default_factory=list)


def evaluate(changes, overrides=None):
    """overrides: collection of acknowledged ids (set or {id: reason} dict)."""
    overrides = overrides or set()
    result = GateResult(passed=True)
    for c in changes:
        if c.severity == FAIL:
            if c.id in overrides:
                result.acknowledged.append(c)
            else:
                result.blocking.append(c)
        elif c.severity == WARN:
            result.warnings.append(c)
        else:
            result.info.append(c)
    result.passed = not result.blocking
    return result
