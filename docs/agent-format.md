# Agent Format Specification

## YAML Frontmatter

All agent definition files in MAOS use YAML frontmatter for routing and discovery.

### Required Fields

```yaml
---
name: string          # Agent identifier (kebab-case). Used in Task(subagent_type=)
description: string   # What the agent does. Used for keyword-based routing.
---
```

### Optional Fields

```yaml
---
name: string
description: string
version: string       # Semver (e.g., "1.0.0")
icon: string          # Emoji identifier (e.g., "🔨")
tools: list           # Claude Code tools the agent needs
                      # Valid: Read, Write, Edit, MultiEdit, Grep, Glob, LS, Bash,
                      #        WebSearch, WebFetch, NotebookRead, NotebookEdit
agnostic: list        # Platform independence markers: [os, project]
created_at: string    # ISO 8601 timestamp
---
```

### Compatibility

Existing agents with minimal frontmatter (`name` + `description` only) continue to work.
Extended fields are additive — they enhance routing and documentation without breaking anything.

### Examples

**Minimal (always valid)**:
```yaml
---
name: orchestrator
description: Master orchestrator for multi-agent coordination and task delegation
---
```

**Extended (recommended for complex agents)**:
```yaml
---
name: forge
version: 1.0.0
icon: 🔨
description: >
  Meta-agent that creates, evaluates, and evolves specialized AI agents.
  Use Forge when no existing agent fits the task.
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Edit
  - WebSearch
agnostic: [os, project]
---
```

---

*MAOS Agent Format v1.0.0 | 2026-03-13*
