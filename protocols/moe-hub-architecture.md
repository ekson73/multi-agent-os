# MAOS Hub — MoE Gating-Network Architecture (Protocol)

> **Version**: 1.0.0 (2026-06-27) · **Status**: Proposed (HITL-ratify via PR)
> **Lineage**: realizes `research/agentic-moe-2026/` Phase 3 (ATH) as a NATIVE MAOS subsystem;
> declared evolution of `mcp-tools/maos-mcp-hub`. Governed by ADR-006.
> **DRY**: reuses `action-priority` (CTS), `rbad`/`forge` (expert-profile), `slm-routing`
> (model-router), `pii-masking` (security), `sentinel` (observability), `agentic-tool-lifecycle`
> (DRY adoption). Reimplements none of them.

## Purpose

The **MAOS Hub** is MAOS's gating network: it routes a human ⇄ dynamically-selected expert(s) on
top of always-on substrates (L0 guardrails · L8 memory · L9 observability). It is the
**generalization of `maos-mcp-hub`** (today Atlassian-scoped, 6 gateways, 4-level progressive
discovery) into a universal MoE router — NOT a new product. Each MAOS agent (RBAD atomic role) and
each adopted external tool is an **expert**; the Hub is the **router/gating network**.

## The MoE layering principle (substrate-first)

```
ALWAYS-ON SUBSTRATES  : L0 Guardrails · L8 Memory · L9 Observability   (envelope every route)
KNOWLEDGE             : L4 Codebase-Intel · L5 PKM
BUILD PIPELINE (ord.) : L1 Spec → L2 Workflow → L6 Design → L7 Slides
AMPLIFIER             : L3 Orchestration (MAOS orchestrator; reuse ruflo/BMAD patterns, never stack)
```

## Native realization of ATH artifacts (a)–(m)

| ATH artifact | MAOS owner (native) | Status | Evolution target |
|---|---|---|---|
| (a) layered pipeline | orchestrator + `delegation/` + maos-mcp-hub router | PARTIAL | generalize router beyond Atlassian |
| (b) ISO / Tool-Attention | maos-mcp-hub 4-level progressive discovery + SchemaRegistry; `token-budget-gate` | PARTIAL | universal ISO (≤60 tok/tool summary pool, top-k schema) |
| (c) CTS scoring | `protocols/action-priority` (Eisenhower+deps) + `rbad` (4-dim) + `agent-select` | PARTIAL | one weighted scorer, hard-filters-first |
| (d) tool-registry | SchemaRegistry + `agentic-tool-lifecycle` frontmatter | PARTIAL | YAML SSOT per tool (layer/role/summary/risk/auth/security) |
| (e) memory substrate | `memory-curator` · `decision-capture` · `agentic-session-harness` · postflight seeds | GAP | adopt mem0 (default) + graphiti (temporal) via `intake` |
| (f) observability | `sentinel/` (traces+10 rules+health) + `statusmap/` | PARTIAL | OTel exporter in `trace_writer`; Langfuse sink optional |
| (g) model-router | `skills/slm-routing` | PARTIAL | LiteLLM gateway + per-category budgets |
| (h) guardrail/HITL | `hooks/hooks.json` (worktree/edit/token gates) + convergence-engine + COWORK-AUTONOMY-POLICY | BUILT/PARTIAL | autonomy tiers wired to risk |
| (i) security | `skills/pii-masking` + governance hooks + os3pd | PARTIAL/GAP | AgentShield (cascade-resolved **HYBRID**): runtime hook (egress-allowlist + secret-scan over tool-I/O & **model_output**) on hooked harness + advisory cross-harness + **BLOCKING CI floor** (gitleaks/trivy) |
| (j) recipes | `enhance-pipeline` · `quiesce` · `auto-pilot` · preflight/postflight | BUILT | bake substrate-first presets into routing |
| (k) evaluation | `agentic-tool-evaluator` + `rule-quality-tests` + `tests/` | BUILT/GAP | add hub-ROUTING eval (6 task families × risk) |
| (l) MCP ref impl | `maos-mcp-hub` (hub.py + gateways) | BUILT | the living reference |
| (m) pragmatism filter | os3pd-manifesto + rbad Goldilocks | BUILT | keep anti-over-engineering culture |

## Invariants

1. **Single-conductor (C1).** MAOS is the only always-on L0/L2/L3 conductor. Competing managers
   (ECC · superpowers · gstack · BASE · ruflo · BMAD) are NEVER co-resident; they are routed in
   isolation (`agentic-tool-intake` → `adapt`/`sub-agent`/`abandon`), patterns reused (DRY), runtimes
   not stacked. Rationale: the documented instruction-layer collision (duplicate hooks, CLAUDE.md
   contention, gstack-bans-the-browser-MCP-ECC-bundles). **Enforcement (cascade-resolved HYBRID, autonomy 0.721):** runtime `SessionStart` conductor-scan (taint/refuse, logged `RULE-011`) on hook-capable harnesses + advisory `agentic-tool-intake` rule cross-harness + a BLOCKING CI floor; residual (instruction-injection conductors on hookless harnesses) is narrowed, not closed.
2. **Substrate-first.** No expert route executes before L0 (guardrails) + L8 (memory) + L9
   (observability) are active.
3. **Supply-chain gate.** `intake` MUST reproduce the EXCLUDED verdicts (GSD $GSD rug-pull;
   MemPalace star-manip/benchmark) and veto rug-pull/star-manipulation/abandonment classes.
4. **HITL on irreversible / risk=HIGH.** Guardrails always fire first; warn → correct → block.

## Mental simulation — a route through the Hub (brownfield refactor, Q2, high-impact)

```
operator: "refatore o módulo de auth deste repo legado sem quebrar a API pública"
 1. L0 guardrails active (hooks); L8 memory recalls prior decisions; L9 starts a trace span.
 2. CTS classify: Eisenhower=Q2, risk=HIGH (irreversible OR high-blast-radius; concrete predicate TBD per spec), scope=brownfield → hard-filters:
    open-source? auth? env-ready? risk-allowed? → survivors scored.
 3. ISO gate: promote full schema ONLY for top-k experts: graphify(L4) → OpenSpec(L1) → ECC-pattern(L2).
 4. Route (substrate-first): graphify builds code graph → OpenSpec writes proposal/spec/tasks →
    [HITL gate: approve spec] → execute via the MAOS workflow (worktree, tests) under AgentShield.
 5. L9 traces every hop; evals feed warn→correct→cure; L8 consolidates the decision (Learning-Loop).
```

## Thesis tests (red-team / mental tests)

- **Two L2 managers co-installed?** → Invariant 1 refuses; `intake` routes the second as sub-agent
  in an isolated worktree. *(Pass.)*
- **Top-1 tool fails mid-route?** → same-category fallback before crossing categories (OpenSpec→Spec
  Kit; graphify→Understand-Anything), traced + HITL if risk rises. *(Pass.)*
- **Memory backend down (mem0)?** → degrade to file/seed memory (current MAOS behavior); never block,
  never fabricate. *(Pass — graceful.)*
- **Untrusted tool output triggers a destructive tool?** → tainting (trusted/untrusted/derived) +
  HITL gate blocks promotion without reclassification. *(Pass.)*
- **MCP-tax returns with +N experts?** → universal ISO gating caps schema tokens (≤60/tool summary,
  top-k). *(Pass once P1-b lands; today PARTIAL.)*

## References
- Architecture & landscape: `research/agentic-moe-2026/` (00..03 + final-report + OODA-RECON).
- As-designed contract: `openspec/specs/maos-hub/spec.md`. Roadmap: the implementation plan + ADR-006.
