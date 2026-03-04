#!/usr/bin/env python3
"""
MAOS MCP Hub - Universal MCP Gateway
Version: 1.0.0
Protocol: MCP 1.0 (JSON-RPC 2.0)
Transport: STDIO (stdin/stdout)

This universal gateway auto-discovers and exposes all MCP servers from servers/
directory, providing a single entry point for Claude Desktop.

Architecture:
    hub.py
        ↓ (auto-discovers)
    servers/
    ├── bitbucket/
    ├── github/
    └── gitlab/
        ↓ (registers as)
    bitbucket.get_recent_builds
    github.get_workflow_status
    gitlab.get_failed_pipelines

Features:
- 🔍 Auto-discovery of MCP servers
- 🏷️ Namespaced tools (server.tool)
- ⚡ Single configuration for Claude Desktop
- 🔄 Zero-config for new servers (just add to servers/)
- 📊 Dynamic tool registration

Environment Variables:
    Server-specific (defined by each server in servers/)
    Example:
        BITBUCKET_EMAIL, BITBUCKET_USERNAME, BITBUCKET_API_TOKEN (for bitbucket server)
        GITHUB_TOKEN (for github server)

Usage:
    # Production (via Claude Desktop)
    python3 hub.py       # Run as MCP hub (STDIO)

    # Testing & Development (via cli.py)
    ./cli.py list-servers                           # List all discovered servers
    ./cli.py <server> list-tools                    # List tools from a server
    ./cli.py <server> <tool_name> <json_args>       # Call a tool directly

    Examples:
        ./cli.py bitbucket list-tools
        ./cli.py bitbucket get_recent_builds '{"count": 5}'
        ./cli.py bitbucket get_test_reports '{"build_number": 640, "step_name": "Unit Tests"}'

Claude Desktop configuration:
    {
      "mcpServers": {
        "maos-mcp-hub": {
          "command": "python3",
          "args": ["/path/to/hub.py"],
          "env": {
            "BITBUCKET_EMAIL": "your-email@company.com",
            "BITBUCKET_USERNAME": "your_username",
            "BITBUCKET_API_TOKEN": "your_bitbucket_api_token",
            "GITHUB_TOKEN": "your_github_token_here"
          }
        }
      }
    }

Example queries in Claude:
    "Liste os últimos 5 builds do Bitbucket"
    → Calls bitbucket.get_recent_builds

    "Qual o status dos workflows GitHub?"
    → Calls github.get_workflow_status

    "Mostre pipelines falhados no GitLab"
    → Calls gitlab.get_failed_pipelines
"""

import sys
import importlib.util
from pathlib import Path
from typing import Dict, Any, List
from fastmcp import FastMCP

# Load .env file if present (for local development)
try:
    from dotenv import load_dotenv
    load_dotenv(override=True)
except ImportError:
    pass  # python-dotenv not installed — env vars must be set externally


# ============================================================================
# CONFIGURATION
# ============================================================================

HUB_NAME = "maos-mcp-hub"
HUB_VERSION = "1.0.0"
SERVERS_DIR = Path(__file__).parent / "servers"


# ============================================================================
# SERVER DISCOVERY
# ============================================================================

def discover_mcp_servers() -> Dict[str, Dict[str, Any]]:
    """
    Auto-discover all MCP servers in servers/ directory

    Returns:
        dict: {
            "server_name": {
                "info": SERVER_INFO,
                "tools": TOOLS,
                "module": tools_module
            }
        }
    """
    servers = {}

    if not SERVERS_DIR.exists():
        sys.stderr.write(f"⚠️  Warning: {SERVERS_DIR} not found\n")
        sys.stderr.flush()
        return servers

    # Iterate through server directories
    for server_dir in SERVERS_DIR.iterdir():
        if not server_dir.is_dir():
            continue

        if server_dir.name.startswith('_') or server_dir.name.startswith('.'):
            continue

        server_name = server_dir.name

        # Check required files
        server_file = server_dir / "server.py"
        tools_file = server_dir / "tools.py"

        if not server_file.exists() or not tools_file.exists():
            sys.stderr.write(f"⚠️  Warning: Skipping '{server_name}' (missing server.py or tools.py)\n")
            sys.stderr.flush()
            continue

        try:
            # Load server.py (metadata)
            spec_server = importlib.util.spec_from_file_location(
                f"mcp_servers.{server_name}.server",
                server_file
            )
            server_module = importlib.util.module_from_spec(spec_server)
            spec_server.loader.exec_module(server_module)

            # Load tools.py (implementations)
            spec_tools = importlib.util.spec_from_file_location(
                f"mcp_servers.{server_name}.tools",
                tools_file
            )
            tools_module = importlib.util.module_from_spec(spec_tools)

            # Add hub directory to sys.path so 'lib' package is importable
            scripts_dir = str(Path(__file__).parent)
            if scripts_dir not in sys.path:
                sys.path.insert(0, scripts_dir)

            spec_tools.loader.exec_module(tools_module)

            # Get metadata and tools
            server_info = getattr(server_module, 'SERVER_INFO', {})
            tools = getattr(tools_module, 'TOOLS', {})

            if not tools:
                sys.stderr.write(f"⚠️  Warning: Server '{server_name}' has no TOOLS\n")
                sys.stderr.flush()
                continue

            servers[server_name] = {
                'info': server_info,
                'tools': tools,
                'module': tools_module
            }

            sys.stderr.write(f"✅ Loaded server: {server_name} ({len(tools)} tools)\n")
            sys.stderr.flush()

        except Exception as e:
            sys.stderr.write(f"❌ Error loading server '{server_name}': {e}\n")
            sys.stderr.flush()
            import traceback
            traceback.print_exc(file=sys.stderr)
            continue

    return servers


