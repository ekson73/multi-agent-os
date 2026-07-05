"""
PolicyResolver — dumb, in-memory gating policy for the MoE hub seam.

This is the v1 "teeth" of the hub gating-network (see
research/agentic-moe-2026/20260628-solutions-debate.md §P1). It answers a
single question the router asks before dispatch::

    resolver.check(tool_id) -> PolicyDecision(allow | deny + reason)

Design constraints (intentional, v1):
  - In-memory only. No file watching, no reload, no async.
  - The active profile (the set of enabled tool ids) comes from OUTSIDE —
    the resolver does not discover or compute it.
  - Default is allow-all: an empty/None profile means "nothing is gated",
    so a router constructed with ``policy=None`` (or a resolver with no
    profile) is a passthrough and changes zero behaviour.

The conflict model is an undirected incompatibility edge-list curated from
the N-Tree analysis (``20260627-02-ntree-moe.md`` §2.7 / §5). A tool is
denied if EITHER:
  - it is not in the active profile (explicitly disabled), OR
  - it has a ``conflicts_with`` edge against any tool already in the active
    profile.

The resolver loads ``conflicts.yaml`` from the gateway directory by default,
but callers/tests may inject their own edge-list or profile.
"""

from __future__ import annotations

import logging
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Deque, Dict, FrozenSet, Iterable, List, Optional, Set, Tuple

import yaml

logger = logging.getLogger("maos_hub.policy")

#: Bounded ring of recorded deny decisions (memory-safe on a hot path).
DECISION_LOG_MAXLEN = 200


@dataclass
class PolicyDecision:
    """Result of a single ``check`` call."""

    allow: bool
    reason: Optional[str] = None
    # When denied by a conflict, the offending already-active tool ids.
    conflicting_with: List[str] = field(default_factory=list)

    def __bool__(self) -> bool:  # allow truthy use: ``if resolver.check(x):``
        return self.allow


class PolicyResolver:
    """In-memory allow/deny resolver for tool activation.

    Args:
        profile: iterable of enabled tool ids (the "active profile"). When
            None or empty, the resolver is a passthrough (allow-all).
        conflicts: iterable of (a, b) undirected incompatibility pairs. When
            None, no conflict edges are loaded (callers may inject later).
    """

    def __init__(
        self,
        profile: Optional[Iterable[str]] = None,
        conflicts: Optional[Iterable[Tuple[str, str]]] = None,
    ) -> None:
        self._profile: Set[str] = set(profile or [])
        # adjacency: tool_id -> frozenset of tool_ids it conflicts with
        self._conflicts: Dict[str, Set[str]] = {}
        for a, b in conflicts or []:
            self._add_edge(a, b)
        # T2 (WAVE-5): every DENY is recorded here (the "decision is logged"
        # acceptance — a checkable field, not prose) + mirrored to `logging`.
        self._decisions: Deque[Dict[str, object]] = deque(maxlen=DECISION_LOG_MAXLEN)

    # -- construction helpers ------------------------------------------------

    def _add_edge(self, a: str, b: str) -> None:
        if not a or not b or a == b:
            return
        self._conflicts.setdefault(a, set()).add(b)
        self._conflicts.setdefault(b, set()).add(a)

    def set_profile(self, profile: Iterable[str]) -> None:
        self._profile = set(profile or [])

    @property
    def profile(self) -> FrozenSet[str]:
        return frozenset(self._profile)

    @property
    def edge_count(self) -> int:
        """Number of undirected conflict edges loaded."""
        return sum(len(v) for v in self._conflicts.values()) // 2

    def conflicts_for(self, tool_id: str) -> FrozenSet[str]:
        return frozenset(self._conflicts.get(tool_id, set()))

    # -- the seam contract ---------------------------------------------------

    def check(self, tool_id: str) -> PolicyDecision:
        """Decide whether ``tool_id`` may be activated under the policy.

        Default = allow-all when no profile is set (passthrough).
        """
        # No active profile => nothing is gated. Pure passthrough.
        if not self._profile:
            return PolicyDecision(allow=True)

        # Disabled: the tool is not part of the active profile.
        if tool_id not in self._profile:
            return self._deny(
                tool_id,
                reason=(
                    f"Tool '{tool_id}' is not enabled in the active profile "
                    f"(disabled by policy)."
                ),
            )

        # Conflict: the tool clashes with something already active.
        clashes = sorted(self._conflicts.get(tool_id, set()) & self._profile)
        if clashes:
            return self._deny(
                tool_id,
                reason=(
                    f"Tool '{tool_id}' conflicts with active tool(s): "
                    f"{', '.join(clashes)}."
                ),
                conflicting_with=clashes,
            )

        return PolicyDecision(allow=True)

    def _deny(
        self,
        tool_id: str,
        reason: str,
        conflicting_with: Optional[List[str]] = None,
    ) -> PolicyDecision:
        """Record + log a deny (T2: the routing decision is a logged field)."""
        record: Dict[str, object] = {
            "tool_id": tool_id,
            "allow": False,
            "reason": reason,
            "conflicting_with": list(conflicting_with or []),
        }
        self._decisions.append(record)
        logger.warning("policy deny: %s — %s", tool_id, reason)
        return PolicyDecision(
            allow=False, reason=reason, conflicting_with=list(conflicting_with or [])
        )

    @property
    def decisions(self) -> List[Dict[str, object]]:
        """The recorded deny decisions (bounded ring, oldest first)."""
        return list(self._decisions)

    # -- loading -------------------------------------------------------------

    @classmethod
    def from_yaml(
        cls,
        path: Optional[Path] = None,
        profile: Optional[Iterable[str]] = None,
    ) -> "PolicyResolver":
        """Build a resolver loading conflict edges from a YAML file.

        The YAML schema is a flat list under a ``conflicts`` key::

            conflicts:
              - [ECC, base]
              - {a: ECC, b: gstack, reason: "duplicate hooks"}

        Both list-pair and mapping forms are accepted. ``profile`` is still
        injected by the caller (the file does NOT define the active profile).
        """
        if path is None:
            path = Path(__file__).resolve().parent / "conflicts.yaml"
        edges = load_conflicts(path)
        return cls(profile=profile, conflicts=edges)


