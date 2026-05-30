---
name: agentic-tool-trainer
description: Use when you want to improve, tune, coach, or evolve an existing agentic-tool (skill/agent/subagent/command/prompt/MCP-tool) based on its eval results — OR distill a brand-new tool from an observed human↔agent task ("turn what we just did into a skill", "make a skill from this session", "this skill underperforms, improve it", "track my corrections and patch the tool", "compare version performance over time"). Consumes eval reports; hands finalized authoring back to skill-writer/forge.
metadata:
  version: "1.0.0"
  scope: AAIF cross-vendor
---

# Agentic-Tool Trainer

## Overview

Make an agentic-tool **better over time**, or **distill a new one from a trace**. Training is a reflect-loop (DSPy/GEPA/SIMBA lineage): read eval results → reflect on failures → distill a revision → re-evaluate → keep only revisions that don't regress (Pareto). Distilling turns an observed human↔agent task into a walkthrough + draft tool. Improvement is evidence-gated (re-eval proves the gain) and applied via PR + review.

> Shared vocabulary, taxonomy, training method, Rovo bridge: **`protocols/agentic-tool-lifecycle.md`** (read it once).

## When to use

- "This skill/agent underperforms — improve it." (mode `improve`)
- "Turn what we just did into a reusable skill." / "Make a skill from this session/trace." (mode `distill`)
- "Track my corrections and patch the tool over time." (mode `track`)
- "Compare this tool's performance across versions."

**When NOT to use**: scoring a tool (→ `agentic-tool-evaluator` — trainer *consumes* its report); from-scratch authoring + final validation (→ `skill-writer` skills / `forge` agents); rule self-validity (→ `rule-quality-tests`).

## Modes

### `improve` (existing tool)
1. Require an `EVAL-REPORT` (run `agentic-tool-evaluator` first) + the golden-set.
2. **Reflect** per low-scoring case: what in the prompt caused it?
3. **Distill** a candidate revision (instructions / examples / scope).
4. **Re-evaluate** the candidate on the SAME golden-set (delegate to evaluator).
5. **Pareto guard**: reject any revision that regresses a complementary case. Keep a frontier of candidates.
6. Bounded: cap N iterations (default 3); plateau → report "no further gain, escalate".
7. **Apply** = PR + review (NEVER auto-merge tool changes — `[C07]`). Log version→score in the training-log.

### `distill` (new tool from a trace)
1. Ingest a session transcript / task trace.
2. **Sanitize** secrets/PII first (gitleaks + scrub) — never distill from raw secret-bearing traces.
3. Extract the procedure → `WALKTHROUGH.md`: steps · do/don't · patterns · anti-patterns · DoR · DoD · acceptance criteria.
4. Emit a **draft** SKILL.md / agent spec.
5. **DRY check**: does an existing tool already cover this? If yes → escalate, don't duplicate (`forge` anti-pattern).
6. Hand the draft to `skill-writer` (skills) / `forge` (agents) for finalization + AAIF validation.

### `track` (corrections over time)
Capture operator instructions/corrections (pairs with `skills/operator-quote-capture`) → feed `improve`. Maintain a training-log enabling progress-tracking + version-comparison.

Full method: `protocols/agentic-tool-lifecycle.md` §5.

## Walkthrough template (distill)

```markdown
# WALKTHROUGH — <task> — <date>
## Goal / Context
## Steps (numbered, observed from trace)
## Do / Don't
## Patterns / Anti-patterns
## DoR / DoD / Acceptance criteria
→ DRAFT: skills/<name>/SKILL.md (hand to skill-writer)
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Claiming improvement without re-eval | Evidence-gate: re-run evaluator, show the delta |
| Accepting a revision that regresses other cases | Pareto guard — held-out + complementary cases must not drop |
| Auto-merging a tool mutation | PR + review always (`[C07]`) |
| Over-fitting to the golden-set | Keep held-out cases; respect a size budget; preserve generality |
| Distilling from a secret-bearing trace | Sanitize (gitleaks + scrub) BEFORE distill |
| Distilling a duplicate of an existing tool | DRY check first; escalate instead of duplicating |
| Churning forever | Bounded iterations (cap 3); plateau → escalate |
| Finalizing authoring here | Hand drafts to skill-writer/forge |

## Rovo

To run training inside Rovo, bridge the trainer via a Forge `rovo:action`; the improved SKILL.md still maps to a Rovo agent `prompt` via the codegen contract. See `protocols/agentic-tool-lifecycle.md` §7.

## Self-test (dogfood)

`improve`: take a deliberately weak skill → train → evaluator confirms score ↑ with **0 regressions**. `distill`: feed a known short trace → expect a coherent WALKTHROUGH + draft. If both hold, the trainer is calibrated.

## Refs

`protocols/agentic-tool-lifecycle.md` (shared) · `skills/agentic-tool-evaluator` (consumes its report) · `skills/skill-writer` + `agents/forge.md` (finalize) · `skills/operator-quote-capture` (corrections) · DSPy/GEPA/SIMBA (reflect-loop) · agentskills.io.
