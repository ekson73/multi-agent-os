"""
Intake-batch eval (WT10 / P3, stories S10/S9) — VERIFY the batch verdicts, don't narrate them.

Checks the golden fixture ``fixtures/intake_verdicts.yaml`` (the machine-readable
SSOT of the batch ``agentic-tool-intake`` dispositions for the agentic-moe-2026
landscape) against falsifiable invariants:

  A1  exactly 26 INCLUDED entries, every verdict in the intake vocabulary
  A2  supply-chain gate REPRODUCED — ``gsd-build/get-shit-done`` ($GSD rug-pull)
      and ``mempalace`` are EXCLUDED+blocked with evidence and a safe successor
      (spec: openspec/specs/maos-hub/spec.md → "Supply-chain gate")
  A3  single-conductor invariant (C1/RULE-011) — every manager listed in
      ``plugin-scripts/governance/lib/conductors.txt`` (the ENFORCEMENT SSOT)
      is present, mirrored by the fixture's ``conductor_class``, and never
      receives a plain INSTALL
  A4  HF2 license gate — license none/null/NOASSERTION never yields INSTALL,
      and INCLUDED entries with such licenses carry explicit conditions
  A5  every EXCLUDED entry is blocked=true with non-empty evidence + rationale
  A6  every evidence ref resolves to an existing repo file (no invented refs)
  A7  ids are unique and every entry carries the required keys

Output is a single JSON object of LOGGED FIELDS (the DoD-gate: every
acceptance is a logged field or golden-fixture invariant, never prose). Run::

    python -m evals.intake_batch_eval               # prints JSON to stdout
    python -m evals.intake_batch_eval --out r.json  # also writes the report

Importable::

    from evals.intake_batch_eval import run_eval
    report = run_eval()
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Set

import yaml

SCHEMA_VERSION = "intake-batch-eval/1.0.0"

_HERE = Path(__file__).resolve().parent
VERDICTS_YAML = _HERE / "fixtures" / "intake_verdicts.yaml"
# repo root = mcp-tools/maos-mcp-hub/evals -> mcp-tools/maos-mcp-hub -> mcp-tools -> <root>
_REPO_ROOT = _HERE.parents[2]
CONDUCTORS_TXT = _REPO_ROOT / "plugin-scripts" / "governance" / "lib" / "conductors.txt"

VERDICT_VOCABULARY = {
    "INSTALL", "ADAPT", "ABSORB", "SUB-AGENT", "ABANDON", "DEFER", "EXCLUDED",
}
REQUIRED_KEYS = {
    "id", "repo", "layer", "role", "set", "license", "flags",
    "verdict", "rationale", "conditions", "evidence",
}
HF2_LICENSES = {"none", "null", "noassertion"}
# verdicts that actually take something on (and therefore need conditions
# when the license is HF2-dirty); ABANDON/EXCLUDED adopt nothing.
ADOPTION_VERDICTS = {"INSTALL", "ADAPT", "ABSORB", "SUB-AGENT", "DEFER"}

# The two supply-chain reproductions the spec names explicitly.
GSD_REPO = "gsd-build/get-shit-done"
GSD_SUCCESSOR_PREFIX = "open-gsd/"
MEMPALACE_ID = "mempalace"
MEMPALACE_SUCCESSOR = "mem0ai/mem0"


def _read_text(path: Path) -> str:
    """Robust read: never crash the eval on encoding noise; fail CLEARLY on I/O."""
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        raise SystemExit(f"intake-batch-eval: cannot read {path}: {exc}") from exc


def load_fixture(path: Path = VERDICTS_YAML) -> Dict[str, Any]:
    return yaml.safe_load(_read_text(path)) or {}


def load_enforcement_conductors(path: Path = CONDUCTORS_TXT) -> Set[str]:
    """Parse the RULE-011 enforcement SSOT (manager names before the '|')."""
    managers: Set[str] = set()
    for line in _read_text(path).splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "|" not in line:
            continue
        managers.add(line.split("|", 1)[0].strip())
    return managers


def run_eval(
    fixture_path: Path = VERDICTS_YAML,
    conductors_path: Path = CONDUCTORS_TXT,
) -> Dict[str, Any]:
    fixture = load_fixture(fixture_path)
    entries: List[Dict[str, Any]] = fixture.get("entries", [])
    violations: List[str] = []

    by_set: Dict[str, List[Dict[str, Any]]] = {}
    for e in entries:
        by_set.setdefault(str(e.get("set")), []).append(e)
    included = by_set.get("INCLUDED", [])
    excluded = by_set.get("EXCLUDED", [])
    bridge = by_set.get("BRIDGE", [])

    # --- A7: schema integrity -------------------------------------------- #
    ids = [str(e.get("id")) for e in entries]
    a7 = len(ids) == len(set(ids))
    if not a7:
        violations.append("A7: duplicate ids in fixture")
    for e in entries:
        missing = REQUIRED_KEYS - set(e)
        if missing:
            a7 = False
            violations.append(f"A7: {e.get('id')} missing keys {sorted(missing)}")

    # --- A1: 26 INCLUDED, vocabulary-clean verdicts ----------------------- #
    a1 = len(included) == 26
    if not a1:
        violations.append(f"A1: expected 26 INCLUDED, got {len(included)}")
    for e in entries:
        if e.get("verdict") not in VERDICT_VOCABULARY:
            a1 = False
            violations.append(f"A1: {e.get('id')} verdict {e.get('verdict')!r} not in vocabulary")

    # --- A2: supply-chain gate reproduced --------------------------------- #
    gsd = next((e for e in excluded if e.get("repo") == GSD_REPO), None)
    mempalace = next((e for e in excluded if e.get("id") == MEMPALACE_ID), None)
    a2 = True
    if gsd is None or not (
        gsd.get("blocked") is True
        and gsd.get("evidence")
        and str(gsd.get("safe_successor", "")).startswith(GSD_SUCCESSOR_PREFIX)
    ):
        a2 = False
        violations.append("A2: gsd-build/get-shit-done EXCLUDED reproduction missing/incomplete")
    if mempalace is None or not (
        mempalace.get("blocked") is True
        and mempalace.get("evidence")
        and mempalace.get("safe_successor") == MEMPALACE_SUCCESSOR
    ):
        a2 = False
        violations.append("A2: mempalace EXCLUDED reproduction missing/incomplete")

    # --- A3: single-conductor invariant (C1/RULE-011) ---------------------- #
    enforcement = load_enforcement_conductors(conductors_path)
    fixture_conductors = set(fixture.get("conductor_class", []))
    a3 = fixture_conductors == enforcement
    if not a3:
        violations.append(
            f"A3: conductor_class drift — fixture {sorted(fixture_conductors)} "
            f"!= enforcement SSOT {sorted(enforcement)}"
        )
    entry_by_id = {str(e.get("id")): e for e in entries}
    for cid in sorted(enforcement):
        entry = entry_by_id.get(cid)
        if entry is None:
            a3 = False
            violations.append(f"A3: conductor {cid} absent from fixture entries")
        elif entry.get("verdict") == "INSTALL":
            a3 = False
            violations.append(f"A3: conductor {cid} has verdict INSTALL (C1 violation)")

    # --- A4: HF2 license gate ---------------------------------------------- #
    a4 = True
    for e in entries:
        lic = str(e.get("license", "")).strip().lower()
        if lic in HF2_LICENSES:
            if e.get("verdict") == "INSTALL":
                a4 = False
                violations.append(f"A4: {e.get('id')} license={lic} but verdict INSTALL (HF2)")
            # conditions are only meaningful on adoption-shaped verdicts —
            # a rejected (ABANDON) or vetoed (EXCLUDED) entry adopts nothing.
            if e.get("verdict") in ADOPTION_VERDICTS and not e.get("conditions"):
                a4 = False
                violations.append(f"A4: {e.get('id')} license={lic} without explicit conditions")

    # --- A5: EXCLUDED completeness ----------------------------------------- #
    a5 = len(excluded) >= 2
    for e in excluded:
        if not (e.get("blocked") is True and e.get("evidence") and e.get("rationale")):
            a5 = False
            violations.append(f"A5: EXCLUDED {e.get('id')} lacks blocked/evidence/rationale")

    # --- A6: evidence refs resolve ------------------------------------------ #
    a6 = True
    for e in entries:
        for ref in e.get("evidence") or []:
            if not (_REPO_ROOT / str(ref)).is_file():
                a6 = False
                violations.append(f"A6: {e.get('id')} evidence not found: {ref}")

    checks = {"A1": a1, "A2": a2, "A3": a3, "A4": a4, "A5": a5, "A6": a6, "A7": a7}
    report: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "fixture": str(fixture_path),
        "fixture_schema": fixture.get("schema_version"),
        "observed": fixture.get("observed"),
        "decided": fixture.get("decided"),
        "revisit": fixture.get("revisit"),
        "counts": {
            "total": len(entries),
            "included": len(included),
            "bridge": len(bridge),
            "excluded": len(excluded),
            "by_verdict": _count_by(entries, "verdict"),
        },
        "conductor_class": sorted(fixture_conductors),
        "checks": checks,
        "violations": violations,
        "verdict": "pass" if all(checks.values()) else "fail",
    }
    return report


def _count_by(entries: List[Dict[str, Any]], key: str) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for e in entries:
        counts[str(e.get(key))] = counts.get(str(e.get(key)), 0) + 1
    return dict(sorted(counts.items()))


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=None, help="also write the JSON report here")
    args = parser.parse_args(argv)

    report = run_eval()
    payload = json.dumps(report, indent=2, ensure_ascii=False)
    print(payload)
    if args.out:
        args.out.write_text(payload + "\n", encoding="utf-8")
    return 0 if report["verdict"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