# ============================================================================
# MCP HUB INITIALIZATION
# ============================================================================

# Initialize FastMCP hub
mcp = FastMCP(
    name=HUB_NAME,
    instructions=(
        f"MAOS MCP Hub v{HUB_VERSION} - Universal gateway for multiple MCP servers. "
        "Auto-discovers and exposes tools from all registered servers with namespaced access."
    ),
)


# Discover all servers
sys.stderr.write("\n" + "=" * 70 + "\n")
sys.stderr.write(f"🚀 MAOS MCP Hub v{HUB_VERSION}\n")
sys.stderr.write("=" * 70 + "\n\n")
sys.stderr.write("📦 Discovering MCP servers...\n\n")
sys.stderr.flush()

discovered_servers = discover_mcp_servers()

if not discovered_servers:
    sys.stderr.write("\n⚠️  No MCP servers found in servers/\n")
    sys.stderr.write("Expected structure:\n")
    sys.stderr.write("  servers/\n")
    sys.stderr.write("  └── {server-name}/\n")
    sys.stderr.write("      ├── server.py   (SERVER_INFO)\n")
    sys.stderr.write("      └── tools.py    (TOOLS)\n\n")
    sys.stderr.flush()


# ============================================================================
# DYNAMIC TOOL REGISTRATION
# ============================================================================

total_tools_registered = 0

sys.stderr.write("\n📋 Registering tools...\n\n")
sys.stderr.flush()

for server_name, server_data in discovered_servers.items():
    server_info = server_data['info']
    tools = server_data['tools']

    sys.stderr.write(f"  📦 {server_name} ({server_info.get('display_name', server_name)})\n")
    sys.stderr.flush()

    for tool_name, tool_func in tools.items():
        # Create namespaced tool name
        namespaced_name = f"{server_name}_{tool_name}"

        # Register tool with FastMCP
        # We use the original function and let FastMCP decorator handle it
        mcp.tool(name=namespaced_name)(tool_func)

        total_tools_registered += 1
        sys.stderr.write(f"     ✅ {namespaced_name}\n")
        sys.stderr.flush()

    sys.stderr.write("\n")
    sys.stderr.flush()


# ============================================================================
# HUB SUMMARY
# ============================================================================

sys.stderr.write("=" * 70 + "\n")
sys.stderr.write(f"✅ MAOS MCP Hub Ready!\n")
sys.stderr.write(f"   Servers: {len(discovered_servers)}\n")
sys.stderr.write(f"   Tools: {total_tools_registered}\n")
sys.stderr.write("=" * 70 + "\n\n")

for server_name, server_data in discovered_servers.items():
    server_info = server_data['info']
    sys.stderr.write(f"📦 {server_name}:\n")
    sys.stderr.write(f"   Display Name: {server_info.get('display_name', server_name)}\n")
    sys.stderr.write(f"   Version: {server_info.get('version', 'unknown')}\n")
    sys.stderr.write(f"   Description: {server_info.get('description', 'No description')}\n")
    sys.stderr.write(f"   Tools: {len(server_data['tools'])}\n")

    env_vars = server_info.get('env_vars', {})
    if env_vars:
        sys.stderr.write(f"   Required Env Vars: {', '.join(env_vars.keys())}\n")

    sys.stderr.write("\n")

sys.stderr.write("🎯 Waiting for MCP client connection...\n\n")
sys.stderr.flush()


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def main():
    """Main entry point for MCP hub"""
    # Handle --help flag
    if len(sys.argv) > 1 and sys.argv[1] in ['--help', '-h', 'help']:
        print(__doc__)
        print("\nDiscovered Servers:")
        for server_name, server_data in discovered_servers.items():
            info = server_data['info']
            print(f"\n  📦 {server_name}")
            print(f"     Name: {info.get('display_name', server_name)}")
            print(f"     Version: {info.get('version', 'unknown')}")
            print(f"     Tools: {len(server_data['tools'])}")

        print(f"\nTotal: {len(discovered_servers)} server(s), {total_tools_registered} tool(s)")
        sys.exit(0)

    try:
        # Run MCP hub with STDIO transport
        mcp.run()
    except KeyboardInterrupt:
        sys.stderr.write("\n\n⚠️  Hub interrupted by user\n")
        sys.stderr.flush()
        sys.exit(130)
    except Exception as e:
        sys.stderr.write(f"\n❌ Fatal Error: {e}\n")
        sys.stderr.flush()
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
