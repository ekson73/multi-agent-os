"""Tests for Jira gateway — 27 actions via meta-tool pattern."""

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
    """Uses new /search/jql endpoint (VKO-88 migration — CHANGE-2046)."""
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/search/jql").mock(return_value=httpx.Response(200, json={
                "issues": [{"key": "VKS-1"}],
                "nextPageToken": "abc123",
                "isLast": False,
            }))

            result = await router.dispatch(GatewayRequest(
                resource="search", operation="jql",
                params={"jql": "project = VKS", "max_results": 50}
            ))
            assert "issues" in result
            assert result.get("nextPageToken") == "abc123"
            assert "_agent_feedback" in result

    asyncio.run(run())


def test_execution_search_jql_with_pagination_and_fields(monkeypatch):
    """New endpoint honors next_page_token + fields + expand params."""
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            route = mock.get(f"{BASE}/search/jql").mock(
                return_value=httpx.Response(200, json={
                    "issues": [], "isLast": True,
                }),
            )

            await router.dispatch(GatewayRequest(
                resource="search", operation="jql",
                params={
                    "jql": "project = VKS",
                    "max_results": 25,
                    "next_page_token": "xyz789",
                    "fields": ["summary", "status"],
                    "expand": "changelog",
                },
            ))

            # Verify query params sent to Jira
            assert route.called
            request = route.calls.last.request
            assert request.url.params["jql"] == "project = VKS"
            assert request.url.params["maxResults"] == "25"
            assert request.url.params["nextPageToken"] == "xyz789"
            assert request.url.params["fields"] == "summary,status"
            assert request.url.params["expand"] == "changelog"

    asyncio.run(run())


def test_execution_search_jql_no_deprecated_startat_sent(monkeypatch):
    """Regression guard: ensure `startAt` is never sent to /search/jql (deprecated)."""
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            route = mock.get(f"{BASE}/search/jql").mock(
                return_value=httpx.Response(200, json={"issues": [], "isLast": True}),
            )

            await router.dispatch(GatewayRequest(
                resource="search", operation="jql",
                params={"jql": "project = VKS"},
            ))

            request = route.calls.last.request
            assert "startAt" not in request.url.params, (
                "startAt must NOT be sent to /search/jql (removed in CHANGE-2046)"
            )
            assert "nextPageToken" not in request.url.params, (
                "nextPageToken should be omitted when empty (first page)"
            )

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
    assert router.action_count == 27


def test_jira_router_tool_name(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()
    assert router.tool_name == "atlassian_jira"


# ---------------------------------------------------------------------------
# VKS-1853 Gap 8: priority field for issue type "Intervenção Técnica - I.A."
# ---------------------------------------------------------------------------

def test_vks1853_create_issue_serializes_priority(monkeypatch):
    """VKS-1853: create_issue with priority serializes as {name: value}."""
    _setup_env(monkeypatch)
    from gateways.jira.actions import create_issue

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            route = mock.post(f"{BASE}/issue").mock(
                return_value=httpx.Response(201, json={
                    "id": "12345",
                    "key": "VKS-2000",
                })
            )
            result = await create_issue(
                project_key="VKS",
                issue_type="Story",
                summary="test priority",
                priority="Medium",
            )
            assert result["key"] == "VKS-2000"
            import json as _json
            payload = _json.loads(route.calls.last.request.content)
            assert payload["fields"]["priority"] == {"name": "Medium"}

    asyncio.run(run())


def test_vks1853_create_issue_without_priority_omits_field(monkeypatch):
    """VKS-1853: create_issue without priority must NOT include priority key."""
    _setup_env(monkeypatch)
    from gateways.jira.actions import create_issue

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            route = mock.post(f"{BASE}/issue").mock(
                return_value=httpx.Response(201, json={"id": "12346", "key": "VKS-2001"})
            )
            await create_issue(
                project_key="VKS",
                issue_type="Intervenção Técnica - I.A.",
                summary="no priority",
            )
            import json as _json
            payload = _json.loads(route.calls.last.request.content)
            assert "priority" not in payload["fields"]

    asyncio.run(run())


def test_vks1853_create_issue_priority_rejected_surfaces_hint(monkeypatch):
    """VKS-1853: when priority is rejected by screen scheme, return helpful hint."""
    _setup_env(monkeypatch)
    from gateways.jira.actions import create_issue

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.post(f"{BASE}/issue").mock(
                return_value=httpx.Response(400, json={
                    "errorMessages": [],
                    "errors": {
                        "priority": "Field 'priority' cannot be set. It is not on the appropriate screen, or unknown."
                    }
                })
            )
            result = await create_issue(
                project_key="VKS",
                issue_type="Intervenção Técnica - I.A.",
                summary="meta-test of gap 8",
                priority="Medium",
            )
            assert "error" in result
            assert result.get("screen_scheme_hint") is True
            assert result["rejected_priority"] == "Medium"
            assert result["issue_type"] == "Intervenção Técnica - I.A."
            hint = result["hint"].lower()
            assert "screen" in hint

    asyncio.run(run())


def test_vks1853_create_issue_non_priority_error_reraises(monkeypatch):
    """VKS-1853: non-priority errors must propagate (not be swallowed)."""
    _setup_env(monkeypatch)
    from gateways.jira.actions import create_issue

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.post(f"{BASE}/issue").mock(
                return_value=httpx.Response(500, text='{"errorMessages":["server error"]}')
            )
            raised = False
            try:
                await create_issue(
                    project_key="VKS",
                    issue_type="Story",
                    summary="server error case",
                )
            except Exception:
                raised = True
            assert raised, "Non-priority errors must propagate (not be swallowed)."

    asyncio.run(run())
