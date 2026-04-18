"""
Jira — Helper module (VKS-1694 / v1.7).

Not exposed as a standalone flat-namespace MCP server since v1.7. The
Jira gateway (`gateways/jira/actions.py`) uses its own `JiraClient`
(`lib.jira.client.JiraClient`); this package is retained mainly for the
`_adf_to_markdown` helper consumed by `lib/jira/cli.py`.
"""

__version__ = "2.0.0"
__all__ = ['TOOLS']

from .tools import TOOLS
