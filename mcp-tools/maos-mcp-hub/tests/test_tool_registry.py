"""
Tests for the auto-generated ToolRegistry (WT8 / S1, backlog P2-d).

The acceptance IS the spec scenario (openspec/specs/maos-hub-registry/spec.md
→ "Records are derived, not hand-maintained"), asserted as LOGGED FIELDS +
golden derivation over the hub's REAL gateways — never prose:

    WHEN records are needed
    THEN they are DERIVED from live MetaToolRouter SchemaRegistry instances
    (provenance field names the real handler) and the WAVE-1 seams
    (IsoGate / CtsScorer) consume them loss-free.
"""

import pytest

from lib.gateway.cts import CtsScorer, CtsTurn, RiskClass
from lib.gateway.iso import IsoGate
from lib.gateway.router import MetaToolRouter
from lib.gateway.tool_registry import (
    REGISTRY_SCHEMA_VERSION,
    ToolRegistry,
    risk_signals_for_operation,
)


# --------------------------------------------------------------------------- #
# synthetic router (always runs — no gateway deps)
# --------------------------------------------------------------------------- #

async def get_widget(widget_id: str, verbose: bool = False):
    """Fetch one widget by id."""
    return {"widget_id": widget_id}


async def create_widget(name: str):
    """Create a widget."""
    return {"name": name}


async def delete_widget(widget_id: str):
    """Delete a widget permanently."""
    return {"deleted": widget_id}


def _demo_router() -> MetaToolRouter:
    router = MetaToolRouter("demo_widgets", governance=["worktree-first"])
    router.register("widget", "get", get_widget)
    router.register("widget", "create", create_widget)
    router.register("widget", "delete", delete_widget)
    return router


@pytest.fixture()
def registry() -> ToolRegistry:
    return ToolRegistry.from_routers([_demo_router()])


# --------------------------------------------------------------------------- #
# derivation: the derived-not-hand-maintained contract
# --------------------------------------------------------------------------- #

def test_records_are_derived_with_real_handler_provenance(registry):
    """Provenance names the REAL handler (unwrapped past @with_feedback)."""
    record = registry.get("demo_widgets.widget.get")
    assert record is not None
    assert record.derived_from.endswith(".get_widget")
    assert record.summary == "Fetch one widget by id."
    assert record.required_params == ("widget_id",)
    assert dict(record.optional_params) == {"verbose": "False"}
    assert record.governance == ("worktree-first",)


def test_report_invariants_are_logged_fields(registry):
    report = registry.report()
    assert report["schema_version"] == REGISTRY_SCHEMA_VERSION
    assert report["total_tools"] == 3
    assert report["per_gateway"] == {"demo_widgets": 3}
    inv = report["invariants"]
    assert inv["all_records_derived"] is True
    assert inv["ids_namespaced_by_gateway"] is True
    assert inv["iso_inventory_complete"] is True


def test_verb_risk_mapping_is_deterministic(registry):
    """delete→HIGH · create→MEDIUM · get→LOW (documented verb map)."""
    assert registry.get("demo_widgets.widget.delete").risk is RiskClass.HIGH
    assert registry.get("demo_widgets.widget.create").risk is RiskClass.MEDIUM
    assert registry.get("demo_widgets.widget.get").risk is RiskClass.LOW
    # the map is pure — same operation, same signals
    assert risk_signals_for_operation("delete_x") == risk_signals_for_operation(
        "delete_y"
    )


def test_multi_router_merge_stays_namespaced():
    other = MetaToolRouter("demo_other")
    other.register("thing", "list", get_widget)
    reg = ToolRegistry.from_routers([_demo_router(), other])
    assert len(reg) == 4
    assert reg.gateways() == ["demo_other", "demo_widgets"]
    assert reg.report()["invariants"]["ids_namespaced_by_gateway"] is True


def test_non_router_object_derives_nothing_without_crashing():
    """PR #200 review (amazon-q): an object without a `registry` surface
    yields zero records — never AttributeError."""

    class NotARouter:
        tool_name = "bogus"

    reg = ToolRegistry()
    assert reg.derive_router(NotARouter()) == []
    assert len(reg) == 0


def test_circular_wrapped_chain_does_not_infinite_loop():
    """PR #200 review (amazon-q): a pathological circular __wrapped__ chain
    terminates via the visited-id guard."""
    from lib.gateway.tool_registry import _provenance

    def a():
        """A."""

    def b():
        """B."""

    a.__wrapped__ = b
    b.__wrapped__ = a  # cycle
    result = _provenance(a, "gw", "res", "op")
    assert result  # terminated and produced a name


# --------------------------------------------------------------------------- #
# the keystone seams: registry → IsoGate (WT3) → CtsScorer (WT4)
# --------------------------------------------------------------------------- #

def test_iso_seam_end_to_end(registry):
    """to_iso_inventory() IS IsoGate.from_inventory's input — loss-free."""
    inventory = registry.to_iso_inventory()
    gate, entries = IsoGate.from_inventory(inventory, k=2)
    assert len(entries) == len(registry)
    selection = gate.select(
        ranked_candidates=[r.tool_id for r in registry.records()]
    )
    report = selection.to_report()
    assert report["invariants"]["promoted_lte_k"] is True
    assert report["invariants"]["summaries_within_limit"] is True


def test_cts_seam_end_to_end(registry):
    """to_cts_candidates() ranks under CtsScorer with derived risk."""
    turn = CtsTurn(max_risk=RiskClass.MEDIUM)
    ranking = CtsScorer().rank(registry.to_cts_candidates(expert_fit=0.8), turn)
    ranked = ranking.ranked_ids()
    # HIGH-risk delete is filtered above the turn ceiling — never silently:
    assert "demo_widgets.widget.delete" not in ranked
    assert "demo_widgets.widget.get" in ranked
    assert "demo_widgets.widget.create" in ranked


# --------------------------------------------------------------------------- #
# YAML projection: generated artifact, deterministic, self-declaring
# --------------------------------------------------------------------------- #

def test_yaml_projection_is_generated_and_deterministic(registry):
    yaml_text = registry.to_yaml()
    assert yaml_text.startswith("# AUTO-GENERATED")
    assert "DO NOT EDIT" in yaml_text
    assert '"demo_widgets.widget.delete"' in yaml_text
    assert registry.to_yaml() == yaml_text  # deterministic


# --------------------------------------------------------------------------- #
# GOLDEN: derivation over the hub's REAL gateways (skip-graceful when the
# gateway deps / Python version aren't available in this environment)
# --------------------------------------------------------------------------- #

def _real_routers():
    routers = []
    for gw in ("confluence", "compass", "common"):
        try:
            mod = __import__(f"gateways.{gw}.actions", fromlist=["build_router"])
            routers.append(mod.build_router())
        except Exception:  # missing deps / py-version syntax — env-specific
            pass
    return routers


def test_golden_derivation_over_real_gateways():
    routers = _real_routers()
    if not routers:
        pytest.skip("no real gateway importable in this environment")
    reg = ToolRegistry.from_routers(routers)
    # loss-free: registry size == the routers' own action counts
    assert len(reg) == sum(r.action_count for r in routers)
    report = reg.report()
    assert report["invariants"]["all_records_derived"] is True
    assert report["invariants"]["ids_namespaced_by_gateway"] is True
    assert report["invariants"]["iso_inventory_complete"] is True
    # the ISO seam holds over the real surface too
    gate, entries = IsoGate.from_inventory(reg.to_iso_inventory(), k=5)
    assert len(entries) == len(reg)
