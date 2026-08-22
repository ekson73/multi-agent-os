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
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill, Artifact
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
| Diagrams (flow · sequence · lifecycle, SVG/PNG) | `archify` — ⚠️ not bundled, probed at selection time |
| Published shareable page | the host's `Artifact` tool — ⚠️ host-provided, probed at selection time |

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

Preservation serves the human who will need the record later. If this pipeline's **ceremony** obstructs actually
keeping the record, keep the record and log the skipped step.

⛔ **The escape covers ceremony only — never a safety gate.** The § Sanitize Gate and the § Cast fail-closed
external-medium rule are **not** skippable by this clause, by a time-box, or by "the scanner was unavailable".
If the scrub cannot run, or runs and hits, the correct outcome is **write nothing and say why** — a transcript
can be re-exported, a leaked credential cannot be un-leaked. "Keep the record anyway" is the right instinct for
a missing tag, a skipped narrative pass, or an unresolved `--context` heuristic; it is the wrong instinct for a
secret.

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `<source>` (positional) | `self` | `self` (the invoking session) · a session-id · an absolute transcript path · **a vault note** carrying this skill's frontmatter marker (→ cast-only mode; see § Note identity — an arbitrary markdown file is **not** a valid source) |
| `--vault-path` | `auto` | Absolute path to the destination vault root. `auto` = detect a vault marker (e.g. `.obsidian/`) upward from cwd, else ask. **Never hardcoded.** |
| `--placement` | `flat` | Folder policy inside the vault: `flat` (one dated note at the vault root, or under `--subdir`) · `dated` (`YYYY/MM/`) · `para:<mapping>` (**delegated** — the consumer supplies the project-bound/general folder mapping; this skill does not know your taxonomy, see § Placement is the consumer's) · `custom:<pattern>` (e.g. `custom:archive/{yyyy}/{slug}.md`). All resolved paths pass § Path safety. |
| `--subdir` | *(none)* | Optional subdirectory under the vault root, applied by `flat`/`dated`. Confined by § Path safety. |
| `--format` | `journal` | **How much text**: `journal` (dated note — gist, decision timeline, appendices) · `raw` (verbatim role-tagged) · `digest` (≤500 words). |
| `--style` | `auto` | **Register**: `auto` (agent-economy for a machine consumer, technical-decision-log for a human) · `raw` · `technical` · `narrative` (**delegates** to `opera-debrief`). |
| `--scope` | `all` | `all` · an ISO 8601 date/time range · `focus-only`. ⛔ `focus-only` with an absent or empty `--focus` is a **hard error — fail immediately** with a clear message; never fall through to a projection with an undefined selector (that silently exports everything or nothing). |
| `--focus` | *(none)* | Topic to slice by; matching turns are kept **plus** `--context` padding — never a bare keyword grep. If a `--focus` yields **zero** matching turns, see § Empty projection — do not write an empty note. |
| `--context` | `same-as-source` | Padding around a `--focus` hit: integer turns · `0` · `full` · `same-as-source` (computed from the session's own turn density). |
| `--filters` | *(none)* | Tool-block handling has **three explicit states**, and only these: **default (no filter)** → tool blocks are *collapsed to a one-line summary each* (kept, but not raw); **`no-tool-noise`** → tool blocks are *dropped entirely*, keeping only role-tagged prose; **`--format=raw`** → verbatim, nothing collapsed or dropped (raw means raw, and this filter does not apply). The transcript remains the lossless record; this is a *reading* copy. |
| `--provenance` | *(none)* | External artifacts stitched in as a **separately cited appendix** — each entry carries `source · origin/URL · date`, and the date is **ISO 8601** (`YYYY-MM-DD`), never relative. Never blended into the session's own turns. |
| `--tags` | `auto` | Frontmatter tags: derived from `--focus` + project/repo + session date(s). |
| `--cast-to` | `none` | **Medium** for a human-readable companion — see § Cast. Repeatable. |
| `--scanner` | `gitleaks` | The secret-scanner the § Sanitize Gate runs over the whole staged set before any commit. Any command honouring the gate contract (receives a staged path, returns exit 0 = clean / non-zero = hit). Absent or unrunnable ⇒ treated as a **hit**, with an error naming the prerequisite. |
| `--dry-run` | `false` | Compute and report; **write nothing and invoke no producer that has a side effect**. Every cast is *reported as requested* (medium · would-be path · producer · sink class) but **not** produced: `artifact`, `slides` and `notebooklm` must not be published, uploaded, or created under `--dry-run` — a "dry" run that publishes is the worst possible surprise. Local media are not rendered to disk either. |

### Defaults doctrine

- **`same-as-source`** — when a parameter describes a shape the source already implies (padding density,
  register, project attribution), compute it FROM the source.
- **`auto`** — when a parameter has a decidable-by-reasoning answer (tags, style-for-this-consumer, slug),
  compute it.
- **Ask only the genuine residue** — a parameter is asked only when it is neither derivable AND the answer
  materially changes the output. Route the ask by consumer: a present human → a ranked, recommended-first
  question; a deferred human → never block, act if `score ≥ 0.85 ∧ reversible ∧ ¬human-domain`, else persist a
  ranked recommendation set; a machine/hook → a JSON-RPC-shaped envelope, never prose.

## Pipeline (0 → 8)

| # | Phase | Kind | Do |
|---|---|---|---|
| 0 | **Resolve source** | det | Locate the transcript (or the vault note → cast-only mode). If not found, say so — never guess a nearby file. |
| 1 | **Resolve params** | hybrid | Fill per § Defaults doctrine; ask only the residue. |
| 2 | **Extract** | det | Parse role · timestamp · content; collapse tool noise unless `--filters` says otherwise; apply `--scope`/`--focus`/`--context` as a read-only projection. **Never mutate the source.** |
| 3 | **Scope discipline** | nondet | Multi-session asks only — see § Scope discipline. |
| 4 | **Enrich** | nondet | Attach `--provenance` items as a separately cited appendix. |
| 5 | **Render** | hybrid | Shape per `--format`/`--style`. `narrative` delegates to `opera-debrief`. |
| 6 | **Stage note** | det | Render the note into the private staging area per `--vault-path`/`--placement` (destination *resolved and validated* per § Path safety, but **not yet written**). |
| 7 | **Stage casts** | hybrid | Only when `--cast-to` ≠ `none`. Produce **every** requested cast into staging. See § Cast. |
| 8 | **Scan + commit** | det | § Sanitize Gate over the **whole staged set**; on any hit, discard staging and stop — nothing was committed. On all-clean, commit local sinks first, external sinks last and one at a time. Log every write (path + what was included/excluded) — an uncited write did not happen. |

### § Sanitize Gate (a gate, not a phase)

The secret-scrub is **not** a positional step that runs once mid-pipeline — it is a **gate standing between
staging and *any* commit, over the exact bytes of every artifact the run produced**. A scrub bound to the note's
own step could not inspect a cast that a later phase had not rendered yet, and would let it reach its sink
unscanned; a per-artifact scan-then-write fixes that but still cannot *abort*, because by the time the second
artifact fails the first is already written. Hence: stage everything, scan everything, then commit.

- **Covers**: the note *and* every cast — the rendered HTML, diagram source, deck, or payload about to be
  published. Each is scanned as **its own bytes**; scanning only the note would leave a cast unscanned.
- **On a hit**: **nothing is committed at all** — see § Stage-scan-commit. This is an ordering guarantee, not a
  cleanup promise: a rollback promise would be worthless for an already-published external artifact.
- **If the scanner is unavailable**: that is a **hit**, not a pass. Absence of a scan is not evidence of
  cleanliness — write nothing and say why (§0 explicitly does not cover this).

#### § Stage-scan-commit (why per-artifact scan-then-write is not enough)

A per-artifact "scan then write" loop **cannot** deliver "a hit aborts the note and every cast". If the note
passed and was written, and a later cast hits, the note is *already persisted*; if an external cast was already
published, it **cannot be withdrawn at all**. The guarantee has to be established *before* the first commit:

1. **STAGE** — render **every** output of the run (the note and each requested cast) into the private staging
   directory (`0700` dir, `0600` files) **outside the vault**. Nothing touches a sink in this step.
2. **SCAN** — run the scanner over **all** staged artifacts. Any hit, or any artifact whose scan could not run,
   fails the **whole set**.
3. **COMMIT** — only when the entire set is clean:
   - **local sinks first** (the note, then local casts) — filesystem moves, individually reversible;
   - **external sinks last, and one at a time** (`artifact` · `slides` · `notebooklm`) — because publication is
     **irreversible**, it is the final act, never interleaved with work that could still fail.
4. **On failure at step 2** — delete the staging directory and exit. Nothing was ever committed, so there is
   nothing to roll back. This is the only atomicity that is actually achievable.

**Honest limit** (stated, not glossed): if a run publishes to *several* external sinks and one fails **after**
another has already published, the earlier publication stands and cannot be undone. The contract is therefore
**"nothing is published unless everything scanned clean"** — not "everything can be undone". The run reports
exactly which external sinks committed.

#### The scanner is named, not assumed

A fail-closed gate that names no scanner is not fail-closed — it is **broken**: every export would abort with
no way to satisfy it. So the gate has a concrete, satisfiable contract:

| | |
|---|---|
| **Supported scanner** | `gitleaks` — already this repo's CI secret-scanner, so it is the house standard rather than a new dependency invented here |
| **Prerequisite** | `gitleaks` on `PATH` (`gitleaks version` answers) — **required to write**; this is documented, not implied |
| **Override** | `--scanner=<command>` — any command honouring the contract below; lets a consumer plug their own |
| **Contract** | the command receives **a path to the exact bytes about to be written** and returns **exit 0 = clean · non-zero = hit**. Anything else (command absent, non-executable, timeout, crash) = **unavailable = hit** |

**How the scanner is invoked** (the *ordering* is § Stage-scan-commit; this is the call itself):

- it receives the **path to a staged artifact**, never a destination path — e.g.
  `gitleaks detect --no-git --source <staged-path> --redact`;
- exit **0** = clean · **non-zero** = hit · not runnable / timeout / crash = **unavailable**, treated as a hit;
- **hit** and **unavailable** are reported as **different messages**: the unavailable one names the prerequisite
  (`install gitleaks, or pass --scanner=<cmd>`) so the operator can act instead of being stuck;
- the report always names **which artifact** failed, not just that the run failed.

**Under `--dry-run`** no artifact is written, so no scan is required — the gate is *not applicable*, not
*waived*. The distinction matters: dry-run is safe because nothing is produced, never because the gate is soft.

### § Path safety (every write is confined to the vault)

`--subdir` and `custom:<pattern>` accept caller-supplied text, so every resolved destination is **normalized and
confined beneath `--vault-path` before any write**:

- reject **absolute** paths and drive/UNC prefixes in `--subdir` / `custom:` patterns;
- reject traversal segments (`..`) — after normalization, not merely by substring match;
- resolve symlinks and re-check: a symlink inside the vault that points outside it is an **escape**;
- the final real path must be **strictly under** the real `--vault-path`; if it is not, **write nothing** and
  report the rejected path.

A rendered `{slug}` is sanitized too — a focus/topic string flows into filenames, so path separators and
traversal sequences are stripped there as well.

### § Note identity (what makes a file a valid cast-only source)

Cast-only mode must never treat an arbitrary markdown file as an export. A note is a valid `<source>` **only**
if its frontmatter carries this skill's marker plus the identity/idempotency fields it writes on every persist:

| Frontmatter key | Written at persist | Purpose |
|---|---|---|
| `session_to_vault: <skill-version>` | always | the **marker** — its absence means "not my artifact"; refuse cast-only |
| `source_session_id` | always | which session this record came from |
| `source_transcript_sha256` | when the transcript is readable | detect that the source changed since export |
| `source_params` | always | the exact `{format, style, scope, focus, context, filters}` used — makes a re-run reproducible |
| `casts` | when casts exist | `[{medium, path_or_url, producer, created}]` — so re-casting is idempotent rather than duplicative |
| `created` / `updated` | always | **ISO 8601** |

If the marker is absent → refuse and say so. If `source_transcript_sha256` no longer matches a still-present
transcript → still allow the cast, but **state that the record is a snapshot of an since-changed source**.

### § Placement is the consumer's (`para:<mapping>`)

`flat`, `dated` and `custom:` are complete here. **`para` is not**: "project-bound goes to `projects/<slug>/`,
everything else to `journals/`" is *one vault's* taxonomy, not a universal one — hardcoding it would reintroduce
exactly the coupling this promotion exists to remove.

So `para` **delegates**: the consumer supplies the mapping (a project-bound folder pattern and a general-trace
folder pattern) via `--placement=para:<mapping>` or its own configuration. With no mapping supplied, this skill
does **not** guess a folder layout — it asks, or falls back to `flat`, and says which it did.

### § Empty projection (never write an empty record)

A `--focus`/`--scope` combination can select **zero** turns. In that case:

- **write nothing** — an empty note is not a record, it is litter that later reads as "we discussed nothing";
- report the projection that matched nothing (source · scope · focus · context) so the caller can widen it;
- exit as a **no-match**, distinct from both success and error.

Conversely, every successful write is **non-empty and self-auditing**: the persisted note carries an audit
section stating source, scope/focus applied, what was included, what was excluded and why, and the sanitization
verdict. A write with no audit section is not a valid write.

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
| `diagram` | flow / sequence / lifecycle + SVG/PNG | `archify` ⚠️ **not bundled** — see § Producer availability | local |
| `artifact` | a published, shareable page | host `Artifact` tool | **external** |
| `slides` | a deck | `content-recast` → its slides producer | **external** |
| `one-pager` | a one-page PDF | `content-recast` → its PDF producer | per producer |
| `notebooklm` | an NLM source + prompt | `content-recast` → its NLM producer | **external** |

### Rules (fail-closed)

1. **`auto` NEVER selects an external medium.** It may resolve only to `markdown`, `html`, or `diagram`.
   `artifact` · `slides` · `notebooklm` publish to a third-party service; a disclosure cannot be un-sent, so
   they require **explicit opt-in by name**. An `auto` that could reach them would silently externalise a
   private session. Invariant: `auto_may_select ∩ external_media = ∅`.
2. **Every cast passes the § Sanitize Gate at its own write.** The gate is invoked per artifact, *after* the
   cast is rendered and *before* it is written or published — a cast can introduce content the note never had
   (an embedded payload, an inlined snippet), so scanning only the note would leave it unscanned. A hit
   **aborts the whole run** — the note *and* every cast.
3. **Idempotent + reversible.** Same source + same params ⇒ same cast, at a deterministic sibling path
   `<note-slug>.cast.<medium>.<ext>`. Always safe to delete and re-derive.
4. **Opt-in by default (`none`).** An unbidden extra file is over-engineering; the capability exists for when a
   human actually needs to *see* the session.
5. **Probe the producer before promising the medium** — see § Producer availability.

### § Producer availability (presence ≠ reachability)

Only `markdown` and `html` are **native** to this skill. Every other medium delegates to a producer that may or
may not be installed alongside it:

| Medium | Wrapper (ships here?) | **Terminal renderer** (the thing that actually produces the file) |
|---|---|---|
| `markdown` · `html` | native ✅ | native — nothing downstream |
| `--style=narrative` | `skills/opera-debrief` ✅ | prose only — nothing downstream |
| `slides` | `skills/content-recast` ✅ | ❌ **deck producer (e.g. Gamma / a `pptx` skill) — NOT bundled** |
| `one-pager` | `skills/content-recast` ✅ | ❌ **PDF producer — NOT bundled** |
| `notebooklm` | `skills/content-recast` ✅ | ❌ **NotebookLM access — NOT bundled** |
| `diagram` | — | ❌ **`archify` — NOT bundled** (user/host-scope skill) |
| `artifact` | — | ❌ **host `Artifact` tool — provided by the agent host** |

**Rule — probe transitively, to the terminal renderer.** A medium is admissible only when the component that
actually emits the file answers. **Probing the wrapper is not enough**: `content-recast` ships here, but it
*delegates* slides/PDF/NotebookLM downstream — so with the wrapper present and the renderer absent it can only
return **handoff instructions**, not an artifact. Instructions are not a cast:

- if the terminal renderer does not answer, the medium is **unavailable** even though its wrapper is installed;
- a wrapper that returns guidance instead of a file ⇒ **report the cast as not produced**. Never log a
  `casts_written` entry for an artifact that does not exist — a phantom cast is worse than a missing one,
  because the note's own frontmatter would then lie about what exists.

- **`auto` must probe first** and choose only among producers that actually answered. If `archify` is absent,
  `auto` falls back to a native medium (`html`, else `markdown`) **and says which fallback it took and why** —
  it never silently emits nothing, and never claims a medium it could not produce.
- **An explicitly named unavailable medium is an error, not a substitution.** `--cast-to=diagram` with no
  `archify` present → report the missing producer and how to install it; do **not** quietly hand back markdown
  under a diagram's name.
- **Never bundle a copy of a producer** to dodge this. Vendoring a diagram engine here would fork a tool that
  already exists; the honest fix is the probe plus the documented dependency.

### Cast-only mode

When `<source>` is a **vault note** rather than a transcript, the run is **0 · 1 · 7 · 8**: resolve the source
(0) and the parameters (1) as always, then **skip 2→6** — the material is already extracted, scoped, enriched,
rendered **and persisted** — and go straight to staging the casts (7) and scanning/committing them (8).

Phase **6 (Stage note) is deliberately skipped**: the note already exists, and re-staging it would put it back
on the commit path — the silent rewrite this mode must never do. The § Sanitize Gate still covers everything
this run actually produces, because the staged casts are scanned in phase 8 before any of them is committed.

This is what lets you re-cast a previously persisted export (of any age) into a diagram without re-reading — or
even still having — the original transcript. If `--cast-to` is `none` in this mode there is no phase left to
run: the invocation is a **no-op** and says so. It never rewrites the note.

All dates written or cited by this skill — frontmatter `created`/`updated`, `--provenance` entries, `--scope`
ranges — are **ISO 8601** (`YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ssZ`). Relative or ambiguous dates ("last week",
"months old", `08/09/26`) are never persisted.

## Scope discipline (multi-session asks)

"Export every session about X" read literally (grep the keyword) exports dozens of incidental hits — compaction
summaries carry a term forward verbatim, hook-spawned sub-sessions echo the last message. **The rule**: export a
session when its content *substantively concerns* the topic (a real thread, decisions, artifacts) — not when the
term merely appears. Every session considered is **listed**; each one not exported states its reason
(scanned-and-excluded, never silently dropped).

## Composition map (zero new engines)

```text
session-to-vault
├── extract/snapshot discipline ──→ session-fission   (read-only, never mutate)
├── --style=narrative ────────────→ opera-debrief
├── --cast-to=diagram ────────────→ archify
├── --cast-to=slides|one-pager|notebooklm ─→ content-recast
└── --cast-to=artifact ───────────→ host Artifact tool
```

## Examples

```text
# 1. Save the current session, defaults, into a detected vault.
session-to-vault
#    -> writes one dated note; no cast (--cast-to defaults to none).

# 2. Save a specific session into an explicit vault, dated folders.
session-to-vault 0c841e65 --vault-path=/home/me/notes --placement=dated
#    -> /home/me/notes/2026/08/2026-08-21-<slug>.md

# 3. Slice by topic, keep surrounding sense, drop tool noise.
session-to-vault 0c841e65 --focus=payments --context=3 --filters=no-tool-noise
#    -> only payment-related turns +/- 3 turns of padding, prose only.

# 4. Compress, then render as a deck (external medium: named explicitly, never via auto).
session-to-vault self --format=digest --cast-to=slides
#    -> note (<=500 words) + a deck produced by content-recast.

# 5. Re-cast an ALREADY-SAVED note as a diagram (cast-only mode: runs 0,1,7,8 — skips 2-6).
session-to-vault /home/me/notes/2026/08/2026-08-21-payments.md --cast-to=diagram
#    -> reads the note (marker required), writes 2026-08-21-payments.cast.diagram.svg
#       The note itself is NOT rewritten.

# 6. See what a run would do, publish nothing.
session-to-vault self --cast-to=artifact --dry-run
#    -> reports "would publish artifact" and stops. Nothing is created or uploaded.

# 7. Error cases (fail fast, never silently degrade):
session-to-vault self --scope=focus-only            # -> ERROR: focus-only requires a non-empty --focus
session-to-vault self --cast-to=diagram             # -> ERROR if archify is absent (no silent markdown fallback)
session-to-vault self --focus=nonexistent-topic     # -> NO-MATCH: nothing written, projection reported
session-to-vault note.md --cast-to=html             # -> ERROR if note.md lacks the session_to_vault marker
session-to-vault self                               # -> ERROR if no scanner: names the prerequisite
                                                    #    ("install gitleaks, or pass --scanner=<cmd>")
session-to-vault self --cast-to=slides              # -> ERROR if content-recast is present but its deck
                                                    #    producer is not: wrapper != terminal renderer

# 8. Bring your own scanner.
session-to-vault self --scanner=/usr/local/bin/my-secret-scan
#    -> gate calls it with the temp path; exit 0 = clean, non-zero = hit.
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
- ❌ **Commit before sanitizing.** The gate precedes *any* commit and runs over the **whole staged set** — a
  per-artifact scan-then-write cannot deliver the abort it promises, because the first artifact is already
  written when the second one fails. See § Stage-scan-commit.
- ❌ **Treat a missing scanner as a pass.** No scan ≠ clean. Write nothing and say why.
- ❌ **Claim a medium whose producer is absent.** Probe first; fall back only from `auto`, only to a native
  medium, and only while saying so. An explicitly named unavailable medium is an error, not a substitution.
- ❌ **Stage or commit the note in cast-only mode.** The note already exists and is the *input*; phase 8 commits
  the casts only. Re-writing it is the silent rewrite that mode exists to prevent.

## §Quality Tests (self-dogfood — 6/6)

| # | Test | Verdict |
|---|---|---|
| 1 | **Self-Application** — this skill's own promotion was preceded by a coverage check that found the engine already existed in a personal vault; it was generalized, not re-authored. | ✅ |
| 2 | **Non-Contradiction** — composes `session-fission`/`opera-debrief`/`content-recast`/`archify` without redefining any of them; `narrative` stays a style, never a medium. | ✅ |
| 3 | **Survival** — applied to itself, it advocates preserving the record and parameterizing the destination; it does both. | ✅ |
| 4 | **Bounded-Responsibility** — preservation + presentation only; continuation, next-action and lesson-extraction are explicitly routed elsewhere. | ✅ |
| 5 | **Explicit-Exception** — §0 escape · `--dry-run` · cast-only no-op · the fail-closed external-medium gate. | ✅ |
| 6 | **Utility-Sunset** — §DUED below. | ✅ |

### `skills/skill-writer` 10-item validation checklist (required for new skills)

| # | Item | Verdict |
|---|---|---|
| 1 | Name lowercase, hyphens only, ≤64 chars | ✅ `session-to-vault` (16) |
| 2 | Description specific and <1024 chars | ✅ measured: **972** |
| 3 | Description includes "what" and "when" | ✅ purpose + trigger phrasings + explicit non-uses |
| 4 | YAML frontmatter valid | ✅ parsed with a YAML loader, not eyeballed |
| 5 | Instructions step-by-step | ✅ pipeline 0→8, each phase with kind + action |
| 6 | Examples concrete and realistic | ✅ § Examples — 6 working invocations + 4 error cases |
| 7 | Dependencies documented | ✅ § Producer availability (what ships, what does not, transitive probe) + the § Sanitize Gate scanner prerequisite (`gitleaks`, or `--scanner`) |
| 8 | File paths use forward slashes | ✅ throughout |
| 9 | Skill activates on relevant queries | ✅ 8 triggers, EN + PT |
| 10 | Agent follows instructions correctly | ⏳ **pending first dogfood cycle** — deliberately not claimed by this PR (`dogfood_status: pending-first-cycle`) |

Item 10 is the one item a PR **cannot** self-certify: it requires a real run. Marking it green here would be
precisely the theater this repo's own gates exist to catch.

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
| 0.1.0 | 2026-08-21 | Promotion — generalized from a personal-vault protocol into a vault-agnostic community skill. The engine (pipeline 0→8, parameters, cast) lives here; vault-specific placement/routing stays in the consuming vault as configuration. Adds `--vault-path`/`--placement` (nothing hardcoded), the `--cast-to` medium axis with its fail-closed external gate, and cast-only mode. **Hardened pre-merge from PR review** (4 findings, all valid): sanitize promoted from a positional phase to the § Sanitize Gate invoked before *every* write (a phase-6 scrub could not inspect a phase-7 cast); §0's BEING > Rules escape explicitly exempted from safety gates (it previously licensed skipping the secret scrub); cast-only mode corrected to collapse 0→6 and run only phase 7 (re-running persist would be the silent rewrite the mode exists to prevent); § Producer availability added — `archify` and the host `Artifact` tool are **not** bundled, so `auto` probes before selecting and an explicitly named unavailable medium is an error, never a silent substitution. **PDCA round 2 (CodeRabbit, 13 findings — 12 applied, 1 already closed):** `focus-only` without `--focus` now fails fast; the three tool-block states made explicit (default collapses, `no-tool-noise` drops, `raw` stays verbatim); `--dry-run` gated against **all** external producers (a dry run must never publish); § Path safety confines every resolved path beneath `--vault-path` (absolute/traversal/symlink-escape rejected); § Note identity defines the frontmatter marker + idempotency fields that make a note a valid cast-only source; § Empty projection forbids writing an empty record and requires a self-auditing note; `para` demoted to a **delegated** mapping (hardcoding `projects/`/`journals/` was the very coupling this promotion removes); `Artifact` declared in `allowed-tools`; ISO 8601 mandated for all persisted dates; § Examples added (6 invocations + 4 error cases); the `skill-writer` 10-item checklist recorded with item 10 honestly pending. **PDCA round 3 (Codex, 2 findings, both applied):** the § Sanitize Gate now **names its scanner** (`gitleaks`, this repo's own CI scanner) with a prerequisite, a `--scanner=<cmd>` override, an explicit exit-code contract and a render-to-temp → scan → move procedure — a fail-closed gate that named no scanner was not fail-closed but *unsatisfiable*, aborting every export; and § Producer availability now probes **transitively to the terminal renderer** — `content-recast` ships here but only *delegates* slides/PDF/NotebookLM downstream, so a present wrapper with an absent renderer yields handoff instructions, not an artifact, and must never be recorded as a written cast. **PDCA round 4 (Codex, 1 finding, applied):** per-artifact scan-then-write could not deliver the promised "a hit aborts the note *and* every cast" — once the note (or an earlier cast) had passed its own gate it was already persisted, and an already-published external cast cannot be withdrawn at all, so the guarantee was false by construction. Replaced with **§ Stage-scan-commit**: render every output into private staging, scan the **whole set**, and commit only if all-clean — local sinks first, external sinks last and one at a time (publication is irreversible, so it is the final act). On a hit nothing was ever committed, so there is nothing to roll back — the only atomicity actually achievable — and the residual limit is stated rather than glossed (with several external sinks, an earlier publication stands if a later one fails; the contract is "nothing is published unless everything scanned clean", not "everything can be undone"). This split staging from committing, so the pipeline renumbered **0→7 ⇒ 0→8** and cast-only became **0·1·7·8** (skipping 2→6); earlier entries in this row describe the pre-renumber numbering. |

---

*Session to Vault Skill v0.1.0 (Fonógrafo) | session-lifecycle family | Claude-Orch-Prime-20260821-047a | 2026-08-22T00:36:11Z*
