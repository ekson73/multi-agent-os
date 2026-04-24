"""
Bitbucket — Gateway-only handler module (VKS-1694 / v1.7).

Not exposed as a standalone flat-namespace MCP server since v1.7. The
TOOLS dict is imported directly by gateways/bitbucket/actions.py.

v2.2.0 (VKS-1853, 2026-04-23): added 3 pull_request interaction tools
(add_pr_comment, update_pr_description, reply_to_pr_comment) and
standardized params across all pull_request.* ops (pr_id / pull_request_id
alias, account on all ops).
"""

__version__ = "2.2.0"
__all__ = ['TOOLS']

from .tools import TOOLS
