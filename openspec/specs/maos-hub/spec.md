# maos-hub — Capability Spec (lightweight, OpenSpec-style)

> As-designed behavioral contract of the **MAOS Hub** (MoE gating network). Lightweight stub — NOT
> full SpecDD ceremony. Source of truth = `protocols/moe-hub-architecture.md` + `docs/adrs/ADR-006-ath-moe-hub-adoption.md`
> + `research/agentic-moe-2026/`. Realizes the ATH (Phase 3) as a native MAOS subsystem; evolution
> of `mcp-tools/maos-mcp-hub`.

## Purpose

Route a human ⇄ dynamically-selected expert(s) over always-on substrates (L0 guardrails · L8 memory
· L9 observability), exposing only the few tools that matter per turn, scoring candidates by a
multi-criteria rubric, gating irreversible/high-risk actions behind HITL, and refusing co-resident
competing conductors — generalizing `maos-mcp-hub` from Atlassian-only to a universal gating network.

## Requirements

### Requirement: Substrate-first activation
The Hub SHALL ensure L0 (guardrails) + L8 (memory) + L9 (observability) are active before routing
any expert, and SHALL NOT execute an expert route while any substrate is uninitialized.

#### Scenario: memory backend unavailable
- WHEN the L8 backend (default mem0) is unreachable
- THEN the Hub degrades to file/seed memory, continues (never blocks, never fabricates), and records
  the degradation in the L9 trace.

### Requirement: ISO tool-gating (MCP-tax control)
The Hub SHALL keep a permanent summary pool (≤60 tokens/tool) and SHALL promote a full tool schema
only for the top-k gated candidates of a turn.

#### Scenario: large tool inventory
- WHEN more tools are connected than fit a turn's budget
- THEN only top-k full schemas are loaded; the rest stay as ≤60-token summaries (per-turn schema
  tokens bounded, not 10k–60k).

### Requirement: CTS multi-criteria scoring (hard-filters-first)
The Hub SHALL apply hard filters (open-source/policy, auth, environment, data-class, risk-class)
BEFORE a weighted score over ISO × Eisenhower × risk × scope × methodology × reversibility (the
4-dim rubric Expert-fit/Authorization/Task-frame/Risk-frame from `rbad` + `action-priority`).

#### Scenario: a candidate fails a hard filter
- WHEN a tool lacks required authorization OR violates policy
- THEN it is eliminated before scoring (never surfaced as a top-k candidate), with the reason traced.

### Requirement: Single-conductor invariant
The Hub SHALL refuse to co-activate a second always-on L0/L2/L3 instruction-layer/orchestration
manager (e.g. ECC, superpowers, gstack, BASE, ruflo, BMAD) and SHALL route such an expert in
isolation via `agentic-tool-intake` instead.

#### Scenario: operator tries to stack a competing manager
- WHEN a competing CLAUDE.md/hook manager is requested as a resident layer
- THEN the Hub declines co-residence and offers an isolated `sub-agent`/`adapt` route (patterns
  reused, runtime not stacked), citing the instruction-layer collision.

### Requirement: Supply-chain gate
The Hub SHALL run candidate tools through the supply-chain veto and SHALL exclude rug-pull /
star-manipulation / abandonment classes, reproducing the EXCLUDED verdicts for `gsd-build/get-shit-done`
($GSD) and `MemPalace`.

#### Scenario: an excluded-class tool is proposed
- WHEN a tool matches an EXCLUDED supply-chain signature
- THEN it is blocked from routing and the operator is shown the evidence + a safe successor (e.g.
  `open-gsd/gsd-core`).

### Requirement: HITL on irreversible / high-risk
The Hub SHALL require a human checkpoint before any action classified risk=HIGH or irreversible, and
guardrails (L0) SHALL fire first (warn → correct → block).

#### Scenario: destructive action selected
- WHEN a route would push/merge/deploy/rotate-secrets or otherwise irreversibly mutate state
- THEN the Hub pauses for explicit HITL approval before proceeding.

### Requirement: Every route is traced
The Hub SHALL emit an L9 trace per route (selected/rejected tools, criteria vector, schemas loaded,
approvals, cost/latency) consumable by Sentinel and (when enabled) an OTel sink.

