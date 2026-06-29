# ADR-006: Absorb `agentic-moe-2026` (ATH) as MAOS's MoE Hub architecture & evolution chapter

- **Status**: **Accepted** (ratified by operator ekson73, 2026-06-29 — WAVE-0 gating-seam shipped #180)
- **Date**: 2026-06-27
- **Deciders**: Operator (Emilson de Queiroz Moraes / ekson73) + Claude (Cowork), via HITL directive
- **Scope**: This repo (`maos`, Class B). Companion to the existing orchestration/observability/anti-conflict protocols. Sibling evidence: `research/agentic-moe-2026/` (the research chapter) + `research/agentic-moe-2026/20260627-ATH-OODA-RECON.md` (the inventory cross-walk).

## Context

In 2026-06 we ran a multi-phase deep-research study (`agentic-moe-2026`) over the open-source
agentic-tooling ecosystem (Claude Code & cross-harness): Phase 0 canonicalization + supply-chain
gate, Phase 1 per-layer landscape (L0–L9), Phase 2 N-Tree / MoE routing graph, Phase 3 the
**Agentic Tool Hub (ATH)** — a gating-network design. An OODA-RECON of this very repo then showed a
non-obvious truth: **MAOS already implements ~70% of the ATH hub.** Nearly every Phase-3 artifact
(a)–(m) has a living owner in-repo:

| ATH artifact | Existing MAOS owner |
|---|---|
| (c) CTS scoring (Eisenhower) | `protocols/action-priority.md` |
| MoE expert-profile / authorization | `protocols/rbad.md` + `agents/forge.md` |
| (b) ISO / Tool-Attention + (d) registry | `mcp-tools/maos-mcp-hub` (MetaToolRouter, 4-level progressive discovery, SchemaRegistry, `_agent_feedback`) |
| (g) model-router | `skills/slm-routing` |
| (i) security model | `skills/pii-masking` + governance hooks |
| (f) observability | `sentinel/` + `statusmap/` |
| (h) guardrail/HITL | `hooks/hooks.json` (worktree-gate, edit-gate, token-budget-gate) |
| DRY adoption of experts | `skills/agentic-tool-{pipeline,intake,evaluator,trainer}` + `protocols/agentic-tool-lifecycle.md` |
| (l) MCP ref impl | `maos-mcp-hub` itself |
| L1 spec | `openspec/` (MAOS already adopted OpenSpec) |

The operator's directive: **"ATH é MAOS, MAOS é ATH"** — make ATH a native, fundamental part of
MAOS and of its evolution history, OR let the ATH principle be one piece of `agentic-moe-2026`
itself; **validate and decide.**

```bash
# /**
#  * Resolver a relação ATH↔MAOS como ABSORÇÃO EM DOIS NÍVEIS (não consumo externo).
#  * @context OODA-RECON provou cobertura ~70% dos artefatos (a)-(m) por componentes JÁ existentes no MAOS.
#  * @reason DRY/os3pd: não reescrever o que funciona; o ATH é o ESPELHO/ESPEC de evolução do MAOS, não um produto terceiro.
#  * @impact agentic-moe-2026 vira capítulo nativo (ADR+CHANGELOG+MVV); o hub vira "MAOS Hub" (evolução do maos-mcp-hub), specado em OpenSpec.
#  */
```

## Decision

1. **Absorb `agentic-moe-2026` as a native MAOS evolution chapter.** The research series lives in
   `research/agentic-moe-2026/` (in-repo), is recorded here (ADR-006), in `CHANGELOG.md`, and
   becomes part of MAOS's MVV narrative ("the de-facto MoE OS for agent orchestration").

2. **Realize the ATH hub as "MAOS Hub" — the native MoE gating-network subsystem, declared
   evolution of `maos-mcp-hub`.** It is NOT a new product; it is the generalization of the existing
   hub (today Atlassian-scoped) into a universal gating network. Its as-designed behavioral contract
   is specified, dogfooding MAOS's own L1, in `openspec/specs/maos-hub/spec.md`; its architecture is
   documented natively in `protocols/moe-hub-architecture.md`.

3. **Reconcile the operator's "OR".** Within `agentic-moe-2026`, the ATH/hub is **one piece**
   (Phase 3); the landscape (Phases 0–2) is MAOS's **market study + intake backlog**. Therefore
   `ATH ⊂ agentic-moe-2026 ⊂ MAOS-evolution`, and **MAOS Hub = the native realization of ATH.** Both
   operator readings hold; no contradiction.

4. **Single-conductor invariant (conflict C1).** MAOS is an always-on L0+L2+L3 conductor. Competing
   instruction-layer/orchestration managers (ECC, superpowers, gstack, BASE, ruflo, BMAD) MUST NOT
   be co-installed as resident layers; they are routed in isolation via `agentic-tool-intake`
   (`adapt`/`sub-agent`/`abandon`), reusing their *patterns* (DRY), never stacking their runtimes.

5. **Adopt the supply-chain verdicts** surfaced by the study: `gsd-build/get-shit-done` ($GSD
   rug-pull) and `MemPalace` (star-manipulation/benchmark allegations) are EXCLUDED; `intake` MUST
   reproduce these vetoes.

6. **Gap roadmap = MAOS evolution backlog** (specced in OpenSpec, tracked via the Jira prompt):
   universal ISO tool-gating, unified CTS scorer, memory substrate (mem0/graphiti), OTel export for
   Sentinel, LiteLLM-backed model router, AgentShield-grade content security.

## Consequences

- **Positive**: the research stops being a side-study and becomes MAOS's **architecture + evolution
  spec**; the hub gets a named, dogfood-specced identity (MAOS Hub); the single-conductor invariant
  closes the only hard conflict; DRY is preserved (we extend, not rewrite).
- **Positive (positioning)**: MAOS, by the study's own filter (OSS/MIT ✓, non-fork ✓, hub ref-impl
  ✓, supply-chain gate ✓), is an **INCLUDED-candidate (emerging)** L3/hub expert in the very
  landscape it produced — the natural path is "MAOS becomes the community MoE hub of reference."
