"""
Tests for the universal ISO gating layer (WT3 / S3).

Two layers, both DoD-gate compliant (every acceptance is a GOLDEN-FIXTURE
invariant or a LOGGED FIELD — never prose):

  A. CORPUS INTEGRITY — the golden inventory is honest: every id is a real
     conflicts.yaml node (or the declared substrate tool), every summary fits
     the normative <=60-token limit, every non-injection profile is internally
     conflict-free, and the injection turn's planted pair has a real edge.
  B. MEASURED OUTCOMES — feeding that corpus to the REAL IsoGate (composing
     the REAL PolicyResolver) produces the logged fields the eval reports:
     top-k bounded promotion, budget respected, denied-never-promoted,
     normative-tokenizer truncation, determinism.
"""

from itertools import combinations
from pathlib import Path
from typing import Any, Dict, FrozenSet, List, Set

import yaml

from lib.gateway.iso import (
    ISO_DEFAULT_TOP_K,
    ISO_SUMMARY_TOKEN_LIMIT,
    IsoGate,
    ToolSummary,
    iso_tokens,
)
from lib.gateway.policy import PolicyResolver, load_conflicts
from evals.iso_gate_eval import CONFLICTS_YAML, INVENTORY_YAML, run_eval


# --------------------------------------------------------------------------- #
# fixtures-as-data (loaded once)
# --------------------------------------------------------------------------- #

def _fixture() -> Dict[str, Any]:
    return yaml.safe_load(Path(INVENTORY_YAML).read_text(encoding="utf-8"))


def _edges() -> Set[FrozenSet[str]]:
    return {frozenset(e) for e in load_conflicts(CONFLICTS_YAML)}


def _conflict_nodes() -> Set[str]:
    nodes: Set[str] = set()
    for edge in _edges():
        nodes |= set(edge)
    return nodes


# Substrate/expert tools that legitimately appear in the inventory without
# carrying a conflict edge (same discipline as routing_cases.yaml).
DECLARED_SUBSTRATE_TOOLS = {"notebooklm"}


# --------------------------------------------------------------------------- #
# A. corpus integrity — the golden inventory is honest
# --------------------------------------------------------------------------- #

def test_every_inventory_id_is_real():
    """No invented/typo'd ids: every id is a conflict node or declared substrate."""
    known = _conflict_nodes() | DECLARED_SUBSTRATE_TOOLS
    for item in _fixture()["inventory"]:
        assert item["id"] in known, f"invented id in fixture: {item['id']}"


def test_every_summary_within_normative_limit():
    """Spec acceptance: <=60 tokens/tool under iso_tokens (never prose-judged)."""
    for item in _fixture()["inventory"]:
        tokens = iso_tokens(item["summary"])
        assert tokens <= ISO_SUMMARY_TOKEN_LIMIT, (
            f"{item['id']} summary is {tokens} tokens (> {ISO_SUMMARY_TOKEN_LIMIT})"
        )


def test_non_injection_profiles_are_conflict_free():
    edges = _edges()
    for turn in _fixture()["turns"]:
        if turn["name"] == "injection" or not turn.get("profile"):
            continue
        for a, b in combinations(turn["profile"], 2):
            assert frozenset((a, b)) not in edges, (
                f"turn {turn['name']} profile carries conflict {a}<->{b}"
            )


def test_injection_turn_plants_a_real_edge():
    fixture = _fixture()
    injection = next(t for t in fixture["turns"] if t["name"] == "injection")
    planted = set(injection["expect"]["denied_contains"])
    assert frozenset(planted) in _edges(), (
        f"injection pair {planted} has no real conflicts.yaml edge"
    )


# --------------------------------------------------------------------------- #
# B. measured outcomes — the real IsoGate, logged fields
# --------------------------------------------------------------------------- #

def test_normative_tokenizer_is_ceil_len_over_4():
    assert iso_tokens("") == 0
    assert iso_tokens("abcd") == 1
    assert iso_tokens("abcde") == 2
    assert iso_tokens("x" * 240) == 60
    assert iso_tokens("x" * 241) == 61


def test_summary_truncation_is_deterministic_and_within_limit():
    long_text = "word " * 200  # far beyond 60 tokens
    entry = ToolSummary.build("openspec", long_text)
    assert entry.truncated is True
    assert entry.tokens <= ISO_SUMMARY_TOKEN_LIMIT
    # deterministic: same input -> same truncation
    assert ToolSummary.build("openspec", long_text) == entry


