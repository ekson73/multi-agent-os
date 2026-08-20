---
name: atomize-and-route
description: |
  Given ANY content (braindump · prompt · doc · transcript · insight · gap · pendency ·
  idea · template) decompose it into TYPED knowledge atoms (norm · procedure · role ·
  insight · fact/reference · decision · work · gap/pendency · idea/braindump-seed ·
  template/example · question/answer), classify each (context · scope · domain ·
  confidence), relate them into a DAG (recursive/sequential/interdependent/
  interconnected/disconnected/parallel per cowork-process-topology-protocol §5),
  resolve WHERE + WHAT-FORMAT each one persists (via bin/atomize-and-route, the
  deterministic KRDR-derived taxonomy lookup), gate-and-persist (H6 governance-self-edit
  → red-team + council-gate; everything else passes straight through), and verify every
  routed target is REAL and openable before reporting DONE. Composes — does NOT
  duplicate — directive-braindump-triage (directive-only, DONE/OPEN/DROP classification),
  graphify (code/folder → knowledge-graph, source of the EXTRACTED/INFERRED provenance
  convention this skill reuses), council-gate (Boule — the H6 pre-persist gate),
  red-teaming-mandatory-trigger (Elenchus — the H6 adversarial check), and
  artifact-registry (dedup before creating any NEW agentic-tool as a `procedure`/`role`
  atom). Use when the operator wants raw, mixed, un-typed content turned into
  persisted, correctly-placed knowledge instead of one more untyped memory file.
  Cross-vendor AAIF.
triggers:
  - atomize this
  - route this content
  - turn this braindump into knowledge
  - what type of atom is this and where should it go
  - atomize e roteie isto
  - decompor este conteúdo em átomos
  - classify and persist this
version: 1.0.0
---

# Atomize & Route (soul-name: *Diairesis*)

> **Diairesis** (διαίρεσις) — Plato's method of *collection and division* (Phaedrus 265d-266b):
> gather the scattered particulars, then cut the whole "at its natural joints" rather than
> hacking it arbitrarily. System-name (the slug/trigger/filename) is `atomize-and-route`;
> *Diairesis* is display-only, per Anima envelope-safety (`[[anima]] §3.4`).

## Purpose

Close the gap between the corpus's existing **doctrine** (KRDR `§Q1.2` — decides artifact
TYPE and, since this skill, FORMAT — see the companion rule PATCH) and its existing
**auto-fire molds** (CEL: hook → ledger → drain → close) by supplying the missing
**executable, generic atomizer**: one pipeline that takes ANY content, decomposes it into
typed atoms, and resolves + persists each one idempotently — instead of every atom becoming
one more untyped file in `projects/*/memory/`.

**This skill does NOT introduce a new auto-fire mechanism.** Capture (broad + on-demand)
stays the CEL hook's job (`akasha-claude` `hooks/learn-from-correction.js`, extended with a
`kind` axis by the companion PR); this skill is the **batch/deliberate** processor that
consumes CEL's ledger (and any other raw content) and turns it into persisted, gated,
verified knowledge.

## When to use

- A braindump/transcript/doc mixes multiple KINDS of knowledge (a rule-worthy norm next to
  a one-off insight next to three unrelated TODOs) and nothing separates them.
- The CEL ledger (`~/.claude/state/learn-from-correction/ledger.jsonl`) has captured atoms
  awaiting a routing decision (`bin/atomize-and-route ledger --query --unrouted`).
- The operator wants "make this a rule / skill / ticket / memory entry" decided systematically,
  not ad-hoc per request.

## When **not** to use

- The content is ALREADY one clear type and the destination is obvious (skip straight to
  writing it — this skill exists for the *mixed/ambiguous* case, not to ceremony a single fact).
- A directive-braindump needs DONE/OPEN/DROP classification against the corpus, not
  atom-typing → use `directive-braindump-triage` instead (sibling, distinct axis).
- A codebase/folder needs a knowledge graph → use `graphify` (this skill reuses its
  `EXTRACTED/INFERRED` provenance convention, never re-derives it).
- Real-time auto-capture of a correction/insight as it's said → that's the CEL hook, already
  running; this skill processes its ledger, it doesn't replace it.

## The Pipeline (P0–P7)

### P0 — RECON (Skopos / CASC Gate-0)
Before atomizing anything: probe the corpus + check `bin/artifact-registry lookup --purpose`
(does a tool/rule for this exact intent already exist?) + check this skill's OWN ledger
(`bin/atomize-and-route ledger --query --unrouted`) for idempotency — never re-atomize
content already fully routed. Cite `environment-capability-reconnaissance` (`akasha-claude`).

