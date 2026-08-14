# EVAL-REPORT — refine-braindump-to-prompt (skill) — 2026-08-14

- **Baseline**: none (first eval, v0.1.0)
- **Golden cases**: 3 (smoke-set, synthetic — low-confidence flag per `agentic-tool-evaluator` step 2)
- **Independence**: the skill's author did NOT score behaviour. Three sub-agents ran blind to authorship
  and to expected outcome. Deterministic checks (D1–D3) were run by the author — they carry no judgment.
- **Run by**: `maos:agentic-tool-evaluator` v1.1.0 method (behavioral, with/without control)

## Why this eval exists

`persist-locus.md` gates persistence into `multi-agent-os` on **dogfood ≥2 + evaluator**. Dogfood reached
5/2; the evaluator had never run. The ledger recorded that as `PERSISTED ⚠️ gate-incomplete` rather than
hiding it. This report closes the open conjunct — and the answer is not the one the author expected.

## Cases

| ID | Input | Condition | Tests |
|----|-------|-----------|-------|
| A | synthetic braindump: recurring goal + a silent-failure dependency | **with** skill | full pipeline, recurrence clause, PRISM |
| B | synthetic braindump: referentially empty (`aquilo`, `o fulano`, `a abordagem nova`) | **with** skill | documented HALT conditions |
| C | same input as A | **without** skill | baseline — isolates the tool's actual effect |

## Scores (0–5; ScopeFit −2..+2)

| Case | Trigger | TaskCompl | ToolCorr | Effic | ScopeFit | Regression |
|------|---------|-----------|----------|-------|----------|------------|
| A | 5 | **2** | **3** | **1** | +1 | n/a (no baseline version) |
| B | 5 | 5 | 4 | 4 | +2 | n/a |
| C | — | 4 | — | 5 | — | *(control, not scored as tool)* |

## Verdict: **FAIL**

Not because the output is bad — case A's rendered prompt is strong, and case B halted exactly as designed.
It fails because **the pipeline cannot terminate cleanly on its own default profile**, and because two of
its own cited primitives contradict it.

### Blocking findings

| # | Finding | Why it is blocking |
|---|---|---|
| **A9.1** | `stop_refine` floor requires **≥6 rounds** (revisions ≥3 AND clean_rounds ≥3 — a round is one or the other, never both). When `long_loop_licensed = false`, the cap is `n* ≤ 3–4`. **Floor > cap.** `profiles/default.md` states the gate "normally evaluates false for this profile" | every default-profile run hits an unsatisfiable predicate |
| **A9.2** | `clean_rounds` requires distinct lenses per round; the profile draws them "in rotation so no round repeats a lens". Under the cross-round reading, 3 clean rounds need **9 distinct lenses** and the roster holds **5** | `STOP-DONE` is **unreachable** on the default profile |
| **A9.3** | The skill assigns PHASE 3 to `convergence-engine`, whose master condition is `verifier > generator ∧ independent` — but its REFINE loop has the draft's author as critic. Run against it, `bin/convergence-guard` returns `REFUSE / correlated-verifier-violates-independence` | the skill's own cited primitive rejects the skill's own phase. Empirically confirmed: RED-TEAM found 2 BLOCKING defects that 6 self-critique rounds missed |
| **B2** | The absorption law states an unconditional `MUST emit both the parts catalogue AND the drop-list-with-reasons`, but DISTILL is positioned `← LAST`. On any RECOVER halt, DISTILL never runs | a `MUST` that the phase ordering makes unsatisfiable |

### Major findings

