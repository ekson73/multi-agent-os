---
name: gap-loop
description: Drive a goal — as a GAP-REGISTER — to convergence via a harness-agnostic, self-scored 5-phase loop (DoR -> RECAP -> RESOLVE MoE-per-gap -> VALIDATE independent-audit -> PERSIST), looping until [every gap dispositioned AND agentic convergence AND autonomy_score >= 0.85]. No /goal dependency. Override-friendly.
---

# /gap-loop Command

Thin wrapper that invokes `skills/gap-loop/SKILL.md`. The skill holds all logic
(the CONVERGED termination predicate, the 5 phases, the anti-gaming derived SCORE rule,
the low-score -> rotate-roster re-loop, the HITL-as-problem SOFT/HARD classification, the
harness-agnostic declarative driver, the composition wiring, the override flags, and the
STOP-marker grammar). This file is the command surface only.

The reusable methodology behind it lives in `protocols/gap-loop-protocol.md`.

## Usage

```text
/gap-loop "<goal / instructions>"
          [--state-source=pulse|ticket:<id>|file|free-text]   (default pulse)
          [--condition='<override predicate>']
          [--autonomy-threshold=0.85]
          [--max-iterations=6]
          [--socratic-depth=N]          (from SSOT; never hardcode "33")
          [--auto-merge=hold|authorized|off]   (default hold — EKO-66 STAGE-only)
          [--driver=self|auto-pilot]
```

Sibling routing: use `/quiesce` when the host HAS `/goal` and you want session-PR
quiescence; use `/auto-pilot` for plain decompose+delegate of ONE goal; use `gap-loop`
when you want a self-driven, self-scored, gap-register convergence loop in ANY harness
(including one with no `/goal`).

## Examples

```text
/gap-loop "harden the auth gaps before we ship"
/gap-loop --state-source=ticket:VKS-1234 --max-iterations=4
/gap-loop --autonomy-threshold=0.9 --socratic-depth=12
/gap-loop --auto-merge=authorized   # only when the operator authorizes the merge
```

## Related

- `skills/gap-loop/SKILL.md` — full skill logic
- `protocols/gap-loop-protocol.md` — the reusable methodology
- `commands/quiesce.md` — the `/goal`-dependent session-quiescence sibling
