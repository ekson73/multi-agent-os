"""
HubConsole — the maos-concierge ``setup``/``config`` rendering + selection
engine (T3 / WAVE 5, ADR-006/007).

``openspec/changes/maos-hub-console/tasks.md`` T3: *"maos-concierge
setup/config modes: views preset · category · use-case · context-aware ·
prose-intent · safe-mode; --help, --safe-mode. ASCII first-class; optional
HTML artifact. Acceptance: each view renders from the registry; selection is
conflict-checked + HITL-confirmed before it writes the profile."*

Design position in the WAVE-5 chain (compose, don't reimplement):

  - **Reads** the derived ``HubRegistry`` (T1, ``lib/registry/hub_registry.py``)
    — every view is a projection of registry records + the curated
    ``recipes.yaml`` catalog. The console NEVER hand-maintains tool data.
  - **Writes** the enablement-profile SSOT (T2, ``lib/gateway/profile.py``)
    — and ONLY after (a) conflict-check vs the UNION of both edge sources
    (curated conflicts.yaml + per-record ``conflicts_with``), (b) fail-closed
    refusal of ``activation=excluded`` ids (cross-checked with the T2
    ``validate_profile`` guard before any write), (c) refusal of an EMPTY
    selection (an empty ``enabled`` list silently disables enforcement —
    ``resolver_from_profile`` treats it as passthrough), and (d) an explicit
    ``--confirm`` (the HITL gate). Without ``--confirm`` the console emits the
    DRAFT it *would* write plus the logged field ``{"written": false,
    "reason": "confirmation_required"}`` — it never auto-applies (same
    posture T5 mandates for prose-intent). Writes are ATOMIC (tmp + replace):
    the hub loads the profile fail-closed at startup, so a truncated file
    must be impossible.

Token planes (honest boundary — surfaced, not hidden): the T2 profile's
``enabled`` list is checked by the runtime gate per gateway OPERATION token
(``get``, ``create`` … — see ``profile.yaml.example``), while the console's
views/selection speak registry TOOL ids. Selecting registry ids under
``mode: enforce`` therefore gates gateway operations OFF unless operation
tokens are also enabled — ``select()`` emits the logged field
``warning: enforce_profile_gates_operations`` whenever that applies. The
plane unification (tool-tier gating riding the registry vs operation gating
riding the profile) is a T4-T6/WAVE-6 design decision, tracked on the PR.

Determinism contract (DoD-GATE): every view is byte-stable for the same
registry input — records sorted by (tier-rank, id) or (category, id); no
timestamps, no randomness. Golden-fixture tested in
``tests/test_hub_console.py``.

Two of the six views are structurally scaffolded here and gain their engines
in later worktrees (honest placeholders, still rendered FROM the registry):

  - ``context-aware`` — v1 deterministic default ranking (tier-rank, id);
    the work-compass signal engine lands in T4 (the view says so).
  - ``prose-intent``  — the bounded ≤3-question interview scaffold whose
    answer domains come from the live registry; the prose→profile mapping
    engine is ``lib/registry/prose_intent.py`` (T5).
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from html import escape
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import yaml

# Package-relative first (hub runtime), path-injected fallback (direct CLI run:
# `python3 lib/registry/console.py …` has no parent package — inject the hub
# dir so `lib.*` absolute imports resolve).
try:  # pragma: no cover - import plumbing
    from .hub_registry import ACTIVATION_TIERS, HubRecord, HubRegistry, _flatten_stack
    from .context_rank import load_signals_file, render_ranking
    from .context_rank import rank as rank_by_signals
    from ..gateway.profile import PROFILE_MODES, HubProfile, validate_profile
except ImportError:  # pragma: no cover
    _HUB_ROOT = str(Path(__file__).resolve().parents[2])  # lib/registry -> lib -> hub dir
    if _HUB_ROOT not in sys.path:
        sys.path.insert(0, _HUB_ROOT)
    from lib.registry.hub_registry import (  # type: ignore
        ACTIVATION_TIERS,
        HubRecord,
        HubRegistry,
        _flatten_stack,
    )
    from lib.registry.context_rank import load_signals_file, render_ranking  # type: ignore
    from lib.registry.context_rank import rank as rank_by_signals  # type: ignore
    from lib.gateway.profile import PROFILE_MODES, HubProfile, validate_profile  # type: ignore

VIEWS = ("preset", "category", "use-case", "context-aware", "prose-intent", "safe-mode")

_OWN_REPO = "ekson73/multi-agent-os"
_WIDTH = 78

# Higher rank = more trusted/always available. Mirrors ACTIVATION_TIERS order
# (["always-on", "default-on-for-context", "opt-in", "excluded"]).
_TIER_RANK = {tier: i for i, tier in enumerate(ACTIVATION_TIERS)}


@dataclass(frozen=True)
class Recipe:
    """One curated composition recipe (the recipes.yaml catalog entry)."""

    id: str
    use_case: str
    stack: Tuple[str, ...]
    why: str
    hitl: str


def load_recipe_catalog(path: Path) -> List[Recipe]:
    """Load the FULL recipe objects (hub_registry._load_recipes only builds
    the inverted tool→recipes map; the console needs the catalog itself)."""
    if not path.is_file():
        return []
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):  # malformed root (list/str) never crashes a view
        return []
    raw_recipes = data.get("recipes", [])
    if not isinstance(raw_recipes, list):
        return []
    out: List[Recipe] = []
    for raw in raw_recipes:
        if not isinstance(raw, dict):
            continue
        rid = str(raw.get("id") or "").strip()
        if not rid:
            continue
        out.append(
            Recipe(
                id=rid,
                use_case=str(raw.get("use_case") or ""),
                stack=tuple(
                    t.strip()
                    for t in _flatten_stack(raw.get("stack", []))
                    if t.strip() and t.strip().lower() != "none"
                ),
                why=str(raw.get("why") or ""),
                hitl=str(raw.get("hitl") or ""),
            )
        )
    return sorted(out, key=lambda r: r.id)


def _rule(char: str = "-") -> str:
    return char * _WIDTH


def _sorted_records(registry: HubRegistry) -> List[HubRecord]:
    return sorted(registry.records(), key=lambda r: (_TIER_RANK[r.activation], r.id))


def _record_line(rec: HubRecord) -> str:
    return f"  {rec.id:<28} {rec.activation:<24} {rec.license_spdx:<12} {rec.owner_repo}"


def _record_header() -> List[str]:
    return [
        f"  {'id':<28} {'activation':<24} {'license':<12} owner_repo",
        "  " + _rule()[:76],
    ]


class HubConsole:
    """Deterministic ASCII renderer + HITL-gated profile writer over the
    T1 registry and the T2 profile SSOT."""

    def __init__(
        self,
        registry: HubRegistry,
        recipes: Sequence[Recipe],
        signals: Sequence[str] = (),
    ) -> None:
        self.registry = registry
        self.recipes = sorted(recipes, key=lambda r: r.id)
        self.signals: Tuple[str, ...] = tuple(sorted(set(signals)))

    # ------------------------------------------------------------------ views

    def render(self, view: str) -> str:
        if view not in VIEWS:
            raise ValueError(f"unknown view {view!r} (expected one of {VIEWS})")
        body = {
            "preset": self._view_preset,
            "category": self._view_category,
            "use-case": self._view_use_case,
            "context-aware": self._view_context_aware,
            "prose-intent": self._view_prose_intent,
            "safe-mode": self._view_safe_mode,
        }[view]()
        head = [
            _rule("="),
            f" MAOS Hub console — view: {view}  (registry: {len(self.registry)} records)",
            _rule("="),
        ]
        return "\n".join(head + body) + "\n"

    def _tier_of(self, tool_id: str) -> str:
        rec = self.registry.get(tool_id)
        return rec.activation if rec is not None else "(not in registry)"

    def _view_preset(self) -> List[str]:
        """Curated presets = the recipe stacks as ready-to-select bundles,
        each tool annotated with its DERIVED activation tier."""
        lines: List[str] = []
        if not self.recipes:
            return [" (no recipes promoted — lib/gateway/recipes.yaml absent/empty)"]
        for r in self.recipes:
            lines.append(f" preset: {r.id}  [{r.use_case}]")
            for tool in r.stack:
                lines.append(f"   - {tool:<28} tier: {self._tier_of(tool)}")
            lines.append(f"   HITL: {r.hitl}")
            lines.append(_rule())
        lines.append(
            " select a preset: console.py select --ids <stack,ids> --confirm --write <profile.yaml>"
        )
        return lines

    def _view_category(self) -> List[str]:
        lines: List[str] = []
        by_cat: Dict[str, List[HubRecord]] = {}
        for rec in self.registry.records():
            by_cat.setdefault(rec.category, []).append(rec)
        for cat in sorted(by_cat):
            lines.append(f" category: {cat}  ({len(by_cat[cat])})")
            lines.extend(_record_header())
            for rec in sorted(by_cat[cat], key=lambda r: r.id):
                lines.append(_record_line(rec))
            lines.append(_rule())
        return lines or [" (registry empty)"]

    def _view_use_case(self) -> List[str]:
        lines: List[str] = []
        if not self.recipes:
            return [" (no recipes promoted — lib/gateway/recipes.yaml absent/empty)"]
        for r in self.recipes:
            lines.append(f" use-case: {r.use_case}  (recipe: {r.id})")
            lines.append(f"   why : {r.why}")
            lines.append(f"   HITL: {r.hitl}")
            lines.append(f"   stack ({len(r.stack)}): {', '.join(r.stack)}")
            lines.append(_rule())
        return lines

    def _view_context_aware(self) -> List[str]:
        if self.signals:
            # T4 engine: deterministic ranking by work-compass signals,
            # reasons ("why") emitted per record (lib/registry/context_rank.py).
            ranking = rank_by_signals(self.registry, self.signals)
            return render_ranking(ranking, self.signals)
        lines = [
            " context-aware ranking v1 — DEFAULT deterministic ordering",
            " (tier-rank, id): no work-compass snapshot provided. Pass a",
            " `bin/work-compass-aggregate.py --json` snapshot via --signals to",
            " rank by project signals with per-record reasoning (T4 engine).",
            _rule(),
        ]
        lines.extend(_record_header())
        for rec in _sorted_records(self.registry):
            lines.append(_record_line(rec))
        return lines

    def _view_prose_intent(self) -> List[str]:
        cats = sorted({rec.category for rec in self.registry.records()})
        lines = [
            " prose-intent — bounded interview (<=3 questions) -> profile DRAFT.",
            " Engine: lib/registry/prose_intent.py --prose '<need>' (T5) — emits the",
            " shown prose->profile mapping; the answer domains below are derived",
            " LIVE from the registry. A draft NEVER auto-applies.",
            _rule(),
            " Q1. What are you building? (maps to a use-case recipe)",
        ]
        for r in self.recipes:
            lines.append(f"      - {r.id}: {r.use_case}")
        lines.append(" Q2. Which capability categories do you need?")
        for cat in cats:
            lines.append(f"      - {cat}")
        lines.append(" Q3. Enforcement posture? (enforce | advisory)")
        return lines

    def _view_safe_mode(self) -> List[str]:
        """Conservative floor: always-on records + FIRST-PARTY
        default-on-for-context. Third-party opt-in/excluded hidden."""
        safe = [
            rec
            for rec in _sorted_records(self.registry)
            if rec.activation == "always-on"
            or (rec.activation == "default-on-for-context" and rec.owner_repo == _OWN_REPO)
        ]
        lines = [
            " safe-mode — the conservative floor (always-on substrates +",
            f" first-party default-on-for-context; {len(safe)} of {len(self.registry)} records).",
            _rule(),
        ]
        lines.extend(_record_header())
        lines.extend(_record_line(rec) for rec in safe)
        return lines

    # -------------------------------------------------------------- selection

    def check_selection(self, ids: Sequence[str]) -> Dict[str, Any]:
        """Conflict-check + fail-closed activation check for a selection.

        Returns a LOGGED-FIELD dict (never prose-judged):
          verdict          — "ok" | "refused"
          conflicts        — [[a, b], ...] pairs inside the selection that the
                             registry marks mutually exclusive
          excluded         — ids whose derived activation == excluded
          unknown          — ids not present in the registry (allowed: the T2
                             profile also carries gateway operation tokens the
                             registry does not model; surfaced for the human)
        """
        chosen = sorted(dict.fromkeys(str(i).strip() for i in ids if str(i).strip()))
        chosen_set = set(chosen)
        # Both edge sources: the curated conflicts.yaml promotion (loaded at
        # derive-time) AND the per-record conflicts_with fields — a pair is
        # mutually exclusive if EITHER source says so (fail-closed union).
        all_edges = self.registry.conflict_edges() | self.registry.edges_from_records()
        conflicts = sorted(
            sorted(edge)
            for edge in all_edges
            if len(edge) == 2 and edge <= chosen_set
        )
        excluded = sorted(
            tid
            for tid in chosen
            if (rec := self.registry.get(tid)) is not None and rec.activation == "excluded"
        )
        unknown = sorted(tid for tid in chosen if self.registry.get(tid) is None)
        verdict = "ok" if not conflicts and not excluded else "refused"
        return {
            "verdict": verdict,
            "ids": chosen,
            "conflicts": [list(pair) for pair in conflicts],
            "excluded": excluded,
            "unknown": unknown,
        }

    def profile_draft(self, ids: Sequence[str], mode: str = "enforce") -> str:
        """The exact YAML the console WOULD write (shown pre-confirmation)."""
        if mode not in PROFILE_MODES:  # API-level guard, not only the CLI (Qodo #3)
            raise ValueError(f"profile mode must be one of {PROFILE_MODES}, got: {mode!r}")
        check = self.check_selection(ids)
        doc = {
            "schema_version": "hub-profile/1.0.0",
            "mode": mode,
            "enabled": check["ids"],
        }
        return yaml.safe_dump(doc, sort_keys=False, allow_unicode=True)

    def select(
        self,
        ids: Sequence[str],
        mode: str = "enforce",
        write_path: Optional[Path] = None,
        confirm: bool = False,
    ) -> Dict[str, Any]:
        """The T3 acceptance path: conflict-checked + HITL-confirmed BEFORE
        any profile write. Returns logged fields only."""
        if mode not in PROFILE_MODES:  # API-level guard, not only the CLI (Qodo #3)
            raise ValueError(f"profile mode must be one of {PROFILE_MODES}, got: {mode!r}")
        result = self.check_selection(ids)
        result["mode"] = mode
        if not result["ids"]:
            # An empty enforce-profile is a silent passthrough (Qodo #5) —
            # never a valid thing to persist from a selection flow.
            result["verdict"] = "refused"
            result["written"] = False
            result["reason"] = "empty_selection"
            result["draft"] = ""
            return result
        result["draft"] = self.profile_draft(ids, mode=mode)
        known_registry_ids = [i for i in result["ids"] if self.registry.get(i) is not None]
        if mode == "enforce" and known_registry_ids:
            # Token-plane surfacing (Qodo #1): the runtime gate checks gateway
            # OPERATION tokens; registry TOOL ids in an enforce profile do not
            # enable operations by themselves.
            result["warning"] = "enforce_profile_gates_operations"
        if result["verdict"] == "refused":
            result["written"] = False
            result["reason"] = "selection_refused"
            return result
        if not confirm:
            # The HITL gate: rendering the draft is free; APPLYING requires
            # the explicit human confirmation flag.
            result["written"] = False
            result["reason"] = "confirmation_required"
            return result
        if write_path is None:
            result["written"] = False
            result["reason"] = "no_write_path"
            return result
        # Belt-and-braces (Copilot #1): re-run the T2 fail-closed guard on the
        # exact profile about to be persisted — the SSOT of the excluded-id
        # rule lives in lib.gateway.profile.validate_profile.
        draft_profile = HubProfile(
            enabled=tuple(result["ids"]), mode=mode, source="<console-draft>"
        )
        violations = validate_profile(draft_profile, self.registry)
        if violations:
            result["verdict"] = "refused"
            result["written"] = False
            result["reason"] = "validate_profile_refused"
            result["violations"] = violations
            return result
        write_path = Path(write_path)
        write_path.parent.mkdir(parents=True, exist_ok=True)
        # Atomic write (Qodo #2): the hub loads this file fail-closed at
        # startup — a truncated YAML must be impossible.
        tmp = write_path.with_suffix(write_path.suffix + ".tmp")
        try:
            tmp.write_text(result["draft"], encoding="utf-8")
            tmp.replace(write_path)
        except BaseException:
            tmp.unlink(missing_ok=True)
            raise
        result["written"] = True
        result["path"] = str(write_path)
        return result

    # ------------------------------------------------------------------- html

    def render_html(self, view: str) -> str:
        """Optional HTML artifact — a minimal wrapper around the ASCII
        first-class rendering (tasks.md: 'ASCII first-class; optional HTML')."""
        ascii_body = self.render(view)
        return (
            "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\">"
            f"<title>MAOS Hub console — {escape(view)}</title></head>\n"
            "<body style=\"background:#111;color:#ddd\">"
            f"<pre>{escape(ascii_body)}</pre></body></html>\n"
        )


# ----------------------------------------------------------------------- CLI


_USAGE = """\
MAOS Hub console (T3) — render registry views / write the enablement profile.

