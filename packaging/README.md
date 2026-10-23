# Packaging entrypoints (multi-host)

| Path | Host | Install |
|---|---|---|
| Root [`package.json`](../package.json) | **Pi** | `pi install git:github.com/ekson73/multi-agent-os@main` |
| [`opencode-maos/`](./opencode-maos/) | **OpenCode** | local plugin file or npm `opencode-maos` |
| `.claude-plugin/` | **Claude Code** | via plugin-marketplace / `maos@plugin-marketplace` |

Product content (skills, etc.) stays in-repo roots; these manifests only expose host loaders.

Skills frontmatter gate: `npm run validate:skills` (Agent Skills / skills.sh compatibility).
