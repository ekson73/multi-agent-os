---
name: person-agent-creator
version: "1.0.0"
description: |
  Create or elevate a PERSON-AGENT: a thinking-archetype agent modeled on the documented thinking,
  decisions, style and track record of a subject — a living public figure, a historical figure, a
  fictional or archetypal character, a collective, or a non-human metaphor — never an impersonation.
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

**Why build one.** To support a decision: break a tie between ideas, add a voice to a deliberation or a
council, or act as an advisor or a worked success case — borrowing the best documented behaviors of a
subject whose name, history and archetype carry the meaning the team wants to use. The subject can be
real, historical, fictional, imagined, collective or non-human.

> **Consultative lens, not an authority.** This person-agent gives an advisory view or breaks a tie between
> ideas. It cannot clear a guardrail, a decision reserved to humans, a governance self-edit or any deny-set
> item. It runs on the same model family as the rest of the panel, so its view is correlated with theirs and
> does not replace an independent review. When it advises or breaks a tie, record its evidence and any
> dissent; its vote counts only after that evidence.
>
> Every charter carries this paragraph (it is part of `references/charter-template.md`). To break a tie
> on a pull request, use the review panel with a declared independence grade (`vendor` / `context`, see
> *Merge gate*), not a person-agent.

## When to use / not use

