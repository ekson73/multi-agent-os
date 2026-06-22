---
name: opera-debrief
description: Deliver a session/work recap as a FAITHFUL, dosed NARRATIVE — a "summary as an opera" (story-arc acts + measured wit + call-to-action + insights + closing moral) for a human, or a structured payload for an agent. Consumes an existing session map; never re-summarizes. Thin wrapper over the `opera-debrief` skill.
argument-hint: "[<source>] [--audience human|agent] [--lang pt-BR|en-US] [--intensity dosed|low|off] [--humour med|low|off] [--drama instigante|low|off] [--acts N] [--lens classic|deductive] [--dry-run]"
allowed-tools: [Read, Write, Edit, Glob, Bash, Skill]
---

# /maos:opera-debrief

Invoke the **`opera-debrief`** skill (Claude Code: `Skill` tool with `skill: "opera-debrief"`; other hosts: the equivalent skill-activation mechanism), passing the arguments below.

**Arguments**: `$ARGUMENTS`

## Parsing
- Token(s) before the first `--` = the `<source>` to narrate (a session map, task, or PR); `--key value` / `--flag` after = parameters.
- No positional / empty `$ARGUMENTS` → derive from the current session map (`postflight` P2-DEBRIEF / `morning-briefing --mode=recap` / prior context); if none exists → print usage.
- `--audience agent` forces `--humour off --drama low` (per the skill's Intake step).

## What it does (skill pipeline)
consume an already-computed session map (from `postflight` P2-DEBRIEF / `morning-briefing --mode=recap`) → recast it through the named **OPERA REGISTER** (acts · measured humour · situational wit · instigating-not-alarming drama · call-to-action · key insights · closing moral) → **faithfulness gate** (every dramatic beat traces to a real fact; no invented drama) → **tone-safety gate** (never alarming; wit aimed at situations or the agent, never at a person). `--audience agent` emits a structured payload instead of prose; `--lens deductive` narrates as a Holmes·Watson·Moriarty case; `--dry-run` previews without finalizing.

It does **not** re-summarize — the summarising is delegated to the recap family (composition-over-inheritance). A vivid-but-false or anxiety-inducing recap is worse than a plain one.

## Family
`content-lifecycle` — the narrative-warm register member, a specialised dosed sibling of `content-recast` (which re-targets audience/abstraction generally). Forged via `agentic-tool-forge`; lifecycle handoff `→ /agentic-tool-evaluator` → `/agentic-tool-trainer`.
