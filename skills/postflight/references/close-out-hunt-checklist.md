---
name: close-out-hunt-checklist
description: The complete 10-item end-of-session HUNT taxonomy (fails · errors · warnings · risks · mitigations · gaps · pendings · decisions-not-taken · unasked-Qs · unanswered-Qs) + a disposition rubric (fix-now / ticket / seed-field / drop) — the SSOT postflight P2 DEBRIEF surveys
version: 1.0.0
---

# Close-Out Hunt Checklist (SSOT) — postflight P2 DEBRIEF

> **Version**: 1.0.0 (2026-07-10)
> **Scope**: AAIF cross-vendor. The single source of truth for **what postflight P2 DEBRIEF
> hunts for** at the session boundary — the complete 10-category survey — and **where each
> found atom is dispositioned** (fix-now · ticket · seed-field · drop-with-note).
> **Position**: consumed by `skills/postflight/SKILL.md` **P2 DEBRIEF**; its outputs feed
> **P2.5 TICKET-SYNC** (the ticketable atoms), **P3 HANDOFF** (the seed fields), and — when
> `--broadcast` is on — **P3.6 BROADCAST** (the discovery markers).
> **Cross-link slug**: `close-out-hunt-checklist`

## Purpose

An amnesic agent that debriefs an incomplete list leaves the rest **invisible** — and *"what
is not seen is not remembered"* (the locus master principle). The operator's close-out ask is
explicit: at exit, **hunt for `[fails · errors · warnings · risks · mitigations · gaps ·
pendings · decisions-not-taken · important-unasked-questions · unanswered-questions]`** so the
handoff is honest and complete. This checklist makes that survey **first-class + total** — no
category is implicit — and binds every found atom to a **disposition**, so nothing is either
silently dropped (Taxis no-silent-drop) or theatrically filed (anti-theater).

Historically postflight P2 surfaced **5 of the 10** first-class (`gaps · pendings · undecided
· unasked-Qs · unanswered-Qs`); the diagnostic + forward-looking half (`fails · errors ·
warnings · risks · mitigations`) was implicit. This SSOT completes the taxonomy.

## The 10-category hunt (survey → disposition)

