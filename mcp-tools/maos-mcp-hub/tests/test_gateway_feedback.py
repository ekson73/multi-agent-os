"""Tests for the feedback decorator — _agent_feedback injection."""

import asyncio
from typing import Any, Dict

import pytest

from lib.common.errors import ApiError, AuthError, NotFoundError
from lib.gateway.feedback import with_feedback
from lib.gateway.types import AgentFeedback


# ---------------------------------------------------------------------------
# Success responses
# ---------------------------------------------------------------------------

def test_feedback_on_success_dict():
    @with_feedback("atlassian_jira", "issue", "get")
    async def handler(issue_key: str) -> Dict[str, Any]:
        return {"key": issue_key, "summary": "Test"}

    async def run():
        result = await handler(issue_key="VKS-1")
        assert result["key"] == "VKS-1"
        assert "_agent_feedback" in result
        fb = result["_agent_feedback"]
        assert fb["tool"] == "atlassian_jira"
        assert fb["resource"] == "issue"
        assert fb["operation"] == "get"

    asyncio.run(run())


def test_feedback_includes_governance():
    @with_feedback("atlassian_jira", "issue", "create",
                   governance=["governance_level obrigatorio"])
    async def handler(project_key: str, summary: str) -> Dict[str, Any]:
        return {"key": f"{project_key}-1", "summary": summary}

    async def run():
        result = await handler(project_key="VKS", summary="Test")
        fb = result["_agent_feedback"]
        assert "governance_level obrigatorio" in fb["governance"]

    asyncio.run(run())


def test_feedback_includes_next_steps():
    @with_feedback("atlassian_jira", "issue", "create",
                   next_steps=["Add DARCI roles"])
    async def handler(project_key: str, summary: str) -> Dict[str, Any]:
        return {"key": f"{project_key}-1"}

    async def run():
        result = await handler(project_key="VKS", summary="Test")
        fb = result["_agent_feedback"]
        assert "Add DARCI roles" in fb["next_steps"]

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Error responses (dict with "error" key)
# ---------------------------------------------------------------------------

def test_feedback_on_error_dict():
    @with_feedback("atlassian_jira", "issue", "get")
    async def handler(issue_key: str) -> Dict[str, Any]:
        return {"error": "Not found", "status_code": 404}

    async def run():
        result = await handler(issue_key="VKS-9999")
        assert "error" in result
        assert "_agent_feedback" in result
        fb = result["_agent_feedback"]
        assert any("not found" in h.lower() for h in fb.get("hints", []))

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Exception handling
# ---------------------------------------------------------------------------

def test_feedback_catches_api_error():
    @with_feedback("atlassian_jira", "issue", "get")
    async def handler(issue_key: str) -> Dict[str, Any]:
        raise AuthError(
            message="Unauthorized",
            status_code=401,
            endpoint="/issue/VKS-1",
            provider="Jira",
            hint="Check JIRA_EMAIL",
        )

    async def run():
        result = await handler(issue_key="VKS-1")
        assert "error" in result
        assert result["status_code"] == 401
        assert "_agent_feedback" in result
        fb = result["_agent_feedback"]
        assert any("credentials" in h.lower() for h in fb.get("hints", []))

    asyncio.run(run())


def test_feedback_catches_unexpected_exception():
    @with_feedback("atlassian_jira", "issue", "get")
    async def handler(issue_key: str) -> Dict[str, Any]:
        raise ValueError("something broke")

    async def run():
        result = await handler(issue_key="VKS-1")
        assert "error" in result
        assert "_agent_feedback" in result
        fb = result["_agent_feedback"]
        assert any("retry" in h.lower() for h in fb.get("hints", []))

    asyncio.run(run())


# ---------------------------------------------------------------------------
# AgentFeedback type
# ---------------------------------------------------------------------------

def test_agent_feedback_to_dict_minimal():
    fb = AgentFeedback(tool="atlassian_jira")
    d = fb.to_dict()
    assert d == {"tool": "atlassian_jira"}


def test_agent_feedback_to_dict_full():
    fb = AgentFeedback(
        tool="atlassian_jira",
        resource="issue",
        operation="create",
        hints=["Use estimate_story_points"],
        governance=["governance_level obrigatorio"],
        next_steps=["Add DARCI roles"],
    )
    d = fb.to_dict()
    assert d["resource"] == "issue"
    assert d["operation"] == "create"
    assert len(d["hints"]) == 1
    assert len(d["governance"]) == 1
    assert len(d["next_steps"]) == 1
