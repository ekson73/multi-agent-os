"""
CtsScorer — unified CTS multi-criteria scoring (WT4 / S2): hard-filters-first.

Spec contract (openspec/specs/maos-hub/spec.md → "CTS multi-criteria scoring
(hard-filters-first)")::

    The Hub SHALL apply hard filters (open-source/policy, auth, environment,
    data-class, risk-class) BEFORE a weighted score over ISO x Eisenhower x
    risk x scope x methodology x reversibility (the 4-dim rubric
    Expert-fit/Authorization/Task-frame/Risk-frame from `rbad` +
    `action-priority`).

Before this module the prioritization logic existed but was SCATTERED
(OODA-RECON critique: "action-priority + rbad + agent-select, but no single
weighted scorer"). This composes the three sources into ONE scorer:

  - ``protocols/action-priority.md`` -> the Eisenhower criterion (Q1..Q4);
  - ``protocols/rbad.md``            -> the 4-dim rubric mapping (below);
  - ``lib/gateway/iso.py``           -> the ISO cost criterion (normative
    tokenizer) AND the downstream consumer: ``CtsRanking.ranked_ids()`` is
    exactly the ``ranked_candidates`` input of ``IsoGate.select``.

THE CONCRETE ``risk=HIGH`` PREDICATE (review-board mandate — "not
'irreversible-ish'"): risk is derived from ``RiskSignals``, a fixed set of
ENUMERABLE BOOLEAN FACTS about the candidate action::

    HIGH   iff ANY of {irreversible, destructive, credential_scope,
                       prod_facing, cross_org}
    MEDIUM iff (not HIGH) and ANY of {bulk_write, remote_write}
    LOW    otherwise (read-only / locally-reversible)

Each signal is a verifiable property of the action — never a vibe:
  irreversible     no single-command undo (force-push, secret rotation, drop)
  destructive      deletes data/branches/resources without a backup path
  credential_scope reads or writes secrets/credentials
  prod_facing      mutates production-facing state (deploy, DNS, billing)
  cross_org        writes/egress beyond the org boundary (public post, 3rd party)
  bulk_write       mutates many resources in one call
  remote_write     any single-target reversible remote mutation

RBAD 4-dim rubric mapping (spec parenthetical):
  Expert-fit     -> ``expert_fit`` + ``methodology_fit`` criteria
  Authorization  -> the ``auth`` HARD FILTER (never a weighted criterion —
                    a tool you cannot authorize must not score at all)
  Task-frame     -> the ``eisenhower`` criterion (Q1..Q4 mapping)
  Risk-frame     -> the ``risk`` + ``reversibility`` criteria (+ the
                    ``risk-class`` hard ceiling)

Every ranking emits LOGGED FIELDS (``CtsRanking.to_report()``) — the
DoD-gate: acceptance is a logged field or golden-fixture invariant, never
prose. See ``evals/cts_eval.py`` + ``tests/test_cts_scorer.py``.
"""

from __future__ import annotations

from dataclasses import dataclass, field, fields as dc_fields
from enum import IntEnum
from typing import Any, Dict, FrozenSet, Iterable, List, Optional, Sequence

from .iso import _schema_tokens
from .policy import PolicyResolver

SCHEMA_VERSION = "cts-scorer/1.0.0"

#: Schema cost (normative iso_tokens) at/above which the ISO criterion is 0.0.
ISO_COST_CEILING = 600

#: Explicit criterion weights (spec: ISO x Eisenhower x risk x scope x
#: methodology x reversibility). MUST sum to 1.0 (asserted by tests).
CTS_WEIGHTS: Dict[str, float] = {
    "scope": 0.30,          # RBAD Expert-fit (domain/scope match)
    "eisenhower": 0.20,     # RBAD Task-frame (action-priority Q1..Q4)
    "risk": 0.15,           # RBAD Risk-frame (derived RiskClass)
    "reversibility": 0.15,  # RBAD Risk-frame (undo-ability)
    "iso": 0.10,            # ISO schema-cost frugality (normative tokenizer)
    "methodology": 0.10,    # RBAD Expert-fit (methodology/task-style match)
}

#: Eisenhower quadrant -> criterion value (Q1 do-now ... Q4 eliminate).
EISENHOWER_VALUE: Dict[int, float] = {1: 1.0, 2: 0.75, 3: 0.40, 4: 0.0}


class RiskClass(IntEnum):
    """Ordered risk classes (comparable: LOW < MEDIUM < HIGH)."""

    LOW = 0
    MEDIUM = 1
    HIGH = 2