For each category: **survey** the session's real state (verified, not asserted — Mente Tomé),
then **dispose** per the rubric. Every atom passes the **anti-theater filter first**
(real ∧ actionable ∧ changes-someone's-next-move? — else drop-with-one-line-note, never file).

| # | Category | Survey question (what to look for) | Default disposition | Lands in |
|---|---|---|---|---|
| 1 | **fails** | Did anything the session ran **fail**? (CI/build/test red, a job that exited non-zero, an unmet acceptance criterion) | **fix-now** if in-scope + cheap (exit-hygiene "fix NOW"); else **ticket** (P2.5, Eisenhower) + record | seed `inherited_state.verified_facts` / `gaps`; P2.5 ticket |
| 2 | **errors** | Any **error** encountered (runtime exception, tool error, a command that errored and was worked-around)? | **fix-now** the root (root-cause-first) if in-scope; else **ticket** + record the workaround | seed `gaps`; P2.5 ticket |
| 3 | **warnings** | Any **warning** raised (deprecation, lint, a non-fatal advisory, a "works but…") that a next agent should know? | **note** if it changes the next agent's behavior; else **drop-with-note** | seed `gaps` (or dropped-note) |
| 4 | **risks** | What could **go wrong for the next agent / downstream** (fragile assumption, untested path, irreversible-adjacent step, a "for now" shortcut)? | **carry forward** (always — a risk unseen is a risk realized); Q1/Q2 risk also → **ticket** | seed `risks[]` (`{risk, mitigation, severity}`); P2.5 ticket if high |
| 5 | **mitigations** | For each risk, **how is it mitigated / how should the next agent mitigate it**? | **pair with its risk** (a risk without a mitigation is half-surveyed) | seed `risks[].mitigation` |
| 6 | **gaps** | What is **missing** from "done" (a deliverable not produced, coverage not added, a spec not met)? | **ticket** per P2.5 Eisenhower; carry forward | seed `gaps[]`; P2.5 ticket |
| 7 | **pendings** | What is **started-but-not-finished** / awaiting an external event (a PR mid-PDCA, a running job, a review pending)? | **continuation** (anchors the next session) + carry forward | seed `pendings[]`; P2.5 **continuation ticket** |
| 8 | **decisions-not-taken** | What **open decision / undecided fork** did the session leave (an A/B/C not chosen, a design left ambiguous)? | **carry forward**; if it BLOCKS the next step → surface to operator (AskUserQuestion) or ticket | seed `undecided[]` |
| 9 | **unasked-questions** | What **important question should have been asked** but wasn't (a should-have-clarified, a blind-spot)? | **carry forward** (the next agent asks it) | seed `unasked_questions[]` |
| 10 | **unanswered-questions** | What operator/HITL question is **still pending an answer** (asked, not yet answered)? | **carry forward** + surface in the exit briefing | seed `unasked_questions[]` (or its own note); exit briefing |

## Disposition rubric (the four exits — one per atom, never "silent nothing")

Per Taxis (`loose-end-triage-queue` — no silent drop) + exit-hygiene (Axiom 4 proactive-resolution
+ the Delegation gate "registered with traceability"), every surveyed atom exits via **exactly
one** of:

1. **fix-now** — resolve it this session (exit-hygiene "fix NOW, there is no later"). Preferred
   for in-scope, cheap, reversible fails/errors (P1 SWEEP).
2. **ticket** — file a bounded, Eisenhower-triaged ticket via **P2.5 TICKET-SYNC** (≤3 + 1 batch
   cap). The tracker becomes the durable memory (mechanize-don't-memorize).
3. **seed-field** — carry it into the **P3 HANDOFF** continuation seed (the field named in the
   table's "Lands in" column) so the next amnesic agent inherits it. Risks/gaps/pendings/
   undecided/questions are seed-carried **by default** (they change the next agent's behavior).
4. **drop-with-note** — decide NOT to carry it, logging a one-line audit note (what + why). An
   honest, logged non-carry — the ONLY legitimate "nothing" (never omission).

**No fifth exit.** An atom that is neither fixed, ticketed, seeded, nor explicitly-dropped is a
**silently-dropped loose end** — the exact anti-pattern this checklist (and Taxis) forbids.

## Anti-patterns (do NOT)

1. ❌ **Partial hunt** — surveying only the 5 easy categories and leaving fails/errors/warnings/
   risks/mitigations implicit (the incompleteness this SSOT exists to fix).
2. ❌ **Hunt-theater** — filing a ticket / seeding an atom that is vanity/already-done/non-actionable
   (fails the anti-theater filter). An atom must change someone's next move.
3. ❌ **Silent drop** — letting a surveyed atom exit via none of the four dispositions (Taxis).
4. ❌ **Risk without mitigation** — carrying a `risk` with no paired mitigation (half-surveyed;
   the next agent inherits the fear without the remedy).
5. ❌ **Assert-not-verify** — reporting a fail/error from memory instead of the real session
   state (a stale/guessed status is worse than none — Mente Tomé + anti-theater R3).

## Related artifacts

- `skills/postflight/SKILL.md` — **P2 DEBRIEF** runs this hunt; **P2.5** tickets the ticketable
  atoms; **P3** seeds the carried atoms; **P3.6** (opt-in) broadcasts the discovery marker.
- `skills/postflight/references/continuation-seed-contract.md` — the seed fields the carried
  atoms land in (`gaps` · `pendings` · `undecided` · `unasked_questions` · **`risks`** (added
  in contract v1.2.0 for categories 4+5) · `inherited_state`).
- `skills/postflight/references/ticket-sync-protocol.md` — **P2.5** files the ticketable atoms
  (bounded ≤3 + 1 batch).
- `protocols/exit-hygiene.md` — the fix-now vs register-with-traceability gate this rubric applies.

## License

MIT (matches the multi-agent-os repo `LICENSE`).
