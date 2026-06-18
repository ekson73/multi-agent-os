---
name: agentic-tool-intake
description: Decide whether and HOW to take on a candidate tool that already exists (external repo/MCP/plugin/skill or internal proposal) — understand → research similars → compare/cross → validate viability → DECIDE among install/create-internally/absorb/adapt/sub-agent/abandon/defer-HITL → (gated) governed install. Thin wrapper over the `agentic-tool-intake` skill. The ADOPT stage of the agentic-tool lifecycle.
argument-hint: "--candidate <repo|mcp|plugin|skill|url|pkg> [--mode research|decide|adopt] [--scope-target multi-agent-os|user|project|auto] [--decision-bias conservative|balanced] [--dry-run] [--json]"
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, WebSearch, WebFetch, Task, Skill]
---

# /agentic-tool-intake

> **Invocation**: `/maos:agentic-tool-intake` where the host supports `command_namespace`; otherwise the function-specific filename `/agentic-tool-intake` (Sandwich-Namespacing fallback). Bare `# /<name>` H1 matches the repo convention for all command wrappers.

Invoke the **`agentic-tool-intake`** skill (Claude Code: `Skill` tool with `skill: "agentic-tool-intake"`; other hosts: the equivalent skill-activation mechanism), passing the arguments below.

## Usage

```
/agentic-tool-intake --candidate <repo|mcp|plugin|skill|url|pkg> [--mode research|decide|adopt] [--scope-target multi-agent-os|user|project|auto] [--decision-bias conservative|balanced] [--dry-run] [--json]
```

Examples:
- `/agentic-tool-intake --candidate https://github.com/colbymchenry/codegraph` — decide (dry-run) whether to adopt an external repo/MCP, and how.
- `/agentic-tool-intake --candidate @some/mcp-package --mode research` — research similars + categorize only.
- `/agentic-tool-intake --candidate "internal: a session-recap skill" --mode decide` — appraise an internal proposal.

**Arguments**: `$ARGUMENTS`

## Parsing
- Pass `--`-flags through verbatim.
- A bare candidate (URL / repo / package) ⇒ `--candidate "$ARGUMENTS" --mode decide --dry-run`.
- Empty `$ARGUMENTS` → print the skill's usage + parameter table; do NOT guess a candidate.

## What it does (skill pipeline)
UNDERSTAND → RESEARCH (→ `agentic-tool-forge` research) → COMPARE/CROSS (decision-matrix) → VALIDATE (CASC + trust-tier) → **DECIDE** one of `install · create-internally · absorb · adapt · sub-agent · abandon · defer-HITL` → INSTALL *(gated, off by default → `claude-code-concierge --mode=install`)* → RECORD (`dogfood-ledger` · `postflight` · `ticket-as-prompt`).

Default = `--mode=decide --dry-run` (a verdict with zero mutation). Install only runs with `--mode=adopt` + operator GO; HUMAN_DOMAIN ⇒ DEFER-HITL.

## Family
The **adopt-or-not** stage of the agentic-tool lifecycle: **forge (create) → intake (adopt) → evaluate (score) → train (improve) → operate → deprecate**. Siblings: `skills/agentic-tool-forge`, `skills/agentic-tool-evaluator`, `skills/agentic-tool-trainer`; shared `protocols/agentic-tool-lifecycle.md`. Composes — reimplements none of them.