@dataclass(frozen=True)
class RiskSignals:
    """Enumerable boolean facts — the concrete risk predicate's inputs."""

    irreversible: bool = False
    destructive: bool = False
    credential_scope: bool = False
    prod_facing: bool = False
    cross_org: bool = False
    bulk_write: bool = False
    remote_write: bool = False

    HIGH_SIGNALS = (
        "irreversible",
        "destructive",
        "credential_scope",
        "prod_facing",
        "cross_org",
    )
    MEDIUM_SIGNALS = ("bulk_write", "remote_write")

    def active(self) -> List[str]:
        return [f.name for f in dc_fields(self) if getattr(self, f.name)]


def risk_class(signals: RiskSignals) -> RiskClass:
    """The CONCRETE ``risk=HIGH`` predicate (see module docstring)."""
    if any(getattr(signals, name) for name in RiskSignals.HIGH_SIGNALS):
        return RiskClass.HIGH
    if any(getattr(signals, name) for name in RiskSignals.MEDIUM_SIGNALS):
        return RiskClass.MEDIUM
    return RiskClass.LOW


#: RiskClass -> criterion value (lower risk scores higher).
RISK_VALUE: Dict[RiskClass, float] = {
    RiskClass.LOW: 1.0,
    RiskClass.MEDIUM: 0.6,
    RiskClass.HIGH: 0.2,
}


@dataclass(frozen=True)
class CtsCandidate:
    """One tool candidate: hard-filter facts + scoring facts."""

    tool_id: str
    # -- hard-filter facts ---------------------------------------------------
    open_source_ok: bool = True
    required_scopes: FrozenSet[str] = frozenset()
    env_ok: bool = True
    data_classes: FrozenSet[str] = frozenset()
    risk: RiskSignals = RiskSignals()
    # -- scoring facts (0..1 unless noted) ------------------------------------
    expert_fit: float = 0.0
    methodology_fit: float = 0.0
    eisenhower_q: int = 2  # quadrant of the task this candidate serves (1..4)
    reversibility: float = 1.0
    schema: Optional[Dict[str, Any]] = None  # for the ISO cost criterion


@dataclass(frozen=True)
class CtsTurn:
    """The turn context hard filters evaluate against."""

    granted_scopes: FrozenSet[str] = frozenset()
    allowed_data_classes: FrozenSet[str] = frozenset()
    max_risk: RiskClass = RiskClass.HIGH  # inclusive ceiling
    require_open_source: bool = True


@dataclass
class CtsRanking:
    """Result of one ``CtsScorer.rank`` turn — all fields loggable."""

    ranked: List[Dict[str, Any]] = field(default_factory=list)
    eliminated: List[Dict[str, Any]] = field(default_factory=list)

    def ranked_ids(self) -> List[str]:
        """The ``ranked_candidates`` input for ``IsoGate.select`` (the seam)."""
        return [entry["tool_id"] for entry in self.ranked]

    def to_report(self) -> Dict[str, Any]:
        """Logged-fields report (the DoD-gate acceptance surface)."""
        eliminated_ids = {e["tool_id"] for e in self.eliminated}
        return {
            "schema_version": SCHEMA_VERSION,
            "weights": dict(CTS_WEIGHTS),
            "hard_filter_order": list(HARD_FILTER_ORDER),
            "ranked": list(self.ranked),
            "eliminated": list(self.eliminated),
            "invariants": {
                "weights_sum_to_1": abs(sum(CTS_WEIGHTS.values()) - 1.0) < 1e-9,
                "eliminated_never_ranked": not (
                    eliminated_ids & {r["tool_id"] for r in self.ranked}
                ),
                "scores_descending": all(
                    self.ranked[i]["score"] >= self.ranked[i + 1]["score"]
                    for i in range(len(self.ranked) - 1)
                ),
                "every_elimination_reasoned": all(
                    e.get("filter") and e.get("reason") for e in self.eliminated
                ),
            },
        }


#: Hard filters run IN THIS ORDER; the first hit eliminates (reason traced).
HARD_FILTER_ORDER = (
    "policy",
    "open_source",
    "auth",
    "environment",
    "data_class",
    "risk_class",
)


