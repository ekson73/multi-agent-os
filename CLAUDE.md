# CLAUDE.md - Multi-Agent OS Plugin

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

> **🔗 HERANÇA DE CONTEXTO GLOBAL**
> Antes de iniciar qualquer tarefa, leia e incorpore:
> - `~/.claude/CLAUDE.md` → Diretrizes C01/C02/C03 (Core Directive, Main Instructions, Iterative Loop)
> - `~/Projects/CLAUDE.md` → Contexto do workspace multi-projeto

## Repository Overview

**Multi-Agent OS** is a Claude Code plugin for orchestrating AI agents in software development workflows. It provides:

- **Sentinel Protocol**: Anomaly detection and observability for multi-agent orchestration
- **Status Map System**: Human-readable ASCII status visualizations
- **Anti-Conflict Protocol**: File conflict prevention with git worktrees
- **Hierarchical Merge Protocol**: Branch convergence rules for parent-child relationships
- **TTL Policy**: Content freshness management with provenance tracking

## Plugin Structure

```
multi-agent-os/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (required)
├── hooks/
│   └── hooks.json            # Hook configuration
├── plugin-scripts/           # Hook executables
│   ├── session-start.sh
│   ├── pre-delegate.sh
│   ├── post-delegate.sh
│   ├── session-end.sh
│   └── governance/
│       ├── worktree-gate.sh
│       ├── auto-name-session.sh
│       └── token-budget-gate.sh  # GaaS token bloat detection (RULE-009)
├── commands/                 # Slash commands (auto-discovered)
│   ├── sync.md              # /sync - Framework sync
│   ├── audit.md             # /audit - Session auditing
│   ├── status.md            # /status - Status visualization
│   ├── worktree.md          # /worktree - Worktree management
│   └── delegate.md          # /delegate - Task delegation
├── agents/                   # Agent definitions
│   ├── orchestrator.md      # Master coordinator
│   ├── sentinel-monitor.md  # Anomaly detection
│   ├── qa-validator.md      # Quality assurance
│   └── consolidator.md      # Output synthesis
├── skills/                   # Skills (subdirectory format)
│   ├── audit/SKILL.md       # Sentinel audit skill
│   ├── agent-select/SKILL.md
│   ├── context-prep/SKILL.md
│   ├── hierarchical-merge/SKILL.md
│   ├── worktree-policy/SKILL.md
│   ├── anti-conflict/SKILL.md
│   ├── status-map/SKILL.md
│   ├── ttl-policy/SKILL.md
│   └── response-compression/SKILL.md  # Output verbosity control (caveman lineage)
├── protocols/                # Protocol documentation
│   └── hierarchical-merge-protocol.md
├── sentinel/                 # Sentinel Protocol files
│   ├── config.json          # Detection thresholds
│   ├── detection_rules.md   # 10 detection rules
│   ├── schema/              # JSON schemas
│   │   ├── trace_schema.json
│   │   └── alert_schema.json
│   └── lib/                 # Implementation patterns
├── statusmap/               # Status Map templates
│   ├── templates/           # 9 template types
│   └── inference.md         # Template selection logic
└── docs/                    # Additional documentation
    ├── worktrees-guide.md
    └── framework-consumption.md
```

## Build & Test Commands

```bash
# Validate plugin structure
bash tests/validate-plugin.sh

# Run plugin locally (self-referential)
claude --plugin-dir .

# Install as Claude Code plugin
claude plugins install /path/to/multi-agent-os
```

## Development Guidelines

### Skills Format

Skills use subdirectory format with `SKILL.md` files:

```markdown
---
name: skill-name
description: Brief description
version: 1.0.0
---

# Skill Name

## Purpose
What the skill does

## When to Use
Trigger conditions

## Trigger Phrases
Keywords that invoke this skill

## Protocol Rules
Core rules and constraints
```

### Commands Format

Commands use markdown files with frontmatter:

```markdown
---
name: command-name
description: Brief description
---

# /command-name Command

## Usage
...
```

### Agents Format

Agents define specialized personas:

```markdown
---
name: agent-name
description: Brief description
---

# Agent Name

## Identity
Naming format

## Purpose
What the agent does

## When Invoked
Trigger conditions
```

### Hook Scripts

