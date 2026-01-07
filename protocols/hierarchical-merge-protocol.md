<!-- ═══════════════════════════════════════════════════════════════════════
     CANONICAL SOURCE
     ═══════════════════════════════════════════════════════════════════════
     Repository: github.com/ekson73/multi-agent-os
     Path: protocols/hierarchical-merge-protocol.md
     Version: v1.0

     TTL POLICY:
     Type: Protocol/Standard
     TTL: 90 days
     Next Review: 2026-04-07

     CONSUMPTION INSTRUCTIONS:
     When duplicating to consumer projects, add a CONSUMER HEADER with:
     - SOURCE OF TRUTH pointing back to this file (Canonical URL)
     - Last sync date (ISO 8601)
     - Calculated expiration date (sync_date + TTL)
     - Status indicator (FRESH/EXPIRING/EXPIRED)
     - Actions by state (what to do when FRESH/EXPIRING/EXPIRED)

     See: docs/framework-consumption.md for full template
     ═══════════════════════════════════════════════════════════════════════ -->

# Hierarchical Merge Protocol v1.0

## Overview

The Hierarchical Merge Protocol (HMP) defines how branches merge in multi-agent environments, enabling controlled convergence through parent-child relationships rather than direct-to-main merges.

**Version**: 1.0 | **Updated**: 2026-01-07

---

## Core Principle

```
┌────────────────────────────────────────────────────────────────────────┐
│  HIERARCHICAL MERGE — BRANCH CONVERGENCE MODEL                         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Branches merge to their PARENT branch, not directly to main.          │
│  This creates a tree-like convergence pattern where:                   │
│                                                                        │
│  • Sub-tasks merge to task branches                                    │
│  • Task branches merge to sprint/feature branches                     │
│  • Sprint/feature branches merge to main                               │
│                                                                        │
│  RATIONALE:                                                            │
│  1. Controlled review at each level                                    │
│  2. Easier conflict resolution (smaller scope per merge)               │
│  3. Clear responsibility chains                                        │
│  4. Rollback granularity (revert feature, not all sub-tasks)          │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Visual Model

```
main (root)
  │
  └── feature/sprint-01 (level 1 — sprint coordinator)
        │
        ├── feature/task-A (level 2 — worktree)
        │     │
        │     └── feature/subtask-A1 (level 3 — sub-worktree)
        │           │
        │           └─── merge → feature/task-A (first)
        │                  │
        │                  └─── merge → feature/sprint-01 (then)
        │
        └── feature/task-B (level 2 — worktree)
              │
              └─── merge → feature/sprint-01
                     │
                     └─── merge → main (finally)
```

### Merge Direction Rules

| Branch Level | Merges To | Example |
|--------------|-----------|---------|
| Level 3 (subtask) | Level 2 (task) | `subtask-A1` → `task-A` |
| Level 2 (task) | Level 1 (sprint) | `task-A` → `sprint-01` |
| Level 1 (sprint) | main | `sprint-01` → `main` |

---

## Child Completion Constraint

```
┌────────────────────────────────────────────────────────────────────────┐
│  CHILD COMPLETION RULE — MANDATORY                                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  A branch can ONLY merge to its parent when ALL children are complete. │
│                                                                        │
│  DEFINITION OF "COMPLETE":                                             │
│  • Child branch has been merged back (or abandoned with record)        │
│  • Associated worktree has been removed                                │
│  • tasks.md status is COMPLETED                                        │
│                                                                        │
│  EXAMPLE:                                                              │
│  feature/task-A has 2 children: subtask-A1, subtask-A2                │
│                                                                        │
│  ✅ Can merge task-A when: A1 merged + A2 merged (both complete)       │
│  ❌ Cannot merge task-A when: A1 merged + A2 still in progress        │
│                                                                        │
│  WHY THIS MATTERS:                                                     │
│  • Prevents orphaned work (child work lost if parent merges early)    │
│  • Ensures complete features are merged, not partial implementations  │
│  • Maintains audit trail integrity                                     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Exceptions to Child Completion

