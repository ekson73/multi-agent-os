---
name: agentic-tool-pipeline
description: Conductor of the agentic-tool lifecycle — route ANY --source-object (intent · url · plugin · marketplace · existing tool) to the right family member and run analyze→research→debate→converge→harmonize → forge/adopt/improve one+ agentic-tools of any --type → save to --location. A thin orchestrator that COMPOSES forge/intake/evaluator/trainer/anima/converge — reimplements nothing. Thin wrapper over the `agentic-tool-pipeline` skill.
argument-hint: "<source-object> | --source-object \"…\" [--type auto|skill|command|agent|subagent|mcp|plugin|prompt|marketplace] [--location akasha|multi-agent-os|vek-ai-toolkit] [--scope user|project|community|auto] [--research both|internal|external] [--blocks 0,1,2,3,4] [--dry-run] [--json] [--no-confirm]"
allowed-tools: [Task, Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Skill]
---

# /agentic-tool-pipeline

Invoke the **`agentic-tool-pipeline`** skill (Claude Code: `Skill` tool with `skill: "agentic-tool-pipeline"`; other hosts: the equivalent skill-activation mechanism), passing the arguments below.

**Arguments**: `$ARGUMENTS`

## Parsing
- If `$ARGUMENTS` starts with `--`, pass the flags through verbatim.
- Else treat the whole string as `--source-object "$ARGUMENTS"` (bare-source shorthand) with defaults: `--type auto --location akasha --scope auto --research both`.
- Empty `$ARGUMENTS` → print the skill's usage + parameter table; do NOT guess a source-object.

## What it does (skill pipeline)
**Stage 0 ROUTE** (classify the source-object → forge | intake | evaluator→trainer | defer-HITL; forge/intake **author/adopt + save to `--location`**, while on the evaluator→trainer path the **evaluator scores read-only** then the **trainer writes improvements** to the owned tool) → **EXPAND** (analyze · research internal‖external similars · compare · cross · catalog · categorize · critique) → **FILTER ⇐ DEBATE** (`converge`/`debate-converge` + optional `perspective-trio`/`persona-pipeline`) → **HARMONIZE ⇐ CONVERGE** (`converge` 5-act → one+ synthesized tool-spec) → **FORGE** (the routed member forges/adopts/improves + saves to `--location`; naming via `anima` inside forge). Use `--dry-run` to get the routed tool-spec proposal without writing.

It **reimplements nothing** — every stage delegates to an existing primitive. It applies and passes the 11 principles (DRY · KISS · SSOT · YAGNI · anti-over-eng · anti-theater · boy-scout · DNA-geracional · continuity · idempotency · handoff) via the existing DNA rails.

## Family
The **conductor** of the agentic-tool lifecycle: **conduct → {forge | intake | evaluate | train}**. Siblings: `skills/agentic-tool-forge`, `skills/agentic-tool-intake`, `skills/agentic-tool-evaluator`, `skills/agentic-tool-trainer`, `skills/anima`; shared `protocols/agentic-tool-lifecycle.md`. Thin-preset precedent: `skills/enhance-pipeline` (feature axis).
