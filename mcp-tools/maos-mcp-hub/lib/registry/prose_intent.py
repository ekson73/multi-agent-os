"""
ProseIntent — prose need → bounded interview (≤3 Qs) → profile DRAFT
(T5 / WAVE 5, ADR-006/007).

``openspec/changes/maos-hub-console/tasks.md`` T5: *"prose need → bounded
interview (≤3 Qs) → custom profile DRAFT (HITL). Acceptance: the
prose→profile mapping is shown; never auto-applies."*

Position in the WAVE-5 chain (compose, don't reimplement):

  - **Matching is over the curated recipe catalog** (``recipes.yaml`` — the
    Phase-2 §4 use-case stacks) + the derived T1 ``HubRegistry``; tokenizing
    reuses the T4 ``context_rank`` tokenizer (one tokenizer, one behavior).
  - **The output is a DRAFT, never an application.** This module has NO
    write capability at all — ``map_prose()`` returns logged fields
    (``applied: false`` always) and the draft YAML text. Applying goes
    through the ONE existing gate: ``console.py select --ids … --confirm``
    (T3 — conflict-checked + fail-closed + HITL-confirmed). One write path,
    one set of gates.
  - **Conflicts inside a recipe stack are surfaced, not silently resolved**:
    recipe stacks carry OR-alternatives (e.g. ``spec-kit`` OR ``openspec``,
    mutually exclusive) — the mapping lists them as ``open_questions`` for
    the human, because choosing is the recipe's own documented HITL point.

Determinism contract (DoD-GATE): pure-integer token-overlap scoring, sorted
outputs, no clock/randomness — same prose + same registry ⇒ same mapping.

The bounded interview: when the prose matches NOTHING (all recipe scores 0),
the module returns the ≤3-question interview (answer domains derived LIVE
from the registry/catalog — same questions the T3 ``prose-intent`` view
scaffolds) instead of a fabricated mapping (anti-theater: no invented
intent).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Sequence

import yaml

# Package-relative first (hub runtime), path-injected fallback (direct CLI /
# pytest — same plumbing as console.py / context_rank.py).
try:  # pragma: no cover - import plumbing
    from .console import Recipe, load_recipe_catalog
    from .context_rank import _tokens
    from .hub_registry import HubRegistry
except ImportError:  # pragma: no cover
    _HUB_ROOT = str(Path(__file__).resolve().parents[2])
    if _HUB_ROOT not in sys.path:
        sys.path.insert(0, _HUB_ROOT)
    from lib.registry.console import Recipe, load_recipe_catalog  # type: ignore
    from lib.registry.context_rank import _tokens  # type: ignore
    from lib.registry.hub_registry import HubRegistry  # type: ignore

MAX_QUESTIONS = 3


def interview_questions(
    registry: HubRegistry, recipes: Sequence[Recipe]
) -> List[Dict[str, Any]]:
    """The bounded interview (≤3 Qs) with answer domains from the live data.
    Same three questions the T3 console view scaffolds — here as fields."""
    questions = [
        {
            "q": "What are you building? (maps to a use-case recipe)",
            "answers": [{"id": r.id, "use_case": r.use_case} for r in
                        sorted(recipes, key=lambda r: r.id)],
        },
        {
            "q": "Which capability categories do you need?",
            "answers": sorted({rec.category for rec in registry.records()}),
        },
        {
            "q": "Enforcement posture? (enforce | advisory)",
            "answers": ["enforce", "advisory"],
        },
    ]
    assert len(questions) <= MAX_QUESTIONS  # the bound IS the contract
    return questions


def _score_recipe(prose_tokens: frozenset, recipe: Recipe) -> Dict[str, Any]:
    """Pure-integer overlap of prose tokens vs one recipe — reasons emitted."""
    score = 0
    why: List[str] = []
    id_toks = _tokens(recipe.id)
    case_toks = _tokens(recipe.use_case)
    why_toks = _tokens(recipe.why)
    for token in sorted(prose_tokens):
        if token in id_toks:
            score += 3
            why.append(f"prose '{token}' matches recipe id '{recipe.id}' (+3)")
        elif token in case_toks:
            score += 2
            why.append(f"prose '{token}' matches use-case '{recipe.use_case}' (+2)")
        elif token in why_toks:
            score += 1
            why.append(f"prose '{token}' matches recipe rationale (+1)")
    return {"id": recipe.id, "use_case": recipe.use_case, "score": score, "why": why}


def map_prose(
    prose: str,
    registry: HubRegistry,
    recipes: Sequence[Recipe],
) -> Dict[str, Any]:
    """Prose need → the SHOWN mapping + profile DRAFT. Logged fields only.

    Always returns ``applied: false`` — this module cannot write. The result
    is either:
      - ``status: draft``      — a best-recipe mapping + draft ids + the
        exact draft YAML + open_questions (conflicts to resolve, posture);
      - ``status: interview``  — prose matched nothing ⇒ the bounded ≤3-Q
        interview (never a fabricated mapping).
    """
    prose_tokens = frozenset(_tokens(prose or ""))
    scored = sorted(
        (_score_recipe(prose_tokens, r) for r in recipes),
        key=lambda e: (-e["score"], e["id"]),
    )
    matched = [e for e in scored if e["score"] > 0]
    if not matched:
        return {
            "status": "interview",
            "applied": False,
            "prose_tokens": sorted(prose_tokens),
            "mapping": [],
            "questions": interview_questions(registry, recipes),
            "note": "prose matched no recipe — answer the bounded interview "
                    "(≤3 Qs); no mapping is fabricated",
        }

    best = matched[0]
    recipe = next(r for r in recipes if r.id == best["id"])

    # Draft ids = the recipe stack, minus registry-excluded ids (fail-closed
    # here too — an excluded tool never even enters a DRAFT).
    draft_ids: List[str] = []
    excluded: List[str] = []
    for tid in recipe.stack:
        rec = registry.get(tid)
        if rec is not None and rec.activation == "excluded":
            excluded.append(tid)
        elif tid not in draft_ids:
            draft_ids.append(tid)

    # Surface intra-stack conflicts as OPEN QUESTIONS (the recipe's own HITL
    # point) — never silently pick a side of an OR-alternative.
    edges = registry.conflict_edges() | registry.edges_from_records()
    draft_set = set(draft_ids)
    open_questions: List[str] = []
    for edge in sorted(sorted(e) for e in edges if len(e) == 2 and e <= draft_set):
        open_questions.append(
            f"choose ONE of the mutually-exclusive pair: {edge[0]} vs {edge[1]}"
            f" (recipe HITL: {recipe.hitl})"
        )
    open_questions.append("enforcement posture: enforce | advisory")

    draft_yaml = yaml.safe_dump(
        {
            "schema_version": "hub-profile/1.0.0",
            "mode": "enforce",
            "enabled": sorted(draft_ids),
        },
        sort_keys=False,
        allow_unicode=True,
    )
    return {
        "status": "draft",
        "applied": False,          # ALWAYS — T5 acceptance: never auto-applies
        "prose_tokens": sorted(prose_tokens),
        "mapping": matched,        # the prose→recipe mapping, SHOWN
        "recipe": recipe.id,
        "draft_ids": sorted(draft_ids),
        "excluded_dropped": sorted(excluded),
        "open_questions": open_questions,
        "draft": draft_yaml,
        "apply_via": (
            "console.py select --ids "
            + ",".join(sorted(draft_ids))
            + " --write <profile.yaml> --confirm   # the ONE gated write path (T3)"
        ),
    }


def render_mapping(result: Dict[str, Any]) -> List[str]:
    """ASCII lines for the console's prose-intent flow (mapping shown)."""
    lines = [f" prose-intent — status: {result['status']}  (applied: false — always)"]
    if result["status"] == "interview":
        lines.append(" prose matched no recipe; bounded interview (<=3 Qs):")
        for i, q in enumerate(result["questions"], start=1):
            lines.append(f"  Q{i}. {q['q']}")
        return lines
    lines.append(f" matched recipe: {result['recipe']}")
    for entry in result["mapping"]:
        lines.append(f"  candidate: {entry['id']:<24} score: {entry['score']}")
        for reason in entry["why"]:
            lines.append(f"    why: {reason}")
    lines.append(f" draft ids: {', '.join(result['draft_ids'])}")
    if result["excluded_dropped"]:
        lines.append(f" dropped (activation=excluded): {', '.join(result['excluded_dropped'])}")
    for oq in result["open_questions"]:
        lines.append(f" OPEN: {oq}")
    lines.append(" apply via: " + result["apply_via"])
    return lines


