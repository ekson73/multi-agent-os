#!/usr/bin/env python3
"""
Universal MCP CLI - Call MCP tools from any registered server

Architecture:
    servers/
    ├── {server-name}/
    │   ├── server.py      # SERVER_INFO metadata
    │   └── tools.py       # TOOLS registry

Usage:
    # List available servers
    ./cli.py list-servers

    # List tools from a server
    ./cli.py {server} list-tools

    # Call a tool
    ./cli.py {server} {tool_name} {json_args}

Examples:
    # Bitbucket Pipeline Monitor
    ./cli.py bitbucket list-tools
    ./cli.py bitbucket get_recent_builds '{"count": 10}'
    ./cli.py bitbucket get_build_details '{"build_number": 632}'
    ./cli.py bitbucket auto_diagnose '{"build_number": 632}'
    ./cli.py bitbucket check_pipeline_health '{}'

    # Future servers...
    ./cli.py another-server some_tool '{}'

Environment Variables:
    Server-specific (see server documentation)
    Example for bitbucket:
        BITBUCKET_USERNAME       - Bitbucket username
        BITBUCKET_APP_PASSWORD   - Bitbucket app password
"""

import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional

# Load .env file if present (for local development)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv not installed — env vars must be set externally

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent))

# Attempt to import servers registry
try:
    # Import with proper module path
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "mcp_registry",
        Path(__file__).parent / "servers" / "__init__.py"
    )
    mcp_registry = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mcp_registry)
except ImportError as e:
    print(f"❌ Error: Could not load servers registry: {e}", file=sys.stderr)
    print("Make sure servers/__init__.py exists", file=sys.stderr)
    sys.exit(1)


def discover_servers() -> Dict[str, Any]:
    """
    Discover all available MCP servers

    Returns:
        dict: {server_name: server_info}
    """
    servers = {}
    servers_dir = Path(__file__).parent / "servers"

    if not servers_dir.exists():
        return servers

    # Iterate through subdirectories
    for item in servers_dir.iterdir():
        if item.is_dir() and not item.name.startswith('_') and not item.name.startswith('.'):
            server_name = item.name

            # Try to load server.py
            server_file = item / "server.py"
            tools_file = item / "tools.py"

            if not server_file.exists() or not tools_file.exists():
                continue

            try:
                # Import server module dynamically
                spec = importlib.util.spec_from_file_location(
                    f"{server_name}_server",
                    server_file
                )
                server_module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(server_module)

                # Import tools module
                spec_tools = importlib.util.spec_from_file_location(
                    f"{server_name}_tools",
                    tools_file
                )
                tools_module = importlib.util.module_from_spec(spec_tools)
                spec_tools.loader.exec_module(tools_module)

                # Get server info and tools
                server_info = getattr(server_module, 'SERVER_INFO', {})
                tools = getattr(tools_module, 'TOOLS', {})

                servers[server_name] = {
                    'info': server_info,
                    'tools': tools
                }

            except Exception as e:
                # Server doesn't have proper structure, skip
                print(f"⚠️  Warning: Could not load server '{server_name}': {e}", file=sys.stderr)
                continue

    return servers


def list_servers_command():
    """List all available MCP servers"""
    servers = discover_servers()

    if not servers:
        print("❌ No MCP servers found in servers/")
        print("\nExpected structure:")
        print("  servers/")
        print("  └── {server-name}/")
        print("      ├── server.py   (SERVER_INFO)")
        print("      └── tools.py    (TOOLS)")
        return

    print("Available MCP Servers:")
    print()
    for server_name, server_data in servers.items():
        info = server_data['info']
        print(f"  📦 {server_name}")
        print(f"     Name: {info.get('display_name', server_name)}")
        print(f"     Version: {info.get('version', 'unknown')}")
        print(f"     Description: {info.get('description', 'No description')}")
        print(f"     Tools: {len(server_data['tools'])}")
        print()

    print(f"Total: {len(servers)} server(s)")
    print()
    print("Usage:")
    print(f"  ./cli.py <server> list-tools")
    print(f"  ./cli.py <server> <tool_name> <json_args>")


