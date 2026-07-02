"""Tests — HubRegistry (T1 / WAVE 5): the spec's Scenarios as logged fields.

Spec: openspec/specs/maos-hub-registry/spec.md — each test names the
Requirement/Scenario it reproduces (the DoD-gate: no prose-judged acceptance).
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from lib.registry import ACTIVATION_TIERS, HubRecord, HubRegistry

_HERE = Path(__file__).resolve()
_HUB_DIR = _HERE.parents[1]           # mcp-tools/maos-mcp-hub
_REPO_ROOT = _HERE.parents[3]         # repo root

AS_OF = "2026-07-02"


@pytest.fixture(scope="module")
def registry() -> HubRegistry:
    assert (_REPO_ROOT / "skills").is_dir(), "repo-root resolution broke (Qodo lesson)"
    return HubRegistry.derive(_REPO_ROOT, as_of=AS_OF)


# --- Requirement: Records are derived, not hand-maintained -----------------

def test_golden_derivation_over_real_repo(registry: HubRegistry) -> None:
    cats = {r.category for r in registry.records()}
    assert {"skill", "agent", "third-party"} <= cats
    skills = [r for r in registry.records() if r.category == "skill"]
    third = [r for r in registry.records() if r.category == "third-party"]
    assert len(skills) >= 40          # the repo ships 60+ skills
    assert len(third) == 32           # 26 INCLUDED + graphiti + 5 EXCLUDED (WT10 fixture)


def test_every_record_is_derived_with_provenance(registry: HubRegistry) -> None:
    for rec in registry.records():
        assert rec.derived_from, rec.id
        assert rec.provenance, rec.id


def test_scenario_a_new_skill_ships(tmp_path: Path) -> None:
    """Scenario: a new skill ships -> its record is (re)generated."""
    skills = tmp_path / "skills" / "brand-new-skill"
    skills.mkdir(parents=True)
    (skills / "SKILL.md").write_text(
        "---\nname: brand-new-skill\ndescription: synthetic\nversion: 0.0.1\n---\n# X\n",
        encoding="utf-8",
    )
    (tmp_path / "agents").mkdir()
    reg = HubRegistry.derive(tmp_path, as_of=AS_OF)
    rec = reg.get("brand-new-skill")
    assert rec is not None
    assert rec.category == "skill"
    assert rec.last_validated == AS_OF
    assert rec.derived_from == "skills/brand-new-skill/SKILL.md"


# --- Requirement: schema completeness + vocabulary --------------------------

def test_all_required_spec_fields_present(registry: HubRegistry) -> None:
    report = registry.report()
    assert report["invariants"]["all_required_fields_present"] is True


def test_activation_vocabulary_valid(registry: HubRegistry) -> None:
    for rec in registry.records():
        assert rec.activation in ACTIVATION_TIERS, (rec.id, rec.activation)


# --- Requirement: Activation gating -----------------------------------------

def test_excluded_verdicts_are_excluded(registry: HubRegistry) -> None:
    """The supply-chain vetoes (GSD rug-pull, MemPalace) can never route."""
    for rid in ("gsd-build-get-shit-done", "mempalace"):
        rec = registry.get(rid)
        assert rec is not None
        assert rec.activation == "excluded"
        assert rec.security_status == "supply-chain-veto"


def test_no_third_party_is_always_on_at_derivation(registry: HubRegistry) -> None:
    report = registry.report()
    assert report["invariants"]["third_party_always_on"] == []


def test_conductor_class_never_default_on(registry: HubRegistry) -> None:
    """RULE-011: a conductor-class third-party is capped at opt-in/excluded."""
    for rid in ("base", "superpowers", "gstack", "ECC", "ruflo", "bmad-method"):
        rec = registry.get(rid)
        assert rec is not None, rid
        assert rec.activation in ("opt-in", "excluded"), (rid, rec.activation)
        assert rec.activation_reason, rid


def test_scenario_third_party_always_on_refused_license_none(registry: HubRegistry) -> None:
    """Scenario: license_spdx=NONE -> always-on refused, reason recorded."""
    decision = registry.request_activation("karpathy-claude-md", "always-on")
    assert decision["granted"] != "always-on"
    assert "license" in decision["reason"]


def test_scenario_third_party_always_on_refused_conflict_edge(registry: HubRegistry) -> None:
    """Scenario: a conflicts_with edge -> always-on refused (mem0 x letta/cognee)."""
    rec = registry.get("mem0")
    assert rec is not None and rec.conflicts_with  # Apache-2.0, but conflicted
    decision = registry.request_activation("mem0", "always-on")
    assert decision["granted"] != "always-on"
    assert "conflict" in decision["reason"]


def test_third_party_clean_always_on_grant_path(registry: HubRegistry) -> None:
    """A license-clean, conflict-free, vetted third-party CAN pass the gate."""
    clean = [
        r for r in registry.records()
        if r.category == "third-party" and r.license_spdx != "NONE"
        and not r.conflicts_with and r.security_status == "vetted"
    ]
    assert clean, "fixture should contain at least one gate-clean third-party"
    decision = registry.request_activation(clean[0].id, "always-on")
    assert decision["granted"] == "always-on"


# --- Requirement: Incompatibility is queryable -------------------------------

def test_conflicts_roundtrip_phase2(registry: HubRegistry) -> None:
    """The conflicts_with graph round-trips conflicts.yaml exactly."""
    assert registry.conflict_edges(), "conflicts.yaml must load"
    assert registry.conflict_edges() == registry.edges_from_records()
    report = registry.report()
    assert report["invariants"]["conflicts_roundtrip"] is True


def test_every_conflict_endpoint_resolves_to_a_record(registry: HubRegistry) -> None:
    """Scenario 'two conductors selected' presupposes both endpoints exist."""
    ids = {r.id for r in registry.records()}
    for edge in registry.conflict_edges():
        for endpoint in edge:
            assert endpoint in ids, f"conflict endpoint without record: {endpoint}"


# --- Requirement: Real license + provenance ----------------------------------

def test_license_classified_never_assumed(registry: HubRegistry) -> None:
    for rec in registry.records():
        assert rec.license_spdx, rec.id          # never empty
    assert registry.get("karpathy-claude-md").license_spdx == "NONE"   # not "MIT-assumed"
    assert registry.get("mem0").license_spdx == "Apache-2.0"


# --- Requirement: Freshness + rollback ---------------------------------------

def test_scenario_upstream_goes_stale(registry: HubRegistry) -> None:
    """Scenario: now - last_validated > ttl -> eject-candidate."""
    fresh = registry.eject_candidates("2026-08-01")   # before revisit 2026-09-27
    stale = registry.eject_candidates("2026-12-01")   # after revisit
    third = [r.id for r in registry.records() if r.category == "third-party"]
    assert fresh == []
    assert set(stale) == set(third)                   # every fixture record shares the TTL
    report = registry.report(today="2026-12-01")
    assert set(report["invariants"]["eject_candidates"]) == set(third)


def test_every_record_has_rollback(registry: HubRegistry) -> None:
    for rec in registry.records():
        assert rec.rollback, rec.id


# --- Requirement: recipes (Phase-2 promotion) --------------------------------

def test_recipes_derived_from_promotion(registry: HubRegistry) -> None:
    rec = registry.get("mem0")
    assert rec is not None
    assert "new-idea-to-mvp" in rec.recipes
    assert "production-deploy" in rec.recipes


def test_recipe_stack_ids_resolve(registry: HubRegistry) -> None:
    """Every tool id named by a recipe stack resolves to a registry record."""
    import yaml as _yaml
    data = _yaml.safe_load(
        (_HUB_DIR / "lib" / "gateway" / "recipes.yaml").read_text(encoding="utf-8")
    )
    ids = {r.id for r in registry.records()}
    for recipe in data["recipes"]:
        for item in recipe["stack"]:
            for tool in (item if isinstance(item, list) else [item]):
                assert tool in ids, f"recipe {recipe['id']} names unknown tool: {tool}"


# --- Outputs ------------------------------------------------------------------

def test_yaml_projection_is_stamped_auto_generated(registry: HubRegistry) -> None:
    out = registry.to_yaml()
    assert out.startswith("# AUTO-GENERATED")
    assert "records:" in out


def test_cli_contract() -> None:
    proc = subprocess.run(
        [sys.executable, "-m", "lib.registry.hub_registry",
         "--repo-root", str(_REPO_ROOT), "--as-of", AS_OF],
        cwd=_HUB_DIR, capture_output=True, text=True, timeout=120,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["verdict"] == "pass"


# --- PR #209 bot-finding regressions (fix/T1-registry-bot-findings) ----------

def _mk_record(rid: str, category: str, **kw) -> HubRecord:
    base = dict(
        id=rid, owner_repo="x/y", layer="L2", role="r", category=category,
        harness_coverage=(), requires=(), conflicts_with=(), guardrails="",
        impact="", recipes=(), activation="opt-in", license_spdx="MIT",
        provenance="p", ttl=None, last_validated="2026-07-02",
        rollback="rb", security_status="vetted", derived_from="d",
    )
    base.update(kw)
    return HubRecord(**base)


def test_conductors_txt_manager_pipe_path_format(tmp_path: Path) -> None:
    """F2 (Copilot/Qodo High): conductors.txt lines are `<manager>|<sig-path>` —
    only the manager id may enter the gate set."""
    from lib.registry.hub_registry import _load_conductors
    f = tmp_path / "conductors.txt"
    f.write_text("# comment\nbmad-method|.bmad-core\nECC | .ecc\n\ngstack|.gstack\n",
                 encoding="utf-8")
    assert _load_conductors(f) == {"bmad-method", "ECC", "gstack"}


def test_conductor_gate_actually_fires(registry: HubRegistry) -> None:
    """F2: at least one conductor is capped BY THE CONDUCTOR GATE itself
    (not merely masked by a license/conflict gate)."""
    reasons = [
        registry.get(rid).activation_reason
        for rid in ("base", "superpowers", "gstack", "ECC", "ruflo", "bmad-method")
        if registry.get(rid) is not None
    ]
    assert any("conductor" in r for r in reasons), reasons


def test_request_activation_never_upgrades_excluded(registry: HubRegistry) -> None:
    """F3 (Qodo Blocker): excluded is immutable via the request API."""
    for requested in ("opt-in", "default-on-for-context", "always-on"):
        decision = registry.request_activation("mempalace", requested)
        assert decision["granted"] == "excluded", decision
        assert "refused" in decision["reason"]


def test_request_activation_refuses_upgrade_beyond_derived(registry: HubRegistry) -> None:
    """F3: a derived opt-in third-party cannot be bumped to default-on."""
    rec = next(r for r in registry.records()
               if r.category == "third-party" and r.activation == "opt-in")
    decision = registry.request_activation(rec.id, "default-on-for-context")
    assert decision["granted"] == rec.activation
    assert "refused: upgrade" in decision["reason"]
    # downgrade remains allowed
    down = registry.request_activation(rec.id, "opt-in")
    assert down["granted"] == "opt-in"


def test_id_collision_first_party_wins_and_verdict_fails_cross_category() -> None:
    """F4 (Qodo High): duplicate id never silently overwrites; cross-category
    collision fails the report verdict."""
    reg = HubRegistry()
    reg._add(_mk_record("dup", "skill"))
    reg._add(_mk_record("dup", "third-party", activation="excluded"))
    assert reg.get("dup").category == "skill"           # first-derived wins
    report = reg.report()
    assert report["invariants"]["id_collisions"] == [
        {"id": "dup", "kept": "skill", "dropped": "third-party"}
    ]
    assert report["verdict"] == "fail"


def test_required_fields_invariant_checks_content_not_keys() -> None:
    """F5 (Qodo Medium): empty critical fields must fail the invariant."""
    reg = HubRegistry()
    reg._add(_mk_record("hollow", "skill", provenance=""))
    assert reg.report()["invariants"]["all_required_fields_present"] is False


def test_recipes_loader_skips_falsy_ids(tmp_path: Path) -> None:
    """F6 (Qodo Medium): null/empty recipe or tool ids never enter the map."""
    from lib.registry.hub_registry import _load_recipes
    f = tmp_path / "recipes.yaml"
    f.write_text(
        "recipes:\n"
        "  - id:\n"
        "    stack: [ghost]\n"
        "  - id: ok\n"
        "    stack: [null, '', mem0]\n",
        encoding="utf-8",
    )
    mapping = _load_recipes(f)
    assert "ghost" not in mapping
    assert mapping == {"mem0": ["ok"]}
