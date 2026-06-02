---
name: convergence-engine
version: "1.0.0"
description: |
  Iterative multi-agent quality-convergence engine: a deterministic harness that
  bounds and verifies probabilistic cognition to lift a result toward (but not past)
  the human-multi-pass quality ceiling, then defers the residue to HITL. Routes one of
  three regimes by verifiability — REFINE (self-improve loop), SELECT (best-of-N /
  debate→converge), DEFER (HITL) — under a non-negotiable master condition
  (verifier > generator, verifier independent) and a closed-form economic stop
  (robustly ≤3–4 rounds). Composes existing primitives; builds no new engine.
  Use when a result must be driven to high quality through bounded iterative review
  rather than a single pass, when multiple proposals must be reconciled, or when an
  autonomy_score must be lifted across the HIGH gate before escalating to a human.
  Triggers: "converge to high quality", "iterate until good enough", "best-of-N",
  "refine this until it passes", "lift the score before asking me", "convergence engine",
  "drive this result to convergence", "engine de convergência".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
---

# Convergence Engine

A thin **deterministic-harness × probabilistic-cognition** kernel. The Convergence Engine does **not** re-implement convergence, critique, scoring, or escalation — it **composes** primitives that already live in this repo, behind a small set of non-negotiable rules that make iterative self-improvement *raise* quality instead of corroding it.

> **Principle (the synthesis)**: best result = **deterministic scaffolding** (scripts · hooks · guard-rails · round-caps — cheap, `f=0`, ~zero-token, amnesia-proof, repeatable) **bounding and verifying** **probabilistic cognition** (judgment — expensive, fallible, where the value is created). *Deterministic skeleton, probabilistic muscle.*

## When to use

- A result must reach high quality via **bounded iterative review**, not one shot (codegen, config, governance docs, analysis).
- Multiple agents (or providers) produced **competing proposals** needing reconciliation → SELECT regime → `converge`.
- An `autonomy_score` sits below the HIGH gate and you want to **lift it honestly** before spending scarce human attention → REFINE regime → `cascade-resolver`.
- A decision needs **diverse-lens breadth** before acting → `perspective-trio`.
- A change needs a **depth verify** (independent review board) → `persona-pipeline`.

## When NOT to use

- A clean, high-confidence single-pass answer → **do not loop** (the self-critique paradox: over-reviewing clean output *degrades* it).
- A purely deterministic check suffices (a test, a lint, a schema) → run the oracle directly; no engine needed.
- The task is unverifiable AND below the floor → go straight to **DEFER (HITL)**.

## The master condition (non-negotiable)

> Iterative convergence raises quality **IFF `verifier_accuracy > generator_accuracy` AND the verifier is independent** (cross-axis diverse — see Diversity below).

Violate it → the **self-critique paradox**: same-model critique on already-clean output *degrades* it (empirical: clean ~98% → 57%; Huang et al. 2024). A **deterministic** verifier (tests · compile · schema · lint · gitleaks · type-check · count) has `f=0` by construction and is the strongest possible critic — **always prefer a deterministic oracle where one exists**; fall back to a probabilistic critic only where no checkable oracle is available.

## Determinism / probabilism allocation

| Engine function | Layer | Mechanism (this repo) |
|---|---|---|
| Selectivity gate (loop-or-skip) | **deterministic** | hook/script on signal (tests-fail? low-conf? oracle-exists?) — never invoke cognition on a clean, high-confidence answer |
| Verifier / oracle-gate | **det where checkable** → prob else | tests · compile · schema · lint · gitleaks · diff (`f=0`); `persona-pipeline` / `perspective-trio` ONLY where no deterministic oracle |
| Round-cap · token-budget · time-box | **deterministic** | `cascade-resolver` 8 termination conditions + harness `n ≤ n*` — **NOT model self-judgment** |
| Vote-tally · dedup · keep-best (monotonicity) | **deterministic** | count/compare — never ship a regressed round |
| Merge-gate | **deterministic** | `CONTRIBUTING.md` bot-convergence gate + `pr-review-protocol §2.6.1` G1-G8 (mergeable / CLEAN / checks=SUCCESS are API reads) |
| Gap-finding · fix-gen · judgment · synthesis | **probabilistic** | diverse cross-brand critic panel (the cognition) |
| Audit-trail · state | **deterministic** | hooks · files · git (amnesia-proof) |

