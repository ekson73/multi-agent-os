---
name: session-reentry
version: "0.1.0"
description: |
  Cold/foreign-thread RE-ENTRY orchestrator (soul-name Anamnesis). The RECEIVING
  dual of postflight's SENDING handoff-seed: given a DORMANT or FOREIGN session
  (opened days/weeks later, or by a different mind — another human or agent),
  reconstruct its intent-hierarchy (motivation → purpose → objectives
  originary/primary/secondary/auxiliary → deliverables → state) PURELY from
  persisted artifacts, then re-onboard the mind PROGRESSIVELY ("enter the vibe —
  não cuspir tudo"), text-first (audio/graphic opt-in). Composes existing
  primitives (CPT Compass, postflight, work-compass, morning-briefing recap,
  content-recast, opera-debrief) — reinvents nothing (Strata). M1 walking-skeleton;
  M2-M4 tracked by issue #234. Triggers: "re-enter this session", "catch me up on
  this old thread", "reonboard me", "what was this session about", "resume dormant
  session", "re-attune", "onboard a new mind to this thread".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
---

# Session-Reentry (soul-name **Anamnesis**)

The **RECEIVING side of a session boundary**. Where `postflight` **emits** a
handoff-seed at end-of-work (the SENDING side), `session-reentry` **reconstructs
and re-onboards** at start-of-re-entry. Anamnesis (Plato ἀνάμνησις — *the
un-forgetting*) is the dual of the amnesia every fresh agent wakes into
(`ai-as-pwd-axiom` §1). Design spec: **ADR-009** (`docs/adrs/`).

> **M1 walking-skeleton** — text-only, composes existing primitives, defines the
> one net-new bit (dormancy score). M2 any-mind register · M3 audio · M4 graphic +
> rule cross-refs are **deferred to issue #234**. This file is that M1 increment.

## Purpose & the gap it fills

Every session is a fresh amnesic agent. A mind — the original operator, a
*different* human, or *another agent* — routinely opens an OLD/DORMANT thread
after dozens of intervening tasks and must **re-attune**: rebuild the thread's
*motivation → purpose → objectives → deliverables → state*, then re-enter "the
vibe" and continue. That reconstruction is the expensive re-entry cost (Mark 2008:
~23 min to fully resume interrupted work).

A 2-agent prior-art census confirmed the gap. Adjacent tools cover the **SENDING**
side or the wrong axis — none does cold/foreign RECEIVING + any-mind re-onboarding:

| Adjacent tool | Covers | Why it is NOT this |
|---|---|---|
| `morning-briefing --mode=recap` | sectioned state-recap | self-audience · **live** thread · sectioned dump |
| `work-compass` | cross-surface N-Tree | the WHAT, not the re-onboarding UX |
| `postflight` P2/P3 · `continuation-seed-contract` | synthesize N-Tree + emit seed | **SENDING** (emits; does not reconstruct/receive) |
| `session-report` plugin | cold transcripts → HTML | **usage/cost analytics** lens |
| `agentic-session-harness` (ASH) | cold journals → what/why | **decision-audit** lens (ingest, no pedagogy) |
| CPT §9 Compass walk | cold artifact re-hydration | a **mechanism**, no pedagogy/multi-modal |

**This tool = the RECEIVING side:** reconstruct a cold/dormant/foreign thread's
intent-hierarchy from persisted artifacts, then re-onboard **any mind**
progressively, multi-modally — by **composing** those primitives, not reinventing
them (Strata / Gordian: no new mechanism where one exists; the only net-new is a
thin dormancy score).

## When to use / not use

- **Use**: re-entering a dormant/old session; onboarding a *different* mind (human
  or agent) to an existing thread; "what was this about, and what's next?".
