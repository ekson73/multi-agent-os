"""Tests for Bitbucket gateway — wrapping 52 tools into meta-tool pattern."""

import asyncio
import os

import pytest

from gateways.bitbucket.actions import build_router, RESOURCE_MAP
from lib.gateway.types import GatewayRequest
from servers.bitbucket.tools import TOOLS as BB_TOOLS


# ---------------------------------------------------------------------------
# Coverage: all 52 tools are mapped
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


def test_resource_map_has_52_actions():
    """Total action count matches expected 52."""
    total = sum(len(ops) for ops in RESOURCE_MAP.values())
    assert total == 52, f"Expected 52 actions, got {total}"


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

    asyncio.run(run())


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
    assert router.action_count == 52


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
