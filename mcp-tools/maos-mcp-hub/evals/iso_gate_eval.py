"""
ISO gating eval (WT3 / S3) — MEASURE the universal ISO layer, don't assume it.

Exercises the REAL ``lib/gateway/iso.py::IsoGate`` (never a reimplementation)
against the golden inventory ``fixtures/iso_inventory.yaml``, composing the
REAL ``lib/gateway/policy.py::PolicyResolver`` (PR #180 seam) for the
policy-gated and injection turns.

Output is a single JSON object of LOGGED FIELDS (the DoD-gate: every
acceptance is a logged field or golden-fixture invariant, never prose). Run::

    python -m evals.iso_gate_eval               # prints JSON to stdout
    python -m evals.iso_gate_eval --out r.json  # also writes the report

Importable::

    from evals.iso_gate_eval import run_eval
    report = run_eval()
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

from lib.gateway.iso import ISO_SUMMARY_TOKEN_LIMIT, IsoGate, iso_tokens
from lib.gateway.policy import PolicyResolver, load_conflicts

SCHEMA_VERSION = "iso-gate-eval/1.0.0"

_HERE = Path(__file__).resolve().parent
_GATEWAY = _HERE.parent / "lib" / "gateway"
CONFLICTS_YAML = _GATEWAY / "conflicts.yaml"
INVENTORY_YAML = _HERE / "fixtures" / "iso_inventory.yaml"


def _load_yaml(path: Path) -> Dict[str, Any]:
    return yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}


def _check_expectations(
    expect: Dict[str, Any], report: Dict[str, Any]
) -> Dict[str, bool]:
    """Evaluate a turn's fixture expectations against its logged report."""
    results: Dict[str, bool] = {}
    denied_ids = {d["tool_id"] for d in report["denied"]}
    for key, want in (expect or {}).items():
        if key == "k_effective":
            results[key] = report["k_effective"] == want
        elif key == "denied_count":
            results[key] = len(report["denied"]) == want
        elif key == "summarized_count":
            results[key] = len(report["summarized"]) == want
        elif key == "k_effective_lt_requested":
            results[key] = (report["k_effective"] < report["k_requested"]) == want
        elif key == "budget_respected":
            results[key] = report["invariants"]["budget_respected"] == want
        elif key == "denied_contains":
            results[key] = set(want).issubset(denied_ids)
        elif key == "denied_never_promoted":
            results[key] = report["invariants"]["denied_never_promoted"] == want
        elif key == "conflict_reason_names_peer":
            # every conflict-denied entry names its actual peer(s)
            conflict_entries = [d for d in report["denied"] if d["conflicting_with"]]
            results[key] = (
                bool(conflict_entries)
                and all(d["conflicting_with"] for d in conflict_entries)
            ) == want
        else:
            results[key] = False  # unknown expectation key fails loudly
    return results


def run_eval(
    inventory_path: Path = INVENTORY_YAML,
    conflicts_path: Path = CONFLICTS_YAML,
) -> Dict[str, Any]:
    """Run the full ISO-gate eval and return the report as a dict (logged fields)."""
    fixture = _load_yaml(inventory_path)
    inventory: List[Dict[str, Any]] = fixture["inventory"]
    edges = load_conflicts(conflicts_path)

    # Pool-level invariants (the spec's "<=60 tokens/tool" acceptance).
    pool_tokens = {item["id"]: iso_tokens(item.get("summary", "")) for item in inventory}
    summaries_within_limit = all(
        t <= ISO_SUMMARY_TOKEN_LIMIT for t in pool_tokens.values()
    )

    turns_report: List[Dict[str, Any]] = []
    all_expectations_pass = True

    for turn in fixture.get("turns", []):
        profile = turn.get("profile")
        policy: Optional[PolicyResolver] = (
            PolicyResolver(profile=profile, conflicts=edges) if profile else None
        )
        gate, _ = IsoGate.from_inventory(inventory, policy=policy)
        selection = gate.select(
            turn["ranked"],
            k=turn.get("k"),
            schema_token_budget=turn.get("schema_token_budget"),
        )
        report = selection.to_report()
        checks = _check_expectations(turn.get("expect", {}), report)
        all_expectations_pass = all_expectations_pass and all(checks.values())
        turns_report.append(
            {
                "name": turn["name"],
                "profile_size": len(profile) if profile else 0,
                "report": report,
                "expectations": checks,
            }
        )

    verdict = {
        # the spec scenario: rest of the inventory stays <=60-token summaries
        "summaries_within_limit": summaries_within_limit,
        "pool_size": len(inventory),
        "pool_tokens_max": max(pool_tokens.values(), default=0),
        # every turn honored its golden expectations
        "all_turn_expectations_pass": all_expectations_pass,
        # promotion is bounded on every turn (never the whole inventory)
        "promotion_always_bounded": all(
            t["report"]["k_effective"] <= t["report"]["k_requested"]
            and t["report"]["k_effective"] < t["report"]["pool_size"]
            for t in turns_report
        ),
    }

    return {
        "schema_version": SCHEMA_VERSION,
        "tokenizer": "ceil(len/4)",
        "summary_token_limit": ISO_SUMMARY_TOKEN_LIMIT,
        "turns": turns_report,
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

    ok = (
        report["verdict"]["summaries_within_limit"]
        and report["verdict"]["all_turn_expectations_pass"]
        and report["verdict"]["promotion_always_bounded"]
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
