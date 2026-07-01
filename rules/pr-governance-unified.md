# PR Governance — Unified Workflow [C07+C12]

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-03-06 -->
<!-- Replaces: pr-review-protocol.md (C07 v3.0), pr-email-review-loop.md (C12 v3.0) -->
<!-- References: ~/.claude/docs/git-worktree-protocol.md (C04 — full spec) -->

## Fundamental Rule

```
MANDATORY: Worktree -> Code -> LOCAL REVIEW -> Push -> PR -> Bot Review -> Merge -> Cleanup
FORBIDDEN: Merge without review | Push without local review | git checkout in main repo
SCOPE: All agents, all sessions, all repos
```

## Complete Lifecycle (12 steps)

```
PRE-PUSH:
  1.WORKTREE -> 2.CODE+COMMIT -> 3.LOCAL REVIEW -> 4.FIX+COMMIT (loop 3-4 until clean)

PUSH+PR:
  5.PUSH -> 6.PR CREATE -> 7.BOT REVIEW (optional 30min wait)

DECISION:
  8.ANALYZE -> MERGE | FIX+PUSH (loop 7-8) | PARTIAL+PUSH | ESCALATE

POST-MERGE:
  9.MERGE -> 10.PULL MAIN -> 11.AUDIT+ARCHIVE EMAILS -> 12.CLEANUP WORKTREE
```

---

## Step 1: Worktree (MANDATORY)

NEVER modify files without worktree sandbox. NEVER `git checkout`/`switch` in main repo.

```bash
# Create + enter
git worktree add .worktrees/{session-id}-{feature} -b {type}/{feature}
cd .worktrees/{session-id}-{feature}
```

Exceptions (ALL require documentation in commit/PR body):
  1. Read-only analysis (no file writes)
  2. Append-only to coordination files (MEMORY.md, plan files)
  3. EXPLICIT user bypass: the user LITERALLY says "skip worktree", "edit directly",
     "don't use worktree", or equivalent DIRECT instruction to bypass the protocol.

WHAT IS NOT AN EXCEPTION:
  - "Fix this" / "Resolve the gaps" / "Implement X" → these are TASK instructions,
    not PROTOCOL bypasses. The task goes through the worktree. Always.
  - Convenience ("it's faster without worktree") → not a valid reason.
  - Scope ("it's just docs") → not a valid reason.
  - Volume ("it's only 3 files") → not a valid reason.

DECISION CHECKPOINT (mandatory before any file Edit/Write):
  "Am I in a worktree?"
    → YES: proceed
    → NO: "Did the user LITERALLY say to skip worktree?"
      → YES (with exact quote): proceed + document exception
      → NO: STOP. Create worktree first. Do NOT rationalize.

## Step 2: Code + Commit

```bash
# Work, then commit
git add <files>
git commit -m "{type}({scope}): {description}"
```

## Step 3: Local CLI Review (MANDATORY before push)

```bash
# PRIMARY: CodeRabbit CLI (~30s, rate-limited ~1/25min free plan)
coderabbit review --plain --base main --config CLAUDE.md

# FALLBACK: Qodo CLI (if CodeRabbit rate-limited)
qodo --ci -y "Review the git diff between this branch and main. Focus on correctness, consistency, and compliance."

# If BOTH rate-limited: proceed to push (GitHub bots will review on PR)
```

### Review Classification

| Category | Priority | Action |
|----------|----------|--------|
| Security | P0 | Fix immediately |
| Bug/Correctness | P1 | Fix |
| Reliability | P1 | Fix |
| Cosmetic/Doc | P2 | Fix if trivial |
| False positive | Skip | Document justification |
| Informational | Skip | Ignore |

## Step 4: Fix + Commit (loop with Step 3)

```bash
# Fix P0/P1/P2 issues found in review
git add <fixed-files>
git commit -m "fix: address local review findings"
# Repeat Step 3 until clean
```

## Step 5: Push Branch

```bash
git push -u origin {branch-name}
```

## Step 6: Create PR

```bash
gh pr create --title "{type}({scope}): {description}" --body "..."
```

NEVER merge directly. Always via PR.

## Step 7: Bot Review (OPTIONAL wait)

