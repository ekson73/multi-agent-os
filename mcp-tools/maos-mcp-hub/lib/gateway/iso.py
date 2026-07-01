"""
IsoGate — universal ISO tool-gating (WT3 / S3): summary pool + top-k promotion.

Spec contract (openspec/specs/maos-hub/spec.md → "ISO tool-gating (MCP-tax
control)")::

    The Hub SHALL keep a permanent summary pool (<=60 tokens/tool) and SHALL
    promote a full tool schema only for the top-k gated candidates of a turn.

This module generalizes the progressive-discovery pattern the Atlassian
gateways already implement (SchemaRegistry levels 0-2) into a
gateway-agnostic layer usable for ANY MCP tool inventory — the "MCP-tax"
control (conflict C4 in 20260627-ATH-OODA-RECON.md): with dozens of connected
tools, full schemas cost 10k-60k tokens/turn; the pool keeps every tool
discoverable at <=60 tokens while only the top-k candidates pay full price.

The two thresholds the review board required to be EXPLICIT (else the
"<=60 tok/tool" acceptance is incomputable):

NORMATIVE TOKENIZER
    ``iso_tokens(text) = ceil(len(text) / 4)`` — the industry-standard
    ~4-chars-per-token English heuristic. Deterministic, dependency-free,
    model-agnostic. The ``<=60 tokens/tool`` threshold is DEFINED in terms of
    this function: it does not drift when a vendor tokenizer changes, and any
    harness can recompute it with one line of arithmetic.

TOP-K
    ``ISO_DEFAULT_TOP_K = 5`` — explicit default, overridable per call.
    When a ``schema_token_budget`` is given, the effective k is additionally
    capped by greedy rank-order promotion while the cumulative promoted
    schema tokens fit the budget:
    ``k_effective = min(k_requested, budget_cap, len(allowed_candidates))``.

Composition (never reimplementation):
  - Hard filters FIRST: an optional ``PolicyResolver`` (PR #180 gating seam)
    eliminates denied candidates BEFORE promotion — a denied tool is never
    surfaced as a top-k candidate (mirrors the CTS "hard-filters-first"
    requirement).
  - ``SchemaRegistry`` remains the per-gateway schema source; IsoGate stores
    opaque schema dicts and only counts their serialized cost.

Every selection emits LOGGED FIELDS (``IsoSelection.to_report()``) — the
DoD-gate: acceptance is a logged field or golden-fixture invariant, never
prose. See ``evals/iso_gate_eval.py`` + ``tests/test_iso_gate.py``.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from .policy import PolicyResolver

SCHEMA_VERSION = "iso-gate/1.0.0"

#: Normative per-tool summary budget (spec: "<=60 tokens/tool").
ISO_SUMMARY_TOKEN_LIMIT = 60

#: Explicit default top-k (review-board requirement: k must be defined).
ISO_DEFAULT_TOP_K = 5


def iso_tokens(text: str) -> int:
    """NORMATIVE tokenizer for all ISO thresholds: ``ceil(len(text) / 4)``.

    Deterministic, dependency-free, model-agnostic. The spec's
    "<=60 tokens/tool" is defined in terms of THIS function (see module
    docstring for rationale).
    """
    if not text:
        return 0
    return math.ceil(len(text) / 4)


def _schema_tokens(schema: Optional[Dict[str, Any]]) -> int:
    """Token cost of a full schema = iso_tokens of its canonical JSON form."""
    if not schema:
        return 0
    return iso_tokens(json.dumps(schema, sort_keys=True, ensure_ascii=False))


@dataclass(frozen=True)
class ToolSummary:
    """One permanent-pool entry: a tool id + its <=60-token summary."""

    tool_id: str
    text: str
    tokens: int
    truncated: bool = False

    @classmethod
    def build(cls, tool_id: str, text: str) -> "ToolSummary":
        """Build a pool entry, deterministically truncating over-limit text.

        Truncation is character-exact against the normative tokenizer:
        the longest prefix whose ``iso_tokens`` is <= the limit
        (= ``ISO_SUMMARY_TOKEN_LIMIT * 4`` characters).
        """
        text = (text or "").strip()
        limit_chars = ISO_SUMMARY_TOKEN_LIMIT * 4
        truncated = False
        if iso_tokens(text) > ISO_SUMMARY_TOKEN_LIMIT:
            text = text[:limit_chars].rstrip()
            truncated = True
        return cls(
            tool_id=tool_id,
            text=text,
            tokens=iso_tokens(text),
            truncated=truncated,
        )


@dataclass
class IsoSelection:
    """Result of one ``IsoGate.select`` turn — all fields loggable."""

    k_requested: int
    k_effective: int
    pool_size: int
    promoted: List[str] = field(default_factory=list)
    summarized: List[str] = field(default_factory=list)
    denied: List[Dict[str, Any]] = field(default_factory=list)
    unknown: List[str] = field(default_factory=list)
    schema_tokens_promoted: int = 0
    schema_token_budget: Optional[int] = None
    summary_tokens_total: int = 0
    summary_tokens_max: int = 0

    def to_report(self) -> Dict[str, Any]:
        """Logged-fields report (the DoD-gate acceptance surface)."""
        return {
            "schema_version": SCHEMA_VERSION,
            "tokenizer": "ceil(len/4)",
            "summary_token_limit": ISO_SUMMARY_TOKEN_LIMIT,
            "k_requested": self.k_requested,
            "k_effective": self.k_effective,
            "pool_size": self.pool_size,
            "promoted": list(self.promoted),
            "summarized": list(self.summarized),
            "denied": list(self.denied),
            "unknown": list(self.unknown),
            "schema_tokens_promoted": self.schema_tokens_promoted,
            "schema_token_budget": self.schema_token_budget,
            "summary_tokens_total": self.summary_tokens_total,
            "summary_tokens_max": self.summary_tokens_max,
            "invariants": {
                "summaries_within_limit": self.summary_tokens_max
                <= ISO_SUMMARY_TOKEN_LIMIT,
                "promoted_lte_k": len(self.promoted) <= self.k_effective,
                "denied_never_promoted": not (
                    {d["tool_id"] for d in self.denied} & set(self.promoted)
                ),
                "budget_respected": (
                    self.schema_token_budget is None
                    or self.schema_tokens_promoted <= self.schema_token_budget
                ),
            },
        }


class IsoGate:
    """Universal ISO gating layer: permanent summary pool + top-k promotion.

    Usage::

        gate = IsoGate(policy=resolver)          # policy optional (passthrough)
        gate.register("openspec", "Spec-driven change management...", schema)
        ...
        sel = gate.select(ranked_ids, k=5, schema_token_budget=1200)
        sel.promoted    # top-k tool ids whose FULL schema is loaded this turn
        sel.summarized  # everything else — stays in the <=60-token pool
    """

    def __init__(
        self,
        k: int = ISO_DEFAULT_TOP_K,
        policy: Optional[PolicyResolver] = None,
    ) -> None:
        if k < 1:
            raise ValueError("k must be >= 1")
        self.default_k = k
        self.policy = policy
        self._pool: Dict[str, ToolSummary] = {}
        self._schemas: Dict[str, Optional[Dict[str, Any]]] = {}

    # -- pool ---------------------------------------------------------------

    def register(
        self,
        tool_id: str,
        summary: str,
        schema: Optional[Dict[str, Any]] = None,
    ) -> ToolSummary:
        """Add a tool to the permanent summary pool (idempotent by tool_id)."""
        entry = ToolSummary.build(tool_id, summary)
        self._pool[tool_id] = entry
        self._schemas[tool_id] = schema
        return entry

    def pool(self) -> List[ToolSummary]:
        """The permanent <=60-token/tool summary pool (sorted, deterministic)."""
        return [self._pool[t] for t in sorted(self._pool)]

    def schema_for(self, tool_id: str) -> Optional[Dict[str, Any]]:
        return self._schemas.get(tool_id)

    # -- selection ----------------------------------------------------------

    def select(
        self,
        ranked_candidates: Sequence[str],
        k: Optional[int] = None,
        schema_token_budget: Optional[int] = None,
    ) -> IsoSelection:
        """Promote the top-k gated candidates; everything else stays summary.

        Args:
            ranked_candidates: tool ids in descending preference order (the
                ranking itself comes from the caller — e.g. the CTS scorer).
            k: per-turn override of the default top-k.
            schema_token_budget: optional cumulative cap on promoted full
                schema tokens (normative tokenizer); greedy in rank order.
        """
        k_requested = k if k is not None else self.default_k
        if k_requested < 1:
            raise ValueError("k must be >= 1")

        promoted: List[str] = []
        denied: List[Dict[str, Any]] = []
        unknown: List[str] = []
        seen: set = set()
        spent = 0

        for tool_id in ranked_candidates:
            if tool_id in seen:
                continue
            seen.add(tool_id)
            if tool_id not in self._pool:
                unknown.append(tool_id)
                continue
            # Hard filter FIRST: a policy-denied tool is never promoted.
            if self.policy is not None:
                decision = self.policy.check(tool_id)
                if not decision.allow:
                    denied.append(
                        {
                            "tool_id": tool_id,
                            "reason": decision.reason,
                            "conflicting_with": list(decision.conflicting_with),
                        }
                    )
                    continue
            if len(promoted) >= k_requested:
                continue  # rank exhausted the k slots; stays summarized
            cost = _schema_tokens(self._schemas.get(tool_id))
            if schema_token_budget is not None and spent + cost > schema_token_budget:
                continue  # would bust the budget; stays summarized
            promoted.append(tool_id)
            spent += cost

        promoted_set = set(promoted)
        denied_set = {d["tool_id"] for d in denied}
        summarized = [
            t for t in sorted(self._pool) if t not in promoted_set and t not in denied_set
        ]
        pool_tokens = [s.tokens for s in self._pool.values()]

        return IsoSelection(
            k_requested=k_requested,
            k_effective=len(promoted),
            pool_size=len(self._pool),
            promoted=promoted,
            summarized=summarized,
            denied=denied,
            unknown=unknown,
            schema_tokens_promoted=spent,
            schema_token_budget=schema_token_budget,
            summary_tokens_total=sum(pool_tokens),
            summary_tokens_max=max(pool_tokens, default=0),
        )

    # -- construction helpers -------------------------------------------------

    @classmethod
    def from_inventory(
        cls,
        inventory: Iterable[Dict[str, Any]],
        k: int = ISO_DEFAULT_TOP_K,
        policy: Optional[PolicyResolver] = None,
    ) -> Tuple["IsoGate", List[ToolSummary]]:
        """Build a gate from an inventory (list of {id, summary, schema?})."""
        gate = cls(k=k, policy=policy)
        entries = [
            gate.register(item["id"], item.get("summary", ""), item.get("schema"))
            for item in inventory
        ]
        return gate, entries
