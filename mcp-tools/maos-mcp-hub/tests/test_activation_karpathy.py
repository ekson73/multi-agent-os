"""Tests — activation taxonomy applied + karpathy principles internalized
(T6 / WAVE 5).

tasks.md T6, as logged fields (the DoD-gate): "apply the `activation`
taxonomy; internalize the karpathy *principles* natively (credit the
inspiration), repo as `opt-in`/`default-on-for-context`."
"""

from __future__ import annotations

from pathlib import Path

import pytest

from lib.registry import HubRegistry

_HERE = Path(__file__).resolve()
_REPO_ROOT = _HERE.parents[3]
AS_OF = "2026-07-02"

_SKILL_MD = _REPO_ROOT / "skills" / "deliberate-coding" / "SKILL.md"


@pytest.fixture(scope="module")
def registry() -> HubRegistry:
    assert (_REPO_ROOT / "skills").is_dir()
    return HubRegistry.derive(_REPO_ROOT, as_of=AS_OF)


# ------------------------------------------------- taxonomy applied (repo)


def test_upstream_repo_is_capped_to_opt_in_or_default_on(registry: HubRegistry) -> None:
    """T6: 'repo as opt-in/default-on-for-context' — the derived tier of the
    upstream record is one of the two allowed tiers, with the gate REASON
    logged (currently the HF2 license gate caps ADAPT → opt-in)."""
    rec = registry.get("karpathy-claude-md")
    assert rec is not None
    assert rec.activation in ("opt-in", "default-on-for-context")
    assert rec.activation == "opt-in"                    # license_spdx=NONE gate
    assert "license_spdx=NONE" in rec.activation_reason  # the reason is a logged field


def test_upstream_repo_can_never_be_upgraded_past_derived(registry: HubRegistry) -> None:
    """Taxonomy teeth: request_activation refuses upgrades beyond the derived
    tier (fail-closed — YAML/API cannot lift the license gate)."""
    decision = registry.request_activation("karpathy-claude-md", "always-on")
    assert decision["granted"] != "always-on"
    decision2 = registry.request_activation("karpathy-claude-md", "default-on-for-context")
    assert decision2["granted"] != "default-on-for-context"


def test_misattributed_variant_stays_excluded(registry: HubRegistry) -> None:
    """The forrestchang mis-attribution (404) is excluded and immutable."""
    rec = registry.get("forrestchang-andrej-karpathy-skills")
    assert rec is not None and rec.activation == "excluded"
    decision = registry.request_activation("forrestchang-andrej-karpathy-skills", "opt-in")
    assert decision["granted"] == "excluded"


# --------------------------------------- principles internalized natively


def test_native_skill_derives_first_party_default_on(registry: HubRegistry) -> None:
    """The internalized principles are a FIRST-PARTY registry record —
    license-clean MIT, default-on-for-context (the native floor)."""
    rec = registry.get("deliberate-coding")
    assert rec is not None
    assert rec.owner_repo == "ekson73/multi-agent-os"
    assert rec.activation == "default-on-for-context"
    assert rec.license_spdx == "MIT"
    assert rec.security_status == "first-party"


def test_credit_is_present_and_greppable() -> None:
    """T6: 'credit the inspiration' — grep-able acceptance in the SKILL.md."""
    text = _SKILL_MD.read_text(encoding="utf-8")
    assert "Andrej Karpathy" in text
    assert "multica-ai/andrej-karpathy-skills" in text
    assert "karpathy-claude-md" in text  # links the registry intake record


def test_patterns_only_no_redistribution_markers() -> None:
    """The ADAPT conditions (patterns-only + no-redistribution) are honored
    EXPLICITLY: the skill states it carries no upstream text, and names all
    four principle families in MAOS's own wording."""
    text = _SKILL_MD.read_text(encoding="utf-8")
    assert "patterns-only" in text
    assert "no upstream text" in text.lower()
    for family in ("Think-Before-Coding", "Simplicity-First",
                   "Surgical-Changes", "Goal-Driven"):
        assert family in text, f"missing principle family: {family}"


def test_native_skill_is_content_not_runtime() -> None:
    """L0 substrate: content-only — the skill dir ships NO executables."""
    skill_dir = _SKILL_MD.parent
    non_md = [p for p in skill_dir.iterdir() if p.suffix not in (".md",)]
    assert non_md == [], f"deliberate-coding must be content-only, found: {non_md}"
