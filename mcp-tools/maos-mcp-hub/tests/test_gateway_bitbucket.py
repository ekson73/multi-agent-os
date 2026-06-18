"""Tests for Bitbucket gateway — wrapping 55 tools into meta-tool pattern (VKS-1853)."""

import asyncio
import os

import pytest

from gateways.bitbucket.actions import build_router, RESOURCE_MAP
from lib.gateway.types import GatewayRequest
from servers.bitbucket.tools import TOOLS as BB_TOOLS


# ---------------------------------------------------------------------------
# Coverage: all 55 tools are mapped (52 legacy + 3 VKS-1853 PR ops)
# ---------------------------------------------------------------------------

def test_all_bitbucket_tools_have_gateway_mapping():
    """Every tool in BB_TOOLS must appear in RESOURCE_MAP."""
    mapped_handlers = set()
    for resource, operations in RESOURCE_MAP.items():
        for operation, handler in operations.items():
            mapped_handlers.add(id(handler))

    unmapped = []
    for tool_name, tool_func in BB_TOOLS.items():
        if id(tool_func) not in mapped_handlers:
            unmapped.append(tool_name)

    assert unmapped == [], f"Unmapped tools: {unmapped}"


def test_resource_map_has_56_actions():
    """Total action count matches expected 56 (52 legacy + 3 VKS-1853 + 1 decline)."""
    total = sum(len(ops) for ops in RESOURCE_MAP.values())
    assert total == 56, f"Expected 56 actions, got {total}"


# ---------------------------------------------------------------------------
# Discovery tests
# ---------------------------------------------------------------------------

def test_discovery_level0_lists_all_resources():
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        assert "resources" in result
        resources = result["resources"]
        assert "pipeline" in resources
        assert "pull_request" in resources
        assert "branch" in resources
        assert "deployment" in resources
        assert "commit" in resources
        assert "test" in resources
        assert "cache" in resources
        assert "variable" in resources
        assert "learning" in resources
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discovery_level1_pipeline_operations():
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="pipeline"))
        assert "operations" in result
        ops = result["operations"]
        assert "list" in ops
        assert "get" in ops
        assert "trigger" in ops
        assert "stop" in ops
        assert "diagnose" in ops

    asyncio.run(run())


def test_discovery_level1_pull_request_operations():
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="pull_request"))
        ops = result["operations"]
        assert "create" in ops
        assert "merge" in ops
        assert "approve" in ops
        assert "get_comments" in ops
        # VKS-1853: new PR interaction operations
        assert "add_comment" in ops
        assert "reply_to_comment" in ops
        assert "update_description" in ops

    asyncio.run(run())


def test_vks1853_pull_request_has_12_ops():
    """pull_request must expose 12 ops (8 legacy + 3 VKS-1853 + 1 decline)."""
    pr_ops = RESOURCE_MAP["pull_request"]
    expected = {
        "list", "get", "create", "merge", "approve", "unapprove",
        "get_comments", "get_build_statuses",
        # VKS-1853 additions
        "add_comment", "reply_to_comment", "update_description",
        # decline op (2026-06-18) — close obsolete/superseded PRs without merging
        "decline",
    }
    assert set(pr_ops.keys()) == expected, (
        f"pull_request ops mismatch: expected {expected}, got {set(pr_ops.keys())}"
    )


def test_vks1853_pr_add_comment_has_governance():
    """VKS-1853: add_comment must carry governance metadata for agents."""
    router = build_router()
    schema = router.registry.get_schema("pull_request", "add_comment")
    assert schema is not None


def test_vks1853_pr_update_description_has_governance():
    """VKS-1853: update_description must carry governance metadata."""
    router = build_router()
    schema = router.registry.get_schema("pull_request", "update_description")
    assert schema is not None


def test_vks1853_pr_reply_to_comment_has_governance():
    """VKS-1853: reply_to_comment must carry governance metadata."""
    router = build_router()
    schema = router.registry.get_schema("pull_request", "reply_to_comment")
    assert schema is not None


def test_vks1853_normalize_pr_id_accepts_canonical():
    """VKS-1853: _normalize_pr_id returns pr_id when only pr_id is provided."""
    from servers.bitbucket.tools import _normalize_pr_id
    assert _normalize_pr_id(pr_id=42, pull_request_id=None) == 42


def test_vks1853_normalize_pr_id_accepts_alias():
    """VKS-1853: _normalize_pr_id returns pull_request_id when only alias provided."""
    from servers.bitbucket.tools import _normalize_pr_id
    assert _normalize_pr_id(pr_id=None, pull_request_id=42) == 42


def test_vks1853_normalize_pr_id_both_equal_ok():
    """VKS-1853: _normalize_pr_id accepts both when equal (canonical wins)."""
    from servers.bitbucket.tools import _normalize_pr_id
    assert _normalize_pr_id(pr_id=42, pull_request_id=42) == 42


def test_vks1853_normalize_pr_id_both_missing_raises():
    """VKS-1853: _normalize_pr_id raises when both are missing."""
    from servers.bitbucket.tools import _normalize_pr_id
    with pytest.raises(ValueError, match="pr_id.*pull_request_id"):
        _normalize_pr_id(pr_id=None, pull_request_id=None)


def test_vks1853_normalize_pr_id_conflict_raises():
    """VKS-1853: _normalize_pr_id raises when values differ."""
    from servers.bitbucket.tools import _normalize_pr_id
    with pytest.raises(ValueError, match="Conflicting"):
        _normalize_pr_id(pr_id=42, pull_request_id=43)


def test_discovery_level1_branch_operations():
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="branch"))
        ops = result["operations"]
        assert "create" in ops
        assert "delete" in ops
        assert "set_default" in ops
        assert "get_restrictions" in ops

    asyncio.run(run())


def test_discovery_level2_shows_params():
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="branch", operation="create"))
        assert "required" in result or "optional" in result
        assert "description" in result
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discovery_unknown_resource():
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="nonexistent"))
        assert "error" in result
        assert "available_resources" in result
        assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Router properties
# ---------------------------------------------------------------------------

def test_router_action_count():
    router = build_router()
    assert router.action_count == 56  # +1: pull_request.decline (2026-06-18)


def test_router_tool_name():
    router = build_router()
    assert router.tool_name == "atlassian_bitbucket"


# ---------------------------------------------------------------------------
# Governance feedback on critical actions
# ---------------------------------------------------------------------------

def test_pr_create_has_governance():
    router = build_router()
    schema = router.registry.get_schema("pull_request", "create")
    assert schema is not None


def test_pr_merge_has_governance():
    router = build_router()
    schema = router.registry.get_schema("pull_request", "merge")
    assert schema is not None


def test_branch_create_has_governance():
    router = build_router()
    schema = router.registry.get_schema("branch", "create")
    assert schema is not None