### P1 — ATOMIZE
Decompose the input into ONE-CONCEPT-PER-ATOM pieces (Zettelkasten discipline), each tagged
`EXTRACTED` (verbatim / directly stated) or `INFERRED` (derived/synthesized) — the exact
honest-provenance convention `graphify` already uses; do not invent a second vocabulary.
Assign each atom a provisional TYPE from the 12-row taxonomy below (§ Taxonomy).

### P2 — CLASSIFY
Per atom: **context** (what surrounding state it depends on) · **scope** (self · user ·
project · work · community · corporate · durable-personal — per `scope-discipline-pre-creation`
`§Q1`) · **domain/category** · **tags** · **confidence** (0-1, honest — an atom you're guessing
the type of is LOW confidence, not silently rounded up).

### P3 — RELATE
Build a DAG over the atoms using the SIX relation types from
`cowork-process-topology-protocol.md §5`: **recursive** · **sequential** ·
**interdependent** · **interconnected** · **disconnected** · **parallel**. Do not invent a
7th type. A disconnected atom is a valid, common outcome (most braindumps are NOT one
coherent tree) — don't force false relations to make the DAG "look complete."

### P4 — ROUTE
For each atom, call `bin/atomize-and-route route --type <type> --scope <scope> --dry-run
--json` to resolve (format, destination, gate) deterministically. This is a **pure lookup**
(the KRDR taxonomy table, executable) — the atomizing/classifying above is the cognitive
work; routing is not. Emit a 1-line-per-atom manifest before persisting anything.

### P5 — CRITICIZE / VALIDATE / AUDIT (Gordian-proportional)
Most atoms (memory · docs · plans · tracker items · eko-engram pages) route straight through
— no council needed (`over-engineering-circuit-breaker` / Gordian: don't gate what isn't
high-stakes). **The ONE mandatory gate**: an atom of type `norm` whose `route` resolution
lands under `~/.claude/rules/` (i.e. it clears the KRDR must-fire-every-session ∧
cross-project ∧ high-stakes bar) is an **H6 governance-self-edit**
(`red-teaming-mandatory-trigger` — *Elenchus*) → an independent red-team is MANDATORY before
persisting, AND the persist itself routes through `council-gate` (*Boule*) rather than being
self-authorized. Cite both skills; do not re-implement either gate here.

### P6 — PERSIST
Apply the routed atoms idempotently (re-running P6 on the same atom set is a no-op — the
`route` ledger entry IS the idempotency key). Stamp `agent-created` provenance on anything
that becomes a tracker ticket (per `agent-ticket-provenance`, `akasha-claude`). Append the
`routed` events via `bin/atomize-and-route route` (non-dry-run) as each atom actually lands.

### P7 — VERIFY + brief
Mente Tomé + `anti-theater-grounding-protocol` R3: **every atom reported DONE must cite a
target that is REAL and openable** (a file that exists, a ticket key that resolves, a
committed line). Never report a route as "persisted" from the resolution string alone —
confirm the write. Close with the 5-state Visual Status Legend
(`end-of-action-briefing-protocol §4.1`) if the caller wants a briefing.

## Taxonomy (the executable table lives in `bin/atomize-and-route`, NOT duplicated here)

| Atom type | Format | Default destination | Gate |
|---|---|---|---|
| `norm` | markdown+frontmatter | `~/.claude/rules/` (only if must-fire ∧ cross-project ∧ high-stakes) | **H6 → red-team + council-gate** |
| `procedure` | skill/command | `multi-agent-os` (community) / `vek-ai-toolkit` (corporate) | dedup via `artifact-registry lookup` first |
| `role` | agent | `multi-agent-os agents/` | dedup via `artifact-registry lookup` first |
| `insight` | markdown | `projects/*/memory/` | elevate to `norm` only on Triple-touch (≥3×) |
| `fact` / `reference` | markdown or NotebookLM source | `~/.claude/docs/` or NotebookLM | prefer NotebookLM for research material |
| `decision` | markdown+frontmatter (ADR) | `~/.claude/docs/decisions/` | cite `decision-capture` |
| `work` | tracker item | Jira (Vek) · Linear (personal) · GH Issue (repo) | eko L4 routing |
| `gap` / `pendency` | tracker or ledger | Taxis triage tiers | never silent-drop |
| `idea` / `braindump-seed` | markdown (Dendron) | `~/eko-engram/pages/` (durable) or `plans/` (scratch) | durable vs session-scoped |
| `template` / `example` | markdown | `~/eko-engram/templates/` or repo `templates/` | |
| `question` / `answer` | markdown or tracker | `projects/*/memory/` | tracker only if independently actionable |

Run `bin/atomize-and-route --help` for the live, executable version of this table (the SSOT —
this markdown copy is illustrative and MAY drift; the bin is authoritative).

## Verification (golden E2E)

