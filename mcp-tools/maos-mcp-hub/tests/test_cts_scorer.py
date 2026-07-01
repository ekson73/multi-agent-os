"""
Tests for the unified CTS scorer (WT4 / S2).

Two layers, both DoD-gate compliant (every acceptance is a GOLDEN-FIXTURE
invariant or a LOGGED FIELD — never prose):

  A. CORPUS INTEGRITY — the golden corpus is honest: every id is a real
     conflicts.yaml node (or declared substrate), every risk block uses only
     RiskSignals field names, the policy-conflict turn plants a real edge.
  B. MEASURED OUTCOMES — feeding that corpus to the REAL CtsScorer produces
     the logged fields the eval reports: hard-filters-first (a perfect-score
     candidate failing auth is never scored), the concrete risk=HIGH
     predicate, weight normalization, determinism, and the WT3<->WT4 seam
     (CTS rank is IsoGate's ranked input).
"""

from dataclasses import fields as dc_fields
from pathlib import Path
from typing import Any, Dict, FrozenSet, Set

import yaml

from lib.gateway.cts import (
    CTS_WEIGHTS,
    CtsCandidate,
    CtsScorer,
    CtsTurn,
    RiskClass,
    RiskSignals,
    candidates_from_fixture,
    risk_class,
)
from lib.gateway.iso import IsoGate
from lib.gateway.policy import PolicyResolver, load_conflicts
from evals.cts_eval import CASES_YAML, CONFLICTS_YAML, run_eval


def _fixture() -> Dict[str, Any]:
    return yaml.safe_load(Path(CASES_YAML).read_text(encoding="utf-8"))


def _edges() -> Set[FrozenSet[str]]:
    return {frozenset(e) for e in load_conflicts(CONFLICTS_YAML)}


def _conflict_nodes() -> Set[str]:
    nodes: Set[str] = set()
    for edge in _edges():
        nodes |= set(edge)
    return nodes


DECLARED_SUBSTRATE_TOOLS = {"notebooklm"}


# --------------------------------------------------------------------------- #
# A. corpus integrity
# --------------------------------------------------------------------------- #

def test_every_candidate_id_is_real():
    known = _conflict_nodes() | DECLARED_SUBSTRATE_TOOLS
    for item in _fixture()["candidates"]:
        assert item["id"] in known, f"invented id in fixture: {item['id']}"


def test_risk_blocks_use_only_enumerable_signals():
    signal_names = {f.name for f in dc_fields(RiskSignals)}
    for item in _fixture()["candidates"]:
        assert set(item.get("risk", {})) <= signal_names, (
            f"{item['id']} risk block uses non-signal keys"
        )


def test_policy_conflict_turn_plants_a_real_edge():
    turn = next(t for t in _fixture()["turns"] if t["name"] == "policy-conflict")
    planted = {e["tool_id"] for e in turn["expect"]["eliminated_contains"]}
    assert frozenset(planted) in _edges()


# --------------------------------------------------------------------------- #
# B. measured outcomes
# --------------------------------------------------------------------------- #

def test_weights_sum_to_one():
    assert abs(sum(CTS_WEIGHTS.values()) - 1.0) < 1e-9
    assert set(CTS_WEIGHTS) == {
        "scope", "eisenhower", "risk", "reversibility", "iso", "methodology",
    }  # the spec's six criteria, exactly


def test_risk_high_predicate_is_concrete_per_signal():
    """Each HIGH signal alone flips the class — enumerable, never vibes."""
    assert risk_class(RiskSignals()) is RiskClass.LOW
    for name in RiskSignals.HIGH_SIGNALS:
        assert risk_class(RiskSignals(**{name: True})) is RiskClass.HIGH, name
    for name in RiskSignals.MEDIUM_SIGNALS:
        assert risk_class(RiskSignals(**{name: True})) is RiskClass.MEDIUM, name
    # a MEDIUM signal never masks a HIGH one
    assert (
        risk_class(RiskSignals(bulk_write=True, prod_facing=True)) is RiskClass.HIGH
    )


