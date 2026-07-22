---
name: lens-dispatch
version: 0.1.0
description: >
  Deterministic BINDING dispatcher of cognitive lens-stacks per work-graph node.
  Given a node (ticket/task/step/decision/pr/session) it emits one of three
  verdicts — DISPATCH (embody this lens-stack), NULL_PROFILE (embody NO lens),
  INCONCLUSIVE (fail-safe) — computed OUTSIDE the model so an agent cannot pick
  its own cognitive lens by vibe. Third orthogonal axis of an existing family:
  `response-compression` controls WHAT is said (verbosity), `slm-routing`
  controls WHERE it is sent (compute target), this controls HOW it is thought.
  Confidence is COMPUTED from the dogfood ledger, never hardcoded — so the tool
  structurally cannot overstate its own validation status.
agnostic: [os, project, vendor]
---

# lens-dispatch

## ⚠️ Read this first — epistemic status

**No lens-stack in this tool has a measured efficacy result.** Not one.

The source catalog's "evidence" records prove a recipe was *applied* and a PR *merged*.
They do not show the lens *improved* anything: there is no control, no counterfactual,
and the recorded `autonomy_score` is an agent **self-report of confidence**, not a
measure of outcome quality. Two of the three recorded "cycles" are the *same PR*.

Therefore this tool is built so it **cannot lie about itself**:

| Mechanism | Effect |
|---|---|
| `confidence` is read from `bin/dogfood-tally`, never hardcoded | with 0 ratified recipe-cycles, **everything returns `HYPOTHESIS`** — including the "best" recipe |
| `provenance` distinguishes `transcribed` from `bridge-hypothesis` | you always know whether a mapping came from a source document or from an authored guess |
| `bridge_authored` stamps the guess with a date | an invented mapping cannot silently age into apparent fact |
| unmapped input → `NULL_PROFILE` | the fallback is the **status quo** (agent with no lens), never a fabricated pick |

> A deterministic script guarantees the output is **reproducible**. It does not
> guarantee the output is **correct**. Do not confuse the two — that confusion is
> precisely how a guess acquires the appearance of rigor.

## Why it exists

The `persona-mindset-catalog` (~470 lenses, 15 recipes, 33 use-cases, a full invocation
contract) is referenced by **three files, all passive prose** — and by **zero
executables**. By the `corpus-firing-audit` criterion it is DORMANT: excellent, and it
never fires. A fresh amnesic agent never finds it.

This tool is the missing **edge**, not more inventory. It does not add lenses; it makes
the existing ones reachable at a decision point.

## Usage

```bash
lens-dispatch --node-kind <kind> [--use-case N | --session-type <mode>x<work>] [options]
lens-dispatch --self-test
```

| Flag | Values |
|---|---|
| `--node-kind` (required) | `ticket` `task` `step` `decision` `pr` `session` |
| `--use-case` | `1..33` — catalog §13.5 row. **Transcribed path** (verifiable against the doc). |
| `--session-type` | `<mode>x<work>`, e.g. `fresh×feat`. **Bridge path** (authored hypothesis). |
| `--stakes` | `trivial` `low` `medium` `high` (default `medium`) → sets `harness_mode` per §13.6.4 |
| `--signals` | csv, e.g. `complex-reasoning,security,irreversible` |
| `--format` | `json` (default) · `text` |

**Exit codes** (`[C06]`): `0` DISPATCH · `3` NULL_PROFILE · `4` INCONCLUSIVE · `1` usage · `2` self-test-fail.

## Verdict logic (deterministic, ordered)

1. missing/invalid input → `INCONCLUSIVE` (fail-safe)
2. `complex-reasoning` signal **or** `work=debug` → `NULL_PROFILE` (**degradation guard**)
3. `--use-case` resolves in §13.5 → `DISPATCH` · `provenance: transcribed`
4. `--session-type` resolves in the bridge → `DISPATCH` · `provenance: bridge-hypothesis`
5. otherwise → `NULL_PROFILE` (no verified mapping; status quo)

