"""
HubProfile — the persisted enablement-profile SSOT (T2 / WAVE 5, ADR-006/007).

The WAVE-0 gating seam (``lib/gateway/policy.py``) is deliberately dumb: the
active profile "comes from OUTSIDE — the resolver does not discover or compute
it". THIS module is that outside: it persists/loads the operator's enablement
profile and turns it into the ``PolicyResolver`` the hub attaches to every
gateway router (``openspec/changes/maos-hub-console/tasks.md`` T2: *"persist an
enablement profile SSOT; wire the MAOS Hub gating to honor it"*).

Profile file schema (YAML)::

    schema_version: hub-profile/1.0.0
    mode: enforce            # enforce | advisory
    enabled:                 # the ids the operator turned ON
      - get_issue
      - list_pages

Resolution order (first hit wins)::

    explicit ``path`` arg  >  $MAOS_HUB_PROFILE  >  <hub dir>/profile.yaml  >  None

Safety posture (all fail-safe toward today's behaviour):

  - **Absent profile => passthrough.** ``load_profile()`` returns ``None`` and
    ``resolver_from_profile(None)`` returns ``None`` => ``router.policy=None``
    => the pre-WAVE-5 zero-gating behaviour. Nothing changes until an operator
    persists a profile with ``mode: enforce``.
  - **advisory mode => loaded but NOT enforced** (the console can display it;
    routing is untouched).
  - **Fail-closed vs the registry** (spec ``maos-hub-registry`` → Activation
    gating): ``validate_profile(profile, registry)`` rejects a profile that
    enables an id the HubRegistry classifies ``activation=excluded`` — a
    supply-chain veto cannot be re-enabled by editing YAML.
  - **Denials are LOGGED fields**: the resolver built here records every deny
    in ``PolicyResolver.decisions`` (bounded ring) and emits a
    ``logging`` warning — the T2 acceptance ("the decision is logged").
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, List, Optional, Tuple

import yaml

from .policy import PolicyResolver

PROFILE_SCHEMA_VERSION = "hub-profile/1.0.0"
PROFILE_ENV_VAR = "MAOS_HUB_PROFILE"
PROFILE_MODES = ("enforce", "advisory")

_HUB_DIR = Path(__file__).resolve().parents[2]  # lib/gateway/x.py -> lib -> hub dir
DEFAULT_PROFILE_PATH = _HUB_DIR / "profile.yaml"


class ProfileError(ValueError):
    """A profile file exists but is invalid — fail loudly, never half-load."""


@dataclass(frozen=True)
class HubProfile:
    """The parsed enablement profile (the SSOT record, not the resolver)."""

    enabled: Tuple[str, ...]
    mode: str
    source: str
    schema_version: str = PROFILE_SCHEMA_VERSION

    def to_dict(self) -> dict:
        return {
            "schema_version": self.schema_version,
            "mode": self.mode,
            "enabled": list(self.enabled),
            "source": self.source,
        }


def load_profile(path: Optional[Path] = None) -> Optional[HubProfile]:
    """Load the profile SSOT, or ``None`` when no profile is persisted.

    Resolution order: ``path`` arg > ``$MAOS_HUB_PROFILE`` > the default
    ``<hub>/profile.yaml``. A missing file at the resolved location => None
    (passthrough). A PRESENT-but-invalid file raises ``ProfileError``.
    """
    resolved: Optional[Path]
    if path is not None:
        resolved = Path(path)
    elif os.environ.get(PROFILE_ENV_VAR):
        resolved = Path(os.environ[PROFILE_ENV_VAR])
    else:
        resolved = DEFAULT_PROFILE_PATH
    if not resolved.is_file():
        return None

    try:
        raw = yaml.safe_load(resolved.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ProfileError(f"profile is not valid YAML: {resolved}: {exc}") from exc
    if not isinstance(raw, dict):
        raise ProfileError(f"profile must be a mapping: {resolved}")

    mode = str(raw.get("mode", "enforce"))
    if mode not in PROFILE_MODES:
        raise ProfileError(f"profile mode must be one of {PROFILE_MODES}, got: {mode!r}")
    enabled_raw = raw.get("enabled", [])
    if not isinstance(enabled_raw, list):
        raise ProfileError(f"profile 'enabled' must be a list: {resolved}")
    enabled = tuple(str(x) for x in enabled_raw)
    schema = str(raw.get("schema_version", PROFILE_SCHEMA_VERSION))
    return HubProfile(enabled=enabled, mode=mode, source=str(resolved), schema_version=schema)


def validate_profile(profile: HubProfile, registry: Any) -> List[str]:
    """Fail-closed guard vs the HubRegistry (spec: Activation gating).

    Returns a list of violations (empty == valid). ``registry`` is a
    ``lib.registry.HubRegistry`` (duck-typed: needs ``get(id)``).
    """
    errors: List[str] = []
    for tid in profile.enabled:
        rec = registry.get(tid)
        if rec is not None and rec.activation == "excluded":
            errors.append(
                f"profile enables '{tid}' but the registry classifies it "
                f"activation=excluded ({rec.security_status}) — refused (fail-closed)"
            )
    return errors


def resolver_from_profile(
    profile: Optional[HubProfile],
    conflicts_path: Optional[Path] = None,
) -> Optional[PolicyResolver]:
    """Build the enforcing resolver, or ``None`` (passthrough) when there is
    nothing to enforce: no profile, ``mode: advisory``, or an empty profile.
    """
    if profile is None or profile.mode != "enforce" or not profile.enabled:
        return None
    return PolicyResolver.from_yaml(path=conflicts_path, profile=profile.enabled)
