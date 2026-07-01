"""
ToolRegistry — the AUTO-GENERATED tool-registry SSOT (WT8 / S1, backlog P2-d).

The keystone that lifts the tool contract out of the gateways' divergent
wiring: every record is DERIVED from a live ``MetaToolRouter`` (its
``SchemaRegistry`` schemas + registered handlers + governance tags) — NEVER
hand-maintained YAML, which drifts (handoff WAVE-2 mandate: *"registry
AUTO-GERADO (derivado por decorator do SchemaRegistry, NÃO YAML
hand-maintained que dá drift)"*).

Spec anchors:
  - ``openspec/specs/maos-hub-registry/spec.md`` → "Records are derived,
    not hand-maintained" (mirrors ``SchemaRegistry`` auto-gen).
  - ``openspec/specs/maos-hub/spec.md`` §Deferred → "tool-registry YAML SSOT
    via auto-generation (WT8)".

Provenance IS the acceptance (the DoD-gate): every ``ToolRecord`` carries
``derived_from`` = the handler's module-qualified name, so "derived, not
hand-maintained" is a checkable field, not prose. ``ToolRegistry.report()``
exposes the invariants as logged fields.

Seams (the WAVE-1 contract this registry feeds):
  - ``to_iso_inventory()``  → the exact ``{id, summary, schema}`` items
    ``IsoGate.from_inventory`` consumes (WT3).
  - ``to_cts_candidates()`` → ``CtsCandidate`` rows with the derived
    ``RiskSignals`` (WT4) — risk comes from a DETERMINISTIC, documented
    verb→signals map (below), never a vibe.
  - ``to_yaml()``           → the generated YAML *projection* (a build
    artifact stamped AUTO-GENERATED; editing it is the anti-pattern).

Deterministic verb → risk mapping (falsifiable, documented):
  - DESTRUCTIVE_VERBS (delete/remove/purge/drop/decline)
      → RiskSignals(destructive=True, remote_write=True)  → HIGH
  - WRITE_VERBS (create/update/edit/add/set/transition/trigger/stop/merge/
    approve/post/upload/move/publish/assign/link/comment)
      → RiskSignals(remote_write=True)                    → MEDIUM
  - everything else (get/list/search/check/…) → RiskSignals() → LOW
The verb is the first ``_``-separated token of the operation name.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Tuple

from .cts import CtsCandidate, RiskClass, RiskSignals, risk_class
from .iso import iso_tokens

REGISTRY_SCHEMA_VERSION = "tool-registry/1.0.0"

DESTRUCTIVE_VERBS = frozenset({"delete", "remove", "purge", "drop", "decline"})
WRITE_VERBS = frozenset(
    {
        "create", "update", "edit", "add", "set", "transition", "trigger",
        "stop", "merge", "approve", "post", "upload", "move", "publish",
        "assign", "link", "comment", "request",
    }
)


def risk_signals_for_operation(operation: str) -> RiskSignals:
    """The deterministic verb→RiskSignals map (module docstring contract)."""
    verb = (operation or "").split("_", 1)[0].lower()
    if verb in DESTRUCTIVE_VERBS:
        return RiskSignals(destructive=True, remote_write=True)
    if verb in WRITE_VERBS:
        return RiskSignals(remote_write=True)
    return RiskSignals()


@dataclass(frozen=True)
class ToolRecord:
    """One derived tool record — the registry's unit of truth."""

    tool_id: str            # "<gateway>.<resource>.<operation>"
    gateway: str            # MetaToolRouter.tool_name
    resource: str
    operation: str
    summary: str            # ActionSchema.description (docstring-derived)
    summary_tokens: int     # iso_tokens(summary) — the WT3 currency
    required_params: Tuple[str, ...] = ()
    optional_params: Tuple[Tuple[str, str], ...] = ()
    governance: Tuple[str, ...] = ()
    risk: RiskClass = RiskClass.LOW
    derived_from: str = ""  # provenance: handler module.qualname (NEVER empty
    #                         for a derived record — the DoD-gate field)

    def schema_dict(self) -> Dict[str, Any]:
        """The {required, optional} schema shape ISO/CTS consume."""
        return {
            "required": list(self.required_params),
            "optional": dict(self.optional_params),
        }

    def to_dict(self) -> Dict[str, Any]:
        return {
            "tool_id": self.tool_id,
            "gateway": self.gateway,
            "resource": self.resource,
            "operation": self.operation,
            "summary": self.summary,
            "summary_tokens": self.summary_tokens,
            "required_params": list(self.required_params),
            "optional_params": dict(self.optional_params),
            "governance": list(self.governance),
            "risk": self.risk.name,
            "derived_from": self.derived_from,
        }


