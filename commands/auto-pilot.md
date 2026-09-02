---
name: auto-pilot
description: Autonomous unattended orchestration entry point — decompose, select, spawn, and converge a goal across sub-agents with hard-bounded autonomy levels
---

# /auto-pilot Command

Drive an entire operator goal end-to-end across one or more sub-agents using
the existing GaaS/GaaC delegation framework, with hard-bounded autonomy
levels and depth-capped recursion. Thin entry point over the
[`auto-pilot` skill](../skills/auto-pilot/SKILL.md).

## Usage

```
/auto-pilot "<goal>" [--mode=<mode>] [--band=<band>]
```

## Modes

| Mode | Description | Cap |
|---|---|---|
| `sequential` (default) | select → init → Task → finalize → next | depth ≤ 2 |
| `parallel` | single message, N Task calls, merged by `agents/consolidator.md` | N ≤ 3 per spawn |
| `recursive` | child re-enters `auto-pilot` with incremented depth | depth ≤ 2 (hard) |
| `debate-converge` | N divergent agents in parallel, then `skills/converge/SKILL.md` | N ≤ 3, max_rounds ≤ 3 |
| `dueto` | alias for `parallel` with N = 2 | N = 2 |
| `swarm` | alias for `parallel` with N ≥ 3 | N ≤ 3 |

## Autonomy bands

| Band | Proceeds without HITL | Pauses for HITL |
|---|---|---|
| `L1-cautious` | Read-only ops, analysis | Any write attempt |
| `L2-bounded` (default) | Writes inside worktree; draft PR creation; no force-push; no protected-file edits | Destructive ops; protected files; cross-tenant data; Sentinel HIGH severity; 6 failed attempts |
| `L3-extended` | L2 + non-draft PR open + auto-merge of green-bot PRs | Sentinel HIGH; OWASP LLM01 prompt-injection signal; secret detection |

## Examples

```
/auto-pilot "migrate the auth module to the new session store"
/auto-pilot "review these 3 competing designs" --mode=debate-converge
/auto-pilot "open the release PR" --band=L3
```

## Environment

Non-negotiable invariants (never overridable by band or mode): worktree
discipline always on, depth ≤ 2 hard cap, `delegation-init-prompt.md`
§Rejection conditions always honored, Sentinel thresholds authoritative.

## Integration

- Skill: [`skills/auto-pilot/SKILL.md`](../skills/auto-pilot/SKILL.md) (the orchestration kernel — decomposition, DNA payload, anti-loop invariants, failure modes).
- Composes: `skills/agent-select`, `skills/converge`, `skills/delegate-governance`, `skills/anti-conflict`, `skills/worktree-policy`, `agents/orchestrator.md`, `agents/consolidator.md`.
- Governance: `protocols/delegation/{delegation-init-prompt,delegation-dna-prompt,delegation-finalize-prompt,provider-matrix}.md`, `sentinel/{config.json,detection_rules.md}`.
