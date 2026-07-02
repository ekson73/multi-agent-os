"""
HubRegistry — the plugin-level registry SSOT (T1 / WAVE 5, ADR-006/ADR-007).

The SSOT both the console (WAVE 5) and the integrator (WAVE 6) read: one
machine-readable record per MAOS-routable tool — own skills + own agents +
integrated third-party experts — per ``openspec/specs/maos-hub-registry/spec.md``.

Derivation sources (records are DERIVED, never hand-maintained — the spec's
first requirement, mirroring WT8 ``lib.gateway.tool_registry``):

  - own skills   → ``skills/*/SKILL.md`` frontmatter (name/description/version)
  - own agents   → ``agents/*.md`` frontmatter (name/description)
  - third-party  → ``evals/fixtures/intake_verdicts.yaml`` (WT10 — verdicts,
                   license, provenance repo, flags, conditions, TTL dates)
  - conflicts    → ``lib/gateway/conflicts.yaml`` (WAVE-0 — the Phase-2
                   incompatibilities, already promoted; round-tripped here)
  - recipes      → ``lib/gateway/recipes.yaml`` (T1 — the Phase-2 §4
                   composition recipes, promoted like conflicts.yaml)
  - conductors   → ``plugin-scripts/governance/lib/conductors.txt`` (RULE-011)

Spec scenarios implemented as CHECKABLE fields (the DoD-gate — no prose):

  - "a new skill ships"            → ``HubRegistry.derive`` regenerates the
    record from frontmatter alone (test adds a synthetic skill to a tmp repo).
  - "third-party proposed as always-on" → ``request_activation(id, "always-on")``
    refuses when ``license_spdx == "NONE"`` OR a ``conflicts_with`` edge exists,
    records the reason in ``gate_decisions`` (a logged field).
  - "two conductors selected"      → the ``conflicts_with`` graph round-trips
    ``conflicts.yaml`` exactly (``report().invariants.conflicts_roundtrip``).
  - "upstream goes stale/abandoned" → ``eject_candidates(today)`` flags records
    whose ``ttl`` deadline has passed (the GSD/MemPalace lesson).

Deterministic activation derivation (documented, fail-closed):

  third-party (by intake verdict):
    EXCLUDED | ABANDON  → excluded
    SUB-AGENT | DEFER   → opt-in
    INSTALL | ADAPT | ABSORB
      → default-on-for-context, UNLESS license_spdx == "NONE" OR the id is in
        the conductor class OR it has a conflicts_with edge → opt-in (reason
        recorded). ``always-on`` is NEVER granted at derivation time — only
        via ``request_activation`` and only when every gate passes.
  own tools:
    skills → default-on-for-context (context-loaded plugin surface)
    agents → opt-in (spawned on demand)
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, FrozenSet, Iterable, List, Optional, Set, Tuple

import yaml

HUB_REGISTRY_SCHEMA_VERSION = "hub-registry/1.0.0"

ACTIVATION_TIERS = ("always-on", "default-on-for-context", "opt-in", "excluded")

#: Verdict → activation tier (third-party derivation; module docstring contract).
_VERDICT_ACTIVATION = {
    "EXCLUDED": "excluded",
    "ABANDON": "excluded",
    "SUB-AGENT": "opt-in",
    "DEFER": "opt-in",
    "INSTALL": "default-on-for-context",
    "ADAPT": "default-on-for-context",
    "ABSORB": "default-on-for-context",
}

#: conflicts.yaml endpoints that are VARIANTS of a canonical intake id.
CONFLICT_ALIASES = {
    "ECC-browser-mcp": "ECC",
    "bmad-as-co-runtime": "bmad-method",
}

_OWN_REPO = "ekson73/multi-agent-os"
_OWN_LICENSE = "MIT"
_FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.S)


@dataclass(frozen=True)
class HubRecord:
    """One registry record — the exact field set of the spec's Tool record."""

    id: str
    owner_repo: str
    layer: str
    role: str
    category: str
    harness_coverage: Tuple[str, ...]
    requires: Tuple[str, ...]
    conflicts_with: Tuple[str, ...]
    guardrails: str
    impact: str
    recipes: Tuple[str, ...]
    activation: str
    license_spdx: str
    provenance: str
    ttl: Optional[str]            # deadline date (ISO) after which re-validation is due
    last_validated: Optional[str]
    rollback: str
    security_status: str
    derived_from: str             # provenance of the DERIVATION itself (checkable)
    activation_reason: str = ""   # why the tier was capped/granted (logged field)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "owner_repo": self.owner_repo,
            "layer": self.layer,
            "role": self.role,
            "category": self.category,
            "harness_coverage": list(self.harness_coverage),
            "requires": list(self.requires),
            "conflicts_with": list(self.conflicts_with),
            "guardrails": self.guardrails,
            "impact": self.impact,
            "recipes": list(self.recipes),
            "activation": self.activation,
            "license_spdx": self.license_spdx,
            "provenance": self.provenance,
            "ttl": self.ttl,
            "last_validated": self.last_validated,
            "rollback": self.rollback,
            "security_status": self.security_status,
            "derived_from": self.derived_from,
            "activation_reason": self.activation_reason,
        }