```
┌────────────────────────────────────────────────────────────────────────┐
│  EXCEPTION PREFIXES — BYPASS CHILD COMPLETION CONSTRAINT              │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ALLOWED PREFIXES (can merge with incomplete children):                │
│                                                                        │
│  • bugfix/*    — Bug fixes that shouldn't wait for feature completion │
│  • hotfix/*    — Critical production fixes                            │
│  • emergency/* — System-critical changes                              │
│  • selective/* — Intentional partial merge (documented reason)        │
│  • partial/*   — Known incomplete work (documented scope)             │
│                                                                        │
│  USAGE:                                                                │
│  When creating a branch that may need early merge:                    │
│                                                                        │
│    git checkout -b hotfix/security-patch-urgent                       │
│    git checkout -b selective/auth-only-for-sprint-deadline            │
│                                                                        │
│  DOCUMENTATION REQUIREMENT:                                            │
│  All exception-prefix branches MUST include in PR description:        │
│  • Reason for early merge                                              │
│  • List of children that remain incomplete                            │
│  • Plan for handling orphaned children                                │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Checklist

### Before Merging to Parent

```
□ All child branches merged or abandoned
□ All child worktrees removed (`git worktree prune`)
□ tasks.md entries for all children show COMPLETED
□ No active lock files for child branches
□ CI/CD passes on the branch being merged
□ Code review approved (if required)
```

### Merge Commands

```bash
# 1. Verify children are complete
git branch --list "feature/task-A*" | wc -l  # Should be 1 (only task-A itself)

# 2. Ensure branch is up-to-date with parent
git checkout feature/task-A
git fetch origin
git rebase origin/feature/sprint-01  # Or merge, per team preference

# 3. Merge to parent
git checkout feature/sprint-01
git merge --no-ff feature/task-A -m "merge: task-A complete - Agent: Claude-Dev-docs-001"

# 4. Delete child branch (optional but recommended)
git branch -d feature/task-A

# 5. Push updates
git push origin feature/sprint-01
```

---

## Anti-Pattern: Direct-to-Main

```
┌────────────────────────────────────────────────────────────────────────┐
│  ❌ ANTI-PATTERN: DIRECT-TO-MAIN MERGE                                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  AVOID:                                                                │
│    git checkout main                                                   │
│    git merge feature/subtask-A1  # WRONG - skips parent               │
│                                                                        │
│  WHY IT'S PROBLEMATIC:                                                 │
│  • Parent branch (task-A) doesn't get the changes                      │
│  • Other children of task-A may conflict                               │
│  • Review hierarchy is bypassed                                        │
│  • Sprint-level coordination is broken                                 │
│                                                                        │
│  CORRECT:                                                              │
│    git checkout feature/task-A                                         │
│    git merge feature/subtask-A1  # Merge to parent first              │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Integration with Worktree Protocol

The Hierarchical Merge Protocol complements the Worktree Policy:

| Worktree Policy | Merge Protocol |
|-----------------|----------------|
| Creates isolated workspace | Defines merge target |
| Tracks branch ownership | Enforces parent-child relationship |
| Prevents file conflicts | Prevents merge order conflicts |
| Uses tasks.md for status | Uses same registry for completion check |

### Combined Workflow

```
1. Create parent branch (feature/sprint-X)
2. Create worktree for task (feature/task-A)
3. Create sub-worktree if needed (feature/subtask-A1)
4. Complete work in subtask
5. Merge subtask → task (in worktree)
6. Remove subtask worktree
7. Complete work in task
8. Merge task → sprint (following HMP)
9. Remove task worktree
10. When all tasks complete: merge sprint → main
```

---

## Validation Script

```bash
#!/bin/bash
# validate-merge-ready.sh
# Validates if a branch is ready to merge to its parent

BRANCH=$1
if [ -z "$BRANCH" ]; then
    echo "Usage: validate-merge-ready.sh <branch-name>"
    exit 1
fi

# Check for child branches
CHILDREN=$(git branch --list "${BRANCH}/*" | wc -l)
if [ "$CHILDREN" -gt 0 ]; then
    echo "❌ BLOCKED: $CHILDREN child branches still exist:"
    git branch --list "${BRANCH}/*"
    exit 1
fi

# Check for active worktrees
WORKTREES=$(git worktree list | grep "$BRANCH" | wc -l)
if [ "$WORKTREES" -gt 1 ]; then  # 1 is the branch itself
    echo "❌ BLOCKED: Active worktrees found for $BRANCH"
    git worktree list | grep "$BRANCH"
    exit 1
fi

echo "✅ READY: $BRANCH can be merged to parent"
exit 0
```

---

## References

- [Trunk-Based Development](https://trunkbaseddevelopment.com/) — Industry patterns for branch management
- [Git Worktrees Documentation](https://git-scm.com/docs/git-worktree) — Official Git documentation
- Multi-Agent OS Worktree Guide — `docs/worktrees-guide.md`

---

## Metadata

| Field | Value |
|-------|-------|
| Created by | `Claude-Dev-docs-001` |
| Delegated by | `Claude-Orch-Prime-20260107-docs` |
| Date | 2026-01-07 |
| Version | 1.0 |

**Changelog**:
- v1.0 (2026-01-07): Initial version — Child Completion Constraint, Exception Prefixes, Integration with Worktree Protocol

*Signature: Claude-Dev-docs-001 | 2026-01-07T12:15:00-03:00*
