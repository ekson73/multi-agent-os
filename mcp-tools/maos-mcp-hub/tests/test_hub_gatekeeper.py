"""Tests — lib.registry.gatekeeper (WAVE 6 T8-core).

Acceptance (narrowed T8): a planted-malicious fixture is BLOCKED by the
deterministic floor, and the gatekeeper NEVER auto-accepts (reject-by-default,
mandatory HITL). The per-PR ceremony is deferred — not tested here.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from lib.registry.gatekeeper import (
    ALLOWED_VERDICTS,
    Candidate,
    GATEKEEPER_SCHEMA_VERSION,
    IntakeGatekeeper,
)

_HUB_DIR = Path(__file__).resolve().parents[1]
_REPO_ROOT = _HUB_DIR.parents[1]


def _gk() -> IntakeGatekeeper:
    return IntakeGatekeeper(_REPO_ROOT)


# -- acceptance: the floor blocks planted malice ------------------------------


def test_planted_malicious_candidate_blocked_by_flag_veto() -> None:
    """A synthetic candidate carrying a compromised-class flag is vetoed."""
    report = _gk().triage(
        Candidate(id="evil-helper", repo="attacker/evil-helper",
                  flags=("live-threat-npm-keys",))
    )
    assert report["verdict"] == "blocked"
    assert report["hitl_required"] is False
    assert any("flag-veto" in r for r in report["reasons"])


def test_known_excluded_record_blocked_with_safe_successor() -> None:
    """The live WT10 fixture's GSD rug-pull record is an executable veto."""
    report = _gk().triage(
        Candidate(id="gsd-build-get-shit-done", repo="gsd-build/get-shit-done")
    )
    assert report["verdict"] == "blocked"
    assert report["safe_successor"] == "open-gsd/gsd-core"
    assert report["evidence"], "an EXCLUDED veto must carry evidence refs"


def test_malformed_candidate_blocked_fail_closed() -> None:
    for cand in (Candidate(id="", repo="x/y"), Candidate(id="x", repo="  ")):
        report = _gk().triage(cand)
        assert report["verdict"] == "blocked"
        assert any("malformed-candidate" in r for r in report["reasons"])


# -- acceptance: the gatekeeper never auto-accepts ----------------------------


def test_never_auto_accepts_structural_and_behavioral() -> None:
    """No verdict ever implies acceptance; every non-blocked verdict is HITL."""
    assert not {v for v in ALLOWED_VERDICTS if "accept" in v or "install" in v}
    gk = _gk()
    spread = [
        Candidate(id="brand-new-tool", repo="someone/brand-new-tool"),
        Candidate(id="superpowers", repo="obra/superpowers"),
        Candidate(id="stale-thing", repo="x/stale-thing", flags=("stale",)),
        Candidate(id="gsd-build-get-shit-done", repo="gsd-build/get-shit-done"),
        Candidate(id="", repo=""),
    ]
    for cand in spread:
        report = gk.triage(cand)
        assert report["verdict"] in ALLOWED_VERDICTS
        assert report["verdict"] == "blocked" or report["hitl_required"] is True


def test_unknown_clean_candidate_is_hitl_never_accepted() -> None:
    report = _gk().triage(Candidate(id="brand-new-tool", repo="someone/brand-new-tool"))
    assert report["verdict"] == "hitl-required"
    assert report["hitl_required"] is True
    assert any("never auto-accepts" in r for r in report["reasons"])


def test_abandoned_flags_warn_but_do_not_block() -> None:
    report = _gk().triage(
        Candidate(id="dusty-tool", repo="x/dusty-tool", flags=("stale", "archived"))
    )
    assert report["verdict"] == "hitl-required"
    assert any("upstream-health" in w for w in report["warnings"])


# -- conductor isolation (RULE-011) -------------------------------------------


def test_dispositioned_conductor_carries_isolation_overlay() -> None:
    """superpowers is fixture-dispositioned AND conductor-class."""
    report = _gk().triage(Candidate(id="superpowers", repo="obra/superpowers"))
    assert report["verdict"] == "already-dispositioned"
    assert report["isolation_required"] is True
    assert any("RULE-011" in w for w in report["warnings"])


def test_unknown_conductor_requires_isolation(tmp_path: Path) -> None:
    """Synthetic repo: a conductor-class candidate NOT in the fixture."""
    fixture = tmp_path / "mcp-tools" / "maos-mcp-hub" / "evals" / "fixtures"
    fixture.mkdir(parents=True)
    (fixture / "intake_verdicts.yaml").write_text(
        "schema_version: intake-batch/1.0.0\nentries: []\n", encoding="utf-8"
    )
    gov = tmp_path / "plugin-scripts" / "governance" / "lib"
    gov.mkdir(parents=True)
    (gov / "conductors.txt").write_text(
        "# synthetic\nmega-manager|skills/mega-manager\n", encoding="utf-8"
    )
    report = IntakeGatekeeper(tmp_path).triage(
        Candidate(id="mega-manager", repo="x/mega-manager")
    )
    assert report["verdict"] == "isolation-required"
    assert report["isolation_required"] is True
    assert report["hitl_required"] is True


# -- determinism + CLI contract ------------------------------------------------


def test_report_is_deterministic() -> None:
    gk = _gk()
    cand = Candidate(id="brand-new-tool", repo="someone/brand-new-tool")
    a = json.dumps(gk.triage(cand), sort_keys=True)
    b = json.dumps(gk.triage(cand), sort_keys=True)
    assert a == b
    assert GATEKEEPER_SCHEMA_VERSION in a


def test_cli_contract_triage_and_failure() -> None:
    ok = subprocess.run(
        [sys.executable, "-m", "lib.registry.gatekeeper",
         "--repo-root", str(_REPO_ROOT),
         "--candidate-id", "gsd-build-get-shit-done",
         "--repo", "gsd-build/get-shit-done"],
        cwd=_HUB_DIR, capture_output=True, text=True, timeout=120,
    )
    assert ok.returncode == 0, ok.stdout + ok.stderr
    payload = json.loads(ok.stdout)
    assert payload["verdict"] == "blocked"

    bad = subprocess.run(
        [sys.executable, "-m", "lib.registry.gatekeeper",
         "--repo-root", "/nonexistent-root",
         "--candidate-id", "x", "--repo", "x/y"],
        cwd=_HUB_DIR, capture_output=True, text=True, timeout=120,
    )
    assert bad.returncode == 1
    fail = json.loads(bad.stdout)
    assert fail["verdict"] == "fail"
    assert "fixture not found" in fail["error"]
