"""
Tests for the hub routing-eval (S8).

Two layers, both DoD-gate compliant (every acceptance is a GOLDEN-FIXTURE
invariant or a LOGGED FIELD — never prose):

  A. CORPUS INTEGRITY — the golden fixture is honest: every inject id is a real
     conflict node, every stack id is a real id (a conflict node OR a declared
     substrate tool — no invented/typo'd ids), every stack is internally
     conflict-free, and every injection has a real conflict edge to exactly its
     expected members.
  B. MEASURED OUTCOMES — feeding that corpus to the REAL PolicyResolver
     produces the logged fields the eval reports (teeth real, passthrough slip,
     coverage calibrated), deterministically.
"""

from pathlib import Path
from typing import FrozenSet, Set

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

def _edges() -> Set[FrozenSet[str]]:
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


def test_every_id_is_real_no_invented_or_typod_ids():
    """No invented/typo'd ids. Stack tools may legitimately be substrate ids
    NOT in the conflict graph (e.g. impeccable/frontend-slides have no edges),
    so the source of truth is `nodes ∪ substrate_tools`: every stack id must be
    one of them. Plus the cross-consistency invariants that make each injection
    meaningful — inject is a real node, inject is not already in its own stack,
    and expect_conflict_with ⊆ stack."""
    doc = _cases_doc()
    nodes = _nodes()
    substrate = set(doc.get("substrate_tools", []))
    legit = nodes | substrate
    all_stack_tools: Set[str] = set()
    for fam in doc["families"]:
        for tool in fam["stack"]:
            assert isinstance(tool, str) and tool, f"{fam['id']}: empty/non-str stack id"
            assert tool in legit, (
                f"{fam['id']}: stack id '{tool}' is neither a conflict node nor a "
                f"declared substrate_tool — invented/typo'd id?"
            )
            all_stack_tools.add(tool)
        assert fam["inject"] in nodes, f"{fam['id']}: inject '{fam['inject']}' is not a conflict node"
        assert fam["inject"] not in fam["stack"], (
            f"{fam['id']}: inject '{fam['inject']}' must not already be in its own stack"
        )
        expect = set(fam.get("expect_conflict_with", []))
        missing = expect - set(fam["stack"])
        assert not missing, f"{fam['id']}: expect_conflict_with {missing} not in stack"
    # the allowlist must not rot into a loophole: every declared substrate tool
    # is actually used by some stack (a stale entry could mask a future typo).
    assert substrate <= all_stack_tools, (
        f"unused substrate_tools (allowlist rot): {sorted(substrate - all_stack_tools)}"
    )


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


def test_coverage_fixture_has_thirteen_artifacts_with_canonical_weights():
    doc = _coverage_doc()
    arts = doc["artifacts"]
    assert len(arts) == 13
    # Canonical status->weight mapping (BUILT=1, GAP=0, PARTIAL=0.5, hybrids =
    # midpoint). Validate EVERY artifact individually: a dict keyed by status
    # collapses duplicates and would only check the LAST artifact per status,
    # so a wrong weight on an earlier same-status artifact would slip through.
    canonical = {
        "BUILT": 1.0,
        "GAP": 0.0,
        "PARTIAL": 0.5,
        "BUILT/PARTIAL": 0.75,
        "PARTIAL/GAP": 0.25,
        "BUILT/GAP": 0.5,
    }
    for a in arts:
        status = a["status"]
        assert status in canonical, f"artifact {a.get('id', a)!r}: unknown status {status!r}"
        assert a["weight"] == canonical[status], (
            f"artifact {a.get('id', a)!r}: status={status} weight={a['weight']} "
            f"!= canonical {canonical[status]}"
        )


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
    # PIN the exact published calibration this PR asserts (not just the ordering)
    # so a drift in the fixture status column or the scoring math can't pass
    # silently. Source of truth: run_eval() over fixtures/artifact_coverage.yaml
    # (the snapshot documented in evals/README.md).
    assert strict == 0.2308
    assert weighted == 0.5769
    assert lenient == 0.9231
    # ...and the relationships that give those numbers meaning:
    # the claim is sensitive to how PARTIAL is counted
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
