"""
Jira — Gateway-only handler module (VKS-1694 / v1.7).

Not exposed as a standalone flat-namespace MCP server since v1.7. The
TOOLS dict is imported directly by gateways/jira/actions.py.
"""

__version__ = "2.0.0"
__all__ = ['TOOLS']

from .tools import TOOLS
