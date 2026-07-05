"""Tests for Discover gateway + Compass + Common + integration."""

import asyncio
import os

import pytest

from conftest import EXPECTED_GATEWAY_ACTIONS, EXPECTED_TOTAL_ACTIONS
from lib.gateway.types import GatewayRequest


def _setup_env(monkeypatch):
    monkeypatch.setenv("JIRA_EMAIL", "dev@example.com")
    monkeypatch.setenv("JIRA_CLOUD_ID", "023bcd49-f455-4451-a096-c50c42c811d7")
    monkeypatch.setenv("JIRA_API_TOKEN", "test-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)
    monkeypatch.delenv("CONFLUENCE_API_TOKEN", raising=False)
    monkeypatch.delenv("CONFLUENCE_CLOUD_ID", raising=False)
    monkeypatch.delenv("COMPASS_API_TOKEN", raising=False)
    monkeypatch.delenv("COMPASS_CLOUD_ID", raising=False)


# ---------------------------------------------------------------------------
# Discover
# ---------------------------------------------------------------------------

def test_discover_returns_all_domains(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.discover.actions import discover

    async def run():
        result = await discover()
        assert "domains" in result
        assert "jira" in result["domains"]
        assert "confluence" in result["domains"]
        assert "bitbucket" in result["domains"]
        assert "compass" in result["domains"]
        assert "common" in result["domains"]
        assert result["total_gateways"] == 5
        assert result["total_actions"] > 0
        assert "_agent_feedback" in result

    asyncio.run(run())


def test_discover_action_counts(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.discover.actions import discover

    async def run():
        result = await discover()
        d = result["domains"]
        # Per-gateway counts + total come from ONE SSOT (conftest, issue #202).
        for gateway, expected in EXPECTED_GATEWAY_ACTIONS.items():
            assert d[gateway]["actions"] == expected, (
                f"{gateway}: expected {expected}, got {d[gateway]['actions']}"
            )
        assert result["total_actions"] == EXPECTED_TOTAL_ACTIONS

    asyncio.run(run())


def test_discover_feedback_has_hints(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.discover.actions import discover

    async def run():
        result = await discover()
        fb = result["_agent_feedback"]
        assert len(fb["hints"]) >= 5
        assert any("jira" in h.lower() for h in fb["hints"])
        assert len(fb["governance"]) >= 1

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Compass gateway
# ---------------------------------------------------------------------------

def test_compass_discovery_level0(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.compass.actions import build_router

    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        assert "resources" in result
        assert "component" in result["resources"]
        assert "relationship" in result["resources"]
        assert "custom_field" in result["resources"]

    asyncio.run(run())


def test_compass_router_action_count(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.compass.actions import build_router
    router = build_router()
    assert router.action_count == 6


# ---------------------------------------------------------------------------
# Common gateway
# ---------------------------------------------------------------------------

def test_common_discovery_level0(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.common.actions import build_router

    router = build_router()

    async def run():
        result = await router.dispatch(GatewayRequest())
        assert "resources" in result
        assert "user" in result["resources"]
        assert "resource" in result["resources"]
        assert "server" in result["resources"]

    asyncio.run(run())


def test_common_router_action_count(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.common.actions import build_router
    router = build_router()
    assert router.action_count == 4


# ---------------------------------------------------------------------------
# Cross-gateway: total action count (SSOT: conftest.EXPECTED_TOTAL_ACTIONS)
# ---------------------------------------------------------------------------

def test_total_action_count_across_all_gateways(monkeypatch):
    _setup_env(monkeypatch)
    from gateways.jira.actions import build_router as jira_router
    from gateways.confluence.actions import build_router as conf_router
    from gateways.bitbucket.actions import build_router as bb_router
    from gateways.compass.actions import build_router as comp_router
    from gateways.common.actions import build_router as common_router

    total = (
        jira_router().action_count
        + conf_router().action_count
        + bb_router().action_count
        + comp_router().action_count
        + common_router().action_count
    )
    assert total == EXPECTED_TOTAL_ACTIONS, (
        f"Expected {EXPECTED_TOTAL_ACTIONS} total actions "
        f"(SSOT: tests/conftest.py EXPECTED_GATEWAY_ACTIONS), got {total}"
    )
