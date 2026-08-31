# Provider Selection Matrix (GaaS/GaaC)

> Pure lookup — no code. Every row/cell cites the file that is the source of truth.
> When a primary tool fails, try fallbacks **in order**. Never invent a new path silently.

## Scope

Covers 4 operation axes × 3 provider domains. Agents use this to stop re-deciding "which tool for this call" per invocation.

- **Ticket providers**: Jira (`VKS-*`) · Linear (`VKO-*`, `EKO-*`)
- **VCS providers**: Bitbucket · GitHub · GitLab
- **Secrets**: your organization's secret-manager CLI (e.g. 1Password, Vault, AWS Secrets Manager)
- **Observability**: session audit JSONL + `/agentic-status` + `/audit` skills

Legend: `→` means fallback. Paths are relative to repo root unless noted.

---

## Ticket operations

### Jira (`VKS-*` keys; cloud `vek.atlassian.net`)

| Operation | Primary | Fallback 1 | Fallback 2 |
|---|---|---|---|
| read / list | `mcp__maos-mcp-hub__atlassian_jira` (`resource: issue\|search`, `operation: get\|jql`) — see `mcp-tools/maos-mcp-hub/gateways/jira/actions.py` | `mcp__atlassian-rovo__getJiraIssue` / `searchJiraIssuesUsingJql` | `acli jira issue view` |
| create / update | `mcp__maos-mcp-hub__atlassian_jira` (`resource: issue`, `operation: create\|edit`) | `mcp__atlassian-rovo__createJiraIssue` / `editJiraIssue` | `acli jira issue create\|edit` |
| comment / review | `mcp__maos-mcp-hub__atlassian_jira` (`resource: comment`, `operation: add`) | `mcp__atlassian-rovo__addCommentToJiraIssue` | `acli jira issue comment` |
| close / transition | `mcp__maos-mcp-hub__atlassian_jira` (`resource: issue`, `operation: transition` after `get_transitions`) | `mcp__atlassian-rovo__transitionJiraIssue` | `acli jira issue transition` |