usage:
  console.py view <name> [--repo-root P] [--as-of DATE] [--html OUT.html]
                  [--signals COMPASS.json]   # work-compass --json snapshot (T4 ranking)
  console.py select --ids a,b,c [--mode enforce|advisory] [--write PROFILE.yaml] [--confirm]
  console.py --safe-mode            # shortcut for: view safe-mode
  console.py --help

views: preset | category | use-case | context-aware | prose-intent | safe-mode

Selection is conflict-checked against BOTH edge sources (curated
conflicts.yaml UNION per-record conflicts_with), fail-closed
(activation=excluded refused; empty selection refused) and NEVER writes
without --confirm (HITL gate). NOTE: the runtime gate checks gateway
OPERATION tokens (see profile.yaml.example) — enforce-profiles built from
registry TOOL ids emit `warning: enforce_profile_gates_operations`.
"""


def _build_console(
    repo_root: Path, as_of: str, signals: Sequence[str] = ()
) -> HubConsole:
    registry = HubRegistry.derive(repo_root, as_of=as_of)
    recipes = load_recipe_catalog(
        repo_root / "mcp-tools" / "maos-mcp-hub" / "lib" / "gateway" / "recipes.yaml"
    )
    return HubConsole(registry, recipes, signals=signals)


def _main(argv: List[str]) -> int:
    here = Path(__file__).resolve()
    repo_root = here.parents[4]  # lib/registry/x.py -> lib -> maos-mcp-hub -> mcp-tools -> ROOT
    as_of = "1970-01-01"
    args = list(argv)
    if not args or "--help" in args or "-h" in args:
        print(_USAGE)
        return 0
    if args == ["--safe-mode"]:
        args = ["view", "safe-mode"]

    cmd = args.pop(0)
    view_name: Optional[str] = None
    html_out: Optional[Path] = None
    ids: List[str] = []
    mode = "enforce"
    write_path: Optional[Path] = None
    confirm = False
    signals: Tuple[str, ...] = ()
    if cmd == "view" and args and not args[0].startswith("--"):
        view_name = args.pop(0)
    while args:
        a = args.pop(0)
        if a == "--repo-root" and args:
            repo_root = Path(args.pop(0)).resolve()
        elif a == "--as-of" and args:
            as_of = args.pop(0)
        elif a == "--html" and args:
            html_out = Path(args.pop(0))
        elif a == "--signals" and args:
            # A work-compass --json snapshot file (T4). Malformed/missing
            # degrades to the tier-ordered baseline (fail-safe, logged below).
            sig_path = Path(args.pop(0))
            signals = load_signals_file(sig_path)
            if not signals:
                print(f"[signals] no usable tokens from {sig_path} — baseline order", file=sys.stderr)
        elif a == "--ids" and args:
            ids = [s for s in args.pop(0).split(",") if s.strip()]
        elif a == "--mode" and args:
            mode = args.pop(0)
        elif a == "--write" and args:
            write_path = Path(args.pop(0))
        elif a == "--confirm":
            confirm = True
        elif a == "--safe-mode":
            cmd, view_name = "view", "safe-mode"
        else:
            # Unknown flags never silently no-op (Copilot #3) — a typo must
            # not run the console with unintended defaults.
            print(json.dumps({"verdict": "fail", "error": f"unknown argument: {a}"}))
            return 2

    if not (repo_root / "skills").is_dir():  # empirical root check (Qodo lesson, T1)
        print(json.dumps({"verdict": "fail", "error": f"not a repo root: {repo_root}"}))
        return 1
    console = _build_console(repo_root, as_of, signals=signals)

    if cmd == "view":
        if view_name not in VIEWS:
            print(_USAGE)
            return 1
        print(console.render(view_name), end="")
        if html_out is not None:
            html_out.write_text(console.render_html(view_name), encoding="utf-8")
            print(f"[html artifact] {html_out}")
        return 0
    if cmd == "select":
        if mode not in ("enforce", "advisory"):
            print(json.dumps({"verdict": "fail", "error": f"invalid mode: {mode}"}))
            return 1
        result = console.select(ids, mode=mode, write_path=write_path, confirm=confirm)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["verdict"] == "ok" else 1
    print(_USAGE)
    return 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(_main(sys.argv[1:]))
