---
title: "MAOS Agora — Technical Deep-Dive"
audience: engineer / architect
date: "2026-06-29"
source: distilled faithfully from research/agentic-moe-2026/ (digest §B–§D · ADR-006/007 · 02-ntree-moe · 03-orchestrator-hub · goal-loop-closure · the seam code in lib/gateway/). Every claim traces to a source; numbers are dated order-of-magnitude unless tied to a test.
---

# MAOS Agora — technical deep-dive

## 1. The frame: the agentic ecosystem is a Mixture-of-Experts (MoE)
The open-source agentic-tooling ecosystem (Claude Code & cross-harness) is **not a homogeneous market** — it's a **stack of functional layers grouped by ROLE**, best routed like an MoE: no single tool "wins"; value comes from **composing** them and from a **hub = gating network** that selects the right expert per task. Guiding principle: **substrate-first**.

### The layers (L0–L9)
- **Always-on substrates** (wrap every route): **L0 Guardrails** · **L8 Memory** · **L9 Observability**.
- **Knowledge:** **L4 Codebase-Intelligence** · **L5 PKM**.
- **Build pipeline (ordered):** **L1 Spec → L2 Workflow → L6 Design → L7 Slides**.
- **Amplifier:** **L3 Orchestration** (MoE engines) — optional, HITL-gated on irreversibles.

### Routing spine (N-Tree)
`substrate-check (L0+L8+L9)` → `knowledge (L4/L5)` → `L1 spec` → `L2 workflow` → `L6 design` → `L7 slides`; **L3 wraps L1–L7 only when justified.**

## 2. The Hub (gating network) — design
`intent-classification` → `CTS multi-criteria scoring` (ISO × Eisenhower × risk × scope × methodology × reversibility; **hard-filters first**; 4-dim rubric: Expert-fit / Authorization / Task-frame / Risk-frame) → `ISO / Tool-Attention gating` (pool of ≤60-token summaries per tool; promote the full schema only for top-k — this is what kills the **10k–60k-tokens/turn "MCP/Tools tax"**) → `model-router` (cheapest capable model + budgets) → `tool-registry` (YAML).
- **Key insight:** MAOS already owned ~70% of this (CTS≈`action-priority`, registry≈`maos-mcp-hub`, model-router≈`slm-routing`, guardrails≈`pii-masking`+hooks, observability≈`sentinel`). We didn't rebuild — we added the missing gate.

## 3. The gating-seam (what was actually built — Loop 2, merged #180)
The critical-analysis said the hub's "teeth" (gating in the router) **didn't exist yet** — the biggest build-risk. They exist now, test-proven:
- **`lib/gateway/policy.py`** — `PolicyResolver` + `PolicyDecision`. In-memory, dumb-on-purpose: the active profile comes from *outside*; it does not discover or reload.
- **`lib/gateway/conflicts.yaml`** — **16 curated structural incompatibility edges** from the N-Tree analysis (ECC×base, spec-kit×openspec, gstack×ECC-browser-mcp, mem0×letta×cognee, …).
- **`lib/gateway/router.py`** (+33/−1) — **one** pre-dispatch check, *after* the `operation` validation; on deny → a structured error in the **existing `_agent_feedback` envelope**. Discovery levels 0–2 untouched.
- **`tests/test_gateway_policy.py`** — 16 tests: passthrough/0-regression + gating (handler-not-invoked, proven by a call-spy) + conflicts-load.

### The safety property (why it's risk-free to merge)
**`policy=None` ⇒ pure passthrough ⇒ zero behaviour change** across all 96 gateway actions. The gate only activates once someone *sets a profile*. This is structural 0-regression, not just tested:
- Full suite (verified Mac-side, Python 3.12 venv): **192 pass / 3 fail** — the 3 fails are a pre-existing action-count drift (`104` expected vs `105`), **reproduced identically on pristine `origin/main`** with no seam present. The **40 seam-touching tests pass clean.**

## 4. Top incompatibilities the seam encodes (don't stack these)
1. **Instruction-layer:** `superpowers × gstack × ECC` (+ BASE at L0) fight over `CLAUDE.md`/`.claude/`; `gstack` bans the browser-MCP that `ECC` bundles; duplicate hooks → **pick ONE conductor**.
2. **Exclusive specs:** `spec-kit × OpenSpec` (incompatible artifact models).
3. **Memory backends:** `letta` (runtime lock-in) × `mem0`/`cognee` (pluggable).
4. `open-design × open-codesign` (same slot); heavy orchestration in a low-risk context = overkill.
→ This is the **single-conductor invariant** (ADR-006 Decision §4), now active guidance.

## 5. The decision score (6-factor, Loop 4)
- **agent-doable 0.79 · full-goal 0.71** (binding factor = `certainty`, HARD-capped).
- Verdict: **DEFER-at-n\*** — what remains is **human action** (ratify, run the demand probe), **not cognition**. Loop trail: `1 ESCALATE(0.75) → 2 BUILD(0.87) → 3 DEMAND(bifurcated) → 4 v3-canonical`.

## 6. Governance (how it shipped)
- **[C04]** worktree-always (the v1 landing script was corrected after a 2026-06-28 lock incident).
- **[C07]** explicit stage (never `git add -A`); gitleaks + `validate-plugin.sh` + the test suite green before commit; Conventional Commits + Co-Author; **merge = HITL** (squash, `--delete-branch`); ADR-004 GitHub Flow.

## 7. What was rejected / deferred (anti-theater)
- ❌ **`gsd-build/get-shit-done`** — `$GSD` token rug-pull (~US$500K, founder deleted accounts ~2026-04, npm abandoned = live vector). Migrate to `open-gsd/gsd-core`. The Hub must reproduce this veto.
- ❌ **`MemPalace`** — *secondary* allegations of star-buying + benchmark leakage; memory default moved to `mem0`.
- ⏸️ **ADR-007 (the curated-community platform)** — demoted to **Draft (frozen)**: a promise to be *earned* (real demand + a first integration proving the gate), not declared with <1K stars and N=1 demand.
- ⏸️ Heavy hub machinery (LiteLLM router, OTel export) deferred until ≥3 incidents justify it (anti-over-engineering, per the os3pd manifesto).

---
*Caveats (honest): star counts are dated order-of-magnitude (2026-06-27), divergent across sources (`superpowers` 147K vs 236K same day) — `[UNVERIFIED]`, not precision. Phase-3 hub weights/thresholds are proposals to calibrate. Code (`*.py`/`*.yaml`) is cited as evidence, not re-pasted here.*
