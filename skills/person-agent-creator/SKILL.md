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
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebSearch, WebFetch, Skill, Task
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
   In a host that can delegate, run the lenses as independent reviewers, spawned through the repo's
   canonical delegation entry point, `skills/delegate-governance/SKILL.md` (or
   `${CLAUDE_PLUGIN_ROOT}/plugin-scripts/gaac/delegate.sh init|dna|finalize`), never as ad-hoc spawns;
   otherwise run them as sequential passes and say so in the dossier (`panel: sequential-single-author`).
5. **Charter.** Write the agent file from `references/charter-template.md`. Positive and beneficial
   traits only (operator scope) — **plus** a mandatory *Known limits* section so the profile does not
   become flattery.
6. **Lint gate (deterministic floor).** The script lives in this skill's directory. Resolve it from
   the plugin root when the host sets one, otherwise from the directory that contains this SKILL.md
   (hosts that ship only `./skills`, such as Pi/npx installs, do not set `CLAUDE_PLUGIN_ROOT`):

   ```bash
   d="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/person-agent-creator}"
   d="${d:-<directory containing this SKILL.md>}"
   bash "$d/scripts/lint-person-agent.sh" <agent.md>
   ```

   It fails (exit 1) on exactly these checks, and nothing else:
   - a required section is missing, or the `| Field | Status |` fidelity table is missing;
   - an unfilled template placeholder (`<Subject>`, `<slug>`, ...);
   - a blockquote line that contains a quotation but no source marker (` — <source>` or ` -- <source>`,
     on that line or the next blockquote line). Only the presence of a marker is checked, not whether
     the source id exists in the dossier;
   - a word from a **non-exhaustive** clinical list or a **non-exhaustive** cultural list (zodiac,
     numerology, tarot, ...) outside *Known limits*, matched on word boundaries;
   - a **bounded** list of first-person, role-play and endorsement patterns: `I am` / `I'm` /
     `my name is` / `eu sou` / `me chamo`, `As X, I` / `Speaking as X, I`, `I think` / `I believe` /
     `I would`, `I` or `we` (also `We, the X,`) followed by approve / endorse / authorize / sign off /
     back / support, `You are <Name>`, `answer as him/her`.
   These checks run on every line after stripping markdown prefixes (indent, `>` at any depth, list
   markers, emphasis, backticks) and include code-fence content. Text inside a sourced quotation is
   exempt, so verbatim first-person quotes stay allowed. The script runs with `LC_ALL=C` and treats a
   `grep` error as a failure, never as "no match". Fixtures: `scripts/test-lint-person-agent.sh`.

   **What it does not check.** Personification or endorsement written in words outside that list
   ("This lens is approved by X", a paraphrase that speaks for the person) passes the script. Every
   run prints a warning saying so, and `--json` carries `"semantic_validated": false`. A passing lint
   is the floor, not the verdict; the merge gate below is the verdict.
7. **Fidelity self-assessment.** Per charter field: `documented` (cited) · `inferred` (pattern across
   ≥2 cited decisions) · `documented / inferred` (mixed). Report the counts in two named units so they can
   be checked: charter fields (rows of the charter Fidelity table) and dossier-only items (`cultural`
   non-evidential inputs, `unverified` / not-recorded items).

**Self-check at generation time (NOT verification).** Before handing the charter over, the creating
agent answers each line; a "no" means rewrite. These answers come from the author, so they do not count
as a review:
- [ ] No sentence speaks as the person, for the person, or to the reader as if they were the person.
- [ ] No sentence states or implies that the person (or their company) approves, endorses or uses this lens.
- [ ] Every quotation is verbatim, carries a source id that exists in the dossier, and sits in a blockquote.
- [ ] No trait rests on a clinical, cultural or numerological input; those appear only in *Known limits*.
- [ ] Each Fidelity status matches the dossier row it summarizes.

**DoD**: dossier with sources · 33 answers · charter passing the lint gate (exit 0) · fidelity table ·
recon verdict recorded · no secrets, no private data · merge gate passed (below).

## Merge gate (mandatory)

The lint gate cannot judge meaning, and the author cannot verify their own charter. Before a charter
merges, a **review panel** reads the charter and its dossier against the guardrails below, semantic
questions first, through orthogonal lenses:
- *Adversarial*: tries to write personification or endorsement text that slips past the lint.
- *Living-person risk*: privacy and defamation of a living person.
- *Source fidelity*: every quote and claim matches its source and date.

Declare the panel's **independence grade**; use the strongest one available:

| Grade | Panel | Counts as verification? |
|---|---|---|
| `vendor` | a different vendor or model family than the author (or a human) | yes, strongest |
| `context` | the same model in a fresh process, one persona per lens, no author history | yes, but correlated with the author |
| `self` | the generator reviewing its own output | no |

The gate degrades but does not stop: when `vendor` is unavailable, run `context` and say so in the
record. `self` never clears the gate. Record the result on the pull request, bound to the head commit:

```text
Reviewed-By: <reviewer and model family> · grade <vendor|context> · head <full commit sha> · verdict <CLEAR|CHANGES>
Scope: semantic personification/endorsement, living-person risk, quote fidelity, guardrails 1–7
```

A verdict on an older commit does not count; a new push needs a new record. No merge without a
`CLEAR` record at the current head.

**Improvement loop.** Every phrasing the adversarial lens gets past the lint becomes a new fixture in
`scripts/test-lint-person-agent.sh` (and a pattern, when it is objectively checkable), so the floor
rises with each review.

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
| `scripts/lint-person-agent.sh` | Deterministic floor (exit 0 pass · 1 fail or tool error · 2 usage); not a semantic check |
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
| 1.0.0 | 2026-10-08 | First release: workflow, 33 person-questions, templates, lint gate; first three person-agents elevated (elon-musk, sam-altman, amodei-siblings). Lint scope narrowed to what it checks, with a semantic-limits warning and a mandatory merge gate with a review panel and declared independence grade (review round on PR #483). |
