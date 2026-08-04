---
name: work-drain
description: Drain a set of <object-targets> (sprint · backlog query · open PRs · tracker issues) item-by-item to quiescence — discover, derive an ordered register, and delegate each item to quiesce. Level-triggered and resumable. Soul-name: Antlia.
---

# /maos:work-drain — Antlia

Thin wrapper that invokes `skills/work-drain/SKILL.md`. The skill holds all logic
(level-triggered register derivation, Eisenhower × dependency ordering, per-item
delegation to `quiesce`, poison-item quarantine, bounds). This file is the command
surface only.

> **Invocation**: canonical form is `/maos:work-drain` (`plugin.json` sets
> `command_namespace.prefix_required = true`, so plugin commands surface namespaced).
> Bare `/work-drain` may work where the host does not implement the namespace layer,
> but write the prefixed form everywhere.

## Usage

```text
/maos:work-drain <object-targets> [--owner=…] [--filter=…] [--sort=…] [--tracker=…] \
                 [--max-items=…] [--max-attempts=…] [--auto-merge=…] [--auto-merge-reason="…"] \
                 [--autonomy-threshold=…] [--max-pdca=…] [--dry-run]
```

`<object-targets>` is required. Everything else is optional and uses the skill's defaults.

## Object-targets

| Form | Drains |
|---|---|
| `sprint:current` | the active sprint's open items for `--owner` |
| `sprint:<name>` | a named sprint (use when `current` doesn't resolve) |
| `jql:"<query>"` | an explicit tracker query |
| `label:<x>` | items carrying a label |
| `issues:<owner>/<repo>` | a repo's open issues |
| `prs:open` | open PRs awaiting convergence |

Comma-separate to combine.

## What it does

1. **DERIVE** — re-read the trackers and build the register (level-triggered: every pass
   re-derives from source, never replays a stored queue).
2. **ORDER** — Eisenhower quadrant × dependency-DAG topological sort.
3. **SELECT** — the next item whose dependencies are satisfied, skipping quarantined ones.
4. **DRAIN** — `/maos:quiesce --scope ticket:<id>` with the forwarded control flags.
5. **VERIFY** — re-read the item; closed → continue, unchanged → count an attempt.
6. **LOOP** — back to step 1 until the register derives empty.

## Safety defaults

- `--auto-merge` defaults to **`hold`** — draining N items with auto-merge on multiplies
  blast-radius by N, so authorization is explicit and per-drain.
- `--max-items` (20) bounds the register; overflow is **reported**, never silently dropped.
- `--max-attempts` (2) quarantines a poison item instead of letting it block the drain.
- If ≥half the register quarantines, the drain **stops and escalates** — systemic fault.

## Anti-loop / autonomy bounds

Inherited from the skill and from `quiesce` per item — `--max-pdca` (6), depth ≤ 2,
Sentinel HIGH auto-blocks, 6-attempt escalation, HUMAN_DOMAIN + non-negotiable guardrails
always halt → HITL. See `skills/work-drain/SKILL.md` (Bounds + Autonomy posture).

## Related

`skills/work-drain/SKILL.md` (logic) · `skills/quiesce/SKILL.md` (per-item driver) ·
`skills/chief-of-staff/SKILL.md` (read-only twin) · `skills/gap-loop/SKILL.md` (sibling) ·
`commands/quiesce.md` · `commands/chief-of-staff.md`.