## Three-regime switch (calculated per task)

Classify the task by **verifiability** and **generator competence**, then route:

| Regime | Condition | Composition (existing primitives) |
|---|---|---|
| **REFINE** | `gen ≳ 70%`, verifiable | `perspective-trio` (parallel diverse breadth) then `cascade-resolver` (sequential diverse uplift, keep-best) → geometric climb to human-multi-pass ~95% |
| **SELECT** | `gen 40–70%`, verifiable | best-of-N → `converge` (5-act steelman→critique→compare→synthesize→reject-log). Works because verifying ≫ generating (asymmetry); selection needs only a good verifier, not a >50% generator |
| **DEFER** | `gen < 40%` OR unverifiable | HITL — the deliberate **10–15% residue, never 0%** (escalate with the synthesis, do not fake a result) |

Verify-depth pass (any regime, before acting on a high-impact result): `persona-pipeline` (6-stage board, depth-scaled by risk) → produces the `certainty` factor the autonomy gate consumes.

Cutoffs are heuristic → **calibrate per task-class empirically**. Benchmark grounding (2026): knowledge/reasoning 85–94%, single-issue coding 74–94% (but contamination-resistant SWE-bench Pro ~46%), long-horizon agentic 37–69%, multi-run consistency drops ~60% → 25%. **"80%" is task-class-dependent, not a constant.**

## Multi-axis diversity (the `r`-lever)

Vary the critic panel along **{discipline (security · perf · correctness · UX) · view (abstraction level) · vertical (specialist depth-audit) + horizontal (peer breadth) · brand (Claude · Gemini · GPT — strength-profiles genuinely differ)}** *simultaneously*. Correlation along any axis re-introduces shared blind-spots and stalls convergence.

> ⚠ **Avoid hive-mind / shared-memory for the critique layer** — it correlates critics → kills the diversity that lifts `r` → violates the master condition. `perspective-trio`'s diversity guard and `cascade-resolver`'s no-duplicate-role validator enforce this.

## Economic stop (deterministic, harness-enforced)

```
n* = 1 + ⌈ ln( (1−ρ)·g₀·V / C ) / ln(1/ρ) ⌉
   ρ = retained-gap-fraction · g₀ = initial gap · V = value/correct-unit · C = round-cost
```

`n*` grows only **logarithmically** in `V/C` → **robustly ≤ 3–4 rounds** (a 100× more valuable task justifies ~1 extra round). Floor = **human-parity (~90%, NOT 100%)**; cap enforced by the harness (`cascade-resolver` termination conditions), not by a model deciding "one more round". Also stop on `Δ < ε for K rounds` OR consensus. The real curve is **sub-geometric** (rounds re-find easy errors; the hard residual resists) → the plateau arrives even sooner. Looping past `n*` costs 4–10× for <1% gain.

## Composition map (no new engine)

| Function | Primitive | Path |
|---|---|---|
| Breadth (parallel orthogonal lenses) | `perspective-trio` | `agents/perspective-trio.md` |
| Score-uplift loop (sequential diverse, economic-stop) | `cascade-resolver` | `agents/cascade-resolver.md` |
| Depth verify (6-stage board, certainty) | `persona-pipeline` | `agents/persona-pipeline.md` |
| Proposal synthesis (SELECT) | `converge` | `skills/converge/SKILL.md` |
| Autonomous drive harness | `auto-pilot` | `skills/auto-pilot/SKILL.md` |
| Deterministic loops/fan-out | host `Workflow`/orchestration primitive | (runtime) |
| Merge-gate / state / audit | `CONTRIBUTING.md` gate · hooks · git | repo infra |

The engine is a **router + bounds** over these — itself an instance of *native-primitive-over-custom-machinery*. Related agents (`best-fit-router`, `agent-forger`) are **not** dispatched and intentionally **not** bundled (YAGNI).

