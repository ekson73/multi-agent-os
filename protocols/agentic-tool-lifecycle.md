# Agentic-Tool Lifecycle — Shared Reference

> **Shared reference** for `skills/agentic-tool-evaluator` + `skills/agentic-tool-trainer`.
> **Version**: 1.0.0 (2026-05-28)
> **Scope**: AAIF cross-vendor. Vendor-neutral; no host-specific hardcoding.
> **Lineage**: extends `agents/forge.md` KPI + Goldilocks/RBAD to ALL agentic-tool types; complements `skills/skill-writer` (authoring) and `skills/rule-quality-tests` (rule self-validity).

This document is the common vocabulary the evaluator and trainer share. Read it once; both skills reference it instead of duplicating.

---

## 1. What is an "agentic-tool"?

An **agentic-tool** is any reusable unit that shapes or extends agent behavior:

| Type | Artifact | Discovery path (Claude Code reference) | Eval surface |
|---|---|---|---|
| **skill** | `<name>/SKILL.md` | `skills/`, `~/.claude/skills/`, `.claude/skills/` | behavioral (with/without) |
| **agent** | `<name>.md` (frontmatter persona) | `agents/`, `~/.claude/agents/` | behavioral (task delegation) |
| **subagent** | agent invoked via Task tool | same as agent | behavioral (delegated task) |
| **command** | `<name>.md` (slash command) | `commands/`, `~/.claude/commands/` | behavioral (invocation→effect) |
| **prompt** | reusable prompt template | inline / `prompts/` | behavioral (input→output) |
| **MCP-tool** | tool exposed by an MCP server | `mcp__<server>__<tool>` | behavioral (call→result, **sandbox side-effects**) |

Other hosts (Cursor, Codex, Gemini CLI, Copilot) use equivalent paths — see the host's docs. The lifecycle below is host-agnostic.

**v1 first-class**: skill · agent · command. **v1 supported via same contract**: prompt · MCP-tool. subagent = agent variant.

---

## 2. AAIF frontmatter contract (agentskills.io)

