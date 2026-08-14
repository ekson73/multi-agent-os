# Gauntlet target — the maos skill corpus

> Rendered by `refine-braindump-to-prompt --architecture=gauntlet-loop`, with the operator naming
> **maos itself** as the target (recursive dogfood). This file is the **artifact**; it is not armed.
> See §Budget — the loop is refused until a ceiling exists.
>
> Signed: **Claude-Doc-ef60-325** · rendered `2026-08-14T22:03Z` · revised `2026-08-14T22:58Z`

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

**What is gated today, stated precisely** (`tests/validate-plugin.sh`, read not assumed):

| Check | skills | agents | commands |
|---|---|---|---|
| artifact file exists | ✅ | ✅ | ✅ |
| frontmatter **parses as YAML** | ✅ | ✅ | ✅ |
| `name` / `description` **present** | ❌ **not checked** | ✅ | ✅ |
| quality vs an external reference | ❌ | ❌ | ❌ |

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
| `bar_is_machine_verifiable` | **hybrid (not pure-D)** | **D** frontmatter parses · **T** description length, body word-count, disclosure-marker count · **J** blind A/B on clarity |
| `critic_is_independent_of_builder` | **partial — see below** | separate invocation without build history; the tag check is a *label* check, not a context check |
| `evidence_is_directly_inspectable` | ✅ | both sides are readable files; the A/B is literal |
| `long_loop_licensed` (**policy**) | ✅ | a deterministic floor exists ⇒ the profile budget *may* apply |
| `run_armed` (**this run**) | ❌ | caps unset ⇒ refused. Policy-licensed ≠ armed; the two are tracked separately on purpose |

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
frontmatter fields, description length, body word-count, disclosure-marker count).
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
    D  frontmatter parses as YAML                      [validate-plugin.sh, already gated]
    D  `name` and `description` keys present           [NOT gated for skills today —
                                                        this run must check it directly]
    T  description <= the spec's stated limit
    T  body <= 5,000 words
    T  disclosure-markers >= 1 when body > 500 words, where a disclosure-marker is a
       level-2 heading (`## `) or a `<details>` block. Both are countable; "progressive
       disclosure is present" as a vibe is not.
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

EVIDENCE  (directly inspectable — no inference from the build story)
  - both SKILL.md texts, provenance-stripped, side by side
  - validate-plugin.sh output for the candidate
  - the countable T-metrics for both sides
The critic may NOT read the builder's reasoning or this prompt's derivation.

STATE
Persist OUTSIDE the conversation, per skill: every attempt, every refutation, every
T-metric, and the blind-guess outcome (guessed-correctly / could-not-tell). Round N must
know what round N-1 already failed. Sink: a journal under the worktree, committed with
the batch.

STOP
Per piece: exit when 3 consecutive critic rounds produce no new gap, using a DISTINCT
lens set each round (bar-nameability · critic-independence · evidence-inspectability ·
decomposability · stop-rule-presence · blast-radius).
Hard caps: 10 attempts/piece · <COST CEILING — operator-set> · <WALL-CLOCK — operator-set>.
Early exit on gain-stagnation (round-over-round delta below threshold twice).
Unbounded running is REFUSED — if either cap is unset, stop and ask.

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
running is REFUSED — if either cap is unset, stop and ask."*

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
