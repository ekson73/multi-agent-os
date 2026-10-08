---
name: person-agent-creator
version: "1.0.0"
description: |
  Create or elevate a PERSON-AGENT: a thinking-archetype agent modeled on the publicly documented
  thinking, decisions, style and track record of a real (often living) person — never an impersonation.
  Runs a fixed workflow: DRY recon → research dossier (sourced, per-axis) → 33 Socratic person-questions
  → multi-lens (MoE) synthesis → charter (agent file) → deterministic lint gate → fidelity self-assessment.
  Use when asked to "create a person-agent for X", "model how X thinks", "elevate the X consultant
  archetype", "build a collective-mind agent for X and Y", or "criar um person-agent".
  Does NOT write first-person voices, invent quotes, diagnose people, or use private data.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebSearch, WebFetch, Skill
---

# person-agent-creator

A person-agent answers one question: *"How would someone who reasons the way X has publicly reasoned
approach this problem?"* It is a **lens**, attributed and bounded. It is not X, does not speak as X,
and does not claim X's endorsement.

## When to use / not use

| Use | Do not use |
|---|---|
| New person-agent for a public figure with a published record | Private individuals, or anyone without a public record of decisions |
| Elevating a thin archetype (e.g. `agents/consultants/*.md`) into a sourced person-agent | Role-play, fan fiction, chat "as" the person |
| A **collective mind** (founding pair, team) whose public record is joint | Generic role personas (use `forge` / the persona catalog) |

## Workflow (DoR → steps → DoD)

**DoR**: subject named · purpose of the lens stated (what decisions should it help with) · web reachable
(or an existing source pack supplied).

1. **Recon (DRY first).** `Grep` `agents/` (incl. `agents/consultants/`), `skills/`, the cross-link
   slugs. If an archetype exists, the default verdict is **ELEVATE in place** (same slug, MAJOR version
   bump, references keep resolving). Record the verdict and the evidence in the dossier header.
2. **Research dossier.** Fill `references/dossier-template.md` for the subject. Every factual line
   carries a source and a date; uncertain items are marked `unverified`, never
   smoothed over. Axes: name · name meaning/etymology · persona (public) · skills/qualifications ·
   education (published sources only) · timeline · creations/companies/achievements · public
   personality, attitudes, characteristics · M.O. (decision patterns) · active minds (primary vs
   secondary) · books/biographies/interviews · expert-drawn profile (published, attributed) ·
   cultural-semiotic inputs (zodiac, numerology, name semiotics — **labeled non-evidential**) ·
   self-declared beliefs (only if publicly self-declared).
3. **33 Socratic person-questions.** Run `references/person-33q.md` against the dossier. Each answer
   determines one charter field; answers live in the dossier.
4. **MoE synthesis (multi-lens panel).** Synthesize the charter through five lenses; each lens may veto
   a claim it cannot ground:
   - *Biographer* — is every claim in the record? dates, sources, conflicts between sources.
   - *Cognitive-style analyst* — which reasoning moves recur across decisions (not one-off anecdotes)?
   - *Talent assessor (HR / head-hunter lens)* — competencies stated as observed behaviors, with evidence.
   - *Cultural-semiotic reader* — name meaning, cultural framing; never allowed to drive behavior.
   - *Ethics and fidelity critic* — impersonation, flattery, invented voice, clinical labels, private data.
   In a host that can delegate, run the lenses as independent reviewers; otherwise run them as
   sequential passes and say so in the dossier (`panel: sequential-single-author`).
5. **Charter.** Write the agent file from `references/charter-template.md`. Positive and beneficial
   traits only (operator scope) — **plus** a mandatory *Known limits* section so the profile does not
   become flattery.
6. **Lint gate (deterministic).** `bash skills/person-agent-creator/scripts/lint-person-agent.sh <agent.md>`.
   Fails on: missing required sections · first-person identity claims ("I am <name>") · a quote without
   a source marker · missing fidelity table · clinical-diagnosis vocabulary applied to the subject.
7. **Fidelity self-assessment.** Per charter field: `documented` (cited) · `inferred` (pattern across
   ≥2 cited decisions) · `cultural` (non-evidential input). Report the counts.

**DoD**: dossier with sources · 33 answers · charter passing the lint gate (exit 0) · fidelity table ·
recon verdict recorded · no secrets, no private data.

## Guardrails (non-negotiable)

1. **No impersonation.** The agent never says it is the person, never writes in the person's first-person
   voice, never claims to represent or be endorsed by them.
2. **No invented quotes.** Verbatim only, with source and date. When the original wording cannot be
   verified, paraphrase and label it as a paraphrase of a named source.
3. **No remote diagnosis.** Psychiatry, psychoanalysis and neuroscience are used only as published
   descriptive vocabularies, attributed to their sources — never as a diagnosis of a living person
   (Goldwater-rule principle). No personality-type labels assigned to the subject unless the subject
   published them.
4. **Cultural inputs are non-evidential.** Zodiac, numerology, name semiotics, spirituality frameworks
   (e.g. Vedanta, gnosis) may appear as labeled cultural context; they never set a trait or a behavior.
5. **Public record only.** Education and history from published biographies or official sources; no
   health, family or finance details beyond what the subject or major biographies published.
6. **Positive scope with honesty.** The operator asked for positive and beneficial traits; the
   *Known limits* section states what the lens cannot claim, so the scope stays honest.
7. **Collective minds** state which traits are joint and which belong to one member.

## Disciplines feeding the 33 questions (descriptive lenses, not instruments)

Biology/neuroscience (only published descriptions of cognitive style, never inferred brain states) ·
psychology (Big Five / cognitive-style vocabulary as *description of observed behavior*, attributed) ·
sociology (networks, institutions, cohort) · HR / head-hunter assessment (competency models,
behavioral-event evidence) · psychiatry / psychoanalysis (vocabulary only, Goldwater rule) ·
spirituality / Vedanta / gnosis (only self-declared beliefs; otherwise cultural context) ·
humanoid profile (communication style, decision tempo, risk posture). See `references/person-33q.md`.

## Files

| File | Purpose |
|---|---|
| `references/person-33q.md` | 33 Socratic questions → charter fields → disciplines |
| `references/dossier-template.md` | Research dossier skeleton |
| `references/charter-template.md` | Agent-file skeleton (required sections the lint gate checks) |
| `scripts/lint-person-agent.sh` | Deterministic gate (exit 0 pass · 1 fail · 2 usage) |
| `dossiers/<slug>.md` | One dossier per person-agent |

## Prior art (recon summary)

Internal: `agents/consultants/*` (thin archetypes, v1.0.0), `agents/forge.md` (33Q method reused in
format), `skills/anima` (naming), `skills/research-dossier` (provenance discipline — it renders finished
research, it does not research), `maos:perspective-trio` / `maos:persona-pipeline` (panel mechanics).
External: a systematic survey of persona / role-play agent frameworks was **not** done in v1.0.0
(open item). The design choice that does not depend on it: every field is grounded in a dossier and
reported as documented vs inferred, so fidelity is checkable against the source record.

## Naming

Named via `anima` (`[C-naming]`): system-name **`person-agent-creator`** — agent register, says what it
does, matches the term the request already uses (zero drift). Rejected runner-ups: `person-agent-forge`
(family-aligned with `forge`, but "forge a person" reads as counterfeit, the opposite of the
no-impersonation guardrail); `persona-forge` (same counterfeit reading, and collides with the
persona-pipeline role).

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-10-08 | First release: workflow, 33 person-questions, templates, lint gate; first three person-agents elevated (elon-musk, sam-altman, amodei-siblings). |
