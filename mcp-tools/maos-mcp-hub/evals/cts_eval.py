"""
CTS scorer eval (WT4 / S2) — MEASURE the unified scorer, don't assume it.

Exercises the REAL ``lib/gateway/cts.py::CtsScorer`` (never a reimplementation)
against the golden corpus ``fixtures/cts_cases.yaml``, composing the REAL
``PolicyResolver`` (PR #180 seam) for the policy turn and the REAL ``IsoGate``
(WT3, PR #197) for the end-to-end seam check.

Output is a single JSON object of LOGGED FIELDS (the DoD-gate: every
acceptance is a logged field or golden-fixture invariant, never prose). Run::

    python -m evals.cts_eval               # prints JSON to stdout
    python -m evals.cts_eval --out r.json  # also writes the report

Importable::

    from evals.cts_eval import run_eval
    report = run_eval()
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

from lib.gateway.cts import (
    CTS_WEIGHTS,
    CtsScorer,
    CtsTurn,
    RiskClass,
    candidates_from_fixture,
)
from lib.gateway.iso import IsoGate
from lib.gateway.policy import PolicyResolver, load_conflicts

SCHEMA_VERSION = "cts-eval/1.0.0"

_HERE = Path(__file__).resolve().parent
_GATEWAY = _HERE.parent / "lib" / "gateway"
CONFLICTS_YAML = _GATEWAY / "conflicts.yaml"
CASES_YAML = _HERE / "fixtures" / "cts_cases.yaml"


def _load_yaml(path: Path) -> Dict[str, Any]:
    return yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}


def _check_expectations(
    expect: Dict[str, Any], report: Dict[str, Any]
) -> Dict[str, bool]:
    """Evaluate a turn's fixture expectations against its logged report."""
    results: Dict[str, bool] = {}
    ranked_ids = [r["tool_id"] for r in report["ranked"]]
    eliminated = {e["tool_id"]: e for e in report["eliminated"]}
    for key, want in (expect or {}).items():
        if key == "top1":
            results[key] = bool(ranked_ids) and ranked_ids[0] == want
        elif key == "ranked_contains":
            results[key] = set(want).issubset(set(ranked_ids))
        elif key == "eliminated_contains":
            results[key] = all(
                item["tool_id"] in eliminated
                and eliminated[item["tool_id"]]["filter"] == item["filter"]
                for item in want
            )
        elif key == "ruflo_hitl_eligible":
            results[key] = (
                eliminated.get("ruflo", {}).get("hitl_eligible", False) == want
            )
        elif key == "eliminated_never_ranked":
            results[key] = report["invariants"]["eliminated_never_ranked"] == want
        else:
            results[key] = False  # unknown expectation key fails loudly
    return results


def run_eval(
    cases_path: Path = CASES_YAML,
    conflicts_path: Path = CONFLICTS_YAML,
) -> Dict[str, Any]:
    """Run the full CTS eval and return the report as a dict (logged fields)."""
    fixture = _load_yaml(cases_path)
    candidates = candidates_from_fixture(fixture["candidates"])
    edges = load_conflicts(conflicts_path)

    turns_report: List[Dict[str, Any]] = []
    all_expectations_pass = True

    for turn_spec in fixture.get("turns", []):
        profile = turn_spec.get("profile")
        policy: Optional[PolicyResolver] = (
            PolicyResolver(profile=profile, conflicts=edges) if profile else None
        )
        scorer = CtsScorer(policy=policy)
        turn = CtsTurn(
            granted_scopes=frozenset(turn_spec.get("granted_scopes", [])),
            allowed_data_classes=frozenset(
                turn_spec.get("allowed_data_classes", [])
            ),
            max_risk=RiskClass[turn_spec.get("max_risk", "HIGH")],
        )
        ranking = scorer.rank(candidates, turn)
        report = ranking.to_report()
        checks = _check_expectations(turn_spec.get("expect", {}), report)
        all_expectations_pass = all_expectations_pass and all(checks.values())
        turns_report.append(
            {"name": turn_spec["name"], "report": report, "expectations": checks}
        )

    # -- the WT3<->WT4 seam: the ranking IS IsoGate's ranked input -----------
    scorer = CtsScorer()
    clean_turn = next(
        (t for t in fixture["turns"] if t["name"] == "spec-task-clean"), None
    )
    if clean_turn is None:
        raise ValueError("required 'spec-task-clean' turn missing from fixture")
    ranking = scorer.rank(
        candidates,
        CtsTurn(
            granted_scopes=frozenset(clean_turn["granted_scopes"]),
            max_risk=RiskClass[clean_turn["max_risk"]],
        ),
    )
    gate, _ = IsoGate.from_inventory(
        [
            {"id": c.tool_id, "summary": f"{c.tool_id} expert", "schema": c.schema}
            for c in candidates
        ]
    )
    selection = gate.select(ranking.ranked_ids(), k=3)
    seam = {
        "cts_rank": ranking.ranked_ids(),
        "iso_promoted": selection.promoted,
        "promoted_is_rank_prefix": selection.promoted
        == ranking.ranked_ids()[: len(selection.promoted)],
    }

    verdict = {
        "weights_sum_to_1": abs(sum(CTS_WEIGHTS.values()) - 1.0) < 1e-9,
        "all_turn_expectations_pass": all_expectations_pass,
        "hard_filters_precede_scoring": all(
            t["report"]["invariants"]["eliminated_never_ranked"]
            and t["report"]["invariants"]["every_elimination_reasoned"]
            for t in turns_report
        ),
        "iso_seam_composes": seam["promoted_is_rank_prefix"],
    }

    return {
        "schema_version": SCHEMA_VERSION,
        "weights": dict(CTS_WEIGHTS),
        "turns": turns_report,
        "iso_seam": seam,
        "verdict": verdict,
    }


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=None, help="also write JSON here")
    args = parser.parse_args(argv)

    report = run_eval()
    text = json.dumps(report, indent=2, ensure_ascii=False)
    print(text)
    if args.out:
        args.out.write_text(text + "\n", encoding="utf-8")

    return 0 if all(report["verdict"].values()) else 1


if __name__ == "__main__":
    sys.exit(main())
