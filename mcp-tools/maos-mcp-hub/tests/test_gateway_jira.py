"""Tests for Jira gateway — 23 actions via meta-tool pattern."""

import asyncio

import httpx
import pytest
import respx

from gateways.jira.actions import build_router, estimate_story_points
from lib.gateway.types import GatewayRequest
from lib.jira.client import JiraClient

CLOUD_ID = "023bcd49-f455-4451-a096-c50c42c811d7"
BASE = f"https://api.atlassian.com/ex/jira/{CLOUD_ID}/rest/api/3"
AGILE = f"https://api.atlassian.com/ex/jira/{CLOUD_ID}/rest/agile/1.0"


def _setup_env(monkeypatch):
    monkeypatch.setenv("JIRA_EMAIL", "dev@example.com")
    monkeypatch.setenv("JIRA_CLOUD_ID", CLOUD_ID)
    monkeypatch.setenv("JIRA_API_TOKEN", "test-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)
    # Reset singleton
    import gateways.jira.actions as mod
    mod._client = None


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def test_discovery_level0_lists_resources(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        assert "resources" in result
        resources = result["resources"]
        assert "issue" in resources
        assert "search" in resources
        assert "comment" in resources
        assert "estimation" in resources
        assert "project" in resources
        assert "user" in resources

    asyncio.run(run())


def test_discovery_level1_issue_operations(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="issue"))
        ops = result["operations"]
        assert "get" in ops
        assert "create" in ops
        assert "edit" in ops
        assert "transition" in ops
        assert "get_transitions" in ops

    asyncio.run(run())


def test_discovery_level2_issue_create_schema(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="issue", operation="create"))
        assert "required" in result
        assert "project_key" in result["required"]
        assert "issue_type" in result["required"]
        assert "summary" in result["required"]
        assert "optional" in result
        assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — issue.get
# ---------------------------------------------------------------------------

def test_execution_issue_get(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/issue/VKS-1234").mock(return_value=httpx.Response(200, json={
                "key": "VKS-1234", "id": "12345",
                "fields": {
                    "summary": "Test issue", "status": {"name": "TO DO"},
                    "assignee": {"displayName": "Dev"}, "reporter": {"displayName": "PM"},
                    "issuetype": {"name": "Task"}, "priority": {"name": "Alta"},
                    "labels": [], "created": "2026-04-08", "updated": "2026-04-08",
                    "description": None,
                }
            }))

            result = await router.dispatch(GatewayRequest(
                resource="issue", operation="get", params={"issue_key": "VKS-1234"}
            ))
            assert result["key"] == "VKS-1234"
            assert result["status"] == "TO DO"
            assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — issue.create
# ---------------------------------------------------------------------------

def test_execution_issue_create(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.post(f"{BASE}/issue").mock(return_value=httpx.Response(201, json={
                "id": "99", "key": "VKS-999", "self": "..."
            }))

            result = await router.dispatch(GatewayRequest(
                resource="issue", operation="create",
                params={"project_key": "VKS", "issue_type": "Task", "summary": "Test"}
            ))
            assert result["key"] == "VKS-999"
            assert "_agent_feedback" in result
            fb = result["_agent_feedback"]
            assert "governance_level obrigatorio" in fb.get("governance", [])

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — search.jql
# ---------------------------------------------------------------------------

def test_execution_search_jql(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/search").mock(return_value=httpx.Response(200, json={
                "issues": [{"key": "VKS-1"}], "total": 1, "startAt": 0, "maxResults": 50,
            }))

            result = await router.dispatch(GatewayRequest(
                resource="search", operation="jql",
                params={"jql": "project = VKS", "max_results": 50, "start_at": 0}
            ))
            assert "issues" in result
            assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — estimation.calculate (estimate_story_points)
# ---------------------------------------------------------------------------

def test_estimate_story_points_dry_run(monkeypatch):
    _setup_env(monkeypatch)

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/issue/VKS-100").mock(return_value=httpx.Response(200, json={
                "key": "VKS-100",
                "fields": {
                    "subtasks": [{"id": "1"}, {"id": "2"}],
                    "attachment": [],
                    "comment": {"total": 3},
                    "issuelinks": [{"id": "1"}],
                    "description": {"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Short desc"}]}]},
                    "labels": [],
                    "issuetype": {"name": "Task"},
                }
            }))

            result = await estimate_story_points(issue_key="VKS-100", board_id=59, dry_run=True)
            assert "estimated_sp" in result
            assert result["estimated_sp"] in [1, 2, 3, 5, 8, 13]
            assert result["applied"] is False
            assert "breakdown" in result

    asyncio.run(run())


def test_estimate_story_points_complex_issue(monkeypatch):
    _setup_env(monkeypatch)

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/issue/VKS-200").mock(return_value=httpx.Response(200, json={
                "key": "VKS-200",
                "fields": {
                    "subtasks": [{"id": str(i)} for i in range(8)],  # 8 subtasks = +3
                    "attachment": [{"id": "1"}, {"id": "2"}, {"id": "3"}, {"id": "4"}, {"id": "5"}],  # 5 = +1
                    "comment": {"total": 10},  # 10 = +1
                    "issuelinks": [{"id": "1"}, {"id": "2"}, {"id": "3"}, {"id": "4"}],  # 4 = +1
                    "description": {"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "x" * 3000}]}]},  # >2000 = +1
                    "labels": ["security"],  # bonus +1
                    "issuetype": {"name": "Epic"},  # ×1.5
                }
            }))

            result = await estimate_story_points(issue_key="VKS-200", board_id=59, dry_run=True)
            # base(1) + sub(3) + att(1) + com(1) + link(1) + desc(1) + label(1) = 9 × 1.5 = 13.5 → snap to 13
            assert result["estimated_sp"] == 13
            assert result["raw_score"] == 13.5

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Router properties
# ---------------------------------------------------------------------------

def test_jira_router_action_count(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()
    assert router.action_count == 22


def test_jira_router_tool_name(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()
    assert router.tool_name == "atlassian_jira"
