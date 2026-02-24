"""
Jira Cloud REST API Client - MCP Server Package

This package implements an async HTTP client for interacting with
Jira Cloud REST API v3 (via Atlassian Cloud platform).

Main components:
- client: HTTP client for Jira REST API v3
"""

__version__ = "1.0.0"
__author__ = "maos-mcp-hub contributors"
__protocol__ = "MCP 1.0 (JSON-RPC 2.0)"

from .client import JiraClient

__all__ = [
    "JiraClient",
]
