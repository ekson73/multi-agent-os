"""
HTTP client for Jira Cloud REST API v3

This module provides an async HTTP client for interacting with the
Jira Cloud REST API to manage issues and attachments.

Authentication uses Basic Auth (email:api_token) as per Atlassian Cloud standard.
"""

import base64
import httpx
import os
from typing import Optional
from aiolimiter import AsyncLimiter


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
            httpx.HTTPError: If API request fails (404 if issue not found)
        """
        params = {}
        if fields:
            params["fields"] = fields

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/issue/{issue_key}",
                    params=params,
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

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
            httpx.HTTPError: If API request fails
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
            httpx.HTTPError: If API request fails (404 if attachment not found)
        """
        # First get the attachment metadata to find the content URL
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/attachment/{attachment_id}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                metadata = response.json()

        content_url = metadata.get("content")
        if not content_url:
            raise ValueError(f"Attachment {attachment_id} has no content URL")

        # Download the actual content
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                response = await client.get(
                    content_url,
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.content

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
            httpx.HTTPError: If API request fails
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
            httpx.HTTPError: If API request fails
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

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=120.0) as client:
                with open(filepath, "rb") as f:
                    response = await client.post(
                        f"{self.base_url}/issue/{issue_key}/attachments",
                        headers=headers,
                        files={"file": (fname, f)},
                    )
                    response.raise_for_status()
                    result = response.json()
                    # API returns array of attachments
                    return result[0] if isinstance(result, list) and result else result

    async def delete_attachment(self, attachment_id: str) -> dict:
        """
        Delete an attachment by ID

        Args:
            attachment_id: Attachment ID (numeric string)

        Returns:
            dict: Success confirmation

        Raises:
            httpx.HTTPError: If API request fails (404 if not found, 403 if no permission)
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.delete(
                    f"{self.base_url}/attachment/{attachment_id}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()

                if response.status_code == 204:
                    return {
                        "status": "deleted",
                        "attachment_id": attachment_id,
                        "message": "Attachment deleted successfully",
                    }
                return response.json()