def load_conflict_records(path: Path) -> List[Dict[str, str]]:
    """Parse a conflicts YAML file into RICH edge records (issue #182).

    Returns one ``{a, b, reason, layer}`` dict per edge — ``reason`` and
    ``layer`` default to ``""`` for bare ``[a, b]`` pairs. Same validation
    contract as :func:`load_conflicts` (ValueError on malformed edges so a
    broken file fails loudly). Consumers that only need the pair topology
    should keep using :func:`load_conflicts` (which now derives from this).
    """
    raw = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    items = raw.get("conflicts", []) if isinstance(raw, dict) else raw
    records: List[Dict[str, str]] = []
    for entry in items or []:
        if isinstance(entry, (list, tuple)):
            if len(entry) < 2:
                raise ValueError(f"Conflict edge needs 2 ids, got: {entry!r}")
            records.append(
                {"a": str(entry[0]), "b": str(entry[1]), "reason": "", "layer": ""}
            )
        elif isinstance(entry, dict):
            if "a" not in entry or "b" not in entry:
                raise ValueError(f"Conflict mapping needs 'a' and 'b': {entry!r}")
            records.append(
                {
                    "a": str(entry["a"]),
                    "b": str(entry["b"]),
                    "reason": str(entry.get("reason", "") or ""),
                    "layer": str(entry.get("layer", "") or ""),
                }
            )
        else:
            raise ValueError(f"Unsupported conflict entry: {entry!r}")
    return records


def load_conflicts(path: Path) -> List[Tuple[str, str]]:
    """Parse a conflicts YAML file into a list of (a, b) edge tuples.

    Accepts each edge as either a 2-item sequence ``[a, b]`` or a mapping
    with ``a``/``b`` keys (extra keys like ``reason`` are ignored). Raises
    ValueError on malformed edges so a broken file fails loudly.
    """
    return [(r["a"], r["b"]) for r in load_conflict_records(path)]
