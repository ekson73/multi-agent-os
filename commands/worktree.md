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
| `prune` | Git-native cleanup of admin-stale worktree entries |
| `reap` | Safely reap STALE/ORPHAN worktrees + merged orphan branches (dry-run default) |

## Options

| Option | Description |
|--------|-------------|
| `--branch <name>` | Specify branch name |
| `--type <tipo>` | Branch type (feature/bugfix/docs) |
| `--force` | Force operation |
| `--apply` | (`reap`) Actually delete — omit for dry-run (preview only) |
| `--stale-days <N>` | (`reap`) Age threshold for "stale" (default `7`) |
| `--json` | (`reap`) Machine-readable output (agentic consumption) |

## Examples

```
/worktree create c614-policy --type docs
/worktree list
/worktree status
/worktree remove c614-policy
/worktree prune
/worktree reap                      # dry-run: preview stale/orphan worktrees + merged orphan branches
/worktree reap --apply              # actually delete the eligible ones
/worktree reap --stale-days 3 --json   # 3-day threshold, machine-readable
```

## reap — the executor (dry-run default)

`reap` wraps `bin/reap-sessions.sh` — the executor that closes the
**detect → act** loop (`work-compass` / `worktree-policy` only *detect* stale/orphan;
`reap` is what actually prunes). It is **safe by construction**:

- **dry-run by default** — preview only; `--apply` required to delete.
- **NEVER** `--force`, **NEVER** `git branch -D` — only `git worktree remove` + `git branch -d` (merged-only).
- **NEVER** touches the **main worktree** nor any worktree with **uncommitted WIP** (read-before-delete).
- **good-neighbor**: defers (no-op, exit 0) if a peer holds `.git/index.lock`.
- **idempotent**: re-running after `--apply` is a no-op.

Eligibility = a worktree whose branch is detached/orphan **or** whose last commit is
older than `--stale-days` (default 7) **and** the tree is clean; plus orphan branches
already merged into the default branch. Session transcripts are out of scope.

```
$ /worktree reap
Would reap (dry-run — pass --apply to delete):
  worktrees:  .worktrees/alpha-docs (stale-9d)  ·  .worktrees/orphan-x (detached)
  branches:   docs/readme-alpha (merged)
  preserved:  .worktrees/live-feature (uncommitted WIP)
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
- `reap` delegates to `bin/reap-sessions.sh` (the safe executor) — consumed by `skills/postflight` P1 SWEEP for end-of-session exit-hygiene
