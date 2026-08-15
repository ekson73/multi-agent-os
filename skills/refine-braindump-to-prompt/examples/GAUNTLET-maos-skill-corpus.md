# Gauntlet target — the maos skill corpus

> Rendered by `refine-braindump-to-prompt --architecture=gauntlet-loop`, with the operator naming
> **maos itself** as the target (recursive dogfood). This file is the **artifact**; it is not armed.
> See §Budget — the loop is refused until a ceiling exists.
>
> Signed: **Claude-Doc-ef60-325** · first rendered `2026-08-14T22:03Z`
> · last revised: **`git log -1 --format=%cI -- <this file>`** — read it, do not copy it here.
> A hand-written `revised` stamp lived here and went stale three times in one session,
> silently, because it duplicates a fact git already tracks authoritatively. The signature
> the review asked for is the agent ID; the timestamp is git's to answer.

## Why this target, from measurement

| Measured (`git ls-files`, 2026-08-14) | Value |
|---|---|
| `skills/*/SKILL.md` | **82** |
| `agents/*.md` | **49** |
| `commands/*.md` | **46** |
| **Total agentic artifacts** | **177** |

> ⚠️ **A first render of this file said 147 (82/28/37) and was wrong.** It counted with
> `ls agents/*.md`, whose glob stops at one directory level; git's pathspec `*` crosses `/`, so it
> also sees `agents/consultants/*.md`. Twenty-one consultant agents and nine commands were invisible
> to the instrument, not absent from the repo. The reviewer that caught it ran the count itself
> rather than reading the claim — which is the only reason it was caught. Recorded because the
> failure shape (an instrument whose *reach* differs from the claim's *scope*) recurs.

**What is gated today** — measured by reading `tests/validate-plugin.sh` *and the script it calls*:

| Check | skills | agents | commands |
|---|---|---|---|
| artifact file exists | ✅ | ✅ | ✅ |
| frontmatter **parses as YAML** | ⚠️ **only if PyYAML present** | ⚠️ top-level only **+ PyYAML** | ⚠️ same |
| `name` / `description` **present** | ✅ **hard fail** | ❌ only *warns* if frontmatter absent; keys never checked | ❌ same |
| quality vs an external reference | ❌ | ❌ | ❌ |

- Skills are the **strictest** class: `validate-plugin.sh:465` calls
  `scripts/validate-skill-frontmatter.sh`, which walks `rglob("SKILL.md")` and `sys.exit(1)` unless
  both `name` and `description` are present.
- Without PyYAML the parse check `warn`s and the build can still PASS (`validate-plugin.sh:301`),
  and `validate-skill-frontmatter.sh` uses `re.search`, not a parser — so "parses as YAML" is
  **conditional on the runner**, not unconditional.
- The YAML-parse gate globs `agents/*.md` / `commands/*.md`, and Python's `*` does **not** cross `/`
  — so **30 artifacts** (21 `agents/consultants/`, 9 `commands/*/`) have never been parsed. Filed
  as **#327**; measured blast of the fix is zero.

> ⚠️ **This table has now been wrong twice, in opposite directions.** The first render claimed
> skills were unchecked for `name`/`description` and agents/commands were checked — almost exactly
> backwards. The second render "corrected" it by reading only the top-level loops in
> `validate-plugin.sh` and never following the call on line 465. Both times the instrument was a
> partial read presented as a full one. The reviewer that caught it named the called script by path.



The validator answers *"is this a well-formed skill?"* It has never answered *"is this a **good**
skill?"* — and "good" is the adjective the profile's `bar-nameability` lens forbids. That gap is the
Gauntlet's native shape: it exists to replace an adjective with a named artifact.

## The bar — verified and PINNED

Both halves were probed with a negative control (a fabricated repo and URL returned 404 under the
same command), then **pinned**, because both sources are mutable and an unpinned bar lets a later
run compare against different content while the target text stays identical:

| Bar | Pin (probed 2026-08-14) |
|---|---|
| `github.com/anthropics/skills` | commit **`f6656c1256d5a8adfa37db9110046ef20bac644c`** (2026-08-13T18:09:54Z) · 17 reference skills |
| `https://agentskills.io/specification` | HTTP 200 · **414,136 bytes** · sha256 `4022d0bd4b9b1d07…` |

A run that finds either pin stale MUST re-probe, re-pin, and record the delta — never silently
compare against whatever is live.

⚠️ **A trap caught by probing.** The repo's `spec/agent-skills-spec.md` is **87 bytes** — not a spec,
a *redirect stub* (`The spec is now located at <https://agentskills.io/specification>`). Naming that
path as the bar would have handed the blind critic a **pointer instead of a specification**, failing
the profile's gate #2 (*cannot observe the true result*). The byte-size was the only tell.

The 17 reference skills: `algorithmic-art` · `brand-guidelines` · `canvas-design` · `claude-api` ·
`doc-coauthoring` · `docx` · `frontend-design` · `internal-comms` · `mcp-builder` · `pdf` · `pptx` ·
`skill-creator` · `slack-gif-creator` · `theme-factory` · `web-artifacts-builder` ·
`webapp-testing` · `xlsx`.

## Verifiability Gate — hybrid, declared honestly

| Conjunct | Verdict | Basis |
|---|---|---|
| `bar_is_machine_verifiable` | **hybrid (not pure-D)** | **D** frontmatter parses · **T** description length, body line-count, linked-supporting-file count · **J** blind A/B on clarity |
| `critic_is_independent_of_builder` | **partial — see below** | separate invocation without build history; the tag check is a *label* check, not a context check |
| `evidence_is_directly_inspectable` | ✅ | both sides are readable files; the A/B is literal |
| `long_loop_licensed` | **❌ FALSE** | the gate is an **AND** (`SKILL.md`): two conjuncts above are *hybrid* and *partial*, and partial is false in a conjunction ⇒ **the economic stop governs, not the profile budget** |
| `run_armed` (**this run**) | ❌ | caps unset ⇒ refused |

> ⚠️ **An earlier render marked `long_loop_licensed` ✅ while marking two of its own conjuncts
> unsatisfied, three rows above.** The governing predicate is literally
> `bar_is_machine_verifiable AND critic_is_independent_of_builder AND evidence_is_directly_inspectable`;
> acknowledging a failed conjunct and keeping the ✅ on the conclusion that depends on it is a
> contradiction the table carried in plain sight. The consequence is not cosmetic: it selects a
> **different stopping rule**.

⚠️ **`bin/convergence-guard` does NOT enforce fresh context, and an earlier render said it did.**
Read: it compares **caller-supplied** brand/axis tags, and its own help states `axis:author` ≠
`axis:reviewer` ⇒ ALLOW. A verifier running inside the builder's own conversation passes by choosing
a different label. It is a **correlated-peer** guard (same brand/axis ⇒ REFUSE), which is real and
useful — and it is not an observation of context.

Independence here therefore rests on a **procedural** control, with the residual named:

- the critic is a **separate agent invocation** that receives ONLY the two provenance-stripped
  files and the T-metrics — never the diff, the build reasoning, or this document;
- `convergence-guard` is still run, for what it *does* catch (correlated brand/axis peers);
- **residual risk, unmitigated**: nothing mechanically proves the critic's context is fresh. The
  control is the narrowness of what it is handed. Claiming more would be the theater this artifact
  exists to refuse.

## The prompt

```text
TARGET
Raise, to the quality bar of Anthropic's own reference skills, every maos skill that HAS a
same-purpose reference among the 17 — measured per skill, never asserted. The candidate
pool is the 82 under skills/*/SKILL.md; the TARGET is the PAIRABLE SUBSET of it, and the
size of that subset is not known until PAIRING runs, so it is not stated here.
  The unpairable remainder is an OUTPUT, not a silence: enumerate it, count it, and report
  it with each skill's domain. Domains like PII masking or session orchestration have no
  counterpart among the 17, and a blind A/B against a reference that does not exist is not
  a weaker measurement — it is not a measurement. An earlier draft claimed the whole
  82-skill corpus as the target while the PAIRING rule quietly dropped the unmatched ones;
  the run would have "finished" against a promise it never attempted.
Out of scope: agents/ (49) and commands/ (46) — see Scope boundary.

TASK
For each skill in scope, produce a diff that closes the largest measured gap between it
and its paired reference. One skill = one independently-judgeable piece.

BUILD-METHOD
A lead agent ranks the in-scope skills by measured gap (deterministic pass first:
frontmatter fields, description length, body line-count, linked-supporting-file count).
Fan out one builder per skill; skills are independent — no verdict entanglement.

Every builder spawn MUST route through the repository's delegation governance:
  skills/delegate-governance/SKILL.md
  plugin-scripts/gaac/delegate.sh init | dna | finalize
A builder spawned outside that entry point does not inherit the required
initialization, DNA and finalization contract, and its output does not count.
Worktree per the Git Worktree Protocol ([C04], ~/.claude/CLAUDE.md); PR per batch.

QUALITY-BAR  (named external artifacts — NOT adjectives)
  1. github.com/anthropics/skills @ f6656c1256d5a8adfa37db9110046ef20bac644c
     — the 17 reference skills, read directly at that commit.
  2. https://agentskills.io/specification — 414,136 bytes, sha256 4022d0bd4b9b1d07…
  Re-probe and re-pin if either has moved; record the delta.

  PAIRING: each candidate is compared against a SAME-PURPOSE reference, chosen by
  domain proximity (an authoring skill -> skill-creator; a document skill -> docx/pdf/
  pptx/xlsx; a UI skill -> frontend-design/canvas-design; a testing skill ->
  webapp-testing; an integration skill -> mcp-builder/claude-api). A cross-domain pair
  lets the critic identify the reference from its SUBJECT MATTER even with provenance
  stripped — which measures domain recognition, not clarity. If no same-purpose
  reference exists for a candidate, that skill is OUT OF SCOPE for this run; record it
  rather than pairing it badly.

  Compliance is per-skill and tri-level, declared explicitly:
    D  frontmatter parses as YAML  [gated ONLY when PyYAML is present on the runner.
       Without it, validate-plugin.sh:301 emits a WARN and the build can still pass,
       and validate-skill-frontmatter.sh uses re.search, not a parser.
       VERIFY FIRST: python3 -c "import yaml". Absent -> parse directly in this run;
       do not report it as gated.]
    D  `name` and `description` keys present           [gated as a HARD FAIL for skills
                                                        via scripts/validate-skill-frontmatter.sh;
                                                        no separate check needed here]
    T  description <= the spec's stated limit
    T  body <= 500 LINES — the pinned reference's own figure
       (anthropics/skills@f6656c12 skills/skill-creator/SKILL.md:90,96 "keep SKILL.md
       under 500 lines"). Anthropic's separate skills-overview page says "<=5k words";
       where two sources disagree, the PINNED one governs, and the divergence is
       recorded rather than silently averaged.
    T  progressive disclosure, per THIS REPO's definition (skills/skill-writer/SKILL.md
       :184-195, :339 — "put advanced details in SEPARATE FILES" such as reference.md,
       examples.md, scripts/, templates/, referenced from SKILL.md):
         count sibling files in the skill directory LINKED from SKILL.md, for the
         CANDIDATE and for its PAIRED REFERENCE. Gap when the reference links >= 1 and
         the candidate links 0. Measured on both sides, like every other T-metric, and
         with no threshold gate — so it runs on every candidate.
       TWO earlier drafts failed here, differently, and both let a monolith through:
       (1) counting `## ` headings and <details> blocks — neither moves material OUT of
       SKILL.md (a heading hides nothing; <details> is visual only, the agent gets the
       source regardless), a proxy invented without reading the definition this repo
       already had; (2) gating on "when body > 500 LINES" while the metric ABOVE requires
       body <= 500 LINES — so the check could only fire on a candidate already failing,
       i.e. it was unreachable, and a 500-line monolith with zero supporting files passed
       "progressive disclosure" untested. Wrong-proxy, then dead-code: the same failure
       twice, which is why the threshold is now the paired reference rather than a number.
    J  BLIND A/B, single success condition:
         the critic, shown the candidate and its paired reference with provenance
         stripped in randomised order, CANNOT reliably say which is Anthropic's.
       Any correctly-named distinguishing gap is a REFUTATION -> another build round.
       Do not restate this in softer words at any point.

CRITIC
A separate agent invocation, receiving ONLY: the two provenance-stripped files and the
T-metrics for both. It receives NEITHER the diff, NOR the builder's reasoning, NOR this
document, NOR any validator output.
  WHY NO VALIDATOR OUTPUT: an earlier draft handed the critic validate-plugin.sh output
  "for the candidate". That single asymmetry destroyed the blind gate, and the leak is
  more direct than asymmetry alone — the script's FIRST output line is the banner
  "Multi-Agent OS Plugin Validation" followed by an absolute path containing
  multi-agent-os, and each pass() line prints the candidate's own skill name. The critic
  would not have inferred provenance; it would have READ it. Running it on both sides does
  not fix this: the reference is not a MAOS plugin, so the validator fails it structurally
  for reasons unrelated to quality — a signal that always condemns one side is a second
  leak, not symmetry. D-level checks therefore move to a PRE-GATE (below); the critic
  judges only what is judgement.
Prompted to REFUTE. It must state which file is the reference and why, or state that it
cannot tell. It may not lower the bar.
Run bin/convergence-guard for what it does catch (correlated brand/axis peers). Note its
limit: it compares caller-supplied labels and cannot observe context freshness.

  NOT RUNNER-ENFORCED — stated, not hidden. A review asked for critic isolation to be a
  runner-enforced contract. It is not, and no primitive in this repo can make it one:
  convergence-guard reads labels the CALLER supplies, so a caller that mislabels a
  context-contaminated critic passes the guard. Isolation here is a PROMPT-level contract
  the invoking agent can violate without detection. Closing it needs a runner that spawns
  the critic itself and controls what enters its context — which does not exist yet.
  Recorded as a known hole rather than described in language that implies a gate.

D-PRE-GATE  (run by the LEAD, before the A/B — never seen by the critic)
The D-level checks are deterministic (f=0), so they are SETTLED before judgement begins,
not offered as evidence during it: run validate-plugin.sh + validate-skill-frontmatter.sh
on the candidate; a FAIL sends it back to the builder and it never reaches the critic.
This keeps the validator's real value (a free, exact gate) without leaking its banner.

EVIDENCE  (directly inspectable — no inference from the build story)
  - both SKILL.md texts, provenance-stripped, side by side
  - the countable T-metrics for both sides
That is the whole list, and it now MATCHES the LENS ASSIGNMENT clause below, which already
said every lens is answerable from "two provenance-stripped SKILL.md texts + the T-metrics".
The two sections had disagreed: one handed the critic a validator dump the other did not
list. Removing it made the document consistent rather than poorer.
The critic may NOT read the builder's reasoning or this prompt's derivation.

STATE
Persist OUTSIDE the conversation, per skill: every attempt, every refutation, every
T-metric, and the blind-guess outcome (guessed-correctly / could-not-tell). Round N must
know what round N-1 already failed.
  SINK: a journal under the worktree, appended ATOMICALLY (write temp + rename) after
  EACH event, BEFORE the next round starts. The batch commit reconciles what is already
  on disk; it is not the moment the state first exists.
  Why not "committed with the batch" alone: an interrupted batch would lose exactly the
  round-to-round history the paragraph above requires — the sink would contradict its own
  stated purpose. An earlier draft of this prompt said precisely that, and the review that
  caught it named the contradiction rather than restating a preference.

STOP  (every term below is measured, not adjectival)

  GAP — the unit of measurement. One gap = one distinguishing feature the critic
  names in a single sentence, recorded verbatim in the journal. The per-round count
  G(k) is the number of gaps the critic named in round k. G(k)=0 means the critic
  stated it could not tell which file was the reference.

  GAP IDENTITY — assigned by the LEAD, never by string comparison. On first record the
  LEAD gives the gap a stable ID (skill + lens + short slug) and the journal carries it.
  Each subsequent round the LEAD marks every OPEN gap closed-or-still-open by INSPECTING
  THE ARTIFACT, not by matching critic prose against the previous round's.
  Why not verbatim text: the critic writes prose and the lens rotates, so the same
  unresolved defect comes back paraphrased — or simply is not revisited next round — and
  never compares equal. A stagnation test keyed on string equality would therefore read a
  builder that keeps failing the SAME defect as steady progress. Identity has to be a
  decision about the artifact, not a diff of two sentences about it.

  EXIT (success): EVERY ONE of the six lenses returned G=0 on its MOST RECENT run.
  Not "no NEW gap" — a critic re-naming the SAME unresolved gap would satisfy a novelty
  test while the skill stays distinguishable. And not "zero for three consecutive rounds"
  either, which an earlier draft used: with a six-lens rotation, three consecutive rounds
  cover only HALF the lenses, so a gap found by lens 0 and never fixed could sit untested
  while rounds 1-3 came back clean on their own axes and tripped the exit. That draft even
  cited "the three exit rounds provably use three distinct lenses" as a STRENGTH — it is
  the proof of the hole: three distinct is three MISSING. A lens that found a gap must be
  re-run and come back zero before exit is available, which makes the rule self-anchoring.
  Consequence, stated plainly: minimum six rounds, since a lens that never ran cannot
  report zero — you may not call a skill indistinguishable on an axis you never tested.

  LENS ASSIGNMENT — round k uses lens (k mod 6) from this fixed order, so the rotation
  reaches every lens and the exit condition above is always eventually satisfiable. Every
  lens is answerable from the critic's PERMITTED INPUTS (two provenance-stripped SKILL.md
  texts + the T-metrics), and each is derived from the pinned reference, not invented:

    0 trigger-completeness  does `description` carry BOTH what it does AND specific
                            when-to-use contexts?              [skill-creator:67]
    1 trigger-assertiveness is the description assertive enough to fire, or passive?
                            (the reference warns skills UNDER-trigger)   [:67]
    2 whentouse-placement   is when-to-use in the DESCRIPTION, or misplaced in the
                            body? ("all when-to-use info goes here")     [:67]
    3 disclosure-layering   body within the line envelope, with advanced material in
                            bundled resources referenced WITH guidance on when to
                            read them?                              [:88-96]
    4 imperative-voice      are instructions in the imperative form?      [:117]
    5 why-over-must         does it explain WHY, instead of heavy-handed MUSTs, and
                            stay general rather than over-fitted to its examples?
                                                                        [:139]

  EVIDENCE required for the exit: three journal entries, consecutive round numbers,
  each recording lens set, G(k)=0, and the critic's verbatim could-not-tell statement.

  STAGNATION (early exit, failure): measured on gap IDENTITY, not on the count.
  A gap is identified by its verbatim recorded text. Exit NOT-CONVERGED when the SAME
  gap is named in two consecutive rounds — the builder was handed it and did not close
  it.
  Counting instead would misfire on the common case: TASK asks each round to close the
  LARGEST gap, so a builder closing one gap while the critic surfaces the next holds
  G(k) constant at 1. A count-based delta reads that steady progress as stagnation.

  GOVERNING CAP: the ECONOMIC STOP, not the profile budget. long_loop_licensed is FALSE
  (see the gate table), so per SKILL.md the cap is convergence-engine's n*.
  And since rho (retained-gap fraction) is not estimable for a prose-clarity loop, cite
  NO round count: use convergence-engine's parameter-free escape — a harness-enforced
  cap plus the stagnation test above, neither of which needs an estimate.

  HARNESS CAP: <ATTEMPTS — operator-set> · <COST CEILING — operator-set> · <WALL-CLOCK — operator-set>.
  Unbounded running is REFUSED — if ANY cap is unset, stop and ask. (No default attempt count is
  rendered: a number here would be profile-derived, and the profile budget does not govern —
  same discipline as the retracted `10 attempts/piece`.)

