---
name: quiesce
description: Drive the current session to QUIESCENCE — no open ticket/gap/fix/failure/PR, every PR green + answered, agentic convergence — by composing the native /goal condition-loop with a pluggable inner driver (default auto-pilot). Override-friendly.
---

# /quiesce Command

Thin wrapper that invokes `skills/quiesce/SKILL.md`. The skill holds all logic
(quiescence predicate, `/goal` + inner-driver composition, PDCA-converge, auto
ticket filing, STOP-marker grammar, bounds). This file is the command surface only.

## Usage

```
/quiesce ["<instructions>"] [--scope=…] [--condition=…] [--driver=…] \
         [--auto-merge=…] [--auto-merge-reason="…"] [--auto-fix=…] [--self-fix=…] \
         [--autonomy-threshold=…] [--max-pdca=…]
```

All flags are optional — invoking bare `/quiesce` uses the defaults below.

## Flags

| Flag | Default | Allowed values |
|---|---|---|
| `"<instructions>"` (positional) | empty | extra free-text appended to the driver action |
| `--scope` | `this.session` | `this.session`, `repo`, `branch`, `ticket:<id>`, `pr:<n>` |
| `--condition` | *(quiescence predicate)* | any override termination predicate string |
| `--driver` | `auto-pilot` | `auto-pilot`, `auto-orchestrator`, `<custom>` |
| `--auto-merge` | `authorized` | `authorized`, `hold`, `off` |
| `--auto-merge-reason` | *(operator invocation)* | non-empty string; required when `--auto-merge=authorized` |
| `--auto-fix` | `enabled` | `enabled`, `disabled` |
| `--self-fix` | `enabled` | `enabled`, `disabled` |
| `--autonomy-threshold` | `0.85` | `0.0`–`1.0` (maps to auto-pilot band L1/L2/L3) |
| `--max-pdca` | `6` | integer — per-PR PDCA iteration cap |

See `skills/quiesce/SKILL.md` § Override parameters and § Quiescence predicate for
the meaning of each value.

## Examples

```
/quiesce
/quiesce "prioritize the auth PRs first"
/quiesce --scope=pr:42 --auto-merge=hold
/quiesce --condition='NOT open PR AND every PR green' --max-pdca=3
/quiesce --driver=auto-orchestrator --auto-merge=authorized --auto-merge-reason="nightly convergence"
```

## Workflow (delegates to the skill)

1. Resolve flags → defaults unless overridden.
2. Emit `/goal --goal-aware --scope=<scope> --condition='<predicate>'` (outer loop).
3. Each iteration runs the inner `<driver>` (default `auto-pilot`) which PDCA-converges
   open PRs and files tracking tickets for out-of-radar items.
4. Emit exactly ONE `<!--ORCH-STATUS: … -->` STOP marker per turn for the `/goal` evaluator.
5. Terminate when the quiescence predicate holds.

## Anti-loop / autonomy bounds

Inherited from the skill — `--max-pdca` cap (6), depth ≤ 2, Sentinel HIGH auto-blocks,
6-attempt escalation, HUMAN_DOMAIN + non-negotiable guardrails always halt → HITL.
See `skills/quiesce/SKILL.md` § Anti-loop invariants and § Auto-merge.

## Related

`skills/quiesce/SKILL.md` (logic) · `skills/auto-pilot/SKILL.md` (default driver, sibling) ·
`skills/converge/SKILL.md` (used inside PDCA) · `commands/auto-pilot.md`.
