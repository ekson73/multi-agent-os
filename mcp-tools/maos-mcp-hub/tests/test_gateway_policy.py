"""
Tests for the gating-seam (PolicyResolver + router policy hook).

Three proofs (see research/agentic-moe-2026/20260628-solutions-debate.md §P1):
  1. PASSTHROUGH / 0-REGRESSION — with policy=None the router behaves
     IDENTICALLY to a router with no policy argument at all. This is the R1
     proof: the seam is additive and reversible.
  2. GATING — with a policy where the checked id is disabled OR conflicts
     with an active id, dispatch is blocked with the structured
     _agent_feedback error envelope (no handler is invoked).
  3. CONFLICTS LOAD — the curated conflicts.yaml parses and round-trips
     >= 15 undirected edges.
"""

import asyncio
from pathlib import Path
from typing import Any, Dict

import pytest

from lib.gateway.policy import PolicyDecision, PolicyResolver, load_conflicts
from lib.gateway.router import MetaToolRouter
from lib.gateway.types import GatewayRequest


# ---------------------------------------------------------------------------
# Helpers — mirror test_gateway_router.py handlers, plus a call-spy.
# ---------------------------------------------------------------------------

_CALLS: Dict[str, int] = {}


async def _mock_get_issue(issue_key: str, format: str = "markdown") -> Dict[str, Any]:
    _CALLS["get"] = _CALLS.get("get", 0) + 1
    return {"key": issue_key, "summary": "Test issue", "format": format}


async def _mock_create_issue(project_key: str, summary: str, issue_type: str = "Task") -> Dict[str, Any]:
    _CALLS["create"] = _CALLS.get("create", 0) + 1
    return {"key": f"{project_key}-999", "summary": summary, "type": issue_type}


def _build_router(policy=None) -> MetaToolRouter:
    """Build a router identical to the router-test fixture, optional policy."""
    router = MetaToolRouter(
        tool_name="atlassian_jira",
        governance=["governance_level obrigatorio ao criar issues"],
        policy=policy,
    )
    router.register("issue", "get", _mock_get_issue, description="Get issue by key")
    router.register(
        "issue",
        "create",
        _mock_create_issue,
        description="Create a new issue",
        governance=["governance_level obrigatorio"],
        next_steps=["Add DARCI roles after creating"],
    )
    return router


CONFLICTS_YAML = Path(__file__).resolve().parent.parent / "lib" / "gateway" / "conflicts.yaml"


# ===========================================================================
# 1. PASSTHROUGH / 0-REGRESSION  (R1 — the biggest lever)
# ===========================================================================

def test_policy_none_is_default():
    """A router built without a policy arg has policy is None."""
    router = MetaToolRouter("atlassian_jira")
    assert router.policy is None


def test_passthrough_execution_identical_to_no_policy():
    """policy=None dispatch == no-policy dispatch, byte-for-byte."""
    async def run():
        baseline = await _build_router().dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "VKS-1234"})
        )
        explicit_none = await _build_router(policy=None).dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "VKS-1234"})
        )
        assert baseline == explicit_none
        # And it is the real handler result (not a gate response).
        assert baseline["key"] == "VKS-1234"
        assert baseline["summary"] == "Test issue"
        assert "error" not in baseline
        assert baseline["_agent_feedback"]["tool"] == "atlassian_jira"
        assert baseline["_agent_feedback"]["operation"] == "get"

    asyncio.run(run())


def test_passthrough_discovery_levels_untouched():
    """Discovery levels 0-2 are identical with policy=None vs no policy."""
    async def run():
        for req in (
            GatewayRequest(),                                          # L0
            GatewayRequest(resource="issue"),                         # L1
            GatewayRequest(resource="issue", operation="get"),        # L2
        ):
            assert await _build_router().dispatch(req) == await _build_router(policy=None).dispatch(req)

    asyncio.run(run())


def test_passthrough_with_empty_profile_resolver_allows_all():
    """Even an attached resolver with no profile is a passthrough."""
    async def run():
        router = _build_router(policy=PolicyResolver())  # no profile => allow-all
        result = await router.dispatch(
            GatewayRequest(resource="issue", operation="create",
                           params={"project_key": "VKS", "summary": "Test"})
        )
        assert result["key"] == "VKS-999"
        assert "error" not in result

    asyncio.run(run())


def test_passthrough_does_not_invoke_handler_when_gated_but_invokes_when_open():
    """The spy proves: open path calls the handler exactly once."""
    async def run():
        _CALLS.clear()
        router = _build_router(policy=None)
        await router.dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "X-1"})
        )
        assert _CALLS.get("get") == 1

    asyncio.run(run())


# ===========================================================================
# 2. GATING  (the teeth are real)
# ===========================================================================

def test_gating_blocks_disabled_operation():
    """An id absent from the active profile is denied (disabled)."""
    async def run():
        _CALLS.clear()
        # Profile enables only 'create' => 'get' is disabled.
        router = _build_router(policy=PolicyResolver(profile={"create"}))
        result = await router.dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "VKS-1"})
        )
        assert "error" in result
        assert "Blocked by policy" in result["error"]
        assert "_agent_feedback" in result
        fb = result["_agent_feedback"]
        assert fb["tool"] == "atlassian_jira"
        assert fb["resource"] == "issue"
        assert fb["operation"] == "get"
        assert fb["hints"] and "disabled" in fb["hints"][0].lower()
        # The handler must NOT have run.
        assert _CALLS.get("get", 0) == 0

    asyncio.run(run())


