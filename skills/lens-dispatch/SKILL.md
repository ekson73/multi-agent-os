---
name: lens-dispatch
version: 0.2.0
description: >
  Deterministic dispatcher of cognitive lens-stacks per work-graph node. Given a node
  (ticket/task/step/decision/pr/session) it emits one of three verdicts — DISPATCH
  (embody this lens-stack), NULL_PROFILE (embody NO lens), INCONCLUSIVE (fail-safe) —
  computed OUTSIDE the model so an agent cannot pick its own cognitive lens by vibe.
  Third orthogonal axis of an existing family: `response-compression` controls WHAT is
  said (verbosity), `slm-routing` controls WHERE it is sent (compute target), this
  controls HOW it is thought. Confidence is COMPUTED from the dogfood ledger, never
  hardcoded. v0.2.0 survived an independent adversarial red-team that REFUTED v0.1.0.
agnostic: [os, project, vendor]
---

# lens-dispatch

## ⚠️ Read this first — epistemic status

**No lens-stack in this tool has a measured efficacy result.** Not one.

The source catalog's "evidence" records prove a recipe was *applied* and a PR *merged*.
They do not show the lens *improved* anything: no control, no counterfactual, and the
recorded `autonomy_score` is an agent **self-report of confidence**, not an outcome
measure. Two of the three recorded "cycles" are the *same PR*.

