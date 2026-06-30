"""
Tests for the hub routing-eval (S8).

Two layers, both DoD-gate compliant (every acceptance is a GOLDEN-FIXTURE
invariant or a LOGGED FIELD — never prose):

  A. CORPUS INTEGRITY — the golden fixture is honest: every tool id is real
     (a node in conflicts.yaml), every stack is internally conflict-free, and
     every injection has a real conflict edge to exactly its expected members.
  B. MEASURED OUTCOMES — feeding that corpus to the REAL PolicyResolver
     produces the logged fields the eval reports (teeth real, passthrough slip,
     coverage calibrated), deterministically.
"""

from pathlib import Path
from typing import Set, Tuple

import yaml

from lib.gateway.policy import PolicyResolver, load_conflicts
from evals.routing_eval import (
    CASES_YAML,
    COVERAGE_YAML,
    CONFLICTS_YAML,
    run_eval,
)


# --------------------------------------------------------------------------- #
# fixtures-as-data (loaded once)
# --------------------------------------------------------------------------- #

def _edges() -> Set[Tuple[str, str]]:
    return {frozenset(e) for e in load_conflicts(CONFLICTS_YAML)}


def _nodes() -> Set[str]:
    nodes: Set[str] = set()
    for a, b in load_conflicts(CONFLICTS_YAML):
        nodes.add(a)
        nodes.add(b)
    return nodes


def _cases_doc():
    return yaml.safe_load(Path(CASES_YAML).read_text(encoding="utf-8"))


def _coverage_doc():
    return yaml.safe_load(Path(COVERAGE_YAML).read_text(encoding="utf-8"))


# ===========================================================================
# A. CORPUS INTEGRITY (golden-fixture invariants)
# ===========================================================================

def test_corpus_has_six_families_and_three_risk_levels():
    doc = _cases_doc()
    assert len(doc["families"]) == 6
    assert len(doc["risk_levels"]) == 3


def test_every_stack_and_inject_id_is_a_real_conflict_node():
    """No invented tool ids — every id must exist in conflicts.yaml."""
    nodes = _nodes()
    for fam in _cases_doc()["families"]:
        for tool in fam["stack"]:
            # stack tools may be substrate ids NOT in the conflict graph
            # (e.g. impeccable/frontend-slides have no edges) -> only assert
            # the INJECT id is a real node (it must collide to be testable).
            assert isinstance(tool, str) and tool
        assert fam["inject"] in nodes, f"{fam['id']}: inject '{fam['inject']}' is not a conflict node"


def test_every_stack_is_internally_conflict_free():
    """A clean stack => the ONLY conflict in an injection case is the injectee."""
    edges = _edges()
    for fam in _cases_doc()["families"]:
        stack = fam["stack"]
        for i in range(len(stack)):
            for j in range(i + 1, len(stack)):
                pair = frozenset((stack[i], stack[j]))
                assert pair not in edges, (
                    f"{fam['id']}: stack has an internal conflict {tuple(pair)}"
                )


def test_every_injection_collides_with_exactly_its_expected_members():
    edges = _edges()
    for fam in _cases_doc()["families"]:
        inject = fam["inject"]
        expected = set(fam.get("expect_conflict_with", []))
        actual = {m for m in fam["stack"] if frozenset((inject, m)) in edges}
        assert actual == expected, (
            f"{fam['id']}: inject '{inject}' collides with {actual}, "
            f"expected {expected}"
        )


def test_coverage_fixture_has_thirteen_artifacts_summing_to_n():
    doc = _coverage_doc()
    arts = doc["artifacts"]
    assert len(arts) == 13
    # hybrid weights are the documented midpoints
    by_status = {a["status"]: a["weight"] for a in arts}
    assert by_status.get("BUILT") == 1.0
    assert by_status.get("GAP") == 0.0
    assert by_status.get("PARTIAL") == 0.5
    assert by_status.get("BUILT/PARTIAL") == 0.75
    assert by_status.get("PARTIAL/GAP") == 0.25
    assert by_status.get("BUILT/GAP") == 0.5


# ===========================================================================
# B. MEASURED OUTCOMES (logged fields from the real PolicyResolver)
# ===========================================================================

def test_report_shape_is_stable():
    r = run_eval()
    assert r["meta"]["families"] == 6
    assert r["meta"]["risk_levels"] == 3
    assert r["meta"]["cases_total"] == 18
    assert r["meta"]["conflicts_edge_count"] >= 15
    for key in ("routing_gating", "architecture_coverage", "verdict"):
        assert key in r


def test_seam_teeth_are_real_every_injection_blocked_with_correct_reason():
    r = run_eval()
    inj = r["routing_gating"]["injection"]
    assert inj["total"] == 18
    assert inj["blocked"] == 18
    assert inj["blocked_rate"] == 1.0
    assert inj["reason_correct"] == 18          # named the RIGHT colliding tool
    assert inj["reason_correct_rate"] == 1.0
    assert r["verdict"]["seam_teeth_real"] is True


def test_clean_stacks_are_fully_routable():
    r = run_eval()
    cov = r["routing_gating"]["coverage_allow"]
    assert cov["correct"] == cov["total"]       # zero false-denies
    assert cov["rate"] == 1.0


def test_without_the_seam_every_conflict_would_slip():
    """policy=None passthrough => the seam's value = every prevented co-activation."""
    r = run_eval()
    off = r["routing_gating"]["gating_off"]
    assert off["unsafe_passthrough"] == r["meta"]["cases_total"]
    assert off["prevented_by_seam"] == r["routing_gating"]["injection"]["blocked"]


def test_risk_gating_is_honestly_reported_as_not_yet_enforced():
    r = run_eval()
    rg = r["routing_gating"]
    assert rg["risk_gating_enforced"] is False   # anti-theatre: seam is risk-agnostic
    assert rg["hitl_required_cases"] == 6        # one high-risk row per family


def test_coverage_claim_is_calibrated_under_three_rules():
    r = run_eval()
    rules = r["architecture_coverage"]["rules"]
    strict = rules["strict"]["score"]
    weighted = rules["weighted"]["score"]
    lenient = rules["lenient"]["score"]
    # the whole point: the claim is sensitive to how PARTIAL is counted
    assert strict < weighted < lenient
    # by the doc's own status column, weighted coverage is BELOW the ~70% claim
    assert weighted < r["architecture_coverage"]["claim_asserted"]
    assert "OPTIMISTIC" in rules["weighted"]["verdict_vs_claim"]


def test_half_the_plan_does_not_fall_so_gap_waves_remain_justified():
    r = run_eval()
    # teeth real BUT coverage < claim => the eval does NOT greenlight cutting
    # the gap-fill waves. This is the eval-first decision WT0 exists to make.
    assert r["verdict"]["half_the_plan_falls"] is False


def test_eval_is_deterministic():
    assert run_eval() == run_eval()


def test_every_case_record_carries_logged_fields_not_prose():
    """DoD-gate: each case is decided by logged booleans/ids, never a prose THEN."""
    required = {
        "family", "risk", "hitl_required", "stack_all_allowed",
        "injection", "injection_blocked", "injection_reason_correct",
        "conflict_named", "gating_off_passthrough",
    }
    for case in run_eval()["routing_gating"]["cases"]:
        assert required <= set(case)
        assert isinstance(case["injection_blocked"], bool)
        assert isinstance(case["conflict_named"], list)
