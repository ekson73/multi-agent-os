# Multi-Agent OS Agents

## Overview

Agent definitions for the multi-agent-os plugin. These define specialized personas that can be spawned by the orchestrator.

## Available Agents

| Agent | File | Description |
|-------|------|-------------|
| orchestrator | `orchestrator.md` | Master coordinator |
| sentinel-monitor | `sentinel-monitor.md` | Anomaly detection |
| qa-validator | `qa-validator.md` | Quality assurance |
| consolidator | `consolidator.md` | Output synthesis |

## Agent Categories

### Coordination
- `orchestrator` — Root agent, manages delegation

### Observability
- `sentinel-monitor` — Background monitoring

### Quality
- `qa-validator` — Validation before completion

### Synthesis
- `consolidator` — Merge parallel outputs

## Agent Naming Convention

### Orchestrator
```
Claude-Orch-Prime-{YYYYMMDD}-{4-hex}
```

### Sub-Agents
```
Claude-{Role}-{prime-hex}-{sequence}
```

### Parallel Agents
```
Claude-{Role}-{prime-hex}-{sequence}{a-z}
```

## Agent Structure

Each agent file uses frontmatter:

```markdown
---
name: agent-name
description: Brief description
---

# Agent Name

## Identity
[Naming format]

## Purpose
[What the agent does]

## When Invoked
[Trigger conditions]

## Capabilities
[What it can do]

## Output Format
[Expected output structure]
```

## Spawning Agents

Agents are spawned via the Task tool:

```
Task(subagent_type="general-purpose", task="...")
```

Note: The frontmatter `name` is a conceptual identifier. Use actual Task tool types (general-purpose, code-reviewer, etc.) for spawning.

## Agent Hierarchy

```
Orchestrator (root)
├── Sentinel Monitor (background)
├── Sub-Agent 1
│   └── Sub-Sub-Agent 1.1 (max depth 3)
├── Sub-Agent 2
└── Consolidator (synthesis)
```

---

*Part of multi-agent-os plugin v1.0.0*
