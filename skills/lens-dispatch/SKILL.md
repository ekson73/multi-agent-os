---
name: lens-dispatch
version: 0.5.0
description: >
  Deterministic dispatcher of cognitive lens-stacks per work-graph node. Given a node
  (ticket/task/step/decision/pr/session) it emits one of three verdicts — DISPATCH
  (embody this lens-stack), NULL_PROFILE (embody NO lens), INCONCLUSIVE (fail-safe) —
  computed OUTSIDE the model so an agent cannot pick its own cognitive lens by vibe.
  Third orthogonal axis of an existing family: `response-compression` controls WHAT is
  said (verbosity), `slm-routing` controls WHERE it is sent (compute target), this
  controls HOW it is thought. Confidence is COMPUTED from the dogfood ledger, never
  hardcoded — which means faithful to that ledger, NOT unfalsifiable. NO lens-stack here
  has a measured efficacy result — read the epistemic-status block before relying on it.
  Four independent adversarial red-team rounds have REFUTED every version so far
  (v0.1.0-v0.4.0), each finding defects in the previous round's fix; v0.5.0 carries the
  fourth round's repair and is NOT yet cleared.
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
returned **REFUTED**; v0.2.0 was the repair — a second round returned **STILL-REFUTED**,
finding defects *in that repair* (incl. that both test suites were blind to lens content);
a third returned **STILL-REFUTED** again — the guard added in v0.3.0 covered only one of
the two routes that reach it; a fourth returned **REFUTED** on one finding, materially
narrower: the *coverage claim* v0.4.0 made was stronger than the mechanism backing it.
v0.5.0 carries that repair and **has not been cleared**. What follows is written to be
checkable, not to be believed.

> **Track record, stated plainly:** **four** independent verification rounds, **four**
> upheld refutations. Each round found defects *in the previous round's fix*. The author's
> self-review caught **0 of 4**. Treat "the author says it is fixed" — including everything
> below — as an unverified claim until a round clears it.
>
> The rounds share ONE defect class, named by the R3 verifier: **the correction is applied
> where the finding was demonstrated, not where the property must hold.** R1 — the flagged
> rows were fixed, the source was never re-read. R2 — the claim was retracted in `SKILL.md`
> and survived in `bin/`. R3 — the guard closed the route the test exercises and stayed
> open on the other; the golden pin covered that same route and not the other; an invented
> label was replaced by a *different* invented label. That is what an acceptance test of
> *"the reported repro now passes"* buys you, instead of *"the invariant holds on every
> path that reaches it."* R4 is the same class once more, one level up: the v0.4.0 fix was
> correct, but the *claim about it* ("total by construction") outran the mechanism — a
> source-text regex a two-line `case` arm defeats.
>
> Two workflow rules came out of this, and they are the durable part:
> **(1)** for each fix, enumerate the paths that reach the property, pin each one, then
> re-run **with the mutant still installed** to confirm the suite actually fails;
> **(2)** assert the **property**, not a proxy for it — and never model the program by
> parsing its source when you can ask the program. Every counter here that probed the CLI
> (`_a`) was immune to all four rounds; the one that read text (`_b`) was broken twice.
>
> A third, from the R4 verifier and adopted: **every negative result needs a positive
> control in the same command** — and for a mutation, assert the mutant's *effect*, not its
> *presence*. That one habit would have caught all three of my own false negatives in R3.

| Mechanism | Effect |
|---|---|
| `confidence` read from `bin/dogfood-tally`, never hardcoded | with 0 ratified recipe-cycles, **everything returns `HYPOTHESIS`** — including the "best" recipe. ⚠️ This means *faithful to the ledger*, **not** "cannot lie": the ledger is mode-644 plaintext JSONL, `DOGFOOD_LEDGER_DIR` redirects it, and `dogfood-tally` counts `ratified==true` without re-checking `evidence` — fabricated entries yield `VALIDATED` (R3 reproduced it). The `bin/` header asserted the stronger claim for one full round *after* this file retracted it |
| `provenance` distinguishes `transcribed` from `bridge-hypothesis` | you always know whether a mapping came from a source document or an authored guess |
| `bridge_authored` stamps the guess with a date | an invented mapping cannot silently age into apparent fact |
| unmapped input → `NULL_PROFILE` | the fallback is the **status quo** (agent with no lens), never a fabricated pick |
| `tests/lens-dispatch-matrix.sh` | every number below **about this tool's behaviour** (16/28, ~36%, Table A=14, Table B=4) is *counted by a test that runs*, never transcribed by hand |