def test_gating_blocks_conflicting_operation():
    """An enabled id that conflicts with an active id is denied (conflict)."""
    async def run():
        _CALLS.clear()
        # Both 'get' and 'create' enabled, but they conflict with each other.
        resolver = PolicyResolver(
            profile={"get", "create"},
            conflicts=[("get", "create")],
        )
        router = _build_router(policy=resolver)
        result = await router.dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "VKS-1"})
        )
        assert "error" in result
        assert "Blocked by policy" in result["error"]
        assert result.get("conflicts_with") == ["create"]
        assert "conflicts with active" in result["_agent_feedback"]["hints"][0].lower()
        assert _CALLS.get("get", 0) == 0

    asyncio.run(run())


def test_gating_allows_enabled_non_conflicting_operation():
    """An enabled id with no active conflict passes through to the handler."""
    async def run():
        _CALLS.clear()
        resolver = PolicyResolver(profile={"get"}, conflicts=[("create", "delete")])
        router = _build_router(policy=resolver)
        result = await router.dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "VKS-1"})
        )
        assert "error" not in result
        assert result["key"] == "VKS-1"
        assert _CALLS.get("get") == 1

    asyncio.run(run())


def test_gating_deny_envelope_matches_existing_error_shape():
    """The gate error envelope mirrors the router's other error responses."""
    async def run():
        router = _build_router(policy=PolicyResolver(profile={"create"}))
        gate_err = await router.dispatch(
            GatewayRequest(resource="issue", operation="get", params={"issue_key": "Z"})
        )
        # An existing error path for comparison (unknown operation).
        existing_err = await _build_router().dispatch(
            GatewayRequest(resource="issue", operation="nope", params={"x": 1})
        )
        # Same top-level keys present in both: error + resource + _agent_feedback.
        for key in ("error", "resource", "_agent_feedback"):
            assert key in gate_err
            assert key in existing_err
        assert set(gate_err["_agent_feedback"]) >= {"tool", "hints"}

    asyncio.run(run())


# ===========================================================================
# 3. CONFLICTS LOAD  (curated edge-list parses + round-trips >= 15)
# ===========================================================================

def test_conflicts_yaml_exists():
    assert CONFLICTS_YAML.is_file(), f"missing curated edge-list: {CONFLICTS_YAML}"


def test_conflicts_yaml_parses_at_least_15_edges():
    edges = load_conflicts(CONFLICTS_YAML)
    assert len(edges) >= 15, f"expected >= 15 curated edges, got {len(edges)}"
    # Every edge is a well-formed 2-tuple of non-empty distinct ids.
    for a, b in edges:
        assert a and b and a != b


def test_conflicts_yaml_contains_curated_incompatibilities():
    """Spot-check the documented incompatibility pairs (order-independent)."""
    edges = load_conflicts(CONFLICTS_YAML)
    norm = {frozenset(e) for e in edges}
    expected = [
        ("ECC", "base"),
        ("spec-kit", "openspec"),
        ("mem0", "letta"),
        ("open-design", "open-codesign"),
        ("paul", "gsd-core"),
    ]
    for pair in expected:
        assert frozenset(pair) in norm, f"missing curated edge: {pair}"


def test_resolver_from_yaml_round_trips_edge_count():
    """from_yaml loads the same number of undirected edges as load_conflicts."""
    edges = load_conflicts(CONFLICTS_YAML)
    resolver = PolicyResolver.from_yaml(CONFLICTS_YAML)
    assert resolver.edge_count == len(edges)


def test_resolver_enforces_loaded_conflict_when_profile_active():
    """End-to-end: load curated edges, activate a conflicting profile, deny."""
    async def run():
        # Reuse a real curated pair as the gateway's checked ids.
        resolver = PolicyResolver.from_yaml(
            CONFLICTS_YAML, profile={"spec-kit", "openspec"}
        )
        router = MetaToolRouter("atlassian_jira", policy=resolver)

        async def _h_speckit() -> Dict[str, Any]:
            return {"ok": True}

        router.register("spec", "spec-kit", _h_speckit)
        result = await router.dispatch(
            GatewayRequest(resource="spec", operation="spec-kit", params={})
        )
        assert "error" in result
        assert result.get("conflicts_with") == ["openspec"]

    asyncio.run(run())


def test_load_conflicts_rejects_malformed_edge(tmp_path):
    """A 1-item edge raises ValueError (fails loudly, not silently)."""
    bad = tmp_path / "bad.yaml"
    bad.write_text("conflicts:\n  - [only-one]\n", encoding="utf-8")
    with pytest.raises(ValueError):
        load_conflicts(bad)


def test_policy_decision_truthiness():
    assert bool(PolicyDecision(allow=True)) is True
    assert bool(PolicyDecision(allow=False, reason="x")) is False
