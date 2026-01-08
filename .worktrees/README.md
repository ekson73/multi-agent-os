# Git Worktrees Coordination

This directory manages git worktrees for multi-agent parallel work.

## Structure

```
.worktrees/
├── README.md           ← This file
├── tasks.md            ← Task registry per agent
├── sessions.json       ← Active sessions registry
└── {agent}-{feature}/  ← Worktree directories (dynamic)
```

## Quick Commands

```bash
# Create worktree
git worktree add .worktrees/{agent}-{feature} -b {type}/{feature}-{agent}

# List worktrees
git worktree list

# Remove worktree
git worktree remove .worktrees/{agent}-{feature}
git worktree prune
```

## Rules

1. **ALWAYS** use worktree for file modifications (except append-only to tasks.md/sessions.json)
2. **NEVER** work directly on main for multi-file changes
3. **REGISTER** your session in sessions.json before starting
4. **UPDATE** tasks.md with your progress
5. **CLEANUP** worktree after merge (max retention: 7 days)

---

*Multi-Agent OS v1.0 | Worktree Coordination Protocol*
