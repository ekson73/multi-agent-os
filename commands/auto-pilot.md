---
name: auto-pilot
description: Drive an operator goal end-to-end across one or more sub-agents using the existing GaaS/GaaC framework, with hard-bounded autonomy levels.
---

# /auto-pilot Command

Thin wrapper that invokes `skills/auto-pilot/SKILL.md`. The skill holds all
orchestration logic; this file is the command surface only.

## Usage

```
/auto-pilot "<goal>" [--mode=<mode>] [--band=L1|L2|L3] [--max-depth=2]
```

## Flags

| Flag | Default | Allowed values |
|---|---|---|
| `--mode` | `sequential` | `sequential`, `parallel`, `recursive`, `debate-converge`, `dueto`, `swarm` |
| `--band` | `L2-bounded` | `L1-cautious`, `L2-bounded`, `L3-extended` |
| `--max-depth` | `2` | integer 1 or 2 (hard cap 2) |

See `skills/auto-pilot/SKILL.md` §Delegation modes and §Autonomy bands for
the meaning of each value.

## Examples

```
/auto-pilot "Decompose roadmap, route per perspective, consolidate" --mode=parallel
/auto-pilot "Compare two ADR drafts and merge" --mode=debate-converge
/auto-pilot "Read-only audit of skills/ frontmatters" --band=L1
```

## Workflow (delegates to the skill)

1. Agent selection — `skills/agent-select/SKILL.md`
2. Per-spawn init — `plugin-scripts/gaac/delegate.sh init`
3. Spawn — `Task` tool
4. Mid-flight DNA refresh (if drift) — `delegate.sh dna`
5. Finalize — `delegate.sh finalize`
6. If multi-proposal — `skills/converge/SKILL.md`

## Anti-loop / autonomy bounds

Inherited from the skill — depth ≤ 2 hard cap, Sentinel HIGH auto-blocks,
6-attempt escalation rule, no protected-file edits without a lock.
See `skills/auto-pilot/SKILL.md` §Anti-loop invariants and §Autonomy bands.
