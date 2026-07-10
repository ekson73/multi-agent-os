"""Intake gatekeeper — WAVE 6 T8 core (deterministic-floor triage).

Narrowed scope per ``openspec/changes/maos-hub-console/tasks.md`` (WAVE 6
ordering note): this module is the **deterministic-floor + triage core** for
inbound candidate tools (the intake of tools WE absorb). The per-PR ceremony
(auto-ADR/changelog emission for inbound community PRs, sandbox execution,
payload scanning) stays DEFERRED until inbound PRs exist.

Floor gates — all deterministic, composing EXISTING SSOTs (no re-derivation):

  F1 known-verdict        ``evals/fixtures/intake_verdicts.yaml`` (WT10):
                          a candidate matching an EXCLUDED record is blocked
                          with the record's evidence + safe successor; a
                          candidate matching any other dispositioned record is
                          routed to that record (re-intake is an HITL matter).
  F2 flag-veto            ``hub_registry._COMPROMISED_FLAGS`` (T9): a
                          compromised-class flag blocks outright; an
                          abandoned-class flag becomes a floor WARNING
                          (abandoned is not malicious — HITL decides).
  F3 conductor-isolation  ``plugin-scripts/governance/lib/conductors.txt``
                          (RULE-011 single-conductor): a conductor-class
                          candidate can NEVER be plain-install eligible —
                          only isolated routes (SUB-AGENT / ADAPT) reach HITL.

Never-auto-accept is STRUCTURAL: ``ALLOWED_VERDICTS`` has no "accepted"
member. The strongest positive outcome is ``hitl-required`` (advisory triage;
a human decides). Reject-by-default: a malformed/empty candidate is blocked
fail-closed. The triage report is byte-stable for identical inputs
(console-determinism contract).
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml

from .hub_registry import _ABANDONED_FLAGS, _COMPROMISED_FLAGS

GATEKEEPER_SCHEMA_VERSION = "intake-gatekeeper/1.0.0"

#: The closed triage vocabulary. Deliberately NO "accepted"/"install" member —
#: acceptance is exclusively a human act (mandatory HITL per the T8 spec line
#: "reject-by-default; never as-is").
ALLOWED_VERDICTS = frozenset(
    {"blocked", "isolation-required", "already-dispositioned", "hitl-required"}
)

_FIXTURE_REL = Path("mcp-tools/maos-mcp-hub/evals/fixtures/intake_verdicts.yaml")
_CONDUCTORS_REL = Path("plugin-scripts/governance/lib/conductors.txt")


@dataclass(frozen=True)
class Candidate:
    """An inbound tool candidate — a descriptor, never a payload (T8-core)."""

    id: str
    repo: str  # owner/name
    flags: Tuple[str, ...] = field(default_factory=tuple)
    layer: str = ""


def _load_conductor_names(path: Path) -> frozenset:
    """Manager names from conductors.txt (`<manager>|<signature-path>` lines)."""
    names = set()
    if not path.is_file():
        return frozenset()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "|" not in line:
            continue
        names.add(line.split("|", 1)[0].strip())
    return frozenset(names)


class IntakeGatekeeper:
    """Deterministic triage of a :class:`Candidate` on the floor SSOTs."""

    def __init__(self, repo_root: Path) -> None:
        self.repo_root = Path(repo_root)
        self._by_id: Dict[str, Dict[str, Any]] = {}
        self._by_repo: Dict[str, Dict[str, Any]] = {}
        fixture = self.repo_root / _FIXTURE_REL
        if fixture.is_file():
            data = yaml.safe_load(fixture.read_text(encoding="utf-8")) or {}
            for entry in data.get("entries", []) or []:
                if entry.get("id"):
                    self._by_id[str(entry["id"])] = entry
                if entry.get("repo"):
                    self._by_repo[str(entry["repo"])] = entry
        self._conductors = _load_conductor_names(self.repo_root / _CONDUCTORS_REL)

    # -- triage ------------------------------------------------------------

    def triage(self, candidate: Candidate) -> Dict[str, Any]:
        """Return the triage report. Deterministic; never raises on content."""
        # Normalize at the boundary (Copilot, fix-PDCA): the floor gates match
        # EXACT strings — an unstripped " gsd-build/get-shit-done " would dodge
        # the F1 EXCLUDED veto and reach HITL labeled "floor-clean" (an evasion
        # vector). All downstream lookups use the normalized values.
        cand_id = candidate.id.strip()
        repo = candidate.repo.strip()
        report: Dict[str, Any] = {
            "schema": GATEKEEPER_SCHEMA_VERSION,
            "candidate_id": cand_id,
            "candidate_repo": repo,
            "verdict": "",
            "hitl_required": False,
            "reasons": [],
            "warnings": [],
            "evidence": [],
            "safe_successor": None,
            "isolation_required": False,
        }

        # Reject-by-default: a descriptor we cannot even identify is vetoed
        # (fail-closed), never waved through to HITL as an anonymous blob.
        if not cand_id or not repo:
            report["verdict"] = "blocked"
            report["reasons"].append(
                "malformed-candidate (id and repo are both required)"
            )
            return report

        # Shape check (fail-closed): repo is documented as owner/name — a
        # value that cannot even name an upstream never reaches HITL as
        # "floor-clean" (Copilot, fix-PDCA).
        owner, sep, name = repo.partition("/")
        if not sep or not owner or not name or "/" in name:
            report["verdict"] = "blocked"
            report["reasons"].append(
                f"malformed-repo (expected owner/name, got: {repo!r})"
            )
            return report

        flag_set = {f.strip() for f in candidate.flags if f.strip()}
        record = self._by_repo.get(repo) or self._by_id.get(cand_id)
        conductor = cand_id in self._conductors
        report["isolation_required"] = conductor

        # F1a — known EXCLUDED record: the floor veto, terminal.
        if record is not None and (
            record.get("set") == "EXCLUDED" or record.get("blocked") is True
        ):
            report["verdict"] = "blocked"
            report["reasons"].append(
                f"known-excluded (intake verdict {record.get('verdict', 'EXCLUDED')})"
            )
            report["evidence"] = list(record.get("evidence", []) or [])
            report["safe_successor"] = record.get("safe_successor")
            return report

        # F2 — compromised-class flag on the candidate itself: veto.
        compromised = sorted(flag_set & _COMPROMISED_FLAGS)
        if compromised:
            report["verdict"] = "blocked"
            report["reasons"].append(f"flag-veto (compromised: {compromised})")
            return report

        # Abandoned-class flags: not malicious — surface as floor warnings.
        abandoned = sorted(flag_set & _ABANDONED_FLAGS)
        if abandoned:
            report["warnings"].append(f"upstream-health (abandoned: {abandoned})")

        # F3 overlay note — a conductor never gets a plain-install route.
        if conductor:
            report["warnings"].append(
                "conductor-class (RULE-011): plain INSTALL is not eligible; "
                "only isolated routes (SUB-AGENT / ADAPT) may be proposed"
            )

        # F1b — already dispositioned by the WT10 batch: route to the record.
        if record is not None:
            report["verdict"] = "already-dispositioned"
            report["hitl_required"] = True
            report["reasons"].append(
                f"existing intake verdict: {record.get('verdict', '?')} "
                f"(set={record.get('set', '?')}); re-intake is an HITL decision"
            )
            report["evidence"] = list(record.get("evidence", []) or [])
            return report

        # F3 — unknown conductor-class candidate: isolation route only.
        if conductor:
            report["verdict"] = "isolation-required"
            report["hitl_required"] = True
            report["reasons"].append(
                "single-conductor invariant (RULE-011): route in isolation only"
            )
            return report

        # Default: the floor found no veto — a HUMAN decides. Never accepted.
        report["verdict"] = "hitl-required"
        report["hitl_required"] = True
        report["reasons"].append(
            "floor-clean: no supply-chain veto; adoption requires HITL "
            "(reject-by-default — the gatekeeper never auto-accepts)"
        )
        return report


# -- CLI --------------------------------------------------------------------


def _main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m lib.registry.gatekeeper",
        description="Deterministic intake triage on the floor SSOTs (T8-core).",
    )
    parser.add_argument("--repo-root", default=None, help="repo root (default: auto)")
    parser.add_argument("--candidate-id", required=True)
    parser.add_argument("--repo", required=True, help="candidate owner/name")
    parser.add_argument("--flags", default="", help="comma-separated intake flags")
    args = parser.parse_args(argv)

    if args.repo_root:
        repo_root = Path(args.repo_root)
    else:
        repo_root = Path(__file__).resolve().parents[4]
    if not (repo_root / _FIXTURE_REL).is_file():
        print(
            json.dumps(
                {
                    "verdict": "fail",
                    "error": f"intake fixture not found under repo root: {repo_root}",
                }
            )
        )
        return 1

    flags = tuple(f.strip() for f in args.flags.split(",") if f.strip())
    candidate = Candidate(id=args.candidate_id, repo=args.repo, flags=flags)
    report = IntakeGatekeeper(repo_root).triage(candidate)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_main())
