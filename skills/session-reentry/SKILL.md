---
name: session-reentry
version: "0.2.0"
description: |
  Cold/foreign-thread RE-ENTRY orchestrator (soul-name Anamnesis). The RECEIVING
  dual of postflight's SENDING handoff-seed: given a DORMANT or FOREIGN session
  (opened days/weeks later, or by a different mind — another human or agent),
  reconstruct its intent-hierarchy (motivation → purpose → objectives
  originary/primary/secondary/auxiliary → deliverables → state) PURELY from
  persisted artifacts, then re-onboard the mind PROGRESSIVELY ("enter the vibe —
  não cuspir tudo"), text-first (audio/graphic opt-in). Composes existing
  primitives (CPT Compass, postflight, work-compass, morning-briefing recap,
  content-recast, opera-debrief) — reinvents nothing (Strata). M2 (any-mind
  register + id→path + dormancy-scaled depth); M3/M4 tracked by issue #234.
  Triggers: "re-enter this session", "catch me up on this old thread", "reonboard
  me", "what was this session about", "resume dormant session", "re-attune",
  "onboard a new mind to this thread".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
---

# Session-Reentry (soul-name **Anamnesis**)

The **RECEIVING side of a session boundary**. Where `postflight` **emits** a
handoff-seed at end-of-work (the SENDING side), `session-reentry` **reconstructs
and re-onboards** at start-of-re-entry. Anamnesis (Plato ἀνάμνησις — *the
un-forgetting*) is the dual of the amnesia every fresh agent wakes into
(`ai-as-pwd-axiom` §1). Design spec: **ADR-009** (`docs/adrs/`).

> **Naming**: the soul-name **Anamnesis** is operator-overridable per `[C-naming]`
> (naming-authority — Anima decides, operator may rename post-hoc). The canonical
> **system-slug `session-reentry`** is what code/routing/`/maos:` key off and does not
> change on a soul-name override.

> **Increment status** — **M1** (text-only walking-skeleton) + **M2** (id→path
> resolution via `bin/resolve-session.sh` · any-mind register `--mind`→`opera-debrief
> --audience` · dormancy-scaled depth) shipped. **M3** audio · **M4** graphic + rule
> cross-refs remain **deferred to issue #234** (build-spec: ADR-009 §M2–M4 Build-Spec).

## Purpose & the gap it fills

Every session is a fresh amnesic agent. A mind — the original operator, a
*different* human, or *another agent* — routinely opens an OLD/DORMANT thread
after dozens of intervening tasks and must **re-attune**: rebuild the thread's
*motivation → purpose → objectives → deliverables → state*, then re-enter "the
vibe" and continue. That reconstruction is the expensive re-entry cost (Mark 2008:
~23 min to fully resume interrupted work).

A 2-agent prior-art census confirmed the gap: adjacent tools cover the **SENDING**
side (`postflight` / `continuation-seed` emit a seed) or the wrong axis —
`morning-briefing --mode=recap` = self + **live** + sectioned dump · `work-compass` =
the WHAT not the UX · `session-report` = usage-analytics · ASH = decision-audit ·
CPT §9 Compass = a cold-rehydration **mechanism** (no pedagogy). **None does
cold/foreign RECEIVING + any-mind re-onboarding.** Full contrast table: ADR-009 §Context.

**This tool = the RECEIVING side:** reconstruct a cold/dormant/foreign thread's
intent-hierarchy from persisted artifacts, then re-onboard **any mind**
progressively, multi-modally — by **composing** those primitives, not reinventing
them (Strata / Gordian: no new mechanism where one exists; the only net-new are two
thin deterministic helpers — the dormancy score + the id→path resolver).

## When to use / not use

- **Use**: re-entering a dormant/old session; onboarding a *different* mind (human
  or agent) to an existing thread; "what was this about, and what's next?".