Hook scripts in `plugin-scripts/` must:
- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Be executable (`chmod +x`)
- Output valid JSON
- Use JSDoc-style comments for documentation

## Naming Conventions

### Agent IDs

| Type | Format | Example |
|------|--------|---------|
| Orchestrator | `Claude-Orch-Prime-{YYYYMMDD}-{4hex}` | `Claude-Orch-Prime-20260106-c614` |
| Sub-agent | `Claude-{Role}-{prime-hex}-{seq}` | `Claude-Dev-c614-001` |
| Parallel | `Claude-{Role}-{prime-hex}-{seq}{a-z}` | `Claude-QA-c614-002a` |

### Branch Names

```
{type}/{scope}-{agent-hex}
```

Types: `feature/`, `bugfix/`, `hotfix/`, `docs/`, `refactor/`, `chore/`

### Worktree Directories

```
.worktrees/{agent-short}-{feature-kebab}/
```

## Key Protocols

### Sentinel Protocol (Observability)

- **10 detection rules** for anomaly prevention
- **Health score** 0-100 based on deductions/bonuses
- **Auto-block** for HIGH severity violations (loops, depth)
- **Trace logging** to `.claude/audit/session_*.jsonl`

### Hierarchical Merge Protocol

- Branches merge to **parent**, not directly to main
- Child Completion Constraint enforced
- Exception prefixes: `bugfix/`, `hotfix/`, `emergency/`

### Anti-Conflict Protocol v3.2

- 7-phase workflow with mandatory worktree
- Lock file coordination for protected files
- Mandatory QA validation before session end

### TTL Policy

- Content expiration by type (14-180 days)
- PROV tags for provenance tracking
- States: FRESH -> EXPIRING -> EXPIRED

## Testing

The validation script checks:
- Required directories exist
- plugin.json valid with required fields
- hooks.json valid
- Hook scripts exist and are executable
- Skills have SKILL.md with correct format
- Commands/agents have frontmatter

## Consumer Projects

This is a **framework** (source of truth). Consumer projects:
- **Reference**, don't duplicate protocols
- Use PROV tags when copying content
- Sync updates via `/sync` command
- Adaptations allowed, modifications go upstream

See `docs/framework-consumption.md` for full guidance.

## MCP Tools: MAOS MCP Hub

The `mcp-tools/maos-mcp-hub/` directory contains a universal MCP gateway exposing Atlassian services through 6 typed meta-tool gateways (VKS-1694). Legacy flat-namespace tools (`bitbucket_*`, `jira_*`) were removed in v1.7. Architecture notes:

- **Bitbucket gateway** (`gateways/bitbucket/actions.py`) imports the handler dict directly: `from servers.bitbucket.tools import TOOLS as BB_TOOLS`.
- **Jira gateway** (`gateways/jira/actions.py`) uses an independent client class `lib.jira.client.JiraClient`; `servers/jira/tools.py` survives as a helper module (exports `_adf_to_markdown` consumed by `lib/jira/cli.py`) but is **not** the gateway's handler source.

### Meta-Tools Gateway

6 Atlassian gateways collapsing 96 actions into typed meta-tools to stay within AI-provider tool limits:

| Tool | Actions | Scope |
|------|---------|-------|
| `atlassian_discover` | -- | Domain catalog |
| `atlassian_jira` | 22 | Issues, boards, estimation, search |
| `atlassian_confluence` | 12 | Pages, comments, spaces |
| `atlassian_bitbucket` | 52 | Pipelines, PRs, branches |
| `atlassian_compass` | 6 | Service registry |
| `atlassian_common` | 4 | User info, server info |

Each gateway accepts `{resource?, operation?, params?}` with 4-level progressive discovery (levels 0–2 = discovery, level 3 = execution). Every response includes `_agent_feedback` with governance hints.

Key framework components in `lib/gateway/`:
- `MetaToolRouter` -- dispatch + discovery routing
- `SchemaRegistry` -- auto-gen typed schemas from handler signatures
- `@with_feedback` -- decorator injecting `_agent_feedback` in every response
- `GatewayRequest` -- 4-level request parser (0=resources, 1=operations, 2=schema, 3=execute)

See `mcp-tools/maos-mcp-hub/README.md` for full documentation.

## Delegation Protocol