class CtsScorer:
    """Unified CTS scorer: hard filters FIRST, weighted score second.

    Usage::

        scorer = CtsScorer(policy=resolver)          # policy optional
        ranking = scorer.rank(candidates, turn)
        gate.select(ranking.ranked_ids(), ...)       # feed IsoGate (WT3)
    """

    def __init__(self, policy: Optional[PolicyResolver] = None) -> None:
        self.policy = policy

    # -- hard filters (spec: BEFORE any weighted score) -----------------------

    def _hard_filter(
        self, candidate: CtsCandidate, turn: CtsTurn
    ) -> Optional[Dict[str, Any]]:
        """Return the elimination record for the FIRST failing filter, or None."""
        if self.policy is not None:
            decision = self.policy.check(candidate.tool_id)
            if not decision.allow:
                return {
                    "tool_id": candidate.tool_id,
                    "filter": "policy",
                    "reason": decision.reason,
                    "conflicting_with": list(decision.conflicting_with),
                    "hitl_eligible": False,
                }
        if turn.require_open_source and not candidate.open_source_ok:
            return {
                "tool_id": candidate.tool_id,
                "filter": "open_source",
                "reason": "candidate fails the open-source/policy requirement",
                "hitl_eligible": False,
            }
        missing = candidate.required_scopes - turn.granted_scopes
        if missing:
            return {
                "tool_id": candidate.tool_id,
                "filter": "auth",
                "reason": f"missing authorization scope(s): {sorted(missing)}",
                "hitl_eligible": False,
            }
        if not candidate.env_ok:
            return {
                "tool_id": candidate.tool_id,
                "filter": "environment",
                "reason": "candidate cannot run in the current environment",
                "hitl_eligible": False,
            }
        disallowed = candidate.data_classes - turn.allowed_data_classes
        if disallowed:
            return {
                "tool_id": candidate.tool_id,
                "filter": "data_class",
                "reason": f"touches disallowed data class(es): {sorted(disallowed)}",
                "hitl_eligible": False,
            }
        rc = risk_class(candidate.risk)
        if rc > turn.max_risk:
            # Never a silent drop: above-ceiling risk is HITL-routable
            # (spec: "HITL on irreversible / high-risk").
            return {
                "tool_id": candidate.tool_id,
                "filter": "risk_class",
                "reason": (
                    f"risk={rc.name} exceeds the turn ceiling {turn.max_risk.name} "
                    f"(active signals: {candidate.risk.active()})"
                ),
                "hitl_eligible": True,
            }
        return None

    # -- weighted score --------------------------------------------------------

    @staticmethod
    def _criteria(candidate: CtsCandidate) -> Dict[str, float]:
        cost = _schema_tokens(candidate.schema)
        return {
            "scope": max(0.0, min(1.0, candidate.expert_fit)),
            "eisenhower": EISENHOWER_VALUE.get(candidate.eisenhower_q, 0.0),
            "risk": RISK_VALUE[risk_class(candidate.risk)],
            "reversibility": max(0.0, min(1.0, candidate.reversibility)),
            "iso": max(0.0, 1.0 - min(1.0, cost / max(ISO_COST_CEILING, 1))),
            "methodology": max(0.0, min(1.0, candidate.methodology_fit)),
        }

    @classmethod
    def score(cls, candidate: CtsCandidate) -> Dict[str, Any]:
        criteria = cls._criteria(candidate)
        total = sum(CTS_WEIGHTS[name] * value for name, value in criteria.items())
        return {
            "tool_id": candidate.tool_id,
            "score": round(total, 6),
            "criteria": {k: round(v, 6) for k, v in criteria.items()},
            "risk_class": risk_class(candidate.risk).name,
        }

    # -- the seam contract ------------------------------------------------------

    def rank(
        self, candidates: Iterable[CtsCandidate], turn: CtsTurn
    ) -> CtsRanking:
        """Hard-filter then score+sort. Deterministic (ties break on tool_id)."""
        ranking = CtsRanking()
        seen: set = set()
        for candidate in candidates:
            if candidate.tool_id in seen:
                continue
            seen.add(candidate.tool_id)
            elimination = self._hard_filter(candidate, turn)
            if elimination is not None:
                ranking.eliminated.append(elimination)
                continue
            ranking.ranked.append(self.score(candidate))
        ranking.ranked.sort(key=lambda e: (-e["score"], e["tool_id"]))
        return ranking


def candidates_from_fixture(
    items: Sequence[Dict[str, Any]],
) -> List[CtsCandidate]:
    """Build candidates from a fixture list (evals/tests helper)."""
    out: List[CtsCandidate] = []
    for item in items:
        out.append(
            CtsCandidate(
                tool_id=item["id"],
                open_source_ok=item.get("open_source_ok", True),
                required_scopes=frozenset(item.get("required_scopes", [])),
                env_ok=item.get("env_ok", True),
                data_classes=frozenset(item.get("data_classes", [])),
                risk=RiskSignals(**item.get("risk", {})),
                expert_fit=item.get("expert_fit", 0.0),
                methodology_fit=item.get("methodology_fit", 0.0),
                eisenhower_q=item.get("eisenhower_q", 2),
                reversibility=item.get("reversibility", 1.0),
                schema=item.get("schema"),
            )
        )
    return out