class ToolRegistry:
    """Auto-derived registry over one or more ``MetaToolRouter`` instances."""

    def __init__(self) -> None:
        self._records: Dict[str, ToolRecord] = {}

    # -- derivation (the ONLY way records enter; no hand-maintained path) -----

    @classmethod
    def from_routers(cls, routers: Iterable[Any]) -> "ToolRegistry":
        """Derive every record from live routers (SchemaRegistry + handlers).

        Accepts any object with the ``MetaToolRouter`` surface:
        ``tool_name`` · ``registry`` (SchemaRegistry) · ``_handlers``.
        """
        reg = cls()
        for router in routers:
            reg.derive_router(router)
        return reg

    def derive_router(self, router: Any) -> List[ToolRecord]:
        """Walk one router's schema registry and derive its records."""
        derived: List[ToolRecord] = []
        gateway = getattr(router, "tool_name", "") or "unknown-gateway"
        schema_registry = getattr(router, "registry", None)
        if schema_registry is None:
            return derived  # not a router surface — nothing derivable
        handlers: Dict[str, Dict[str, Any]] = getattr(router, "_handlers", {})
        governance = tuple(getattr(router, "governance", ()) or ())
        for resource in schema_registry.resources():
            for operation in schema_registry.operations(resource):
                schema = schema_registry.get_schema(resource, operation)
                handler = handlers.get(resource, {}).get(operation)
                record = ToolRecord(
                    tool_id=f"{gateway}.{resource}.{operation}",
                    gateway=gateway,
                    resource=resource,
                    operation=operation,
                    summary=schema.description if schema else "",
                    summary_tokens=iso_tokens(
                        schema.description if schema else ""
                    ),
                    required_params=tuple(
                        schema.required_params if schema else ()
                    ),
                    optional_params=tuple(
                        sorted((schema.optional_params or {}).items())
                    )
                    if schema
                    else (),
                    governance=governance,
                    risk=risk_class(risk_signals_for_operation(operation)),
                    derived_from=_provenance(handler, gateway, resource, operation),
                )
                self._records[record.tool_id] = record
                derived.append(record)
        return derived

    # -- queries ---------------------------------------------------------------

    def records(self) -> List[ToolRecord]:
        return [self._records[k] for k in sorted(self._records)]

    def get(self, tool_id: str) -> Optional[ToolRecord]:
        return self._records.get(tool_id)

    def gateways(self) -> List[str]:
        return sorted({r.gateway for r in self._records.values()})

    def __len__(self) -> int:
        return len(self._records)

    # -- seams (the keystone contract) ------------------------------------------

    def to_iso_inventory(self) -> List[Dict[str, Any]]:
        """Exactly the ``{id, summary, schema}`` items IsoGate.from_inventory
        consumes (WT3 seam)."""
        return [
            {
                "id": r.tool_id,
                "summary": r.summary,
                "schema": r.schema_dict(),
            }
            for r in self.records()
        ]

    def to_cts_candidates(
        self,
        expert_fit: float = 0.0,
        methodology_fit: float = 0.0,
        eisenhower_q: int = 2,
    ) -> List[CtsCandidate]:
        """CtsCandidate rows with the derived RiskSignals (WT4 seam).

        Fit/eisenhower facts are TURN-scoped (the caller's judgment), not
        registry facts — passed through, defaulted neutrally.
        """
        return [
            CtsCandidate(
                tool_id=r.tool_id,
                risk=risk_signals_for_operation(r.operation),
                expert_fit=expert_fit,
                methodology_fit=methodology_fit,
                eisenhower_q=eisenhower_q,
                reversibility=1.0 if r.risk is RiskClass.LOW else 0.4,
                schema=r.schema_dict(),
            )
            for r in self.records()
        ]

    # -- projections + acceptance ------------------------------------------------

    def to_yaml(self) -> str:
        """The generated YAML projection of the SSOT (a BUILD ARTIFACT).

        Stdlib-only emission (values JSON-encoded — valid YAML subset).
        Editing this output by hand is the drift anti-pattern the registry
        exists to kill; the header says so.
        """
        lines = [
            "# AUTO-GENERATED by lib/gateway/tool_registry.py — DO NOT EDIT.",
            "# Derived from live MetaToolRouter SchemaRegistry instances;",
            "# regenerate instead of editing (hand-maintained YAML drifts).",
            f"schema_version: {json.dumps(REGISTRY_SCHEMA_VERSION)}",
            "tools:",
        ]
        for r in self.records():
            lines.append(f"  - tool_id: {json.dumps(r.tool_id)}")
            for key, value in r.to_dict().items():
                if key == "tool_id":
                    continue
                lines.append(f"    {key}: {json.dumps(value, sort_keys=True)}")
        return "\n".join(lines) + "\n"

    def report(self) -> Dict[str, Any]:
        """Logged-field invariants (the DoD-gate surface)."""
        records = self.records()
        return {
            "schema_version": REGISTRY_SCHEMA_VERSION,
            "total_tools": len(records),
            "per_gateway": {
                gw: sum(1 for r in records if r.gateway == gw)
                for gw in self.gateways()
            },
            "risk_distribution": {
                level.name: sum(1 for r in records if r.risk is level)
                for level in RiskClass
            },
            "invariants": {
                # every record carries handler provenance → derived, never hand-made
                "all_records_derived": all(r.derived_from for r in records),
                # tool_ids are namespaced by their gateway (no cross-wiring)
                "ids_namespaced_by_gateway": all(
                    r.tool_id.startswith(r.gateway + ".") for r in records
                ),
                # the ISO seam is loss-free (one inventory item per record)
                "iso_inventory_complete": len(self.to_iso_inventory())
                == len(records),
            },
        }


def _provenance(
    handler: Any, gateway: str, resource: str, operation: str
) -> str:
    """Module-qualified handler name — the derived-not-hand-maintained proof.

    ``MetaToolRouter.register`` wraps handlers with @with_feedback; unwrap
    via ``__wrapped__`` when present so provenance names the REAL handler.
    """
    fn = handler
    seen: set = set()
    while fn is not None and hasattr(fn, "__wrapped__") and id(fn) not in seen:
        seen.add(id(fn))  # guards pathological circular __wrapped__ chains
        fn = fn.__wrapped__
    if fn is None:
        # schema without a live handler — still derived (from the registry),
        # provenance names the schema slot
        return f"schema:{gateway}.{resource}.{operation}"
    module = getattr(fn, "__module__", "") or "unknown"
    qualname = getattr(fn, "__qualname__", None) or getattr(
        fn, "__name__", "unknown"
    )
    return f"{module}.{qualname}"
