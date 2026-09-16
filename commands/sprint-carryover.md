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

```text
/sprint-carryover [--scope identity,agents,department] [--department X] [--project KEY] [--active-sprint S] [--apply] [--json]
```

## Parameters

| Param | Default | Effect |
|-------|---------|--------|
| `--identity` | `auto` | operator login/email/displayName; `auto` = tracker `myself` / `git config user.email` / env |
| `--agents` | `auto` | comma-list of the operator's ai-bot-agent logins; `auto` = config/registry or `--agents-file` |
| `--agents-file` | — | path to a file listing bot logins (one per line); takes precedence over `--agents` when both are supplied |
| `--department` | — | area label(s): `devops` · `dev-fe` · `dev-be` · `ba` · `sa` (tracker component/team/label) |
| `--project` | `auto` | tracker project key/board; `auto` = infer from remote or a single accessible project, else HITL |
| `--active-sprint` | `auto` | the current active sprint; `auto` = the board's `state=active` sprint; ambiguous ⇒ HITL |
| `--scope` | `identity` | owner-sets to include (union): any combination of `identity`,`agents`,`department` |
| `--apply` | **off** | WRITE the moves. Absent = dry-run (the default): discover + render the move table, write NOTHING. With `--apply`, skip the interactive confirm and move directly (still subject to the per-item phase-5 re-check). |
| `--json` | off | machine envelope (agent-to-agent) |

## Examples

```text
/sprint-carryover                                          # dry-run: propose table, then ASK "apply for real?"
/sprint-carryover --scope identity,agents                   # include my bot-agents' stranded items
/sprint-carryover --department dev-be --scope department --project VKS  # a department's backlog on a named board
/sprint-carryover --active-sprint "Sprint 42" --apply        # GATED move into a named active sprint (needs the per-item re-check)
/sprint-carryover --json                                     # machine envelope
```

## Behavior

- **Composes as fast-path, extends where needed**: `work-compass` is the deterministic fast-path for
  the discovery **fan-out + identity seed** (the same way `work-drain` composes it). Sprint enumeration,
  other-owner/department/label/component matching, and pagination are the skill's **own tracker-native
  query** layered on top — with hybrid/forward-compatible escalation (enrich → provision → DEFER-HITL)
  where a capability is absent today. No tracker-access plumbing is rebuilt here.
- **Capability-detected**: probes the tracker surface (MCP: atlassian/jira/linear/gh-issues; then CLI:
  `gh`, `acli`, `jira`) — never fabricated; a missing surface degrades to `unavailable`, never blocks.
- **dry-run default / gated MOVE**: a bare interactive invocation (human at a TTY, no `--json`) proposes the move-set, then ASKS "apply for real? [y/N]"; nothing is written on NO / no answer. A non-interactive or `--json` run does NOT prompt — it stops read-only at the proposed move-set (verdict DRY_RUN); it writes ONLY with an explicit `--apply`. `--apply` moves directly (skips the prompt, keeps the per-item re-check). HUMAN_DOMAIN bulk mutation of a shared tracker.
- **Level-triggered / idempotent**: re-derives the candidate set from the tracker each pass; a re-run
  after a partial move is a no-op on already-moved items.
- **Report contract**: table with columns exactly `ticket-id | Title/Description-slug | Old Sprint | New Sprint`.
  Nothing skipped is silently dropped — each skip is named with a reason.

## Integration

- Skill: [`skills/sprint-carryover/SKILL.md`](../skills/sprint-carryover/SKILL.md) (orchestrator).
- Composes: [`skills/work-compass`](../skills/work-compass/SKILL.md) (fast-path discovery fan-out + identity seed).
- Distinct from: [`work-compass`](../skills/work-compass/SKILL.md) (detect, read-only) ·
  [`work-drain`](../skills/work-drain/SKILL.md) (drain to DONE, executes) — this one **relocates** across sprints.
- Governance: `skills/worktree-policy`, `skills/hierarchical-merge` (reused, not re-authored).
- Named by: `skills/anima` (system-name `sprint-carryover`; rejected runner-up `backlog-rollover`).
