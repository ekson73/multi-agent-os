"""
Hub routing-eval (S8) — MEASURE the MoE hub's routing behaviour, don't assume it.

This is the (k) "hub-ROUTING eval (6 task families x risk)" called out in
``protocols/moe-hub-architecture.md`` and ADR-006's gap roadmap. It is
eval-first by design: it runs BEFORE the gap-fill worktrees so the "~70%
coverage" claim is calibrated, not taken on faith.

It exercises the REAL gating-seam shipped in PR #180
(``lib/gateway/policy.py::PolicyResolver``) — never a reimplementation — against
a golden corpus (``fixtures/routing_cases.yaml``) and calibrates the artifact
coverage claim against ``fixtures/artifact_coverage.yaml``.

Output is a single JSON object of LOGGED FIELDS (the DoD-gate: every acceptance
is a logged field or a golden-fixture invariant, never prose). Run::

    python -m evals.routing_eval               # prints JSON to stdout
    python -m evals.routing_eval --out r.json  # also writes the report

Importable::

    from evals.routing_eval import run_eval
    report = run_eval()
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

# The seam under test — the real shipped code, imported (not copied).
from lib.gateway.policy import PolicyResolver, load_conflicts

SCHEMA_VERSION = "routing-eval/1.0.0"

_HERE = Path(__file__).resolve().parent
_GATEWAY = _HERE.parent / "lib" / "gateway"
CONFLICTS_YAML = _GATEWAY / "conflicts.yaml"
CASES_YAML = _HERE / "fixtures" / "routing_cases.yaml"
COVERAGE_YAML = _HERE / "fixtures" / "artifact_coverage.yaml"


# --------------------------------------------------------------------------- #
# Loading
# --------------------------------------------------------------------------- #

def _load_yaml(path: Path) -> Dict[str, Any]:
    return yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}


# --------------------------------------------------------------------------- #
# Block 1 — routing-gating measurement (exercises the real PolicyResolver)
# --------------------------------------------------------------------------- #

def _measure_routing(
    families: List[Dict[str, Any]],
    risk_levels: List[Dict[str, Any]],
    edges: List[Any],
) -> Dict[str, Any]:
    """Feed the golden corpus to the real PolicyResolver and tally outcomes."""
    cases: List[Dict[str, Any]] = []

    coverage_correct = coverage_total = 0
    inj_total = inj_blocked = inj_reason_correct = 0
    off_passthrough = 0
    hitl_required_cases = 0

    for fam in families:
        stack: List[str] = list(fam["stack"])
        inject: str = fam["inject"]
        expect_cw: List[str] = sorted(fam.get("expect_conflict_with", []))

        # --- gating ON: clean stack -> every member must be ALLOWED ----------
        on = PolicyResolver(profile=stack, conflicts=edges)
        stack_allows = {t: bool(on.check(t)) for t in stack}
        stack_all_allowed = all(stack_allows.values())

        # --- gating ON: inject a conflicting tool -> must be DENIED ----------
        on_inj = PolicyResolver(profile=stack + [inject], conflicts=edges)
        inj_dec = on_inj.check(inject)
        inj_blocked_here = not inj_dec.allow
        inj_reason_ok = sorted(inj_dec.conflicting_with) == expect_cw

        # --- gating OFF (policy=None passthrough): inject would SLIP ---------
        off = PolicyResolver()  # empty profile => allow-all passthrough
        off_allows_inject = bool(off.check(inject))

        for rl in risk_levels:
            hitl = bool(rl.get("hitl_required", False))
            if hitl:
                hitl_required_cases += 1

            coverage_total += len(stack)
            coverage_correct += sum(1 for v in stack_allows.values() if v)
            inj_total += 1
            if inj_blocked_here:
                inj_blocked += 1
            if inj_reason_ok:
                inj_reason_correct += 1
            if off_allows_inject:
                off_passthrough += 1

            cases.append({
                "family": fam["id"],
                "quadrant": fam.get("quadrant"),
                "risk": rl["level"],
                "hitl_required": hitl,
                "stack_all_allowed": stack_all_allowed,
                "injection": inject,
                "injection_blocked": inj_blocked_here,
                "injection_reason_correct": inj_reason_ok,
                "conflict_named": sorted(inj_dec.conflicting_with),
                "gating_off_passthrough": off_allows_inject,
            })

    def _rate(n: int, d: int) -> float:
        return round(n / d, 4) if d else 0.0

    return {
        "coverage_allow": {
            "correct": coverage_correct,
            "total": coverage_total,
            "rate": _rate(coverage_correct, coverage_total),
        },
        "injection": {
            "total": inj_total,
            "blocked": inj_blocked,
            "blocked_rate": _rate(inj_blocked, inj_total),
            "reason_correct": inj_reason_correct,
            "reason_correct_rate": _rate(inj_reason_correct, inj_total),
        },
        "gating_off": {
            # Each off-passthrough is an unsafe co-activation the seam prevents.
            "unsafe_passthrough": off_passthrough,
            "prevented_by_seam": inj_blocked,
        },
        # Honest: the seam is profile-based and risk-AGNOSTIC. Risk gating is
        # WT4/S2; the eval records the as-designed HITL expectation + the gap.
        "risk_gating_enforced": False,
        "hitl_required_cases": hitl_required_cases,
        "cases": cases,
    }


# --------------------------------------------------------------------------- #
# Block 2 — architecture coverage (calibrate the "~70%" claim)
# --------------------------------------------------------------------------- #

def _measure_coverage(cov: Dict[str, Any]) -> Dict[str, Any]:
    artifacts: List[Dict[str, Any]] = cov.get("artifacts", [])
    n = len(artifacts)
    claim = float(cov.get("claim", {}).get("asserted", 0.70))

    def _is_built(a: Dict[str, Any]) -> bool:
        return a["status"] == "BUILT"

    def _non_gap(a: Dict[str, Any]) -> bool:
        return a["status"] != "GAP"

    strict = sum(1 for a in artifacts if _is_built(a))
    lenient = sum(1 for a in artifacts if _non_gap(a))
    weighted = sum(float(a.get("weight", 0.0)) for a in artifacts)

    by_status: Dict[str, int] = {}
    for a in artifacts:
        by_status[a["status"]] = by_status.get(a["status"], 0) + 1

    def _score(num: float) -> float:
        return round(num / n, 4) if n else 0.0

    def _verdict(score: float) -> str:
        if score >= claim + 0.05:
            return "ABOVE_CLAIM"
        if score <= claim - 0.05:
            return "BELOW_CLAIM (claim OPTIMISTIC)"
        return "CONFIRMS_CLAIM (within +-5pp)"

    rules = {
        "strict":   {"score": _score(strict),   "verdict_vs_claim": _verdict(_score(strict))},
        "weighted": {"score": _score(weighted), "verdict_vs_claim": _verdict(_score(weighted))},
        "lenient":  {"score": _score(lenient),  "verdict_vs_claim": _verdict(_score(lenient))},
    }
    return {
        "n": n,
        "claim_asserted": claim,
        "by_status": by_status,
        "rules": rules,
        "note": (
            "The ~70% claim is sensitive to how PARTIAL is counted: "
            f"strict={rules['strict']['score']} "
            f"weighted={rules['weighted']['score']} "
            f"lenient={rules['lenient']['score']}."
        ),
    }


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #

def run_eval(
    cases_path: Optional[Path] = None,
    coverage_path: Optional[Path] = None,
    conflicts_path: Optional[Path] = None,
) -> Dict[str, Any]:
    """Run the full routing-eval and return the report as a dict (logged fields)."""
    cases_doc = _load_yaml(cases_path or CASES_YAML)
    coverage_doc = _load_yaml(coverage_path or COVERAGE_YAML)
    edges = load_conflicts(conflicts_path or CONFLICTS_YAML)

    families: List[Dict[str, Any]] = cases_doc.get("families", [])
    risk_levels: List[Dict[str, Any]] = cases_doc.get("risk_levels", [])

    routing = _measure_routing(families, risk_levels, edges)
    coverage = _measure_coverage(coverage_doc)

    # --- top-level verdict (all derived from logged fields above) ----------
    # Compare EXACT integer counts, not the rounded rates: "all blocked / all
    # correct" must mean blocked == total and reason_correct == total, never a
    # rate that rounded UP to 1.0. (For integer counts round(n/d, 4) == 1.0
    # already implies n == d, but asserting on the counts makes it rounding-proof.)
    inj = routing["injection"]
    seam_teeth_real = (
        inj["blocked"] == inj["total"]
        and inj["reason_correct"] == inj["total"]
    )
    weighted_score = coverage["rules"]["weighted"]["score"]
    claim = coverage["claim_asserted"]
    # WT0's gating question: "if it measures high, half the plan falls." This is
    # an EXACT gate (weighted >= claim) on purpose — deliberately stricter than
    # the ±5pp tolerance band that produces the human-readable `claim_70pct`
    # verdict (BELOW/CONFIRMS/ABOVE). The two may differ near the boundary by
    # design: this boolean decides whether the gap-fill waves stay justified;
    # the band only narrates how close the weighted measurement is to the claim.
    half_the_plan_falls = bool(seam_teeth_real and weighted_score >= claim)

    return {
        "meta": {
            "schema_version": SCHEMA_VERSION,
            "families": len(families),
            "risk_levels": len(risk_levels),
            "cases_total": len(routing["cases"]),
            "conflicts_edge_count": len(edges),
            "seam_under_test": "lib/gateway/policy.py::PolicyResolver (PR #180)",
        },
        "routing_gating": routing,
        "architecture_coverage": coverage,
        "verdict": {
            "seam_teeth_real": seam_teeth_real,
            "weighted_coverage": weighted_score,
            "claim_asserted": claim,
            "claim_70pct": coverage["rules"]["weighted"]["verdict_vs_claim"],
            "half_the_plan_falls": half_the_plan_falls,
        },
    }


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="MAOS hub routing-eval (S8).")
    parser.add_argument("--out", type=Path, default=None,
                        help="also write the JSON report to this path")
    parser.add_argument("--quiet", action="store_true",
                        help="suppress stdout (only write --out)")
    args = parser.parse_args(argv)

    report = run_eval()
    text = json.dumps(report, indent=2, ensure_ascii=False)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
    if not args.quiet:
        print(text)
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
