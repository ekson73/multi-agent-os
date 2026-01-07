# Multi-Agent OS Commands

## Overview

Slash commands for the multi-agent-os plugin. Commands are auto-discovered by Claude Code from this directory.

## Available Commands

| Command | File | Description |
|---------|------|-------------|
| `/sync` | `sync.md` | Sync content from framework to consumer |
| `/audit` | `audit.md` | On-demand session/agent/task auditing |
| `/status` | `status.md` | Display human-readable status maps |
| `/worktree` | `worktree.md` | Manage git worktrees |
| `/delegate` | `delegate.md` | Delegate tasks to sub-agents |

## Command Categories

### Synchronization
- `/sync` — Keep consumer projects updated with framework

### Observability
- `/audit` — Deep analysis via Sentinel Protocol
- `/status` — Quick visual status check

### Coordination
- `/worktree` — Git worktree management
- `/delegate` — Sub-agent task delegation

## Command Structure

Each command file uses frontmatter:

```markdown
---
name: command-name
description: Brief description
---

# /command-name Command

[Documentation...]
```

## Usage

Commands are invoked in Claude Code conversations:

```
/sync all
/audit session
/status
/worktree create c614-feature
/delegate analyst "Review the requirements"
```

## Adding New Commands

1. Create `{name}.md` in this directory
2. Add frontmatter with `name` and `description`
3. Document usage, options, and examples
4. Commands are auto-discovered on plugin load

---

*Part of multi-agent-os plugin v1.0.0*
