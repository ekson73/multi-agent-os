# Gauntlet target — the maos skill corpus

> Rendered by `refine-braindump-to-prompt --architecture=gauntlet-loop` on 2026-08-14, with the
> operator naming **maos itself** as the target (recursive dogfood). This file is the **artifact**;
> it is not armed. See §Budget — the loop is refused until a ceiling exists.

## Why this target, from measurement

| Measured | Value |
|---|---|
| Agentic artifacts in maos | **147** — 82 `skills/*/SKILL.md` · 28 `agents/*.md` · 37 `commands/*.md` |
| What `tests/validate-plugin.sh` gates | **structure** — frontmatter present + YAML-parses, JSON valid, hook exec-bit, token budget |
| What nothing gates | **quality against an external reference** |

The validator answers *"is this a well-formed skill?"* It has never answered *"is this a **good**
skill?"* — and "good" is exactly the adjective the profile's `bar-nameability` lens forbids. That
gap is the Gauntlet's native shape: it exists to replace an adjective with a named artifact.

## The bar — verified, not assumed

Both halves were probed before being named, with a negative control proving the instrument
discriminates (a fabricated repo/URL returned 404 under the same command):

| Bar | Probe result (2026-08-14) |
|---|---|
| `github.com/anthropics/skills` | exists · **169,418** stars · pushed **2026-08-13** · **17** reference skills under `skills/` |
| `https://agentskills.io/specification` | **HTTP 200**, 414,136 bytes |

⚠️ **One trap caught by probing.** The repo's `spec/agent-skills-spec.md` is **87 bytes** — not a
spec, a *redirect stub*: `The spec is now located at <https://agentskills.io/specification>`.
Naming that path as the bar would have handed the critic a pointer instead of a specification,
failing the profile's own gate #2 (*cannot observe the true result*). The size was the tell.

The 17 reference skills: `algorithmic-art` · `brand-guidelines` · `canvas-design` · `claude-api` ·
`doc-coauthoring` · `docx` · `frontend-design` · `internal-comms` · `mcp-builder` · `pdf` · `pptx` ·
**`skill-creator`** · `slack-gif-creator` · `theme-factory` · `web-artifacts-builder` ·
`webapp-testing` · `xlsx`.

Primary comparator is **`skill-creator`** — Anthropic's own skill for authoring skills, i.e. the
most on-point possible reference for a corpus of 82 skills.

## Verifiability Gate — hybrid, declared honestly

| Conjunct | Verdict | Basis |
|---|---|---|
| `bar_is_machine_verifiable` | **hybrid (not pure-D)** | **D** frontmatter parses · **T** description length, body word-count, progressive-disclosure presence · **J** blind A/B on clarity |
| `critic_is_independent_of_builder` | ✅ | fresh context; `bin/convergence-guard` REFUSES a same-context verifier |
| `evidence_is_directly_inspectable` | ✅ | both sides are readable files; the A/B is literal |
| `long_loop_licensed` | ✅ | a deterministic floor exists ⇒ profile budget applies |

The floor is mechanical; the ceiling is judged. This is stated rather than marked ✅, because
calling a clarity comparison "deterministic" would be the theater the skill exists to refuse.

## The prompt

```text
TARGET
Raise the maos skill corpus (82 skills under skills/*/SKILL.md) to the quality bar of
Anthropic's own reference skills — measured per skill, never asserted.

TASK
For each skill in scope, produce a diff that closes the largest measured gap between it
and the bar. One skill = one independently-judgeable piece.

BUILD-METHOD
A lead agent ranks the in-scope skills by measured gap (cheap deterministic pass first:
frontmatter fields, description length, body word-count, progressive-disclosure presence).
Fan out one builder per skill; skills are genuinely independent — no verdict entanglement.
Each piece is gated by a critic before it counts as done. Worktree per [C04]; PR per batch.

QUALITY-BAR  (named external artifacts — NOT adjectives)
  1. github.com/anthropics/skills — the 17 reference skills, read directly.
     Primary comparator: `skill-creator` (Anthropic's own skill-authoring skill).
  2. https://agentskills.io/specification — the AAIF spec (verified reachable, 414KB).

  Compliance is per-skill and tri-level, declared explicitly:
    D  frontmatter parses as YAML; `name` + `description` present   [validate-plugin.sh]
    T  description <= spec limit; body <= 5k words; progressive
       disclosure present when body > threshold                      [countable]
    J  blind A/B: shown this SKILL.md and a reference SKILL.md with
       provenance stripped, the critic cannot reliably tell which is
       Anthropic's — OR names the specific gap that gives it away    [judged]

  The J-level bar is the acceptance signal. Do not restate it in softer words.

CRITIC
A separate agent, FRESH CONTEXT, with no visibility into how the diff was built.
Prompted to REFUTE. It receives the candidate SKILL.md and a reference SKILL.md with
provenance stripped, in randomised order, and must name which is the reference and why.
It may not lower the bar. If it cannot refute, it says so explicitly.
Independence enforced by bin/convergence-guard — a same-context verifier is REFUSED.

EVIDENCE  (directly inspectable — no inference from the build story)
  - both SKILL.md texts, provenance-stripped, side by side
  - validate-plugin.sh output for the candidate
  - the countable T-metrics for both sides
  - the diff under review
The critic may NOT read the builder's reasoning or this prompt's derivation.

STATE
Persist OUTSIDE the conversation, per skill: every attempt, every refutation, every
T-metric, and the blind-guess outcome. Round N must know what round N-1 already failed.
Sink: a journal under the worktree, committed with the batch.

STOP
Per piece: exit when 3 consecutive critic rounds produce no new gap, using a DISTINCT
lens set each round (bar-nameability · critic-independence · evidence-inspectability ·
decomposability · stop-rule-presence · blast-radius).
Hard caps: 10 attempts/piece · <COST CEILING — operator-set> · <WALL-CLOCK — operator-set>.
Early exit on gain-stagnation (round-over-round delta below threshold twice).
Unbounded running is REFUSED — if either cap is unset, stop and ask.

ESCALATION
Halt and escalate to a human when: a guardrail surface is touched (Guardrails section, a
guardrail-enforcing rule/hook, gitleaks allowlist); the change becomes irreversible;
a skill's semantics (not its form) would change; or the caps above are exhausted.
Form may be raised autonomously. Meaning may not.
```

## Budget — why this file is NOT armed

The profile marks `cost_ceiling` and `wall_clock` as **`operator-set; REQUIRED before any long run`**,
with no defaults ("unbounded time is not a budget"). The rendered `STOP` restates it: *"Unbounded
running is REFUSED — if either cap is unset, stop and ask."*

Asked; unanswered at render time. So the loop is refused **by its own contract**, not by hesitation.
Two slots remain, and only the operator can fill them:

```text
<COST CEILING>   — required
<WALL-CLOCK>     — required
```

Recommended first run when a ceiling exists: **a 3-skill pilot**, ranked by the deterministic gap
pass. Rationale — if the blind A/B fails to discriminate, that is discovered across 3 pieces rather
than 82, and the run yields a playbook before any fan-out multiplies a harness defect by 82.

## Scope boundary

`agents/` (28) and `commands/` (37) are **out of scope** for this target. The bar named here is a
*skill* bar; Anthropic's reference corpus contains no comparable agent/command artifacts, so
extending the same bar to them would be naming a reference that does not exist — the exact failure
the `spec/` stub nearly caused above.
