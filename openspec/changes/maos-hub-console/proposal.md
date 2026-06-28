# Change: maos-hub-console — operator control-plane for the MAOS Hub

> OpenSpec change proposal (lightweight). Governed by ADR-006 (MAOS Hub) + ADR-007 (integration
> platform). Contract: `openspec/specs/maos-hub-registry/spec.md` + `openspec/specs/maos-hub/spec.md`.
> Identifiers en-US.

## Why

MAOS exposes ~59 skills + ~49 agents + external plugins across L0–L9, with real incompatibilities
(single-conductor) and a curated community catalog (ADR-007). The operator is lost: *what is good,
good-for-what, when, which conflicts with which*. There is no operator-facing control-plane. This
change adds it — **not** a bespoke GUI subsystem, but the human projection of the Hub's gating data,
where the operator's **profile is a first-class INPUT to the gating** (teeth in our hub layer).

## What Changes

Add a single entry-point (extending the `maos-concierge` family) with **modes**, not a proliferation
of commands. Flags `--help` and `--safe-mode`.

- **Views/modes** (all project the registry, all conflict-checked, all HITL-confirmed):
  `preset` (curated, = the Phase-2 composition recipes) · `category` (by L0–L9 role) · `use-case`
  (greenfield-MVP · brownfield-onboarding · inventory/audit · documentation · continuity/handoff ·
  integration/APIs · database/migration · prod-deploy · long-session+memory) · **`context-aware`**
  (ranked by detected project signals — IN v1, deterministic + reasoning shown) · **`prose-intent`**
  (operator types the need → bounded clarifying interview ≤2–3 Qs → proposes a custom profile draft) ·
  **`safe-mode`** (substrates + security floor + single-conductor only; all optional/third-party OFF;
  HITL on everything).
- **Profile = gating input.** The chosen/enabled set is persisted (the profile SSOT) and the Hub
  enforces it (routes/exposes only enabled + compatible tools). Enforcement teeth live in our layer,
  not in a harness per-skill toggle (which is not natively enforceable — do not promise it).
- **Incompatibility-aware selection.** Reads `conflicts_with` + the single-conductor invariant;
  refuses co-residence, offers "pick one" / isolated `sub-agent`.
- **Visual = first-class adapter** (ASCII for any harness; optional HTML artifact for Cowork/Claude) —
  over **portable logic** (registry/profile/gating stay vendor-neutral / AAIF).

## The 4 console guardrails (fixed)

1. No harness-impossible magic (don't promise per-skill runtime disable the harness can't enforce).
2. No vendor-lock of the **logic** (registry/profile/gating portable; visual is the only platform-bound layer).
3. No rotting stateful GUI framework (presentation is a thin adapter, not a maintained app).
4. No opaque/non-auditable dynamic (the context-aware ranking + the prose→profile mapping show their reasoning).

## Impact

- Reuses `maos-concierge` (modes/dashboard), `agentic-tool-pipeline`/`intake` (intent), the registry,
  the Phase-2 recipes + incompatibility graph, `work-compass` (context signals). DRY.
- New: the **profile SSOT** + the wiring of the Hub gating to honor it.
- Sequenced AFTER the WAVE-0 safety foundation (ADR-006) and ON the registry (this change depends on
  `openspec/specs/maos-hub-registry/spec.md`).