| # | Finding |
|---|---|
| **B5** | The escalation clause (*"one with three independent parts barely needs `relate`"*) permits skipping the **one gate that catches the referentially-empty input class** — whose parts *look* independent on a surface read. Mitigated by an unconditional goal-absent backstop, so the outcome is robust; the **diagnosis quality** is what degrades |
| **A9.5** | The PRISM halt reads only `inconclusive.flag`. In case A that flag was `false` while `structural_route.py` independently returned `human_review: true, allowed_use: assistive_only`. The skill never reads the router's verdict — a DoD its own primitive says needs human review passes the gate untouched |
| **A9.7** | The Validation section cites `skills/maos:refine-braindump-to-prompt/SKILL.md` and `commands/maos:...`. **No skill directory carries a `maos:` prefix** — that is the invocation namespace, not a path segment. Same wrong path in the command file. Both artifacts exist; only the documented paths are wrong |
| **A9.4** | The recursion clause mandates a `BUILD-METHOD` section, which exists only in `gauntlet-loop`. Unfollowable under `--architecture=default` |
| **A9.6** | Two braindump bullets were dropped as session-meta, but the independent refuter argued `busque semelhantes` and `invoque Forge` are **output-shaping constraints wearing method-directive clothing**, and that rendering `use [tooling]` as "permissible, none mandated" **inverted an imperative into a permission**. The skill's own straddler test anticipates this class; its Protocol Rules give the opposite instruction |
| **B1 / B3** | DISSECT's halt test is ambiguous between speech-act and referent readings (different halt sites, same input). "Ranked hypotheses (never guess a goal)" is self-tensioned on zero-content input |
| **B4** | Two lineage blockquotes number the movements with an off-by-one (Alambique=M2/M3 vs M1/M2). Zero pipeline effect; two drafts left in place |

## Deterministic checks (author-run, no judgment)

| # | Check | Result |
|---|-------|--------|
| D1 | `/slash` invocation surface — `commands/` wrapper exists | PASS (positive control: `gap-loop` wrapper found) |
| D2 | command `name:` matches skill `name:`; description 767 < 1024 | PASS |
| D3 | `tests/validate-plugin.sh` | PASS rc=0 |

Note: D3 passing is itself a finding — **no structural gate in this repo catches A9.1, A9.2 or A9.7.**

## Strengths (measured, not asserted)

- **Case B halted correctly, and halted *with a receipt*** — it emitted the parts catalogue and relation
  map (5 nodes, 0 resolvable edges) before refusing, rather than bouncing at the door. The artifacts
  *are* the evidence for the halt.
- **Prompt-injection posture held in both cases.** Braindump imperatives were catalogued as objects,
  never executed.
- **RELATE earns its place.** In case A it found the decisive edge — the stated DoD is a *lagging*
  indicator, observable only after sending, so it can never gate the send. That is a property of an
  edge, not of any part, and it restructured the entire ACCEPTANCE section into three tiers.
- **PRISM's veto-gate rule caught a real modelling error**: "statement closed" had been placed as a
  weighted leaf, where a high sibling averages a hard blocker away.

## Weaknesses

- **Efficiency is the worst score, and it is measured, not impressionistic.** Case A ran 12 rounds and
  two red-teams and still terminated `STOP-HITL` with 1 BLOCKING un-applied. The control (case C)
  produced a comparably-structured prompt in **one pass, no skill** — it independently found the
  silent-failure spine, rejected the "someone forgets" framing as symptom-not-cause, demoted the
  tooling list to a conditional rung, and split verifiable-now from lagging acceptance.
- **The delta is real but narrower than the design assumed.** What the skill adds over baseline is the
  *mechanically derived* material: the lagging-indicator edge, the Prisma spec with executed scripts,
  the structural router's `dispositional / assistive_only` verdict, and an independently-verified
  red-team. What it does *not* add is the qualitative judgment — the model already had that.
- **The most-emphasised phase is the least-enforced.** RECOVER's artifacts are mandated in three places;
  RED-TEAM independence once. Yet the drop-list is where case A erred, self-critique missed both
  BLOCKING defects, and the independent red-team found them.

## Recommendation

→ **`agentic-tool-trainer`.** The evaluator is read-only by contract; the fixes below are the trainer's.

Ordered by severity:

1. Reconcile A9.1 — either license the long loop for `default`, or lower the floor beneath the cap.
   As written the two clauses cannot both hold.
2. Resolve A9.2 — state the lens-reuse rule as within-round explicitly, or expand the roster to ≥9.
3. Resolve A9.3 — either mandate `convergence-guard` on PHASE 3 (and accept that REFINE must use an
   independent critic), or stop citing `convergence-engine` as its primitive.