ESCALATION
Halt and escalate to a human when: a guardrail surface is touched (the Guardrails
section, a guardrail-enforcing rule or hook, the gitleaks allowlist); the change becomes
irreversible; a skill's semantics (not its form) would change; a candidate has no
same-purpose reference; or the caps above are exhausted.
Form may be raised autonomously. Meaning may not.
```

## Budget — why this file is NOT armed

The profile marks `cost_ceiling` and `wall_clock` as **`operator-set; REQUIRED before any long run`**,
with no defaults ("unbounded time is not a budget"). The rendered `STOP` restates it: *"Unbounded
running is REFUSED — if ANY cap is unset, stop and ask."* — where "ANY cap" now includes the
ATTEMPTS cap (round-5 symmetry: a default there would be an invented number).

Asked; unanswered at render time. The loop is refused **by its own contract**, not by hesitation.
**Three** slots remain, and only the operator can fill them:

```text
<ATTEMPTS>       — required (max build attempts per skill; the document renders no default —
                   a default here would be an invented number, the class round 5 retracted)
<COST CEILING>   — required
<WALL-CLOCK>     — required
```

The attempts row was missing for one round: `STOP` had been tightened to refuse on ANY unset cap
while this form still offered two fields, so an operator who filled the form exactly as printed
would have been refused by the prompt for a slot it never asked them for. A fill-in form that
cannot satisfy its own gate is worse than no form — it reads as completable.

Recommended first run once a ceiling exists: **a 3-skill pilot**, ranked by the deterministic gap
pass and drawn from domains with a clear same-purpose reference. Rationale — if the blind A/B fails
to discriminate, that is discovered across 3 pieces rather than 82, and the run yields a playbook
before any fan-out multiplies a harness defect.

## Scope boundary

`agents/` (49) and `commands/` (46) are **out of scope**. The bar named here is a *skill* bar;
Anthropic's reference corpus contains no comparable agent or command artifacts, so extending it to
them would name a reference that does not exist — the same failure the `spec/` stub nearly caused.

Individual skills with no same-purpose reference are likewise out of scope for a given run, and are
recorded rather than paired badly.
