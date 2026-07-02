"""Tests — ProseIntent (T5 / WAVE 5): prose need → interview → profile DRAFT.

tasks.md T5 acceptance, as logged fields (the DoD-gate):
  "the prose→profile mapping is shown; never auto-applies."
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

from lib.registry import HubRecord, HubRegistry, Recipe
from lib.registry.prose_intent import (
    MAX_QUESTIONS,
    interview_questions,
    map_prose,
    render_mapping,
)

_HERE = Path(__file__).resolve()
_HUB_DIR = _HERE.parents[1]
_REPO_ROOT = _HERE.parents[3]


# ------------------------------------------------------------------ fixtures


def _mk_record(rid: str, **kw) -> HubRecord:
    base = dict(
        id=rid, owner_repo="acme/tools", layer="L2", role="r", category="skill",
        harness_coverage=(), requires=(), conflicts_with=(), guardrails="g",
        impact="i", recipes=(), activation="opt-in", license_spdx="MIT",
        provenance="p", ttl=None, last_validated="2026-07-02",
        rollback="rb", security_status="vetted", derived_from="d",
    )
    base.update(kw)
    return HubRecord(**base)


@pytest.fixture()
def registry() -> HubRegistry:
    reg = HubRegistry()
    reg._add(_mk_record("guard", activation="always-on", category="substrate"))
    reg._add(_mk_record("spec-kit", conflicts_with=("openspec",)))
    reg._add(_mk_record("openspec", conflicts_with=("spec-kit",)))
    reg._add(_mk_record("cognee"))
    reg._add(_mk_record("mallory", activation="excluded", security_status="rejected"))
    return reg


@pytest.fixture()
def recipes() -> list:
    return [
        Recipe(id="new-idea-to-mvp", use_case="Nova ideia -> MVP",
               stack=("guard", "spec-kit", "openspec"),
               why="seed estrutura a ideia; deck para pitch",
               hitl="escolha spec-kit vs openspec + aprovação do plano"),
        Recipe(id="legacy-refactor", use_case="Refactor de legado",
               stack=("guard", "cognee", "mallory"),
               why="characterization tests protegem o comportamento",
               hitl="aprovação do plano de refactor"),
    ]


# ------------------------------------------------------ mapping is SHOWN


def test_prose_maps_to_recipe_with_shown_mapping(registry, recipes) -> None:
    """T5 acceptance: the prose→profile mapping is shown (logged fields)."""
    result = map_prose("quero refatorar um serviço legado", registry, recipes)
    assert result["status"] == "draft"
    assert result["recipe"] == "legacy-refactor"
    assert result["mapping"], "mapping must be shown"
    top = result["mapping"][0]
    assert top["id"] == "legacy-refactor" and top["score"] > 0
    assert any("prose 'legado'" in w or "prose 'refatorar'" in w or
               "prose 'refactor'" in w for w in top["why"])


def test_never_auto_applies(registry, recipes, tmp_path: Path) -> None:
    """T5 acceptance: never auto-applies — applied:false always, no write API."""
    import lib.registry.prose_intent as mod
    result = map_prose("mvp idea", registry, recipes)
    assert result["applied"] is False
    assert "apply_via" in result and "--confirm" in result["apply_via"]
    assert not hasattr(mod, "select") and not hasattr(mod, "write_profile")
    interview = map_prose("zzz qqq", registry, recipes)
    assert interview["applied"] is False


def test_mapping_is_deterministic(registry, recipes) -> None:
    a = json.dumps(map_prose("refactor legado", registry, recipes), sort_keys=True)
    b = json.dumps(map_prose("refactor legado", registry, recipes), sort_keys=True)
    assert a == b


def test_draft_is_valid_hub_profile_yaml(registry, recipes) -> None:
    result = map_prose("nova ideia mvp", registry, recipes)
    doc = yaml.safe_load(result["draft"])
    assert doc["schema_version"].startswith("hub-profile/1.")
    assert doc["mode"] == "enforce"
    assert sorted(doc["enabled"]) == result["draft_ids"]


# --------------------------------------------- fail-closed + open questions


def test_excluded_ids_never_enter_a_draft(registry, recipes) -> None:
    """Fail-closed at DRAFT time too: mallory is in the recipe stack but
    activation=excluded — dropped and surfaced."""
    result = map_prose("refactor legado", registry, recipes)
    assert "mallory" not in result["draft_ids"]
    assert result["excluded_dropped"] == ["mallory"]


def test_intra_stack_conflict_is_an_open_question_not_a_silent_pick(
    registry, recipes
) -> None:
    """OR-alternatives (spec-kit vs openspec) are the recipe's own HITL point
    — surfaced as an open question; BOTH stay in the draft for the human."""
    result = map_prose("nova ideia mvp", registry, recipes)
    assert result["recipe"] == "new-idea-to-mvp"
    conflicts = [q for q in result["open_questions"] if "openspec vs spec-kit" in q
                 or "spec-kit vs openspec" in q]
    assert len(conflicts) == 1
    assert "escolha spec-kit vs openspec" in conflicts[0]  # recipe hitl echoed


def test_posture_question_always_open(registry, recipes) -> None:
    result = map_prose("refactor legado", registry, recipes)
    assert any("enforce | advisory" in q for q in result["open_questions"])


# ------------------------------------------------------ bounded interview


def test_unmatched_prose_returns_bounded_interview(registry, recipes) -> None:
    """No match ⇒ the ≤3-Q interview — never a fabricated mapping."""
    result = map_prose("xyzzy plugh", registry, recipes)
    assert result["status"] == "interview"
    assert result["mapping"] == []
    assert len(result["questions"]) <= MAX_QUESTIONS
    assert "no mapping is fabricated" in result["note"]


def test_interview_answer_domains_come_from_live_data(registry, recipes) -> None:
    qs = interview_questions(registry, recipes)
    assert len(qs) <= MAX_QUESTIONS
    assert {a["id"] for a in qs[0]["answers"]} == {"new-idea-to-mvp", "legacy-refactor"}
    assert "substrate" in qs[1]["answers"]
    assert qs[2]["answers"] == ["enforce", "advisory"]


def test_empty_prose_goes_to_interview(registry, recipes) -> None:
    assert map_prose("", registry, recipes)["status"] == "interview"


# ---------------------------------------------------------------- rendering


def test_render_mapping_shows_reasons_and_open_questions(registry, recipes) -> None:
    lines = render_mapping(map_prose("nova ideia mvp", registry, recipes))
    text = "\n".join(lines)
    assert "applied: false" in text
    assert "why: prose" in text
    assert "OPEN:" in text
    assert "apply via: console.py select" in text


# ------------------------------------------------------------------- CLI


def test_cli_prose_maps_and_never_writes(tmp_path: Path) -> None:
    """CLI smoke over the LIVE repo: real recipe matched; applied:false;
    deterministic (double-run diff)."""
    script = _HUB_DIR / "lib" / "registry" / "prose_intent.py"
    argv = [sys.executable, str(script), "--prose",
            "refactor a legacy service safely", "--json",
            "--repo-root", str(_REPO_ROOT)]
    run1 = subprocess.run(argv, capture_output=True, text=True, check=True)
    run2 = subprocess.run(argv, capture_output=True, text=True, check=True)
    payload = json.loads(run1.stdout)
    assert payload["applied"] is False
    assert payload["status"] in ("draft", "interview")
    assert run1.stdout == run2.stdout


def test_cli_unknown_argument_is_an_error() -> None:
    script = _HUB_DIR / "lib" / "registry" / "prose_intent.py"
    out = subprocess.run([sys.executable, str(script), "--porse", "typo"],
                         capture_output=True, text=True)
    assert out.returncode == 2
    assert "unknown argument" in out.stdout