**v0.1.0 of this file made a safety claim that its own citation refutes.** See
[The floor claim, corrected](#the-floor-claim-corrected). An independent red-team
returned **REFUTED**; v0.2.0 is the repair. What follows is written to be checkable,
not to be believed.

| Mechanism | Effect |
|---|---|
| `confidence` read from `bin/dogfood-tally`, never hardcoded | with 0 ratified recipe-cycles, **everything returns `HYPOTHESIS`** — including the "best" recipe |
| `provenance` distinguishes `transcribed` from `bridge-hypothesis` | you always know whether a mapping came from a source document or an authored guess |
| `bridge_authored` stamps the guess with a date | an invented mapping cannot silently age into apparent fact |
| unmapped input → `NULL_PROFILE` | the fallback is the **status quo** (agent with no lens), never a fabricated pick |
| `tests/lens-dispatch-matrix.sh` | every claim below that states a number is asserted by a test that runs |

> A deterministic script guarantees the output is **reproducible**. It does not
> guarantee the output is **correct**. Do not confuse the two — that confusion is
> precisely how a guess acquires the appearance of rigor.

## Why it exists

The `persona-mindset-catalog` (~470 lenses, 15 recipes, 33 use-cases, a full invocation
contract) is referenced by **three files, all passive prose** — and by **zero
executables**. By the `corpus-firing-audit` criterion it is DORMANT: excellent, and it
never fires. A fresh amnesic agent never finds it.

This tool is the missing **edge**, not more inventory.

## Usage

```bash
lens-dispatch --node-kind <kind> [--use-case N | --session-type <mode>x<work>] [options]
lens-dispatch --self-test
```

| Flag | Values |
|---|---|
| `--node-kind` (required) | `ticket` `task` `step` `decision` `pr` `session` |
| `--use-case` | `1..33` — catalog §13.5 row. **Transcribed path.** |
| `--session-type` | `<mode>x<work>`, e.g. `fresh×refactor`. **Bridge path** (authored hypothesis). |
| `--stakes` | `trivial` `low` `medium` `high` (default `medium`) → sets `harness_mode` per §13.6.4 |
| `--signals` | csv, e.g. `complex-reasoning,security,irreversible` |
| `--format` | `json` (default) · `text` |

**Exit codes** (`[C06]`): `0` DISPATCH · `3` NULL_PROFILE · `4` INCONCLUSIVE · `1` usage · `2` self-test-fail.

⚠️ `NULL_PROFILE` — the *correct and most common* verdict — is a **non-zero** exit.
A `set -e` caller, or `lens-dispatch … && next-step`, will die or silently skip on the
status-quo answer. Branch on the verdict, not on truthiness.

## Verdict logic (deterministic, ordered)

1. missing/invalid input → `INCONCLUSIVE` (fail-safe)
2. `complex-reasoning` signal **or** `work=debug` **or** `work=fix` → `NULL_PROFILE` (**degradation guard**)
3. `--use-case` resolves in §13.5 → `DISPATCH` · `provenance: transcribed`
4. `--session-type` resolves in the bridge → `DISPATCH` · `provenance: bridge-hypothesis`
5. otherwise → `NULL_PROFILE`

`--use-case` **wins** over `--session-type`. The degradation guard wins over **both**.

> Ordering caveat found by the suite itself: with **no** resolution input, step 1 fires
> *before* the guard. That is safe (INCONCLUSIVE = status quo) but it means a guard test
> with empty input proves nothing about the guard. The regression tests pass a real input.

## The two tables

**Table A — use-case → recipe (`transcribed`).** Every row is a **1:1** mapping whose
lens set matches the catalog row verbatim. 14 rows.

**Table B — work → use-case (`bridge-hypothesis`).** ⚠️ **Exists in no source document.**
Authored `2026-07-22` as an explicit hypothesis, operator-authorized to run-and-measure.
4 rows: `refactor` `harmonize` `docs` `test`.

Over the 44 canonical `mode × work` combinations the bridge resolves **16 DISPATCH /
28 NULL_PROFILE** — i.e. **~36% of sessions apply a lens chosen by an unvalidated guess**.
That number is asserted by `tests/lens-dispatch-matrix.sh`; if the tables change and the
number is not updated, the test fails.

⚠️ **`mode` is inert.** All four modes produce byte-identical output — no decision path
reads it. "44 combinations" is **11 behaviours tested four times**. The test asserts the
inertness so this doc cannot overclaim coverage.

## What the red-team removed (v0.1.0 → v0.2.0)

An independent adversarial red-team (H6 per `red-teaming-mandatory-trigger`) returned
**REFUTED**. The headline finding was not in Table B — the admitted guess — but in
Table A, the part labelled `transcribed`:

> **8 of 21 rows did not match the source.** The author had collapsed whole §13.5
> *subsections* onto one representative row (`15|16|17 → uc-15`, `23|24|25|26 → uc-23`)
> and shipped the result labelled `transcribed`. UC26 ("Onboarding flow doc") had **zero**
> lens overlap with its catalog row: the catalog requires UX + Empathetic + Teacher; the
> tool emitted Editor + Researcher + Patient — a stack that prunes the scaffolding a
> newcomer needs and drives toward reference-completeness. Under binding, that is
> **worse than no lens**. UC33 pointed at `recipe-04` where the catalog says "Recipe #10",
> which would have credited #10's ledger cycles to #4 from the very first cycle.

A guess wearing the honest label's clothes is worse than an honestly-labelled guess.

| Fixed | How |
|---|---|
| 8 fabricated Table A rows | **removed**, not repaired-by-approximation → `NULL_PROFILE` |
| UC33 → recipe-04 | → `recipe-10`; `recipe-10` added with the catalog's own lens set |
| `feat\|enhance\|gap` → recipe-01 (12/44) | **withdrawn** — a go/no-go *decision-audit* recipe bound to *execution*: four rejection-biased lenses, no generative counterweight |
| `fix` escaping the guard | guard now covers `fix` — it is the same cognitive work as `debug` |
| one space disarming the guard | `has_signal` strips whitespace around every comma |
| `06` declared unmapped (false) | leading zeros stripped before the string lookup |
| 20-digit input bypassing range check | length-gated before any arithmetic; no raw bash error leaks to stdout |
| `"21/21 PASS"` hardcoded | counted — the same defect as hardcoding confidence, one function away |
| "the 44-combination matrix" cited as proof | now `tests/lens-dispatch-matrix.sh`, committed and runnable |

## The floor claim, corrected

v0.1.0 claimed a **non-regression floor "by construction"**: since `NULL_PROFILE` and
`INCONCLUSIVE` are today's behaviour, binding "can only ADD a lens, never remove
capability." The red-team showed this contradicts the very paper cited two sections
above it. If persona induction can *impair* — which is precisely why the degradation
guard exists — then a DISPATCH is a candidate capability **removal**, and the floor is an
*assumption*, not a construction. Both claims cannot be true; v0.1.0 shipped both.

**The honest statement:**

- For the **28/44 non-DISPATCH** combinations the floor is real: the verdict *is* the
  status quo.
- For the **16/44 DISPATCH** combinations there is **no floor**. Binding says embody this
  stack — which implies *not* embodying others. That is removal by displacement. A wrong
  lens is worse than no lens; UC26 was the proof.
- What justifies those 16 is **not** a safety proof. It is that (a) they resolve through
  verified rows, (b) each carries its provenance, and (c) `dispatch-then-regret` is a
  measured SLI with a kill-switch: any pair with confirmed regret is demoted to
  `NULL_PROFILE` in the table — a deterministic fix, not "remember to avoid it".

Also honest: arXiv 2604.11048's own proposal is **Dynamic Persona Routing**, which exists
because *static* persona assignment is suboptimal. This tool is a static lookup table. It
is a floor beneath the paper's approach, not an implementation of it.

## How a HYPOTHESIS becomes VALIDATED

```bash
bin/dogfood-mark recipe-04 <cycle-id> --status complete --ratified --evidence <ref>
```

`dogfood-mark` refuses a `complete` cycle without `--ratified` **and** ≥1 `--evidence`.
Once `dogfood-tally` counts ≥2, `lens-dispatch` reports `confidence: VALIDATED` for that
recipe — automatically, with no edit here.

⚠️ **Known integrity limits of that ledger** (red-team, unfixed here — they belong to the
ledger, not this tool): it is a mode-644 plaintext JSONL with no signature or hash-chain;
`DOGFOOD_LEDGER_DIR` redirects it; and `dogfood-tally` counts `ratified==true` **without
re-checking `evidence`** (the evidence gate lives on the *write* path only). So "cannot
lie about itself" is precisely: *faithfully reports whatever that file says*. Treat
`VALIDATED` as ledger-attested, not as tamper-evident.

## What it does NOT do

- ❌ pick an **agent** (that is `agent-select` / `auto-best-fit-router`)
- ❌ pick a **model / compute target** (that is `slm-routing`)
- ❌ claim any lens-stack improves outcomes — **no such measurement exists yet**
- ❌ promote itself: `confidence` is read from the ledger, never written by this tool
- ❌ provide a safety floor for the DISPATCH path — see above

## Source catalog (not promoted — deliberately)

Lens-stacks are transcribed from the user-scope `persona-mindset-catalog`, which is
**not** vendored here: `bin/check-layer-purity` reports **12 organization-specific
violations**, so it is not promotion-eligible as-is — despite its own frontmatter
asserting `promotion_eligible: true`. Sanitizing and promoting it is separate work.

This tool is therefore **self-contained**: every lens-stack it emits is inline. The
`§N.M` markers are provenance citations, not runtime dependencies — and for anyone
without that catalog they are **unresolvable pointers**.

## Verify

```bash
bin/lens-dispatch --self-test              # 30 assertions, incl. every red-team regression
tests/lens-dispatch-matrix.sh              # the 44-combination matrix, as a real test
bin/check-layer-purity bin/lens-dispatch skills/lens-dispatch/SKILL.md
```
