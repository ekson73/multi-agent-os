# Adoption verdicts — intake batch (26 INCLUDED + BRIDGE + EXCLUDED reproductions)

> **Produced by**: the `agentic-tool-intake` discipline in batch · WAVE-3 WT10 (backlog P3, stories
> S10/S9) · 2026-07-01.
> **Machine-readable SSOT**: `mcp-tools/maos-mcp-hub/evals/fixtures/intake_verdicts.yaml` — THIS
> document is the human mirror; when they disagree, the fixture wins (the eval only checks the fixture).
> **Acceptance (DoD gate — no prose-judged THEN)**: `cd mcp-tools/maos-mcp-hub && python -m
> evals.intake_batch_eval` → logged `verdict: pass` over checks A1..A7, plus
> `cd mcp-tools/maos-mcp-hub && python -m pytest tests/test_intake_batch.py` (16 tests).
> **Research base (DRY — cited, not re-run)**: `research/agentic-moe-2026/` phases 0–4 (observed
> 2026-06-27; star counts are order-of-magnitude, not precision) + the WAVE-1/2 adoption precedents
> (`docs/adoption/mem0-2026-07-01.md`, `docs/adoption/codegraph-2026-06-18.md`).
> **Revisit (TTL)**: 2026-09-27 — re-validate every `[UNVERIFIED]`/`[sec]` flag (final-report §5).

## What this batch is

ADR-006 frames the agentic-moe-2026 landscape as MAOS's **market study + intake backlog**. This
batch closes backlog item **P3**: every one of the 26 INCLUDED experts (plus the graphiti BRIDGE)
receives an explicit `agentic-tool-intake` disposition, and the supply-chain gate's two named
EXCLUDED verdicts are **reproduced as data** (spec: `openspec/specs/maos-hub/spec.md` →
"Supply-chain gate"). Verdicts derive from the existing research corpus — no re-research was run.

## Verdict summary (32 entries)

| Verdict | n | Entries |
|---|---|---|
| **INSTALL** | 9 | graphify · understand-anything · obsidian-skills · spec-kit · openspec · open-codesign · impeccable · slidev · frontend-slides |
| **ADAPT** | 4 | karpathy-claude-md (patterns-only, HF2) · base (patterns-only, C1+HF2) · mem0 (adapter-first — WT5 #199) · gsd-core (safe fork ONLY, SHA-pinned) |
| **ABSORB** | 3 | ECC (AgentShield → WT2 #189) · ruflo (trust_score → CTS WT4 #198) · bmad-method (phase-gating → hub intent classifier) |
| **SUB-AGENT** | 3 | superpowers · gstack (RULE-011 fires on it live) · open-design (sandboxed, via opendesign-concierge) |
| **ABANDON** | 4 | letta (runtime lock-in) · paul (redundant) · carl (second hook-engine) · seed (license=null, HF2) |
| **DEFER** | 4 | cognee (graph workload) · langfuse (WT6 deferred; ee/ NOASSERTION) · cli-anything (no workload) · graphiti (BRIDGE — temporal workload) |
| **EXCLUDED** | 5 | gsd-build/get-shit-done ($GSD rug-pull → `open-gsd/gsd-core`) · mempalace (star-manip/unproven claims → `mem0ai/mem0`) · forrestchang/andrej-karpathy-skills (404/mis-attrib) · klaviyo/graphiti_mcp (fork) · goabstract/Awesome-Design-Tools (stale/non-agentic) |

## The invariants the eval enforces (falsifiable, not prose)

| Check | Invariant |
|---|---|
| A1 | exactly 26 INCLUDED; every verdict in the intake vocabulary |
| A2 | the two named EXCLUDED reproductions exist, `blocked: true`, with evidence + safe successor |
| A3 | `conductor_class` mirrors `plugin-scripts/governance/lib/conductors.txt` (RULE-011 SSOT) and **no conductor gets a plain INSTALL** (C1 single-conductor) |
| A4 | HF2: license none/null/NOASSERTION never yields INSTALL; adoption-shaped verdicts on dirty licenses carry explicit conditions |
| A5 | every EXCLUDED entry: blocked + evidence + rationale |
| A6 | every evidence ref resolves to a real repo file (no invented refs) |
| A7 | unique ids; schema-complete entries |

## Notable dispositions (why, in one line each)

- **ECC / ruflo / bmad-method = ABSORB, empirically already done**: AgentShield's egress/secret
  model became RULE-012 (WT2), ruflo's `trust_score` is imported verbatim in `lib/gateway/cts.py`
  (WT4), and BMAD's phase-gating is the hub's cheap intent classifier
  (`protocols/moe-hub-architecture.md` (a)). The batch records these as data.
- **gstack = SUB-AGENT with live evidence**: the RULE-011 scan emits `decision=taint scope=user`
  on real sessions today — the conductor class is enforced at runtime, and the verdict encodes it.
- **letta = ABANDON** despite Apache-2.0: categorially a rival runtime ("must use Letta"), not a
  pluggable layer — the L8 slot was resolved to mem0 (WT5).
- **seed = ABANDON on HF2 alone**: `license=null` on the API with only a prose MIT claim is the
  Kahler cluster's highest legal exposure; the benefit does not offset it.
- **mempalace**: fraud is NOT asserted as fact — the allegations are unproven; by the gate it
  stays out until an independent audit (evidence + successor recorded).

## Boundaries (honest scope)

- These are **adoption dispositions for MAOS's own stack**, not landscape membership: ABANDONED
  experts remain documented in the research landscape for routing literacy.
- Verdicts inherit the research run's epistemics (dated 2026-06-27; `[sec]`/`[UNVERIFIED]` star
  flags preserved in the fixture `flags`). The TTL (2026-09-27) exists precisely to re-validate.
- INSTALL verdicts remain **confirm-gated at install time** (intake SKILL invariant: a clean
  INSTALL still requires operator GO; nothing here auto-installs anything).

---

*Signed: Claude-Dev-S10-intake-batch (WT10 / WAVE 3) · 2026-07-01T00:00:00-03:00 · branch
`chore/S10-ath-intake-batch` · fixture schema `intake-batch/1.0.0` · eval schema
`intake-batch-eval/1.0.0`.*
