"""
Jira Cloud MCP Server
Provides tools for managing Jira issues and attachments
"""

__version__ = "1.0.0"
__all__ = ['TOOLS', 'SERVER_INFO']

from .server import SERVER_INFO
from .tools import TOOLS
