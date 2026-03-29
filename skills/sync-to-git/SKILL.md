---
name: sync-to-git
version: 1.0.0
description: Git synchronization automation for AI agents with GitHub/Bitbucket support
triggers:
  - sync git
  - git sync
  - push changes
  - create pr
  - check pr status
  - sync status
  - pull changes
tools:
  - Bash
  - Read
  - Write
  - Grep
protocols:
  - C04  # Git Worktree Protocol
  - C07  # PR Review Protocol
  - C06  # AI-Native Environment
---

# sync-to-git Skill

> **Spec**: `~/.claude/docs/specs/sync-to-git-spec.md`
> **Version**: 1.0.0

## Purpose

Automate Git synchronization operations following corporate protocols (C04, C07).

## Quick Reference

| Command | Description |
|---------|-------------|
| `sync-status` | Show repository state |
| `sync-fetch` | Fetch from remotes |
| `sync-pull` | Pull with conflict detection |
| `sync-push` | Push with branch protection |
| `sync-commit` | Commit with Co-Author |
| `sync-pr` | Create/check PRs |
| `sync-merge` | Merge after approval |

## Execution Flow

### 1. Pre-flight Checks

Before any operation:

```bash
# Check if in git repo
git rev-parse --git-dir >/dev/null 2>&1 || exit 1

# Check if in worktree (REGRA 7 C04)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')

if [ "$WORKTREE_PATH" = "$MAIN_REPO" ]; then
  # Em repo principal - verificar se há worktrees disponíveis
  CURRENT_BRANCH=$(git branch --show-current)
  if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
    # VIOLAÇÃO: está em branch feature no repo principal
    echo '{"jsonrpc":"2.0","error":{"code":-32011,"message":"Worktree required","data":{"instructions":"Create worktree: git worktree add .worktrees/$(git branch --show-current)"}}}' >&2
    exit 1
  fi
fi
```

### 2. sync-status

```bash
# Get comprehensive status
BRANCH=$(git branch --show-current)
REMOTE=$(git config --get branch.$BRANCH.remote || echo "origin")
UPSTREAM=$(git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "none")

# Count ahead/behind
if [ "$UPSTREAM" != "none" ]; then
  AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
else
  AHEAD="?"
  BEHIND="?"
fi

# Uncommitted changes
UNCOMMITTED=$(git status --porcelain | grep -c "^[MADRC]" || echo "0")
UNTRACKED=$(git status --porcelain | grep -c "^??" || echo "0")

# Remote info
REMOTE_URL=$(git remote get-url $REMOTE 2>/dev/null || echo "none")

# Detect provider
if [[ "$REMOTE_URL" == *"github.com"* ]]; then
  PROVIDER="github"
elif [[ "$REMOTE_URL" == *"bitbucket.org"* ]]; then
  PROVIDER="bitbucket"
else
  PROVIDER="unknown"
fi

echo "Branch: $BRANCH"
echo "Remote: $REMOTE ($PROVIDER)"
echo "Ahead: $AHEAD | Behind: $BEHIND"
echo "Uncommitted: $UNCOMMITTED | Untracked: $UNTRACKED"
```

### 3. sync-fetch

```bash
git fetch --all --prune
```

### 4. sync-pull

```bash
# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo '{"jsonrpc":"2.0","error":{"code":-32013,"message":"Uncommitted changes","data":{"instructions":"Commit or stash changes first: git stash"}}}' >&2
  exit 1
fi

# Detect potential conflicts
git fetch origin
CONFLICTS=$(git diff --name-only HEAD...origin/$(git branch --show-current) 2>/dev/null)
if [ -n "$CONFLICTS" ]; then
  echo "Potential conflicts in: $CONFLICTS"
  # Continue anyway with merge
fi

git pull --rebase
```

### 5. sync-push

```bash
BRANCH=$(git branch --show-current)
PROTECTED="main master develop"

# Branch protection gate
if [[ " $PROTECTED " =~ " $BRANCH " ]]; then
  echo '{"jsonrpc":"2.0","error":{"code":-32010,"message":"Branch protection","data":{"instructions":"Cannot push directly to protected branch. Create PR instead."}}}' >&2
  exit 1
fi

# Check if upstream exists
if ! git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
  git push -u origin $BRANCH
else
  git push
fi
```

### 6. sync-commit