Sub-agent spawning (Task tool, `/delegate`, `/parallel`) is governed by the GaaS/GaaC framework under `protocols/delegation/`:

- `delegation-init-prompt.md` — emit before spawning (provider detection, Phase-1 Anti-Conflict, output contract)
- `delegation-dna-prompt.md` — emit mid-flight (token watchdog, TTL check, escalation rule)
- `delegation-finalize-prompt.md` — emit at close (cleanup, ticket/PR closure, learning codification)
- `provider-matrix.md` — lookup table (Ticket × VCS × Secrets × Observability × operation)

Entry points: skill `delegate-governance` (discoverable) + CLI `plugin-scripts/gaac/delegate.sh <init|dna|finalize>`. See `skills/delegate-governance/SKILL.md`.

## Known Issues & TODOs

### Critical Issues (P0)
- None - plugin validates successfully

### Improvements (P1)
- [x] Add CHANGELOG.md for version tracking (completed 2026-01-08)
- [x] Add version-sync GitHub Action (completed 2026-01-08)
- [ ] Add example consumer project
- [ ] Add automated TTL checking script
- [ ] Add Prometheus metrics export

### Future (P2)
- [ ] Visual dashboard for Status Maps
- [ ] OpenTelemetry native export
- [ ] Cost/token tracking in Sentinel

## NOT-TODOs (Intentional Design Decisions)

- **No CLAUDE.md file in root initially**: Claude Code plugins don't require it, but we add for AI agent guidance
- **No install.sh scripts**: Use Claude Code plugin system instead (`claude plugins install`)
- **No marketplace.json**: Moved to separate registry repository

## MUST / MUST-NOT Rules

### MUST

- Use worktree for any file modifications
- Sign documents with agent ID and timestamp
- Validate plugin structure before committing
- Follow hierarchical merge (to parent, not main)
- Include frontmatter in commands/agents/skills
- Use ISO 8601 dates everywhere

### MUST NOT

- Merge directly to main from subtask branches
- Commit without running validation script
- Create duplicate protocols (reference framework instead)
- Skip QA validation before session end
- Edit protected files without lock file
- Use relative dates or ambiguous formats

## References

- [Claude Code Plugins Documentation](https://docs.anthropic.com/claude-code/plugins)
- [OpenTelemetry AI Agent Observability](https://opentelemetry.io/blog/2025/ai-agent-observability/)
- [Git Worktrees](https://git-scm.com/docs/git-worktree)

---

## Organizational Identity (MVV)

### Mission (A Práxis)

> **Prover um framework de orquestração para agentes AI em ambientes de desenvolvimento de software, através de protocolos formalizados de coordenação, observabilidade embutida e prevenção de conflitos, para resolver o problema de múltiplos agentes trabalhando em paralelo no mesmo repositório sem colidir, entrar em loops, ou perder visibilidade.**

### Vision (A Teleologia)

> **Tornar-se o padrão de facto para orquestração de agentes AI em desenvolvimento de software, onde qualquer equipe que use múltiplos AI agents possa adotar este framework como "sistema operacional" para coordenação, assim como Kubernetes é o padrão para orquestração de containers.**

### Values (A Ética)

| Value | Description |
|-------|-------------|
| **Protocol-First** | Behaviors governed by documented protocols, not implicit conventions |
| **Human Observability** | Automated systems always provide visibility for humans, not just machine logs |
| **Source of Truth Discipline** | Single source of truth per concept, with expiration and sync mechanisms |
| **Defensive Automation** | Automation detects and blocks anomalous behaviors before causing damage |
| **Hierarchical Convergence** | Parallel work converges through controlled hierarchies, not direct merges |

---

*MVV extracted via ontological analysis by Claude-Analyst-eed7-001 | 2026-01-08*

---

*Multi-Agent OS v1.14.0 | Plugin for Claude Code*
*Analysis by: Claude-Analyst-c614-plugin | 2026-01-08T21:30:00-03:00*

## Branching & Release Model

**GitHub Flow (Class B — library/marketplace).** Canonical SSOT: [`AGENTS.md`](./AGENTS.md) §"Branching & Release Model" + `docs/adrs/ADR-004-github-flow-branching.md`. No environment branches here; source-pin = float per ADR-003.