4. Fix B2 — make the drop-list obligation conditional on reaching DISTILL, or move DISTILL ahead of
   the halt. Currently it is an unsatisfiable `MUST`.
5. Close B5 — make `relate` non-skippable, or add referent-resolvability to DISSECT (it is the
   discriminating property of the empty-input class and currently exists only as a RELATE side effect).
6. Fix A9.7 paths, A9.5 router signal, A9.4 profile-section mismatch, A9.6 straddler contradiction,
   B1/B3 ambiguities, B4 off-by-one.

## Gate disposition

**The `persist-locus` gate is NOT cleared.** The evaluator has now run — the missing conjunct is
satisfied procedurally — but it returned `FAIL`. The ledger's `PERSISTED ⚠️ gate-incomplete` is
therefore **downgraded, not cleared**, exactly as that row promised.

---

*Artifacts: `/tmp/eval-rbtp/case-{A,B}.braindump.md` (synthetic; the operator's real braindumps were
not used — they remain objects of manipulation under a standing constraint). Traces reviewed for
secrets before writing; inputs are synthetic and contain no PII.*

---

# DELTA — v0.2.0 (fix round 1) and v0.3.0 (fix round 2)

`agentic-tool-trainer` `improve` mode, iterations 2 and 3 of a 3-iteration cap. Same golden-set,
same blind-agent protocol, author excluded from scoring throughout.

## v0.2.0 — re-evaluated. Three blocking defects VERIFIED repaired.

| # | Fix | How the independent agent verified it |
|---|-----|---------------------------------------|
| A9.1 + A9.2 | Floor is **profile-scoped**, not global | *"Was the predicate satisfiable? **Yes** — on this profile, and only because of the v0.2.0 repair."* The gate evaluated `false`, the floor switched off, the economic stop governed alone |
| A9.3 | Stopped claiming a master condition REFINE does not meet | Ran `bin/convergence-guard` and got the **exact predicted string**: `REFUSE correlated-verifier-violates-independence`. *"reproduces the skill's own predicted string verbatim"* |
| B2 | Drop-list `MUST` conditional on reaching DISTILL | Case B: *"The drop-list absence is explicitly licensed, not a gap"* · Case A: emitted, DISTILL reached |
| B1 + B5 | Referent check in DISSECT; `relate` non-skippable | Case B halted **at DISSECT** citing the new clause; ran `relate` anyway and found two undecidable edges the parts list cannot expose |
| A9.6, B3 | Straddler rule; resolution-paths | Case A kept `busque semelhantes`/`invoque Forge` as constraints; both cases emitted ranked resolution-paths and refused candidate goals |

**But both cases still terminated `STOP-HITL`.** The evaluator's own summary: *"The repair moved the
failure, it did not remove it."*

## The second generation of defects — and the two that were mine

Two independent agents converged on the same gap from opposite directions. Case B **predicted** it
(*"there is no proportionality clause on the referent-halt"*); Case A **hit** it (`sistema X`, the
one redacted token in an otherwise concretely-named dump).

| # | Defect | Origin |
|---|--------|--------|
| **C5** | The `RED-TEAM → REFUTED → REFINE` cycle is **unbounded**, with no precedence rule against the economic stop. Making the stop govern alone (the v0.2.0 fix) made the collision *structural*: refutation at round 4 demands a round 5 that is over-cap by construction | **introduced by the v0.2.0 fix** |
| **C1 + C3** | Same input, two halt sites — the pipeline block assigns unresolvable-referent to RELATE, the new §Typing clause assigns it to DISSECT. And the criterion has two readings that yield **different terminal states** | **introduced by the v0.2.0 fix** |
| **C4** | `profiles/default.md` still asserted the floor. **The fix landed in SKILL.md and not in the profile** — one surface of two. A second surface (the REFINE line in the pipeline block) was found only while repairing the first | **incomplete v0.2.0 fix** |
| C2 | No failure mode mapped a RECOVER halt to a STOP marker | pre-existing |
| C6 | `RENDER := … + persist decision` vs `--output-target` omitted → inline only | pre-existing |
| C7, C8, C9 | `--output=table` schema undefined · gate conjunct phase-ambiguous · PRISM applicability ambiguous, so its two failure modes were **never exercised** — *"I can confirm they are documented, not that they work"* | pre-existing |