- **Negative (mitigated)**: one more ADR + a protocol + an OpenSpec spec to maintain — kept as
  *companions* that reference `research/agentic-moe-2026/` rather than duplicating it.
- **Follow-ups (separate PRs, GitHub Flow per ADR-004)**: P0 `single-conductor` rule in
  `agentic-tool-intake`; P0 expand `pii-masking`→AgentShield; then the P1/P2 gap items.
- **MVV touch (proposed)**: add to the Vision — *"MAOS is the open-source MoE gating hub (ATH) for
  agentic software engineering"* — to be applied to `CLAUDE.md` §Organizational Identity in the
  ratifying PR.
- **Ratified 2026-06-29** (operator ekson73, HITL — recorded in the goal-loop session). **WAVE-0, the
  gating-seam, already shipped in the same cycle** (PR #180: `lib/gateway/{policy.py,conflicts.yaml}` +
  `router.py` pre-dispatch check; additive `policy=None` passthrough; 0-regression, 192 pass proven on
  pristine HEAD — see `research/agentic-moe-2026/20260628-goal-loop-closure.md` Loop 2). The
  **single-conductor invariant** (Decision §4) and the **always-on collision rule** (do NOT co-reside
  ECC/superpowers/gstack/BASE — route via `agentic-tool-intake`, never stack runtimes) are now **active
  guidance**, not proposals. **ADR-007 remains Draft (frozen)** — only ADR-006 is ratified. The
  CLAUDE.md Vision/MVV touch above stays a deferred follow-up (bootstrap-SSOT edit; not bundled here).

## References

- Companions: `docs/adrs/ADR-003-version-ssot-float.md`, `docs/adrs/ADR-004-github-flow-branching.md`, `docs/adrs/ADR-005-dogfood-cycle-ledger.md`.
- **Forward: `docs/adrs/ADR-007-curated-community-integration-platform.md`** — the community-integration platform North Star; the operator **console** + the **integrator** are the human/inbound faces of this same MAOS Hub. Vision: `docs/vision/maos-integration-platform.md`; contracts: `openspec/changes/maos-hub-console/` + `openspec/specs/maos-hub-registry/spec.md`.
- The chapter: `research/agentic-moe-2026/` (00..03 + final-report) + `…/20260627-ATH-OODA-RECON.md` (inventory cross-walk) + `…/20260627-HANDOFF-claude-code.md` (hands-on prompt).
- Native realization: `protocols/moe-hub-architecture.md` · `openspec/specs/maos-hub/spec.md`.