- **Not use**: the session is **live** and you just need a state-recap →
  `morning-briefing --mode=recap`; you're **ending** work and want to leave a seed
  → `postflight`; a single-file Q&A → answer directly.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--session <id\|path>` | current | target thread (transcript id or artifact path) |
| `--mind self\|human\|agent` | `self` | audience register (see `opera-debrief`) |
| `--depth L1\|L2\|L3\|full` | `L2` | progressive layer; expand-on-demand |
| `--media text\|audio-voice\|graphic` | `text` | delivery modality (audio/graphic opt-in; **M3/M4**) |
| `--scope current\|down\|sideways\|up\|forward` | `current` | CPT Compass verb (§9) |

> **M1 honesty**: `--mind` register-shaping is thin in M1 (M2); `--media` audio/graphic
> are **M3/M4** — in M1 they emit a stderr `[--media] audio/graphic deferred to M3/M4 (#234)`
> and fall back to text. No fabricated modality (anti-theater R3).

## Architecture — 3 phases, each COMPOSING primitives

Scaled by the **dormancy score** (`bin/dormancy-score.sh` — the one net-new bit):
staler/more-foreign ⇒ deeper reconstruction (grounds Monk-Trafton resumption-lag).

| Phase | Does | COMPOSES (reuse — do not rebuild) |
|---|---|---|
| **1 · INGEST** | walk the thread's persisted surfaces; compute dormancy | CPT Compass walk (akasha `rules/cowork-process-topology-protocol.md` §9: `INDEX.yaml`/`manifest`/`events`) · ASH (`skills/agentic-session-harness`) · `session-report/analyze-sessions.mjs` (transcript parse) · `skills/postflight/references/continuation-seed-contract.md` (seed shape) · `ticket-as-prompt` re-entry-block (akasha) · the **37-type work-surface taxonomy** (akasha `docs/work-surface-taxonomy-2026-07.md`) as the input-surface map |
| **2 · RECONSTRUCT** | build the objectives **N-Tree** (originary/primary/secondary/auxiliary) + deliverables + state | `skills/postflight` **P2 DEBRIEF** (N-Tree synthesis — *the owner*) · `morning-briefing --mode=recap` (state-recap) · `skills/work-compass` (cross-surface aggregation) · `skills/pulse` (re-orientation phasing) |
| **3 · RE-ATTUNE** | layered, any-mind onboarding | `skills/content-recast` (progressive-disclosure lens + faithfulness guard + `--to-audience`/`--abstraction`) · `skills/opera-debrief` (human/agent register) · producers (M3/M4): `skills/voice-director`+`bin/speak.sh` (audio), content-recast render → NotebookLM/Gamma (graphic), `session-report/template.html` (HTML) |

### Dormancy score (the net-new bit — M1 defines it)

`bin/dormancy-score.sh <session-path-or-id>` → a `0.00–1.00` scalar + JSON envelope.
Inputs: newest-artifact **mtime staleness** (age since last touch) + a **foreignness**
signal (is the re-entering mind the author?). Output contract:

```json
{ "score": 0.67, "band": "deep", "age_days": 14, "foreign": false,
  "recommended_depth": "L3", "signals": { "mtime_days": 14, "foreign_author": false } }
```

Bands (scale reconstruction depth): `fresh` <0.25 → L1 · `warm` 0.25–0.55 → L2 ·
`deep` 0.55–0.80 → L3 · `cold` >0.80 → full. Deterministic (same inputs → same
score); no interpretation-dependent output (mirrors the Convergence-Engine
deterministic-harness discipline).

## Output layering (the pedagogy — research-grounded)

**Endsley L1 perception** (what artifacts/state exist) → **L2 comprehension** (the
objective N-Tree = "the vibe") → **L3 projection** (next-actions), nested inside
**Nielsen progressive disclosure** (reveal-on-demand), **chunk-gated ≤~4–7 units**
(Miller 7±2 / Sweller CLT), **opened by an Ausubel narrative advance-organizer**
(the 🌱 *originário* root as the bridge), **priming the Altmann-Trafton decayed
goal**, wrapped in the corpus **sign-system** (🌱 originary / 🌳 N-Tree), **closed by
exactly ONE primary recommended next-action (the CTA)**. Default render = the
dormancy-band's depth (L1/L2/L3/full); operator expands on demand.

### Output contract (single-CTA — disambiguated)

Re-entry renders **one** primary recommended action as the CTA. The Handoff Option
Menu (up/down/sideways/forward Compass verbs) is **secondary and optional** — shown
only on request or at `--depth full`. Never dump every option as co-equal (that is
the "spit everything at once" failure this tool exists to avoid).

## Faithfulness guard (anti-theater R4)

Reconstruct ONLY from persisted artifacts. Where an artifact is missing/silent,
render an honest **"unknown / not persisted"** — never a confident guess (garbage-in
is surfaced, not fabricated). Low artifact-coverage ⇒ shallower, flagged output.

## Definition of Done (M1)

- [ ] Reconstructs a **real dormant** session's intent-hierarchy purely from
  persisted artifacts (dogfood on 1 session).
- [ ] Progressive layered output (L1→L2→L3, expand-on-demand); **one CTA** + optional
  secondary Compass menu.
- [ ] Faithfulness guard (no fabrication).
- [ ] Every phase composes an existing primitive **except** the thin dormancy score.
- [ ] `SKILL.md` + `bin/dormancy-score.sh` + smoke test + PR→converge→merge.

## Anti-patterns (do NOT)

1. ❌ **Spit-everything** — dumping the full transcript/all options at once (defeats
   progressive disclosure + the single-CTA contract).
2. ❌ **Fabricate the un-persisted** — inventing motivation/objectives an artifact
   doesn't support (anti-theater R4).
3. ❌ **Reinvent a primitive** — re-implementing N-Tree synthesis (postflight P2 owns
   it) or state-recap (morning-briefing) instead of composing them (Strata).
4. ❌ **Claim a modality it can't render** — M1 is text-only; audio/graphic degrade with
   an honest stderr note (anti-theater R3), never a faked artifact.
5. ❌ **Interpretation-dependent dormancy** — the score must be deterministic (same
   inputs → same score).

## Quality tests (self-validity)

1. **Self-Application** — re-entry can reconstruct *its own* build session. ✅ (dogfood)
2. **Non-Contradiction** — composes postflight/morning-briefing/work-compass without
   duplicating; distinct axis (RECEIVING vs SENDING). ✅
3. **Survival** — advocates faithful reconstruction; renders honestly on itself. ✅
4. **Bounded** — M1 text-only scope · dormancy cap 0–1 · Goldilocks <12KB · #234 defers M2-M4. ✅
5. **Explicit-Exception** — faithfulness guard + degraded-modality note + `--depth` bounds. ✅
6. **Utility-Sunset** — deprecate if a host ships native cold-thread re-onboarding (DUED). ✅

## Versioning

- v0.1.0 (2026-07-10) — **M1 walking-skeleton**: SKILL.md (3-phase INGEST→RECONSTRUCT→
  RE-ATTUNE composing existing primitives) + `bin/dormancy-score.sh` (the net-new bit:
  mtime-staleness × foreignness → depth-scaling scalar + JSON contract) + smoke test.
  Text-only; single-CTA output contract; faithfulness guard. M2 (any-mind register),
  M3 (audio), M4 (graphic + rule cross-refs) deferred to issue #234. Transcribes ADR-009.

## Related

- `docs/adrs/ADR-009-session-reentry-anamnesis.md` — the design spec.
- `skills/postflight` — the SENDING dual (P2 DEBRIEF / P3 HANDOFF seed this RECEIVES).
- `skills/morning-briefing` · `skills/work-compass` · `skills/pulse` · `skills/content-recast`
  · `skills/opera-debrief` · `skills/agentic-session-harness` — composed primitives.
- Build tracker: [ekson73/multi-agent-os#234](https://github.com/ekson73/multi-agent-os/issues/234).

## License

MIT (matches multi-agent-os repo `LICENSE`).
