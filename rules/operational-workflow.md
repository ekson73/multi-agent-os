---
description: Workflow operacional — PR governance + git worktrees + email cleanup
---

# Operational Workflow — PR Governance + Git Worktrees + Email Cleanup

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-03-07 -->
<!-- Scope: User-scope (all projects) -->
<!-- Complements: pr-governance-unified.md (C07+C12), git-worktree-protocol.md (C04) -->

## Quick Reference: Complete PR Lifecycle

```
WORKTREE → CODE → LOCAL REVIEW → FIX LOOP → PUSH → PR → [BOT REVIEW] → MERGE → PULL → AUDIT → ARCHIVE EMAILS → CLEANUP
```

## 1. Worktree Creation (MANDATORY)

```bash
# Create worktree with session-prefixed branch
git worktree add .worktrees/{feature} -b {type}/{feature}
cd .worktrees/{feature}
```

Types: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`

Exceptions: See pr-governance-unified.md Step 1.
NEVER interpret a task instruction ("fix X", "resolve Y") as authorization to skip worktree.

## 2. Code + Commit

```bash
git add <files>
git commit -m "{type}({scope}): {description}"
```

## 3. Local Review (MANDATORY before push)

```bash
# PRIMARY: CodeRabbit CLI
cr review --plain --base main --config CLAUDE.md

# FALLBACK: Qodo CLI (if CodeRabbit rate-limited)
qodo --ci -y "Review the git diff between this branch and main. Focus on correctness, consistency, and compliance."

# If BOTH rate-limited: proceed to push (GitHub bots will review on PR)
```

### CodeRabbit CLI aliases
- `cr` or `coderabbit` — same binary
- `cr review --plain --base main` — minimal output, compare against main
- Rate limit: ~1 review/25min on free plan, 150 files/PR max

### Qodo CLI notes
- `qodo --ci -y "prompt"` — non-interactive mode (no agent.toml needed)
- AVOID `qodo self-review` without agent.toml (opens browser)
- AVOID `-q` flag (suppresses output)

## 4. Fix Loop

```bash
# Fix P0/P1/P2 issues from review
git add <fixed-files>
git commit -m "fix: address review findings"
# Re-run review (step 3) until clean
```

## 5. Push + PR

```bash
git push -u origin {branch-name}
gh pr create --title "{type}({scope}): {description}" --body "$(cat <<'EOF'
## Summary
- ...

## Review
- Local review: CodeRabbit/Qodo CLI (pre-push)
EOF
)"
```

## 6. Merge + Pull

```bash
gh pr merge <N> --merge
cd /path/to/main-repo
git pull origin main
```

## 7. Audit Reviews (gh api)

```bash
gh api repos/{owner}/{repo}/pulls/{N}/comments --jq '.[].body'
gh api repos/{owner}/{repo}/pulls/{N}/reviews --jq '.[] | "\(.state): \(.body)"'
```

## 8. Archive Emails (gog CLI)

```bash
# Search both accounts
gog gmail search '{repo} PR #{N}' -a your-personal-email@example.com -j \
  | python3 -c "import json,sys; [print(t['id']) for t in json.loads(sys.stdin.read()).get('threads',[])]" \
  | xargs -I{} gog gmail thread modify {} --remove INBOX -a your-personal-email@example.com -y

# Check acme-corp account
gog gmail search '{repo}' -a user@acme-corp.example.com -p
```

## 9. Cleanup Worktree

```bash
cd /path/to/main-repo
git worktree remove .worktrees/{feature}
git branch -d {type}/{feature}
git push origin --delete {type}/{feature}
```

## Tool Availability Matrix

| Tool | Binary | Purpose | Rate Limits |
|------|--------|---------|-------------|
| CodeRabbit CLI | `cr` / `coderabbit` | Local code review (primary) | ~1/25min free |
| Qodo CLI | `qodo` | Local code review (fallback) | Server-side limits |
| GitHub CLI | `gh` | PR ops, review audit | None |
| gog CLI | `gog` | Email search + archive | None |
| Gmail MCP | MCP server | Email read (fallback) | @gmail.com only |

## Anti-Patterns

```
X  git checkout/switch in main repo (use worktree)
X  Push without local CLI review
X  Merge without any review
X  qodo self-review without agent.toml
X  qodo -q (suppresses output)
X  gog gmail threads (use singular: thread)
X  Archiving emails BEFORE auditing reviews
X  Using Gmail MCP for @acme-corp.example.com (not connected)
```

---

*v1.1.0 | 2026-03-11 | Add worktree exception cross-reference + task-vs-bypass clarification*
*v1.0.0 | 2026-03-07 | Consolidated from pr-governance-unified.md + git-worktree-protocol.md + operational learnings*