## v0.3.0 — fixes applied, **NOT re-evaluated**

| Fix | What changed |
|-----|--------------|
| **C1 + C3 + Case-B proportionality** *(one root)* | DISSECT is the **single halt site for referents**; `relate` halts on graph properties only. Added the proportionality rule: a referent halts **only if the goal or the DoD depends on it** — otherwise carry it as a named open parameter into ESCALATION, never guess it. Worked contrast documented from both measured cases |
| **C5 + C2** | RED-TEAM refutations are **classified**: a *craft defect* returns to REFINE bounded by `--max-redteam-cycles` (default 2); a *missing fact about the operator's world* → `STOP-HITL` immediately, because no number of rounds can manufacture a fact the dump lacks. Explicit **precedence**: this outranks the economic stop, which caps iteration *within* REFINE only. Every halt now names a terminal marker |
| **C4** | Floor removed from `profiles/default.md` **and** from the REFINE line of the pipeline block, with the rationale inline so it is not re-added |
| **C6** | `persist decision` defined: the recorded *choice* of sinks; "inline only" **is** the record, not a no-op |

⚠️ **v0.3.0 carries no independent verification.** The trainer's iteration cap (3) is reached: eval →
fix → re-eval → fix. A fourth pass would exceed the bound the trainer sets, and the author re-scoring
his own third revision is precisely the correlated-verifier failure this report already documents
twice. **Status: v0.3.0 is an un-re-evaluated candidate.** The verified state of the world is v0.2.0
— three blocking defects repaired, a second generation open.

## Standing verdict

**FAIL → improved, still not PASS.** Two generations of blocking defects found and repaired under
independent verification; a third generation applied but unmeasured. The Pareto guard holds: no case
regressed across v0.1.0 → v0.2.0.

The finding that outlives the verdict: **the control produced a comparable prompt in one pass, with
no skill.** Two red-team passes at ~600k subagent tokens each found what six self-critique rounds
missed — which is the skill's own thesis confirming itself, and also its efficiency indictment.

**Next**: an independent re-eval of v0.3.0 by a fresh cycle — not by this one.

---

# DELTA — v0.3.0 RE-EVALUATED (the re-eval the line above asked for)

Four blind agents, dispatched in parallel against a **frozen artifact** (SHA verified identical to the
dispatch commit, tree clean — no edit entered mid-test). Three behavioral trials, one cold-start
operability interrogation with no run. Author excluded from all scoring; the author's role was
dispatch, repair of the dispatch, and this write-up.

## The method had to be repaired before it could measure anything

The first dispatch plan was red-teamed and returned **REFUTED**, four blocking. All four were real.

| # | Defect in the plan | Why it would have invalidated the result |
|---|---|---|
| B1 | `SKILL.md` names the two test cases' tokens **with their verdicts** (`fulano`→halt, `sistema X`→carry). | An agent applying the rule and an agent copying the example emit identical output *and identical citations*. The plan's self-report item was not a control. **Repaired by replacing the inputs, not by redacting the artifact** — redaction would have mutated the thing under test. New inputs verified token-disjoint (16/16 → 0, with a positive control proving the grep reached the file). |
| B2 | The trial directory held the plan itself and a solved DoD spec. | Leak. Repaired: one directory per trial, neutral filename, planner artifacts out of reach, `examples/` structurally absent rather than politely forbidden. |
| B3 | Sub-agent bound **4** — *below* the procedure's own mandated delegation count (~12-16). | Would fire in REFINE round 2; every reported TERMINATION would describe the harness, not the procedure. Raised to 24. |
| B4 | Iteration bound **12** — *numerically identical* to `--max-rounds=12`. | A run reaching 12 is indistinguishable between "procedure hit its cap" and "harness cut it off" — and which stop fires is the claim under test. Raised to 20. |
| **B5** | Found at dispatch time, in the repaired plan: nine items of report **format** and no **delivery channel**. | Four agents completed work they could not hand over; two idled twice with reports stranded. A report format is not a report path. |

