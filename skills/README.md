# Claude Code Skills

## Overview

This folder contains reusable skills for the Multi-Agent OS framework. Skills follow the Claude Code plugin format with subdirectory structure.

## Available Skills

| Skill | Directory | Description |
|-------|-----------|-------------|
| `audit` | `audit/SKILL.md` | On-demand audit and analysis (Sentinel Protocol) |
| `agent-select` | `agent-select/SKILL.md` | Select best agent for a task |
| `context-prep` | `context-prep/SKILL.md` | Prepare optimal context before delegation |
| `hierarchical-merge` | `hierarchical-merge/SKILL.md` | Enforce branch merge hierarchy |
| `worktree-policy` | `worktree-policy/SKILL.md` | Enforce mandatory worktree usage |
| `anti-conflict` | `anti-conflict/SKILL.md` | Prevent file conflicts between agents |
| `status-map` | `status-map/SKILL.md` | Generate ASCII status visualizations |
| `ttl-policy` | `ttl-policy/SKILL.md` | Manage content freshness policies |

## Skill Categories

### Delegation Skills
- `agent-select` — Agent selection algorithm
- `context-prep` — Pre-delegation context preparation

### Observability Skills (Sentinel Protocol)
- `audit` — On-demand session/agent/task auditing
- `status-map` — Human-readable status visualizations

### Coordination Skills
- `hierarchical-merge` — Branch convergence rules
- `worktree-policy` — Git worktree isolation
- `anti-conflict` — 7-phase conflict prevention

### Governance Skills
- `ttl-policy` — Content freshness and expiration

## Directory Structure

```
skills/
├── README.md                    ← This file
├── audit/
│   └── SKILL.md                 ← Audit skill definition
├── agent-select/
│   └── SKILL.md                 ← Agent selection skill
├── context-prep/
│   └── SKILL.md                 ← Context preparation skill
├── hierarchical-merge/
│   └── SKILL.md                 ← Merge hierarchy skill
├── worktree-policy/
│   └── SKILL.md                 ← Worktree enforcement skill
├── anti-conflict/
│   └── SKILL.md                 ← Conflict prevention skill
├── status-map/
│   └── SKILL.md                 ← Status visualization skill
└── ttl-policy/
    └── SKILL.md                 ← TTL management skill
```

## SKILL.md Structure

Each skill follows the Claude Code plugin format:

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

## Commands
Executable commands

## Examples
Usage examples
```

## Skill Invocation

Skills are automatically invoked by Claude Code when:
- Trigger phrases are detected in conversation
- Related tools are used (e.g., Task tool triggers delegation skills)
- Session lifecycle events occur

Skills can also be referenced explicitly in CLAUDE.md or agent definitions.

---

*Part of multi-agent-os plugin v1.0.0*
