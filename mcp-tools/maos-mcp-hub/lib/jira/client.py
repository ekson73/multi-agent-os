"""
HTTP client for Jira Cloud REST API v3

This module provides an async HTTP client for interacting with the
Jira Cloud REST API to manage issues and attachments.

Authentication uses Basic Auth (email:api_token) as per Atlassian Cloud standard.
"""

import asyncio
import base64
import os
from typing import Optional
from aiolimiter import AsyncLimiter

from lib.common.http import request_bytes, request_empty, request_json


def _read_file_bytes(path: str) -> bytes:
    with open(path, "rb") as fh:
        return fh.read()


class JiraClient:
    """
    Async HTTP client for Jira Cloud REST API v3

    Handles authentication, API calls, and response parsing.
    Uses Basic Auth with email + API token (Atlassian Cloud standard).

    Environment variables:
        JIRA_EMAIL: Atlassian account email
        JIRA_API_TOKEN: Jira-specific API token (preferred)
        ATLASSIAN_API_TOKEN: Shared fallback token for Jira/Confluence (optional)
        JIRA_CLOUD_ID: Cloud instance ID (UUID format)
    """

    def __init__(self, cloud_id: Optional[str] = None):
        """
        Initialize the Jira client

        Args:
            cloud_id: Optional cloud ID override.
                      If not provided, uses JIRA_CLOUD_ID env var.

        Raises:
            ValueError: If required environment variables are missing
        """
        self.email = os.getenv("JIRA_EMAIL")
        self.api_token = os.getenv("JIRA_API_TOKEN") or os.getenv("ATLASSIAN_API_TOKEN")
        self.cloud_id = cloud_id or os.getenv("JIRA_CLOUD_ID")

        if not self.api_token:
            raise ValueError(
                "Missing required Jira token. Set JIRA_API_TOKEN "
                "(preferred) or ATLASSIAN_API_TOKEN (fallback). "
                "Generate at https://id.atlassian.com/manage-profile/security/api-tokens"
            )
        if not self.email:
            raise ValueError(
                "Missing required JIRA_EMAIL (Atlassian account email)."
            )
        if not self.cloud_id:
            raise ValueError(
                "Missing required JIRA_CLOUD_ID (Cloud instance UUID)."
            )

        self.base_url = f"https://api.atlassian.com/ex/jira/{self.cloud_id}/rest/api/3"
        self.agile_url = f"https://api.atlassian.com/ex/jira/{self.cloud_id}/rest/agile/1.0"
        self._provider_name = "Jira"
        self._auth_hint = (
            "Verifique JIRA_EMAIL e JIRA_API_TOKEN (ou ATLASSIAN_API_TOKEN fallback)."
        )

        # Rate limiter: 300 requests per hour (conservative for Jira Cloud)
        self.rate_limiter = AsyncLimiter(max_rate=300, time_period=3600)

        # Pre-compute Basic Auth header
        credentials = base64.b64encode(
            f"{self.email}:{self.api_token}".encode()
        ).decode()
        self._auth_kwargs = {
            "headers": {"Authorization": f"Basic {credentials}"}
        }

    # ========================================================================
    # Issues API
    # ========================================================================

    async def get_issue(self, issue_key: str, fields: Optional[str] = None) -> dict:
        """
        Get detailed information about a specific issue

        Args:
            issue_key: Issue key (e.g., "VKS-1134")
            fields: Comma-separated list of fields to return (optional).
                    If not provided, returns all navigable fields.

        Returns:
            dict: Issue data with key, fields (summary, description, status, etc.)

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        params = {}
        if fields:
            params["fields"] = fields

        return await request_json(
            method="GET",
            url=f"{self.base_url}/issue/{issue_key}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params=params,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    # ========================================================================
    # Attachments API
    # ========================================================================

    async def list_attachments(self, issue_key: str) -> list:
        """
        List all attachments for an issue

        Args:
            issue_key: Issue key (e.g., "VKS-1134")

        Returns:
            list: Array of attachment objects with id, filename, size, content URL
                  Format: [
                      {
                          "id": "10001",
                          "filename": "v1-structured.md",
                          "size": 12345,
                          "mimeType": "text/markdown",
                          "content": "https://api.atlassian.com/...",
                          "created": "2026-02-20T10:00:00.000+0000",
                          "author": {"displayName": "..."}
                      }
                  ]

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        issue = await self.get_issue(issue_key, fields="attachment")
        return issue.get("fields", {}).get("attachment", [])

    async def download_attachment(self, attachment_id: str) -> bytes:
        """
        Download attachment content by ID

        Args:
            attachment_id: Attachment ID (numeric string)

        Returns:
            bytes: Raw file content

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        # First get attachment metadata to resolve the content URL.
        metadata = await request_json(
            method="GET",
            url=f"{self.base_url}/attachment/{attachment_id}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

        content_url = metadata.get("content")
        if not content_url:
            raise ValueError(f"Attachment {attachment_id} has no content URL")

        return await request_bytes(
            method="GET",
            url=content_url,
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=60.0,
            follow_redirects=True,
            limiter=self.rate_limiter,
        )

    async def download_attachment_by_name(self, issue_key: str, filename: str) -> bytes:
        """
        Download attachment by issue key and filename

        Args:
            issue_key: Issue key (e.g., "VKS-1134")
            filename: Attachment filename (e.g., "v1-structured.md")

        Returns:
            bytes: Raw file content

        Raises:
            ValueError: If attachment with given filename not found
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        attachments = await self.list_attachments(issue_key)
        for att in attachments:
            if att.get("filename") == filename:
                return await self.download_attachment(att["id"])
        raise ValueError(
            f"Attachment '{filename}' not found on {issue_key}. "
            f"Available: {[a.get('filename') for a in attachments]}"
        )

    async def upload_attachment(self, issue_key: str, filepath: str, filename: Optional[str] = None) -> dict:
        """
        Upload a file as attachment to an issue

        Args:
            issue_key: Issue key (e.g., "VKS-1134")
            filepath: Local file path to upload
            filename: Override filename (optional, defaults to basename of filepath)

        Returns:
            dict: Created attachment metadata

        Raises:
            FileNotFoundError: If filepath doesn't exist
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"File not found: {filepath}")

        fname = filename or os.path.basename(filepath)

        # Jira attachment upload requires multipart/form-data
        # and X-Atlassian-Token: no-check header
        headers = {
            **self._auth_kwargs["headers"],
            "X-Atlassian-Token": "no-check",
        }

        content = await asyncio.to_thread(_read_file_bytes, filepath)
        result = await request_json(
            method="POST",
            url=f"{self.base_url}/issue/{issue_key}/attachments",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs={"headers": headers},
            files={"file": (fname, content)},
            timeout=120.0,
            limiter=self.rate_limiter,
            # POST upload is non-idempotent.
            max_retries=0,
        )

        # API usually returns array; keep backward-compatible shape.
        return result[0] if isinstance(result, list) and result else result

    # ========================================================================
    # Agile API — Boards & Estimation
    # ========================================================================

    async def get_boards(self, project_key_or_id: str = "") -> list:
        """
        List Scrum/Kanban boards, optionally filtered by project

        Args:
            project_key_or_id: Project key (e.g., "VKS") or ID to filter boards.
                               If empty, returns all visible boards.

        Returns:
            list: Board objects [{id, name, type, ...}]
        """
        params = {}
        if project_key_or_id:
            params["projectKeyOrId"] = project_key_or_id

        result = await request_json(
            method="GET",
            url=f"{self.agile_url}/board",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params=params,
            timeout=30.0,
            limiter=self.rate_limiter,
        )
        return result.get("values", [])

    async def get_estimation(self, issue_key: str, board_id: int) -> dict:
        """
        Get story points estimation for an issue

        Args:
            issue_key: Issue key (e.g., "VKS-1673")
            board_id: Board ID (from get_boards)

        Returns:
            dict: {"value": <number>} or {"value": null}
        """
        return await request_json(
            method="GET",
            url=f"{self.agile_url}/issue/{issue_key}/estimation",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"boardId": board_id},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def set_estimation(self, issue_key: str, board_id: int, value: float) -> dict:
        """
        Set story points estimation for an issue

        Args:
            issue_key: Issue key (e.g., "VKS-1673")
            board_id: Board ID (from get_boards)
            value: Story points value (e.g., 8)

        Returns:
            dict: {"value": <number>} (the set value, echoed back)
        """
        return await request_json(
            method="PUT",
            url=f"{self.agile_url}/issue/{issue_key}/estimation",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"boardId": board_id},
            json={"value": value},
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # PUT is non-idempotent for estimation
        )

    # ========================================================================
    # Issues CRUD — create, edit, transition, search
    # ========================================================================

    async def create_issue(
        self, project_key: str, issue_type: str, summary: str, **fields
    ) -> dict:
        """Create a new Jira issue."""
        body = {
            "fields": {
                "project": {"key": project_key},
                "issuetype": {"name": issue_type},
                "summary": summary,
                **fields,
            }
        }
        return await request_json(
            method="POST",
            url=f"{self.base_url}/issue",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=body,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    async def edit_issue(self, issue_key: str, **fields) -> dict:
        """Update fields on an existing issue."""
        status = await request_empty(
            method="PUT",
            url=f"{self.base_url}/issue/{issue_key}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={"fields": fields},
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )
        return {"status": "updated", "issue_key": issue_key, "http_status": status}

    async def transition_issue(self, issue_key: str, transition_id: str) -> dict:
        """Transition issue to a new workflow status."""
        status = await request_empty(
            method="POST",
            url=f"{self.base_url}/issue/{issue_key}/transitions",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={"transition": {"id": transition_id}},
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )
        return {"status": "transitioned", "issue_key": issue_key, "http_status": status}

    async def get_transitions(self, issue_key: str) -> list:
        """List available transitions for an issue."""
        result = await request_json(
            method="GET",
            url=f"{self.base_url}/issue/{issue_key}/transitions",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )
        return result.get("transitions", [])

    async def search_jql(
        self,
        jql: str,
        max_results: int = 50,
        next_page_token: str = "",
        fields: list[str] | None = None,
        expand: str | None = None,
    ) -> dict:
        """Search issues using JQL (new /search/jql endpoint).

        Migrated from the deprecated /rest/api/3/search (HTTP 410 as of
        CHANGE-2046). The new endpoint uses opaque `nextPageToken` pagination
        instead of `startAt` + `total`; response contains `nextPageToken` and
        `isLast` fields. See:
        https://developer.atlassian.com/changelog/#CHANGE-2046
        """
        params: dict = {"jql": jql, "maxResults": max_results}
        if next_page_token:
            params["nextPageToken"] = next_page_token
        if fields:
            params["fields"] = ",".join(fields)
        if expand:
            params["expand"] = expand
        return await request_json(
            method="GET",
            url=f"{self.base_url}/search/jql",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params=params,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    # ========================================================================
    # Comments & Worklogs
    # ========================================================================

    async def add_comment(self, issue_key: str, body: str) -> dict:
        """Add a comment to an issue (markdown format)."""
        return await request_json(
            method="POST",
            url=f"{self.base_url}/issue/{issue_key}/comment",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={"body": {"type": "doc", "version": 1, "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": body}]}
            ]}},
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    async def add_worklog(
        self, issue_key: str, time_spent: str, comment: str = ""
    ) -> dict:
        """Add a worklog entry to an issue."""
        payload: dict = {"timeSpent": time_spent}
        if comment:
            payload["comment"] = {"type": "doc", "version": 1, "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": comment}]}
            ]}
        return await request_json(
            method="POST",
            url=f"{self.base_url}/issue/{issue_key}/worklog",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )

    # ========================================================================
    # Issue Links
    # ========================================================================

    async def create_issue_link(
        self, link_type: str, inward_issue: str, outward_issue: str
    ) -> dict:
        """Create a link between two issues."""
        status = await request_empty(
            method="POST",
            url=f"{self.base_url}/issueLink",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={
                "type": {"name": link_type},
                "inwardIssue": {"key": inward_issue},
                "outwardIssue": {"key": outward_issue},
            },
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,
        )
        return {"status": "linked", "http_status": status}

    async def get_issue_link_types(self) -> list:
        """List available issue link types."""
        result = await request_json(
            method="GET",
            url=f"{self.base_url}/issueLinkType",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )
        return result.get("issueLinkTypes", [])

    async def get_remote_issue_links(self, issue_key: str) -> list:
        """Get remote links for an issue."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/issue/{issue_key}/remotelink",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    # ========================================================================
    # Projects & Metadata
    # ========================================================================

    async def get_visible_projects(self) -> list:
        """List all visible projects."""
        result = await request_json(
            method="GET",
            url=f"{self.base_url}/project/search",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )
        return result.get("values", [])

    async def get_issue_type_metadata(self, project_key: str) -> list:
        """Get issue types and their fields for a project."""
        result = await request_json(
            method="GET",
            url=f"{self.base_url}/issue/createmeta/{project_key}/issuetypes",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )
        return result.get("issueTypes", result.get("values", []))

    async def lookup_account_id(self, query: str) -> list:
        """Search for users by display name or email."""
        return await request_json(
            method="GET",
            url=f"{self.base_url}/user/search",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"query": query},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def delete_attachment(self, attachment_id: str) -> dict:
        """
        Delete an attachment by ID

        Args:
            attachment_id: Attachment ID (numeric string)

        Returns:
            dict: Success confirmation

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        status = await request_empty(
            method="DELETE",
            url=f"{self.base_url}/attachment/{attachment_id}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
            # DELETE can have side effects; avoid automatic retries.
            max_retries=0,
        )

        if status == 204:
            return {
                "status": "deleted",
                "attachment_id": attachment_id,
                "message": "Attachment deleted successfully",
            }
        return {
            "status": "success",
            "attachment_id": attachment_id,
            "http_status": status,
        }
