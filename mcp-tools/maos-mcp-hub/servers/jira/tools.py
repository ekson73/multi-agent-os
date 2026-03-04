"""
Jira Cloud MCP Server - Tool Implementations

Provides 5 tools for Jira issue and attachment management:
- get_issue: Read issue details (body, status, metadata)
- list_attachments: List all attachments on an issue
- download_attachment: Download attachment content (text or base64)
- upload_attachment: Upload a local file as attachment
- delete_attachment: Delete an attachment by ID
"""

import base64
import re
from typing import Optional

import httpx

from lib.jira.client import JiraClient
from lib.common.errors import ApiError
from lib.common.http import sanitize_exception


# ============================================================================
# SINGLETON
# ============================================================================

_client = None


def get_client() -> JiraClient:
    """Get or create JiraClient singleton"""
    global _client
    if _client is None:
        _client = JiraClient()
    return _client


# ============================================================================
# HELPERS
# ============================================================================

def _validate_issue_key(issue_key: str) -> Optional[dict]:
    """Validate Jira issue key format (e.g., VKS-1134)"""
    if not issue_key or not isinstance(issue_key, str):
        return {"error": "issue_key must be a non-empty string"}
    if not re.match(r"^[A-Z][A-Z0-9]+-\d+$", issue_key.strip()):
        return {"error": f"Invalid issue key format: '{issue_key}'. Expected format: PROJECT-123"}
    return None


def _adf_to_markdown(node: dict, depth: int = 0) -> str:
    """Convert Atlassian Document Format (ADF) to Markdown"""
    if not isinstance(node, dict):
        return ""

    node_type = node.get("type", "")
    content = node.get("content", [])
    text_parts = []

    if node_type == "doc":
        for child in content:
            text_parts.append(_adf_to_markdown(child, depth))

    elif node_type == "paragraph":
        para_text = "".join(_adf_to_markdown(c, depth) for c in content)
        text_parts.append(para_text + "\n")

    elif node_type == "text":
        text = node.get("text", "")
        marks = node.get("marks", [])
        for mark in marks:
            mark_type = mark.get("type", "")
            if mark_type == "strong":
                text = f"**{text}**"
            elif mark_type == "em":
                text = f"*{text}*"
            elif mark_type == "code":
                text = f"`{text}`"
            elif mark_type == "link":
                href = mark.get("attrs", {}).get("href", "")
                text = f"[{text}]({href})"
        text_parts.append(text)

    elif node_type == "heading":
        level = node.get("attrs", {}).get("level", 1)
        heading_text = "".join(_adf_to_markdown(c, depth) for c in content)
        text_parts.append(f"\n{'#' * level} {heading_text}\n")

    elif node_type == "bulletList":
        for item in content:
            text_parts.append(_adf_to_markdown(item, depth))

    elif node_type == "orderedList":
        for i, item in enumerate(content, 1):
            text_parts.append(_adf_to_markdown(item, depth))

    elif node_type == "listItem":
        indent = "  " * depth
        item_text = "".join(_adf_to_markdown(c, depth + 1) for c in content).strip()
        text_parts.append(f"{indent}- {item_text}\n")

    elif node_type == "codeBlock":
        lang = node.get("attrs", {}).get("language", "")
        code_text = "".join(_adf_to_markdown(c, depth) for c in content)
        text_parts.append(f"\n```{lang}\n{code_text}\n```\n")

    elif node_type == "blockquote":
        quote_text = "".join(_adf_to_markdown(c, depth) for c in content)
        text_parts.append("> " + quote_text.replace("\n", "\n> "))

    elif node_type == "table":
        for row in content:
            text_parts.append(_adf_to_markdown(row, depth))

    elif node_type == "tableRow":
        cells = [
            "".join(_adf_to_markdown(c, depth) for c in cell.get("content", [])).strip()
            for cell in content
        ]
        text_parts.append("| " + " | ".join(cells) + " |\n")

    elif node_type == "tableHeader":
        cells = [
            "".join(_adf_to_markdown(c, depth) for c in cell.get("content", [])).strip()
            for cell in content
        ]
        text_parts.append("| " + " | ".join(cells) + " |\n")
        text_parts.append("| " + " | ".join(["---"] * len(cells)) + " |\n")

    elif node_type == "rule":
        text_parts.append("\n---\n")

    elif node_type == "hardBreak":
        text_parts.append("\n")

    elif node_type == "mediaSingle" or node_type == "media":
        pass  # skip embedded media

    else:
        # Fallback: recurse into content
        for child in content:
            text_parts.append(_adf_to_markdown(child, depth))

    return "".join(text_parts)


