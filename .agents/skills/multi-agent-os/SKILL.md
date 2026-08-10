---
name: multi-agent-os-repo
description: >-
  How to work on the multi-agent-os (MAOS) repository itself — layout (skills/,
  agents/, commands/, packaging/), Agent Skills standard, Claude plugin + Pi
  package + OpenCode thin plugin entrypoints, tests, and contribution norms.
  Use when contributing to MAOS, packaging for multi-harness, or debugging
  npx skills / marketplace installs of this repo.
---

# Working on multi-agent-os (MAOS)

## Domain
This repository is the **product** (agentic-tools). Distribution index is
`ekson73/eko-claude-plugins` (target name eko-plugin-marketplace) — do not
vendor skills into eko.

## Layout (high signal)
| Path | Role |
|---|---|
| `skills/*/SKILL.md` | Agent Skills corpus (portable via `npx skills`) |
| `agents/` | Subagent definitions |
| `commands/` | Slash commands (Claude plugin) |
| `.claude-plugin/plugin.json` | Claude marketplace plugin manifest (`maos`) |
| `package.json` | Pi package (`pi.skills`) |
| `packaging/opencode-maos/` | OpenCode thin plugin |
| `docs/multi-host-packaging.md` | Multi-host install matrix |

## Install (consumers)
```bash
# Portable (many harnesses)
npx skills add ekson73/multi-agent-os -g -a '*' -y

# Claude
# /plugin marketplace add ekson73/eko-claude-plugins
# /plugin install maos@eko-claude-plugins

# Pi
pi install git:github.com/ekson73/multi-agent-os@main
```

## Skill authoring rules
Every `SKILL.md` **must** start with YAML frontmatter containing at least:
```yaml
---
name: my-skill-id
description: When to use this skill (trigger-oriented, one paragraph).
---
```
`npx skills` **skips** files missing `name` / `description`.

## Tests / quality
Follow repo `AGENTS.md` / `CONTRIBUTING.md`. Run project test-runner before commit.
Do not invent marketplace formats for hosts eko marks `n/a`.

