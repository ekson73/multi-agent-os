# Delegation — Finalize Prompt (Cleanup, Handoff, Sign-Off)

> Emit this block when a delegated task is at the **end**. The delegated agent runs it before returning; the delegator runs it after receiving output. Double-pass is intentional — both sides cleanup their own surface.

---

## Invariant Header — Closure Ethos

From `rules/axial-principles.md` §5 (Cerimônia de Fechamento Impecável):

> "O estado do ambiente deve estar invariavelmente melhor após a sua intervenção do que estava antes."

**Resolver ≠ deletar. Fechar ≠ ignorar. Limpar ≠ destruir.** Read before discard. Understand before delete. Cleanup without comprehension is disguised destruction.

4 cognitive lenses (final pass): **Tomé** verifies completion claim, **Crítica** checks for half-done work, **Agnóstica** ensures the fix works outside the session's specific stack, **Autônoma** decides autonomously whether to close or escalate.

---

## Phase 6 — Cleanup Protocol

Run these **in order** (any failure = pause + fix before continuing):

### 6.1 Uncommitted state

```bash
git status --short                                 # must be clean, or intentional untracked
git diff --cached                                  # staged? if yes, commit or reset
git stash list                                     # stashes? document or pop
```

If dirty → either commit (atomic, with `Agent: {session-id}` sign-off line), stash with an explanatory message, or explicitly discard after reading the diff.

### 6.2 Worktree lifecycle

Per `skills/worktree-policy/SKILL.md` + `skills/hierarchical-merge/SKILL.md`:

- **Merged**: delete the worktree after PR merge — **only** through the guarded procedure in `rules/pr-governance-unified.md` Step 12 (4 gates: PR `MERGED` · worktree resolved from the **registry** via `headRefName` · `status --porcelain --untracked-files=all --ignored` empty · tip == `headRefOid`). Then `git worktree remove <path>` followed by the **atomic** ref deletion `git update-ref -d "refs/heads/{branch}" "$MERGED_OID"` — never a bare `git branch -D`, which would discard a commit another session pushed between the gates and the deletion. **NEVER `--force`** — it deletes another session's uncommitted WIP with no warning; a dirty worktree is fail-closed, not an obstacle to override.
- **WIP** (must persist): keep the worktree AND write `<worktree>/RESUME.md` with a 5-line handoff (context, last step, next step, blockers, ETA).
- **Abandoned**: remove worktree + document reason in `dna_delegation_learnings.md` (user-scope memory) so future sessions don't re-attempt blindly.

Branches merge to **parent**, not directly to main (Hierarchical Merge Protocol). Exceptions: `bugfix/`, `hotfix/`, `emergency/` prefixes.

### 6.3 Lock files

```bash
ls .worktrees/*.lock 2>/dev/null
```

Any lock owned by this session → remove (the work is done). Any lock older than 30 min from another session with no heartbeat → declare stale, reclaim or surface to delegator.

### 6.4 Audit trail

Append a closing event to `~/.claude/audit/session_${CLAUDE_SESSION_ID}.jsonl`:

```bash
AUDIT_DIR="${HOME}/.claude/audit"
AUDIT_FILE="${AUDIT_DIR}/session_${CLAUDE_SESSION_ID:-unknown}.jsonl"
mkdir -p "$AUDIT_DIR"                                        # ensure target exists
printf '{"event":"delegation_finalize","timestamp":"%s","session_id":"%s","agent":"%s","outcome":"%s"}\n' \
  "$(date -u +%FT%TZ)" "${CLAUDE_SESSION_ID:-unknown}" "${AGENT_ID:-unknown}" "${OUTCOME:-unknown}" \
  >> "$AUDIT_FILE"
```

See `skills/audit/SKILL.md` for the full event schema.

### 6.5 Sanitize (secrets)

Before any `git push`:

```bash
git diff | grep -iE "(password|secret|token|api[_-]?key)[[:space:]]*=[[:space:]]*[\"']?[A-Za-z0-9_-]{16,}" && exit 1 || true
```

gitleaks runs on pre-commit via GaaS hook. Do not bypass with `--no-verify`. If a real leak is found: purge from working tree, rotate the secret via your secret manager (see provider matrix §Secrets), then retry.

---

## Phase 7 — Ticket & PR Closure (via Provider Matrix)

Use `protocols/delegation/provider-matrix.md` rows for the active `TICKET_PROVIDER` and `VCS_PROVIDER`. Pattern:

### 7.1 Link PR ↔ ticket