def test_topk_promotion_bounded_and_rest_summarized():
    """The spec scenario: only top-k full schemas; the rest stay summaries."""
    fixture = _fixture()
    gate, _ = IsoGate.from_inventory(fixture["inventory"])
    ranked = [item["id"] for item in fixture["inventory"]]
    sel = gate.select(ranked, k=ISO_DEFAULT_TOP_K)
    assert sel.k_effective == ISO_DEFAULT_TOP_K
    assert sel.promoted == ranked[:ISO_DEFAULT_TOP_K]
    assert set(sel.promoted) | set(sel.summarized) == set(ranked)
    assert sel.summary_tokens_max <= ISO_SUMMARY_TOKEN_LIMIT
    report = sel.to_report()
    assert report["invariants"]["summaries_within_limit"] is True
    assert report["invariants"]["promoted_lte_k"] is True


def test_budget_caps_promotion_greedily():
    fixture = _fixture()
    gate, _ = IsoGate.from_inventory(fixture["inventory"])
    ranked = [item["id"] for item in fixture["inventory"]]
    unbounded = gate.select(ranked, k=5)
    assert unbounded.schema_tokens_promoted > 0
    tight = unbounded.schema_tokens_promoted // 2
    sel = gate.select(ranked, k=5, schema_token_budget=tight)
    assert sel.schema_tokens_promoted <= tight
    assert sel.k_effective < unbounded.k_effective
    assert sel.to_report()["invariants"]["budget_respected"] is True


def test_policy_denied_is_never_promoted():
    """Hard-filter first: a denied tool never surfaces as a top-k candidate."""
    fixture = _fixture()
    turn = next(t for t in fixture["turns"] if t["name"] == "policy-gated")
    policy = PolicyResolver(
        profile=turn["profile"], conflicts=load_conflicts(CONFLICTS_YAML)
    )
    gate, _ = IsoGate.from_inventory(fixture["inventory"], policy=policy)
    sel = gate.select(turn["ranked"], k=turn["k"])
    denied_ids = {d["tool_id"] for d in sel.denied}
    assert set(turn["expect"]["denied_contains"]) <= denied_ids
    assert not denied_ids & set(sel.promoted)
    assert not denied_ids & set(sel.summarized)  # denied is its own bucket


def test_injection_denies_both_endpoints_with_named_peer():
    fixture = _fixture()
    turn = next(t for t in fixture["turns"] if t["name"] == "injection")
    policy = PolicyResolver(
        profile=turn["profile"], conflicts=load_conflicts(CONFLICTS_YAML)
    )
    gate, _ = IsoGate.from_inventory(fixture["inventory"], policy=policy)
    sel = gate.select(turn["ranked"], k=turn["k"])
    denied = {d["tool_id"]: d for d in sel.denied}
    assert {"mem0", "letta"} <= set(denied)
    assert denied["mem0"]["conflicting_with"] == ["letta"]
    assert denied["letta"]["conflicting_with"] == ["mem0"]


def test_unknown_candidates_are_reported_not_promoted():
    gate = IsoGate()
    gate.register("openspec", "spec tool")
    sel = gate.select(["openspec", "not-a-tool"], k=2)
    assert sel.unknown == ["not-a-tool"]
    assert sel.promoted == ["openspec"]


def test_empty_pool_selection_does_not_crash():
    """Regression lock for PR #197 review: ``max(pool_tokens, default=0)``
    handles the empty pool by definition (PEP-defined ``default``) — an empty
    gate selects cleanly with all invariants green and summary_tokens_max=0."""
    gate = IsoGate()
    sel = gate.select([], k=3)
    assert sel.pool_size == 0
    assert sel.summary_tokens_max == 0
    report = sel.to_report()
    assert all(report["invariants"].values())
    # empty ranked list against a populated pool is equally safe
    gate.register("openspec", "spec tool")
    assert gate.select([], k=3).summarized == ["openspec"]


def test_selection_is_deterministic():
    fixture = _fixture()
    gate, _ = IsoGate.from_inventory(fixture["inventory"])
    ranked = [item["id"] for item in fixture["inventory"]]
    a = gate.select(ranked, k=4).to_report()
    b = gate.select(ranked, k=4).to_report()
    assert a == b


def test_run_eval_verdict_all_green():
    """The eval's own logged verdict — the reproducible acceptance command."""
    report = run_eval()
    verdict = report["verdict"]
    assert verdict["summaries_within_limit"] is True
    assert verdict["all_turn_expectations_pass"] is True
    assert verdict["promotion_always_bounded"] is True
    assert report["tokenizer"] == "ceil(len/4)"
    assert report["summary_token_limit"] == ISO_SUMMARY_TOKEN_LIMIT


def test_run_eval_is_deterministic():
    assert run_eval() == run_eval()