When the tool is a skill, it MUST satisfy the [Agent Skills open standard](https://agentskills.io/specification):

- `name`: lowercase letters/numbers/hyphens, ≤64 chars, **matches parent directory name**.
- `description`: ≤1024 chars, "what + when", keyword-rich; for triggering. **Should describe WHEN to use, not summarize the workflow.**
- Body: ≤500 lines / ≤5000 tokens recommended.
- `references/` / `scripts/` / `assets/`: loaded on demand, referenced via **relative paths one level deep**.
- Optional: `license`, `compatibility`, `metadata`, `allowed-tools` (experimental — host-varying; avoid hard reliance for portability).

Agents/commands in this repo use a lighter frontmatter (`name`, `description`, optional `version`, `tools`, `agnostic`) per `CLAUDE.md` Skills/Commands/Agents Format.

---

## 3. The lifecycle (create → evaluate → train)

```
        skill-writer / forge          agentic-tool-evaluator        agentic-tool-trainer
AUTHOR ───────────────────────▶ EVALUATE ──────────────────▶ TRAIN ──┐
  (create SKILL.md / agent)      (behavioral score + report)   (improve OR distill)
        ▲                                                              │
        └──────────────── re-author / finalize distilled draft ◀──────┘
```

- **Author** is OUT of scope for evaluator/trainer (use `skill-writer` for skills, `forge` for agents).
- **Evaluate** = score current behavior. Read-only. → produces `EVAL-REPORT`.
- **Train** = consume the report → improve (mutate, supervised) OR distill (emit new draft from a trace). Hands finalization back to `skill-writer`/`forge`.

---

## 4. Behavioral evaluation method (NOT code unit-testing)

A SKILL.md/agent.md is prompt-markdown, not executable code. You evaluate the **behavior it induces**, not source assertions.

### 4.1 Golden task set
- 20–50 curated `input → expected-behavior` cases (CI target <5min). If absent, auto-generate a **smoke-set** (3–5 cases) from the tool's own `description`/examples and flag low confidence.
- Grow the set from observed production failures.

### 4.2 With/without control
For each case: run a host agent **WITH** the tool present and **WITHOUT** it. The delta isolates the tool's contribution (did it trigger? change the outcome correctly?).

### 4.3 Scoring rubric (0–5 per dimension; deterministic-first, LLM-judge for qualitative)

| Dimension | Question | 0 | 5 |
|---|---|---|---|
| **Triggering** | Did the tool activate when it should (and stay silent when it shouldn't)? | never/always-wrong | precise |
| **TaskCompletion** | Did the induced behavior solve the case? | failed | fully |
| **ToolCorrectness** | Right steps/tools/sequence followed? | wrong | optimal |
| **Efficiency** | Tokens/tool-calls vs expected? | wasteful | optimal |
| **ScopeFit** | Atomic + reusable (Goldilocks), not too broad/narrow? | -2..+2 (0=perfect) | — |
| **Regression** | vs baseline version: any case that got worse? | regressed | none |

*(Triggering/TaskCompletion/ToolCorrectness/Efficiency are eval-specific; ScopeFit reuses `forge.md` KPI; Regression is version-comparison only.)*

### 4.4 Verdict
`PASS` (all dims ≥ threshold, 0 regressions) · `FLAG` (passes but improvable) · `FAIL` (any dim below threshold OR regression).

---

## 5. Training method (trace → reflect → distill)

Reflective-optimizer lineage (DSPy teleprompters · GEPA · SIMBA · PromptAgent). Two modes:

### 5.1 `improve` (existing tool)
1. Consume `EVAL-REPORT` + golden-set.
2. **Reflect** on failing/low-scoring cases: *what in the prompt caused this?*
3. **Distill** a candidate revision (instructions/examples/scope).
4. **Re-evaluate** the candidate on the SAME golden-set.
5. Keep a **Pareto frontier** of candidates (never accept a revision that regresses a complementary case).
6. Bounded iterations (cap N, default 3); plateau → report "no further gain, escalate".
7. Apply = PR + review (never auto-merge tool changes per `[C07]`).

### 5.2 `distill` (new tool from observed task)
1. Ingest a session transcript / task trace (human↔agent).
2. **Sanitize** secrets/PII first (gitleaks + scrub).
3. Extract the procedure: steps · do/don't · patterns/anti-patterns · DoR · DoD · acceptance criteria → `WALKTHROUGH`.
4. Emit a **draft** SKILL.md / agent spec.
5. DRY check (does an existing tool cover this? → if yes, escalate, don't duplicate — `forge` anti-pattern).
6. Hand the draft to `skill-writer` (skills) / `forge` (agents) for finalization + validation.

### 5.3 `track` (corrections over time)
Capture operator instructions/corrections (links to `skills/operator-quote-capture`) → patch the tool via `improve`. Maintain a training-log (version → score over time) enabling progress-tracking + version-comparison.

---

## 6. Machine output envelope ([C06] AI-Native)

Both skills support `--json`. Standard shape:

```json
{
  "tool": "<path>",
  "type": "skill|agent|command|mcp-tool|prompt",
  "mode": "evaluate|improve|distill|track",
  "scores": {"triggering": 0, "taskCompletion": 0, "toolCorrectness": 0, "efficiency": 0, "scopeFit": 0, "regression": 0},
  "verdict": "PASS|FLAG|FAIL",
  "recommendation": "string",
  "_agent_feedback": "governance hints (maos house style)"
}
```

Exit codes ([C06]): `0` success · `1` error · `2` warning/FLAG.

---

## 7. Rovo bridge (Atlassian compatibility)

**Atlassian Rovo does NOT natively consume SKILL.md.** Rovo agents use a Forge YAML manifest (`rovo:agent`: `key`, `name`≤30, `prompt` [string or `resource:`], `conversationStarters`, `actions[]`); actions = `rovo:action` Forge functions; knowledge = Confluence/Jira/Drive.

**Bridge (only confirmed path)** — SKILL.md stays the portable SSOT; a codegen step emits the Rovo manifest:

| SKILL.md | → Rovo Forge manifest |
|---|---|
| `body` | agent `prompt` (via `resource:key;path`) |
| `description` | agent `description` |
| `scripts/*` | `rovo:action` Forge functions |
| golden-set / report | Forge function returning structured result |

"Rovo-compatible" therefore means **bridgeable**, not natively-loadable. Sources: developer.atlassian.com `/forge/manifest-reference/modules/rovo-agent/`.

---

## 8. Governance + sunset

- **PR + bot-convergence** for any tool mutation (Copilot/qodo/CodeRabbit per `.claude/rules/pr-reviewer-communication.md` + `[C07]`).
- **Worktree** mandatory ([C04]).
- **Anti-theater 8Q REALITY** on every report/recommendation (real? not-theater? not-hallucinated? not-invented? viable? applicable? implementable? useful?).
- **DUED sunset** (qualitative, not counter-based): deprecate a dimension/method when contradicted by a newer standard, domain ceases, empirical learning supersedes, operator retracts, ≥3 false-positive contexts, or an elegant replacement emerges.

---

## 9. Refs

- `agents/forge.md` — KPI scale · Goldilocks · RBAD · 33 Socratic Questions · post-mortem feedback loop (reused).
- `skills/skill-writer/SKILL.md` — AAIF authoring (finalization target).
- `skills/rule-quality-tests/SKILL.md` — rule self-validity (adjacent quality discipline).
- `agents/qa-validator.md` — output QA (adjacent).
- [agentskills.io/specification](https://agentskills.io/specification) — SKILL.md open standard.
- promptfoo · DeepEval — behavioral-eval framework patterns (referenced, not hard dependency).
- DSPy · GEPA · SIMBA — reflective prompt-optimization lineage (training loop).
- developer.atlassian.com — Rovo agent Forge manifest (bridge).
