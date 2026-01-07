# Multi-Agent OS (multi-agent-os)

A comprehensive framework for orchestrating AI agents in software development workflows.

## Features

### 🛡️ Sentinel Protocol
- 10 detection rules for anomaly prevention
- Loop detection, scope creep, stagnation alerts
- Error cascade prevention

### 📊 Status Map System
- 10 template types for different contexts
- Human-centric observability
- Automatic template inference

### 🔀 Anti-Conflict Protocol v3.1
- 7-phase workflow with mandatory QA
- Git worktree integration
- Lock file coordination

### 📁 Worktree Policy v1.1
- Multi-agent branch isolation
- Catch-22 scenario handling
- Orphan branch cleanup

### 🔄 Hierarchical Merge Protocol v1.0
- Parent-child branch convergence
- Child Completion Constraint (merge only when children complete)
- Exception prefixes for hotfix/emergency scenarios

### 📚 Framework as Source of Truth
- Canonical protocols for multi-agent coordination
- Consumer projects adapt (not duplicate) protocols
- Versioned updates with backward compatibility

## Installation

```bash
# Clone the framework
git clone https://github.com/ekson73/multi-agent-os.git ~/.multi-agent-os

# Run install script
cd ~/.multi-agent-os
./install/install.sh
```

## Usage

After installation, the framework components are available in `~/.claude/`:

- `~/.claude/protocols/` - Coordination protocols
- `~/.claude/sentinel/` - Anomaly detection rules
- `~/.claude/statusmap/` - Observability templates
- `~/.claude/skills/` - Reusable agent skills

## Documentation

| Document | Description |
|----------|-------------|
| [Worktrees Guide](docs/worktrees-guide.md) | Complete guide for multi-agent worktree coordination |
| [Hierarchical Merge Protocol](protocols/hierarchical-merge-protocol.md) | Branch convergence and merge rules |
| [Framework Consumption](docs/framework-consumption.md) | How downstream projects consume this framework |

## License

MIT License - See LICENSE file for details.

---

*Created by Emilson Moraes | Powered by Claude Code*