def _sanitize_error(error: Exception) -> str:
    """Remove sensitive data from error messages"""
    msg = str(error)
    # Remove potential auth tokens from error messages
    msg = re.sub(r"Basic [A-Za-z0-9+/=]+", "Basic ***", msg)
    msg = re.sub(r"Bearer [A-Za-z0-9._-]+", "Bearer ***", msg)
    return msg


# ============================================================================
# TOOLS
# ============================================================================

async def get_issue(issue_key: str, format: str = "markdown") -> dict:
    """
    Get Jira issue details including summary, description, status, and metadata.

    Args:
        issue_key: Issue key (e.g., "VKS-1134")
        format: Output format for description — "markdown" (default) or "raw" (ADF JSON)

    Returns:
        dict: Issue details with key, summary, description, status, assignee, labels, etc.
    """
    validation = _validate_issue_key(issue_key)
    if validation:
        return validation

    client = get_client()

    try:
        issue = await client.get_issue(issue_key)
        fields = issue.get("fields", {})

        # Convert ADF description to markdown if requested
        description = fields.get("description")
        if format == "markdown" and isinstance(description, dict):
            description_md = _adf_to_markdown(description)
        elif isinstance(description, dict):
            description_md = description  # raw ADF
        else:
            description_md = description or ""

        return {
            "key": issue.get("key"),
            "id": issue.get("id"),
            "summary": fields.get("summary"),
            "description": description_md,
            "status": fields.get("status", {}).get("name"),
            "assignee": (fields.get("assignee") or {}).get("displayName"),
            "reporter": (fields.get("reporter") or {}).get("displayName"),
            "labels": fields.get("labels", []),
            "priority": (fields.get("priority") or {}).get("name"),
            "issue_type": (fields.get("issuetype") or {}).get("name"),
            "created": fields.get("created"),
            "updated": fields.get("updated"),
            "attachment_count": len(fields.get("attachment", [])),
        }

    except ApiError as e:
        if e.status_code == 404:
            return {"error": f"Issue {issue_key} not found"}
        return {"error": f"Jira API error: {sanitize_exception(e)}", "hint": e.hint}
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Issue {issue_key} not found"}
        return {"error": f"Jira API error: {_sanitize_error(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {_sanitize_error(e)}"}