> Numbers about the **external catalog** (how many files reference it, how many Layer-Purity
> violations it has) are **dated observations**, not assertions — they describe a user-scope
> path outside this repo, so a portable test cannot check them. They are labelled as such
> wherever they appear. Do not read them as verified-on-every-run.

> A deterministic script guarantees the output is **reproducible**. It does not
> guarantee the output is **correct**. Do not confuse the two — that confusion is
> precisely how a guess acquires the appearance of rigor.

## Why it exists

The `persona-mindset-catalog` (~470 lenses, 15 recipes, 33 use-cases, a full invocation
contract) was referenced by **zero executables**. By the `corpus-firing-audit` criterion it
is DORMANT: excellent, and it never fires. A fresh amnesic agent never finds it — `docs/`
is not auto-loaded (`[C08]` "arquivo morto").

> ⚠️ **Correction (2026-07-22).** v0.2.0 said "referenced by **three** files, all passive
> prose". Re-probed with a positive control: it is **10** files — 3 auto-loaded rules
> (`eko-system-default-mode-laws`, `auto-merge-standing-authorization`, `council-gate`) and
> 7 non-auto-loaded prose files under `docs/`+`plans/`. The undercount ran in the direction
> that **flattered the argument** ("only three" reads as more dormant), which is why it is
> corrected loudly rather than quietly. The verdict is unchanged and now rests where it
> belongs: on **zero executables**, which is the criterion — not on a reference tally, which
> was decorative. *(Dated observation, not a test assertion — see the note above.)*

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
| `--format` | `json` (default) · `text` — **fail-closed**: any other value (incl. `TEXT`) exits `1`, never silently falls through to JSON |

**Exit codes** (`[C06]`): `0` DISPATCH · `3` NULL_PROFILE · `4` INCONCLUSIVE · `1` usage · `2` self-test-fail.

⚠️ `NULL_PROFILE` — the *correct and most common* verdict — is a **non-zero** exit.
A `set -e` caller, or `lens-dispatch … && next-step`, will die or silently skip on the
status-quo answer. Branch on the verdict, not on truthiness.

## Verdict logic (deterministic, ordered)

1. missing/invalid input → `INCONCLUSIVE` (fail-safe) — incl. an **unknown `--signals` token**
2. `complex-reasoning` signal **or** `work=debug` **or** `work=fix` → `NULL_PROFILE` (**degradation guard**)
3. `--use-case` resolves in §13.5 **and is not §13.5.D work** → `DISPATCH` · `provenance: transcribed`
4. `--use-case` resolves but **is** §13.5.D (*Debugging / investigation*, UC15-18) → `NULL_PROFILE` (guard, by work-class)
5. `--session-type` resolves to a **§13.5.D** use-case → `NULL_PROFILE` (**same guard as 4**, on the bridge route)
6. `--session-type` resolves, not §13.5.D → `DISPATCH` · `provenance: bridge-hypothesis`
7. otherwise → `NULL_PROFILE`

`--use-case` **wins** over `--session-type`. The degradation guard wins over **both**.

> **The guard is a property of the WORK, not of the flag.** Step 4 exists because the guard
> was bypassable by *route*: `--session-type fresh×debug` withheld the lens while
> `--use-case 15` ("Bug root-cause analysis") dispatched one — identical cognitive work,
> different flag. Same family as the `fix`-vs-`debug` finding, one layer up. The criterion is
> documentary (catalog §13.5.D is titled *Debugging / investigation*), not a judgement call.
> Steps 3/4 stay distinct on purpose: "a mapping exists but is withheld" is **not** the same
> fact as "no mapping exists", and collapsing them would repeat the `06` defect of asserting
> something false about the source document.

