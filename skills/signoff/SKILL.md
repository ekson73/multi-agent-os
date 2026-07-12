---
name: signoff
description: |
  The operator's END-OF-SESSION SIGN-OFF (encerramento) verb — invoked when you are DONE and
  want the session closed out AND its pending work left discoverable for whoever comes next.
  A thin OODA-framed composition (it reimplements NOTHING): Observe (recon + the complete
  10-item close-out hunt) → Orient (root-cause + anti-theater + Eisenhower) → Decide (Taxis
  disposition per atom) → Act (drive-to-green, sweep, ticket-sync, seed, BROADCAST the
  continuation back-pointer marker, spawn, full git close-out). Composes `quiesce` (drive PR
  green, optional) + `postflight full --broadcast --spawn` (the heavy close-out) — BROADCAST is
  default-ON here (that is the whole point of a sign-off: leave a discoverable trail). Use at the
  end of a session/thread, especially before `/compact` or `/clear`, or when handing off.
version: 0.1.0
triggers:
  - signoff
  - sign off
  - sign off this session
  - encerrar
  - encerrar a sessão
  - close out and leave breadcrumbs
  - wrap up and broadcast the continuation
  - end of thread sign-off
  - i'm done here, close it out
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: worktree-lifecycle
  lifecycle-stage: operate
  cross_link_slug: signoff
  dogfood_status: in-progress
  id: MAOS-SKILL-signoff
  type: skill
  status: active
  owner: maos-community
  wraps: postflight
  naming: "Anima-named (COMP register, descriptive-canonical) — `signoff`; rejected runner-up `disembark`. Operator may override ([C-naming])."
  dogfooding_validation:
    cycles_completed: 0
    cycles_required: 2
    promotion_eligible: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

# Signoff Skill — the sign-off / encerramento verb

## Purpose

`signoff` is the operator's **"I'm done — close this out properly and leave a trail"** gesture.
Where `postflight` is the close-out *machinery*, `signoff` is the operator-facing verb that runs it
with the continuation **BROADCAST default-ON** — so the pending work is left **discoverable** for
whatever mind arrives next (a fresh amnesic agent, another agent, or the operator days later).

It **composes, it does not reimplement** (Strata / Gordian — no new machinery). Everything is delegated:

```
signoff [--converge] [--broadcast=<conservative|all> | --no-broadcast] [--no-spawn] [--dry-run]
  ├─ (optional, --converge) → `quiesce`   # drive the open PR toward green first
  └─ `postflight` full --broadcast[=<scope>] [--spawn|--no-spawn] [--dry-run]
        P1 SWEEP → P2 DEBRIEF (+ the complete 10-item hunt) → P2.5 TICKET-SYNC
        → P3 HANDOFF (seed) → P3.5 SPAWN (default-ON) → P3.6 BROADCAST (default-ON HERE)
```

## What differs from bare `postflight` (its entire net behavior)

| Aspect | `postflight` | `signoff` |
|---|---|---|
| BROADCAST | opt-in (`--broadcast`) | **default-ON** (`conservative`) — the point of a sign-off |
| framing | phases | explicit **OODA** (Observe = recon + 10-item hunt · Orient = root-cause + anti-theater · Decide = Taxis · Act = execute + broadcast + git) — table in `commands/signoff.md` |
| `--converge` | — | optionally drive the PR green via `quiesce` first |

Everything else — the sweep, debrief, hunt, ticket-sync, seed, spawn, and every guardrail — is
`postflight`'s (and `quiesce`'s). `signoff` owns only the broadcast-default-ON policy + the OODA
framing; it holds no machinery of its own.

## When to Use

At the **end of a session/thread**, especially before `/compact` or `/clear`, or when handing off —
whenever you want the close-out **and** a discoverable continuation trail (the default).

## Guardrails (all inherited — `signoff` adds none of its own)

Safe-or-DEFER close-out (P1: dirty tree / conflict / held `index.lock` / untracked-you-didn't-create
→ DEFER), structured-back-pointer-not-TODO broadcast (P3.6 / ADR-010: byte-idempotent · fail-closed ·
metadata-only · decision-records refused · `MAOS_BROADCAST=0` kill-switch · NOOP when nothing
pending), high-blast spawn (P3.5: `POSTFLIGHT_SPAWN=0` · depth-cap · `--no-spawn`), and full git
under `pr-review-protocol` + `auto-merge-standing-authorization` (HITL only for genuine
HUMAN_DOMAIN residue). Full flag/example reference: `commands/signoff.md`.

## Anti-patterns (do NOT)

1. ❌ **Reimplement** sweep/debrief/seed/broadcast inside `signoff` — it COMPOSES `quiesce` + `postflight`.
2. ❌ **Sign off over an un-swept state**, OR **force a spawn/broadcast the operator opted out of** —
   the P3 DoR gates the seed/marker (so they never misreport reality); honor `--no-spawn` /
   `--no-broadcast` / the kill-switches.

## Related Multi-Agent OS Artifacts

- `skills/postflight/SKILL.md` — the close-out machinery `signoff` wraps (P1–P3.6).
- `skills/postflight/references/{continuation-broadcast-protocol.md,close-out-hunt-checklist.md}`
  + `bin/continuation-broadcast.sh` + `docs/adrs/ADR-010-continuation-broadcast.md` — the P3.6 marker.
- `skills/quiesce/SKILL.md` — the drive-to-green `signoff --converge` composes.
- `commands/signoff.md` — the `/maos:signoff` entry point (full flags + examples + the OODA table).
- `skills/preflight/SKILL.md` — start-of-session counterpart; loop `preflight → work → signoff → (spawn) → preflight …`.

## License

MIT (matches the multi-agent-os repo `LICENSE`).
