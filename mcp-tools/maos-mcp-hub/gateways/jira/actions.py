"""
Jira gateway actions — 22 actions across 8 resources.

Wraps existing JiraClient methods + servers/jira/tools.py functions.
"""

from __future__ import annotations

import base64
from typing import Any, Dict, Optional

from lib.jira.client import JiraClient
from lib.gateway.router import MetaToolRouter
from .gateway import GATEWAY_INFO

_client: Optional[JiraClient] = None


def get_client() -> JiraClient:
    global _client
    if _client is None:
        _client = JiraClient()
    return _client


# ---------------------------------------------------------------------------
# Handlers — thin wrappers around JiraClient
# ---------------------------------------------------------------------------

async def get_issue(issue_key: str, format: str = "markdown") -> dict:
    """Get issue details by key."""
    client = get_client()
    issue = await client.get_issue(issue_key)
    fields = issue.get("fields", {})
    return {
        "key": issue.get("key"),
        "id": issue.get("id"),
        "summary": fields.get("summary"),
        "status": fields.get("status", {}).get("name"),
        "assignee": (fields.get("assignee") or {}).get("displayName"),
        "reporter": (fields.get("reporter") or {}).get("displayName"),
        "issue_type": fields.get("issuetype", {}).get("name"),
        "priority": (fields.get("priority") or {}).get("name"),
        "labels": fields.get("labels", []),
        "created": fields.get("created"),
        "updated": fields.get("updated"),
        "description": fields.get("description") if format == "raw" else _extract_text(fields.get("description")),
    }


async def create_issue(
    project_key: str,
    issue_type: str,
    summary: str,
    description: str = "",
    labels: list | None = None,
    priority: str | None = None,
    assignee_account_id: str | None = None,
) -> dict:
    """Create a new issue.

    Args:
        project_key: Jira project key (e.g., "VKS").
        issue_type: Issue type name (e.g., "Story", "Intervenção Técnica - I.A.").
        summary: Issue summary (title).
        description: Plain-text description (converted to ADF automatically).
        labels: Optional list of string labels.
        priority: Optional priority name ("Highest", "High", "Medium", "Low",
            "Lowest"). VKS-1853 note: some issue types (e.g., "Intervenção
            Técnica - I.A." id 10407) in project VKS do NOT expose the
            priority field in their screen scheme. In that case Jira returns
            400 with a hint pointing to the screen-scheme mismatch. The
            wrapper forwards this hint verbatim so callers can either
            (a) create without priority and `editJiraIssue` afterward, or
            (b) request a Jira admin to add priority to the screen scheme.
        assignee_account_id: Optional assignee accountId (Atlassian 24-byte id).

    Returns:
        dict: Created issue on success, or
            {"error": str, "hint": str, "screen_scheme_hint": bool} on 400.
    """
    client = get_client()
    fields: Dict[str, Any] = {}
    if description:
        fields["description"] = {"type": "doc", "version": 1, "content": [
            {"type": "paragraph", "content": [{"type": "text", "text": description}]}
        ]}
    if labels:
        fields["labels"] = labels
    if priority:
        # Jira REST API v3 expects {"name": "Medium"} or {"id": "3"}.
        # We accept the friendlier string form and serialize canonically.
        fields["priority"] = {"name": priority}
    if assignee_account_id:
        fields["assignee"] = {"accountId": assignee_account_id}

    try:
        return await client.create_issue(project_key, issue_type, summary, **fields)
    except Exception as e:
        # VKS-1853 Gap 8: surface screen-scheme errors with a clear hint.
        # CodeRabbit PR #42 iteration 2 refinement: gate the hint translation on
        # an HTTP 400 status to avoid mis-translating unrelated failures (e.g.
        # network/timeout/5xx) that might happen to contain similar phrases.
        status_code = getattr(e, "status_code", None)
        if status_code is None:
            response = getattr(e, "response", None)
            status_code = getattr(response, "status_code", None)
        if status_code != 400:
            raise

        msg = str(e)
        # Only treat as screen-scheme mismatch when the error message contains
        # explicit screen-related phrases. The previous overbroad condition
        # (`"priority" in msg.lower()`) matched any error mentioning priority
        # and emitted a misleading hint for unrelated validation failures
        # (CodeRabbit PR #42 finding 4 — VKS-1853 Gap 8 refinement).
        if priority and (
            "cannot be set" in msg.lower()
            or "is not on the appropriate screen" in msg.lower()
            or "not on the appropriate screen" in msg.lower()
        ):
            return {
                "error": "Priority not available on this screen scheme for this issue type",
                "details": msg,
                "hint": (
                    f"Issue type '{issue_type}' in project '{project_key}' does not "
                    "expose the 'priority' field on its Create screen. Options: "
                    "(a) retry without `priority` and call `issue.edit` with "
                    "priority afterward; (b) ask a Jira admin to add 'Priority' "
                    "to the screen scheme of this issue type."
                ),
                "screen_scheme_hint": True,
                "issue_type": issue_type,
                "project_key": project_key,
                "rejected_priority": priority,
            }
        raise