TTL: 30 minutes. Optional if local review was executed.

```bash
gh pr view <N> --json comments,reviews,statusCheckRollup
```

Reviewers: Copilot, Qodo, CodeRabbit (bots) | GitHub UI (human) | Claude agent (AI)

## Step 8: Analyze Review + Decide

| Classification | Action |
|----------------|--------|
| Approved | Merge (Step 9) |
| Valid correction | Fix in worktree, commit, push, loop Step 7-8 |
| Partially valid | Apply valid items, document rejected with justification, push, loop |
| Disagree (justified) | Merge + document justification via `gh pr comment` |
| Inconclusive | Escalate to human (do NOT merge) |

## Step 9: Merge

```bash
gh pr merge <N> --merge
```

## Step 10: Pull Main

```bash
cd /path/to/repo   # back to main repo root
git pull origin main
```

## Step 11: Audit Reviews + Archive Emails

### 11a. Audit PR reviews (PRIMARY: gh api)

```bash
# Read inline comments
gh api repos/{owner}/{repo}/pulls/{N}/comments --jq '.[].body'

# Read reviews
gh api repos/{owner}/{repo}/pulls/{N}/reviews --jq '.[] | "\(.state): \(.body)"'
```

If fix-needed issues found post-merge: new Worktree -> Fix -> PR -> Review -> Merge (C07 loop).

### 11b. Search + archive emails (gog CLI)

```bash
# Search both accounts
gog gmail search '{repo} PR #{N}' -a your-personal-email@example.com -p
gog gmail search '{repo}' -a user@acme-corp.example.com -p

# Get thread IDs for scripting
gog gmail search '{repo} PR #{N}' -a your-personal-email@example.com -j \
  | python3 -c "import json,sys; [print(t['id'],t['subject']) for t in json.loads(sys.stdin.read()).get('threads',[])]"

# Archive (remove from INBOX) — AFTER audit
gog gmail thread modify {threadId} --remove INBOX -a your-personal-email@example.com -y
```

### Email accounts

| Account | gog Profile | Content |
|---------|-------------|---------|
| `your-personal-email@example.com` | default | GitHub notifications |
| `user@acme-corp.example.com` | org | Jira, Confluence, Bitbucket |

### Email classification

| Source | Action |
|--------|--------|
| GitHub bots (Copilot, Qodo, CodeRabbit) | Archive after gh api audit |
| GitHub workflow failures | Archive (info only) |
| Jira automation | Archive (document if revert) |

## Step 12: Cleanup Worktree

```bash
# Remove worktree
git worktree remove .worktrees/{session-id}-{feature}
# Or: rm -rf .worktrees/{session-id}-{feature} && git worktree prune

# Delete local branch
git branch -d {type}/{feature}

# Delete remote branch
git push origin --delete {type}/{feature}
```

---

## Tools Reference

| Tool | Binary | Purpose | Scope |
|------|--------|---------|-------|
| CodeRabbit CLI | `coderabbit` / `cr` | Local code review (primary) | Local diff |
| Qodo CLI | `qodo` | Local code review (fallback) | Local diff |
| GitHub CLI | `gh` | PR ops, review data (primary) | GitHub API |
| gog CLI | `gog` | Email search + archive | Both gmail accounts |
| Gmail MCP | MCP server | Email read (fallback) | @gmail.com only |

### CLI Gotchas

- **CodeRabbit**: Free plan ~1 review/25min, 150 files/PR limit
- **Qodo**: `self-review` requires `agent.toml` and opens web UI — use `qodo --ci -y "prompt"` for CLI
- **Qodo**: Avoid `-q` (silent) — suppresses review output. Use `--ci -y` for non-interactive
- **gog**: Uses `thread` (singular), not `threads` for subcommand
- **Gmail MCP**: Only @gmail.com (OAuth). Cannot access @acme-corp.example.com

### Known False Positives (acme-solution repo)

- Portuguese accents: CodeRabbit flags "Versao" -> "Versao". Convention is ASCII-safe. **Dismiss.**
- Read-only violations: Qodo flags `docs/` modifications. `docs/` IS the project's purpose. **Dismiss.**

---

## Bot-Config Correction Discipline

