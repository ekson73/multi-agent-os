"""
Hub registration invariants (VKS-1694 Phase 2 / v1.7).

After v1.7, the hub must expose exactly 6 MCP tools — the `atlassian_*`
meta-tool gateways — and zero flat-namespace tools (no `bitbucket_*`,
no `jira_*`). The `MAOS_EXPOSE_FLAT_TOOLS` env var is no longer honored.

These tests guard against regressions of the flat-tool residue that
VKS-1694 cleaned up.
"""

import importlib
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def _run_hub(env: dict | None = None, timeout: int = 10) -> str:
    """Spawn hub.py in a subprocess and capture stderr (tool registration log)."""
    merged_env = {
        "PATH": "/usr/bin:/bin",
        "MAOS_DOTENV_PATH": str(ROOT / ".env.example"),
    }
    if env:
        merged_env.update(env)
    proc = subprocess.Popen(
        [sys.executable, str(ROOT / "hub.py")],
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        env=merged_env,
    )
    try:
        _, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        _, stderr = proc.communicate()
    return stderr.decode("utf-8", errors="replace")


def test_hub_exposes_exactly_six_mcp_tools():
    """Hub must report `Total MCP tools: 6` in its startup log."""
    log = _run_hub()
    assert "Total MCP tools: 6" in log, log


def test_hub_registers_six_atlassian_gateways():
    """All 6 atlassian_* gateways must be registered with 96 actions total."""
    log = _run_hub()
    assert "6 gateways registered (96 actions)" in log, log


def test_hub_does_not_register_flat_bitbucket_tools():
    """No `bitbucket_*` flat tool must appear in the registration log."""
    log = _run_hub()
    assert "bitbucket_get_recent_builds" not in log, log
    assert "bitbucket_create_pull_request" not in log, log


def test_hub_does_not_register_flat_jira_tools():
    """No `jira_*` flat tool must appear in the registration log."""
    log = _run_hub()
    assert "jira_get_issue" not in log, log
    assert "jira_list_attachments" not in log, log


def test_maos_expose_flat_tools_env_has_no_effect():
    """v1.7: MAOS_EXPOSE_FLAT_TOOLS is no longer honored — must still be 6 tools."""
    log = _run_hub(env={"MAOS_EXPOSE_FLAT_TOOLS": "true"})
    assert "Total MCP tools: 6" in log, log
    assert "bitbucket_get_recent_builds" not in log, log


def test_bitbucket_handlers_still_importable_by_gateway():
    """Gateway depends on handlers in servers/bitbucket/tools.py — must import."""
    sys.path.insert(0, str(ROOT))
    try:
        module = importlib.import_module("servers.bitbucket.tools")
        assert hasattr(module, "TOOLS"), "TOOLS dict missing"
        assert len(module.TOOLS) >= 50, f"expected >=50 tools, got {len(module.TOOLS)}"
    finally:
        if str(ROOT) in sys.path:
            sys.path.remove(str(ROOT))


def test_jira_handlers_still_importable_by_gateway():
    """Gateway depends on handlers in servers/jira/tools.py — must import."""
    sys.path.insert(0, str(ROOT))
    try:
        module = importlib.import_module("servers.jira.tools")
        assert hasattr(module, "TOOLS"), "TOOLS dict missing"
        assert len(module.TOOLS) >= 5, f"expected >=5 tools, got {len(module.TOOLS)}"
    finally:
        if str(ROOT) in sys.path:
            sys.path.remove(str(ROOT))
