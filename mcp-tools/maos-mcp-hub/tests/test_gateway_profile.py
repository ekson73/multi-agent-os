"""Tests — HubProfile + profile-as-gating-input wiring (T2 / WAVE 5).

tasks.md T2 acceptance, as logged fields (the DoD-gate):
  "a disabled/conflicting tool is not routed; the decision is logged."
"""

from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Any, Dict

import pytest

from lib.gateway.policy import PolicyResolver
from lib.gateway.profile import (
    PROFILE_ENV_VAR,
    HubProfile,
    ProfileError,
    load_profile,
    resolver_from_profile,
    validate_profile,
)
from lib.gateway.router import MetaToolRouter
from lib.gateway.types import GatewayRequest

_HUB_DIR = Path(__file__).resolve().parents[1]
_REPO_ROOT = _HUB_DIR.parents[1]


# ---------------------------------------------------------------------- helpers

async def _mock_get_issue(issue_key: str) -> Dict[str, Any]:
    return {"key": issue_key}


async def _mock_create_issue(project_key: str, summary: str) -> Dict[str, Any]:
    return {"key": f"{project_key}-1", "summary": summary}


def _build_router(policy=None) -> MetaToolRouter:
    router = MetaToolRouter(tool_name="atlassian_jira", policy=policy)
    router.register("issue", "get", _mock_get_issue, description="Get issue")
    router.register("issue", "create", _mock_create_issue, description="Create issue")
    return router


def _write_profile(tmp_path: Path, body: str) -> Path:
    p = tmp_path / "profile.yaml"
    p.write_text(body, encoding="utf-8")
    return p


# ------------------------------------------------------------------ load_profile

def test_absent_profile_is_none_and_passthrough(tmp_path: Path) -> None:
    assert load_profile(tmp_path / "missing.yaml") is None
    assert resolver_from_profile(None) is None


def test_profile_parses_schema(tmp_path: Path) -> None:
    p = _write_profile(
        tmp_path,
        "schema_version: hub-profile/1.0.0\nmode: enforce\nenabled: [get]\n",
    )
    prof = load_profile(p)
    assert prof is not None
    assert prof.mode == "enforce"
    assert prof.enabled == ("get",)
    assert prof.source == str(p)


def test_env_var_resolution(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    p = _write_profile(tmp_path, "mode: enforce\nenabled: [x]\n")
    monkeypatch.setenv(PROFILE_ENV_VAR, str(p))
    prof = load_profile()
    assert prof is not None and prof.enabled == ("x",)


def test_invalid_profile_fails_loudly(tmp_path: Path) -> None:
    p = _write_profile(tmp_path, "mode: bogus\nenabled: []\n")
    with pytest.raises(ProfileError):
        load_profile(p)
    p2 = _write_profile(tmp_path, "- not\n- a\n- mapping\n")
    with pytest.raises(ProfileError):
        load_profile(p2)


def test_advisory_mode_is_not_enforced(tmp_path: Path) -> None:
    p = _write_profile(tmp_path, "mode: advisory\nenabled: [get]\n")
    prof = load_profile(p)
    assert prof is not None and prof.mode == "advisory"
    assert resolver_from_profile(prof) is None


def test_empty_enabled_is_not_enforced(tmp_path: Path) -> None:
    p = _write_profile(tmp_path, "mode: enforce\nenabled: []\n")
    assert resolver_from_profile(load_profile(p)) is None


# --------------------------------------------- acceptance: not routed + logged

def test_disabled_tool_is_not_routed_and_decision_logged(tmp_path: Path) -> None:
    """T2 acceptance (half 1): a DISABLED tool is not routed; deny is logged."""
    p = _write_profile(tmp_path, "mode: enforce\nenabled: [get]\n")
    resolver = resolver_from_profile(load_profile(p))
    assert isinstance(resolver, PolicyResolver)
    router = _build_router(policy=resolver)

    result = asyncio.run(
        router.dispatch(GatewayRequest(resource="issue", operation="create",
                                       params={"project_key": "X", "summary": "s"}))
    )
    assert "error" in result and "Blocked by policy" in result["error"]

    allowed = asyncio.run(
        router.dispatch(GatewayRequest(resource="issue", operation="get",
                                       params={"issue_key": "X-1"}))
    )
    assert allowed.get("key") == "X-1"

    # The decision is a LOGGED FIELD (not prose):
    denies = resolver.decisions
    assert denies and denies[-1]["tool_id"] == "create"
    assert denies[-1]["allow"] is False
    assert "disabled by policy" in str(denies[-1]["reason"])


def test_conflicting_tool_is_denied_and_decision_logged() -> None:
    """T2 acceptance (half 2): a CONFLICTING tool is denied; deny is logged."""
    resolver = PolicyResolver(profile=["ECC", "gstack"], conflicts=[("ECC", "gstack")])
    decision = resolver.check("gstack")
    assert not decision.allow
    assert decision.conflicting_with == ["ECC"]
    denies = resolver.decisions
    assert denies[-1]["tool_id"] == "gstack"
    assert denies[-1]["conflicting_with"] == ["ECC"]


def test_decision_log_is_bounded() -> None:
    resolver = PolicyResolver(profile=["only"])
    for i in range(500):
        resolver.check(f"nope-{i}")
    assert len(resolver.decisions) == 200  # DECISION_LOG_MAXLEN ring


# --------------------------------------------- fail-closed vs the hub-registry

def test_profile_enabling_excluded_id_is_refused() -> None:
    """Spec (maos-hub-registry → Activation gating): supply-chain vetoes cannot
    be re-enabled by editing a YAML profile."""
    from lib.registry import HubRegistry

    registry = HubRegistry.derive(_REPO_ROOT, as_of="2026-07-02")
    bad = HubProfile(enabled=("mempalace", "get"), mode="enforce", source="test")
    errors = validate_profile(bad, registry)
    assert errors and "mempalace" in errors[0] and "excluded" in errors[0]

    clean = HubProfile(enabled=("get",), mode="enforce", source="test")
    assert validate_profile(clean, registry) == []


# --------------------------------------------- regression: passthrough intact

def test_no_policy_router_unchanged() -> None:
    router = _build_router(policy=None)
    result = asyncio.run(
        router.dispatch(GatewayRequest(resource="issue", operation="create",
                                       params={"project_key": "X", "summary": "s"}))
    )
    assert result.get("key") == "X-1"