## Return-Gate application (self-resolve before asking)

Before returning [options · decisions · questions] to the operator: (1) **rank** by recommendation; (2) **impact-score** each (6-factor autonomy gate); (3) **diverse-validate** (`persona-pipeline` + the multi-axis panel); (4) **gate** — top item HIGH (≥0.85) ∧ reversible ∧ ¬HUMAN_DOMAIN → **decide + act + report** (skip the ask); else **score-uplift** (`cascade-resolver`, ≤ n*) → regenerate ranked items → **re-loop bounded**; (5) **exit** — HIGH self-resolution → act; OR genuine residue → **ask** (tool-over-prose, recommended-first). **Escapes (do NOT suppress the ask)**: HUMAN_DOMAIN · a genuine operator-preference the agent lacks + can't self-verify · irreversible/high-blast · duly-justified.

## Viability bar (settled)

**Beat the human baseline (~90% single-pass, NOT 100%)** — humans hit higher numbers via the same multi-pass review this engine automates. Viable NOW for verifiable regimes; HITL on the residue.

## Invariants & bounds (non-negotiable)

- Master condition holds (verifier > generator, independent) or **do not loop**.
- Stopping is **deterministic-harness-enforced** (`cascade-resolver` conditions / `n*`), never model self-judgment.
- **Keep-best monotonicity**: never ship a round that regressed against the prior best.
- Recursion depth ≤ 2; cascade attempts cannot spawn cascade.
- The **10–15% HITL residue is by design**, not a failure — never fake a result to avoid it.
- No `--no-verify`, no auto-merge bypass of the `CONTRIBUTING.md` convergence gate.

## Anti-patterns (do NOT)

- ❌ Self-critique on a clean, high-confidence output (the paradox — degrades it)
- ❌ Same-model / same-brand verifier (correlated blind-spots; violates the master condition)
- ❌ **Model-judged stopping** (must be deterministic-harness-enforced)
- ❌ Loop past `n*` (4–10× token cost for <1% gain)
- ❌ Hive-mind / shared-memory for the critique layer (correlates critics)
- ❌ Suppressing a genuine HITL-residue ask (the 10–15% deferral is by design)
- ❌ Treating any single benchmark % as ground-truth (contamination inflates 5–15 pts)
- ❌ Re-implementing converge / cascade / pipeline inside this skill (it is a composition, not an engine)

## Examples (invocation prompts — not a CLI)

No binary/slash-command — invoke conversationally (frontmatter triggers):

- **REFINE** — *"drive this draft to high quality with a few bounded diverse-review iterations"* → runs `perspective-trio` (breadth) then `cascade-resolver` (sequential uplift, keep-best), stops at `n*`.
- **SELECT** — *"reconcile these competing proposals into one validated synthesis"* → routes to `converge` (best-of-N / debate→converge).
- **AUTO** — *"converge this PR to high quality before asking me"* → classifies regime by verifiability, routes, and applies the Return-Gate before any HITL ask.

## Prior art

See [`PRIOR-ART.md`](PRIOR-ART.md) for the research grounding (Self-Refine, Reflexion, CRITIC, Huang 2024 self-correction limits, multi-agent-debate Du et al.) and the composed-primitive provenance. The SELECT regime's synthesis primitive (`converge`) carries its own 20+-artifact survey in `skills/converge/PRIOR-ART.md`.

## Related multi-agent-os artifacts

- `skills/converge/SKILL.md` — the SELECT-regime synthesis primitive this engine routes to
- `agents/perspective-trio.md` · `agents/cascade-resolver.md` · `agents/persona-pipeline.md` — the probabilistic primitives this engine composes
- `skills/auto-pilot/SKILL.md` — sibling autonomous-drive kernel (also composes, doesn't re-implement)
- `skills/quiesce/SKILL.md` — termination-predicate driver that can wrap this engine per PR
- `protocols/agent-delegation.md` — how spawned primitives fit the delegation chain

## License

MIT (matches multi-agent-os repo `LICENSE`).
