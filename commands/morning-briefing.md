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
                  [--clipboard] [--save [path?]] [--save-overwrite]
```

All flags are optional — bare `/morning-briefing` runs the default 7-section
briefing in the auto-detected language, writes nothing to disk (no-save default)
and copies nothing to the clipboard.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--mode` | `briefing` | `briefing` = forward-looking cold-start state · `recap` = end-of-session retrospective (N-Tree objectives · metrics · gaps · pendings · HITL · Eisenhower 2×2 · DAG) |
| `--scope` | `current` | Compass verb: `current` (here/now) · `down` · `sideways` · `up` · `forward` |
| `--depth` / `--height` / `--breadth` | skill defaults | Modifiers on the scope verb |
| `--lang` | auto-detect | BCP-47; 5-step cascade (flag → LC_MESSAGES → LANG → AGENTS.md → en-us) |
| `--clipboard` | off | Copy the rendered briefing **or recap** to the system clipboard (mode-agnostic destination sink; gitleaks pre-copy guard, stdout preserved when no clipboard tool is found) |
| `--save [path?]` | off (no-save default) | Persist the rendered briefing/recap to disk. Optional path; when omitted, the skill resolves the destination via its 4-step cascade (explicit → repo `.claude/sessions/` → AAIF user-scope docs dir → cwd). 5 safety guards incl. no-silent-overwrite and gitleaks pre-write scan |
| `--save-overwrite` | off | Modifier for `--save`: permits replacing an existing target file. Without it, `--save` aborts on an existing path instead of overwriting |

Never re-implement briefing logic here — change the skill, not this card.