| Use | Do not use |
|---|---|
| New person-agent for a public figure with a published record | Private individuals, or anyone without a public record of decisions |
| Elevating a thin archetype (e.g. `agents/consultants/*.md`) into a sourced person-agent | Role-play, chat "as" the subject, or fan fiction (new text in a character's voice). A fictional character is supported through the `fictional-or-archetypal` class below, which models the documented behavior, not a new voice |
| A **collective mind** (founding pair, team) whose public record is joint | Generic role personas (use `forge` / the persona catalog) |
| A historical, fictional or non-human subject used as an advisory lens or a tiebreak voice | Any gate, approval or human-reserved decision (see the box above) |

## Subject classes

Set `subject_class` in the charter front matter. Every class keeps the base guardrails (no impersonation,
verbatim quotes only with a source, a *Known limits* section); the class adds its own:

| `subject_class` | Extra guardrails | *Known limits* must say |
|---|---|---|
| `living-public` | All the strict rules below; public record only; no remote clinical labels | The lens is not the person, holds no private reasoning, and is dated (as-of) |
| `deceased-historical` | Primary or scholarly sources for every claim; apocryphal quotes flagged (many famous lines are) and never presented as the subject's words; no fabricated quotes; no defamation; public-domain texts may be quoted verbatim with a source | Historical context differs from today; which apocryphal material was excluded |
| `fictional-or-archetypal` (RBAD category 6) | Labeled as fictional; the canonical source (the work, edition, chapter) is cited; intellectual property and trademarks apply: use the archetype and its behavior, do not reproduce protected text; quotations only verbatim with a source (public-domain works are safest); labeled literary analysis may use clinical words. This is the supported path for fiction; writing new text in a character's voice (fan fiction) stays out of scope | The behavior comes from the work, not from a person; rights status of the source |
| `collective` | The collective is kept separate from its members: nothing is attributed to one member without a source naming that member; every member follows the rules of their own class | Which traits are joint and which belong to one member |
| `non-human-or-abiotic` | Declared as an analogy or metaphor; no anthropomorphic claim (intent, feeling, agency) stated as fact | It is a metaphor; the behaviors are human readings of the subject |

The class is declared by the author, so it never switches a check off. The clinical-vocabulary check
runs for every class; a `fictional-or-archetypal` charter may use clinical words only on a line that
starts with `Literary analysis:`, and a `non-human-or-abiotic` charter only on a line that starts with
`Metaphor:` or `As a metaphor,`. Those two classes must also state why they are in that class, on a line
`Class basis: <the work and its creator, or the metaphor> (S<n>)` citing a dossier source id. Whether a
labeled line is really about a character or a metaphor, and not about a real person, is semantic: the
merge gate decides it, and a change of `subject_class` is a finding for the panel (see *Merge gate*).
First person, role-play and unsourced quotes fail for every class: an unsourced line in a character's
voice is still fabrication.

**Example — tiebreak in a council.** Two designs tie 2–2. The facilitator asks a
hypothetical `river-current` lens (`non-human-or-abiotic`) for an advisory vote:

> *Lens vote (advisory): design B.* Rationale: B routes around the legacy dependency instead of
> removing it first, matching this lens's behavior "take the path of least resistance that still
> reaches the sea" (charter, *Method*; a metaphor, not evidence). Evidence: B needs 2 changed services,
> A needs 5 (design docs, section 3). Dissent recorded: one member prefers A because it removes the
> dependency for good. The vote breaks the tie between ideas only, after the evidence is on record; the
> security review and the human sign-off still apply.

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
3. **33 Socratic person-questions.** Run `references/person-33q.md` against the dossier. Each question
   names where its answer lands: a charter section (the agent reads it) or a dossier section (the
   record behind it). All answers are also listed in dossier §5.
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

   It fails (exit 1) on these checks, plus any internal tool error, and nothing else:
   - `subject_class` is missing from the front matter, is not one of the five classes above, or the
     front matter has no closing `---` (the block ends at the first `---` after line 1; every line of
     it must look like YAML — a `key:`, an indented continuation, a `- item`, a `#comment` without a
     space — so a markdown heading or plain text inside it means the closing line is missing and a later
     body rule closed it, which fails);
   - an HTML comment that opens (`<!--`) and never closes, or a code fence that never closes;
   - a `fictional-or-archetypal` or `non-human-or-abiotic` charter has no `Class basis:` line (outside
     code fences and HTML comments), or that line cites no dossier source id, cites one that is not in
     the dossier, or writes one other than strictly `S<digits>` (a list or `S<a>-S<b>` ranges; `S5a`,
     `s999` and reversed ranges fail); a `Class basis:` line in any other class fails;
   - a source id in the *Source ids* column of the Fidelity table (`S3`, or a range `S1–S7` / `S1-S7`;
     the cell must hold only ids and `,` / `;` separators, so `S 99` or `§3` fails) is not an id of the
     dossier's source table (the table whose header starts with `| id |`, rows outside code fences and
     HTML comments only) named on the charter's `Dossier:` line, or that line or file is missing
     (the path is looked up from the charter's directory upwards; existence only, not what the source
     says), or a cited id is malformed (`S1a`) or a range is reversed (`S7-S1`); ranges are expanded
     only up to the highest dossier id;
   - a section of `references/charter-template.md` is missing: the script reads every `## ` heading of
     the template at run time (the template is the single source of truth; a missing template is an
     internal error), and each must appear as a heading outside code fences and HTML comments (order is not checked, extra
     sections are allowed), and the fidelity table must exist inside `## Fidelity` as the only table
     there, with a `Source ids` column and at least one cited id (a Field/Status header outside the
     section, a second table or a missing column fails: nothing to check is a failure). That is all the
     DoD's "from the template" means for the script; the content of each section is the panel's job;
   - an unfilled template placeholder (`<Subject>`, `<slug>`, ...);
   - a blockquote line with a double-quoted span (straight `"`, curly `“ ”` or `« »`) that has no
     source marker of its own. A span is *sourced* when ` — <source>` or ` -- <source>` follows it
     directly, or when it ends the line and the next blockquote line starts with that marker. Text
     after a same-line marker is the source (a quoted title there needs no second marker). Only the
     presence of a marker is checked on these lines (source ids are checked in the Fidelity table, above). Single-quoted
     text is not treated as a quotation;
   - a word from a **non-exhaustive** clinical list or a **non-exhaustive** cultural list (zodiac,
     numerology, tarot, ...) outside *Known limits*, matched on word boundaries (the clinical list applies to
     every class; the only extra exemption is a line with the class label, `Literary analysis:` for
     fictional and `Metaphor:` / `As a metaphor,` for non-human);
   - a **bounded** list of first-person, role-play and endorsement patterns: `I am` / `I'm` /
     `my name is` / `eu sou` / `meu nome é` / `me chamo`; `As X, I|we` / `Speaking as X, I` (X may
     contain `Mr.`, `Dr.`, ...); `I` / `I'd` + think / believe / feel / would / will / want and `eu`
     + acho / penso / creio / acredito / quero / vou; `I`, `I'd`, `we`, `we'd` (also `We, the X,` and
     `We the X`) followed by approve / endorse / authorize / vouch for / sign off / certify / back /
     support, in present or past tense; `you are <Name>` / `you're <Name>` in any letter case (the
     next word counts when it is capitalized, or lowercase and not a common word, a `-ing`, `-ed` or
     `-ly` word); `answer as him/her/them`; `act as` / `pretend to be` / `roleplay as` / `impersonate` /
     `channel` / `become`, optionally followed by `the`, then a capitalized name (`Act as a consultative
     lens` and `become familiar` pass); the contractions `I've`, `I'll`, `we've`, `we'll` before an
     approval verb. Carriage returns are removed before any check, so a CRLF charter is linted like an
     LF one.
   **One normalization pre-pass, every check on its output.** The script never matches the raw
   markdown. It builds two views. The *structure* view keeps only lines outside code fences (``` or
   ~~~, any length, nested) and HTML comments; only those lines can be a heading, end a section, be a
   `Class basis:` line or a Fidelity row. The *voice* view keeps every line, fences and comments
   included (an agent reads the raw file, so hidden text still reaches the model), joins the soft line
   breaks of a paragraph into one unit (so `I` / `am X` is one sentence), and is what the first-person,
   role-play, clinical and cultural checks read. A unit is exempt from the clinical and cultural checks
   only when every line of it is a structure line inside *Known limits*; text inside a fence or a comment
   is never exempt. A line that starts with a class label is a unit of its own, so a label never covers
   the next line. Headings: up to three spaces, 1–6 `#`, a space, the text; trailing spaces and a
   closing `#` run are trimmed and the text is compared in lower case, and a level-1 or level-2 heading
   starts a new section (a `# X` after *Known limits* ends it). Latin-1 accented letters are folded to
   ASCII and the voice text is lowered, so case and accents change no match (`MEU NOME É`, `Act as Émile
   Zola`), under `LC_ALL=C` and `C.UTF-8` alike. Markdown prefixes are stripped (indent, `>` at any
   depth, list markers, emphasis, backticks); a fence opens only at the start of a line (a backtick run
   followed by more backticks on the same line is inline code), and `<!--` inside inline code does not
   open a comment. Only the double-quoted spans that are sourced (as defined above) are exempt, so a
   verbatim first-person quote stays allowed while an unsourced span on the same line is still checked.
   Every external tool it calls (`grep`, `awk`, `cut`, `tr`, `dirname`, the JSON escape helper) has its
   exit status checked; the helpers that pick the first match use shell expansion instead of `sed`,
   `head` or `cut`. Any tool error is a failure, never "no match", and the fixtures prove it by breaking
   each tool through a `PATH` shim. Fixtures: `scripts/test-lint-person-agent.sh` (rerun them against another script with
   `LINT=<path>`; the script reads `../references/charter-template.md` relative to itself, so an older
   script must be placed in `scripts/` beside this one, or every fixture that should pass fails and the
   count misleads). Tested end to end on 2026-10-09 with three throwaway charters (a historical figure,
   a fictional character quoted from a public-domain text, and a non-human metaphor): all passed, and
   the same charters failed once a fabricated first-person line (or, for the historical one, a clinical
   label) was added.

   **What it does not check (out of scope, kept as passing fixtures).** Personification or
   endorsement in words outside that list ("This lens is approved by X", a paraphrase that speaks for
   the person), other languages than English and Portuguese, look-alike (confusable) letters,
   zero-width spaces inside a pattern, a source id cited outside the Fidelity table,
   whether a source actually says what the charter claims, and single-quoted quotations.

   **Fail-closed forms (the script does not emulate them).** In the voice view every run of spaces,
   tabs and non-breaking spaces is one space, so `I  am X` and a trailing-space soft break are caught.
   A heading line or a Fidelity table row that contains `<!--` fails ("html comment in heading/table
   row"); inside *Known limits*, a setext underline (`===` or `---` right after a text line) or an HTML
   heading tag (`<h1>`–`<h6>`) fails ("unsupported heading form"): rewrite it as an ATX `#` heading.
   `Class basis:` needs at least one valid `S<digits>` id after URLs are removed (an id inside a URL is
   not a citation). In the dossier, a closing fence is a fence line only: a fence run followed by text
   (four backticks then `not-a-closer`) does not close it. Every occurrence is read, not only the
   first: the Fidelity table has exactly one `Source ids` column and one header row; a charter has at
   most one `Class basis:` line (exactly one in the classes that need it, none elsewhere, empty or not);
   an autolink (`<https://...>`) in `Class basis:` is removed whole, so an id inside it, even after a
   `)`, does not count, while an id in a markdown link's text still does.

   **Lint contract.** The lint is a deterministic **floor** against accidental drift and low-effort
   evasion. Deliberate obfuscation and every semantic judgement (personification, endorsement, whether
   a class label is true, flattery) belong to the independent review panel (see *Merge gate*), which
   judges each charter against this contract. A further gap that needs more than a fail-closed cut is
   recorded below as a known limit, not as a new rule.

   **Known limits of the floor (documented, not new rules; the panel decides).** The normalization
   above is the last lint lot for this release; what it does not catch stays a known limit:
   - an escaped pipe (`\|`) inside a Fidelity cell splits the cell, so a valid row can fail;
   - valid YAML that does not look like `key:` in the front matter is rejected (`a.b:`, `"k":`, a
     `...` document end); write plain keys;
   - forms outside the lists and cuts above (other heading or comment tricks, other languages,
     confusable letters) pass; deliberate obfuscation is the panel's job;
   - role-play false positives in plain biography (`Before becoming President of Anthropic`, `He would
     become CEO`, `Post updates in the channel General`, `Never impersonate Dario`) fail; reword them;
   - role-play and endorsement forms outside the bounded list pass: `Be Dario Amodei.`, `You will be
     Dario.`, `Respond as` / `Speak as` / `Answer as Dario`, `Write in the voice of Dario`, `I've just
     approved`, `We all endorse`, and Portuguese plural endorsement (`Nós aprovamos`);
   - a `Literary analysis:` or `Metaphor:` label applied to a real person reclassified as fictional or
     non-human passes when the charter carries a `Class basis:` with a real dossier id: whether the
     class is true is semantic, and a change of class is a panel finding (see *Merge gate*);
   - a YAML comment with a space after `#` in the front matter (`# note`) is read as a markdown heading
     and fails; write `#note`;
   - an id written with a leading zero (`S01`) is read as `S1`;
   - inside *Known limits*, a `---` line right after a list item or a fence is read as a setext
     underline and fails; leave a blank line before it or drop it;
   - an `<h2>` written inside inline code in *Known limits* still fails as an HTML heading;
   - a `<table>` or other HTML tag in prose is reported as an unfilled placeholder;
   - a `mailto:S3@...` address counts `S3` as an id (only `scheme://` URLs and autolinks are removed);
   - a quotation whose source marker sits on the next line (split across two lines) fails;
   - "I am" inside a code example outside a fence fails as first person;
   - a Fidelity header without a trailing pipe is not recognized as the table header;
   - a forced line break inside a pattern, or `[I](url)` link text, is deliberate obfuscation and
     passes the floor; the panel judges it;
   - the mutation proof through `LINT=<path>` needs the older script placed in `scripts/` beside this
     one (it reads the template relative to itself). Every run prints a warning saying so, and `--json` carries
   `"semantic_validated": false`. A passing lint is the floor, not the verdict; the merge gate below
   is the verdict.
7. **Fidelity self-assessment.** Per charter field: `documented` (cited) · `inferred` (pattern across
   ≥2 cited decisions) · `documented / inferred` (mixed). Report the counts in two named units so they can
   be checked: charter fields (rows of the charter Fidelity table) and dossier-only items (`cultural`
   non-evidential inputs, `unverified` / not-recorded items).

**Self-check at generation time (NOT verification).** Before handing the charter over, the creating
agent answers each line; a "no" means rewrite. These answers come from the author, so they do not count
as a review:
- [ ] No sentence speaks as the person, for the person, or to the reader as if they were the person.
- [ ] No sentence states or implies that the person (or their company) approves, endorses or uses this lens.
- [ ] Every quotation is verbatim and complete, or its cut is visibly marked (`[…]`) and the dossier
  says what was left out; it carries a source id that exists in the dossier and sits in a blockquote.
- [ ] No trait rests on a clinical, cultural or numerological input; those appear only in *Known limits*.
- [ ] Each Fidelity status matches the dossier row it summarizes.

**DoD**: dossier with sources · 33 answers · charter passing the lint gate (exit 0) · fidelity table ·
recon verdict recorded · no secrets, no private data · merge gate passed (below).

## Merge gate (mandatory)

The lint gate cannot judge meaning, and the author cannot verify their own charter. Before a charter
merges, a **review panel** reads the charter and its dossier against the guardrails below, semantic
questions first, through orthogonal lenses:
- *Adversarial*: tries to write personification or endorsement text that slips past the lint.
- *Living-person risk*: privacy (only published biography; no health, family or finances),
  defamation, clinical labels (guardrail 3), cultural inputs used as evidence (guardrail 4), flattery
  by omission or by a selectively cut quote, past roles presented as current, and the author's
  conflict of interest with the subject.
- *Source fidelity*: every quote and claim matches its source and date; every quote is complete or
  visibly marked as cut (`[…]`).

Declare the panel's **independence grade**; use the strongest one available:

| Grade | Panel | Counts as verification? |
|---|---|---|
| `vendor` | a different vendor or model family than the author (or a human) | yes, strongest |
| `context` | the same model in a fresh process, one persona per lens, no author history | yes, but correlated with the author |
| `self` | the generator reviewing its own output | no |

The gate degrades but does not stop: when `vendor` is unavailable, run `context` and say so in the
record. `self` never clears the gate. **Exception — conflict of interest:** when the dossier declares a
conflict of interest between the author's model vendor and the subject (e.g. a charter about a
company's founders written by that company's model), `context` is not enough: the gate needs `vendor`
or a human reviewer, and without one it stays on HOLD instead of degrading.

*Policy status:* "`context` counts as verification" and "degrade, never stop" are rules stated by the
operator who commissioned this skill; they are recorded here as awaiting the operator's explicit
acknowledgment on the pull request that first applies them.

How to run a `vendor` reviewer from a shell, when a different vendor's CLI is installed (example with
OpenAI Codex CLI; any other vendor's non-interactive mode works the same way):

```bash
codex exec --sandbox read-only "<review prompt: charter path, dossier path, the three lenses>" < /dev/null
```

Close stdin (`< /dev/null`): without it `codex exec` was observed waiting for more input and never
returning. Read-only sandbox: the reviewer reports, it does not edit. In-host reviewers spawned through
`perspective-trio` or `persona-pipeline` share the author's model, so they count as `context`, not
`vendor`.

Record the result on the pull request, bound to the head commit, with one verdict per lens:

```text
Reviewed-By: <reviewer and model family> · grade <vendor|context> · head <full commit sha> · verdict <CLEAR|CHANGES|HOLD>
Lenses: adversarial <ok|changes> · living-person <ok|changes> · source-fidelity <ok|changes>
Scope: semantic personification/endorsement, living-person risk, quote fidelity, guardrails 1–7
```

A verdict on an older commit does not count; a new push needs a new record. **Reclassification:** any
change of `subject_class` between commits (for example from `collective` to `fictional-or-archetypal`)
is a finding for the panel and needs an independent review of the new class and its `Class basis`, even
when the lint passes: the class is declared by the author and moves which lines the clinical check
exempts. A record that omits a
lens, or marks one `changes`, is not `CLEAR`. No merge without a `CLEAR` record at the current head.

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
   published them. A `fictional-or-archetypal` subject may carry labeled literary analysis instead
   (see *Subject classes*).
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
| `references/person-33q.md` | 33 Socratic questions → where each answer lands (charter or dossier section) → disciplines |
| `references/dossier-template.md` | Research dossier skeleton |
| `references/charter-template.md` | Agent-file skeleton (required sections the lint gate checks) |
| `scripts/lint-person-agent.sh` | Deterministic floor (exit 0 pass · 1 fail or tool error · 2 usage); not a semantic check |
| `scripts/test-lint-person-agent.sh` | Offline fixtures for the lint, incl. the declared out-of-scope cases |
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
| 1.0.0 | 2026-10-08 | First release: workflow, 33 person-questions, templates, lint gate; first three person-agents elevated (elon-musk, sam-altman, amodei-siblings). Lint scope narrowed to what it checks, with a semantic-limits warning and a mandatory merge gate with a review panel and declared independence grade (review round on PR #483). Council round on PR #483: lint checks every template section (new *Revalidation*), exempts only sourced double-quoted spans, ignores fenced code and HTML comments, catches past-tense and Portuguese endorsement, fails on any internal tool error (79 fixtures, proven against the previous script). Operator addendum: subject classes (living-public, deceased-historical, fictional-or-archetypal, collective, non-human-or-abiotic) with guardrails and Known limits per class; the lint requires `subject_class`, scopes the clinical check to real people, and checks that every Fidelity source id exists in the dossier (96 fixtures); a person-agent is an advisory lens, never an authority; tiebreak example. Adversarial round: fences and comments exclude each other and inline code opens neither; required sections read from the template; every external tool status checked (proved with PATH shims); act as / pretend to be / roleplay as <Name> and "he's paranoid" caught (112 fixtures); front matter must close, and reversed, oversized or suffixed source ids fail (119 fixtures, CodeRabbit review 5472633615); the consultative-lens paragraph is in the SKILL, the agent and the charter template. Final adversarial round: the clinical check runs for every class (a self-declared class no longer switches it off; only lines labeled `Literary analysis:` or `Metaphor:` are exempt in their class), fictional and non-human charters need a `Class basis:` line with a dossier id, a change of class is a panel finding, the front matter may not swallow body headings, and `I've`/`I'll`/`we've`/`we'll`, `impersonate`/`channel`/`become`, `act as the <Name>` and CRLF files are handled (141 fixtures; the JSON fixture skips without python3/jq). Second adversarial pass: a backtick inside an open HTML comment no longer exempts a term, glued source ids (`S1S999`) and lowercase ids (`s9`) are checked, accented uppercase Portuguese first person is caught, failed directory or JSON helpers fail the lint, and tool-failure fixtures assert the `lint error` message (151 fixtures). Final lint lot: one normalization pre-pass replaces point rules (structure view without fences and comments, voice view with soft breaks joined, accents folded, headings trimmed and case-folded, H1 ends Known limits); an unclosed comment or fence fails; `Class basis:` only in fictional and non-human charters, outside fences and comments, with strict `S<digits>` ids; Fidelity ids read only from the Source ids column and dossier ids only from the dossier's source table; front-matter lines must look like YAML; residual gaps documented as known limits of the floor (172 fixtures). Last lint lot (round 4): nothing to check fails (one Fidelity table inside `## Fidelity` with a `Source ids` column and at least one id; `Class basis:` needs a valid id outside URLs), setext or HTML headings in Known limits and `<!--` in a heading or Fidelity row fail, whitespace runs collapse in the voice view, a dossier fence closes only on a bare fence line; the lint contract is stated (floor, panel for semantics) (191 fixtures). Round 5: every occurrence is read (one `Source ids` column and one Fidelity header row; one `Class basis:` line; autolinks removed whole), and the remaining false positives are known limits (197 fixtures). Amodei charter: later RSP version dates marked unsourced; dossier answers 1 and 25 attribute the safety commitments to Dario's sources and company policy. Amodei charter: Dario-only traits attributed to Dario; dossier: the RSP is institutional context, not a joint achievement, and the 3.0/3.4 dates are marked unsourced. Each Socratic question names where its answer lands; conflict-of-interest rule needs a vendor or human reviewer; agent loads the skill by name with a path fallback. Unreleased: folded into 1.0.0. |