> Ordering caveat found by the suite itself: with **no** resolution input, step 1 fires
> *before* the guard. That is safe (INCONCLUSIVE = status quo) but it means a guard test
> with empty input proves nothing about the guard. The regression tests pass a real input.

## The two tables

**Table A — use-case → recipe (`transcribed`).** Every row is a **1:1** mapping whose
lens set matches the catalog row verbatim. **14 rows** (counted by the test, not typed here)
— of which **12 can dispatch** and **2 (UC15, UC18) are permanently withheld** by the
work-class guard above. 12 of the 14 are pinned verbatim by a golden assertion; the 2
withheld rows are not pinnable through the CLI (their lens is never emitted), so the test
asserts only that their mapping still *exists*. Honest residual: a drift in those 2 rows
would go unnoticed — accepted, because a value that is never emitted has no behavioural
effect.

> ⚠️ **Two exceptions to "verbatim" (R3/F5, R3/F6) — stated because the word was doing
> work it had not earned:**
> - **`recipe-14`** shipped invented labels *twice*. R1 used `founder-vision`/`moonshot`;
>   the R1 "fix" used `jobs-simplicity`/`musk-first-principles` under a comment claiming
>   they "track the catalog's own entry names" — a positive-controlled grep returns **zero**
>   occurrences of either, and `simplicity` appears nowhere in §5.1 ("Product polish + user
>   obsession + verticalization"). It was folk knowledge imported from outside the source,
>   and the golden pin then locked the paraphrase in **as if it were the source**. Now
>   `steve-jobs`/`elon-musk` — the catalog's own entry names, kebab-cased, nothing else.
> - **`recipe-10`** is byte-identical to `recipe-04`. Catalog #10 ("6-stage virtual review
>   board") is a **sequential pipeline** and supplies **no §refs of its own**; the refs are
>   **inferred from row #4**, so "matches the catalog row verbatim" is false for this row —
>   a row with no refs has none to match. The distinguishing attribute (*sequential*) is
>   **not in the payload**, so a consumer cannot act on it: the id separates the two for
>   ledger accounting, the dispatched lens does not. Open.

**Table B — work → use-case (`bridge-hypothesis`).** ⚠️ **Exists in no source document.**
Authored `2026-07-22` as an explicit hypothesis, operator-authorized to run-and-measure.
4 rows: `refactor` `harmonize` `docs` `test`.

All 4 rows' lens content is pinned by `golden_st` assertions, and the test asserts the
**coverage property directly** over the rows the program itself declares (`--list-bridge`):
every declared row that dispatches must be pinned, or the suite fails.

**Scope of that claim, stated because four earlier versions overstated it.** It holds for the
**bridge** route (`--session-type`). Three path-count invariants assert that the declared
lookup is the only *path* that can dispatch there (`valid_work` 1 accepting path ·
`use_case_for_work` 2 echoes · `decide()` 2 DISPATCH exits), each failing closed on any added
or reshaped path. The **transcribed** route (`--use-case`) never calls `valid_work` and is
guarded separately by `_a`, which runs the binary over 1..33 and counts mapped rows against
the number stated here. It asks what the program *did* — but that alone does **not** make it
unfoolable (R8 below refuted exactly that inference). `_a` is a **count**: it catches a row added
to or removed from the mapped set, and is **blind to value-drift** — a mapped row whose recipe
changes keeps the count. Measured (R9-cont ask-3): UC11 `recipe-02`→`recipe-14` was caught by
golden-11 + the whole-file hash, **not** by `_a`. Its sound scope is count-integrity over 1..33;
value-drift is covered elsewhere.

⚠️ **`--list-works` is not literally the accept-set** (R7, verified here). `norm()` lowercases
and trims, so `REFACTOR` and `Refactor` dispatch too. Normalisation is total *onto* the
declared set, so this yields no unpinned dispatch — but "the declaration is the accept-set" is
false as a sentence, and false sentences about true mechanisms are what this file has had to
retract four times.

**What the gates cover, by mechanism — no universal claim, on purpose.** Four successive
versions of this paragraph asserted that some class of attack was exhaustively caught, and each
was refuted by an instance inside the class it claimed. The sentences below say which mechanism
catches which measured mutant, and then name what is NOT covered. That is the whole claim.

*Behavioural gates* (they run the binary and read its verdict) catch: a second accepting path ·
a second emitting path · a third `DISPATCH` exit · a widened condition plus a declared row · a
coverage loop gone inert · single-path condition-widening in `valid_work`. The last of those is
the **near-miss battery**, added in R7: `valid_work` widened alone never dispatches (Table B
stays exact-match, so garbage moves from *rejected* to merely *unmapped* — the fail-safe
direction), so "no unpinned dispatch" was true while every gate passed **silently**. What does
change is the reason (`invalid-session-work` → `no-bridge-mapping-for-work`), so the battery
asserts *that*, over inputs derived from `--list-works` (three shape-variants per declared work
— 33 today, and the count follows the vocabulary rather than being fixed at 33). It is
**load-bearing**: disable only the battery and all three globs pass green (rc=0, zero other
failures); enable it and all three fail. Independently reproduced by R8.

*The resolution-path tripwire* (R8) catches what no behavioural gate can: a widening applied
**before** the declaration is read. R8 broke every gate above with one line —
`work="$(split_session_type "$st" work | tr -d '-_.')"` — making `fresh×re-factor` dispatch
`recipe-02` while `--list-works`/`--list-bridge` stayed byte-identical, all path-counts passed,
the battery stayed blind, and both suites went green. **Strictly weaker than the two-path case
below: one edit, not two.** The reason it was invisible is structural, and it is the sharpest
lesson this file records: every behavioural gate *derives its inputs from the declaration*, so a
transform applied upstream of the lookup is unreachable by declaration-derived generation **by
construction**. Adding separator-shaped variants would close `tr -d '-_.'` and not `tr -d ' '`,
not a stemmer, not a soundex — **the gap is the stage, not the shape**. A stage is enumerable
where a shape-space is not, so the tripwire pins the resolution path by **hashing the whole
binary file** and failing on any byte-change to it.

*It took three versions to reach "the whole file", and the two I discarded are the argument —
each was broken, twice by me and once by the red-team, and each break was the same mistake one
level up: a selection I mistook for the program.*

**v1 pinned a `grep`-filtered slice of `decide()`.** I broke it myself before submitting: a
one-line insert the filter did not match — `work="${work//-/}"` below the `split_session_type`
line — made `fresh×re-factor` dispatch with the suite green. *A filter is a selection — a model of
which lines matter — so the widening moved to a line the model excluded.*

**v2 pinned the whole `decide()` body** (filter removed) and I wrote that it "has no model to
evade." **That sentence was false, and the red-team refuted it.** Two one-line transforms placed
**upstream of `decide()`** — one at the `--session-type` arg-parse assignment, one at the
`decide()` call site — rewrite `$SESSION_TYPE` to `frescxrefactor` *before* the pinned code ever
runs, so every pinned byte is untouched and both dispatch with the suite green. I verified both
independently against the v2 commit with a verified-clean baseline (an in-pin positive control was
CAUGHT, so the two OPENs are meaningful, not a dead harness). **The `awk` range was the model** —
`/^decide()/,/^}/` is a selection exactly as the grep was. Widening a selection is not removing
one; the residual is never "a line the filter missed" but **a stage the selection does not
cover**, and the entire arg-parse/dispatch prologue was outside it.

**v3 hashes the file.** No selection ⇒ no stage left uncovered inside the binary. Re-measured: the
red-team's MB (arg-parse transform) and MC (call-site transform) — both OPEN against v2 — are now
**CAUGHT**; the in-`decide()` MA and R8's in-pin mutant stay CAUGHT. The inertness guard is
**deleted**, not fixed: it was machinery required only because the extraction had a shape to
truncate (v2's 7-marker presence loop was itself defeatable — a padding carrying the tail marker's
text truncated `decide()` 80→21 lines with all 7 markers passing, and what caught it was an
unrelated invariant, true by accident). With no selection there is nothing to truncate; `[ -s ]`
covers the degenerate empty case so the failure is legible. Deleting a guard because the mechanism
it guarded no longer exists is the correct direction.

*The cost is larger and stated, not hidden: **every** edit to `bin/lens-dispatch` re-pins,
comments included* — measured, a benign comment added inside `decide()` turns the suite red. That
friction IS the mechanism. *The residual is what a file hash cannot reach: the environment and the
interpreter.* ⚠️ **R9-continuation, self-caught (the 10th): the first draft here *grepped* for the
environment residual and concluded `DOGFOOD_LEDGER_DIR` was the only var reaching behaviour and that
none reached dispatch — a CONTAINS-claim (read the source for env-reads), and the DID-test refuted
it.** Measured: **`LC_ALL` reaches the dispatch verdict.** Under an 8-bit legacy locale
(`tr_TR.ISO8859-9`) `FRESH×HARMONIZE` flipped `DISPATCH`→`INCONCLUSIVE` (rc 0→4), because `norm()`'s
`tr '[:upper:]' '[:lower:]'` and `split_session_type`'s `sed 's/×/x/g'` are locale-sensitive — and
the **signals path** could flip the *injection* direction (a locale-mangled `complex-reasoning` that
fails to match would skip the degradation guard and DISPATCH a wrong lens). A structural "it's
fail-safe" argument would be the un-measurable claim that broke nine times; instead the vector is
**eliminated** — `export LC_ALL=C` in the preamble (inside the hashed file) removes locale as an
input to every resolution stage by construction (Gordian: one line, not per-command sprinkling that
misses one — the "closed one of two routes" class). Measured after: the tr_TR flip is **gone** (both
locales DISPATCH), positive control still distinguishes NULL/INCONCLUSIVE. *(Instrument-fault, also
self-caught: the `git checkout -- $BIN` trap that removed the regression **mutant** also removed the
uncommitted **fix** — it restores to the committed base, not the working base; caught loudly because
the already-edited test pin disagreed with the reverted bin. Restore an uncommitted-fix mutation
test from a working-tree `cp`, never `git checkout`.)*
That is the honest boundary of the mechanism, and the `WORK_VOCAB` global — a genuinely different
sibling — is covered by the taxonomy drift-gate, which pins the vocabulary's *contents* (it does
not cover a token rewritten before `valid_work` sees it, which is what MB/MC did — hence the file
hash).

