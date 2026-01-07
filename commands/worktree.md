---
name: worktree
description: Manage git worktrees for multi-agent isolation
---

# /worktree Command

Manage git worktrees for isolated multi-agent development.

## Usage

```
/worktree <action> [options]
```

## Actions

| Action | Description |
|--------|-------------|
| `create <name>` | Create new worktree with branch |
| `list` | List all active worktrees |
| `remove <name>` | Remove worktree and cleanup |
| `status` | Show worktree status with lock info |
| `prune` | Cleanup stale worktrees |

## Options

| Option | Description |
|--------|-------------|
| `--branch <name>` | Specify branch name |
| `--type <tipo>` | Branch type (feature/bugfix/docs) |
| `--force` | Force operation |

## Examples

```
/worktree create c614-policy --type docs
/worktree list
/worktree status
/worktree remove c614-policy
/worktree prune
```

## Naming Convention

### Directory
```
.worktrees/{agent-short}-{feature-kebab}/
```

### Branch
```
{tipo}/{escopo}-{agent-hex}
```

## Output

### /worktree list
```
Active Worktrees
─────────────────────────────────────────────────
Directory              Branch                   Status
─────────────────────────────────────────────────
.worktrees/c614-policy docs/policy-c614        🟢 Active
.worktrees/alpha-docs  docs/readme-alpha       🟡 Stale (2h)
```

### /worktree status
```
Worktree Status
─────────────────────────────────────────────────
Active: 2
Stale: 1 (> 30 min without heartbeat)
Locks: 1 active, 0 stale

Recommendation:
  Run '/worktree prune' to clean up stale worktrees
```

## Integration

- Creates worktree in `.worktrees/` directory
- Registers in `tasks.md` automatically
- Creates lock file if editing protected files
- Updates `sessions.json` with worktree info