async def edit_issue(issue_key: str, fields: dict) -> dict:
    """Update fields on an existing issue. Pass a dict of field names to values."""
    if not fields:
        return {"error": "fields must contain at least one update"}
    client = get_client()
    return await client.edit_issue(issue_key, **fields)


async def transition_issue(issue_key: str, transition_id: str) -> dict:
    """Transition issue to a new workflow status."""
    client = get_client()
    return await client.transition_issue(issue_key, transition_id)


async def get_transitions(issue_key: str) -> dict:
    """List available transitions for an issue."""
    client = get_client()
    transitions = await client.get_transitions(issue_key)
    return {"issue_key": issue_key, "transitions": transitions}


async def search_jql(
    jql: str,
    max_results: int = 50,
    next_page_token: str = "",
    fields: list[str] | None = None,
    expand: str | None = None,
) -> dict:
    """Search issues using JQL (new /search/jql endpoint, token pagination).

    Migrated from deprecated /rest/api/3/search (VKO-88, CHANGE-2046).
    - `next_page_token`: opaque string returned as `nextPageToken` in a
      previous response; empty string means "first page".
    - `fields`: optional list of field names to include (reduces payload).
    - `expand`: optional expand string (e.g. "changelog", "names,schema").
    Response shape: `{issues, nextPageToken?, isLast?}`.
    """
    client = get_client()
    return await client.search_jql(jql, max_results, next_page_token, fields, expand)


async def add_comment(issue_key: str, body: str) -> dict:
    """Add a comment to an issue."""
    client = get_client()
    return await client.add_comment(issue_key, body)


async def add_worklog(issue_key: str, time_spent: str, comment: str = "") -> dict:
    """Add a worklog entry to an issue."""
    client = get_client()
    return await client.add_worklog(issue_key, time_spent, comment)


async def create_issue_link(link_type: str, inward_issue: str, outward_issue: str) -> dict:
    """Create a link between two issues."""
    client = get_client()
    return await client.create_issue_link(link_type, inward_issue, outward_issue)


async def get_issue_link_types() -> dict:
    """List available issue link types."""
    client = get_client()
    types = await client.get_issue_link_types()
    return {"link_types": types}


async def get_remote_issue_links(issue_key: str) -> dict:
    """Get remote links for an issue."""
    client = get_client()
    links = await client.get_remote_issue_links(issue_key)
    return {"issue_key": issue_key, "remote_links": links}


async def get_visible_projects() -> dict:
    """List all visible projects."""
    client = get_client()
    projects = await client.get_visible_projects()
    return {"projects": projects}


async def get_issue_type_metadata(project_key: str) -> dict:
    """Get issue types and their fields for a project."""
    client = get_client()
    types = await client.get_issue_type_metadata(project_key)
    return {"project_key": project_key, "issue_types": types}


