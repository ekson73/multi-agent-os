# Multi-Agent OS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![AI Agnostic](https://img.shields.io/badge/AI-Agnostic-purple)](https://github.com/ekson73/multi-agent-os)
[![Version](https://img.shields.io/badge/Version-1.6.0-blue)](https://github.com/ekson73/multi-agent-os)
[![AAIF Aligned](https://img.shields.io/badge/AAIF-Aligned-orange)](https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation)
[![MCP Native](https://img.shields.io/badge/MCP-Native-green)](https://modelcontextprotocol.io)
[![Sentinel](https://img.shields.io/badge/Sentinel-Protocol-green)](https://github.com/ekson73/multi-agent-os/tree/main/sentinel)

An open-source, AI-agnostic framework for orchestrating multi-agent software development workflows with formalized governance, observability, and conflict prevention.

> **Native by Design**: Built from inception on the pillars of provider-agnosticism, protocol-first governance, and open interoperability — not retrofitted from a single-vendor tool.

---

## Architecture Pillars

Multi-Agent OS is founded on 9 architectural pillars that ensure it works across any AI provider, any organization, and any project:

| # | Pillar | Description | Implementation |
|---|--------|-------------|----------------|
| 1 | **AGENTS.md** | Universal project instructions standard (AAIF) | All protocols are Markdown-native, `AGENTS.md`-compatible — 24+ AI tools read natively |
| 2 | **MCP-HUB** (Model Context Protocol) | Tool and data connectivity layer for AI agents | `mcp-tools/maos-mcp-hub/` — AAIF/Linux Foundation standard (donated by Anthropic) |
| 3 | **A2A Protocol** (Agent-to-Agent) | Inter-agent communication and coordination | `protocols/agent-delegation.md`, `protocols/rbad.md` — aligned with Google A2A patterns |
| 4 | **ACP** (Agent Communication Protocol) | IDE-agent interaction standard | `commands/`, `skills/`, `hooks/` — compatible with JetBrains/Zed ACP standard |
| 5 | **GaaS** (Governance-as-a-Service) | **The guarantor pillar** — physical enforcement via hooks + CI/CD + Policy-as-Code | `.githooks/`, `sentinel/`, `rules/` — the only pillar agents cannot ignore ([manifesto](docs/gaas-architecture-manifesto.md)) |
| 6 | **Direct-Raw-URLs Ready** | Zero-install context injection via GitHub Raw URLs | `docs/RAW_URL_INJECTION.md` — any AI agent fetches governance on-demand |
| 7 | **Multi-Agent** | Native support for N concurrent agents in parallel | `docs/git-worktree-protocol.md`, `protocols/hierarchical-merge-protocol.md` |
| 8 | **AI-Agnostic** | Provider, LLM, and agent CLI agnostic | All protocols are Markdown/JSON — consumable by any LLM or agentic tool |
| 9 | **Company/Org-Agnostic** | No corporate assumptions baked in | Framework adapts to any org via consumer model (`docs/framework-consumption.md`) |

### GaaS: The Guarantor Pillar

> All other 8 pillars are *advisory* — the agent can ignore them. GaaS is the only pillar that is **physical enforcement**. An `exit code 1` from a git hook is a deterministic fact, not a probabilistic suggestion.

```
Markdown instructions = suggestions (the LLM may ignore)
exit code + stderr    = facts (the LLM cannot circumvent)
```

**3 Enforcement Motors:**

| Motor | Layer | What it blocks | Bypassable? |
|-------|-------|----------------|-------------|
| **Git Hooks** | Local terminal | Commits on main, bad branch names | Only via `--no-verify` |
| **CI/CD Pipeline** | Cloud (PR) | PII leaks, missing co-author, failed review | No (branch protection) |
| **Policy-as-Code** | Cloud (OPA/Rego) | Schema violations, security misconfigs | No (boolean evaluation) |

The AI reads `stderr`, recognizes the error, and self-corrects in a loop — **learning from infrastructure without human intervention**. This is Zero-Trust for hybrid teams (Humans + AIs).

Full manifesto: [`docs/gaas-architecture-manifesto.md`](docs/gaas-architecture-manifesto.md)

### Agnosticism in Detail

```
AI-Agnostic means:
├── AI-Provider-Agnostic    → Works with OpenAI, Anthropic, Google, Meta, Mistral, etc.
├── LLM-Agnostic            → Works with any model: GPT-4o, Claude, Gemini, Llama, DeepSeek, Qwen, etc.
├── AI-Agent-CLI-Agnostic   → Works with: Claude Code, Codex CLI, Cursor, Windsurf, Copilot,
│                              Gemini CLI, Aider, OpenHands, Zed, Goose, RooCode/Cline, Warp, etc.
└── Company/Org-Agnostic    → No Vek, no Acme — adapts to ANY organization via consumer model
```

### Alignment with Industry Standards (AAIF / Linux Foundation)

In December 2025, the Linux Foundation established the **Agentic AI Foundation (AAIF)** with three cornerstone projects. Multi-Agent OS aligns natively with all three:

| AAIF Project | Origin | Multi-Agent OS Integration |
|--------------|--------|---------------------------|
| **MCP** | Anthropic | `mcp-tools/maos-mcp-hub/` — native MCP server hub |
| **AGENTS.md** | OpenAI | All protocols are Markdown-native, AGENTS.md-compatible |
| **goose** | Block | Compatible runtime via StdIO/SSE MCP transport |

### How Agents Consume This Framework

```
┌──────────────────────────────────────────────────────────────────┐
│  CONSUMPTION METHODS (pick one or combine)                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. RAW URL INJECTION (zero-install, any AI provider)           │
│     Agent fetches governance on-demand from GitHub Raw URLs      │
│     → Works with ANY tool that can fetch URLs                    │
│                                                                  │
│  2. CLAUDE CODE PLUGIN (native hooks + commands)                │
│     claude plugins install /path/to/multi-agent-os               │
│     → Deepest integration: hooks, commands, skills, agents       │
│                                                                  │
│  3. AGENTS.md REFERENCE (emerging standard)                     │
│     Include Raw URLs in your project's AGENTS.md                │
│     → 24+ AI tools read AGENTS.md natively                      │
│                                                                  │
│  4. SUBMODULE / CLONE (full local access)                       │
│     git submodule add ... .multi-agent-os                        │
│     → Version-locked, offline-capable                            │
│                                                                  │
│  5. MCP SERVER (tool connectivity)                              │
│     Register maos-mcp-hub as MCP server in any MCP-aware tool  │
│     → Works with Claude, ChatGPT, Copilot, Gemini, VS Code     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

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

*Multi-Agent OS v1.6.0 | Created by Emilson Moraes | Native by Design: AI-Agnostic, Multi-Agent, Protocol-First*