- **Not use**: the session is **live** and you just need a state-recap →
  `morning-briefing --mode=recap`; you're **ending** work and want to leave a seed
  → `postflight`; a single-file Q&A → answer directly.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--session <id\|path>` | current | target thread; an **id** resolves via `bin/resolve-session.sh` (M2) |
| `--mind self\|human\|agent` | `self` | audience register → `opera-debrief --audience` (M2) |
| `--depth L1\|L2\|L3\|full` | `L2` | progressive layer; default = the dormancy band; expand-on-demand |
| `--media text\|audio-voice\|graphic` | `text` | delivery modality (audio/graphic opt-in; **M3/M4**) |
| `--scope current\|down\|sideways\|up\|forward` | `current` | CPT Compass verb (§9) |

> **M2 wiring** (this increment) — `--session <id>` resolves to an artifact path via
> `bin/resolve-session.sh` (an existing path passes through; no match → honest
> non-zero, never a fabricated path). `--mind` maps to the RE-ATTUNE register:
> `self`/`human` → `opera-debrief --audience human` (warm; `self` at lower
> `--intensity`), `agent` → `--audience agent` (machine-economy digest). `--depth`
> (defaulting to the dormancy band) gates how many N-Tree layers render (L1→L2→L3→full).
> `--media audio/graphic` remain **M3/M4** — they emit a stderr `[--media]
> audio/graphic deferred to M3/M4 (#234)` + fall back to text (no fabricated modality,
> anti-theater R3).

## Architecture — 3 phases, each COMPOSING primitives

Scaled by the **dormancy score** (`bin/dormancy-score.sh` — a net-new bit):
staler/more-foreign ⇒ deeper reconstruction (grounds Monk-Trafton resumption-lag).

| Phase | Does | COMPOSES (reuse — do not rebuild) |
|---|---|---|
| **1 · INGEST** | resolve `--session` id→path (`bin/resolve-session.sh`); walk persisted surfaces; compute dormancy | CPT Compass walk (akasha `rules/cowork-process-topology-protocol.md` §9: `INDEX.yaml`/`manifest`/`events`) · ASH (`skills/agentic-session-harness`) · `session-report/analyze-sessions.mjs` (transcript parse) · `skills/postflight/references/continuation-seed-contract.md` (seed shape) · `ticket-as-prompt` re-entry-block (akasha) · the **37-type work-surface taxonomy** (akasha `docs/work-surface-taxonomy-2026-07.md`) as the input-surface map |
| **2 · RECONSTRUCT** | build the objectives **N-Tree** (originary/primary/secondary/auxiliary) + deliverables + state | `skills/postflight` **P2 DEBRIEF** (N-Tree synthesis — *the owner*) · `morning-briefing --mode=recap` (state-recap) · `skills/work-compass` (cross-surface aggregation) · `skills/pulse` (re-orientation phasing) |
| **3 · RE-ATTUNE** | layered, any-mind onboarding (`--mind`→`opera-debrief --audience`; `--depth`→layers) | `skills/opera-debrief` (human/agent register + audio passthrough) · `skills/content-recast` (progressive-disclosure lens + faithfulness guard) · producers (M3/M4): `skills/voice-director`+`bin/speak.sh` (audio), content-recast render → NotebookLM/Gamma (graphic), `session-report/template.html` (HTML) |

### Dormancy score + id→path (the net-new bits)

`bin/dormancy-score.sh <session-path>` → a `0.00–1.00` scalar + JSON envelope; the
sibling `bin/resolve-session.sh <id|path>` turns a session **id** into that path (M2 —
closes the M1 "the bin takes a path only" gap; an existing path passes through).
Dormancy inputs: newest-artifact **mtime staleness** + a **foreignness** signal (is
the re-entering mind the author?). Output contract:

```json
{ "score": 0.67, "band": "deep", "age_days": 14, "foreign": false,
  "recommended_depth": "L3", "signals": { "mtime_days": 14, "foreign_author": false } }
```

Bands (scale reconstruction depth): `fresh` <0.25 → L1 · `warm` 0.25–0.55 → L2 ·
`deep` 0.55–0.80 → L3 · `cold` >0.80 → full. Both bins are **deterministic** (same
inputs → same output); no interpretation-dependent output (mirrors the
Convergence-Engine deterministic-harness discipline).

## Output layering (the pedagogy — research-grounded)

**Endsley L1 perception** (artifacts/state) → **L2 comprehension** (the objective
N-Tree = "the vibe") → **L3 projection** (next-actions), nested inside **Nielsen
progressive disclosure** (reveal-on-demand), **chunk-gated ≤~4–7 units** (Miller /
Sweller), **opened by an Ausubel advance-organizer** (the 🌱 *originário* root),
wrapped in the corpus **sign-system** (🌱 originary / 🌳 N-Tree), **closed by exactly
ONE primary recommended next-action (the CTA)**. Default render = the `--depth` /
dormancy band; the mind expands on demand.

