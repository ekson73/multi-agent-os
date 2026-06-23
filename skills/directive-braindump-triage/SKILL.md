---
name: directive-braindump-triage
description: |
  Use to triage an operator directive-braindump (a scratch of mixed directives, e.g.
  a prompt-aux / *.braindump.md) against the auto-loaded corpus (rules · memories ·
  tickets) so a future amnesic agent executes ONLY the verified residual and never
  re-processes what is already done. Idempotent: recon-first → decompose into atomic
  directives → classify each DONE/OPEN/DROP-EXPLICIT/COVERED + the artifact that fulfills it →
  inter-dependency DAG → Eisenhower residual roadmap, emitted as a provenance ledger.
  Cures the re-learning anti-pattern: never re-execute an already-satisfied directive.
  NOT for auditing whether standing rules fire (use corpus-firing-audit — the
  firing/vitality axis) or for adopting an external tool (use agentic-tool-intake).
  Cross-vendor AAIF.
triggers:
  - triage this braindump
  - process this prompt-aux
  - what in this scratch is already done?
  - did we already do these directives?
  - triagem deste braindump
  - o que aqui já foi feito?
  - braindump provenance ledger
version: 1.0.0
---

# Directive-Braindump Triage — execute only the residual

Given an operator directive-braindump (a `*.braindump.md` / `prompt-aux-N`-style scratch of
mixed directives), produce/update ONE **provenance ledger** recording WHICH corpus artifact
already fulfills each directive — so a future amnesic agent runs only the verified residual.

**Canonical output (single file):** a themed provenance ledger — default in the host's
planning/scratch dir as `<theme>-provenance-ledger.md`; repo-scoped if the braindump is repo-bound.
**Why:** a braindump without a provenance ledger gets **re-learned**. A directive without
application is a dead file. This is the cure for "we keep re-learning what we already knew."

---

**Input:** path to a directive-braindump file. Optional arg = an existing ledger path to update.

## Distinct-from-siblings (DRY — composes, never duplicates)

- **`agentic-tool-intake`** (skill) decides whether to ADOPT an external tool → this classifies
  operator **DIRECTIVES** already in hand. Different input, different verdict space.
- **`protocols/agentic-tool-lifecycle.md`** (protocol) governs distill→promote of tools → this
  triages intentions, then *feeds* the lifecycle when a residual warrants a new tool.
- **`corpus-firing-audit`** (sibling skill): audits the **standing corpus** for firing-vs-theater
  (artifact → application). This triages a **braindump file** (directive → artifact). Opposite
  traversal; pair the two skills, never merge them.
- **anti-theater grounding** (host rule, if present) → used in P6 (no hallucinated provenance).

## Idempotency contract (non-negotiable)

- **Probe before acting** — read the braindump's `PROCESSED` banner (if any) + any existing
  ledger FIRST; never re-run a triage that already converged.
- **Update in place** — append/refresh the SAME ledger; never spawn a parallel doc (DRY).
- **Convergence** — no corpus change ⇒ semantically identical ledger (only generated-at differs).
- **Read-only corpus** — the ONLY writes are the ledger + a `PROCESSED` banner on the source
  braindump. Never re-execute already-DONE directives.

## Steps

**P0 — Recon (read-only, observe-before-assume).** OBSERVE before assuming: read the braindump;
probe the auto-loaded corpus (the host's rules dir, memory index, tickets via the project
tracker / MCP) AND the environment relevant to the directives. Read any existing ledger. Treat
felt-certainty over an unprobed corpus as a smell (a Dunning-Kruger guard), not a signal.

**P1 — Decompose + harmonize.** Restate the braindump as N atomic directives — edited, corrected,
expanded — grouped by ontological family (e.g. Posture · Validation · Provenance · Governance ·
Meta-learning · Strategy). This is the polished canonical form; preserve the raw scratch as source.

**P2 — Classify × provenance.** For each directive emit: `status ∈ {DONE · OPEN · DROP-EXPLICIT ·
COVERED}` + **the artifact that fulfills it** (rule / memory / ticket / PR / commit / skill).
**Anti-re-learning rule:** a directive already satisfied by the corpus is DONE, not pending.
Session meta-directives (slash-commands, `--auto-merge`, motivational asides) are EXCLUDED —
they are execution authorizations, not reusable content.

**P3 — Inter-dependency graph** (mermaid DAG): recursive · sequential · inter-dependent ·
independent · blocked. Mark the critical residual chain + transversal/independent items.

**P4 — Residual roadmap (Eisenhower 2×2).** ONLY the verified-residual gets a disposition:
Q1 ticket+execute · Q2 ticket+schedule · Q3 ticket+delegate · Q4 note-or-drop-explicit.
Drop decisions are logged with rationale (drop-explicit > unpaid memory-debt).

**P5 — Anti-re-learning note + persist.** Record the meta-lesson (provenance + sharpen-an-existing-
fire-point > add a passive rule). Stamp the source braindump with a `PROCESSED <YYYY-MM-DD>`
(ISO-8601) banner pointing at the ledger.

**P6 — Verify + brief.** Confirm every "DONE" cites a real, locatable artifact (no hallucinated
provenance — every claim points at something a reader can open); emit a short briefing
(N DONE / OPEN / DROP + the residual next-action).

## Example (input → output)
**Input:** `directive-braindump-triage docs/scratch/posture.braindump.md`

**Output** — a provenance ledger (excerpt):
```
# posture — provenance ledger (generated 2026-06-22)
| # | directive (atomic)             | status        | fulfilling artifact            |
|---|--------------------------------|---------------|--------------------------------|
| 1 | recon the env before assuming  | DONE          | rule: <env-recon rule>         |
| 2 | stamp agent-authored tickets   | DONE          | rule: <ticket-provenance rule> |
| 3 | add a posture self-test        | OPEN          | — (residual → Q2 ticket+sched) |
| 4 | rename every internal variable | DROP-EXPLICIT | rationale: out-of-scope, low value |
Residual: only #3.  DAG: #3 independent.  Eisenhower: Q2.
```
Re-running with no corpus change ⇒ the same ledger (only the `generated` date differs) — the
idempotency contract. Directives #1/#2 are never re-executed (already DONE); #4 is logged-dropped,
not silently abandoned.

## Guard-rails

Recon-before-assume · Dunning-Kruger guard · never re-execute already-DONE directives · escalate
to a human only post-recon when genuinely beyond reach · stamp any created ticket as agent-authored ·
auto-merge only within the host's standing-authorization guardrails · transcribe the delegation
heritage (see `protocols/agent-delegation.md`) on any delegation · keep outputs secret-clean.

## Provenance

Genesis: distilled as the *form-correspondent* of an operator agentic-posture braindump in a
downstream project's prompt-library, then elevated to a user-scope skill. Promoted here via the
`protocols/agentic-tool-lifecycle.md` distill→promote path after clearing the **ADR-005
≥2-dogfood-cycle gate** — two ratified cycles (the triage analyses of an agentic-posture braindump
and a repo-inventory braindump). Cross-link slug: `[[directive-braindump-triage]]`.
