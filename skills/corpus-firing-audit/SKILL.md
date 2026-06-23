---
name: corpus-firing-audit
description: |
  Use to audit whether a governance corpus is ALIVE or THEATER — does each
  rule/memory/instruction actually FIRE at a live decision point, or is it
  present-but-dormant? Idempotent, read-only: scans a corpus (e.g. a user-scope
  rules dir + MEMORY/AGENTS/CLAUDE, or a repo's docs/governance) and classifies
  each artifact FIRING / DORMANT-OK / THEATER / STALE via an empirical
  grep-for-live-references test, kind-aware so reference docs and decision-records
  are not mistaken for theater. Detects re-learning (the symptom of non-firing) and
  proposes effectivation — sharpen an existing fire-point > add a new passive rule.
  NOT for testing a rule's self-validity (that is a rule-quality concern), triaging
  a directive braindump (use directive-braindump-triage), or measuring run-level
  SLIs (that is a separate observability concern).
triggers:
  - "are our rules firing or theater?"
  - "audit the corpus"
  - "which rules never fire"
  - "are we re-learning what we already knew?"
  - "find dormant / dead rules"
  - "is this governance alive or dead weight?"
version: 1.0.0
---

# Corpus Firing-Audit — is the governance ALIVE or THEATER?

Audit whether a governance corpus **fires** (gets applied at decision-time) or is
**theater** (present but never applied), then propose the minimal **effectivation**.
Operationalizes the lesson *"re-learning is the symptom of a corpus not firing →
sharpen an existing fire-point > add the Nth passive rule"*.

**Canonical output (single file):** a firing-audit ledger — default a user-scope
audit path (e.g. `~/.claude/audit/corpus-firing-audit.md`) for a user-scope corpus,
or `<repo>/docs/governance/corpus-firing-audit.md` for a repo corpus.
**Why:** a rule/memory that never FIRES is a dead file — you keep **re-learning what
you already recorded**. This audit surfaces non-firing governance + the cure.

---

**Input:** none (full corpus scan). Optional arg = a path/glob that **narrows** the
audit to a subset; idempotency + the firing contract still apply.

## Distinct-from-siblings (DRY — composes, never duplicates)
- A **rule-quality / self-validity** check tests whether a rule is internally well-formed → this tests whether it **actually fires**. Validity ≠ firing.
- A **run-level observability / SLI** measure tracks success/rework/rollback over runs → this is a **static corpus sweep** of firing-vs-theater.
- **`directive-braindump-triage`** (sibling skill) triages a **braindump file** → this audits the **standing corpus**.
- A **recon-before-assume** step (read-only environment/corpus probe) is the recon fire-point — used in P0, not redefined here.
- A **dangling-ref / multi-repo audit** covers reference integrity → this is the firing / vitality axis.

## Idempotency contract (non-negotiable)
- **Probe before acting** — read the existing ledger's `generated-at` + verdict set first.
- **Update in place** — regenerate the SAME file; never versioned duplicates.
- **Convergence** — no corpus change ⇒ semantically identical ledger (only generated-at differs).
- **Read-only corpus** — the ONLY write is the ledger; never mutate audited governance.

## Steps

**P0 — Recon (read-only).** OBSERVE before assuming. Read any existing ledger.
Inventory the corpus to audit: for user-scope = a rules dir + `MEMORY.md` +
top-level `CLAUDE.md`/`AGENTS.md`; for a repo = `AGENTS.md` · `CLAUDE.md` ·
`CONTRIBUTING.md` · `docs/governance/*` · `openspec/*`. Capability-detect each path
(`if present`); degrade-not-block on absence. Treat felt-certainty over an unprobed
corpus as a smell (Dunning-Kruger guard).

**P1 — Firing classification.** Per artifact/rule emit a record:

| field | values |
|---|---|
| artifact | path / rule id |
| mandates | one line — what behavior it requires |
| kind | **behavioral-rule** (fires via hook/gate/recon-step) · **decision-record** (ADR — fires by being the honored canonical decision) · **reference/inventory** (map/catalog/subscription — consulted on-demand) · **session-artifact** (scorecard/ledger/continuation-seed — output-by-design) |
| fires | **where** it is actually applied at a live decision point (an invoking hook / gate / recon-step / cross-ref / commit) — or "none found" |
| verdict | **FIRING** · **DORMANT-OK** (insurance/reference/decision-record/session-artifact — present-by-design, low-freq-high-stakes) · **THEATER** (should-fire-but-doesn't) · **STALE** (premise gone) |
| evidence | `grep -ril <token>` refs · last-applied commit · invoking hook/gate |

> **The firing test is kind-aware, not count-only.** Empirically `grep -ril <slug>`
> across hooks/gates/CI/recon/other-rules, BUT classify by the artifact's **kind**
> (column above) before verdict — a low/zero-ref count is only THEATER for a
> **behavioral-rule with a should-apply mandate**. A **reference/inventory** rule
> (refs≈0 by nature — e.g. a subscription map), a **decision-record** (an ADR fires
> by canonical-authority, not a runtime hook), a **session-artifact** (a POC scorecard
> is output-by-design), or an **insurance** rule (low-freq-high-stakes) ⇒
> **DORMANT-OK, never THEATER**. **Counting guard:** derive the ref count from
> `grep -ril <slug> | wc -l` (or `grep -rilq <slug> && fires=1`) — NEVER `grep -cl`,
> which prints per-file match-counts/filenames (not a corpus total) and breaks
> integer comparison.

**P2 — Recon-readiness sub-check.** Confirm the corpus has an **active**
recon-before-assume fire-point and that it itself fires — the canonical example of
effectivation. Cite, don't re-implement.

**P3 — Re-learning detection** (the core symptom). Cross-check recent session
evidence (session journals / memories / recent commits) for lessons being
**re-learned**; each re-learn fingerprints a non-firing rule. Link symptom → the
THEATER artifact in P1.

**P4 — Effectivation proposals** (Eisenhower-ranked). For each THEATER verdict,
propose the cure: **SHARPEN an existing fire-point** (fold the mandate into an active
gate/hook/recon-step/sister-rule cross-ref) **> ADD a new passive rule** (which would
itself be theater). DORMANT-OK stays; STALE → propose qualitative deprecation.

**P5 — (Re)generate the ledger** at the canonical path: a scannable table
(artifact · kind · verdict · fires-where · effectivation) + a top-of-file pulse
(`N firing / N dormant-ok / N theater / N stale`).

**P6 — Verify + brief.** Every **FIRING** verdict MUST cite a real, locatable
reference (no hallucinated firing — recursively the point of this audit). Emit a
short briefing: pulse counts + top theater→effectivation action + delta vs the prior
ledger.

## Guard-rails
Read-only corpus · single write = the ledger · gitleaks-clean · cite-don't-duplicate
(recon · rule-quality · observability · `directive-braindump-triage` · dangling-ref
audit) · DORMANT-OK ≠ THEATER (never flag an insurance/reference/decision-record/
session-artifact as theater — classify by kind first) · counting guard
(`grep -ril … | wc -l`, never `grep -cl`) · inherited context transcribed on any
delegation.

## Provenance
Distilled from a repo-local generator (a `*-audit.prompt.md`) and promoted to a
reusable skill after clearing the dogfood gate (≥2 ratified cycles): cycle 1 on a
user-scope rules corpus (36 rules) + cycle 2 on a repo `docs/governance` corpus
(80 artifacts). Those two cycles produced the kind-aware classification (reference /
decision-record / session-artifact ⇒ DORMANT-OK, never THEATER) and the counting
guard (`grep -ril … | wc -l`, never `grep -cl`) now baked into P1. Designed as a
skill (fires-on-invoke), deliberately NOT a passive rule — adding a passive rule to
fix "rules don't fire" would be the very theater this audits. Cross-link slug:
`[[corpus-firing-audit]]`.