> Generalizes the two dismissals above + the `.pr_agent.toml` precedent (whose header exists to *"prevent
> recurring false-positive"* findings) into a governed loop: instead of dismissing the same false-positive
> forever, **teach the bot via its own repo config** so it stops emitting it. Executed by the
> `bot-finding-arbiter` skill (*Praetor*); this section is the policy.

**When a reviewer/scanner bot flags a finding**, classify it into exactly one bucket:

| Bucket | Action |
|---|---|
| **valid-actionable** | fix/adapt the code (dispositions accept/fix/improve/expand per Step 8) |
| **bot-wrong** (false-positive · governance-misalignment · style-only) | reject + **teach the bot via its config file** (below) — but ONLY after independent verify |
| **ambiguous** | DEFER + comment; **never** guess a config edit |

**Rules for a teach-the-bot config edit (the "edict"):**
1. ⛔ **NEVER suppress a valid security or logic finding.** A config edit that would silence a real
   secret / injection / auth flaw / CVE / correctness bug is forbidden (gaming the scanner = Goodhart).
   Security-class "bot-wrong" verdicts are **HITL-gated**; the default is *fix/upgrade*, not suppress.
2. **Verifier > generator.** The "bot is wrong" verdict must be **independently verified** (a deterministic
   oracle where one exists — the flagged pattern is our documented convention / re-run the scanner — OR a
   second-lens review via `convergence-engine`/`perspective-trio`) BEFORE any file is touched.
3. **Repo-fixable only.** Some bot errors are account/dashboard-side (quota, rate-limit, import,
   entitlement — e.g. a Snyk "test limit reached") and NO committed file fixes them → HITL playbook,
   **no config edit**. See `skills/bot-finding-arbiter/bot-config-registry.md` (`repo-fixable?` column).
4. **Narrowest teaching form.** Prefer a path-scoped instruction / documented-convention note over a broad
   ignore (over-suppression hides future real findings).
5. **Reviewed PR, never silent.** A config edit lands via worktree → review → merge like any change, with a
   rationale, and is recorded on the Bot Scorecard as a `config-taught` disposition (accuracy tracking).

The bot → config-file map (`.pr_agent.toml` · `.coderabbit.yaml` · `.github/copilot-instructions.md` ·
`.amazonq/rules/` · `.gitleaks.toml` · `.trivyignore`) is the SSOT in
`skills/bot-finding-arbiter/bot-config-registry.md`.

---

## Anti-Patterns

```
X  git checkout/switch in main repo (use worktree)
X  Push without local CLI review
X  Merge without any review
X  Archiving emails before auditing reviews (audit FIRST)
X  Using email to extract review content (use gh api)
X  Using Gmail MCP for @acme-corp.example.com (not connected)
X  Using qodo self-review without agent.toml (use qodo --ci -y "prompt" instead)
X  Rationalizing protocol bypass: "user said 'resolve gaps' so I can edit in main repo"
   → Task instructions ("fix", "resolve", "implement") are NOT protocol overrides.
   → Only EXPLICIT bypass language counts ("skip worktree", "edit directly").
   → If you catch yourself justifying a bypass, you're already wrong.
```

## Exceptions (Require Justification)

Merge without review ONLY if:
1. **Critical hotfix**: Production down (document urgency)
2. **Explicit bypass**: User authorizes explicitly
3. **Isolated infrastructure**: Config repo with no impact

ALWAYS document exception in the PR.

---

*v1.2.0 | 2026-07-01 | Add Bot-Config Correction Discipline: classify {valid \| bot-wrong \| ambiguous} + teach-the-bot-via-its-config edicts, gated by ⛔never-suppress-valid-security + verifier>generator + repo-fixable-only + narrowest-form + reviewed-PR. Executed by `skills/bot-finding-arbiter` (Praetor); SSOT map in `bot-config-registry.md`.*
*v1.1.0 | 2026-03-11 | Tighten worktree exception clause: "explicit user request" → literal bypass language only + decision checkpoint + rationalization anti-pattern*
*v1.0.0 | 2026-03-06 | Unified from C07 v3.0 + C12 v3.0 + C04 essentials + CLI review tools*
