---
name: agentic-tool-forge
description: Forge a raw intent into the optimal reusable agentic-tool — research pre-existing internal+external solutions first (DRY), decide the best artifact TYPE (prompt/skill/command/agent/mcp/plugin/marketplace/rule), name it via 5-axis rigor, make it AI-agnostic + multi-agentic, then forge + save (operator-confirmed). Thin wrapper over the `agentic-tool-forge` skill. Genesis stage of the agentic-tool lifecycle.
argument-hint: "<intent> | --goal \"…\" [--scope user|project|community|auto] [--type auto|skill|command|agent|mcp|plugin|prompt|rule] [--name auto|<name>] [--research both|internal|external] [--dry-run] [--context \"refs\"]"
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, WebSearch, WebFetch, Task, Skill]
---

# /agentic-tool-forge

Invoke the **`agentic-tool-forge`** skill (Claude Code: `Skill` tool with `skill: "agentic-tool-forge"`; other hosts: the equivalent skill-activation mechanism), passing the arguments below.

**Arguments**: `$ARGUMENTS`

## Parsing
- If `$ARGUMENTS` starts with `--`, pass the flags through verbatim.
- Else treat the whole string as `--goal "$ARGUMENTS"` (bare-intent shorthand) with defaults: `--scope auto --type auto --name auto --research both`.
- Empty `$ARGUMENTS` → print the skill's usage + parameter table; do NOT guess an intent.

## What it does (skill pipeline)
research (internal ‖ external ‖ DRY) → compare/critique → **decide artifact type** → **name (5-axis)** → design (Goldilocks · RBAD · Socratic) → gate (host pre-creation + anti-theater gates if present · `rule-quality-tests` 6 self-validity) → forge → confirm + save → handoff (`→ /agentic-tool-evaluator` → `/agentic-tool-trainer`).

If an existing tool already covers ≥50% of the intent, it recommends **EXTEND** that tool instead of creating a new one. Use `--dry-run` to get the type+name+path proposal without writing.

## Family
Genesis stage of the agentic-tool lifecycle: **forge → evaluate → train → operate → deprecate**. Siblings: `skills/agentic-tool-evaluator`, `skills/agentic-tool-trainer`; shared `protocols/agentic-tool-lifecycle.md`.