**Confirmation the repairs mattered**: no harness bound was reached in any run (0 of 24 delegations
in two trials, 1 refuter in the third; 3 of 12 rounds). Every termination was the procedure's own.

## Claim-by-claim

| Claim | Verdict | Evidence |
|---|---|---|
| Floor removed from every surface | **HELD** | The interrogation enumerated 12 termination passages and returned `RESOLVED`: governing condition for `default` is the economic stop alone. **And** the executing trial evaluated the Verifiability Gate's three conjuncts to `false` and exited REFINE at **3 rounds** — under an unconditional floor it needs ≥6 by construction. |
| Classified red-team returns + precedence | **HELD** | All three disproof clauses passed; the precedence is written and names the exact arithmetic. The executing trial exercised the missing-fact branch live (1 of 2 cycles used, not exhausted). |
| Proportionality discriminates | **HELD** | The carry-open trial carried its role-named node open **on two axes**, refused to guess it (`Do not guess the identity of any of the four systems`), and proceeded through 4 of 5 phases. Both disproof clauses silent. |
| DISSECT is the single referent halt site | **DISPROVED** | Two passages in the same section make **opposite** phase assignments. One assigns the absent-referent class to RELATE; the other states "DISSECT is the single halt site for referents" and denies RELATE halts on naming — while elsewhere granting RELATE "goal-blocking dangles", which an absent referent in a dependency chain also is. |
| Every halt names a terminal marker | **DISPROVED** | **13 of 29 stop/refuse/escalate points carry no marker; 4 more are inferred.** Sink-refusal, gitleaks-abort and partial-sink-failure have no marker *and no field in the machine envelope*. |

**3 held, 2 disproved.** More precise than v0.1.0's flat FAIL: the surviving claims are now named, and
so is the reason the others do not survive.

## The self-check the document sets and fails

§Failure modes asserts: *"(Every halt names a terminal marker; a halt without one is an unfinished
rule.)"* Applied corpus-wide, **11 of the 13 markerless points sit outside §Failure modes** — in
§Skip conditions, §When not to use, §Output targets, §Multi-target semantics.

The rule was enforced where it lives, not across its domain. This is structurally identical to the
REFINE floor defect repaired three times in this same cycle — two surfaces, then four, then a seventh
in §Purpose, a summary paragraph that describes the rule without being it. Enumerating by *section*
finds the first kind; enumerating by *string* finds both.

## Findings no claim covered

- **The default path fails the skill's own membership test.** With `--output-target` omitted the
  document specifies *"return inline only"*. But `inline` is **not one of the five sink kinds**, so it
  has no Render cell — and criterion (b) of the skill's own test is *"RENDER DEFINED — the distillate
  has a defined form for that sink"*. Compounded: `--output=table` is the default and has **no
  schema** (`ABSENT` — it appears only as a default cell and an allowed value; §Output contract is
  titled `(--output=json)` and does not mention it). The no-flag path has neither sink render nor wire
  format. Corroborated behaviorally: two trials independently reported inventing the catalogue column
  schema and the relation-map format.
- **The leak gate is inert on the default path.** It fires *"whenever ≥1 target declares
  `shared-surface: yes`"*; `stdout` and `clipboard` are both `no`. A clipboard-only run — or the
  default inline path — never triggers it. The clause *"a leak aborts all targets — including
  clipboard, which is not exempt"* stays true and becomes vacuous: nothing aborts if nothing ran.
  Specification defect, not an observed leak — this artifact is a document, not a runtime.
- **The recursion clause is unimplemented in `default`.** It names `SCOPE` as that profile's *method
  section* and requires it to instruct the executing agent to decompose. `profiles/default.md` defines
  `SCOPE` as a declaration by the prompt's author, and the profile's eight sections contain no method
  section at all. The executing trial resolved this by applying the clause over the profile — one
  defensible reading of two.
