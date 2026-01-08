# Multi-Agent OS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue)](https://github.com/ekson73/multi-agent-os)
[![Sentinel](https://img.shields.io/badge/Sentinel-Protocol-green)](https://github.com/ekson73/multi-agent-os/tree/main/sentinel)

A comprehensive Claude Code plugin for orchestrating AI agents in software development workflows.

## Features

### Sentinel Protocol
- 10 detection rules for anomaly prevention
- Loop detection, scope creep, stagnation alerts
- Error cascade prevention
- Health score calculation

### Status Map System
- 10 template types for different contexts
- Human-centric observability
- Automatic template inference

### Anti-Conflict Protocol v3.2
- 7-phase workflow with mandatory QA
- Git worktree integration
- Lock file coordination

### Worktree Policy v1.1
- Multi-agent branch isolation
- Catch-22 scenario handling
- Orphan branch cleanup

### Hierarchical Merge Protocol v1.0
- Parent-child branch convergence
- Child Completion Constraint
- Exception prefixes for hotfix/emergency

### TTL Policy
- Content freshness management
- PROV tags for provenance tracking
- Automatic expiration alerts

## Installation

### As Claude Code Plugin

```bash
# Clone the plugin
git clone https://github.com/ekson73/multi-agent-os.git

# Install in user scope
claude plugins install /path/to/multi-agent-os

# Or use directly
claude --plugin-dir /path/to/multi-agent-os
```

### Project-Level Installation

Add to your project's `.claude/settings.json`:

```json
{
  "plugins": [
    "/path/to/multi-agent-os"
  ]
}
```

## Plugin Structure

```
multi-agent-os/
├── .claude-plugin/
│   └── plugin.json           ← Plugin manifest
├── hooks/
│   └── hooks.json            ← Hook configuration
├── plugin-scripts/           ← Hook executables
│   ├── session-start.sh
│   ├── pre-delegate.sh
│   ├── post-delegate.sh
│   └── session-end.sh
├── commands/                 ← Slash commands
│   ├── sync.md
│   ├── audit.md
│   ├── status.md
│   ├── worktree.md
│   └── delegate.md
├── agents/                   ← Agent definitions
│   ├── orchestrator.md
│   ├── sentinel-monitor.md
│   ├── qa-validator.md
│   └── consolidator.md
├── skills/                   ← Skills (subdirectory format)
│   ├── audit/SKILL.md
│   ├── agent-select/SKILL.md
│   ├── context-prep/SKILL.md
│   ├── hierarchical-merge/SKILL.md
│   ├── worktree-policy/SKILL.md
│   ├── anti-conflict/SKILL.md
│   ├── status-map/SKILL.md
│   ├── ttl-policy/SKILL.md
│   ├── ontological-analysis/SKILL.md  ← NEW: 8-dimension analysis
│   └── mvv-synthesis/SKILL.md         ← NEW: MVV generation
├── protocols/                ← Protocol documentation
├── sentinel/                 ← Sentinel Protocol files
├── statusmap/                ← Status Map templates
└── docs/                     ← Additional documentation
```

## Available Commands

| Command | Description |
|---------|-------------|
| `/sync` | Sync from framework to consumer |
| `/audit` | On-demand session auditing |
| `/status` | Display status map |
| `/worktree` | Manage git worktrees |
| `/delegate` | Delegate to sub-agent |
| `/mvv` | Generate Mission, Vision, Values |

## Available Skills

| Skill | Description |
|-------|-------------|
| `audit` | Sentinel Protocol auditing |
| `agent-select` | Agent selection algorithm |
| `context-prep` | Pre-delegation context |
| `hierarchical-merge` | Branch merge rules |
| `worktree-policy` | Worktree enforcement |
| `anti-conflict` | Conflict prevention |
| `status-map` | Status visualization |
| `ttl-policy` | Content freshness |
| `ontological-analysis` | 8-dimension philosophical analysis |
| `mvv-synthesis` | Mission/Vision/Values synthesis |

## Available Agents

| Agent | Description |
|-------|-------------|
| `orchestrator` | Master coordinator |
| `sentinel-monitor` | Anomaly detection |
| `qa-validator` | Quality assurance |
| `consolidator` | Output synthesis |

## Hooks

The plugin automatically hooks into Claude Code lifecycle:

| Hook | Trigger |
|------|---------|
| `SessionStart` | Session initialization |
| `PreToolUse[Task]` | Before delegation |
| `PostToolUse[Task]` | After delegation |
| `Stop` | Session end |

## Documentation

| Document | Description |
|----------|-------------|
| [Worktrees Guide](docs/worktrees-guide.md) | Multi-agent worktree coordination |
| [Hierarchical Merge Protocol](protocols/hierarchical-merge-protocol.md) | Branch convergence rules |
| [Framework Consumption](docs/framework-consumption.md) | Consumer project integration |

## Self-Referential Usage

This plugin can use itself during development:

```bash
# In multi-agent-os directory
claude --plugin-dir .
```

## License

MIT License - See LICENSE file for details.

---

*Multi-Agent OS v1.0.0 | Created by Emilson Moraes | Powered by Claude Code*
