# Exit Hygiene Protocol

> Do not leave loose ends. Do not leave banana peels. Do not shoot yourself in the foot.

## Fundamental Principle

When exiting any work cycle (session, PR, task, sub-task):
the environment state MUST be BETTER, SAFER, and MORE TRACEABLE than at the start.

## Five Axioms

1. **Close the door behind you**: do not leave open what you started
2. **Snowball effect**: unresolved problems multiply
3. **Entropy**: disorder is the default state; hygiene is deliberate action
4. **Proactive resolution**: detected → resolve (or delegate)
5. **Understand before acting**: cleanup without reading is destruction disguised as hygiene

## Exit Gate Checklist

Execute BEFORE declaring "work complete":

### Git
- [ ] `git status` clean in ALL touched repos
- [ ] `git worktree list` shows only the main repo
- [ ] No stale local branches (from already-merged PRs)
- [ ] No stale remote branches
- [ ] No pending unpushed commits
- [ ] No files modified directly in main repo (all edits via worktree)

### Metrics & Counters
- [ ] Counters match reality (e.g., merged PR count)
- [ ] No metrics with "TODO: fix next session" — fix NOW
- [ ] Document versions reflect changes from this session

### Documentation
- [ ] Changelogs updated in modified docs
- [ ] Cross-references consistent between related documents
- [ ] No stale version references

### Tickets / Backlog
- [ ] Verifiably-DONE tickets closed (DoD met + PR merged); loose ends (gaps/pendings/undecided) filed as **bounded** tickets — Eisenhower-triaged, **≤3 + 1 batch housekeeping ticket** — plus a single **continuation ticket** anchoring the next session. Delegated to a capability-detected ticketing primitive (DEFER if none — never block exit). See `skills/postflight/references/ticket-sync-protocol.md`.

### Read Before Discard (MANDATORY)
- [ ] Before `rm`, `git checkout --`, `git clean`, or committing files not created in this session:
  - READ the file contents
  - UNDERSTAND the purpose
  - Verify file belongs to this repo/scope
  - If untracked and not created by you: ask the user before deleting

### Delegation
- [ ] Problems identified outside current scope → delegated or registered with traceability?
- [ ] Active delegations have tracking (ticket, memory, PR comment)?

## Priority Levels

| Level | Gate |
|-------|------|
| **P0** (BLOCK exit) | Worktrees not removed, branches not deleted, known inconsistencies not fixed, files deleted without reading |
| **P1** (Fix before closing) | Documentation with incorrect state, stale cross-references |
| **P2** (Register if not fixed) | Unarchived notifications, known gaps not formally documented |

## Anti-Patterns

```
X  "Fix next session" for known inconsistencies
   → Fix NOW. It takes <5 min. Leaving it guarantees confusion.

X  Stale local branch from already-merged PR
   → git branch -d {branch} before closing session

X  Worktree not removed
   → git worktree remove + git worktree prune

X  Optimistic documentation ("all ok") when there's a known inconsistency
   → Document the REAL state, even if it's bad

X  Commit "fix: address review findings" without checking what was fixed
   → Read the diff before committing

X  PR merged without pull origin main
   → Always git pull after merge

X  "I'll do the cleanup later"
   → There is no later. Do it now.

X  Changelog says one version when the correct is another
   → Verify cross-references BEFORE push, not after

X  Accepting incremental disorder ("it's just one more TODO")
   → Entropy is exponential. One TODO becomes five. Five become tech debt.

X  Leaving partial states: branch created but PR not opened
   → Partial state = open door. Close it: open the PR or delete the branch.

X  "I know it's wrong but it works for now"
   → "For now" is the most expensive phrase in development.

X  Editing files directly in main repo without worktree
   → Recovery: stash → worktree → apply → commit → PR

X  Deleting/discarding files without reading content ("blind cleanup")
   → Untracked ≠ valueless. Always: Read → Understand → Decide.

X  Making git status "green" as a goal in itself
   → Clean status is a CONSEQUENCE of good work, not a GOAL.
   → Cleaning status by deleting/committing without understanding is cargo cult hygiene.
```

## Integration

This protocol works with:
- **Agent Delegation Protocol** (protocols/agent-delegation.md): delegate out-of-scope problems
- **Action Priority Protocol** (protocols/action-priority.md): classify tasks before closing

---

*MAOS Exit Hygiene Protocol v1.0.0 | 2026-03-13 | Derived from Boy Scout Rule*
