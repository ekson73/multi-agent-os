# Agent Skills

## Overview

This folder contains reusable Agent Skills for the Multi-Agent OS framework. Skills follow the [Agent Skills open standard](https://agentskills.io) (SKILL.md format) and are compatible with 30+ AI tools including Claude Code, Cursor, Codex, Gemini CLI, Kiro, VS Code, GitHub Copilot, Goose, and others.

## Available Skills

| Skill | Directory | Description |
|-------|-----------|-------------|
| `audit` | `audit/SKILL.md` | On-demand audit and analysis (Sentinel Protocol) |
| `agent-select` | `agent-select/SKILL.md` | Select best agent for a task |
| `context-prep` | `context-prep/SKILL.md` | Prepare optimal context before delegation |
| `hierarchical-merge` | `hierarchical-merge/SKILL.md` | Enforce branch merge hierarchy |
| `worktree-policy` | `worktree-policy/SKILL.md` | Enforce mandatory worktree usage |
| `anti-conflict` | `anti-conflict/SKILL.md` | Prevent file conflicts between agents |
| `status-map` | `status-map/SKILL.md` | Generate ASCII status visualizations |
| `ttl-policy` | `ttl-policy/SKILL.md` | Manage content freshness policies |
| `find-docs` | `find-docs/SKILL.md` | Library documentation lookup via Context7 |
| `response-compression` | `response-compression/SKILL.md` | Output verbosity control with role-based profiles (none/lite/full/ultra) |
| `founder-playbook` | `founder-playbook/SKILL.md` | AI-native startup lifecycle router — diagnose stage + route to stage skills |
| `founder-stage-idea` | `founder-stage-idea/SKILL.md` | Idea stage — validate the problem before building |
| `founder-stage-mvp` | `founder-stage-mvp/SKILL.md` | MVP stage — product-market-fit evidence without compounding tech debt |
| `founder-stage-launch` | `founder-stage-launch/SKILL.md` | Launch stage — repeatable growth; remove the founder bottleneck |
| `founder-stage-scale` | `founder-stage-scale/SKILL.md` | Scale stage — systematic growth + defensible moat |
| `agentic-tool-pipeline` | `agentic-tool-pipeline/SKILL.md` | Conductor — route ANY source-object → analyze→research→debate→converge→harmonize → forge/adopt/improve one+ agentic-tools of any type, to any location |
| `agentic-tool-forge` | `agentic-tool-forge/SKILL.md` | Genesis — turn a raw intent into the right reusable agentic-tool (research-first → decide type → name → forge+save) |
| `agentic-tool-intake` | `agentic-tool-intake/SKILL.md` | Adopt-or-not — decide whether & how to take on an existing candidate (install/adapt/absorb/create-internally/abandon/defer) |
| `agentic-tool-evaluator` | `agentic-tool-evaluator/SKILL.md` | Behaviorally evaluate/score/QA any agentic-tool (skill/agent/command/prompt/MCP-tool) |
| `agentic-tool-trainer` | `agentic-tool-trainer/SKILL.md` | Improve a tool over time (reflect-loop) OR distill a new tool from an observed task |
| `voice` | `voice/SKILL.md` | On-demand TTS narration (Gemini 3.1 → ElevenLabs v3 → Kokoro fallback chain); the **opt-in** audio producer for the content-lifecycle family (opera-debrief · morning-briefing · content-recast). Text is always the default — audio never auto-plays |

## Skill Categories

### Delegation Skills
- `agent-select` — Agent selection algorithm
- `context-prep` — Pre-delegation context preparation

### Observability Skills (Sentinel Protocol)
- `audit` — On-demand session/agent/task auditing
- `status-map` — Human-readable status visualizations

### Coordination Skills
- `hierarchical-merge` — Branch convergence rules
- `worktree-policy` — Git worktree isolation
- `anti-conflict` — 7-phase conflict prevention

### Governance Skills
- `ttl-policy` — Content freshness and expiration

### Token Optimization
- `response-compression` — Output verbosity control with role-based compression profiles

### Developer Tools
- `find-docs` — Up-to-date library documentation and code examples via Context7 CLI

### Founder / Startup Skills

- `founder-playbook` — Lifecycle router: diagnose stage, check exit gates, route
- `founder-stage-idea` — Validate the problem before building
- `founder-stage-mvp` — Product-market-fit evidence; tech-debt / scope / security discipline
- `founder-stage-launch` — Repeatable growth engine; remove the founder bottleneck
- `founder-stage-scale` — Systematic growth + defensible moat + GTM

### Agentic-Tool Lifecycle Skills

> The family that creates/adopts → evaluates → trains agentic-tools, **conducted** by `agentic-tool-pipeline`. Shared reference: `protocols/agentic-tool-lifecycle.md`.

- `agentic-tool-pipeline` — **Conductor**: route ANY source-object → analyze→research→debate→converge→harmonize → land on the right member: forge/intake **author/adopt + save**, or evaluator **scores (read-only)** → trainer **writes improvements**. Thin preset; reimplements nothing
- `agentic-tool-forge` — Genesis: raw intent → the right reusable tool (research-first → decide type → name via `anima` → forge+save)
- `agentic-tool-intake` — Adopt-or-not: existing candidate → decide install/adapt/absorb/create-internally/abandon/defer (gated install)
- `agentic-tool-evaluator` — Behavioral eval-harness (with/without control + rubric); read-only score + report
- `agentic-tool-trainer` — Reflect-loop improvement (trace→reflect→distill, Pareto-guarded) + distill-new-tool-from-trace

### Orchestration / Convergence Skills

> Driver/loop family — auto-discovered from `skills/*/SKILL.md` (not all listed in the table above; the catalog is being backfilled). Shared methodology: `protocols/gap-loop-protocol.md`.

- `gap-loop` — **harness-agnostic** self-driven, self-scored 5-phase convergence loop (DoR → RECAP gap-register → RESOLVE MoE-per-gap → VALIDATE independent-audit → PERSIST); loops until [gaps dispositioned ∧ convergence ∧ autonomy_score ≥ 0.85]. Fills the seam left by `quiesce` (which needs the `/goal` slash-command); composes `converge`/`convergence-engine`/`perspective-trio`/`persona-pipeline`/`cascade-resolver`/`pulse` — reimplements nothing. Siblings (auto-discovered): `quiesce` · `auto-pilot` · `enhance-pipeline` · `convergence-engine` · `converge` · `pulse` · `work-compass`.

## Directory Structure

```
skills/
├── README.md                    ← This file
├── audit/
│   └── SKILL.md                 ← Audit skill definition
├── agent-select/
│   └── SKILL.md                 ← Agent selection skill
├── context-prep/
│   └── SKILL.md                 ← Context preparation skill
├── hierarchical-merge/
│   └── SKILL.md                 ← Merge hierarchy skill
├── worktree-policy/
│   └── SKILL.md                 ← Worktree enforcement skill
├── anti-conflict/
│   └── SKILL.md                 ← Conflict prevention skill
├── status-map/
│   └── SKILL.md                 ← Status visualization skill
├── ttl-policy/
│   └── SKILL.md                 ← TTL management skill
├── find-docs/
│   └── SKILL.md                 ← Library docs lookup skill
└── response-compression/
    └── SKILL.md                 ← Output verbosity control skill
```

## SKILL.md Structure

Each skill follows the Agent Skills open standard (SKILL.md with YAML frontmatter):

```markdown
---
name: skill-name
description: Brief description
version: 1.0.0
---

# Skill Name

## Purpose
What the skill does

## When to Use
Trigger conditions

## Trigger Phrases
Keywords that invoke this skill

## Protocol Rules
Core rules and constraints

## Commands
Executable commands

## Examples
Usage examples
```

## Skill Invocation

Skills are automatically invoked by compatible agents when:
- Trigger phrases are detected in conversation
- Related tools are used (e.g., Task tool triggers delegation skills)
- Session lifecycle events occur

Skills can also be referenced explicitly in CLAUDE.md or agent definitions.

---

*Part of multi-agent-os plugin v1.0.0*