*Say input→use-case, not input→recipe.* The draft of this paragraph said "the complete
input→recipe path", which is false — the final `use_case_for_work → recipe_for_use_case` step is
**outside** the pin. Positive control: a benign comment added inside `recipe_for_use_case` leaves
the suite **green**, proving the tripwire does not reach it. That step is covered by a different
mechanism, measured: repointing `recipe_for_use_case` 11 from `recipe-02` to `recipe-14` — the
exact R2 fabrication — fails on `UC11 lens drift`, i.e. the golden pins, not the hash. Two
mechanisms, two scopes; naming them as one is the same word-doing-two-jobs error R7 corrected,
and it nearly shipped a fifth time in this very sentence.

*Its cost, stated rather than hidden*: a hash is a **change**-detector, not a semantic gate. Any
edit to the file fails the suite — a benign rename, a reformat, a comment — and must be re-pinned
deliberately. That is the trade taken on purpose: whole-file is the only scope with no selection
to evade, and the failure direction is closed (loudly stale beats silently wrong). One consequence
worth knowing: the tripwire fires *first* for mutants the path-count invariants also catch, so a
FAIL there names the hash rather than the count — the counts still run; re-pinning does not
silence them (verified: a co-firing mutant produced rc=1 with *both* messages present).

**Why the transcribed route needs no tripwire — measured, not assumed.** The obvious next
question is where else "the resolution path is pinned" must hold; the `--use-case` route has the
same shape (a token, a normalization at `sed 's/^0*//'`, a table, a guard) and is **not** in a
hashed path. Four mutants say it does not need to be: a fabricated Table A row (uc 4, the exact
R1 defect re-introduced) · an upstream transform folding out-of-range into range
(`uc=$(( (uc-1) % 33 + 1 ))`, R8's attack ported to this route) · the protection guard disabled ·
the guard narrowed to drop UC15 — **4/4 caught**. *The reason is structural: this route's input
domain is **enumerable** (integers 1–33, plus out-of-range).* But state the guarantee precisely —
the red-team's R9 precision, folded in: the `for uc in $(seq 1 33)` loop asserts a **count**
(`_a -eq 14` mapped) over the domain, **not per-input identity**; identity is pinned for the 12
golden use-cases plus the two `withheld` reasons (15, 18). So the honest phrasing is *the domain
is enumerated for count, and 14 of 33 inputs are pinned by identity* — not "exhaustively
enumerated." The gap that phrasing hides was itself measured: a `SWAP-15-18` permutation is
**OPEN** (rc=0, 0 FAILs) yet **harmless** — both emit byte-identical
`protected-work-use-case-lens-withheld` with `recipe=null`, so the permutation is invisible *and*
fail-safe (no dispatch). The bridge route needed a hash precisely because its domain is arbitrary
strings. *Enumerate the domain where you can; pin the stage where you cannot — and say which
guarantee the enumeration actually gives.*

**Residual, stated precisely.** The two-path widening (both conditions widened, declarations
byte-identical) is invisible to every *behavioural* gate; it is caught only by the *tripwire*.
Those are different kinds of coverage and collapsing them is the word-doing-two-jobs error
corrected in R7 — a tripwire proves the code did not change, never that the code is right. So
what remains uncovered for honest drift is a widening that changes **no byte** of the file and
**no declared table row**.

*The R9 refutation of ask 4 lives here, because this is the sentence it broke.* An earlier draft
listed "upstream token preparation on the bridge route" among the classes **checked and
excluded** — while the pin was still v2's `decide()` body. That was false: the red-team's MB and
MC **are** upstream token preparation on the bridge route (arg-parse and call-site), and v2 did
not exclude them — they dispatched. The exclusion claim failed; only the closing hedge ("I have
not enumerated that remainder and do not claim it is empty") survived. What now makes the claim
true is the fix, not the wording: the pin became the **whole file**, so any upstream transform
inside `bin/lens-dispatch` — arg-parse, call-site, or a stage nobody has named — changes the
hash. Re-verified: MB and MC are **CAUGHT** against the file hash. The classes now genuinely
excluded are the data tables (own gates), **any in-file token preparation** (the file hash — no
longer a selection to slip past), and the transcribed route (count-enumerated + 14/33
identity-pinned, per above). What a file hash still cannot reach is stated plainly: the
environment — now **only** `DOGFOOD_LEDGER_DIR` (confidence read, verdict-invariant, measured) plus
the process context a file cannot pin (`PATH` / which-`coreutils`) — and the interpreter. *(`LC_ALL`
was in this residual until the R9-continuation above; it is now pinned out by `export LC_ALL=C`,
inside the hash — measured, not argued. Re-measured for R9′ ask-1: `fresh×HARMONİZE` with the
Turkish dotted-İ (U+0130) under `C`, `tr_TR.UTF-8`, and `tr_TR.ISO8859-9` yields INCONCLUSIVE /
exit 4 **identically** (measured here on BSD `tr`). The ambient-locale `tr`-fold flip is
**structurally** eliminated on any `tr` implementation — the `export` forces `C` for every
subprocess before `norm()` runs — but that generalization is *inferred from the forced-`C`
mechanism, not measured on GNU `tr`/Linux here* (the DID-vs-CONTAINS split, marked honestly).)* I do not claim that remainder is empty. Against an adversary rather than a maintainer, nothing in a
co-located suite helps — see the boundary below.

**Where the boundary actually sits** — R7's reframe, adopted because it is smaller and more
defensible than the one this file used to state. An adversary who can edit `bin/` can edit
`tests/`; against that adversary no assertion in a co-located suite helps, and that was never
in scope. The suite's real job is **honest drift**: a maintainer who widens a condition without
seeing the blast radius. Honest drift widens by *class* — case-insensitive, a prefix, a glob —
essentially never by one hidden token, which is what the battery covers.

> **The observable-vs-input refinement (R8).** Seven rounds supported "asking what the program
> **did** has never been foolable; asking what it **contains** has been fooled three times", and
> R8 refuted the first half — but not where it looked. The near-miss battery asks what the
> program DID, and was blind anyway. R8's own reading is the precise one: the observable
> (`.reason`) was right; the **input domain** was wrong. Generation was anchored to the
> declaration, so the effect-observable silently inherited the declaration's blind spot.
> Corrected: *an effect-observable is only as wide as the inputs you can generate, and generating
> them from the artifact's own declaration re-imports the very gap you were trying to escape.*
> That is why the remaining mechanism is a tripwire on the stage rather than a wider sample —
> when you cannot enumerate the inputs, enumerate the code they flow through.

> ⚠️ **v0.4.0 claimed this "by construction" and was wrong (R4/N1).** It rested the claim
> on a row COUNT implemented as a source-text regex, which matched only single-line `case`
> arms — so a two-line arm (identical bash, identical semantics) grew Table B to 5 **live**
> works while the counter still said 4 and the 5th dispatched unpinned, suite green. The
> assertion was strictly stronger than the mechanism: this tool's recurring defect, fourth
> iteration. A count is a proxy; the property is now asserted directly, and both counters
> are behavioural — but **behavioural does not imply unfoolable** (the R8 refinement above
refuted exactly that inference). `_a`'s soundness is *scoped*: it is a count, so it catches a
row entering/leaving the mapped set and is blind to value-drift inside it — not an oracle that
"was never foolable."

This closes R3/F3: *every* DISPATCH the matrix exercises goes
through this route, and until v0.4.0 **none of it was content-pinned** — a mutant
retargeting `docs` from UC23 to UC27 silently gave documentation work founder-vision
lensing while both suites stayed green.

Over the 44 canonical `mode × work` combinations the bridge resolves **16 DISPATCH /
28 NULL_PROFILE** — i.e. **~36% of sessions apply a lens chosen by an unvalidated guess**.
That number is asserted by `tests/lens-dispatch-matrix.sh`; if the tables change and the
number is not updated, the test fails.

⚠️ **`mode` is inert.** All four modes produce byte-identical output — no decision path
reads it. "44 combinations" is **11 behaviours tested four times**. The test asserts the
inertness so this doc cannot overclaim coverage.

## What the red-teams removed (v0.1.0 → v0.2.0 → v0.3.0)

An independent adversarial red-team (H6 per `red-teaming-mandatory-trigger`) returned
**REFUTED**. The headline finding was not in Table B — the admitted guess — but in
Table A, the part labelled `transcribed`:

> **8 of 21 rows did not match the source** (7 fabricated + 1 mis-credited). The author had collapsed whole §13.5
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
| 7 fabricated Table A rows | **removed**, not repaired-by-approximation → `NULL_PROFILE` (the 8th, UC33, was mis-credited rather than fabricated → re-keyed, next row) |
| UC33 → recipe-04 | → `recipe-10`; `recipe-10` added with the catalog's own lens set |
| `feat\|enhance\|gap` → recipe-01 (12/44) | **withdrawn** — a go/no-go *decision-audit* recipe bound to *execution*: four rejection-biased lenses, no generative counterweight |
| `fix` escaping the guard | guard now covers `fix` — it is the same cognitive work as `debug` |
| one space disarming the guard | `has_signal` strips whitespace around every comma |
| `06` declared unmapped (false) | leading zeros stripped before the string lookup |
| 20-digit input bypassing range check | length-gated before any arithmetic; no raw bash error leaks to stdout |
| `"21/21 PASS"` hardcoded | counted — the same defect as hardcoding confidence, one function away |
| "the 44-combination matrix" cited as proof | now `tests/lens-dispatch-matrix.sh`, committed and runnable |
| both suites blind to lens content | **golden pin**: 12 `--use-case` rows pinned; a mutant repointing UC11 used to pass green. ⚠️ **Incomplete** — see R3/F3 below |
| **R3/F1** retracted ledger claim still shipping in `bin/` | header now says *faithful to the ledger*, with the attack (redirect + fabricate) written out; the quote one function away was corrected too |
| **R3/F2** guard had **one** call site — bridge route open | the `--session-type` route now calls the same guard. Protection was previously an accident of Table B's data, not a property. Pinned by a **reachability proof**: the test builds an isolated copy, points Table B at UC15, and asserts the withholding — the only way to test a path no legitimate input reaches today |
| **R3/F3** every golden pin used `--use-case`, but **all 16 DISPATCH combos go through the bridge** | 4 `golden_st` pins added — one per mapped work. ⚠️ v0.4.0 called this "total by construction" on the strength of a source-regex row count that a two-line `case` arm defeats (**R4/N1**); v0.5.0 asserts the coverage property directly instead — every dispatching work must be pinned — and makes both counters behavioural |
| **R3/F4** `_b` counted dispatching works, not table rows | counts arms from source: `chore -> 5` grows the table to 5 rows while resolving to `NULL_PROFILE`, and used to pass |
| **R3/F5** invented labels on a "verbatim" row (2nd time) | `steve-jobs`/`elon-musk`; golden 27 re-pinned to the source, not the paraphrase |
| **R3/F7** `--format` neither validated nor normalized | fail-closed (`json\|text`, exit 1). `--format TEXT` used to return JSON silently — the `06`≠`6` / `fix`≠`debug` family: a value that misses a match and falls through to a default instead of being rejected |
| leak-detector dead under `pipefail` | captured to a variable, plus a meta-check proving the detector can still fire |
| `--signals` accepted anything (N6) | closed vocabulary; an unknown token is `INCONCLUSIVE`, never a silent no-op that disarms the guard |
| guard bypassable by **route** (N5) | `--use-case 15/18` (catalog §13.5.D *Debugging*) now hits the same guard as `work=debug\|fix` |

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
- What justifies those 16 is **not** a safety proof. It is only that (a) they resolve
  through verified rows and (b) each carries its provenance.

> ⚠️ **Retracted overclaim (2026-07-22).** This bullet used to add "(c) `dispatch-then-regret`
> **is** a measured SLI with a kill-switch". **It is not. Neither exists.** No regret signal
> is emitted, collected, or wired anywhere; nothing demotes a bad pair. Written in the
> present tense, it read as a live control compensating for the missing floor — inside the
> very section retracting a different unearned safety claim. Stated correctly: the kill-switch
> is a **deterministic fix that remains available** (demote the pair to `NULL_PROFILE` in the
> table — a one-line diff, not "remember to avoid it"), and the SLI is **unbuilt future work**.
> Until it is built, a wrong DISPATCH is caught by a human noticing, not by this tool.

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
**not** vendored here: `bin/check-layer-purity` reported **12 organization-specific
violations** *(dated observation, 2026-07-22 — an external user-scope file, so no portable
test can re-check it)*, so it is not promotion-eligible as-is — despite its own frontmatter
asserting `promotion_eligible: true`. Sanitizing and promoting it is separate work.

This tool is therefore **self-contained**: every lens-stack it emits is inline. The
`§N.M` markers are provenance citations, not runtime dependencies — and for anyone
without that catalog they are **unresolvable pointers**.

## Verify

```bash
bin/lens-dispatch --self-test              # prints its own assertion count (never hardcoded)
tests/lens-dispatch-matrix.sh              # the 44-combination matrix + golden pin, as a real test
bin/check-layer-purity bin/lens-dispatch skills/lens-dispatch/SKILL.md tests/lens-dispatch-matrix.sh
```

The assertion count is deliberately **not** written here: quoting it would re-create the
`"21/21 PASS"` defect one file over — a number that drifts silently from what runs.