- **Jira**: add PR URL as a comment on the ticket; if Jira ticket has a Development panel, it auto-links from commit/PR references containing `VKS-*` key. Add the `@mention` if a reviewer is expected.
- **Linear**: `mcp__claude_ai_Linear__save_issue` with `links: [{url, title}]` (append-only per tool schema).

### 7.2 Update ticket status

- **Jira**: `get_transitions` → pick terminal transition (Done / Approved / Deployed) → `transition`. If no direct transition (e.g. VKS workflow blocks Backlog→Done), post a comment noting "awaiting PO transition" and stop.
- **Linear**: `save_issue` with `state: "Done"`.

### 7.3 PR merge decision

Consult `feedback_autonomous_merge.md`. All 6 criteria met → merge autonomously; else
pause and request confirmation with the criteria table.

**Execute the merge through canonical Step 9** (`rules/pr-governance-unified.md`) — do
not inline the command here. A second executable copy is exactly the drift this protocol
suffered: it merged over REST without `merge_method`, silently falling back to a merge
commit on repos that declare squash. Step 9 resolves the method from declared policy ∧
effective capability (repo flags, rulesets, classic protection) and fails closed.

### 7.4 Post-merge cleanup

**Delegate to canonical Steps 10 and 12** — no cleanup commands belong in this file.

- **Step 10** syncs the branch the PR merged **into**, resolved from the PR — never
  `origin/main` by reflex.
- **Step 12** removes the worktree and refs under its 4 gates, deleting local and remote
  refs **atomically** (expected-OID / lease).

⛔ Two forms are **never** acceptable, whatever the caller: deleting the remote ref over
REST (that endpoint has **no expected-OID parameter**, so it cannot be atomic — a push
landing mid-call is destroyed undetectably) and bare `git worktree prune` as cleanup
(skips every gate).

---

## Phase 8 — Handoff to Delegator

Return a single structured block (delegator parses it):

```
## Delegation Report

- session: Claude-{Role}-{prime-hex}-{seq}
- outcome: success | partial | failure | blocked
- artifacts:
  - <path>: <one-line purpose>
- tickets_touched: <KEY> → <new status>
- prs: <url> → <state>
- surprises: <one-line; what was non-obvious>
- next_step: <one actionable sentence>
- housekeeping: <worktree removed? locks released? tasks.md updated? audit appended?>
- sign_off: Agent {session-id} | {ISO-8601}
```

Omit fields that don't apply (don't emit `N/A`). Keep lines ≤ 120 chars for log-grep friendliness.

---

## Phase 9 — Learning Codification

Append an entry to `~/.claude/projects/<project>/memory/dna_delegation_learnings.md` (user-scope memory, append-only):

```markdown
### {YYYY-MM-DD} — {session-id} — {task-id}

- task: <1 line>
- type: <code|arch|review|debug|refactor|docs|plan|security|perf|governance|multiagent|merge|learning>
- minds_activated: [<primary>, <secondary>]
- executor: <self | agent/subagent/persona>
- outcome: <success|partial|failure|blocked>
- surprise: <what was non-obvious>
- learning: <transferable rule; this is what future agents will cite>
- dna_update: yes — edited <file> | no
```

Write honestly. "surprise" + "learning" are the fields that compound over sessions. Zero value in recording the expected.

---

## Phase 10 — Session Close (orchestrator only)

If this was the orchestrator session closing (not a sub-agent):

1. Update `.worktrees/sessions.json` entry for your session: `status: "completed"`, `ended: "<ISO-8601>"`, `qa_result: {...}` (honest score; don't lie about violations).
2. Update `.worktrees/tasks.md`: move your row from Active → Completed.
3. Spawn `Claude-QA-{prime-hex}-final` sub-agent against `skills/audit/SKILL.md` for a closing sanity check (optional when bot reviewers + CI already validated).
4. Sign every document modified with `Agent: {session-id} | {ISO-8601}` (commit trailer is acceptable).

---

## Rejection conditions (refuse to finalize if any true)

- Uncommitted changes with no handoff plan.
- Worktree still active but no `RESUME.md`.
- Lock file held by this session but never released.
- PR merged but ticket not linked/updated.
- Secret pattern matched in the diff.
- `tests/validate-plugin.sh` failing introduced by this session.

On rejection: emit a single-line error stating the specific rule, do not report "success".

---

*Source of truth: `protocols/delegation/delegation-finalize-prompt.md` | Version 1.0 | 2026-04-18*
