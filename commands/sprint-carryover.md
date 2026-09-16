---
name: sprint-carryover
description: Relocate stranded open backlog from past/closed sprints INTO the active sprint (dry-run default; MOVE is operator-gated; discovery composes work-compass; report table ticket-id | Title/Description-slug | Old Sprint | New Sprint)
---

# /sprint-carryover Command

Carry the operator's **stranded open backlog** — items still owned by you, your ai-bot-agents, or
your department but stuck on a **past/closed sprint** — forward into the **current active sprint**.
Thin entry point over the [`sprint-carryover` skill](../skills/sprint-carryover/SKILL.md).
**dry-run by default** — a bare invocation discovers and renders the proposed move-set and writes
NOTHING. The MOVE is a bulk mutation of a shared tracker (HUMAN_DOMAIN) and is **operator-gated**:
the move-set is presented for confirmation BEFORE any write.

## Usage

```
/sprint-carryover [--scope identity,agents,department] [--department X] [--project KEY] [--active-sprint S] [--dry-run=off] [--json]
```

## Parameters

| Param | Default | Effect |
|-------|---------|--------|
| `--identity` | `auto` | operator login/email/displayName; `auto` = tracker `myself` / `git config user.email` / env |
| `--agents` | `auto` | comma-list of the operator's ai-bot-agent logins; `auto` = config/registry or `--agents-file` |
| `--department` | — | area label(s): `devops` · `dev-fe` · `dev-be` · `ba` · `sa` (tracker component/team/label) |
| `--project` | `auto` | tracker project key/board; `auto` = infer from remote or a single accessible project, else HITL |
| `--active-sprint` | `auto` | the current active sprint; `auto` = the board's `state=active` sprint; ambiguous ⇒ HITL |
| `--scope` | `identity` | owner-sets to include (union): any combination of `identity`,`agents`,`department` |
| `--dry-run` | **on** | discover + render the move table; NO write. Forced off only with explicit operator GO |
| `--json` | off | machine envelope (agent-to-agent) |

## Examples

```
/sprint-carryover                                          # dry-run: my stranded items -> proposed table
/sprint-carryover --scope identity,agents                   # include my bot-agents' stranded items
/sprint-carryover --department dev-be --project VKS          # a department's backlog on a named board
/sprint-carryover --active-sprint "Sprint 42" --dry-run=off  # GATED move into a named active sprint (needs GO)
/sprint-carryover --json                                     # machine envelope
```

## Behavior

- **Composes, never reimplements**: discovery, identity/owner-matching, and sprint enumeration are
  delegated to `work-compass` (the same way `work-drain` composes it) — no tracker access is rebuilt here.
- **Capability-detected**: probes the tracker surface (MCP: atlassian/jira/linear/gh-issues; then CLI:
  `gh`, `acli`, `jira`) — never fabricated; a missing surface degrades to `unavailable`, never blocks.
- **dry-run default / gated MOVE**: the move-set is shown for confirmation first; nothing is written
  without an explicit operator GO. HUMAN_DOMAIN bulk mutation of a shared tracker.
- **Level-triggered / idempotent**: re-derives the candidate set from the tracker each pass; a re-run
  after a partial move is a no-op on already-moved items.
- **Report contract**: table with columns exactly `ticket-id | Title/Description-slug | Old Sprint | New Sprint`.
  Nothing skipped is silently dropped — each skip is named with a reason.

## Integration

- Skill: [`skills/sprint-carryover/SKILL.md`](../skills/sprint-carryover/SKILL.md) (orchestrator).
- Composes: [`skills/work-compass`](../skills/work-compass/SKILL.md) (discovery/identity/sprint enumeration).
- Distinct from: [`work-compass`](../skills/work-compass/SKILL.md) (detect, read-only) ·
  [`work-drain`](../skills/work-drain/SKILL.md) (drain to DONE, executes) — this one **relocates** across sprints.
- Governance: `skills/worktree-policy`, `skills/hierarchical-merge` (reused, not re-authored).
- Named by: `skills/anima` (system-name `sprint-carryover`; rejected runner-up `backlog-rollover`).