#### Scenario: routing decision audited later
- WHEN an operator asks "why did the Hub choose X?"
- THEN the trace yields the scored candidates, the hard-filter eliminations, and the HITL events.

### Requirement: Same-category fallback
The Hub SHALL prefer a same-category fallback before crossing expert categories when a selected tool
fails or becomes ineligible.

#### Scenario: top-1 spec tool fails
- WHEN OpenSpec is unavailable for a spec task
- THEN the Hub falls back to another L1 spec expert (e.g. Spec Kit) before routing to a non-spec tool.

### Requirement: Safety enforcement is runtime + CI-floor (not advisory-only)
The C1 (single-conductor) and C6 (content-security) controls SHALL be enforced at runtime on hook-capable
harnesses AND backed by a harness-agnostic BLOCKING CI floor; the advisory skill layer is a cross-harness
complement, never the sole control. Every enforcement decision SHALL be logged (no prose-only acceptance).

#### Scenario: co-resident conductor (C1)
- WHEN a competing L0/L2 manager is present at session start (a second `hooks.json`/`CLAUDE.md` manager)
- THEN `SessionStart` emits `RULE-011` (the Sentinel SSOT historically stopped at RULE-010; RULE-011 (implemented WT1/#188) and RULE-012 (implemented WT2) are the sentinel rules added by this proposal — both now live, see `sentinel/detection_rules.md`) `c1_conductor_scan{detected_conductors[...], scope, decision}` with decision ∈ {clean, taint, refuse} (`clean` = no competitor; `taint` = user-global only; `refuse` = co-resident in THIS project). The DoD-gate acceptance fixture below plants a conductor, so it asserts the non-`clean` subset {taint, refuse}.

#### Scenario: secret/exfil over a tool call or model output (C6)
- WHEN a tool input/output OR the model output carries a secret or targets a non-allowlisted egress
- THEN `PreToolUse` emits `RULE-012 c6_egress_check{channel, classification, secret_match, decision}` with
  decision=block when `secret_match≠null` (channel includes `model_output`). *(Implemented WT2 — the
  blocking `PreToolUse` hook `plugin-scripts/governance/agentshield.sh` + pure detector
  `lib/agentshield-scan.sh`; exit 2 + JSON-RPC `-32004` on block. Leak-safe: `secret_match` reports the
  signature KIND, never the value.)*

#### Scenario: secret-at-rest in a PR (harness-agnostic floor)
- WHEN a commit carries a secret regardless of harness
- THEN the (as-designed) BLOCKING CI floor (gitleaks/trivy) emits `ci_floor{tool, sarif_path, verdict}` with verdict=fail and blocks the merge. *(As-designed target: today gitleaks runs and Trivy is advisory/non-required — promoting the floor to merge-blocking is part of this proposal.)*

#### Scenario: falsifiable acceptance (DoD gate for WT1/WT2)
- WHEN the WT1/WT2 acceptance fixture (planted secret + a CLAUDE.md-conductor) is run
- THEN RULE-011.decision ∈ {taint, refuse} AND RULE-012.secret_match≠null & decision=block on channel=model_output
  AND ci_floor.verdict=fail with a resolvable SARIF — else the worktree does NOT close.

## Deferred (as-designed gaps — not yet built)

- ~~Universal ISO tool-gating beyond the Atlassian hub (WT3)~~ *(implemented — `lib/gateway/iso.py::IsoGate`:
  ≤60-tok summary pool under the normative tokenizer `ceil(len/4)` + top-k promotion, `k=5` default with
  budget-derived cap, PolicyResolver hard-filter first; acceptance = `python -m evals.iso_gate_eval` logged
  verdict + golden fixture `evals/fixtures/iso_inventory.yaml`)* · unified CTS scorer (WT4) · L8 memory substrate
  (mem0 default; graphiti temporal DEFERRED until a measured workload) (WT5) · OTel exporter for Sentinel
  (WT6, DEFERRED — C3 severity LOW) · LiteLLM model-router (CUT — `os3pd` defers a runtime gateway until ≥3
  incidents and `slm-routing` is not a runtime router) · tool-registry YAML SSOT via auto-generation (WT8).