def _parse_frontmatter(path: Path) -> Optional[Dict[str, Any]]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return None
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError:
        return None
    return data if isinstance(data, dict) else None


def _flatten_stack(stack: Iterable[Any]) -> List[str]:
    """Flatten a recipe stack; nested lists mean 'a OR b' alternatives."""
    out: List[str] = []
    for item in stack:
        if isinstance(item, list):
            out.extend(str(x) for x in item)
        else:
            out.append(str(item))
    return out


class HubRegistry:
    """Plugin-level registry derived from the repo's own sources of truth."""

    def __init__(self) -> None:
        self._records: Dict[str, HubRecord] = {}
        self._conflict_edges: Set[FrozenSet[str]] = set()
        self._gate_decisions: List[Dict[str, str]] = []
        self._conductors: Set[str] = set()
        self._collisions: List[Dict[str, str]] = []

    # ------------------------------------------------------------ derive ---
    @classmethod
    def derive(cls, repo_root: Path, as_of: str) -> "HubRegistry":
        """Derive the full registry from a repo checkout.

        ``as_of`` (ISO date) stamps ``last_validated`` on OWN records —
        derivation IS validation for first-party tools (they are re-derived
        from the live checkout every build). Third-party records keep the
        intake fixture's ``decided``/``revisit`` dates.
        """
        reg = cls()
        hub_dir = repo_root / "mcp-tools" / "maos-mcp-hub"

        reg._conductors = _load_conductors(
            repo_root / "plugin-scripts" / "governance" / "lib" / "conductors.txt"
        )
        conflicts_by_id = reg._load_conflicts(hub_dir / "lib" / "gateway" / "conflicts.yaml")
        recipes_by_id = _load_recipes(hub_dir / "lib" / "gateway" / "recipes.yaml")

        reg._derive_own_skills(repo_root, as_of, conflicts_by_id, recipes_by_id)
        reg._derive_own_agents(repo_root, as_of, conflicts_by_id, recipes_by_id)
        reg._derive_third_party(
            hub_dir / "evals" / "fixtures" / "intake_verdicts.yaml",
            conflicts_by_id,
            recipes_by_id,
        )
        return reg

    def _load_conflicts(self, path: Path) -> Dict[str, Set[str]]:
        by_id: Dict[str, Set[str]] = {}
        if not path.is_file():
            return by_id
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        for edge in data.get("conflicts", []):
            if isinstance(edge, dict):
                a, b = str(edge.get("a")), str(edge.get("b"))
            else:  # 2-item sequence
                a, b = str(edge[0]), str(edge[1])
            a = CONFLICT_ALIASES.get(a, a)
            b = CONFLICT_ALIASES.get(b, b)
            self._conflict_edges.add(frozenset((a, b)))
            by_id.setdefault(a, set()).add(b)
            by_id.setdefault(b, set()).add(a)
        return by_id

    def _derive_own_skills(
        self,
        repo_root: Path,
        as_of: str,
        conflicts: Dict[str, Set[str]],
        recipes: Dict[str, List[str]],
    ) -> None:
        for skill_md in sorted((repo_root / "skills").glob("*/SKILL.md")):
            fm = _parse_frontmatter(skill_md)
            if not fm or "name" not in fm:
                continue
            sid = str(fm["name"])
            rel = skill_md.relative_to(repo_root).as_posix()
            self._add(
                HubRecord(
                    id=sid,
                    owner_repo=_OWN_REPO,
                    layer="L2",
                    role="pipeline",
                    category="skill",
                    harness_coverage=("claude-code",),
                    requires=(),
                    conflicts_with=tuple(sorted(conflicts.get(sid, ()))),
                    guardrails="",
                    impact=str(fm.get("description", "")).strip()[:200],
                    recipes=tuple(recipes.get(sid, ())),
                    activation="default-on-for-context",
                    license_spdx=_OWN_LICENSE,
                    provenance=f"repo:{_OWN_REPO}@{rel}",
                    ttl=None,
                    last_validated=as_of,
                    rollback="git revert the introducing commit; plugin re-install",
                    security_status="first-party",
                    derived_from=rel,
                )
            )

    def _derive_own_agents(
        self,
        repo_root: Path,
        as_of: str,
        conflicts: Dict[str, Set[str]],
        recipes: Dict[str, List[str]],
    ) -> None:
        for agent_md in sorted((repo_root / "agents").glob("*.md")):
            fm = _parse_frontmatter(agent_md)
            if not fm or "name" not in fm:
                continue  # README / policy docs without frontmatter
            aid = str(fm["name"])
            if aid in self._records:  # a skill already claimed the id
                continue
            rel = agent_md.relative_to(repo_root).as_posix()
            self._add(
                HubRecord(
                    id=aid,
                    owner_repo=_OWN_REPO,
                    layer="L3",
                    role="amplifier",
                    category="agent",
                    harness_coverage=("claude-code",),
                    requires=(),
                    conflicts_with=tuple(sorted(conflicts.get(aid, ()))),
                    guardrails="",
                    impact=str(fm.get("description", "")).strip()[:200],
                    recipes=tuple(recipes.get(aid, ())),
                    activation="opt-in",
                    license_spdx=_OWN_LICENSE,
                    provenance=f"repo:{_OWN_REPO}@{rel}",
                    ttl=None,
                    last_validated=as_of,
                    rollback="git revert the introducing commit; plugin re-install",
                    security_status="first-party",
                    derived_from=rel,
                )
            )

    def _derive_third_party(
        self,
        fixture: Path,
        conflicts: Dict[str, Set[str]],
        recipes: Dict[str, List[str]],
    ) -> None:
        if not fixture.is_file():
            return
        data = yaml.safe_load(fixture.read_text(encoding="utf-8")) or {}
        decided = str(data.get("decided", "")) or None
        revisit = str(data.get("revisit", "")) or None
        rel = "mcp-tools/maos-mcp-hub/evals/fixtures/intake_verdicts.yaml"
        for entry in data.get("entries", []):
            tid = str(entry.get("id"))
            verdict = str(entry.get("verdict", "")).upper()
            license_raw = str(entry.get("license", "") or "none")
            license_spdx = "NONE" if license_raw.lower() in ("none", "null", "") else license_raw
            edges = tuple(sorted(conflicts.get(tid, ())))
            activation, reason = self._third_party_activation(tid, verdict, license_spdx, edges)
            flags = [str(f) for f in entry.get("flags", [])]
            if entry.get("blocked") or verdict == "EXCLUDED":
                security = "supply-chain-veto"
            elif "license-none" in flags:
                security = "license-risk"
            else:
                security = "vetted"
            conditions = [str(c) for c in entry.get("conditions", [])]
            self._add(
                HubRecord(
                    id=tid,
                    owner_repo=str(entry.get("repo", "")),
                    layer=str(entry.get("layer", "")),
                    role=str(entry.get("role", "")).strip()[:200],
                    category="third-party",
                    harness_coverage=(),
                    requires=(),
                    conflicts_with=edges,
                    guardrails="; ".join(conditions),
                    impact=str(entry.get("rationale", "")).strip()[:200],
                    recipes=tuple(recipes.get(tid, ())),
                    activation=activation,
                    license_spdx=license_spdx,
                    provenance=f"intake:{rel}#{tid} (verdict={verdict})",
                    ttl=revisit,
                    last_validated=decided,
                    rollback="disable in the enablement profile; remove slot-adapter (WAVE-6 T7 recipe)",
                    security_status=security,
                    derived_from=rel,
                    activation_reason=reason,
                )
            )

    def _third_party_activation(
        self, tid: str, verdict: str, license_spdx: str, edges: Tuple[str, ...]
    ) -> Tuple[str, str]:
        tier = _VERDICT_ACTIVATION.get(verdict, "opt-in")
        reason = f"verdict={verdict}"
        if tier == "default-on-for-context":
            if license_spdx == "NONE":
                tier, reason = "opt-in", "gate: license_spdx=NONE (HF2 — not license-clean)"
            elif tid in self._conductors:
                tier, reason = "opt-in", "gate: conductor class (RULE-011 single-conductor)"
            elif edges:
                tier, reason = "opt-in", f"gate: conflicts_with={','.join(edges)}"
        self._gate_decisions.append({"id": tid, "activation": tier, "reason": reason})
        return tier, reason

    def _add(self, record: HubRecord) -> None:
        existing = self._records.get(record.id)
        if existing is not None:
            # NEVER silently overwrite the SSOT (PR #209 finding): derivation
            # order (skills -> agents -> third-party) fixes precedence =
            # first-derived wins; the collision is a recorded, verdict-failing
            # invariant when it crosses categories (a third-party id shadowing
            # a first-party tool would swap provenance/activation silently).
            self._collisions.append(
                {"id": record.id, "kept": existing.category, "dropped": record.category}
            )
            return
        self._records[record.id] = record

    # ------------------------------------------------------------ queries ---
    def records(self) -> List[HubRecord]:
        return sorted(self._records.values(), key=lambda r: r.id)

    def get(self, rid: str) -> Optional[HubRecord]:
        return self._records.get(rid)

    def __len__(self) -> int:
        return len(self._records)

    @property
    def gate_decisions(self) -> List[Dict[str, str]]:
        return list(self._gate_decisions)

    def conflict_edges(self) -> Set[FrozenSet[str]]:
        return set(self._conflict_edges)

    def edges_from_records(self) -> Set[FrozenSet[str]]:
        out: Set[FrozenSet[str]] = set()
        for rec in self._records.values():
            for other in rec.conflicts_with:
                out.add(frozenset((rec.id, other)))
        return out

    def request_activation(self, rid: str, requested: str) -> Dict[str, str]:
        """Spec scenario 'third-party proposed as always-on' — a logged gate.

        ``always-on`` is granted to a third-party record ONLY when license-clean
        (SPDX present, not NONE) AND conflict-free AND not supply-chain-vetoed.
        Refusals keep the derived tier and record the reason.
        """
        rec = self._records.get(rid)
        if rec is None:
            raise KeyError(rid)
        if requested not in ACTIVATION_TIERS:
            raise ValueError(f"unknown activation tier: {requested}")
        decision = {"id": rid, "requested": requested, "granted": rec.activation, "reason": ""}
        rank = {tier: i for i, tier in enumerate(ACTIVATION_TIERS[::-1])}  # excluded=0 .. always-on=3
        if rec.activation == "excluded":
            # Immutable via API (PR #209 finding — Blocker): a supply-chain
            # veto / ABANDON verdict can only change by RE-DERIVATION (a new
            # intake verdict), never by an activation request.
            decision["reason"] = "refused: activation=excluded is immutable via request (re-derive)"
        elif requested == "always-on" and rec.category == "third-party":
            if rec.license_spdx == "NONE":
                decision["reason"] = "refused: license_spdx=NONE (license-clean gate)"
            elif rec.conflicts_with:
                decision["reason"] = (
                    f"refused: conflicts_with={','.join(rec.conflicts_with)} (conflict-free gate)"
                )
            elif rec.security_status != "vetted":
                decision["reason"] = f"refused: security_status={rec.security_status}"
            else:
                decision["granted"] = "always-on"
                decision["reason"] = "granted: license-clean + conflict-free + vetted"
        elif requested == "always-on":
            decision["granted"] = "always-on"
            decision["reason"] = "granted: first-party"
        elif rank[requested] > rank[rec.activation]:
            # Fail-closed (PR #209 finding): upgrades beyond the DERIVED tier
            # are refused — the derivation (verdict + gates) is the authority.
            decision["reason"] = (
                f"refused: upgrade {rec.activation} -> {requested} beyond derived tier (re-derive)"
            )
        else:
            decision["granted"] = requested
            decision["reason"] = "granted: downgrade/equal to derived tier"
        self._gate_decisions.append(
            {"id": rid, "activation": decision["granted"], "reason": decision["reason"]}
        )
        return decision

    def eject_candidates(self, today: str) -> List[str]:
        """Freshness invariant: ttl deadline passed → eject-candidate (HITL)."""
        out = []
        for rec in self.records():
            if rec.ttl and today > rec.ttl:
                out.append(rec.id)
        return out

    # ------------------------------------------------------------ outputs ---
    def to_yaml(self) -> str:
        header = (
            "# AUTO-GENERATED by lib/registry/hub_registry.py — DO NOT EDIT.\n"
            f"# schema: {HUB_REGISTRY_SCHEMA_VERSION}\n"
        )
        body = yaml.safe_dump(
            {"records": [r.to_dict() for r in self.records()]},
            sort_keys=False,
            allow_unicode=True,
        )
        return header + body

    def report(self, today: Optional[str] = None) -> Dict[str, Any]:
        """The logged-field acceptance surface (DoD-gate — never prose)."""
        recs = self.records()
        # Non-EMPTY critical fields (PR #209 finding: key-presence on a
        # dataclass dict is vacuous — content is the real invariant).
        required_ok = all(
            bool(r.id) and bool(r.provenance) and bool(r.derived_from)
            and bool(r.activation) and bool(r.license_spdx) and bool(r.rollback)
            and bool(r.security_status) and bool(r.category)
            for r in recs
        )
        vocab_ok = all(r.activation in ACTIVATION_TIERS for r in recs)
        roundtrip = self.conflict_edges() == self.edges_from_records()
        third_party_always_on = [
            r.id for r in recs if r.category == "third-party" and r.activation == "always-on"
        ]
        cross_category_collisions = [
            c for c in self._collisions if c["kept"] != c["dropped"]
        ]
        invariants = {
            "schema_version": HUB_REGISTRY_SCHEMA_VERSION,
            "total_records": len(recs),
            "all_required_fields_present": required_ok,
            "activation_vocab_valid": vocab_ok,
            "conflicts_roundtrip": roundtrip,
            "third_party_always_on": third_party_always_on,
            "id_collisions": list(self._collisions),
        }
        if today:
            invariants["eject_candidates"] = self.eject_candidates(today)
        ok = (
            required_ok and vocab_ok and roundtrip
            and not third_party_always_on and not cross_category_collisions
        )
        return {
            "verdict": "pass" if ok else "fail",
            "invariants": invariants,
            "gate_decisions": self.gate_decisions,
        }