async def lookup_account_id(query: str) -> dict:
    """Search for users by display name or email."""
    client = get_client()
    users = await client.lookup_account_id(query)
    return {"query": query, "users": users}


# --- Attachments (existing) ---

async def list_attachments(issue_key: str) -> dict:
    """List all attachments for an issue."""
    client = get_client()
    atts = await client.list_attachments(issue_key)
    return {"issue_key": issue_key, "attachments": atts}


async def upload_attachment(issue_key: str, filepath: str, filename: str = "") -> dict:
    """Upload a file as attachment to an issue."""
    client = get_client()
    return await client.upload_attachment(issue_key, filepath, filename or None)


async def download_attachment(issue_key: str, filename: str) -> dict:
    """Download an attachment by filename. Returns base64-encoded content for binary safety."""
    client = get_client()
    content = await client.download_attachment_by_name(issue_key, filename)
    return {
        "issue_key": issue_key,
        "filename": filename,
        "size": len(content),
        "encoding": "base64",
        "content": base64.b64encode(content).decode("ascii"),
    }


async def delete_attachment(attachment_id: str) -> dict:
    """Delete an attachment by ID."""
    client = get_client()
    return await client.delete_attachment(attachment_id)


# --- Agile (existing) ---

async def get_boards(project_key: str = "") -> dict:
    """List boards, optionally filtered by project."""
    client = get_client()
    boards = await client.get_boards(project_key)
    return {"boards": boards}


async def get_estimation(issue_key: str, board_id: int) -> dict:
    """Get story points estimation for an issue."""
    client = get_client()
    return await client.get_estimation(issue_key, board_id)


async def set_estimation(issue_key: str, board_id: int, value: float) -> dict:
    """Set story points estimation for an issue."""
    client = get_client()
    return await client.set_estimation(issue_key, board_id, value)


async def estimate_story_points(issue_key: str, board_id: int, dry_run: bool = True) -> dict:
    """Calculate story points from observable issue data using deterministic formula.

    Formula: base(1) + subtask_w + attachment_w + comment_w + link_w + desc_w + label_bonus
    × type_multiplier → Fibonacci snap {1, 2, 3, 5, 8, 13}
    """
    client = get_client()
    issue = await client.get_issue(issue_key)
    fields = issue.get("fields", {})

    subtasks = len(fields.get("subtasks", []))
    attachments = len(fields.get("attachment", []))
    comments = fields.get("comment", {}).get("total", 0)
    links = len(fields.get("issuelinks", []))
    desc = fields.get("description") or {}
    desc_len = len(str(desc))
    labels = [l.lower() for l in fields.get("labels", [])]
    issue_type = fields.get("issuetype", {}).get("name", "Task")

    # Weights
    base = 1
    sub_w = 0 if subtasks == 0 else (1 if subtasks <= 3 else (2 if subtasks <= 6 else 3))
    att_w = 0 if attachments == 0 else (0.5 if attachments <= 3 else 1)
    com_w = 0 if comments <= 2 else (0.5 if comments <= 5 else 1)
    lnk_w = 0 if links == 0 else (0.5 if links <= 2 else 1)
    dsc_w = 0 if desc_len < 500 else (0.5 if desc_len <= 2000 else 1)
    lbl_bonus = 1 if any(l in labels for l in ("complex", "security", "migration")) else 0

    # Type multiplier
    type_mult = {"Epic": 1.5, "Story": 1.0, "Task": 1.0, "Bug": 0.8, "Sub-task": 0.6}.get(issue_type, 1.0)

    raw = (base + sub_w + att_w + com_w + lnk_w + dsc_w + lbl_bonus) * type_mult

    # Fibonacci snap
    fib = [1, 2, 3, 5, 8, 13]
    sp = min(fib, key=lambda f: abs(f - raw))

    result = {
        "issue_key": issue_key,
        "issue_type": issue_type,
        "estimated_sp": sp,
        "raw_score": round(raw, 2),
        "breakdown": {
            "base": base, "subtasks": sub_w, "attachments": att_w,
            "comments": com_w, "links": lnk_w, "description": dsc_w,
            "label_bonus": lbl_bonus, "type_multiplier": type_mult,
        },
        "applied": not dry_run,
    }

    if not dry_run:
        await client.set_estimation(issue_key, board_id, sp)
        result["message"] = f"Story Points set to {sp} on board {board_id}"

    return result


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _extract_text(adf: Any) -> str:
    """Best-effort plain text extraction from ADF (recursive)."""
    if not adf or not isinstance(adf, dict):
        return ""
    parts: list[str] = []
    _walk_adf(adf, parts)
    return "".join(parts).strip()


