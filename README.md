# Multi-Agent OS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-1.13.0-blue)](https://github.com/ekson73/multi-agent-os)
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

> **Plugin name vs repo name**: the repository is `multi-agent-os`; the **plugin is named `maos`** (see `.claude-plugin/plugin.json`). Install and reference it as `maos`. Skills/commands surface namespaced as **`/maos:<name>`** (e.g. `/maos:orchestrator`, `/maos:auto-pilot`).

### From Marketplace (recommended)

Plugin management runs **inside a Claude Code session** via the `/plugin` command (not a shell `claude plugins` subcommand):

```text
/plugin marketplace add ekson73/eko-claude-plugins
/plugin install maos@eko-claude-plugins
/reload-plugins
```

Then run `/plugin` (Installed tab) to confirm, and `/help` to see the `/maos:*` skills. Need to update later? `/plugin marketplace update eko-claude-plugins`.

### From source (local dev / self-use)

```bash
git clone https://github.com/ekson73/multi-agent-os.git
claude --plugin-dir ./multi-agent-os     # load for this session
claude plugin validate ./multi-agent-os  # validate the manifest
```

`--plugin-dir` may be repeated to load several plugins and takes precedence over an installed copy of the same name (handy for testing local changes). See [Self-Referential Usage](#self-referential-usage).

### Project / team scope

To make `maos` available to **everyone on a repository**, add to that project's `.claude/settings.json` (collaborators are prompted to install when they trust the folder):

```json
{
  "extraKnownMarketplaces": {
    "eko-claude-plugins": {
      "source": { "source": "github", "repo": "ekson73/eko-claude-plugins" }
    }
  },
  "enabledPlugins": ["maos@eko-claude-plugins"]
}
```

CLI equivalent (writes project scope): `claude plugin install maos@eko-claude-plugins --scope project`. Full schema: [Plugin settings](https://code.claude.com/docs/en/settings#plugin-settings).

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
├── commands/                 ← Slash commands (~15; representative subset shown)
│   ├── sync.md
│   ├── audit.md
│   ├── agentic-status.md
│   ├── worktree.md
│   └── delegate.md
├── agents/                   ← Agent definitions (20+; representative subset shown)
│   ├── orchestrator.md
│   ├── sentinel-monitor.md
│   ├── qa-validator.md
│   ├── consolidator.md
│   ├── forge.md              ← Meta-agent creator (Goldilocks + RBAD + 33 Socratic Questions)
│   ├── governance-auditor.md ← Standards & compliance guardian
│   ├── naming-organizer.md   ← Digital organization & taxonomy
│   ├── data-validator.md     ← Truth & evidence verification (11 validation types)
│   └── validation-auditor.md ← Second-line active auditing
├── skills/                   ← Skills (40+, subdirectory format; representative subset shown)
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

> Namespaced as `/maos:<name>`. This table is **representative** — run `/help` for the full live list, or `/maos:maos-concierge` to be guided to the right command/agent/skill for your intent.

| Command | Description |
|---------|-------------|
| `/maos:agentic-status` | Human-readable status of the agentic system (git + agents + sentinel + locks). *(Was `/status` — renamed to avoid colliding with Claude Code's built-in `/status`.)* |
| `/maos:sync` | Sync content from the framework to a consumer project |
| `/maos:audit` | On-demand audit of sessions, tasks, and orchestration flows |
| `/maos:worktree` | Manage git worktrees for multi-agent isolation |
| `/maos:delegate` | Delegate a task to a specialized sub-agent with context prep |
| `/maos:mvv` | Generate/update Mission, Vision, Values for a repository |
| `/maos:auto-pilot` | Drive an operator goal end-to-end across sub-agents (GaaS/GaaC) |
| `/maos:quiesce` | Drive the session to quiescence — no open ticket/gap/fix/PR, all PRs green |
| `/maos:enhance-pipeline` | Run one feature through the full divergent→convergent→deliver lifecycle |
| `/maos:founder-playbook` | Diagnose an AI-native startup's lifecycle stage and route to the right discipline |
| `/maos:agentic-tool-forge` | Forge a raw intent into the optimal reusable agentic-tool |
| `/maos:session-fission` | Non-destructively split a tangled session into focused new ones |

Plus namespaced utilities (`/maos:auto-shard`, `/maos:code:*`, `/maos:analyze:*`) — see `/help`.

## Available Skills

> **40+ skills** ship with MAOS — the table below is a **representative subset**. Model-invoked (Claude auto-selects by task) or explicit via `/maos:<skill>`. For the full live catalog and guidance on which to use, invoke `/maos:maos-concierge`.

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
| `maos-concierge` | Onboarding/router/anchor for the **entire** MAOS framework (start here) |
| `auto-pilot` / `quiesce` / `converge` / `convergence-engine` | Autonomous orchestration, session quiescence, and multi-proposal convergence |
| `enhance-pipeline` | Divergent→convergent→deliver feature lifecycle |
| `agentic-delegation` / `delegate-governance` | Delegation criteria + GaaS/GaaC governance prompts |
| `agentic-tool-forge` / `-evaluator` / `-trainer` | Create, evaluate, and improve reusable agentic-tools |
| `anima` | Sovereign precision-naming engine — names anything (12 correctness + 4 resonance aspects, register-aware); the forge's Phase-4 naming delegate + standalone |
| `founder-playbook` / `founder-stage-*` | AI-native startup lifecycle disciplines (Idea/MVP/Launch/Scale) |
| `morning-briefing` / `pulse` / `session-fission` | Context restoration, re-orientation, session splitting |
| `rule-quality-tests` / `operator-quote-capture` / `pii-masking` / `slm-routing` | Governance, capture, PII detection, model routing |

## Available Agents

> **20+ agents** ship with MAOS — representative subset below. Invoke via the `Task` tool (`subagent_type: maos:<agent>`) or see `/agents`.

| Agent | Description |
|-------|-------------|
| `orchestrator` | Master coordinator |
| `sentinel-monitor` | Anomaly detection |
| `qa-validator` | Quality assurance |
| `consolidator` | Output synthesis |
| `forge` | Meta-agent creator — specialized agents via Goldilocks Principle + RBAD |
| `governance-auditor` | Standards governance, compliance auditing, pattern enforcement |
| `naming-organizer` | Digital organization, taxonomy, naming conventions |
| `data-validator` | Data validation, evidence capture, truth verification (11 types) |
| `validation-auditor` | Second-line active auditing, drift detection, integrity verification |
| `cascade-resolver` / `perspective-trio` / `persona-pipeline` | Convergence engine primitives — score-uplift, orthogonal-trio, review-board |
| `code-reviewer` / `debugger` | Code review and systematic debugging specialists |
| `data-analyst` / `legacy-archaeologist` / `memory-curator` | Analysis, legacy reverse-engineering, memory hygiene |
| `gitops-engineer` / `founder-coach` / `consultants` | GitOps/K8s, startup coaching, expert thinking-archetypes |

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

*Multi-Agent OS v1.13.0 | Created by Emilson Moraes | Powered by Claude Code*
