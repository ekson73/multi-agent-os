---
name: delegate
description: Delegate task to specialized sub-agent with proper context preparation
---

# /delegate Command

Delegates a task to a specialized sub-agent with automatic context preparation and anti-loop validation.

## Usage

```
/delegate <agent-type> "<task>"
```

## Agent Types

| Agent | Expertise |
|-------|-----------|
| `analyst` | Requirements, gaps, specs |
| `architect` | System design, dependencies |
| `dev` | Code, tests, implementation |
| `pm` | Planning, risks, timeline |
| `po` | Prioritization, value, scope |
| `qa` | Testing, validation, quality |
| `devops` | CI/CD, infrastructure |
| `editor` | Documentation, terminology |
| `consolidator` | Synthesis, merging outputs |
| `forge` | Meta-agent creator — creates specialized agents on demand |
| `governance-auditor` | Standards governance, compliance auditing, pattern enforcement |
| `naming-organizer` | Digital organization, taxonomy, naming conventions |
| `data-validator` | Data validation, evidence capture, truth verification |
| `validation-auditor` | Second-line active auditing, drift detection, integrity verification |

## Examples

```
/delegate analyst "Analyze VKS-550 for MVP inclusion"
/delegate qa "Validate the plugin proposal"
/delegate consolidator "Merge outputs from all agents"
```

## Parallel Delegation

```
/parallel analyst,architect,pm "Analyze the roadmap from multiple perspectives"
```

## Workflow

1. **Agent Selection** — Validate agent type
2. **Anti-Loop Check** — Ensure no loops in delegation chain
3. **Context Prep** — Prepare minimal required context
4. **Spawn Agent** — Use Task tool with proper subagent_type
5. **Monitor** — Track via Sentinel Protocol
6. **Return** — Consolidate result

## Anti-Loop Rules

Before delegating, checks:
- Same task delegated before? → BLOCK
- Delegation depth > 3? → BLOCK
- Same agent type in chain? → WARN
- Task similarity > 85%? → BLOCK

## Output

```
Delegation Started
─────────────────────────────────────────────────
Agent: Claude-PO-c614-001
Task: Analyze VKS-550 for MVP inclusion
Depth: 1
Chain: Orch-Prime → PO

Context Package:
  - roadmap_macro_2027Q3.csv
  - analise_critica_recursiva_2027Q3.md (section 8)

Anti-Loop: ✓ PASS
Status: 🟢 Executing...
```
