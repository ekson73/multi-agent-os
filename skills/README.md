# Claude Code Skills

## Overview

This folder contains reusable skills for the AI Agent Orchestration Framework.

## Available Skills

| Skill | File | Description |
|-------|------|-------------|
| `/context-prep` | `context-prep.md` | Prepare optimal context before delegation |
| `/agent-select` | `agent-select.md` | Select best agent for a task |
| `/audit` | `audit.md` | On-demand audit and analysis (Sentinel Protocol) |

## Skill Categories

### Delegation Skills
- `/context-prep` — Pre-delegation context preparation
- `/agent-select` — Agent selection algorithm

### Observability Skills (Sentinel Protocol)
- `/audit` — On-demand session/agent/task auditing

## Skill Structure

Each skill file follows this structure:

```markdown
# Skill Name

## Metadata
- Skill ID, version, author, created date

## Purpose
What the skill does and why it exists

## When to Use
Trigger conditions and use cases

## Execution Steps
Step-by-step instructions

## Output Format
Expected output structure

## Example Usage
Concrete examples with input/output

## Integration
How the skill integrates with other components
```

## Creating New Skills

1. Copy an existing skill file as template
2. Update metadata with new skill ID
3. Define clear purpose and triggers
4. Document input parameters
5. Provide concrete examples
6. Test with orchestrator

## Skill Invocation

Skills can be invoked by:
- Orchestrator (Claude-Orch-Prime) automatically
- User explicitly via `/skill-name`
- Sub-agents during task execution

---

*Maintained by Claude-Orch-Prime-20260106-86fa*
