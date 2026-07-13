---
name: ooda-loop
description: Run the operator's recover->measure->converge contract end-to-end as ONE preset — Observe (recover the goal -> handoff-as-prompt) -> Orient (derive a measurable DoD via Prisma -> dod-as-prompt) -> Decide (dual inconclusive->HITL + autonomy gate) -> Act (drive the typed {goal, dod} pair to quiescence via gap-loop or quiesce). Thin composer; inherits (never re-loosens) gap-loop's verifier != generator invariant.
---

# /ooda-loop Command

Thin wrapper that invokes `skills/ooda-loop/SKILL.md`. The skill holds all logic
(the OODA map, the typed {goal, dod} pair flow, the DECIDE gate, the driver resolution,
the composition wiring, the override flags, the output contract, and the STOP-marker grammar).
This file is the command surface only.

The DoD envelope contract lives in `skills/ooda-loop/templates/dod-as-prompt.schema.json`
(wraps Prisma); the goal envelope + validator live under `skills/goal-recovery/`.

## Usage

```text
/ooda-loop "<extra instructions>"
           [--scope=this.session|branch|ticket:<id>|session:<id>]   (default this.session)
           [--driver=auto|gap-loop|quiesce|<custom>]                (default auto)
           [--conf-inconclusive=0.60]      (goal-recovery HITL gate)
           [--autonomy-threshold=0.85]     (DECIDE gate + passed to driver)
           [--max-iterations=6]            (ACT loop cap)
           [--auto-merge=hold|authorized|off]   (default hold)
           [--auto-merge-reason="<why>"]        (required when --auto-merge=authorized)
           [--output=text|json]
           [--dry-run]                     (recover + measure + gate; print the pair; do NOT drive)
```

Sibling routing: use `auto-pilot` when the goal is EXPLICIT and you only need decompose+delegate;
use `gap-loop`/`quiesce` directly when you ALREADY have a typed goal + DoD; use `ooda-loop` when the
goal is UNSTATED and you want the FULL recover->measure->converge contract in one move. `--driver=auto`
picks `quiesce` on a host with `/goal` + session scope, else the harness-agnostic `gap-loop`.

## Examples

```text
/ooda-loop --scope=this.session                    # recover the goal -> DoD -> drive to done
/ooda-loop --dry-run                               # print the recovered {goal, dod} + driver + predicate
/ooda-loop --driver=quiesce --auto-merge=authorized --auto-merge-reason="nightly convergence, green CI"
/ooda-loop --scope=ticket:VKS-1234 --autonomy-threshold=0.9 --max-iterations=4
```

## Related

- `skills/ooda-loop/SKILL.md` — full skill logic
- `skills/goal-recovery/SKILL.md` — the Observe step · `skills/decompose-abstract-to-measurable/SKILL.md` (Prisma) — the Orient step
- `commands/gap-loop.md` / `commands/quiesce.md` — the Act drivers
