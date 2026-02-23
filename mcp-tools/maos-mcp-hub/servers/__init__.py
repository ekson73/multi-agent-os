"""
MCP Servers Registry
Automatic discovery and registration of MCP servers
"""

import importlib
import pkgutil
from pathlib import Path
from typing import Dict, List, Any

__all__ = ['discover_servers', 'get_server', 'list_servers']


def discover_servers() -> Dict[str, Any]:
    """
    Automatically discover all MCP servers in mcp-servers/ directory

    Returns:
        dict: {server_name: server_module}
    """
    servers = {}
    servers_dir = Path(__file__).parent

    # Iterate through subdirectories
    for item in servers_dir.iterdir():
        if item.is_dir() and not item.name.startswith('_'):
            server_name = item.name
            try:
                # Import server module
                server_module = importlib.import_module(f'mcp-servers.{server_name}.server')
                servers[server_name] = server_module
            except (ImportError, AttributeError) as e:
                # Server doesn't have proper structure, skip
                continue

    return servers


def get_server(server_name: str) -> Any:
    """
    Get a specific MCP server by name

    Args:
        server_name: Name of the server (e.g., 'bitbucket')

    Returns:
        Server module or None if not found
    """
    servers = discover_servers()
    return servers.get(server_name)


def list_servers() -> List[str]:
    """
    List all available MCP server names

    Returns:
        List of server names
    """
    return list(discover_servers().keys())
