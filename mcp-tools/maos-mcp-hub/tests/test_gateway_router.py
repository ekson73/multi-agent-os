"""Tests for the gateway router — dispatch and discovery at all levels."""

import asyncio
from typing import Any, Dict

import pytest

from lib.gateway.router import MetaToolRouter
from lib.gateway.types import GatewayRequest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _mock_get_issue(issue_key: str, format: str = "markdown") -> Dict[str, Any]:
    """Mock handler for issue.get."""
    return {"key": issue_key, "summary": "Test issue", "format": format}


async def _mock_create_issue(project_key: str, summary: str, issue_type: str = "Task") -> Dict[str, Any]:
    """Mock handler for issue.create."""
    return {"key": f"{project_key}-999", "summary": summary, "type": issue_type}


async def _mock_list_boards(project_key: str = "") -> Dict[str, Any]:
    """Mock handler for board.list."""
    return {"boards": [{"id": 59, "name": "VKS Dev"}]}


def _build_router() -> MetaToolRouter:
    """Build a test router with sample handlers."""
    router = MetaToolRouter(
        tool_name="atlassian_jira",
        governance=["governance_level obrigatorio ao criar issues"],
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
    router.register("board", "list", _mock_list_boards, description="List boards")
    return router


# ---------------------------------------------------------------------------
# Level 0 — Discovery: list resources
# ---------------------------------------------------------------------------

def test_discovery_level0_lists_resources():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        assert "resources" in result
        assert "issue" in result["resources"]
        assert "board" in result["resources"]
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discovery_level0_includes_feedback():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        fb = result["_agent_feedback"]
        assert fb["tool"] == "atlassian_jira"
        assert len(fb.get("governance", [])) > 0

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Level 1 — Discovery: list operations for resource
# ---------------------------------------------------------------------------

def test_discovery_level1_lists_operations():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="issue"))
        assert "operations" in result
        assert "get" in result["operations"]
        assert "create" in result["operations"]
        assert result["resource"] == "issue"
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discovery_level1_unknown_resource():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="nonexistent"))
        assert "error" in result
        assert "available_resources" in result
        assert "issue" in result["available_resources"]
        assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Level 2 — Discovery: show param schema
# ---------------------------------------------------------------------------

def test_discovery_level2_shows_schema():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="issue", operation="get"))
        assert "required" in result
        assert "issue_key" in result["required"]
        assert "optional" in result
        assert "format" in result["optional"]
        assert result["description"] == "Get issue by key"
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discovery_level2_unknown_operation():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="issue", operation="delete"))
        assert "error" in result
        assert "available_operations" in result
        assert "get" in result["available_operations"]
        assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Level 3 — Execution
# ---------------------------------------------------------------------------

def test_execution_get_issue():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(
            resource="issue", operation="get", params={"issue_key": "VKS-1234"}
        ))
        assert result["key"] == "VKS-1234"
        assert result["summary"] == "Test issue"
        assert "_agent_feedback" in result
        assert result["_agent_feedback"]["tool"] == "atlassian_jira"
        assert result["_agent_feedback"]["resource"] == "issue"
        assert result["_agent_feedback"]["operation"] == "get"

    asyncio.run(run())


def test_execution_create_issue_with_feedback():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(
            resource="issue",
            operation="create",
            params={"project_key": "VKS", "summary": "Test"},
        ))
        assert result["key"] == "VKS-999"
        fb = result["_agent_feedback"]
        assert "governance_level obrigatorio" in fb.get("governance", [])
        assert "Add DARCI roles after creating" in fb.get("next_steps", [])

    asyncio.run(run())


def test_execution_unknown_resource():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(
            resource="unknown", operation="get", params={"id": "1"}
        ))
        assert "error" in result
        assert "available_resources" in result
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_execution_unknown_operation():
    router = _build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(
            resource="issue", operation="destroy", params={"id": "1"}
        ))
        assert "error" in result
        assert "available_operations" in result
        assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Router properties
# ---------------------------------------------------------------------------

def test_router_resources():
    router = _build_router()
    assert "board" in router.resources
    assert "issue" in router.resources


def test_router_action_count():
    router = _build_router()
    assert router.action_count == 3  # get, create, list


# ---------------------------------------------------------------------------
# GatewayRequest parsing
# ---------------------------------------------------------------------------

def test_request_parse_empty():
    req = GatewayRequest.parse({})
    assert req.level == 0
    assert req.resource is None


def test_request_parse_resource_only():
    req = GatewayRequest.parse({"resource": "issue"})
    assert req.level == 1
    assert req.resource == "issue"
    assert req.operation is None


def test_request_parse_full():
    req = GatewayRequest.parse({
        "resource": "issue",
        "operation": "get",
        "params": {"issue_key": "VKS-1"},
    })
    assert req.level == 3
    assert req.params == {"issue_key": "VKS-1"}


def test_request_parse_empty_strings_treated_as_none():
    req = GatewayRequest.parse({"resource": "", "operation": ""})
    assert req.level == 0
    assert req.resource is None
