---
name: signoff
description: Sign off / encerrar a sessão — close it out cleanly AND leave the pending work discoverable for the next mind (OODA-framed close-out that composes quiesce + postflight with the continuation BROADCAST default-ON)
---

# /signoff Command

**Sign off** the session (encerramento): run the full end-of-session close-out **and** broadcast a
discoverable continuation trail for whoever comes next. A thin OODA-framed wrapper that composes
`quiesce` (drive-to-green, optional) + the [`postflight` skill](../skills/postflight/SKILL.md)
with **BROADCAST default-ON** — because the point of signing off is to close cleanly *and* leave
the pending work findable. Thin entry point over the [`signoff` skill](../skills/signoff/SKILL.md).

> Surfaces at runtime as `/maos:signoff` (Sandwich Namespacing per `.claude-plugin/plugin.json`).
> Naming: Anima-named (`signoff`; rejected runner-up `disembark`). Operator may override (`[C-naming]`).

## Usage

```
/signoff [--converge] [--broadcast=<conservative|all> | --no-broadcast] [--spawn | --no-spawn] [--dry-run]
```

## What it does (OODA — recon → hunt → disposition → act)

| Stage | Action | Delegates to |
|-------|--------|--------------|
| **Observe** | environment recon + the **complete 10-item close-out hunt** (fails · errors · warnings · risks+mitigations · gaps · pendings · decisions-not-taken · unasked-Qs · unanswered-Qs) | Skopos recon · `postflight` P2 DEBRIEF + `close-out-hunt-checklist.md` |
| **Orient** | root-cause (not symptom) + anti-theater filter + Eisenhower rank | `root-cause-first` · `anti-theater` · `postflight` P2 |
| **Decide** | Taxis disposition per atom — fix-now / ticket / seed / drop (no silent drop); is a pendency left? | `postflight` P2.5 · Taxis |
| **Act** | drive-to-green → sweep → ticket-sync → seed → spawn → **broadcast the marker** → full git | `quiesce` + `postflight full --broadcast --spawn` |

## Flags

| Flag | Effect |
|------|--------|
| `--converge` | First drive the open PR toward green via `quiesce`, then close out. |
| `--broadcast=<scope>` | Marker reach: `conservative` (default) = commit-trailer + PR-body; `all` = ALSO caller-named docs/changelogs (ADRs refused). |
| `--no-broadcast` | Sign off WITHOUT leaving a marker (rare; broadcast is a NOOP anyway when nothing is pending). |
| `--spawn` / `--no-spawn` | Launch (default) / skip the pre-seeded continuation session. |
| `--dry-run` | Preview the whole close-out (sweep plan, seed, marker, spawn command) — writes/launches nothing. |

> **BROADCAST is default-ON here** (that is the whole point of a sign-off) — unlike bare
> `/postflight` where it is opt-in. It is a **structured back-pointer, never a free-form TODO**
> (reconciled with exit-hygiene by `docs/adrs/ADR-010-continuation-broadcast.md`): idempotent,
> metadata-only, ADRs refused, and a NOOP when nothing is pending. Kill-switch: `MAOS_BROADCAST=0`.

## Behavior (safe-or-DEFER — all inherited)

- **Never clobbers**: dirty tree / conflict / held `.git/index.lock` / untracked-you-did-not-create → **DEFER**.
- **Handoff + marker are gated**: emitted only after the sweep + debrief, so they never misreport the state.
- **Governance-aware**: reads `CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories` and adapts; full git under `pr-review-protocol` + `auto-merge-standing-authorization` (HITL only for genuine residue).

## Examples

```
/signoff                       # close out + broadcast (conservative) + spawn — run before /compact
/signoff --converge            # drive PR green first, then close out + broadcast + spawn
/signoff --broadcast=all       # ALSO stamp caller-named docs/changelogs (ADRs still refused)
/signoff --no-spawn            # close out + broadcast, but don't open a new session
/signoff --dry-run             # preview the entire close-out (nothing written/launched)
```

## Output

```
✍️  signoff (OODA)
─────────────────────────────────────────────────
OBSERVE  debrief + 10-item hunt → 1 gap · 1 risk · 0 fails
ORIENT   root-caused · anti-theater PASS · Eisenhower Q2/Q2
DECIDE   gap → continuation ticket · risk → seed.risks[] · nothing else pending
ACT      swept (pushed feat/x · PR #42 green) · seed + spawn · 🔁 BROADCAST → PR #42 body + commit trailer
─────────────────────────────────────────────────
✅ Signed off. Continuation VKS-456 discoverable in PR #42 + the exit commit. Next: /maos:preflight.
```

## Integration

- Skill: [`skills/signoff/SKILL.md`](../skills/signoff/SKILL.md) (the OODA composition contract).
- Composes: [`skills/postflight/SKILL.md`](../skills/postflight/SKILL.md) (P1–P3.6, `--broadcast` default-ON) + `skills/quiesce/SKILL.md` (`--converge`).
- Broadcast: `bin/continuation-broadcast.sh` + `skills/postflight/references/continuation-broadcast-protocol.md` + `docs/adrs/ADR-010-continuation-broadcast.md`.
- Counterpart: `/preflight` (start-of-session) — the loop: `preflight → work → signoff → (spawn) → preflight …`.
