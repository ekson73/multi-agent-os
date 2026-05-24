# Agent Skills

## Overview

This folder contains reusable Agent Skills for the Multi-Agent OS framework. Skills follow the [Agent Skills open standard](https://agentskills.io) (SKILL.md format) and are compatible with 30+ AI tools including Claude Code, Cursor, Codex, Gemini CLI, Kiro, VS Code, GitHub Copilot, Goose, and others.

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
| `find-docs` | `find-docs/SKILL.md` | Library documentation lookup via Context7 |
| `response-compression` | `response-compression/SKILL.md` | Output verbosity control with role-based profiles (none/lite/full/ultra) |
| `founder-playbook` | `founder-playbook/SKILL.md` | AI-native startup lifecycle router — diagnose stage + route to stage skills |
| `founder-stage-idea` | `founder-stage-idea/SKILL.md` | Idea stage — validate the problem before building |
| `founder-stage-mvp` | `founder-stage-mvp/SKILL.md` | MVP stage — product-market-fit evidence without compounding tech debt |
| `founder-stage-launch` | `founder-stage-launch/SKILL.md` | Launch stage — repeatable growth; remove the founder bottleneck |
| `founder-stage-scale` | `founder-stage-scale/SKILL.md` | Scale stage — systematic growth + defensible moat |

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

### Token Optimization
- `response-compression` — Output verbosity control with role-based compression profiles

### Developer Tools
- `find-docs` — Up-to-date library documentation and code examples via Context7 CLI

### Founder / Startup Skills

- `founder-playbook` — Lifecycle router: diagnose stage, check exit gates, route
- `founder-stage-idea` — Validate the problem before building
- `founder-stage-mvp` — Product-market-fit evidence; tech-debt / scope / security discipline
- `founder-stage-launch` — Repeatable growth engine; remove the founder bottleneck
- `founder-stage-scale` — Systematic growth + defensible moat + GTM

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
├── ttl-policy/
│   └── SKILL.md                 ← TTL management skill
├── find-docs/
│   └── SKILL.md                 ← Library docs lookup skill
└── response-compression/
    └── SKILL.md                 ← Output verbosity control skill
```

## SKILL.md Structure

Each skill follows the Agent Skills open standard (SKILL.md with YAML frontmatter):

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

Skills are automatically invoked by compatible agents when:
- Trigger phrases are detected in conversation
- Related tools are used (e.g., Task tool triggers delegation skills)
- Session lifecycle events occur

Skills can also be referenced explicitly in CLAUDE.md or agent definitions.

---

*Part of multi-agent-os plugin v1.0.0*
