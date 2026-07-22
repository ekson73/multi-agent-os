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
           [--only=observe|orient|decide]  (run OBSERVE..stage and STOP; --only=orient = dod-recovery)
           [--for-goal="<goal>"]           (skip OBSERVE; derive the DoD for THIS explicit goal)
```

**`dod-recovery`** = `/ooda-loop --only=orient` — recover/ingest the goal, derive + emit the measurable
DoD (Prisma value-tree -> `bin/render_dod_as_prompt.py` -> validator-gated `dod-as-prompt`), then STOP.
No DECIDE, no ACT. It is a MODE of `ooda-loop`, not a separate skill.

**ORIENT-b (`system-as-prompt`)** — after the DoD, `ooda-loop` invokes **Hodos**
(`skills/derive-system-from-goal`) to derive the *vehicle*: the smallest recurring system that
conducts to the goal (implementation-intention trigger→action + cadence + signal + revision guard).
Per the law "meta sem sistema é intenção sem ação" (akasha `[C22]`; fire-point = `anti-theater`
Layer-5 **R9**).

⚠️ **GOAL-SHAPE first**: a one-shot/bounded goal exits with `system-as-prompt = N/A` — *a plan IS
its system*. The DECIDE gate therefore validates **all APPLICABLE envelopes**, not a fixed three:
`{goal, dod}` suffices for a bounded goal, so a typo-fix never blocks on a missing third envelope.

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
/ooda-loop --only=orient --for-goal="ship the session-handoff spine"   # dod-recovery: derive+emit the DoD; drive nothing
```

## Related

- `skills/ooda-loop/SKILL.md` — full skill logic
- `skills/ooda-loop/bin/render_dod_as_prompt.py` — the deterministic Orient projection (Prisma spec -> validator-gated dod-as-prompt; the `--only=orient`/dod-recovery renderer)
- `skills/goal-recovery/SKILL.md` — the Observe step · `skills/decompose-abstract-to-measurable/SKILL.md` (Prisma) — the Orient-a step
- `skills/derive-system-from-goal/SKILL.md` (Hodos) — the **Orient-b** step (`system-as-prompt`; N/A for a bounded goal)
- `commands/gap-loop.md` / `commands/quiesce.md` — the Act drivers
