---
name: agentic-tool-evaluator
description: Use when you need to evaluate, test, score, benchmark, or QA an agentic-tool (a skill/SKILL.md, agent, subagent, slash-command, prompt, or MCP-tool) — e.g. "is this skill any good?", "does this skill actually trigger?", "test this agent", "did my edit regress the skill?", "compare these two skill versions", "score this command". Produces a behavioral eval report; does NOT author or modify the tool.
metadata:
  version: "1.1.0"
  scope: AAIF cross-vendor
---

# Agentic-Tool Evaluator

## Overview

Evaluate the **behavior an agentic-tool induces** — not its source code. A skill/agent/command is prompt-markdown; you score what an agent *does* with it, by running golden cases WITH vs WITHOUT the tool and applying a rubric. Output: a reviewable `EVAL-REPORT` + `--json`. Read-only — improving the tool is the trainer's job (`agentic-tool-trainer`).

> Shared vocabulary, taxonomy, rubric, Rovo bridge: **`protocols/agentic-tool-lifecycle.md`** (read it once).

## When to use

- "Is this skill/agent/command good / production-ready?"
- "Does this skill actually trigger on the right inputs (and stay silent otherwise)?"
- "I edited a tool — did it regress?" (version A/B)
- "Compare these two tools/versions."
- Before promoting a tool (dogfood gate) or merging a tool PR.

**When NOT to use**: authoring a new tool (→ `skill-writer` / `forge`); improving/mutating a tool (→ `agentic-tool-trainer`); validating a *rule* for self-consistency (→ `rule-quality-tests`); unit-testing executable code (use the project's test runner); evaluating the **hub's routing** (the MoE gating-network) rather than a single tool (→ `mcp-tools/maos-mcp-hub/evals/routing_eval.py` — the (k) hub-routing eval; this skill scores one tool's induced behaviour, that harness scores route selection across the gating-seam).

## Method (behavioral, not unit-test)

1. **Identify** the target tool + its type (skill/agent/command/prompt/MCP-tool), resolve its path, **and its intended invocation surface** (model auto-trigger · `plugin:name` · human `/slash`). For a human-`/slash` tool, confirm a `commands/<name>.md` wrapper exists — see the Triggering check below.
2. **Golden set**: locate or build 20–50 `input → expected-behavior` cases. None found? Generate a 3–5 case **smoke-set** from the tool's own description/examples and flag low confidence.
3. **With/without control**: for each case, run a host agent (a sub-agent via Task is ideal for isolation) WITH the tool present and WITHOUT it. The delta isolates the tool's effect.
4. **Score** each case 0–5 on: Triggering · TaskCompletion · ToolCorrectness · Efficiency · ScopeFit (−2..+2); plus Regression vs baseline when comparing versions. Rubric details: `protocols/agentic-tool-lifecycle.md` §4.
5. **Verdict**: `PASS` (all ≥ threshold, 0 regressions) · `FLAG` (passes, improvable) · `FAIL` (any below / any regression).
6. **Sanitize** (gitleaks + PII scrub) any captured traces before writing the report.
7. **Report**: write `EVAL-REPORT.md` + emit `--json` envelope ([C06], `protocols/agentic-tool-lifecycle.md` §6). Hand FLAG/FAIL findings to `agentic-tool-trainer` if improvement is wanted.

## Report template

```markdown
# EVAL-REPORT — <tool> (<type>) — <date>
- Baseline: <version|none>   Golden cases: <N> (<curated|smoke-set>)
## Scores (0–5)
| Case | Trigger | TaskCompl | ToolCorr | Effic | ScopeFit | Regression |
|------|---------|-----------|----------|-------|----------|------------|
## Verdict: PASS|FLAG|FAIL
## Strengths / Weaknesses
## Recommendation  (→ agentic-tool-trainer if improvable)
```

## Common mistakes

| Mistake | Fix |
|---|---|
| **Invocation-surface miss** — a skill/agent meant to be human-`/slash`-invokable ships WITHOUT a `commands/<name>.md` wrapper, so typing `/name` does nothing (only auto-trigger / `plugin:name` work) | Score it as a **Triggering FAIL** for the `/slash` surface: the wrapper is what creates the `/name` entry point. Detects, at maintenance/QA time, the gap that `agentic-tool-forge`'s Invocation-surface gate prevents at creation time. (Empirical: a narrative-recap skill landed slash-less.) |
| Asserting on the markdown source | Score induced **behavior** (with/without control) |
| Claiming "unit/integration tests pass" | This is behavioral eval — say so; don't fake code-coverage |
| Fabricating golden cases that don't exercise real behavior | Anti-theater R4 — cases must be runnable + meaningful |
| Mutating the tool to "fix" it | Out of scope — that's the trainer; evaluator is read-only |
| No baseline when asked "did it regress?" | Regression needs A/B; capture/locate the prior version |
| Leaking trace secrets into the report | gitleaks + scrub before writing |

## Rovo

Rovo doesn't consume SKILL.md natively; to run this eval inside Rovo, bridge via a Forge `rovo:action` that wraps the eval. See `protocols/agentic-tool-lifecycle.md` §7.

## Self-test (dogfood)

Run the evaluator on a known-good skill (expect PASS) and a deliberately broken one (expect FAIL). If both verdicts are correct, the evaluator is calibrated.

## Refs

`protocols/agentic-tool-lifecycle.md` (shared) · `agents/forge.md` (KPI) · `skills/skill-writer` (author) · `skills/agentic-tool-trainer` (improve) · `skills/rule-quality-tests` (rules) · agentskills.io · promptfoo/DeepEval.
