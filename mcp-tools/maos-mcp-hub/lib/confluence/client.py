"""
HTTP client for Confluence Cloud REST API v2

Same pattern as JiraClient: Basic Auth, httpx async, AsyncLimiter.
Shares JIRA_EMAIL + ATLASSIAN_API_TOKEN credentials.
"""

import base64
import os
from typing import Optional

from aiolimiter import AsyncLimiter

from lib.common.http import request_empty, request_json


class ConfluenceClient:
    """Async HTTP client for Confluence Cloud REST API v2."""

    def __init__(self, cloud_id: Optional[str] = None):
        self.email = os.getenv("JIRA_EMAIL")
        self.api_token = (
            os.getenv("CONFLUENCE_API_TOKEN")
            or os.getenv("ATLASSIAN_API_TOKEN")
            or os.getenv("JIRA_API_TOKEN")
        )
        self.cloud_id = cloud_id or os.getenv("CONFLUENCE_CLOUD_ID") or os.getenv("JIRA_CLOUD_ID")

        if not self.api_token:
            raise ValueError("Missing token. Set CONFLUENCE_API_TOKEN, ATLASSIAN_API_TOKEN, or JIRA_API_TOKEN.")
        if not self.email:
            raise ValueError("Missing JIRA_EMAIL (Atlassian account email).")
        if not self.cloud_id:
            raise ValueError("Missing CONFLUENCE_CLOUD_ID or JIRA_CLOUD_ID.")

        self.base_url = f"https://api.atlassian.com/ex/confluence/{self.cloud_id}/wiki/api/v2"
        self._provider_name = "Confluence"
        self._auth_hint = "Verifique JIRA_EMAIL e API token (CONFLUENCE/ATLASSIAN/JIRA)."
        self.rate_limiter = AsyncLimiter(max_rate=300, time_period=3600)

        credentials = base64.b64encode(f"{self.email}:{self.api_token}".encode()).decode()
        self._auth_kwargs = {"headers": {"Authorization": f"Basic {credentials}"}}

    # ------------------------------------------------------------------
    # Pages
    # ------------------------------------------------------------------

    async def get_page(self, page_id: str) -> dict:
        """Get page by ID with body and version."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pages/{page_id}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"body-format": "storage"},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def create_page(self, space_id: str, title: str, body: str, parent_id: str = "", status: str = "current") -> dict:
        """Create a page in a space."""
        payload: dict = {
            "spaceId": space_id,
            "status": status,
            "title": title,
            "body": {"representation": "storage", "value": body},
        }
        if parent_id:
            payload["parentId"] = parent_id
        return await request_json(
            method="POST",
            url=f"{self.base_url}/pages",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    async def update_page(self, page_id: str, title: str, body: str, version_number: int, status: str = "current") -> dict:
        """Update a page (requires current version number)."""
        return await request_json(
            method="PUT",
            url=f"{self.base_url}/pages/{page_id}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={
                "id": page_id,
                "status": status,
                "title": title,
                "body": {"representation": "storage", "value": body},
                "version": {"number": version_number, "message": "Updated via maos-mcp-hub"},
            },
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    async def get_pages_in_space(self, space_id: str, limit: int = 25) -> dict:
        """List pages in a space."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/spaces/{space_id}/pages",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"limit": limit},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_page_descendants(self, page_id: str) -> dict:
        """Get child pages of a page."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pages/{page_id}/children",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    # ------------------------------------------------------------------
    # Spaces
    # ------------------------------------------------------------------

    async def get_spaces(self, limit: int = 25) -> dict:
        """List available spaces."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/spaces",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"limit": limit},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    # ------------------------------------------------------------------
    # Comments
    # ------------------------------------------------------------------

    async def get_footer_comments(self, page_id: str) -> dict:
        """Get footer comments for a page."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pages/{page_id}/footer-comments",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_inline_comments(self, page_id: str) -> dict:
        """Get inline comments for a page."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pages/{page_id}/inline-comments",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def create_footer_comment(self, page_id: str, body: str) -> dict:
        """Create a footer comment on a page."""
        return await request_json(
            method="POST",
            url=f"{self.base_url}/footer-comments",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={"pageId": page_id, "body": {"representation": "storage", "value": body}},
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    async def create_inline_comment(self, page_id: str, body: str, inline_comment_properties: dict = None) -> dict:
        """Create an inline comment on a page."""
        payload: dict = {"pageId": page_id, "body": {"representation": "storage", "value": body}}
        if inline_comment_properties:
            payload["inlineCommentProperties"] = inline_comment_properties
        return await request_json(
            method="POST",
            url=f"{self.base_url}/inline-comments",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    async def get_comment_children(self, comment_id: str) -> dict:
        """Get child comments of a comment."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/comments/{comment_id}/children",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    # ------------------------------------------------------------------
    # Search
    # ------------------------------------------------------------------

    async def search_cql(self, cql: str, limit: int = 25) -> dict:
        """Search Confluence using CQL."""
        return await request_json(
            method="GET",
            url=f"https://api.atlassian.com/ex/confluence/{self.cloud_id}/wiki/rest/api/search",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"cql": cql, "limit": limit},
            timeout=30.0,
            limiter=self.rate_limiter,
        )