## Co-creation review — the MoE experts validated their own incorporation

Per the operator directive ("os experts co-criam o próprio lar"), two **native MAOS personas** reviewed this
incorporation — a recursive self-audit where the framework reviews its own evolution:

- **`maos:governance-auditor` → CLEARED-FOR-PR.** One hard MUST: branch names require the `<id>` segment
  (`AGENTS.md §Branching`) — **applied** in the handoff (`feature/<id>-slug`). Polish: this `## References`
  section (done); add `## Deferred` to the maos-hub spec; the Vision/MVV edit touches `CLAUDE.md` bootstrap
  SSOT → **HITL-escalated**, ratify only in the PR (never a side-change).
- **`maos:persona-pipeline` → GO-WITH-FIXES (autonomy_score 0.35).** Incorporated into the handoff:
  (a) C1 single-conductor + C6 AgentShield move to **runtime enforcement** (PreToolUse/SessionStart hook +
  egress-allowlist/session-tainting), not skill-advisory; (b) **eval-first** — the routing-eval (WT0) runs
  **before** the gap-fill worktrees, to MEASURE the "~70%" claim rather than assume it; (c) anti-over-engineering
  cuts coherent with `protocols/os3pd-manifesto.md` (which defers a runtime gateway until ≥3 incidents):
  **cut WT7 (LiteLLM)**, **defer WT6 (OTel)**, **one memory backend (mem0)**; (d) **DoD-gate** — no worktree
  closes on a prose-judged `THEN` (logged field or golden fixture only).

### Cascade resolution — C1/C6 enforcement topology (autonomy 0.35 → 0.721)
`maos:cascade-resolver` (4/4 consensus) resolved the contested runtime-vs-advisory point as **HYBRID /
defense-in-depth**: runtime-hook on the hooked harness (Claude Code: `SessionStart` conductor-enumerate +
`PreToolUse` egress-allowlist / secret-scan over tool-I/O **and model-output**) + advisory cross-harness
(`agentic-tool-intake` rule + pii-masking-by-default) + a **non-negotiable BLOCKING CI floor**
(gitleaks/trivy), harness-agnostic. Rationale: a **security guardrail ≠ the perf/PII "runtime proxy
gateway"** that `os3pd-manifesto` defers — an invariant fails *silently* and would never accumulate the
"≥3 incidents" trigger, so the YAGNI deferral does not transfer. **Consequence:** the supply-chain CI gate
becomes **blocking** (not advisory). **autonomy_score = 0.721** (MEDIUM-HIGH, below HIGH 0.85) → proceed
hands-on at BOUNDED autonomy; the falsifiable known-bad acceptance test is the HITL checkpoint before the
first unattended run. Residual (logged, not silent): instruction-injection conductors (CLAUDE.md/AGENTS.md
on hookless harnesses) + lazy-late registration — narrowed by the CI floor, not closed. Tracked doc-changes:
RULE-011/RULE-012/ci_floor Requirements added to the maos-hub spec; a 1-line `os3pd-manifesto` "Out of scope"
clarifying the ≥3-incident deferral excludes security guardrails C1/C6; annotate Invariant 1 + row (i) in
`protocols/moe-hub-architecture.md`; flip this ADR's status to Accepted on operator ratification.

### Spec refinements required (tracked — close in the implementing worktrees)
- Define `k` (top-k) + the tokenizer for the "≤60 tokens/tool" bound — WT3.
- Define `risk=HIGH` as a concrete predicate (not "irreversible-ish") — WT4.
- Add a `## Deferred` section to `openspec/specs/maos-hub/spec.md` (PARTIAL/GAP items).
- Add an explicit **data-tainting** requirement (trusted/untrusted/derived) to the spec — WT2.

> The recursion landed: `os3pd-manifesto`, `slm-routing` and `pii-masking` literally cited their **own**
> constraints to re-shape the plan that enables them — the experts co-authored their own habilitation.

---
*ADR-006 · drafted by Claude (Cowork) under operator HITL · reviewed by maos:governance-auditor + maos:persona-pipeline · 2026-06-27 · ratify via PR (squash-merge, human gate).*