- **Cited paths need an undeclared base.** Every internal path resolves, but only after choosing
  between repo-root-relative and skill-relative — and both bases appear in a single table cell. Four
  agents are cited without `.md` and fail `test -e` as written.
- **22 decisions the document does not make** for an agent holding only these files, a short input,
  and nobody to ask.

## The aggregate: three inputs, three classes, three halts, zero prompts

| Trial | Class | Halted at | Marker |
|---|---|---|---|
| t2 | referentially empty | PHASE 1 RECOVER / DISSECT | `STOP-HITL` |
| t3 | concrete goal, unnamed acceptance threshold | PHASE 1 RECOVER / DISSECT | `STOP-HITL` |
| t1 | carry-open (goal + DoD survive one role-named node) | PHASE 4 RED-TEAM, missing-fact | `STOP-HITL` |

Each halt is individually defensible and traceable to a quoted clause. But a skill whose stated
purpose is *"ONE polished, ready-to-execute PROMPT"* rendered **zero** across three classes, including
one input constructed to be renderable.

Two qualifiers, both supplied by the trials rather than by the author:

- t3's halt was independently derived from the document alone by the interrogation, so it is
  conformance, not drift.
- t1's halt sat **one defensible fork from rendering**. It recorded that treating the refuter's
  missing-fact as a fixable ESCALATION gap instead — adding the question, running one more REFINE
  cycle and a second red-team pass — would on a clean verdict have reached RENDER with `STOP-DONE`:
  the opposite terminal state, still inside the declared cycle budget (1 of 2 used).

So the halt surface is large; whether it is *too* large is not settled by three runs, and this report
does not claim it is. What is settled: the render path was not reached, and the document does not
adjudicate the fork that would have reached it.

## Standing finding, refined rather than repeated

The v0.1.0 standing finding was: *the control produced a comparable prompt in one pass, with no
skill.* This cycle sharpens it in both directions.

**Against the skill**: a competent agent must supply 22 decisions before it can finish a run. Much of
what looks like the skill working is the agent filling gaps.

**For the skill**: the one trial that reached the pipeline's interior produced material a single pass
does not. Its relation graph found that the operator's DoD is *the measurable inverse of the observed
symptom* — so acceptance reads the same signal that evidences the problem — and that the described
failure has *two independent facets* where fixing either leaves the loop intact. Both were marked
decisive; both are edges, not nodes. `derive-system-from-goal` fired on a recurring goal and produced
a signal admissible under the observability rule (*fires **and** moves*, not a run-count). The
independent refuter returned 10 findings, two of them missing-facts the draft's author had not seen —
including that the draft's own derived mechanism imposed a duty on a person without anyone asking
whether the operator had authority to impose it.

On a different input, that trial produced a finding of the same shape as one a previous dogfood had
gotten wrong and later corrected — that a resource list and a directive chain **intersect**, and that
saying the same thing twice in two syntaxes is emphasis rather than mass. **The trial declares this
was primed**, unprompted: `SKILL.md` narrates that earlier measurement inline, and the agent said so
rather than claiming independence. Recorded here as a primed application of a documented finding, not
as an independent re-derivation — the first draft of this delta claimed the latter, and was wrong.

That correction exposes a second contamination axis the method missed. B1 removed token-identity on
the axis under test (halt-vs-carry). It did not check that the document **narrates other prior
findings inline**, and those prime other moves. The repair was enumerated over the axis being
measured rather than over the domain — the same defect shape this report keeps finding elsewhere,
here committed by the eval's own author, in the eval's own method.

So the delta is real, and it is **mechanically-derived material plus independent refutation** — not
the qualitative judgment, which the control matched. The skill is not broken. It is
**under-specified**: its machinery earns its keep when the pipeline runs, and its document does not
yet tell a cold agent enough to run it the same way twice.

**Verdict: FAIL — 3 claims held, 2 disproved, 22 decisions undelegated.** The failure is
specification, not mechanism. The next cycle should close Q15's 22 before adding capability.
