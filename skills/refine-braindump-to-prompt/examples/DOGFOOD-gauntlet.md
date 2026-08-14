# Dogfood — the originating braindump

Run: `/refine-braindump-to-prompt "<gauntlet.braindump.md>" --architecture=gauntlet-loop`
Date: 2026-08-14. Full audit trail, including what was dropped and what each round changed.

The gate this run had to clear: **if the skill cannot lapidate the braindump that originated it,
it failed.** The rendered prompt must contain (a) a machine-verifiable goal, (b) an independent
critic, (c) an explicit stopping rule.

---

## PHASE 1 · RECOVER

**Source**: `braindump` (ladder rank 2 — the operator's own words about this work).

### Recovered

| Field | Value |
|---|---|
| **motivation** | prompts that drive agents to complete projects/tasks end-to-end with **minimum HITL** |
| **DoR** | the Gauntlet Loop architecture must be understood before generating — satisfied: 7 sources read (operator's notebook incl. an 11.9k-char PT-BR report) + independent public corroboration |
| **goal** | produce a reusable capability that **generates Gauntlet-Loop-compliant prompts** for arbitrary targets |
| **condition (DoD)** | a generated prompt is compliant ⟺ it carries a named external bar · an independent critic · directly-inspectable evidence · an explicit stopping rule. Each is binary-checkable → measurable, not a wish |
| **loop spec** | `min_revisions ≥ 3` **AND** `consecutive_clean_rounds ≥ 3`, `lenses = 3` distinct per round |
| **recurring?** | yes → the capability must be a standing mechanism, not a one-shot artifact |

### Dropped as session-meta (listed, never silent)

| Dropped | Why |
|---|---|
| "Analise, critique, busque/pesquise semelhantes… invoque Anima… invoque Forge…" | the `/enhance` ritual wrapper — it describes *how this session should run*, not the work |
| "Organize e entenda este próprio prompt antes de executá-lo" | meta-instruction about the dump itself |
| The `[scripts, flows, processes, … marketplaces]` cartesian list | a list of *available* resources offered as examples. **A listed resource is not a requirement to instantiate it** |
| The 40+ `--principles` list | already codified as auto-loaded governance in the host corpus — referenced, never inlined (inlining would duplicate an SSOT) |

> The cartesian list is the single largest token mass in the braindump and contributes **zero**
> constraints. Recovering the goal required deleting most of the text — which is the job.

---

## PHASE 2 · DRAFT (v0)

First cut in the `gauntlet-loop` shape. Recorded here because the REFINE log below is meaningless
without the thing it criticised.

> TASK: build agentic tooling that generates efficient and effective Gauntlet-Loop prompts.
> BUILD-METHOD: fan out sub-agents; each takes one piece; a separate sub-agent critiques.
> QUALITY-BAR: the prompts should be efficient and effective, driving end-to-end completion.

---

## PHASE 3 · REFINE

`--lenses=3` distinct per round; a repeated lens does not count toward `clean_rounds`.

### Round 1 — lenses: `bar-nameability` · `critic-independence` · `stop-rule-presence`

| Lens | Finding | Fix |
|---|---|---|
| bar-nameability | ❌ "efficient and effective" is an **adjective**, not a bar. This is precisely the failure the Extreme-Reference lever exists to prevent: the model resolves it against its own average prior and stops early | QUALITY-BAR must name an **external artifact**: a prompt is compliant only when an independent reader can execute it cold and reach the DoD without asking a question |
| critic-independence | ❌ draft says "a separate sub-agent" but never that it lacks build context — "separate" is satisfied by a second call in the same conversation | CRITIC gets a **fresh context, no build history**, and is prompted to REFUTE |
| stop-rule-presence | ❌ no cost ceiling, no wall-clock, no attempt cap, no stagnation delta — the braindump inherits Shumer's *"you are the brake"* | STOP block made mandatory; unbounded refused |

**revisions = 1 · clean_rounds = 0**

### Round 2 — lenses: `evidence-inspectability` · `decomposability` · `blast-radius`

| Lens | Finding | Fix |
|---|---|---|
| evidence-inspectability | ❌ "the prompt is effective" is not directly observable — the critic would be **guessing**, which silently voids the Verifiability Gate | EVIDENCE named: the generated prompt text itself + a cold-execution trace + the count of clarifying questions the executor had to ask (an observable proxy for minimum-HITL) |
| decomposability | ⚠️ "one or more agentic-tools" leaves the unit of judgement undefined | one judgeable unit = **one generated prompt**, judged whole |
| blast-radius | ✅ generating a prompt is cheap and reversible — a long loop is admissible here | none |

**revisions = 2 · clean_rounds = 0**

### Round 3 — lenses: `completeness` · `executability` · `falsifiability`

| Lens | Finding | Fix |
|---|---|---|
| completeness | ❌ the **target is unnamed** — a generator with no target renders nothing. A fresh amnesic agent would have to invent one | TARGET promoted to a **required slot**; absent → refuse and ask, never invent |
| executability | ✅ every instruction maps to a named tool | none |
| falsifiability | ✅ acceptance is now four binary checks | none |

**revisions = 3 · clean_rounds = 0**

### Rounds 4, 5, 6 — rotating lens sets, no new findings

| Round | Lenses | Result |
|---|---|---|
| 4 | scope-drift · failure-path · bar-nameability | clean |
| 5 | critic-independence · evidence-inspectability · stop-rule-presence | clean |
| 6 | decomposability · completeness · falsifiability | clean |

**revisions = 3 · clean_rounds = 3 · rounds = 6 (cap 12)**

`stop_refine := (3 ≥ 3) AND (3 ≥ 3) AND (6 ≤ 12)` → **EXIT**

> Note what the floor bought. Round 1 found three defects in a draft that read fluently. Had the
> loop been allowed to exit on one clean pass, it would have shipped an adjective as a quality bar.

---

## PHASE 4 · RED-TEAM

Independent refuter, no REFINE context, prompted to break the prompt.

| Attack | Verdict |
|---|---|
| "The bar is still soft — 'execute cold without asking' is judgeable but subjective" | **PARTIALLY LANDS** → mitigated: the observable is the *count of clarifying questions*, a number, not an impression |
| "The critic could lower the bar silently across rounds" | **HELD** — the bar is written into the prompt and the critic is forbidden from restating it |
| "The stopping rule could be satisfied by three trivially-clean rounds" | **HELD** — a round only counts if it uses a distinct lens set |
| "The Verifiability Gate is asserted, not evaluated" | **LANDS** → fixed: the gate is now evaluated explicitly in the rendered prompt's header, with its three conjuncts shown |

**Verdict: CLEAR** (after folding the two landing findings).

---

## PHASE 5 · RENDER

### Verifiability Gate — evaluated, not assumed

| Conjunct | Value | Evidence |
|---|---|---|
| `bar_is_machine_verifiable` | ✅ | four binary checks + a countable clarifying-question metric |
| `critic_is_independent_of_builder` | ✅ | fresh-context refuter, enforced by `bin/convergence-guard` |
| `evidence_is_directly_inspectable` | ✅ | the prompt text + a cold-execution trace are directly readable |
| **`long_loop_licensed`** | **true** | → profile budget applies, not the bare economic stop |

### The rendered prompt

```text
TARGET (required — refuse and ask if absent): <the work to be driven>

TASK
Generate ONE prompt that drives an agent (or team) to complete TARGET end-to-end
with minimum human-in-the-loop.

BUILD-METHOD
A lead agent decomposes TARGET into the smallest independently-judgeable pieces.
Fan out one builder per piece; parallelise only pieces that are genuinely independent.
Each piece is gated by a critic before it counts as done.

QUALITY-BAR
The generated prompt is compliant if and only if all four hold:
  1. it names an EXTERNAL reference for "good" — never an adjective;
  2. its critic is independent of its builder;
  3. its evidence is directly inspectable by that critic;
  4. it carries an explicit stopping rule.
Operational bar: a competent executor who has never seen this conversation can run
the prompt cold and reach the DoD. Measured by the number of clarifying questions
they must ask. Target: zero. This number is the acceptance signal — do not restate
the bar in softer words at any point.

CRITIC
A separate agent, FRESH CONTEXT, with no visibility into how the prompt was built.
Prompted to REFUTE, not to approve. It compares the candidate against the four
checks above, blind. It may not lower the bar; if it cannot refute, it says so.

EVIDENCE
The critic may directly inspect: the candidate prompt text; a cold-execution trace;
the clarifying-question count. It may not infer quality from the build story.

STATE
Persist every attempt, every refutation and every clarifying question OUTSIDE the
conversation, so round N knows what round N-1 already failed.

STOP
Exit when: revisions >= 3 AND consecutive gap-free rounds >= 3 (each round using a
distinct lens set). Hard caps: 12 rounds; an operator-set cost ceiling; an
operator-set wall-clock. Exit early on gain-stagnation (round-over-round delta below
threshold twice). Unbounded running is refused — if no cap is set, stop and ask.

ESCALATION
Halt and escalate to a human when: TARGET is absent or ambiguous; the work becomes
irreversible, costly or unobservable; a guardrail surface is touched (secrets, PII,
production, cross-org); or the caps above are exhausted.
```

---

## Verdict

| Dogfood gate | Result |
|---|---|
| (a) machine-verifiable goal | ✅ four binary checks + a countable metric |
| (b) independent critic | ✅ fresh context, refute-prompted, may not restate the bar |
| (c) explicit stopping rule | ✅ two-part predicate + three hard caps + stagnation exit |

**PASS.** The skill lapidated the braindump that originated it.

The dropped mass is the finding worth keeping: the braindump's longest passages — the cartesian
resource list and the 40-principle enumeration — contributed **zero** constraints to the rendered
prompt, while the shortest clause (`mínimo HITL`) became the acceptance metric.