async def list_attachments(issue_key: str) -> dict:
    """
    List all attachments on a Jira issue.

    Args:
        issue_key: Issue key (e.g., "VKS-1134")

    Returns:
        dict: List of attachments with id, filename, size, mimeType, created date.
    """
    validation = _validate_issue_key(issue_key)
    if validation:
        return validation

    client = get_client()

    try:
        attachments = await client.list_attachments(issue_key)
        return {
            "issue_key": issue_key,
            "count": len(attachments),
            "attachments": [
                {
                    "id": att.get("id"),
                    "filename": att.get("filename"),
                    "size": att.get("size"),
                    "mimeType": att.get("mimeType"),
                    "created": att.get("created"),
                    "author": (att.get("author") or {}).get("displayName"),
                }
                for att in attachments
            ],
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Issue {issue_key} not found"}
        return {"error": f"Jira API error: {_sanitize_error(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {_sanitize_error(e)}"}


async def download_attachment(issue_key: str, filename: str) -> dict:
    """
    Download an attachment from a Jira issue by filename.

    Returns text content directly for text files, or base64-encoded content for binary files.

    Args:
        issue_key: Issue key (e.g., "VKS-1134")
        filename: Attachment filename (e.g., "v1-structured.md")

    Returns:
        dict: Content with encoding info. Text files return {"content": "...", "encoding": "utf-8"}.
              Binary files return {"content": "base64...", "encoding": "base64"}.
    """
    validation = _validate_issue_key(issue_key)
    if validation:
        return validation

    if not filename or not isinstance(filename, str):
        return {"error": "filename must be a non-empty string"}

    client = get_client()

    try:
        content_bytes = await client.download_attachment_by_name(issue_key, filename)

        # Try to decode as UTF-8 text
        try:
            text_content = content_bytes.decode("utf-8")
            return {
                "issue_key": issue_key,
                "filename": filename,
                "size": len(content_bytes),
                "content": text_content,
                "encoding": "utf-8",
            }
        except UnicodeDecodeError:
            # Binary file — return base64
            return {
                "issue_key": issue_key,
                "filename": filename,
                "size": len(content_bytes),
                "content": base64.b64encode(content_bytes).decode("ascii"),
                "encoding": "base64",
            }

    except ValueError as e:
        return {"error": str(e)}
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Attachment '{filename}' not found on {issue_key}"}
        return {"error": f"Jira API error: {_sanitize_error(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {_sanitize_error(e)}"}


async def upload_attachment(issue_key: str, filepath: str, filename: str = "") -> dict:
    """
    Upload a local file as attachment to a Jira issue.

    Args:
        issue_key: Issue key (e.g., "VKS-1134")
        filepath: Absolute path to the local file to upload
        filename: Override filename (optional, defaults to basename of filepath)

    Returns:
        dict: Created attachment metadata with id, filename, size.
    """
    validation = _validate_issue_key(issue_key)
    if validation:
        return validation

    if not filepath or not isinstance(filepath, str):
        return {"error": "filepath must be a non-empty string"}

    client = get_client()

    try:
        result = await client.upload_attachment(
            issue_key, filepath, filename if filename else None
        )
        return {
            "issue_key": issue_key,
            "attachment": {
                "id": result.get("id"),
                "filename": result.get("filename"),
                "size": result.get("size"),
                "mimeType": result.get("mimeType"),
            },
            "message": "Attachment uploaded successfully",
        }

    except FileNotFoundError as e:
        return {"error": str(e)}
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Issue {issue_key} not found"}
        if e.response.status_code == 403:
            return {"error": f"No permission to upload attachments to {issue_key}"}
        return {"error": f"Jira API error: {_sanitize_error(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {_sanitize_error(e)}"}


async def delete_attachment(attachment_id: str) -> dict:
    """
    Delete a Jira attachment by ID.

    Args:
        attachment_id: Attachment ID (numeric string, e.g., "10001").
                       Use list_attachments to find the ID.

    Returns:
        dict: Success confirmation or error details.
    """
    if not attachment_id or not isinstance(attachment_id, str):
        return {"error": "attachment_id must be a non-empty string"}
    if not attachment_id.isdigit():
        return {"error": f"attachment_id must be numeric, got: '{attachment_id}'"}

    client = get_client()

    try:
        return await client.delete_attachment(attachment_id)

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Attachment {attachment_id} not found"}
        if e.response.status_code == 403:
            return {"error": f"No permission to delete attachment {attachment_id}"}
        return {"error": f"Jira API error: {_sanitize_error(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {_sanitize_error(e)}"}


# ============================================================================
# TOOL REGISTRY
# ============================================================================

TOOLS = {
    "get_issue": get_issue,
    "list_attachments": list_attachments,
    "download_attachment": download_attachment,
    "upload_attachment": upload_attachment,
    "delete_attachment": delete_attachment,
}
