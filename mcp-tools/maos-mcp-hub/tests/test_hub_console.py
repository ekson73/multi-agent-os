"""Tests — HubConsole (T3 / WAVE 5): console setup/config modes.

tasks.md T3 acceptance, as logged fields / golden fixtures (the DoD-gate):
  "each view renders from the registry; selection is conflict-checked +
   HITL-confirmed before it writes the profile."
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from lib.gateway.profile import load_profile
from lib.registry import VIEWS, HubConsole, HubRecord, HubRegistry, Recipe, load_recipe_catalog

_HERE = Path(__file__).resolve()
_HUB_DIR = _HERE.parents[1]           # mcp-tools/maos-mcp-hub
_REPO_ROOT = _HERE.parents[3]         # repo root


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
    """A small synthetic registry covering every tier + one conflict edge."""
    reg = HubRegistry()
    reg._add(_mk_record("guard", activation="always-on", category="substrate",
                        owner_repo="ekson73/multi-agent-os"))
    reg._add(_mk_record("memory", activation="default-on-for-context", category="substrate",
                        owner_repo="ekson73/multi-agent-os"))
    reg._add(_mk_record("alpha", activation="opt-in", conflicts_with=("beta",)))
    reg._add(_mk_record("beta", activation="opt-in", conflicts_with=("alpha",),
                        category="third-party"))
    reg._add(_mk_record("mallory", activation="excluded", category="third-party",
                        security_status="rejected"))
    reg._add(_mk_record("vendor-default", activation="default-on-for-context",
                        category="third-party"))
    return reg


@pytest.fixture()
def recipes() -> list:
    return [
        Recipe(id="quick-start", use_case="Quick start", stack=("guard", "memory", "alpha"),
               why="minimal stack", hitl="approve the plan"),
        Recipe(id="full-stack", use_case="Full stack", stack=("guard", "beta"),
               why="broader", hitl="pick alpha vs beta"),
    ]


@pytest.fixture()
def console(registry: HubRegistry, recipes: list) -> HubConsole:
    return HubConsole(registry, recipes)


# --------------------------------------------------- views render from registry


def test_every_view_renders_from_registry(console: HubConsole) -> None:
    """T3 acceptance: each of the 6 views renders (non-empty, header present)."""
    for view in VIEWS:
        out = console.render(view)
        assert f"view: {view}" in out
        assert "registry: 6 records" in out


def test_views_are_byte_stable(console: HubConsole) -> None:
    """DoD determinism: same input -> byte-identical rendering."""
    for view in VIEWS:
        assert console.render(view) == console.render(view)


def test_unknown_view_is_refused(console: HubConsole) -> None:
    with pytest.raises(ValueError):
        console.render("dashboard")


def test_category_view_groups_all_records(console: HubConsole) -> None:
    out = console.render("category")
    for cat in ("skill", "substrate", "third-party"):
        assert f"category: {cat}" in out
    for rid in ("guard", "memory", "alpha", "beta", "mallory", "vendor-default"):
        assert rid in out


def test_preset_view_annotates_tiers_from_registry(console: HubConsole) -> None:
    """Preset stacks show the DERIVED tier per tool (renders FROM the registry)."""
    out = console.render("preset")
    assert "preset: quick-start" in out
    assert "guard" in out and "always-on" in out
    assert "HITL: approve the plan" in out


def test_use_case_view_lists_recipes(console: HubConsole) -> None:
    out = console.render("use-case")
    assert "use-case: Quick start  (recipe: quick-start)" in out
    assert "why : minimal stack" in out


def test_context_aware_view_is_tier_ordered_and_names_t4(console: HubConsole) -> None:
    out = console.render("context-aware")
    assert "lands in T4" in out
    # deterministic ordering: always-on first, excluded last
    assert out.index("guard") < out.index("alpha") < out.index("mallory")


def test_prose_intent_view_scaffolds_3_questions_from_registry(console: HubConsole) -> None:
    out = console.render("prose-intent")
    questions = [ln for ln in out.splitlines() if ln.lstrip().startswith("Q")]
    assert len(questions) == 3  # the interview is BOUNDED (<=3 Qs)
    assert "quick-start" in out and "third-party" in out
    assert "NEVER auto-applies" in out


def test_safe_mode_view_hides_third_party_opt_in_and_excluded(console: HubConsole) -> None:
    out = console.render("safe-mode")
    body = out.split("owner_repo", 1)[1]  # only the record table
    assert "guard" in body and "memory" in body
    for hidden in ("alpha", "beta", "mallory", "vendor-default"):
        assert hidden not in body


def test_golden_safe_mode_fixture(console: HubConsole) -> None:
    """Golden fixture (DoD-gate): the safe-mode record lines, byte-exact."""
    out = console.render("safe-mode")
    lines = [ln for ln in out.splitlines() if ln.startswith("  guard") or ln.startswith("  memory")]
    assert lines == [
        "  guard                        always-on                MIT          ekson73/multi-agent-os",
        "  memory                       default-on-for-context   MIT          ekson73/multi-agent-os",
    ]


def test_html_artifact_wraps_ascii(console: HubConsole) -> None:
    html = console.render_html("category")
    assert html.startswith("<!DOCTYPE html>")
    assert "view: category" in html


# --------------------------------------- selection: conflict-check + HITL gate


def test_selection_conflict_pair_is_refused(console: HubConsole) -> None:
    """T3 acceptance: selection is conflict-checked (logged field, not prose)."""
    result = console.select(["alpha", "beta"], confirm=True, write_path=None)
    assert result["verdict"] == "refused"
    assert result["conflicts"] == [["alpha", "beta"]]
    assert result["written"] is False
    assert result["reason"] == "selection_refused"


def test_selection_excluded_id_is_refused_fail_closed(console: HubConsole) -> None:
    result = console.select(["guard", "mallory"], confirm=True)
    assert result["verdict"] == "refused"
    assert result["excluded"] == ["mallory"]
    assert result["written"] is False


def test_selection_without_confirm_never_writes(console: HubConsole, tmp_path: Path) -> None:
    """T3 acceptance: HITL-confirmed BEFORE it writes the profile."""
    target = tmp_path / "profile.yaml"
    result = console.select(["guard", "memory"], write_path=target, confirm=False)
    assert result["verdict"] == "ok"
    assert result["written"] is False
    assert result["reason"] == "confirmation_required"
    assert not target.exists()
    assert "enabled:" in result["draft"]  # the draft is SHOWN, not applied


def test_confirmed_selection_writes_t2_loadable_profile(
    console: HubConsole, tmp_path: Path
) -> None:
    """Integration with T2: the written profile round-trips through
    lib.gateway.profile.load_profile (schema hub-profile/1.x)."""
    target = tmp_path / "profile.yaml"
    result = console.select(["guard", "memory"], write_path=target, confirm=True)
    assert result["written"] is True and result["path"] == str(target)
    prof = load_profile(target)
    assert prof is not None
    assert prof.mode == "enforce"
    assert prof.enabled == ("guard", "memory")


def test_confirmed_selection_without_path_does_not_write(console: HubConsole) -> None:
    result = console.select(["guard"], confirm=True, write_path=None)
    assert result["written"] is False and result["reason"] == "no_write_path"


def test_unknown_ids_are_surfaced_but_allowed(console: HubConsole, tmp_path: Path) -> None:
    """Gateway operation tokens (`get`, `create`) are not registry records —
    they must pass selection but be SURFACED for the human (logged field)."""
    result = console.select(["guard", "get"], write_path=tmp_path / "p.yaml", confirm=True)
    assert result["verdict"] == "ok"
    assert result["unknown"] == ["get"]
    assert result["written"] is True


def test_selection_dedupes_and_sorts_ids(console: HubConsole) -> None:
    result = console.check_selection(["memory", "guard", "memory", " guard "])
    assert result["ids"] == ["guard", "memory"]


# -------------------------------------------------------------- catalog + CLI


def test_recipe_catalog_loads_live_recipes_yaml() -> None:
    catalog = load_recipe_catalog(_HUB_DIR / "lib" / "gateway" / "recipes.yaml")
    ids = [r.id for r in catalog]
    assert "new-idea-to-mvp" in ids and len(ids) == 6
    assert ids == sorted(ids)  # deterministic ordering


def test_cli_view_renders_and_select_gates(tmp_path: Path) -> None:
    """CLI smoke over the LIVE repo: view renders; unconfirmed select refuses."""
    script = _HUB_DIR / "lib" / "registry" / "console.py"
    view = subprocess.run(
        [sys.executable, str(script), "view", "safe-mode", "--repo-root", str(_REPO_ROOT)],
        capture_output=True, text=True, check=True,
    )
    assert "view: safe-mode" in view.stdout
    sel = subprocess.run(
        [sys.executable, str(script), "select", "--ids", "get,create",
         "--write", str(tmp_path / "p.yaml"), "--repo-root", str(_REPO_ROOT)],
        capture_output=True, text=True,
    )
    payload = json.loads(sel.stdout)
    assert payload["written"] is False
    assert payload["reason"] == "confirmation_required"
    assert not (tmp_path / "p.yaml").exists()


def test_cli_help_flag(tmp_path: Path) -> None:
    script = _HUB_DIR / "lib" / "registry" / "console.py"
    out = subprocess.run([sys.executable, str(script), "--help"],
                         capture_output=True, text=True, check=True)
    assert "views: preset | category | use-case" in out.stdout
