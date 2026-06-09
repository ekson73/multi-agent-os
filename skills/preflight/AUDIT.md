# Preflight — reuse-verification audit (vs the session-lifecycle "start-of-session" spec)

> Purpose: document, in-repo, that `preflight` v1.1.1 **already satisfies** the start-of-session
> responsibilities (branch-detect-without-interfering · heal-from-origin · worktree-on-mutation),
> so its end-of-session counterpart `postflight` **composes** rather than duplicates them
> (DRY / reuse-first). Companion to issue #118.

## Spec → preflight responsibility map

| Start-of-session responsibility | preflight | Verdict |
|---|---|---|
| Detect the **right branch** without interfering with other agents/sessions/worktrees | **R1** (`lib/git-branch-detect.sh`: branch + upstream + ahead/behind + `git worktree list --porcelain` locked-branches + tree-state) + **R1.5** peer-aware cross-session detection (`lib/peer-session-detect.sh`, capability-detected, graceful `UNKNOWN` off-host) | ✅ covered |
| Git **pull / harmonize / heal / cure** the current branch from origin | **R2** (`lib/git-safe-sync.sh`: fetch → classify {up-to-date / ff-ready / diverged / dirty / detached / mid-op / busy / peers-active} → `ff-only` \| `rebase --autostash` \| **DEFER**) | ✅ covered |
| Create a **git worktree** the moment you are about to create/update files/dirs | **R3** (lazy isolation; composes `/maos:worktree create`; `preflight-edit-gate.sh` PreToolUse safety-net) | ✅ covered |
| Adapt to **whatever patterns/governance are available at invocation** | Governance Discovery section (reads `CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories`, falls back to C04 defaults) | ✅ covered |

## Non-interference is structural

A branch checked out in another worktree is git-locked → preflight **reports it and never
switches to it** (R1). Two sessions in the same checkout on the same branch → R1.5 defers R2
when a peer is actively writing. Healing never clobbers (dirty / detached / mid-rebase /
mid-merge / held `.git/index.lock` → DEFER). Isolation is lazy (worktree only on imminent
mutation). These are exactly the safety properties the spec requires.

## Conclusion

No new start-of-session tools are warranted. `postflight` reuses preflight as the session's
opening bookend (`preflight → work → postflight`) and focuses net-new effort on the genuine
gaps: the end-of-session **exit-hygiene sweep** + the **amnesic continuation seed**.

> Dogfood: `preflight` ships `dogfood_status: in-progress`; its real use this cycle counts
> toward its 2-cycle promotion gate (record via `bin/dogfood-mark`).
