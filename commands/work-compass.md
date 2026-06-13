---
name: work-compass
description: Aggregate scattered work (Jira/GitHub/sessions/git) into ONE N-Tree, detect stale/orphan/pending, route node actions to existing tools (read-only; review-before-submit)
---

# /work-compass Command

Render the operator's **unified work-landscape N-Tree** across the 7 CPT domains
(ticket · worktree · branch · session · thread · process · graph-node), flag
stale/orphan/pending items, and suggest a routing command per node. Thin entry point over
the [`work-compass` skill](../skills/work-compass/SKILL.md). **Read-only by default** — any
write/pause/stop/delete is *printed for approval*, never executed.

## Usage

```
/work-compass [action]
```

## Actions

| Action | Description |
|--------|-------------|
| *(none)* | Aggregate + render the ASCII N-Tree across all available domains. |
| `detect` | Print only the flagged stale/orphan/pending candidates (JSON). |
| `json` | Emit the normalized work-item graph (agent-to-agent). |
| `forward` | Compass `--scope forward` — just the work queue (flagged items). |
| `route <id>` | Print a SUGGESTED command to act on a node (review-before-submit). |
| `mermaid` | Render the tree as a mermaid flowchart. |

## Examples

```
/work-compass                              # full N-Tree for the current repo
/work-compass detect                       # what's stale/orphan/pending
/work-compass route branch:feat/x          # suggested command for a node (read-only)
/work-compass forward                      # the actionable queue
```

## Behavior

- **Composes, never reimplements**: `inventory-sessions.py` (sessions/branches) · `gh pr/issue list` · `acli jira` · `git worktree list`/`branch -vv`.
- **Capability-detected**: a missing provider → domain marked `unavailable`, never blocks.
- **Read-only contract**: the router returns `execute: false` + a `suggested_command`; the operator submits it.
- **Deterministic**: same input → same tree (CPT §9.5 consumer contract).

## Integration

- Skill: [`skills/work-compass/SKILL.md`](../skills/work-compass/SKILL.md) (orchestrator).
- Script: `bin/work-compass-aggregate.py` (stdlib-only aggregator/renderer/detector/router).
- Composes: `inventory-sessions.py`, `gh`, `acli`, native git.
- Routes to: `/preflight`, `/maos:postflight`, `/maos:auto-pilot`, `/morning-briefing --mode=recap`, `/maos:quiesce`, `/auto-orchestrator`, `/ticket-as-prompt`.
- Complements: `morning-briefing` (per-domain READ) · `maos-concierge` (framework router) · CPT §9.5 Compass API (consumer).
