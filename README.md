# Multi-Agent OS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-1.8.0-blue)](https://github.com/ekson73/multi-agent-os)
[![Sentinel](https://img.shields.io/badge/Sentinel-Protocol-green)](https://github.com/ekson73/multi-agent-os/tree/main/sentinel)
[![Branching: GitHub Flow](https://img.shields.io/badge/branching-GitHub%20Flow%20(Class%20B)-0a7bbb)](./AGENTS.md)

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

### Statusline Auto-install
- Automatic statusline template installation
- Settings.json auto-configuration
- Checksum-based update detection

### Hierarchical Merge Protocol v1.0
- Parent-child branch convergence
- Child Completion Constraint
- Exception prefixes for hotfix/emergency

### TTL Policy
- Content freshness management
- PROV tags for provenance tracking
- Automatic expiration alerts

### MVV Generator (v1.1.0)
- 8-dimension ontological analysis (Context, Purpose, Taxonomy, Semantics, Lineage, Epistemology, Ontology, Aesthetics)
- Mission/Vision/Values synthesis pipeline
- Automated organizational identity extraction
- `/mvv` command for one-shot execution

## Installation

### From Marketplace (Recommended)

```bash
# Add the marketplace
claude plugins marketplace add ekson73/eko-claude-plugins

# Install the plugin
claude plugins install multi-agent-os
```

### From Source

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
│   ├── session-end.sh
│   └── governance/
│       ├── worktree-gate.sh
│       ├── auto-name-session.sh
│       └── token-budget-gate.sh  ← GaaS token bloat detection
├── commands/                 ← Slash commands
│   ├── sync.md
│   ├── audit.md
│   ├── status.md
│   ├── worktree.md
│   └── delegate.md
├── agents/                   ← Agent definitions (9 agents)
│   ├── orchestrator.md
│   ├── sentinel-monitor.md
│   ├── qa-validator.md
│   ├── consolidator.md
│   ├── forge.md              ← Meta-agent creator (Goldilocks + RBAD + 33 Socratic Questions)
│   ├── governance-auditor.md ← Standards & compliance guardian
│   ├── naming-organizer.md   ← Digital organization & taxonomy
│   ├── data-validator.md     ← Truth & evidence verification (11 validation types)
│   └── validation-auditor.md ← Second-line active auditing
├── skills/                   ← Skills (subdirectory format)
│   ├── audit/SKILL.md
│   ├── agent-select/SKILL.md
│   ├── context-prep/SKILL.md
│   ├── hierarchical-merge/SKILL.md
│   ├── worktree-policy/SKILL.md
│   ├── anti-conflict/SKILL.md
│   ├── status-map/SKILL.md
│   ├── ttl-policy/SKILL.md
│   ├── ontological-analysis/SKILL.md  ← 8-dimension analysis
│   ├── mvv-synthesis/SKILL.md         ← MVV generation
│   └── response-compression/SKILL.md  ← Output verbosity control
├── protocols/                ← Governance protocols
│   ├── exit-hygiene.md       ← Session exit hygiene (zero loose ends)
│   ├── agent-delegation.md   ← Delegation chain & Forge bootstrap
│   ├── rbad.md               ← Role-Based Agent Design (6-category taxonomy)
│   └── action-priority.md    ← Eisenhower Matrix for task prioritization
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
| `response-compression` | Output verbosity control (none/lite/full/ultra) with role-based profiles |

## Available Agents

| Agent | Description |
|-------|-------------|
| `orchestrator` | Master coordinator |
| `sentinel-monitor` | Anomaly detection |
| `qa-validator` | Quality assurance |
| `consolidator` | Output synthesis |
| `forge` | Meta-agent creator — creates specialized agents using Goldilocks Principle + RBAD |
| `governance-auditor` | Standards governance, compliance auditing, pattern enforcement |
| `naming-organizer` | Digital organization, taxonomy, naming conventions |
| `data-validator` | Data validation, evidence capture, truth verification (11 types) |
| `validation-auditor` | Second-line active auditing, drift detection, integrity verification |

## Hooks

The plugin automatically hooks into Claude Code lifecycle:

| Hook | Trigger | Scripts |
|------|---------|---------|
| `SessionStart` | Session initialization | session-start.sh, auto-name-session.sh |
| `PreToolUse[Task]` | Before delegation | pre-delegate.sh, token-budget-gate.sh |
| `PreToolUse[Bash]` | Before shell commands | worktree-gate.sh |
| `PostToolUse[Task]` | After delegation | post-delegate.sh |
| `Stop` | Session end | session-end.sh |

## Documentation

| Document | Description |
|----------|-------------|
| [Worktrees Guide](docs/worktrees-guide.md) | Multi-agent worktree coordination |
| [Hierarchical Merge Protocol](protocols/hierarchical-merge-protocol.md) | Branch convergence rules |
| [Framework Consumption](docs/framework-consumption.md) | Consumer project integration |
| [Agent Format](docs/agent-format.md) | YAML frontmatter specification for agents |
| [Exit Hygiene](protocols/exit-hygiene.md) | Session exit protocol (zero loose ends) |
| [Agent Delegation](protocols/agent-delegation.md) | Delegation chain & Forge bootstrap |
| [RBAD](protocols/rbad.md) | Role-Based Agent Design taxonomy |
| [Action Priority](protocols/action-priority.md) | Eisenhower Matrix for prioritization |

## Self-Referential Usage

This plugin can use itself during development:

```bash
# In multi-agent-os directory
claude --plugin-dir .
```

## Interoperability

Skills in this plugin follow the [Agent Skills open standard](https://agentskills.io) and are compatible with 30+ AI coding tools including Claude Code, Cursor, OpenAI Codex, Gemini CLI, Kiro, VS Code, GitHub Copilot, Goose, Windsurf, and others. Install with `npx skills add` or native plugin mechanisms.

This repository includes an [AGENTS.md](AGENTS.md) file following the [AAIF standard](https://agents.md) (60k+ projects) to guide any AI coding agent working on this codebase.

## License

MIT License - See LICENSE file for details.

---

*Multi-Agent OS v1.8.0 | Created by Emilson Moraes | Powered by Claude Code*
