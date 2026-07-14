# ADR-009 — `session-reentry` (Anamnesis): cold/foreign-thread re-entry orchestrator

- **Status:** Accepted (build IN PROGRESS — **M1 + M2 shipped**; M3/M4 spec'd in §M2–M4 Build-Spec + tracked by [#234](https://github.com/ekson73/multi-agent-os/issues/234)). This ADR is the design spec; the §M2–M4 Build-Spec turns the roadmap into build-level composition contracts.
- **Date:** 2026-07-10
- **Deciders:** operator (Emilson) + Claude (Opus 4.8)
- **Origin:** operator `/enhance /deep-research Ultrathink` 2026-07-09; SHAPE + SCOPE decided via AskUserQuestion 2026-07-10.
- **Naming:** Anima `--n=5` slate → system-slug `session-reentry` · soul-name **Anamnesis** (Plato ἀνάμνησις, *recollection / the un-forgetting* — the dual of amnesia). Operator may override (`[C-naming]`).

## Context

Every session is a fresh **amnesic** agent, and the operator (or a *different* mind — another human, or another agent) routinely **opens an OLD/DORMANT claude-session days/weeks later, after dozens of intervening tasks, and must re-attune**: reconstruct the thread's *motivation → purpose → objectives (originary/primary/secondary/auxiliary) → deliverables → state* — then re-enter "the vibe" and continue. This is the recurring, expensive **re-entry cost** (Mark 2008: ~23 min to fully resume interrupted work; developer context reconstruction 30–45 min).

A 2-agent prior-art census confirmed a real gap. Existing tools cover the **SENDING side of a session boundary** or the wrong axis:

| Tool | What it does | Why it is NOT this |
|---|---|---|
| `morning-briefing --mode=recap` | sectioned state-recap for context restoration | self-audience · **live** thread · sectioned dump (not foreign/dormant reconstruction) |
| `work-compass` | aggregates surfaces into one N-Tree | the WHAT, not the re-onboarding UX |
| `postflight` P2/P3 / `continuation-seed-contract` / `end-of-action-briefing §7.2` | synthesize the objectives-N-Tree + emit a handoff seed at end-of-work | **SENDING** side — it emits, does not reconstruct/receive |
| `docs/auto-catchup-protocol.md` | emit a status report before compaction (≥80%) | **SENDING** side (emission), not RECEIVING/re-onboarding |
| `session-report` plugin | cold transcripts → HTML | **usage/cost analytics** lens |
| `agentic-session-harness` (ASH) | cold journals → what/why | **decision-audit** lens (an ingest primitive, no pedagogy) |
| CPT §9 Compass walk | cold artifact-driven re-hydration | a **mechanism**, self/agent, no pedagogy/multi-modal |
| concierge family | onboard a **platform/framework** | wrong subject (not a specific dormant thread) |

**The gap = the RECEIVING side:** reconstruct a **cold/dormant/foreign** thread's intent-hierarchy **purely from persisted artifacts**, then **re-onboard any mind** into it **progressively** ("não cuspir tudo — enter the vibe"), **multi-modally** (text default; audio/graphic opt-in). No built tool does this, and no *pre-existing* ticket tracked it — this ADR's build is now tracked by issue [#234](https://github.com/ekson73/multi-agent-os/issues/234).

## Decision

Build **one** maos community skill, `session-reentry` (soul-name **Anamnesis**), the **RECEIVING dual** of postflight's SENDING seed and the *pedagogical elevation* of the CPT §9 cold-rehydration walk. It **COMPOSES existing primitives** — it does NOT reinvent them (reuse-and-elevate / Strata; Gordian: no new mechanism where a native primitive exists). The **only net-new computation** is a thin **dormancy score** (§ Architecture; deferred to M1).

Rejected alternatives: **(a)** `morning-briefing --mode=reentry` extension — morning-briefing is fundamentally live/self; cold/foreign/any-mind is a different input model + audience → would bloat it. **(b)** a small family (re-entry + separate any-mind recaster) — `opera-debrief` + `content-recast` already do register-recast/any-mind delivery → duplication.

### Architecture — 3 phases, each composing primitives (scaled by a **dormancy metric** — the one thin net-new bit, deferred to M1)

| Phase | Does | COMPOSES (reuse — path) |
|---|---|---|
| **1 · INGEST** (cold artifacts) | walk the thread's persisted surfaces; compute **dormancy** | CPT Compass walk (`cowork-process-topology-protocol.md` §9: `INDEX.yaml`/`manifest`/`events` — *operator akasha-claude rules, cross-repo*) · ASH (`skills/agentic-session-harness`) · `session-report/analyze-sessions.mjs` (transcript parse) · `skills/postflight/references/continuation-seed-contract.md` (seed shape) · `ticket-as-prompt` `re-entry-block` · the **37-type work-surface taxonomy** (see References — cross-repo) as the input-surface map |
| **2 · RECONSTRUCT** (intent-hierarchy) | build the objectives **N-Tree** (originary/primary/secondary/auxiliary) + deliverables + state | `skills/postflight` **P2 DEBRIEF** (objectives-N-Tree synthesis — *the owner*) · `morning-briefing --mode=recap` (sectioned state-recap / context-restoration) · `skills/work-compass` (cross-surface aggregation) · `skills/pulse` (re-orientation phasing) |
| **3 · RE-ATTUNE** (deliver) | layered, any-mind, multi-modal onboarding | `skills/content-recast` (progressive-disclosure lens + faithfulness guard + `--to-audience`/`--abstraction`) · `skills/opera-debrief` (human/agent register) · producers: `skills/voice-director` + `bin/speak.sh` (audio), content-recast render → NotebookLM/Gamma (graphic), `session-report/template.html` (HTML) |

> **Dormancy metric (the net-new bit — traceability note):** neither `work-compass` (staleness threshold + flagged-candidate output) nor `agentic-session-harness` (audit journal) defines a dormancy *score* or its output contract. So dormancy is a **thin net-new computation** — artifact-mtime staleness + the work-compass staleness signal → a scalar that scales reconstruction depth (grounds Monk-Trafton resumption-lag). Its definition + output contract are **deferred to build M1**; the "composes existing primitives" claim holds for everything *except* this one score.

### Output layering (the pedagogy — research-grounded)

**Endsley L1 perception** (what artifacts/state exist) → **L2 comprehension** (the objective N-Tree = "the vibe") → **L3 projection** (next-actions), nested inside **Nielsen progressive disclosure** (reveal-on-demand), **chunk-gated ≤~4–7 units** (Miller 7±2 / Sweller cognitive-load), **opened by an Ausubel narrative advance-organizer** (the 🌱 *originário* root as the bridge), **priming the Altmann-Trafton decayed goal**, wrapped in the corpus **sign-system** (glyphs 🌱/🌳), **closed by exactly ONE primary recommended next-action (the CTA)** — optionally followed by *secondary* Compass-verb options (the `end-of-action-briefing §7` Handoff Option Menu → CPT Compass verbs). Auto-synthesized à la **TaCoS** (ICSE 2026); optional **LACY code-tour** modality for foreign threads. Goal: collapse the ~23-min re-entry cost. Faithfulness guard: never fabricate (anti-theater R4) — low research-coverage surfaces as an honest "unknown," not a confident guess.

> **Output contract (single-CTA, disambiguated):** re-entry renders **one** primary recommended action as the CTA; the Handoff Option Menu (up/down/sideways/forward Compass verbs) is **secondary and optional**, shown only on request or at `--depth full`. The DoD reflects this.

### Flags (spec)

`--session <id|path>` (target; default = current) · `--mind self|human|agent` (audience register) · `--depth auto|L1|L2|L3|full` (progressive layer; default `auto` = dormancy band, expand-on-demand) · `--media text|audio-voice|graphic` (default text; audio/graphic opt-in) · `--scope current|down|sideways|up|forward` (CPT Compass). Any-mind.

### Home & family

`multi-agent-os` (maos community), sibling of `preflight`/`postflight`/`work-compass`/`morning-briefing`/`pulse`/`opera-debrief`.

## Roadmap (build milestones — tracked by issue [#234](https://github.com/ekson73/multi-agent-os/issues/234))

- **M1** ✅ (PR #235) — text-only walking-skeleton: INGEST→RECONSTRUCT→RE-ATTUNE on 1 real dormant session; **defined the dormancy score + its output contract**.
- **M2** ✅ — dormancy-scaled depth + any-mind register (self/human/agent) + id→path resolution. Build-level contract: §M2–M4 Build-Spec.
- **M3** ⬜ — audio modality (voice-director). Build-level contract: §M2–M4 Build-Spec.
- **M4** ⬜ — graphic modality (content-recast render / session-report HTML) + LACY code-tour; **rule cross-refs** land here (bidirectional back-refs from `end-of-action-briefing §7.2`, `cowork-process-topology §9`, `loose-end-triage-queue` — deferred until the tool exists to avoid dangling forward-refs). Build-level contract: §M2–M4 Build-Spec.

## M2–M4 Build-Spec (composition contracts)

Turns each roadmap bullet into a **build-level composition contract** grounded in the
*actual* interfaces of the composed primitives (Strata — verified against their
`SKILL.md`, not vaporware). Beyond the two thin deterministic bins, **every capability
delegates to an existing primitive; no new register/audio/graphic machinery is built.**

**Net-new-vs-composed ledger:** the ONLY net-new code across M1–M4 is two thin
deterministic bins — `bin/dormancy-score.sh` (M1) and `bin/resolve-session.sh` (M2).
Register (opera-debrief), audio (voice-director/`speak.sh`), graphic (content-recast
render / session-report HTML), N-Tree (postflight P2), state-recap (morning-briefing)
are all **composed**.

### M2 — dormancy-scaled depth + any-mind register + id→path  *(BUILT — v0.2.0)*
- **id→path** (the explicit M1 gap): `bin/resolve-session.sh <id|path>` resolves a
  session **id** to its artifact path via the Claude-Code session-artifact convention
  (`<root>/<encoded-cwd>/<id>.jsonl`; `--root` overridable via flag or `$CLAUDE_SESSION_ROOT`).
  An existing path passes through; no match → non-zero + honest message (anti-theater R4
  — never a fabricated path). Deterministic (exact-match preferred, then `LC_ALL=C`
  lexical). Hardened: `set -u`-safe when `HOME` is unset (`${HOME:-}`), and rejects
  glob-metachar ids (`*?[`) — `find -name` glob would otherwise silently resolve the
  WRONG artifact. INGEST now feeds `dormancy-score.sh` the resolved path.
- **any-mind register**: `--mind` → `opera-debrief --audience` — `self`/`human` →
  `--audience human` (warm; `self` at lower `--intensity`), `agent` → `--audience agent`
  (machine-economy JSON-RPC digest). RE-ATTUNE delegates the register switch to
  opera-debrief (which already owns human/agent registers + the faithfulness/tone gates)
  — zero new register code.
- **dormancy-scaled depth**: `--depth` defaults to `dormancy-score.sh`'s
  `recommended_depth` band; it gates how many pedagogy layers render — L1 perception,
  L2 comprehension (the N-Tree "vibe"), L3 projection (next-actions), `full` (+ the
  secondary Compass menu). Composes content-recast/opera-debrief `--intensity` + act-count.
- **Acceptance**: `--session <id>` resolves a real dormant session · `--mind agent`
  yields the JSON-RPC digest via opera-debrief · `--depth`/band varies layer count ·
  smoke green (resolver: passthrough · exact-over-prefix · not-found/usage/bad-root ·
  HOME-unset-safe · glob-metachar-id rejected → non-zero).

### M3 — audio modality  *(SPEC — ready for build)*
- **Composition (a passthrough, not new audio machinery):** `session-reentry --media
  audio-voice` → after RE-ATTUNE renders the text, delegate to `opera-debrief --media
  audio-voice`, which ALREADY wires `bin/speak.sh --play` + `skills/voice-director`
  (`--style narrador`, register-adapted). Voice/gender/intonation/rhythm casting is
  voice-director's job (hybrid deterministic × agentic). Net-new for M3 = only the
  passthrough + removing the M1 stderr-deferral for `audio-voice`.
- **Guardrails (inherited):** audio is **OPT-IN, NEVER auto-plays** (the mind may be
  where sound is unwelcome); text stays the default. If `speak.sh`/voice-director is
  unavailable → honest stderr fallback to text (never a faked audio artifact, R3).
- **Acceptance**: `--media audio-voice` speaks the re-onboarding via opera-debrief's
  audio path; text remains default; graceful honest fallback when the producer is absent.
- **Test note (honest):** audio playback is not CI-testable (opt-in + no audio device);
  a smoke would assert the passthrough + honest-fallback logic, **not** actual playback
  (faking an audio test would be the anti-theater this corpus forbids).

### M4 — graphic modality + LACY code-tour + rule cross-refs  *(SPEC — the heaviest)*
- **Graphic:** `--media graphic` → `content-recast` render path (→ Gamma · NotebookLM ·
  `make-pdf`) for the objective N-Tree, **+** `session-report/template.html` (HTML view).
  Compose content-recast's render Composition map — no new renderer.
- **LACY code-tour:** optional modality for a mind re-entering a *foreign code* thread —
  an auto-synthesized walkthrough (à la TaCoS, ICSE 2026) over content-recast render.
- **Rule cross-refs (land HERE, now the tool exists):** bidirectional back-refs from the
  cross-repo akasha rules — `end-of-action-briefing-protocol §7.2` (SENDING seed → this
  RECEIVING tool), `cowork-process-topology §9` (Compass walk → its pedagogical
  elevation), `loose-end-triage-queue` (Taxis — re-entry surfaces the pending queue).
  ⚠️ These are **cross-repo edits (operator akasha-claude, a shared repo)** → an akasha
  worktree + PR, **not** this maos repo. Deferred until now to avoid dangling
  forward-refs to a not-yet-built tool (audit-protocols §1).
- **Acceptance**: `--media graphic` produces an HTML/Gamma N-Tree · LACY tour for a
  foreign code thread · the 3 rule cross-refs land bidirectionally (no dangling ref).
- **Why heaviest / still spec:** real graphic producers + cross-repo (shared akasha)
  rule edits — larger blast-radius than M2; kept as a build-ready spec tracked in #234.

## Definition of Done (per milestone)

Reconstructs a real dormant/foreign session's intent-hierarchy purely from persisted artifacts · progressive layered output (L1→L2→L3, expand-on-demand) · faithfulness guard (no fabrication) · any-mind register · dormancy-scaled depth · **one primary recommended action (CTA) + optional secondary Compass-verb options** · text default with opt-in modalities · every phase composes an existing primitive **except the thin dormancy score (net-new, M1)** · SKILL.md + bin + tests + PR→converge→merge.

## Consequences

**Positive:** closes the RECEIVING-side gap; collapses re-entry cost; any-mind onboarding (incl. cross-vendor / other humans); near-pure composition (low build risk; the only net-new is a thin dormancy score); makes the 37-surface taxonomy actionable. **Negative / risks:** depends on the quality of what the SENDING side persisted (garbage-in); multi-modal producers add opt-in surface; the dormancy score needs calibration. **Neutral:** rule cross-refs deferred to M4 (avoids vaporware refs now).

## References

- Build tracker: [ekson73/multi-agent-os#234](https://github.com/ekson73/multi-agent-os/issues/234).
- Input surface: the 37-type work-surface taxonomy — [`docs/work-surface-taxonomy-2026-07.md` @ ekson73/akasha-claude](https://github.com/ekson73/akasha-claude/blob/main/docs/work-surface-taxonomy-2026-07.md) (operator akasha-claude, cross-repo).
- SENDING-side duals **in THIS repo** (this tool RECEIVES what they emit): `skills/postflight` P3 · `docs/auto-catchup-protocol.md`. Cross-repo: `end-of-action-briefing-protocol.md §7.2` (operator akasha-claude rules).
- Composed primitives — **in THIS repo**: `skills/{postflight,work-compass,pulse,content-recast,opera-debrief,voice-director,agentic-session-harness,morning-briefing}` · `session-report` plugin. **Cross-repo** (operator akasha-claude): `rules/cowork-process-topology-protocol.md §9` · `skills/ticket-as-prompt`.
- Research grounding: Altmann & Trafton (2002) memory-for-goals · Monk/Trafton (2008) resumption-lag · Mark et al. (2008) cost-of-interrupted-work · Endsley (1995) situation-awareness · Nielsen progressive disclosure · Sweller CLT / Miller 7±2 · Ausubel (1960) advance-organizers · Csikszentmihalyi flow · TaCoS (ICSE 2026) · LACY code-tours · classical rhetoric + semiotics.
- Related ADRs: ADR-001 (session-identity) · ADR-002 (PR-ops).
