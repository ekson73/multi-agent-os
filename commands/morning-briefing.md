---
name: morning-briefing
description: Deterministic SitRep of operator work state (repos/PRs/tasks/memory) for fast context restore — 7-section briefing by default, --mode=recap for end-of-session N-Tree retrospective with Eisenhower next-tasks.
---

# /morning-briefing Command

Thin wrapper that invokes `skills/morning-briefing/SKILL.md`. The skill holds all
logic (the 5-phase deterministic pipeline, the Compass scope verbs, the recap
mode, i18n cascade, clipboard sink, gitleaks pre-copy guard). This file is the
command surface only.

## Usage

```text
/morning-briefing [--mode=briefing|recap] [--scope=current|down|sideways|up|forward] \
                  [--depth N] [--height N] [--breadth all|N] [--lang <BCP-47>] \
                  [--clipboard] [--save]
```

All flags are optional — bare `/morning-briefing` runs the default 7-section
briefing in the auto-detected language.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--mode` | `briefing` | `briefing` = forward-looking cold-start state · `recap` = end-of-session retrospective (N-Tree objectives · metrics · gaps · pendings · HITL · Eisenhower 2×2 · DAG) |
| `--scope` | `current` | Compass verb: `current` (here/now) · `down` · `sideways` · `up` · `forward` |
| `--depth` / `--height` / `--breadth` | skill defaults | Modifiers on the scope verb |
| `--lang` | auto-detect | BCP-47; 5-step cascade (flag → LC_MESSAGES → LANG → AGENTS.md → en-us) |
| `--clipboard` | off | Copy the rendered briefing to the system clipboard (gitleaks pre-copy guard) |
| `--save` | per skill | Persist the rendered output per the skill's save policy |

Never re-implement briefing logic here — change the skill, not this card.
