"""
Jira Cloud MCP Server - Metadata

Provides SERVER_INFO for hub auto-discovery.
"""

SERVER_INFO = {
    "name": "jira",
    "display_name": "Jira Cloud Issue Tracker",
    "version": "1.0.0",
    "description": (
        "Manage Jira Cloud issues and attachments via REST API v3. "
        "Supports reading issues, listing/downloading/uploading/deleting attachments."
    ),
    "mcp_server": "hub.py",
    "env_vars": {
        "JIRA_EMAIL": "Atlassian account email for Basic Auth",
        "JIRA_API_TOKEN": "Jira-specific API token (preferred)",
        "ATLASSIAN_API_TOKEN": "Shared fallback token for Jira/Confluence (optional)",
        "JIRA_CLOUD_ID": "Cloud instance UUID (e.g., 023bcd49-f455-4451-a096-c50c42c811d7)",
    },
    "tools": [
        "get_issue",
        "list_attachments",
        "download_attachment",
        "upload_attachment",
        "delete_attachment",
    ],
}