def _walk_adf(node: Any, parts: list[str]) -> None:
    """Recursively walk ADF nodes extracting text."""
    if not isinstance(node, dict):
        return
    node_type = node.get("type")
    if node_type == "text":
        parts.append(node.get("text", ""))
    elif node_type == "hardBreak":
        parts.append("\n")
    elif node_type == "mention":
        attrs = node.get("attrs", {})
        parts.append(attrs.get("text") or attrs.get("displayName") or "")
    for child in node.get("content", []):
        _walk_adf(child, parts)
    if node_type in ("paragraph", "heading", "blockquote", "codeBlock", "listItem", "tableRow"):
        if not parts or parts[-1] != "\n":
            parts.append("\n")


# ---------------------------------------------------------------------------
# Router builder
# ---------------------------------------------------------------------------

def build_router() -> MetaToolRouter:
    """Build the Jira meta-tool router with 22 actions."""
    router = MetaToolRouter(
        tool_name=GATEWAY_INFO["tool_name"],
        governance=["Jira operations follow DARCI-Expanded governance"],
    )

    # Issue CRUD
    router.register("issue", "get", get_issue, description="Get issue details by key")
    router.register("issue", "create", create_issue, description="Create a new issue",
                    governance=["governance_level obrigatorio", "DARCI roles recomendados"],
                    next_steps=["Estimar story points", "Adicionar DARCI roles"])
    router.register("issue", "edit", edit_issue, description="Update issue fields",
                    governance=["risk_score pode mudar — reavaliar governance_level"])
    router.register("issue", "transition", transition_issue, description="Transition issue status",
                    next_steps=["Verificar se Story Points estao definidos"])
    router.register("issue", "get_transitions", get_transitions, description="List available transitions")

    # Search
    router.register("search", "jql", search_jql, description="Search issues using JQL with pagination")

    # Comments
    router.register("comment", "add", add_comment, description="Add a comment to an issue")

    # Worklogs
    router.register("worklog", "add", add_worklog, description="Add worklog entry to an issue")

    # Links
    router.register("link", "create", create_issue_link, description="Create a link between two issues")
    router.register("link", "get_types", get_issue_link_types, description="List available link types")
    router.register("link", "get_remote", get_remote_issue_links, description="Get remote links for an issue")

    # Attachments
    router.register("attachment", "list", list_attachments, description="List attachments on an issue")
    router.register("attachment", "upload", upload_attachment, description="Upload file as attachment")
    router.register("attachment", "download", download_attachment, description="Download attachment by filename")
    router.register("attachment", "delete", delete_attachment, description="Delete attachment by ID")

    # Boards & Estimation
    router.register("board", "list", get_boards, description="List boards by project")
    router.register("estimation", "get", get_estimation, description="Get story points for issue")
    router.register("estimation", "set", set_estimation, description="Set story points for issue")
    router.register("estimation", "calculate", estimate_story_points,
                    description="Calculate story points from observable data (deterministic formula)",
                    governance=["Formula: volume signals × type_multiplier → Fibonacci snap"],
                    next_steps=["Se dry_run=True, chame com dry_run=False para aplicar"])

    # Projects & Metadata
    router.register("project", "list", get_visible_projects, description="List visible projects")
    router.register("project", "get_issue_types", get_issue_type_metadata, description="Get issue types for project")

    # Users
    router.register("user", "search", lookup_account_id, description="Search users by name or email")

    return router
