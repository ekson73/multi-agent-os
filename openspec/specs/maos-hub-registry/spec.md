# maos-hub-registry — Capability Spec (lightweight, OpenSpec-style)

> The SSOT both the **console** (ADR-006/this change) and the **integrator** (ADR-007) read/write.
> Source of truth = `docs/adrs/ADR-006` + `docs/adrs/ADR-007` + `protocols/moe-hub-architecture.md`.
> Identifiers en-US.

## Purpose

Hold the vetted, machine-readable knowledge about every MAOS-routable tool (own + integrated): what
it is, what it's good for, when/which-phase to use it, what it conflicts with, its activation tier,
license/provenance, freshness, and rollback — so the console can project it, the gating can enforce
it, and the integrator can grow it.

## Tool record (schema)

Each record SHALL carry: `id` · `owner/repo` · `layer (L0–L9)` · `role (substrate|knowledge|pipeline|
amplifier)` · `category` · `harness_coverage[]` · `requires[]` · `conflicts_with[]` · `guardrails` ·
`impact` · `recipes[]` (use-cases) · **`activation`** ∈ {always-on, default-on-for-context, opt-in,
excluded} · `license_spdx` · `provenance` (source + pin + SBOM ref) · `ttl` (+ last_validated) ·
`rollback` (revert/uninstall recipe) · `security_status`.

## Requirements

### Requirement: Records are derived, not hand-maintained
The registry SHALL auto-derive from skill/agent frontmatter + the promoted Phase-2 N-Tree, and SHALL
NOT require hand-maintained duplication (avoids drift; mirrors `SchemaRegistry` auto-gen).

#### Scenario: a new skill ships
- WHEN a skill is added with valid frontmatter
- THEN its registry record is (re)generated (id/layer/role/category derived; conflicts/recipes from the N-Tree).

### Requirement: Activation gating
The registry SHALL classify each tool's `activation`, and `always-on` SHALL be reachable by a
third-party tool ONLY after passing license-clean + conflict-free + low-attack-surface gates.

#### Scenario: third-party proposed as always-on
- WHEN a third-party tool requests `always-on` AND has `license_spdx=NONE` OR a `conflicts_with` edge
- THEN the registry refuses `always-on` and records it as `opt-in`/`default-on-for-context` with the reason.

### Requirement: Incompatibility is queryable
The `conflicts_with` graph SHALL round-trip the Phase-2 incompatibilities and SHALL be the source the
console + gating consult to enforce single-conductor.

#### Scenario: two conductors selected
- WHEN the operator selects two tools with a `conflicts_with` edge (e.g. ECC × superpowers)
- THEN the console blocks co-residence and offers pick-one / isolated sub-agent (logged).

### Requirement: Real license + provenance
Every record SHALL carry an SPDX `license_spdx` (classified, not assumed) and `provenance`; integrated
third-party records SHALL be referenced in `THIRD_PARTY_NOTICES`/SBOM.

#### Scenario: AGPL tool integrated
- WHEN a tool classified `AGPL-3.0` is integrated
- THEN `license_spdx=AGPL-3.0`, compatibility is flagged, and `THIRD_PARTY_NOTICES` is updated (never "assume MIT").

### Requirement: Freshness + rollback
Every record SHALL carry a `ttl` + `last_validated` and a `rollback` recipe; stale/abandoned/compromised
entries SHALL be auto-flagged for ejection.

#### Scenario: upstream goes stale/abandoned
- WHEN `now - last_validated > ttl` OR the upstream is flagged abandoned/compromised
- THEN the record is marked `eject-candidate` and surfaced to HITL (the GSD/MemPalace lesson).

## Deferred (as-designed, not yet built)
- The integrator auto-discovery feed (trending → intake) — WAVE 6 / ADR-007.
- Signed-release + SBOM generation for MAOS-as-distributor — WAVE 6 T10.
- HTML console artifact — optional, after the ASCII view.
