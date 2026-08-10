# opencode-maos

Thin [OpenCode](https://opencode.ai/docs/plugins/) plugin entry for **MAOS** (`multi-agent-os`).

## Install

### A — Local plugin file (no npm publish)
```bash
mkdir -p ~/.config/opencode/plugins
curl -fsSL -o ~/.config/opencode/plugins/maos.js \
  https://raw.githubusercontent.com/ekson73/multi-agent-os/main/packaging/opencode-maos/index.js
```
Restart OpenCode.

### B — npm package (when published)
```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-maos"]
}
```

### Skills (agentic-tools — not this package’s job)
```bash
npx skills add ekson73/multi-agent-os -g -a opencode
```

## Scope
This package is a **runtime entrypoint**, not a dump of MAOS skills/agents/hooks.