# ----------------------------------------------------------------------- CLI

_USAGE = """\
MAOS Hub prose-intent (T5) — prose need -> bounded interview / profile DRAFT.

usage:
  prose_intent.py --prose "I want to refactor a legacy service" [--repo-root P] [--as-of DATE] [--json]

Output is a DRAFT + the shown prose->profile mapping (logged fields;
applied: false always). This tool CANNOT write a profile — apply the draft
via the one gated path: console.py select --ids ... --confirm (T3).
"""


def _main(argv: List[str]) -> int:
    here = Path(__file__).resolve()
    repo_root = here.parents[4]
    as_of = "1970-01-01"
    prose = ""
    as_json = False
    args = list(argv)
    if not args or "--help" in args or "-h" in args:
        print(_USAGE)
        return 0
    while args:
        a = args.pop(0)
        if a == "--prose" and args:
            prose = args.pop(0)
        elif a == "--repo-root" and args:
            repo_root = Path(args.pop(0)).resolve()
        elif a == "--as-of" and args:
            as_of = args.pop(0)
        elif a == "--json":
            as_json = True
        else:
            print(json.dumps({"verdict": "fail", "error": f"unknown argument: {a}"}))
            return 2
    if not (repo_root / "skills").is_dir():
        print(json.dumps({"verdict": "fail", "error": f"not a repo root: {repo_root}"}))
        return 1
    registry = HubRegistry.derive(repo_root, as_of=as_of)
    recipes = load_recipe_catalog(
        repo_root / "mcp-tools" / "maos-mcp-hub" / "lib" / "gateway" / "recipes.yaml"
    )
    result = map_prose(prose, registry, recipes)
    if as_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("\n".join(render_mapping(result)))
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(_main(sys.argv[1:]))