def test_hard_filter_eliminates_before_scoring():
    """Spec scenario: perfect-score candidate lacking auth is NEVER scored."""
    scorer = CtsScorer()
    perfect_but_unauth = CtsCandidate(
        tool_id="gstack",
        expert_fit=1.0,
        methodology_fit=1.0,
        eisenhower_q=1,
        required_scopes=frozenset({"browser.control"}),
    )
    ranking = scorer.rank(
        [perfect_but_unauth], CtsTurn(granted_scopes=frozenset({"repo.write"}))
    )
    assert ranking.ranked == []
    assert ranking.eliminated[0]["filter"] == "auth"
    assert "browser.control" in ranking.eliminated[0]["reason"]


def test_risk_ceiling_elimination_is_hitl_eligible_not_silent():
    scorer = CtsScorer()
    risky = CtsCandidate(
        tool_id="ruflo", expert_fit=0.9, risk=RiskSignals(prod_facing=True)
    )
    ranking = scorer.rank([risky], CtsTurn(max_risk=RiskClass.MEDIUM))
    entry = ranking.eliminated[0]
    assert entry["filter"] == "risk_class"
    assert entry["hitl_eligible"] is True
    assert "prod_facing" in entry["reason"]
    # ceiling raised -> the same candidate is scored instead
    ranking_high = scorer.rank([risky], CtsTurn(max_risk=RiskClass.HIGH))
    assert ranking_high.ranked and ranking_high.eliminated == []


def test_data_class_filter():
    scorer = CtsScorer()
    pii_tool = CtsCandidate(tool_id="mem0", data_classes=frozenset({"pii"}))
    ranking = scorer.rank([pii_tool], CtsTurn())
    assert ranking.eliminated[0]["filter"] == "data_class"
    ok = scorer.rank(
        [pii_tool], CtsTurn(allowed_data_classes=frozenset({"pii"}))
    )
    assert ok.ranked


def test_ranking_is_deterministic_with_tool_id_tiebreak():
    scorer = CtsScorer()
    twin_a = CtsCandidate(tool_id="mem0", expert_fit=0.5)
    twin_b = CtsCandidate(tool_id="cognee", expert_fit=0.5)
    ranking = scorer.rank([twin_a, twin_b], CtsTurn())
    assert [r["tool_id"] for r in ranking.ranked] == ["cognee", "mem0"]
    again = scorer.rank([twin_a, twin_b], CtsTurn())
    assert ranking.to_report() == again.to_report()


def test_golden_turns_all_pass():
    report = run_eval()
    for turn in report["turns"]:
        assert all(turn["expectations"].values()), (
            turn["name"],
            turn["expectations"],
        )


def test_cts_rank_feeds_iso_gate_as_prefix():
    """The WT3<->WT4 seam: IsoGate promotes exactly the CTS rank prefix."""
    fixture = _fixture()
    candidates = candidates_from_fixture(fixture["candidates"])
    turn_spec = next(t for t in fixture["turns"] if t["name"] == "spec-task-clean")
    scorer = CtsScorer()
    ranking = scorer.rank(
        candidates,
        CtsTurn(
            granted_scopes=frozenset(turn_spec["granted_scopes"]),
            max_risk=RiskClass[turn_spec["max_risk"]],
        ),
    )
    gate, _ = IsoGate.from_inventory(
        [{"id": c.tool_id, "summary": f"{c.tool_id} expert", "schema": c.schema}
         for c in candidates]
    )
    selection = gate.select(ranking.ranked_ids(), k=3)
    assert selection.promoted == ranking.ranked_ids()[:3]
    assert selection.to_report()["invariants"]["promoted_lte_k"] is True


def test_run_eval_verdict_all_green_and_deterministic():
    report = run_eval()
    assert all(report["verdict"].values()), report["verdict"]
    assert run_eval() == run_eval()
