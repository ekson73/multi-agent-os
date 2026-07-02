"""
ContextRank — deterministic context-aware ranking v1 (T4 / WAVE 5, ADR-006/007).

``openspec/changes/maos-hub-console/tasks.md`` T4: *"deterministic ranking by
`work-compass` project signals, reasoning shown. Acceptance: same input →
same ranking (byte-stable); the 'why' is emitted."*

Position in the WAVE-5 chain (compose, don't reimplement):

  - **Signals come from `work-compass`** (`bin/work-compass-aggregate.py
    --json` — the CPT §9.5 consumer that aggregates sessions · worktrees ·
    branches · GitHub · Jira into one graph). This module consumes that
    graph as a SNAPSHOT input; it never re-collects (the collector already
    exists and is itself deterministic per its own contract).
  - **Ranking is over the derived T1 ``HubRegistry``** + the curated recipe
    catalog — the same data plane every console view projects.
  - **The console's `context-aware` view** (T3 scaffold — "engine lands in
    T4") upgrades to this engine when a signals snapshot is provided, and
    keeps the tier-ordered baseline when none is.

Determinism contract (DoD-GATE — "same input → same ranking, byte-stable"):

  - Signal extraction ignores volatile fields (``meta.generated_utc``,
    timestamps) — only stable content (item ids, titles, domains, refs)
    becomes tokens.
  - Tokens, matches, and reasons are SORTED; scoring is pure integer
    arithmetic; the final order is the total order ``(-score, tier-rank,
    id)`` — no floats, no randomness, no clock.

The "why" contract: every ranked entry carries ``why: [str, ...]`` — one
human-readable reason per scoring contribution (which signal token matched
which field, plus the activation-tier prior). An entry that scored 0 says so
explicitly (``no signal match; activation-tier baseline``).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Sequence, Set, Tuple

# Package-relative first (hub runtime), path-injected fallback (direct CLI /
# pytest — same plumbing as console.py).
try:  # pragma: no cover - import plumbing
    from .hub_registry import ACTIVATION_TIERS, HubRegistry
except ImportError:  # pragma: no cover
    _HUB_ROOT = str(Path(__file__).resolve().parents[2])
    if _HUB_ROOT not in sys.path:
        sys.path.insert(0, _HUB_ROOT)
    from lib.registry.hub_registry import ACTIVATION_TIERS, HubRegistry  # type: ignore

_TIER_RANK = {tier: i for i, tier in enumerate(ACTIVATION_TIERS)}

# Tier prior: substrates that are always-on deserve to surface first at equal
# signal relevance (they are the floor every recipe stands on).
_TIER_PRIOR = {"always-on": 2, "default-on-for-context": 1}

_TOKEN_RE = re.compile(r"[a-z0-9]{3,}")

# Ubiquitous repo/workflow words that carry no project-signal meaning.
_STOPWORDS = frozenset(
    (
        # NOTE: "refactor"/"legacy" are NOT stopwords — a `refactor/…` branch
        # is exactly the intent signal that should surface `legacy-refactor`.
        "the and for with from feat fix chore docs test tests main master "
        "branch worktree session issue merge merged open closed done wip pull "
        "request unknown none null true false"
    ).split()
)


def _tokens(text: str) -> Set[str]:
    return {t for t in _TOKEN_RE.findall(text.lower()) if t not in _STOPWORDS}


def extract_signals(compass_graph: Any) -> Tuple[str, ...]:
    """Deterministic signal-token bag from a work-compass ``--json`` graph.

    Only STABLE content contributes (item ``id``/``title``/``domain`` + the
    values of ``refs``); volatile fields (``meta.generated_utc``, ``last_ts``,
    ``status``) are ignored so two snapshots of the same project state yield
    the same tokens. Malformed input degrades to an empty bag (fail-safe:
    the console then renders the tier-ordered baseline)."""
    if not isinstance(compass_graph, dict):
        return ()
    items = compass_graph.get("items", [])
    if not isinstance(items, list):
        return ()
    bag: Set[str] = set()
    for it in items:
        if not isinstance(it, dict):
            continue
        for field in ("id", "title", "domain"):
            bag |= _tokens(str(it.get(field) or ""))
        refs = it.get("refs")
        if isinstance(refs, dict):
            for v in refs.values():
                bag |= _tokens(str(v or ""))
    return tuple(sorted(bag))


def rank(
    registry: HubRegistry,
    signals: Sequence[str],
    top: int = 0,
) -> List[Dict[str, Any]]:
    """Rank registry records by signal relevance — reasons ("why") emitted.

    Scoring (pure integers, documented so the "why" is checkable):
      +2  per distinct signal token found in the record's TOOL ID
      +1  per distinct signal token found in one of the record's RECIPE ids
      +1  per distinct signal token equal to the record's CATEGORY
      +2/+1 activation-tier prior (always-on / default-on-for-context)
    ``activation=excluded`` records are NEVER ranked (they are not offerable).

    Total order: ``(-score, tier-rank, id)`` — byte-stable for equal input.
    """
    sig = sorted(set(signals))
    out: List[Dict[str, Any]] = []
    for rec in registry.records():
        if rec.activation == "excluded":
            continue
        score = 0
        why: List[str] = []
        id_tokens = _tokens(rec.id)
        recipe_tokens = {r: _tokens(r) for r in rec.recipes}
        for token in sig:
            if token in id_tokens:
                score += 2
                why.append(f"signal '{token}' matches tool id '{rec.id}' (+2)")
            for rid in sorted(recipe_tokens):
                if token in recipe_tokens[rid]:
                    score += 1
                    why.append(f"signal '{token}' matches recipe '{rid}' (+1)")
            if token == rec.category.lower():
                score += 1
                why.append(f"signal '{token}' matches category (+1)")
        prior = _TIER_PRIOR.get(rec.activation, 0)
        if prior:
            score += prior
            why.append(f"activation-tier prior: {rec.activation} (+{prior})")
        if not why:
            why.append("no signal match; activation-tier baseline")
        out.append(
            {
                "id": rec.id,
                "score": score,
                "activation": rec.activation,
                "category": rec.category,
                "why": why,
            }
        )
    out.sort(key=lambda e: (-e["score"], _TIER_RANK[e["activation"]], e["id"]))
    return out[:top] if top else out


def load_signals_file(path: Path) -> Tuple[str, ...]:
    """Load a work-compass ``--json`` snapshot file → signal tokens.
    Malformed JSON degrades to an empty bag (fail-safe, never crashes a view)."""
    try:
        return extract_signals(json.loads(Path(path).read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError):
        return ()


def render_ranking(ranking: List[Dict[str, Any]], signals: Sequence[str]) -> List[str]:
    """ASCII lines for the console's context-aware view (reasons inline)."""
    lines = [
        f" context-aware ranking v1 — {len(signals)} project signal token(s)"
        f" (work-compass snapshot), {len(ranking)} rankable record(s).",
        " order: (-score, tier-rank, id) — deterministic; excluded ids never ranked.",
        "-" * 78,
    ]
    for pos, entry in enumerate(ranking, start=1):
        lines.append(
            f" {pos:>2}. {entry['id']:<28} score: {entry['score']:<4}"
            f" tier: {entry['activation']}"
        )
        for reason in entry["why"]:
            lines.append(f"       why: {reason}")
    return lines
