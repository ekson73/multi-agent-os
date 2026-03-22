# Multi-Agent Backlog Governance Protocol

> **Purpose**: Standardized protocol for multiple AI agents working on shared backlogs concurrently.
> **Created**: 2026-03-22 by Antigravity (Google/Gemini-2.5-Pro)
> **Scope**: Any AI agent (agent-agnostic, open-source protocol)

## Core Principle

> No task should be executed without ownership. No task should have two owners.
> Every agent must follow the handshake protocol before executing.

## Task Lifecycle

```text
BACKLOG → ASSIGNED → IN_PROGRESS → REVIEW → DONE
                                      ↘ BLOCKED (with reason)
                                      ↘ STALE (>7 days no update)
```

## YAML Frontmatter Standard (Task Files)

Every task file MUST have:

```yaml
---
id: TASK-NNN
title: Short description
status: backlog | assigned | in_progress | review | done | blocked | stale
assignee: agent-name | human-name | unassigned
locked_by: agent-name        # Set when agent starts work
locked_at: ISO-8601           # Timestamp of lock acquisition
priority: Q1 | Q2 | Q3 | Q4  # Eisenhower quadrant
blocked_by: [TASK-NNN]        # Dependency list
blocks: [TASK-NNN]            # What this unblocks
created: ISO-8601
updated: ISO-8601
---
```

## Handshake Protocol (Before Executing)

```text
1. UPDATE  — Close current task: status=done, updated=now
2. REORDER — Re-evaluate N-Tree by Eisenhower × blockers
3. SCAN    — Read next task in ordered list
4. CHECK   — Validate:
   ├── Is assignee == "unassigned"?  → proceed
   ├── Is assignee == me?            → proceed (resuming)
   ├── Is assignee == other agent?   → SKIP, take next
   ├── Is status == "stale"?         → reassign to me, proceed
   └── Is status == "blocked"?       → SKIP, take next
5. LOCK    — Set: assignee=me, locked_by=me, locked_at=now, status=in_progress
6. EXECUTE — Do the work
7. REPORT  — Phase-end self-assessment
8. REPEAT  — Go to step 1
```

## Conflict Resolution

| Scenario | Resolution |
| -------- | ---------- |
| Two agents lock same task | First lock wins (earliest `locked_at`) |
| Task stale >7 days | Any agent can reassign to itself |
| Task blocked | Skip; work on next unblocked task |
| Agent crashes mid-task | Task stays `in_progress`; next agent can claim after stale threshold |
| Human-assigned task | AI agents MUST NOT claim; skip |

## Stale Detection

```python
is_stale = (now - updated) > timedelta(days=7) and status == "in_progress"
# If stale: any agent can reassign after documenting previous progress
```

## Status Update Format

When closing a task:

```yaml
---
status: done
assignee: Antigravity (Google/Gemini-2.5-Pro)
locked_by: ""                 # Release lock
completed: 2026-03-22
updated: 2026-03-22
resolution: "Brief description of what was done"
---
```

## Integration with Pre-Task Requirements

This protocol is step 0 — it runs BEFORE the 7 pre-task requirements:

```text
0. Handshake Protocol (this document)
1. Delegate to best resource
2. Best practices by default
3. Reorder N-Tree
4. Analyze .gitignore
5. Check dependency chain
6. Verify secret exposure
7. Phase-end self-assessment
```
