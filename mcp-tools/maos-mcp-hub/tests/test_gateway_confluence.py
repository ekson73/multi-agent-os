"""Tests for Confluence gateway — 12 actions via meta-tool pattern."""

import asyncio

import httpx
import pytest
import respx

from gateways.confluence.actions import build_router
from lib.confluence.client import ConfluenceClient
from lib.gateway.types import GatewayRequest

CLOUD_ID = "023bcd49-f455-4451-a096-c50c42c811d7"
BASE = f"https://api.atlassian.com/ex/confluence/{CLOUD_ID}/wiki/api/v2"
SEARCH_BASE = f"https://api.atlassian.com/ex/confluence/{CLOUD_ID}/wiki/rest/api/search"


def _setup_env(monkeypatch):
    monkeypatch.setenv("JIRA_EMAIL", "dev@example.com")
    monkeypatch.setenv("JIRA_CLOUD_ID", CLOUD_ID)
    monkeypatch.setenv("JIRA_API_TOKEN", "test-token")
    monkeypatch.delenv("CONFLUENCE_API_TOKEN", raising=False)
    monkeypatch.delenv("CONFLUENCE_CLOUD_ID", raising=False)
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)
    import gateways.confluence.actions as mod
    mod._client = None


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def test_discovery_level0(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        assert "resources" in result
        assert "page" in result["resources"]
        assert "space" in result["resources"]
        assert "comment" in result["resources"]
        assert "search" in result["resources"]
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discovery_level1_page(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="page"))
        ops = result["operations"]
        assert "get" in ops
        assert "create" in ops
        assert "update" in ops
        assert "list_in_space" in ops
        assert "get_descendants" in ops

    asyncio.run(run())


def test_discovery_level2_page_create(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest(resource="page", operation="create"))
        assert "required" in result
        assert "space_id" in result["required"]
        assert "title" in result["required"]
        assert "body" in result["required"]
        assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — page.get
# ---------------------------------------------------------------------------

def test_execution_page_get(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/pages/12345").mock(return_value=httpx.Response(200, json={
                "id": "12345", "title": "Test Page", "status": "current",
                "version": {"number": 3},
            }))
            result = await router.dispatch(GatewayRequest(
                resource="page", operation="get", params={"page_id": "12345"}
            ))
            assert result["id"] == "12345"
            assert result["title"] == "Test Page"
            assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — page.create
# ---------------------------------------------------------------------------

def test_execution_page_create(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.post(f"{BASE}/pages").mock(return_value=httpx.Response(200, json={
                "id": "99999", "title": "New Page", "status": "current",
            }))
            result = await router.dispatch(GatewayRequest(
                resource="page", operation="create",
                params={"space_id": "STG", "title": "New Page", "body": "<p>Content</p>"}
            ))
            assert result["id"] == "99999"
            assert "_agent_feedback" in result
            fb = result["_agent_feedback"]
            assert any("DPIA" in g for g in fb.get("governance", []))

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — search.cql
# ---------------------------------------------------------------------------

def test_execution_search_cql(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(SEARCH_BASE).mock(return_value=httpx.Response(200, json={
                "results": [{"title": "Found"}], "totalSize": 1,
            }))
            result = await router.dispatch(GatewayRequest(
                resource="search", operation="cql",
                params={"cql": "type=page AND space=STG"}
            ))
            assert "results" in result
            assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Execution — space.list
# ---------------------------------------------------------------------------

def test_execution_space_list(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()

    async def run():
        with respx.mock(assert_all_called=True) as mock:
            mock.get(f"{BASE}/spaces").mock(return_value=httpx.Response(200, json={
                "results": [{"id": "STG", "name": "Staging"}],
            }))
            result = await router.dispatch(GatewayRequest(
                resource="space", operation="list", params={}
            ))
            assert "results" in result
            assert "_agent_feedback" in result

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Router properties
# ---------------------------------------------------------------------------

def test_router_action_count(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()
    assert router.action_count == 12


def test_router_tool_name(monkeypatch):
    _setup_env(monkeypatch)
    router = build_router()
    assert router.tool_name == "atlassian_confluence"


# ---------------------------------------------------------------------------
# Client — credential fallback
# ---------------------------------------------------------------------------

def test_confluence_uses_jira_cloud_id_fallback(monkeypatch):
    monkeypatch.setenv("JIRA_EMAIL", "dev@example.com")
    monkeypatch.setenv("JIRA_API_TOKEN", "token")
    monkeypatch.setenv("JIRA_CLOUD_ID", CLOUD_ID)
    monkeypatch.delenv("CONFLUENCE_CLOUD_ID", raising=False)
    monkeypatch.delenv("CONFLUENCE_API_TOKEN", raising=False)
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    client = ConfluenceClient()
    assert client.cloud_id == CLOUD_ID
    assert "confluence" in client.base_url