### Output contract (single-CTA — disambiguated)

Re-entry renders **one** primary recommended action as the CTA. The Handoff Option
Menu (up/down/sideways/forward Compass verbs) is **secondary and optional** — shown
only on request or at `--depth full`. Never dump every option as co-equal (that is
the "spit everything at once" failure this tool exists to avoid).

## Faithfulness guard (anti-theater R4)

Reconstruct ONLY from persisted artifacts. Where an artifact is missing/silent,
render an honest **"unknown / not persisted"** — never a confident guess (garbage-in
is surfaced, not fabricated). Low artifact-coverage ⇒ shallower, flagged output. Both
bins fail clearly (non-zero) rather than fabricate a path/score.

## Definition of Done

- **M1** ✅ — 3-phase reconstruction from persisted artifacts · progressive layered
  output (L1→L2→L3) · one CTA + optional Compass menu · faithfulness guard · every
  phase composes an existing primitive except the dormancy score · SKILL + bin +
  smoke + merged (PR #235).
- **M2** ✅ — id→path resolution (`bin/resolve-session.sh`) · any-mind register
  (`--mind`→`opera-debrief --audience`) · dormancy-scaled depth · smoke assertions.
- **M3/M4** — deferred to issue #234 (build-spec: ADR-009 §M2–M4 Build-Spec).

## Anti-patterns (do NOT)

1. ❌ **Spit-everything** — dumping the full transcript/all options at once (defeats
   progressive disclosure + the single-CTA contract).
2. ❌ **Fabricate the un-persisted** — inventing motivation/objectives (or a session
   path/score) an artifact doesn't support (anti-theater R4).
3. ❌ **Reinvent a primitive** — re-implementing N-Tree synthesis (postflight P2 owns
   it), state-recap (morning-briefing), or the register/audio (opera-debrief owns
   them) instead of composing them (Strata).
4. ❌ **Claim a modality it can't render** — audio/graphic (M3/M4) degrade with an
   honest stderr note (anti-theater R3), never a faked artifact.
5. ❌ **Interpretation-dependent bins** — dormancy + resolver must be deterministic.

## Quality tests (self-validity)

1. **Self-Application** — re-entry can reconstruct *its own* build session. ✅ (dogfood)
2. **Non-Contradiction** — composes postflight/morning-briefing/work-compass/opera-debrief
   without duplicating; distinct axis (RECEIVING vs SENDING). ✅
3. **Survival** — advocates faithful reconstruction; renders honestly on itself. ✅
4. **Bounded** — id→path + register + depth scope · deterministic bins · Goldilocks
   <12KB · #234 defers M3/M4. ✅
5. **Explicit-Exception** — faithfulness guard + degraded-modality note + `--depth` bounds. ✅
6. **Utility-Sunset** — deprecate if a host ships native cold-thread re-onboarding (DUED). ✅

## Versioning

- v0.2.0 (2026-07-14) — **M2**: `bin/resolve-session.sh` (id→path resolver — closes the
  M1 path-only gap; deterministic, honest-on-no-match) · `--mind` → `opera-debrief
  --audience` register wiring · `--depth` gates N-Tree layers from the dormancy band ·
  smoke assertions for the resolver. M3 (audio) / M4 (graphic + rule cross-refs) stay
  deferred to #234; build-spec = ADR-009 §M2–M4.
- v0.1.0 (2026-07-10) — **M1 walking-skeleton** (PR #235): 3-phase reconstruction +
  `bin/dormancy-score.sh` + smoke; text-only, single-CTA, faithfulness guard.

## Related

- `docs/adrs/ADR-009-session-reentry-anamnesis.md` — the design spec (+ §M2–M4 Build-Spec).
- `skills/postflight` — the SENDING dual (P2 DEBRIEF / P3 HANDOFF seed this RECEIVES).
- `skills/morning-briefing` · `skills/work-compass` · `skills/pulse` · `skills/content-recast`
  · `skills/opera-debrief` · `skills/agentic-session-harness` — composed primitives.
- Build tracker: [ekson73/multi-agent-os#234](https://github.com/ekson73/multi-agent-os/issues/234).

## License

MIT (matches multi-agent-os repo `LICENSE`).
