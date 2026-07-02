---
name: deliberate-coding
version: "1.0.0"
description: |
  MAOS-native deliberation-before-coding guardrail principles (L0 substrate,
  content-not-runtime). Use when an agent is about to write/modify code and needs the
  house discipline for HOW to approach the change: think-before-coding (state the problem,
  the constraint set, and at least one rejected alternative BEFORE the first edit),
  simplicity-first (the least mechanism that fully achieves the outcome — no speculative
  abstraction), surgical-changes (smallest reviewable diff; never opportunistic refactors
  inside a fix), and goal-driven execution (every edit traces to the stated goal; drift =
  stop and re-anchor). Apply at task start, before large diffs, during PDCA fix rounds,
  and whenever a review flags over-engineering or scope creep.
license: MIT
provenance: |
  MAOS-native articulation (T6 / WAVE 5, ADR-006). Principle FAMILY inspired by
  observations popularized by Andrej Karpathy; the four-principle framing was
  popularized by the community repo multica-ai/andrej-karpathy-skills (registry
  intake id `karpathy-claude-md`, verdict ADAPT, conditions: patterns-only +
  no-redistribution-until-license-clarified — HF2: upstream README claims MIT but
  the repo ships NO LICENSE file, so its TEXT is all-rights-reserved). This
  document therefore contains NO upstream text — patterns internalized, prose
  original to MAOS (MIT).
evals:
  should_trigger:
    - "Before I start coding this feature, what discipline should I follow?"
    - "This fix is ballooning into a refactor — what does MAOS say?"
    - "Review my plan for over-engineering before I implement"
  should_not_trigger:
    - "Run the code review itself (that is code-reviewer / persona-pipeline)"
    - "Decide WHICH tool to route to (that is maos-concierge / agent-select)"
---

# Skill: deliberate-coding — deliberation-before-coding house principles (L0)

> **Credit (inspiration, not source-text)**: the principle family below is inspired by
> coding-with-LLM observations popularized by **Andrej Karpathy**, and by the framing that the
> community repo **multica-ai/andrej-karpathy-skills** made ubiquitous (~180k★). Per that
> intake's ADAPT verdict (`karpathy-claude-md`: *patterns-only, no-redistribution* — the
> upstream ships no LICENSE file), **no upstream text appears here**: this is MAOS's own
> articulation, internalized as a first-party, license-clean (MIT) substrate.

## Why this exists (registry position)

The MoE hub (ADR-006) classifies the upstream repo `opt-in` (license gate HF2 — not
license-clean), yet the *principles* are exactly the L0 guardrail content every recipe stack
floors on. The resolution is structural: **internalize the patterns natively** (this skill —
first-party, `default-on-for-context`, MIT) and keep the upstream record available at its
capped tier for whoever opts in. Content, not runtime: this skill defines *how to think about
a change*; it executes nothing.

## The four principles (MAOS articulation)

### 1. Think-Before-Coding
Before the first edit, produce — in the task record, not in your head — (a) the problem in one
sentence, (b) the constraint set (contracts, invariants, protocols in force), and (c) at least
one considered-and-rejected alternative with the reason. If you cannot name a rejected
alternative, you have not yet explored the solution space; do not start typing.

### 2. Simplicity-First
Choose the least mechanism that FULLY achieves the outcome. No speculative abstraction, no
"while I'm here" generality, no framework where a function does. Simplicity is measured at the
reader: if the reviewer needs your conversation context to understand the design, it is not
simple yet. (Simple ≠ simplistic: the mechanism must still fully meet the stated goal.)

### 3. Surgical-Changes
The diff is the unit of trust. Keep it the smallest reviewable change that achieves the goal:
no opportunistic refactors inside a fix, no drive-by renames, no formatting churn. If a
neighboring improvement is genuinely worth doing, it is worth its OWN branch/PR — file it,
don't fold it.

### 4. Goal-Driven
Every edit must trace to the stated goal. When you notice work that doesn't (a test rewritten
"for style", an abstraction added "for later"), STOP and re-anchor: either the goal changed —
then restate it explicitly — or the work is drift — then drop it. Done = the goal's acceptance
holds, not "the code looks finished".

## When invoked (protocol hooks)

| Moment | Application |
|---|---|
| Task start | Principle 1 gate: problem + constraints + rejected alternative on record |
| Before a large diff | Principles 2+3: can the same outcome ship as a smaller/simpler change? |
| PDCA fix rounds (pr-review) | Principle 3: fix-commits address findings only — no scope creep |
| Review flags over-engineering | Principles 2+4: cut to the least sufficient mechanism, re-anchor to goal |

## Boundaries (what this skill is NOT)

- NOT a runtime/hook — content-only substrate (L0); it changes how an agent reasons, not what
  executes. Enforcement lives in the existing protocols (Anti-Conflict, Sentinel, pr-review).
- NOT a replacement for the upstream repo — that record stays in the registry at its derived
  tier for opt-in users; this skill is the license-clean native floor.
- NOT a review tool — route reviews to `code-reviewer` / `persona-pipeline`; this skill is the
  discipline the *author* applies before and during the change.

## Cross-refs

`karpathy-claude-md` (registry intake — upstream record, ADAPT/patterns-only) ·
ADR-006 (MoE hub) · `openspec/specs/maos-hub-registry/spec.md` (activation gating) ·
`research/agentic-moe-2026/20260627-01a-substrates.md` (landscape analysis) ·
`skills/convergence-engine` (the diff-trust discipline PDCA rides on)

## Changelog
- 2026-07-02 — v1.0.0 — Bootstrap (T6 / WAVE 5, ADR-006): native internalization of the
  deliberation-before-coding principle family (patterns-only per the `karpathy-claude-md`
  ADAPT verdict; zero upstream text; credit retained). First-party L0 substrate — derives
  into the hub registry as `default-on-for-context`, MIT.
