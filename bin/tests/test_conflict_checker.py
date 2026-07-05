#!/usr/bin/env python3
"""
test_conflict_checker.py — tests for bin/conflict-checker.py (issue #182).

Covers (per the issue's DoD — every acceptance a checkable field):
  - GOLDEN: the 6 known collisions modelled in conflicts.yaml are reproduced
    (ECC×base · spec-kit×openspec · gstack×ECC-browser-mcp · the
    mem0×letta×cognee triangle).
  - engine cross-confirmation: every collision is `engine_confirmed` by the
    live PolicyResolver (two independent derivations agree).
  - clean stack → verdict clean · exit 0; conflicted → exit 2.
  - determinism: same input → byte-identical JSON.
  - RULE-011 JSON input composes (single-conductor-scan.sh output shape).
  - unknown ids are surfaced, never silently dropped.

Requires PyYAML (the engine's own dependency — see
mcp-tools/maos-mcp-hub/requirements.txt).
Run: python3 bin/tests/test_conflict_checker.py
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_MOD = _HERE.parent / "conflict-checker.py"
_spec = importlib.util.spec_from_file_location("cc", _MOD)
cc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cc)

PASS = 0
FAIL = 0


def check(name: str, cond: bool, detail: str = "") -> None:
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  ✓ {name}")
    else:
        FAIL += 1
        print(f"  ✗ {name}    {detail}")


# ---------------------------------------------------------------------------
# GOLDEN — the 6 known collisions (issue #182 DoD) on the real conflicts.yaml
# ---------------------------------------------------------------------------
GOLDEN_STACK = [
    "ECC", "base", "spec-kit", "openspec",
    "gstack", "ECC-browser-mcp", "mem0", "letta", "cognee",
]
GOLDEN_EDGES = {
    frozenset(p)
    for p in [
        ("ECC", "base"),
        ("spec-kit", "openspec"),
        ("gstack", "ECC-browser-mcp"),
        ("mem0", "letta"),
        ("letta", "cognee"),
        ("mem0", "cognee"),
    ]
}

report = cc.analyze(GOLDEN_STACK, cc._DEFAULT_CONFLICTS)
found = {frozenset((c["a"], c["b"])) for c in report["collisions"]}

check(
    "golden: all 6 known collisions reproduced",
    GOLDEN_EDGES <= found,
    f"missing={ [tuple(e) for e in (GOLDEN_EDGES - found)] }",
)
check("golden: verdict = conflicted", report["verdict"] == "conflicted")
check(
    "golden: every collision engine_confirmed (resolver agrees)",
    all(c["engine_confirmed"] for c in report["collisions"]),
    str([c for c in report["collisions"] if not c["engine_confirmed"]]),
)
check(
    "golden: collisions carry layer + reason (report is human-usable)",
    all(c["layer"] and c["reason"] for c in report["collisions"]),
)
check("golden: schema tag present", report["schema"] == cc.SCHEMA)

# ---------------------------------------------------------------------------
# clean stack
# ---------------------------------------------------------------------------
clean = cc.analyze(["maos", "mem0", "openspec"], cc._DEFAULT_CONFLICTS)
check("clean: no collisions for a compatible trio", clean["collisions"] == [])
check("clean: verdict = clean", clean["verdict"] == "clean")
check(
    "clean: unknown ids surfaced (maos is not an edge endpoint)",
    "maos" in clean["unknown_ids"],
    str(clean["unknown_ids"]),
)

# ---------------------------------------------------------------------------
# determinism — same input → byte-identical JSON (shuffled input order)
# ---------------------------------------------------------------------------
a = json.dumps(cc.analyze(GOLDEN_STACK, cc._DEFAULT_CONFLICTS), sort_keys=True)
b = json.dumps(
    cc.analyze(list(reversed(GOLDEN_STACK)), cc._DEFAULT_CONFLICTS),
    sort_keys=True,
)
check("determinism: order-insensitive, byte-identical JSON", a == b)

# ---------------------------------------------------------------------------
# RULE-011 composition — the single-conductor-scan.sh JSON shape
# ---------------------------------------------------------------------------
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    f.write(
        '{"rule":"RULE-011","event":"c1_conductor_scan",'
        '"detected_conductors":["gstack","superpowers"],'
        '"scope":"user","decision":"taint"}\n'
    )
    rule011_path = f.name
stack_from_scan = cc._parse_rule011(rule011_path)
check(
    "rule011: detected_conductors extracted as the stack",
    stack_from_scan == ["gstack", "superpowers"],
    str(stack_from_scan),
)
r11 = cc.analyze(stack_from_scan, cc._DEFAULT_CONFLICTS)
check(
    "rule011: superpowers × gstack collision detected (L2 edge)",
    frozenset(("superpowers", "gstack"))
    in {frozenset((c["a"], c["b"])) for c in r11["collisions"]},
)

# ---------------------------------------------------------------------------
# CLI surface — exit codes + human render (subprocess, end-to-end)
# ---------------------------------------------------------------------------
py = sys.executable
p = subprocess.run(
    [py, str(_MOD), "--stack", "ECC,base"], capture_output=True, text=True
)
check("cli: conflicted stack exits 2", p.returncode == 2, f"rc={p.returncode}")
check("cli: human report names the pair", "ECC × base" in p.stdout, p.stdout)
check("cli: human report shows verdict", "CONFLICTED" in p.stdout)

p = subprocess.run(
    [py, str(_MOD), "--stack", "mem0,openspec", "--json"],
    capture_output=True,
    text=True,
)
check("cli: clean stack exits 0", p.returncode == 0, f"rc={p.returncode}")
parsed = json.loads(p.stdout)
check("cli: --json is parseable + clean verdict", parsed["verdict"] == "clean")

p = subprocess.run([py, str(_MOD)], capture_output=True, text=True)
check("cli: no input mode → usage error (exit 2 from argparse)", p.returncode != 0)

# ---------------------------------------------------------------------------
print(f"\n{PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)