`--use-case` **wins** over `--session-type`: a transcribed mapping beats an authored guess.
The degradation guard wins over **both**: safety beats resolution.

### The degradation guard

Persona-steering is *withheld* for complex-reasoning work. Motivation: reporting that
persona induction produces stable, reproducible capability shifts — some personas
*impair* complex reasoning (arXiv 2604.11048, which independently proposes "Dynamic
Persona Routing").

⚠️ **Honest provenance of this guard**: that citation was read as a search summary, not
as the full paper; its transfer to *this* setup (6-role recipes over session types) is
unverified. The guard is kept anyway because it is **conservative** — it only ever
*declines* to add a lens, so it cannot cause harm even if its motivating claim is wrong.
It is a safe default, not a proven mechanism.

## The two tables

**Table A — use-case → recipe (`transcribed`).** Rows whose mapping is unambiguous in
catalog §13.5. Verifiable line-by-line against that document.

**Table B — work → use-case (`bridge-hypothesis`).** ⚠️ **This table exists in no source
document.** It was authored `2026-07-22` as an explicit hypothesis, operator-authorized
to run-and-measure. Over the 44 canonical `mode × work` combinations it currently
resolves **32 DISPATCH / 12 NULL_PROFILE**, i.e. **~73% of sessions would apply a lens
chosen by an unvalidated guess**. That number is the point: it is the exposure being
measured, stated plainly rather than buried.

`hotfix` and `chore` are deliberately unmapped (urgency ⇒ no lens overhead; low value).

## How a HYPOTHESIS becomes VALIDATED

There is no separate scoring system to invent or game. Promotion rides the ledger that
already exists and already demands proof:

```bash
# after genuinely applying a lens-stack and observing the outcome:
bin/dogfood-mark recipe-04 <cycle-id> --status complete --ratified --evidence <ref>
```

`dogfood-mark` refuses a `complete` cycle without `--ratified` **and** ≥1 `--evidence`.
Once `dogfood-tally` counts ≥2 such cycles for a recipe, `lens-dispatch` starts reporting
`confidence: VALIDATED` for it — **automatically, with no edit to this tool**. Nothing
here declares its own status.

## Non-regression floor

`NULL_PROFILE` and `INCONCLUSIVE` are *exactly* today's behaviour (an agent operating
with no lens). The verdict set therefore has a floor at the status quo: this tool can
only **add** a lens where a mapping exists — it can never remove capability. Binding is
safe by construction, not by trust. Proven by the self-test (21 assertions) plus the
44-combination matrix, which asserts zero `DISPATCH` without traceable provenance.

## What it does NOT do

- ❌ pick an **agent** (that is `agent-select` / `auto-best-fit-router`)
- ❌ pick a **model / compute target** (that is `slm-routing`)
- ❌ claim any lens-stack improves outcomes — **no such measurement exists yet**
- ❌ promote itself: `confidence` is read from the ledger, never written by this tool

## Source catalog (not promoted — deliberately)

Lens-stacks are transcribed from the user-scope `persona-mindset-catalog`. That catalog
is **not** vendored here: `bin/check-layer-purity` reports **12 organization-specific
violations** in it (repo names, org-specific manifesto references), so it is not
promotion-eligible as-is — despite its own frontmatter asserting `promotion_eligible: true`.
Sanitizing and promoting it is tracked as separate work.

This tool is therefore **self-contained**: every lens-stack it can emit is inline. The
`§N.M` markers are provenance citations back to that catalog, not runtime dependencies.

## Verify

```bash
bin/lens-dispatch --self-test                                  # 21 assertions
bin/lens-dispatch --node-kind pr --use-case 6 --stakes high    # transcribed path
bin/lens-dispatch --node-kind task --session-type fresh×debug  # degradation guard
bin/lens-dispatch --node-kind task --session-type fresh×chore  # status-quo fallback
```
