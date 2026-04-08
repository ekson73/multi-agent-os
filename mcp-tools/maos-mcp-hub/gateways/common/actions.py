"""Common gateway actions — 4 cross-cutting actions."""

from __future__ import annotations

import base64
import os

from lib.common.http import request_json
from lib.gateway.router import MetaToolRouter
from .gateway import GATEWAY_INFO


async def get_user_info() -> dict:
    """Get current authenticated user info."""
    email = os.getenv("JIRA_EMAIL", "")
    token = os.getenv("JIRA_API_TOKEN") or os.getenv("ATLASSIAN_API_TOKEN") or ""
    cloud_id = os.getenv("JIRA_CLOUD_ID", "")
    if not token or not email:
        return {"error": "Missing credentials"}
    if not cloud_id:
        return {"error": "Missing JIRA_CLOUD_ID"}
    creds = base64.b64encode(f"{email}:{token}".encode()).decode()
    return await request_json(
        method="GET",
        url=f"https://api.atlassian.com/ex/jira/{cloud_id}/rest/api/3/myself",
        provider="Atlassian", auth_hint="Check credentials.",
        auth_kwargs={"headers": {"Authorization": f"Basic {creds}"}},
        timeout=30.0,
    )


async def get_accessible_resources() -> dict:
    """List accessible Atlassian cloud resources.

    Note: This endpoint officially requires OAuth 2.0. With Basic Auth (API token)
    it may return 401. Use get_user_info or get_server_info as alternatives.
    """
    email = os.getenv("JIRA_EMAIL", "")
    token = os.getenv("JIRA_API_TOKEN") or os.getenv("ATLASSIAN_API_TOKEN") or ""
    if not token or not email:
        return {"error": "Missing credentials"}
    creds = base64.b64encode(f"{email}:{token}".encode()).decode()
    result = await request_json(
        method="GET",
        url="https://api.atlassian.com/oauth/token/accessible-resources",
        provider="Atlassian",
        auth_hint="This endpoint requires OAuth 2.0. Basic Auth may fail — use get_user_info instead.",
        auth_kwargs={"headers": {"Authorization": f"Basic {creds}"}},
        timeout=30.0,
    )
    return {"resources": result} if isinstance(result, list) else result


async def lookup_user(query: str) -> dict:
    """Search for Atlassian users by name or email."""
    email = os.getenv("JIRA_EMAIL", "")
    token = os.getenv("JIRA_API_TOKEN") or os.getenv("ATLASSIAN_API_TOKEN") or ""
    cloud_id = os.getenv("JIRA_CLOUD_ID", "")
    if not token or not email:
        return {"error": "Missing credentials"}
    if not cloud_id:
        return {"error": "Missing JIRA_CLOUD_ID"}
    creds = base64.b64encode(f"{email}:{token}".encode()).decode()
    return await request_json(
        method="GET",
        url=f"https://api.atlassian.com/ex/jira/{cloud_id}/rest/api/3/user/search",
        provider="Atlassian", auth_hint="Check credentials.",
        auth_kwargs={"headers": {"Authorization": f"Basic {creds}"}},
        params={"query": query}, timeout=30.0,
    )


async def get_server_info() -> dict:
    """Get Jira server info (version, URLs)."""
    email = os.getenv("JIRA_EMAIL", "")
    token = os.getenv("JIRA_API_TOKEN") or os.getenv("ATLASSIAN_API_TOKEN") or ""
    cloud_id = os.getenv("JIRA_CLOUD_ID", "")
    if not token or not email:
        return {"error": "Missing credentials"}
    if not cloud_id:
        return {"error": "Missing JIRA_CLOUD_ID"}
    creds = base64.b64encode(f"{email}:{token}".encode()).decode()
    return await request_json(
        method="GET",
        url=f"https://api.atlassian.com/ex/jira/{cloud_id}/rest/api/3/serverInfo",
        provider="Atlassian", auth_hint="Check credentials.",
        auth_kwargs={"headers": {"Authorization": f"Basic {creds}"}},
        timeout=30.0,
    )


def build_router() -> MetaToolRouter:
    router = MetaToolRouter(tool_name=GATEWAY_INFO["tool_name"])
    router.register("user", "info", get_user_info, description="Get current user info")
    router.register("user", "search", lookup_user, description="Search users by name/email")
    router.register("resource", "list", get_accessible_resources, description="List accessible cloud resources")
    router.register("server", "info", get_server_info, description="Get server info")
    return router
