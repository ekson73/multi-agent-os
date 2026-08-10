# Multi-host packaging

| Host | Entrypoint | Status |
|---|---|---|
| Claude Code | `.claude-plugin/plugin.json` + eko marketplace | ready |
| Pi | root `package.json` (`pi.skills`) | ready for `pi install git:…` |
| OpenCode | `packaging/opencode-maos/` | ready (thin plugin + skills via npx skills) |
| Codex / others | Agent Skills via `npx skills add ekson73/multi-agent-os` | docs |

Discovery hub: `ekson73/eko-claude-plugins` (target name **eko-plugin-marketplace**).

## Discovery index (eko) — research 2026-08
- https://github.com/ekson73/eko-claude-plugins/blob/main/docs/research/HOST-RESEARCH-2026-08.md
- Compat: MULTI-HARNESS-COMPAT.md in eko
- Portable: `npx skills add ekson73/multi-agent-os -g -a '*' -y`