def _load_conductors(path: Path) -> Set[str]:
    """Parse ``conductors.txt`` (RULE-011 registry).

    File format is ``<manager>|<signature-path>`` (e.g. ``bmad-method|.bmad-core``)
    — only the MANAGER id (left of the first ``|``) enters the set, so the
    ``tid in conductors`` gate actually matches intake ids (PR #209 finding).
    """
    if not path.is_file():
        return set()
    out: Set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        manager = line.split("|", 1)[0].strip()
        if manager:
            out.add(manager)
    return out


def _load_recipes(path: Path) -> Dict[str, List[str]]:
    by_id: Dict[str, List[str]] = {}
    if not path.is_file():
        return by_id
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    for recipe in data.get("recipes", []):
        rid = str(recipe.get("id") or "").strip()
        if not rid:
            continue
        for tool in _flatten_stack(recipe.get("stack", [])):
            tool = tool.strip()
            if tool and tool.lower() != "none":
                by_id.setdefault(tool, []).append(rid)
    return by_id


def _main(argv: List[str]) -> int:
    """CLI: derive over the live repo and print the report (exit 1 on fail)."""
    here = Path(__file__).resolve()
    repo_root = here.parents[4]  # lib/registry/x.py -> lib -> maos-mcp-hub -> mcp-tools -> ROOT
    as_of = "1970-01-01"
    today = None
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--repo-root" and args:
            repo_root = Path(args.pop(0)).resolve()
        elif a == "--as-of" and args:
            as_of = args.pop(0)
        elif a == "--today" and args:
            today = args.pop(0)
    if not (repo_root / "skills").is_dir():  # empirical root check (Qodo lesson)
        print(json.dumps({"verdict": "fail", "error": f"not a repo root: {repo_root}"}))
        return 1
    reg = HubRegistry.derive(repo_root, as_of=as_of)
    report = reg.report(today=today)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["verdict"] == "pass" else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(_main(sys.argv[1:]))