**Gotcha**: search endpoint migrated `/search` → `/search/jql` per Atlassian CHANGE-2046 (fixed in `maos-mcp-hub` PR #38). If running hub is stale, fallback 1 works.

### Linear (`VKO-*`, `EKO-*` keys; `linear.app/ekson73`)

| Operation | Primary | Fallback 1 |
|---|---|---|
| read / list | `mcp__claude_ai_Linear__list_issues` / `get_issue` | Linear REST API via `curl -H "Authorization: $LINEAR_API_KEY"` |
| create / update | `mcp__claude_ai_Linear__save_issue` | Linear GraphQL via `curl` |
| comment | `mcp__claude_ai_Linear__save_comment` | Linear GraphQL |
| close | `mcp__claude_ai_Linear__save_issue` (`state: "Done"`) | Linear GraphQL |

---

## VCS operations

### GitHub (`github.com/ekson73/*`, `github.com/vek-im/*`)

| Operation | Primary | Fallback 1 | Fallback 2 |
|---|---|---|---|
| read / list branches & PRs | `gh pr list`, `gh pr view`, `gh api /repos/{owner}/{repo}/...` | `git ls-remote` | GitHub REST via `curl -H "Authorization: Bearer $GITHUB_TOKEN"` |
| branch create / commit / push | `git` (local) + `env -u GITHUB_TOKEN git push` | `gh api -X POST /repos/.../git/refs` | — |
| PR create / review | `gh pr create`, `gh pr comment`, `gh pr review` | `gh api -X POST /repos/.../pulls` | REST via `curl` |
| merge | `gh api -X PUT /repos/.../pulls/{n}/merge` (REST — avoids local-checkout side effects) | `gh pr merge` | REST via `curl` |

**Auth pattern** (per `feedback_autonomous_merge.md` + this session): run `gh` commands with `env -u GITHUB_TOKEN` when a stale `GITHUB_TOKEN` env var is present; this forces `gh` to use the keyring auth. See also `rules/agent-scm.md` §GitHub.

### Bitbucket (`bitbucket.org/vek-servicos/*` — VKS repos)

| Operation | Primary | Fallback 1 |
|---|---|---|
| read / list pipelines, PRs, branches | `mcp__maos-mcp-hub__bitbucket_*` (flat tools deprecated — use `atlassian_bitbucket(resource, operation, params)`) | Bitbucket REST via `curl -u $BITBUCKET_EMAIL:$BITBUCKET_API_TOKEN` |
| branch create / PR create | `mcp__maos-mcp-hub__atlassian_bitbucket` (`resource: branch\|pull_request`, `operation: create`) | Bitbucket REST |
| PR comment / approve | `mcp__maos-mcp-hub__atlassian_bitbucket` (`resource: pull_request`, `operation: approve\|unapprove`) + PR-level comment via web UI until API supports | Bitbucket REST |
| merge | `mcp__maos-mcp-hub__atlassian_bitbucket` (`resource: pull_request`, `operation: merge`) with `account="emilson"` for write ops | Bitbucket REST |

**Multi-persona**: write ops (`approve`, `merge`, `comment`) require `account="emilson"` parameter per `rules/agent-scm.md` §Bitbucket and `CLAUDE.md` §Multi-persona.

### GitLab (future; `glab` when available)

| Operation | Primary | Fallback 1 |
|---|---|---|
| all | `glab` CLI when installed | GitLab REST via `curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN"` |

Not currently active in this ecosystem; placeholder for `rules/agent-scm.md` §GitLab alignment.

---

## Secrets

| Operation | Primary | Fallback 1 |
|---|---|---|
| read a single secret | your secret-manager CLI (e.g. `op item get`, `vault kv get`, `aws secretsmanager get-secret-value`) | `~/.env` file (only when the secret manager is offline and ownership is the user's own repo) |
| list items | your secret-manager CLI's list/search command | pipe its JSON output through `jq` |

Rule: **never** print a secret to stdout in a message that might be logged outside the user's machine. Use env-var passthrough (`TOKEN=$(<secret-manager-cmd>) cmd`). See `rules/axial-principles.md` §Cerimônia de Fechamento and `feedback_multi_agent_harmony.md` (Credential safety).

---

## Observability

| Operation | Primary | Fallback 1 |
|---|---|---|
| write a trace event | append line to `~/.claude/audit/session_${CLAUDE_SESSION_ID}.jsonl` (pattern in `plugin-scripts/pre-delegate.sh` and `post-delegate.sh`) | `printf '%s\n' "$EVENT" >> session.log` |
| session status (human-readable) | `/agentic-status` skill → `skills/status-map/SKILL.md` (templates PULSE / COMPACT / FULL / DEBUG / PRE / END) | `git log --oneline -5 && git worktree list` |
| session audit on-demand | `/audit` skill → `skills/audit/SKILL.md` | grep of `session_*.jsonl` |

---

## Provider detection (auto)

Agents detect providers deterministically — no guessing:

```bash
# Ticket provider from key prefix — MUST stay in lock-step with plugin-scripts/gaac/delegate.sh
case "${TICKET:-}" in
  VKS-*|VKS_*) TICKET_PROVIDER=jira ;;
  VKO-*|EKO-*) TICKET_PROVIDER=linear ;;
  "") TICKET_PROVIDER=none ;;  # empty → ad-hoc session
  *) TICKET_PROVIDER=auto ;;   # unknown prefix → escalate to user
esac

# VCS provider from git remote
REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
case "$REMOTE_URL" in
  *bitbucket.org*) VCS_PROVIDER=bitbucket ;;
  *github.com*) VCS_PROVIDER=github ;;
  *gitlab.com*) VCS_PROVIDER=gitlab ;;
  *) VCS_PROVIDER=none ;;  # no git or unknown host
esac
```

See `plugin-scripts/gaac/delegate.sh` for the canonical implementation.

---

## Cross-pairs (Linear ticket + Bitbucket repo, Jira ticket + GitHub repo, etc.)

Matrix rows are independent across axes. If a session has a Linear ticket but a Bitbucket repo, follow the Linear row for ticket ops and the Bitbucket row for VCS ops. No assumption of canonical pairing.

---

## Changelog of this matrix

| Date | Change | Reason |
|---|---|---|
| 2026-04-18 | Initial version (v1.0) | GaaS/GaaC delegation framework (this PR) |

When a provider migrates an endpoint (see CHANGE-2046 for Jira search), update this file first, then update the corresponding MCP gateway or CLI call-sites. Consumers of the matrix should pin to `protocols/delegation/provider-matrix.md` path.
