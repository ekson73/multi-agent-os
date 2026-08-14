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
