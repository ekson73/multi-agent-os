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
Raise the maos skill corpus (82 skills under skills/*/SKILL.md) to the quality bar of
Anthropic's own reference skills — measured per skill, never asserted.
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
         when body > 500 LINES, count sibling files in the skill directory that are
         LINKED from SKILL.md. Require >= 1.
       An earlier draft counted `## ` headings and <details> blocks instead. Neither
       moves any material out of SKILL.md — a heading hides nothing, and <details> is
       visual only since the agent receives the source regardless. That metric would
       have passed large monolithic skills. It was invented without reading the
       definition this repo already had.
    J  BLIND A/B, single success condition:
         the critic, shown the candidate and its paired reference with provenance
         stripped in randomised order, CANNOT reliably say which is Anthropic's.
       Any correctly-named distinguishing gap is a REFUTATION -> another build round.
       Do not restate this in softer words at any point.

CRITIC
A separate agent invocation, receiving ONLY: the two provenance-stripped files, the
T-metrics for both, and validate-plugin.sh output for the candidate. It receives NEITHER
the diff, NOR the builder's reasoning, NOR this document.
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

EVIDENCE  (directly inspectable — no inference from the build story)
  - both SKILL.md texts, provenance-stripped, side by side
  - validate-plugin.sh output for the candidate
  - the countable T-metrics for both sides
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

  EXIT (success): G(k) = 0 for three CONSECUTIVE rounds.
  Not "no NEW gap" — a critic re-naming the SAME unresolved gap three times would
  satisfy a novelty test while the skill stays distinguishable, contradicting the
  acceptance rule. Consecutive ZERO is the condition.

  LENS ASSIGNMENT — round k uses lens (k mod 6) from this fixed order, so the three
  exit rounds provably use three distinct lenses. Every lens is answerable from the
  critic's PERMITTED INPUTS (two provenance-stripped SKILL.md texts + the T-metrics),
  and each is derived from the pinned reference, not invented:

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
Two slots remain, and only the operator can fill them:

```text
<COST CEILING>   — required
<WALL-CLOCK>     — required
```

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
