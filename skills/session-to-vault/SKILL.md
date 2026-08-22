---
name: session-to-vault
description: |
  Use when you want to PRESERVE an agent session's history as a durable, dated, tagged note in a
  knowledge vault (Obsidian or any markdown vault) — "save this session", "export this conversation
  to my vault", "salvar esta sessão no obsidian", "archive this thread", "keep a record of this
  session", "exportar a sessão", "save the session about X". Parametrized (source · format · style ·
  scope · focus · context · filters · provenance · tags), NEVER mutates the source transcript, and
  can additionally CAST the record into a medium a human can actually SEE (markdown · html ·
  diagram · slides · one-pager · artifact) — including re-casting an ALREADY-SAVED note without the
  original transcript. It preserves and presents HISTORY; it does NOT reseed or continue a session
  (use session-fission / postflight P3), and it does NOT decide what to do next (use goal-recovery).
  Vault-agnostic: the vault path and placement policy are parameters, never hardcoded.
  Cross-vendor AAIF.
triggers:
  - save this session
  - export this conversation to my vault
  - salvar esta sessão no obsidian
  - exportar a sessão para o vault
  - archive this thread as a note
  - keep a durable record of this session
  - cast this saved session as a diagram
  - re-cast this export for a human
version: 0.1.0
license: MIT
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill
metadata:
  version: "0.1.0"
  soul: "Fonógrafo"
  scope: AAIF cross-vendor
  family: session-lifecycle
  cross_link_slug: session-to-vault
  dogfood_status: pending-first-cycle
---

# Session to Vault

> **Soul-name**: *Fonógrafo* (display only — never the slug) — the instrument that inscribes an ephemeral
> voice onto a durable medium so it can be replayed later. **System-name**: `session-to-vault`.

## Overview

A session is a **dialogue** — ephemeral, stored as a raw transcript the agent host will eventually rotate away.
This skill turns it into a **durable, dated, tagged, cross-linkable note** in a markdown knowledge vault, and —
optionally — into a **reading copy a human can see**.

Single responsibility = **preservation + presentation of history**. Everything else is delegated:

| Concern | Owner (delegated, never reimplemented here) |
|---|---|
| Read-only snapshot/parse discipline | `skills/session-fission` |
| Narrative register (story-arc prose) | `skills/opera-debrief` |
| Audience re-targeting + slides/PDF/NotebookLM producers | `skills/content-recast` |
| Diagrams (flow · sequence · lifecycle, SVG/PNG) | `archify` |
| Published shareable page | the host's `Artifact` tool |

**Vault-agnostic by construction**: the destination vault, its folder taxonomy, and its placement policy are
**parameters** (`--vault-path`, `--placement`), never constants. This skill knows *how* to preserve a session;
it does not know, and must not encode, *whose* vault it is.

## When to use / when not

**Use** when a session contains something worth keeping — decisions, a debate that converged, provenance for a
ticket, an investigation whose reasoning matters later — and the transcript alone is too raw to read.

**Do NOT use** for:

| You want… | Use instead |
|---|---|
| to continue/resume/reseed work | `postflight` P3 continuation seed · `session-fission` |
| to know what to do next | `goal-recovery` · `work-compass` |
| token/usage analytics | a usage dashboard — this is qualitative, not quantitative |
| to narrate a session as a story (fixed audience/register) | `opera-debrief` directly |
| to distill reusable lessons OUT of a session | your knowledge-atom router (e.g. `atomize-and-route`) |

## §0 — BEING > Rules (foundational)

