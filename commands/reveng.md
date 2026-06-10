---
name: reveng
description: Reverse-engineer source code into an OpenSpec SPEC model (as-built behavioral contract) — code as read-only oracle, distill→recast→faithfulness-check→validate→score-card. Thin wrapper over the `reveng` skill. src→spec is the priority pair; other source→target pairs are roadmap.
argument-hint: "<source> | --from src|docs|adrs|tickets|git --target spec|docs|readme|agents [--out openspec/specs] [--cap <name>] [--scope-lock \"…\"] [--validate] [--dry-run] [--json]"
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit, Skill]
---

# /maos:reveng

Invoke the **`reveng`** skill (Claude Code: `Skill` tool with `skill: "reveng"`; other hosts: the equivalent skill-activation mechanism), passing the arguments below.

**Arguments**: `$ARGUMENTS`

## Parsing
- Token(s) before the first `--` = `<source>` (default `src/`); `--key value` / `--flag` after = parameters.
- Bare intent (no `--`) → treat as `<source>` with defaults `--target spec --validate`.
- Empty `$ARGUMENTS` → print the skill's usage + parameter table; do NOT guess a source.

## What it does (skill pipeline)
discover capabilities → distill → neutral brief (faithfulness anchor) → recast into OpenSpec (`## Purpose` / `### Requirement[SHALL]` / `#### Scenario[WHEN/THEN]`) → **faithfulness check** (every requirement traces to a code/test oracle; no invented behavior; `src` wins on drift) → gap report (cloud-only truth) → `openspec validate --specs` → **end-of-reveng score-card**.

The code is a **read-only oracle** (never written to; specs never override it — ADR-026 precedence `src > spec > docs`). `--dry-run` gives the plan + score-card without writing. If `openspec/specs/` already exists at full fidelity it *refreshes* idempotently.

## Family
`spec-lifecycle` — sibling of `content-recast` (re-targets audience; `reveng` re-targets abstraction/model). Audit/route the output via `openspec-concierge`. Forged via `agentic-tool-forge`; lifecycle handoff `→ /agentic-tool-evaluator` → `/agentic-tool-trainer`.
