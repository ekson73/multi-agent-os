# Multi-host packaging

| Host | Entrypoint | Status |
|---|---|---|
| Claude Code | `.claude-plugin/plugin.json` + eko marketplace | ready |
| Pi | root `package.json` (`pi.skills`) | ready (`pi install git:…`) |
| OpenCode | `packaging/opencode-maos/` | ready (thin plugin + skills) |
| Codex / Copilot / Kiro / Gemini / Warp / … | [Agent Skills](https://agentskills.io) via `npx skills` | docs |

## Domain
| Repo | Role |
|---|---|
| **multi-agent-os** (this) | **Product** — skills, agents, commands, packaging |
| **eko-claude-plugins** | **Index** — catalog + host docs only |

Discovery / research council (2026-08):  
https://github.com/ekson73/eko-claude-plugins/blob/main/docs/research/HOST-RESEARCH-2026-08.md

## Install matrix

### Portable (recommended multi-harness bridge)
```bash
npx skills add ekson73/multi-agent-os -g -a '*' -y
```
Requires each `SKILL.md` to have YAML `name` + `description` (see `scripts/validate-skill-frontmatter.sh`).

### Native
| Host | Command |
|---|---|
| Claude | `/plugin marketplace add ekson73/eko-claude-plugins` then `/plugin install maos@eko-claude-plugins` |
| Pi | `pi install git:github.com/ekson73/multi-agent-os@main` |
| OpenCode | copy/curl `packaging/opencode-maos/index.js` → `~/.config/opencode/plugins/maos.js` **and/or** skills CLI |

### Explicit skills agent ids (when known)
```bash
npx skills add ekson73/multi-agent-os -g -a codex
npx skills add ekson73/multi-agent-os -g -a opencode
npx skills add ekson73/multi-agent-os -g -a claude-code
npx skills add ekson73/multi-agent-os -g -a gemini-cli
npx skills add ekson73/multi-agent-os -g -a github-copilot
npx skills add ekson73/multi-agent-os -g -a kiro
```
If an id is rejected by your `skills` CLI version, use `-a '*'`.

## Not in this repo’s job
- Publishing ChatGPT store / VS Code VSIX / Open VSX / Grok packs as MAOS core
- Hosting a multi-vendor “app store” UI (that’s eko’s index role, Claude-only mall)

## Validate
```bash
npm run validate:skills
# or
bash scripts/validate-skill-frontmatter.sh
```