Input (synthetic, mixed): *"CEL background-agent delegations can go silent across a session
boundary (root-caused twice today) — also, remember to check PR #309 tomorrow, and here's a
Dendron page idea for 'agentic delegation failure modes'."*

1. **P1 ATOMIZE** → 3 atoms: (a) `EXTRACTED` insight — "background-agent silent-death,
   root-caused 2×"; (b) `EXTRACTED` pendency — "check PR #309 tomorrow"; (c) `INFERRED`
   braindump-seed — "agentic delegation failure modes" (synthesized from (a), not verbatim).
2. **P2 CLASSIFY** → (a) scope=user, confidence=0.9 · (b) scope=project, confidence=0.95 ·
   (c) scope=durable-personal, confidence=0.7 (it's a page IDEA, not the content itself).
3. **P3 RELATE** → (c) is **sequential** on (a) (the page would elaborate the insight); (b) is
   **disconnected** from both (unrelated PR check).
4. **P4 ROUTE** (dry-run, this session, verified against the real bin):
   ```
   $ bin/atomize-and-route route --type insight --scope user --dry-run
   ~/.claude/projects/<enc>/memory/<slug>.md
   $ bin/atomize-and-route route --type pendency --scope project --dry-run
   tracker-or-taxis-queue
   $ bin/atomize-and-route route --type braindump-seed --scope durable-personal --dry-run
   ~/eko-engram/pages/<slug>.md
   ```
5. **P5** — none of the three clears the `norm`+`rules/` bar → no red-team/council needed;
   all pass straight through.
6. **P6/P7** — (a)/(c) would persist as markdown files, (b) as a Taxis-tier tracker note; each
   confirmed openable before reporting DONE.

This is a REAL dry-run against the shipped `bin/atomize-and-route` (not hypothetical output) —
re-run it yourself to reproduce.

## Dogfood

This SKILL.md's own genesis is an atomize-and-route instance: the operator's original
Ultrathink braindump (4-part A/B/C/D ask) was itself decomposed into exactly the atom types
this pipeline names — `norm` (the KRDR format-axis patch), `procedure` (this skill + its bin),
`insight` (the background-agent-silent-death lesson, captured mid-build), `idea`
(`~/eko-engram/` as a destination) — and routed via the P0-P7 steps above, including the P5
gate (the KRDR patch, being a `norm` destined for `~/.claude/rules/`, went through the
red-team+council discipline in its own PR, not this one — see the companion `akasha-claude`
PR for that gate's application).

## Distinct-from-siblings (DRY — composes, never duplicates)

| Sibling | Distinct axis |
|---|---|
| `directive-braindump-triage` | classifies DIRECTIVES against the corpus (DONE/OPEN/DROP); this skill classifies ANY content into TYPED ATOMS and routes them — orthogonal, composable (triage first if the input is directive-shaped, then atomize the OPEN residual) |
| `graphify` | code/folder → knowledge graph (structural); this skill is content → typed+routed atoms (destination-oriented) — shares the `EXTRACTED/INFERRED` provenance tag only |
| `council-gate` (*Boule*) | the H6 pre-persist authorization mechanism this skill's P5 invokes, never reimplements |
| `red-teaming-mandatory-trigger` (*Elenchus*) | the H6 adversarial-check trigger predicate this skill's P5 invokes, never reimplements |
| `artifact-registry` | the dedup ledger this skill's P0 + `procedure`/`role` routing consult before creating anything new |
| `corpus-firing-audit` | audits whether EXISTING rules fire; this skill decides where a NEW atom should land — different question, same corpus |

## Related

- `bin/atomize-and-route` (the executable taxonomy + ledger; the P4 primitive)
- `bin/tests/atomize-and-route.test.sh`
- `skills/directive-braindump-triage/SKILL.md`
- `skills/graphify/SKILL.md`
- `skills/council-gate/SKILL.md`
- `skills/red-teaming-mandatory-trigger` (`akasha-claude` rule — cross-repo cite)
- `skills/artifact-registry` (`bin/artifact-registry`)
- Companion PR (`akasha-claude`): `hooks/learn-from-correction.js` `kind`-axis extension +
  `rules/scope-discipline-pre-creation.md` format-axis + `§Q1.3` Fire-Point Binding patch.
- Origin plan: `~/.claude/plans/ultrathink-analise-critique-busque-procu-rosy-clover.md`

## Versioning

v1.0.0 (2026-08-20) — bootstrap. Composes existing primitives (KRDR taxonomy → executable
bin, `graphify` provenance convention, `council-gate`/`red-teaming-mandatory-trigger` H6
gate, `artifact-registry` dedup); introduces zero new auto-fire mechanism (capture stays
CEL's job). Built inline (not via background Agent-tool delegation) after that delegation
mode silently stalled for this exact task earlier the same day — see
`feedback_background_agent_silent_death_diairesis_dropped.md` (`akasha-claude` memory).