Preservation serves the human who will need the record later. If this pipeline's ceremony obstructs actually
keeping the record, keep the record and log the skipped step. A lost session is the only unrecoverable outcome.

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `<source>` (positional) | `self` | `self` (the invoking session) · a session-id · an absolute transcript path · **a vault note** already produced by this skill (→ cast-only mode) |
| `--vault-path` | `auto` | Absolute path to the destination vault root. `auto` = detect a vault marker (e.g. `.obsidian/`) upward from cwd, else ask. **Never hardcoded.** |
| `--placement` | `flat` | Folder policy inside the vault: `flat` (one dated note at the vault root or `--subdir`) · `dated` (`YYYY/MM/`) · `para` (project-bound → `projects/<slug>/`, else `journals/`) · `custom:<pattern>` (e.g. `custom:archive/{yyyy}/{slug}.md`). |
| `--subdir` | *(none)* | Optional subdirectory under the vault root, applied by `flat`/`dated`. |
| `--format` | `journal` | **How much text**: `journal` (dated note — gist, decision timeline, appendices) · `raw` (verbatim role-tagged) · `digest` (≤500 words). |
| `--style` | `auto` | **Register**: `auto` (agent-economy for a machine consumer, technical-decision-log for a human) · `raw` · `technical` · `narrative` (**delegates** to `opera-debrief`). |
| `--scope` | `all` | `all` · an ISO date/time range · `focus-only`. |
| `--focus` | *(none)* | Topic to slice by; matching turns are kept **plus** `--context` padding — never a bare keyword grep. |
| `--context` | `same-as-source` | Padding around a `--focus` hit: integer turns · `0` · `full` · `same-as-source` (computed from the session's own turn density). |
| `--filters` | *(none)* | e.g. `no-tool-noise` — drops raw tool blocks, keeping role-tagged prose. The transcript remains the lossless record; this is a *reading* copy. |
| `--provenance` | *(none)* | External artifacts stitched in as a **separately cited appendix** (source · origin/URL · date). Never blended into the session's own turns. |
| `--tags` | `auto` | Frontmatter tags: derived from `--focus` + project/repo + session date(s). |
| `--cast-to` | `none` | **Medium** for a human-readable companion — see § Cast. Repeatable. |
| `--dry-run` | `false` | Compute and report; write nothing. |

### Defaults doctrine

- **`same-as-source`** — when a parameter describes a shape the source already implies (padding density,
  register, project attribution), compute it FROM the source.
- **`auto`** — when a parameter has a decidable-by-reasoning answer (tags, style-for-this-consumer, slug),
  compute it.
- **Ask only the genuine residue** — a parameter is asked only when it is neither derivable AND the answer
  materially changes the output. Route the ask by consumer: a present human → a ranked, recommended-first
  question; a deferred human → never block, act if `score ≥ 0.85 ∧ reversible ∧ ¬human-domain`, else persist a
  ranked recommendation set; a machine/hook → a JSON-RPC-shaped envelope, never prose.

## Pipeline (0 → 7)

| # | Phase | Kind | Do |
|---|---|---|---|
| 0 | **Resolve source** | det | Locate the transcript (or the vault note → cast-only mode). If not found, say so — never guess a nearby file. |
| 1 | **Resolve params** | hybrid | Fill per § Defaults doctrine; ask only the residue. |
| 2 | **Extract** | det | Parse role · timestamp · content; collapse tool noise unless `--filters` says otherwise; apply `--scope`/`--focus`/`--context` as a read-only projection. **Never mutate the source.** |
| 3 | **Scope discipline** | nondet | Multi-session asks only — see § Scope discipline. |
| 4 | **Enrich** | nondet | Attach `--provenance` items as a separately cited appendix. |
| 5 | **Render** | hybrid | Shape per `--format`/`--style`. `narrative` delegates to `opera-debrief`. |
| 6 | **Sanitize + persist** | det | Secret-scrub (gitleaks-class) **before** any write; then write idempotently per `--vault-path`/`--placement`. Log path + what was included/excluded — an uncited write did not happen. |
| 7 | **Cast** | hybrid | Only when `--cast-to` ≠ `none` — see § Cast. |

## Cast (`--cast-to`) — the reading copy a human can *see*

The record and the **reading** of that record are different artifacts. A 400-turn export is faithful and
unreadable. A cast is a **derived companion**: the note stays authoritative; delete any cast and nothing is lost.

### Why a separate axis

| Axis | Question | Owner |
|---|---|---|
| `--vault-path` / `--placement` | **WHERE** does it land? | this skill (parameters) |
| `--format` | **HOW MUCH** text? | this skill |
| `--style` | In **WHICH REGISTER**? | this skill (`narrative` → `opera-debrief`) |
| `--cast-to` | In **WHICH MEDIUM** does a human read it? | this section |

`--format=digest --cast-to=slides` is a real, distinct request. Folding medium into format would conflate
*volume* with *medium*. `narrative` stays a **`--style`**: register ≠ medium.

### Medium registry — every medium delegates

| `--cast-to` | Produces | Delegates to | Sink class |
|---|---|---|---|
| `none` *(default)* | nothing — the note is the deliverable | — | — |
| `auto` | picks from the **local** rows only | own reasoning | local |
| `markdown` | a reading copy (gist + decision timeline + collapsed detail) | native | local |
| `html` | one self-contained, theme-aware file | native (inline CSS/SVG, no external fetch) | local |
| `diagram` | flow / sequence / lifecycle + SVG/PNG | `archify` | local |
| `artifact` | a published, shareable page | host `Artifact` tool | **external** |
| `slides` | a deck | `content-recast` → its slides producer | **external** |
| `one-pager` | a one-page PDF | `content-recast` → its PDF producer | per producer |
| `notebooklm` | an NLM source + prompt | `content-recast` → its NLM producer | **external** |

### Rules (fail-closed)

1. **`auto` NEVER selects an external medium.** It may resolve only to `markdown`, `html`, or `diagram`.
   `artifact` · `slides` · `notebooklm` publish to a third-party service; a disclosure cannot be un-sent, so
   they require **explicit opt-in by name**. An `auto` that could reach them would silently externalise a
   private session. Invariant: `auto_may_select ∩ external_media = ∅`.
2. **Sanitize covers the cast.** Phase 6's scrub applies to every medium; a hit **aborts the whole run** — the
   note *and* every cast.
3. **Idempotent + reversible.** Same source + same params ⇒ same cast, at a deterministic sibling path
   `<note-slug>.cast.<medium>.<ext>`. Always safe to delete and re-derive.
4. **Opt-in by default (`none`).** An unbidden extra file is over-engineering; the capability exists for when a
   human actually needs to *see* the session.

### Cast-only mode

When `<source>` is a **vault note** rather than a transcript, phases 0→5 collapse (the material is already
extracted, scoped, enriched and rendered) and only **6 → 7** run. This is what lets you re-cast a months-old
export into a diagram without re-reading — or even still having — the original transcript. If `--cast-to` is
`none` in this mode the run is a **no-op** and says so; it never silently rewrites the note.

## Scope discipline (multi-session asks)

"Export every session about X" read literally (grep the keyword) exports dozens of incidental hits — compaction
summaries carry a term forward verbatim, hook-spawned sub-sessions echo the last message. **The rule**: export a
session when its content *substantively concerns* the topic (a real thread, decisions, artifacts) — not when the
term merely appears. Every session considered is **listed**; each one not exported states its reason
(scanned-and-excluded, never silently dropped).

## Composition map (zero new engines)

```
session-to-vault
├── extract/snapshot discipline ──→ session-fission   (read-only, never mutate)
├── --style=narrative ────────────→ opera-debrief
├── --cast-to=diagram ────────────→ archify
├── --cast-to=slides|one-pager|notebooklm ─→ content-recast
└── --cast-to=artifact ───────────→ host Artifact tool
```

## Anti-patterns (do NOT)

- ❌ **Hardcode a vault path, folder taxonomy, or personal project slug.** They are parameters. A skill that
  knows whose vault it is cannot be shared.
- ❌ **Mutate, delete, or reseed the source session.** This tool preserves; it never edits history.
- ❌ **Let `--cast-to=auto` reach an external medium.** Fail-closed, always.
- ❌ **Treat a cast as the record.** The note is authoritative; a cast is derived and deletable.
- ❌ **Reimplement a producer** (a diagram engine, a slide renderer, a narrative pass). Delegate.
- ❌ **Blend `--provenance` into the session's own turns.** Evidence sits *alongside* the record, cited.
- ❌ **Bare-keyword multi-session export.** Apply § Scope discipline and show the excluded list.
- ❌ **Write before sanitizing.** The scrub precedes every write, cast included.

## §Quality Tests (self-dogfood — 6/6)

| # | Test | Verdict |
|---|---|---|
| 1 | **Self-Application** — this skill's own promotion was preceded by a coverage check that found the engine already existed in a personal vault; it was generalized, not re-authored. | ✅ |
| 2 | **Non-Contradiction** — composes `session-fission`/`opera-debrief`/`content-recast`/`archify` without redefining any of them; `narrative` stays a style, never a medium. | ✅ |
| 3 | **Survival** — applied to itself, it advocates preserving the record and parameterizing the destination; it does both. | ✅ |
| 4 | **Bounded-Responsibility** — preservation + presentation only; continuation, next-action and lesson-extraction are explicitly routed elsewhere. | ✅ |
| 5 | **Explicit-Exception** — §0 escape · `--dry-run` · cast-only no-op · the fail-closed external-medium gate. | ✅ |
| 6 | **Utility-Sunset** — §DUED below. | ✅ |

## §DUED Sunset (qualitative, not counter-based)

Retire when ANY: agent hosts ship durable, queryable, exportable session history natively (the preservation half
becomes moot) · a vault tool absorbs both preservation and casting more elegantly · ≥3 contexts where the cast
media prove to be the wrong abstraction (refine, don't auto-retire) · operator retraction.

## Related Multi-Agent OS Artifacts

- `skills/session-fission` — snapshot/parse discipline (composed)
- `skills/opera-debrief` — narrative register (composed)
- `skills/content-recast` — audience re-targeting + slides/PDF/NLM producers (composed)
- `skills/session-reentry` · `postflight` — continuation, the orthogonal half of the session lifecycle

## §Refs

- Read-only-snapshot discipline: `skills/session-fission`
- Register/medium separation: `skills/content-recast` § Composition map
- Fail-closed disclosure reasoning: external publication is irreversible — opt-in by name only

## License

MIT

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-08-21 | Promotion — generalized from a personal-vault protocol into a vault-agnostic community skill. The engine (pipeline 0→7, parameters, cast) lives here; vault-specific placement/routing stays in the consuming vault as configuration. Adds `--vault-path`/`--placement` (nothing hardcoded), the `--cast-to` medium axis with its fail-closed external gate, and cast-only mode. |