```bash
# Usage: sync-commit "type(scope): description"
MESSAGE="$1"
CO_AUTHOR="Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>"

# Validate conventional commits
if ! echo "$MESSAGE" | grep -qE "^(feat|fix|docs|chore|refactor|test|style|perf|ci|build)(\(.+\))?:"; then
  echo "Warning: Message doesn't follow Conventional Commits format"
fi

# Check if there are staged changes
if [ -z "$(git diff --cached --name-only)" ]; then
  echo '{"jsonrpc":"2.0","error":{"code":-32013,"message":"No staged changes","data":{"instructions":"Stage changes first: git add <files>"}}}' >&2
  exit 1
fi

git commit -m "$(cat <<EOF
$MESSAGE

$CO_AUTHOR
EOF
)"
```

### 7. sync-pr (GitHub)

```bash
# Create PR
BRANCH=$(git branch --show-current)
BASE="${2:-main}"
TITLE="$1"

# Ensure branch is pushed
git push -u origin $BRANCH 2>/dev/null

# Create PR using gh CLI
gh pr create --title "$TITLE" --body "$(cat <<EOF
## Summary
[Description of changes]

## Test Plan
- [ ] Tests pass
- [ ] Manual testing done

---
Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>
EOF
)" --base "$BASE"

# Get PR URL
PR_URL=$(gh pr view --json url -q '.url')
echo "PR created: $PR_URL"
```

### 8. sync-pr status

```bash
# Check PR status
PR_STATUS=$(gh pr view --json state,reviews,statusCheckRollup)
echo "$PR_STATUS"
```

### 9. sync-merge

```bash
# Pre-merge checks
PR_STATE=$(gh pr view --json state -q '.state')
if [ "$PR_STATE" != "OPEN" ]; then
  echo "PR is not open"
  exit 1
fi

# Check reviews
REVIEWS=$(gh pr view --json reviews -q '.reviews | length')
if [ "$REVIEWS" -eq 0 ]; then
  echo '{"jsonrpc":"2.0","error":{"code":-32015,"message":"Review pending","data":{"instructions":"Wait for review or delegate to code-reviewer agent"}}}' >&2
  exit 1
fi

# Check CI
CI_STATUS=$(gh pr view --json statusCheckRollup -q '.statusCheckRollup[0].conclusion')
if [ "$CI_STATUS" != "SUCCESS" ]; then
  echo '{"jsonrpc":"2.0","error":{"code":-32016,"message":"CI failed","data":{"instructions":"Fix CI failures before merge"}}}' >&2
  exit 1
fi

# Merge
gh pr merge --merge
```

## Safety Gates

### Branch Gate
- NEVER `push --force` to protected branches
- NEVER merge directly (always via PR)
- WARN on rebase of published branches

### Worktree Gate (C04)
- If in main repo on feature branch → ERROR
- Must create worktree first

### Conflict Gate
- Detect conflicts before pull/merge
- List affected files
- Require manual resolution

### PR Gate (C07)
- Verify PR exists before merge
- Verify reviews received
- Verify CI passed
- Respect TTL (30min default)

## Error Codes

| Code | Name | Recovery |
|------|------|----------|
| -32010 | Branch protection | Use PR instead |
| -32011 | Worktree required | Create worktree |
| -32012 | Conflict detected | Resolve manually |
| -32013 | Uncommitted changes | Commit or stash |
| -32014 | PR not found | Create PR first |
| -32015 | Review pending | Wait or delegate |
| -32016 | CI failed | Fix failures |

## Integration Notes

### With C04 (Git Worktree Protocol)
- Always check if in worktree before modifications
- Respect REGRA 7: NEVER switch branches in main repo
- Use `cd .worktrees/{name}` instead of `git checkout`

### With C07 (PR Review Protocol)
- Create PR after push (never merge direct)
- Wait for review with TTL
- Analyze review feedback
- Auto-delegate if timeout

## Examples

```bash
# Full workflow
sync-to-git status
sync-to-git fetch
sync-to-git pull
# ... make changes ...
git add .
sync-to-git commit "feat(auth): add JWT validation"
sync-to-git push
sync-to-git pr create "feat(auth): add JWT validation"
# ... wait for review ...
sync-to-git pr status
sync-to-git merge
```

---

*Skill Version: 1.0.0 | Protocols: C04, C07, C06*