def list_tools_command(server_name: str):
    """List all tools from a specific server"""
    servers = discover_servers()

    if server_name not in servers:
        print(f"❌ Error: Server '{server_name}' not found", file=sys.stderr)
        print(f"\nAvailable servers: {', '.join(servers.keys())}", file=sys.stderr)
        sys.exit(1)

    server_data = servers[server_name]
    info = server_data['info']
    tools = server_data['tools']

    print(f"Server: {info.get('display_name', server_name)}")
    print(f"Version: {info.get('version', 'unknown')}")
    print()
    print("Available Tools:")
    for tool_name, tool_func in tools.items():
        doc = tool_func.__doc__ or "No description"
        # Get first line of docstring
        doc_line = doc.strip().split('\n')[0]
        print(f"  • {tool_name}")
        print(f"    {doc_line}")
    print()
    print(f"Total: {len(tools)} tool(s)")
    print()

    # Show environment variables if any
    env_vars = info.get('env_vars', {})
    if env_vars:
        print("Required Environment Variables:")
        for var, desc in env_vars.items():
            print(f"  • {var}: {desc}")
        print()

    print("Usage:")
    print(f"  ./cli.py {server_name} <tool_name> <json_args>")
    print()
    print("Examples:")
    if tools:
        first_tool = list(tools.keys())[0]
        print(f"  ./cli.py {server_name} {first_tool} '{{}}'")


async def call_tool(server_name: str, tool_name: str, args: Dict[str, Any]):
    """
    Call a tool from a specific server

    Args:
        server_name: Name of the server
        tool_name: Name of the tool
        args: Arguments to pass to the tool
    """
    servers = discover_servers()

    if server_name not in servers:
        print(f"❌ Error: Server '{server_name}' not found", file=sys.stderr)
        print(f"\nAvailable servers: {', '.join(servers.keys())}", file=sys.stderr)
        sys.exit(1)

    server_data = servers[server_name]
    tools = server_data['tools']

    if tool_name not in tools:
        print(f"❌ Error: Tool '{tool_name}' not found in server '{server_name}'", file=sys.stderr)
        print(f"\nAvailable tools: {', '.join(tools.keys())}", file=sys.stderr)
        print(f"\nUse: ./cli.py {server_name} list-tools", file=sys.stderr)
        sys.exit(1)

    # Call the tool
    try:
        tool_func = tools[tool_name]
        result = await tool_func(**args)
        print(json.dumps(result, indent=2))
    except TypeError as e:
        print(f"❌ Error: Invalid arguments for {tool_name}: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


async def main():
    """Main CLI entry point"""
    if len(sys.argv) < 2 or sys.argv[1] in ["--help", "-h", "help"]:
        print(__doc__)
        print("\nCommands:")
        print("  list-servers              List all available MCP servers")
        print("  {server} list-tools       List tools from a specific server")
        print("  {server} {tool} {args}    Call a tool with JSON arguments")
        print()
        list_servers_command()
        sys.exit(0)

    command = sys.argv[1]

    # Handle list-servers command
    if command == "list-servers":
        list_servers_command()
        sys.exit(0)

    # Handle server-specific commands
    server_name = command

    if len(sys.argv) < 3:
        print(f"❌ Error: Missing command for server '{server_name}'", file=sys.stderr)
        print(f"\nUsage: ./cli.py {server_name} list-tools", file=sys.stderr)
        print(f"       ./cli.py {server_name} <tool_name> <json_args>", file=sys.stderr)
        sys.exit(1)

    subcommand = sys.argv[2]

    # Handle list-tools subcommand
    if subcommand == "list-tools":
        list_tools_command(server_name)
        sys.exit(0)

    # Handle tool call
    tool_name = subcommand

    # Parse arguments
    if len(sys.argv) >= 4:
        try:
            args = json.loads(sys.argv[3])
        except json.JSONDecodeError as e:
            print(f"❌ Error: Invalid JSON arguments: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        args = {}

    # Call the tool
    await call_tool(server_name, tool_name, args)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n⚠️ Interrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Fatal Error: {e}", file=sys.stderr)
        sys.exit(1)
