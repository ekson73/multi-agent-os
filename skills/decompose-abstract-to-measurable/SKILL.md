---
name: decompose-abstract-to-measurable
description: >-
  Use when a task, DoR, DoD, metric, KPI, or acceptance criterion is ABSTRACT
  ("is this good / healthy / professional / beautiful / stylish / risky /
  inconclusive?") and an agent would otherwise GUESS a number. Decomposes the
  abstract construct into a recursive value-tree whose leaves are each directly
  measurable (D), typeable/observable (T), or bounded-calibrated-judgment (J),
  then a deterministic script rolls it up into score + band + confidence +
  sensitivity + an explicit "inconclusive → escalate" verdict. Turns a guess into
  a reproducible, auditable measurement-spec.
triggers:
  - "how do I measure <abstract quality>"
  - "is this <good|healthy|professional|beautiful|stylish|clean|risky>?"
  - "turn this DoD / KPI / acceptance criterion into a score"
  - "is this inconclusive / can I decide this autonomously?"
  - "score / rate / evaluate <thing> against an abstract standard"
version: 1.3.0
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
agnostic: [os, project, vendor]
soul-name: Prisma
---

# decompose-abstract-to-measurable  ·  soul-name **Prisma**

> A prism splits one white beam into its measurable component frequencies. This
> skill splits one abstract construct into its measurable component leaves — so
> an amnesic agent can **compute** "is this good?" instead of **guessing** it.

## What this is for (the root bug it fixes)

A human or agent hands you a task whose `[motive · purpose · DoR · DoD · metric ·
KPI · acceptance]` is **abstract** — "make it *professional*", "is this PR
*healthy*?", "is the release *quality-ready*?". You cannot compute an abstract
word natively, so the failure mode is: **you fabricate a plausible number and
ship the wrong result.** This skill replaces the guess with a transparent,
reproducible decomposition + a deterministic roll-up that *refuses to fake
precision* when the answer is genuinely judgment-bound.

## ⚠️ Honest verdict (read before you believe the thesis)

The originating thesis — *"everything is energy/frequency, so every abstract
concept fully reduces, without loss, to native math"* — is **UNPROVEN and
partly false**. The **strong** claim breaks against four independent, well-known
limits, and you must not pretend otherwise:

| Limit | What it means for this skill |
|---|---|
| **Hume is–ought** / **Moore open-question** | You cannot derive a *value* ("good") purely from *facts* ("has tests") — a value judgment is always injected. This skill makes that injection **explicit** (the weights + the J-leaves), it does not eliminate it. |
| **Harnad symbol-grounding** | "Beautiful" has no context-free numeric ground truth; it is grounded only relative to a stated purpose + audience. → Step 0 CONTEXT-LOCK is mandatory. |
| **Construct validity** (psychometrics) | A tree can be *reliable* (repeatable) yet *invalid* (measuring the wrong thing). Anchors + held-out validation manage this; they never fully close it. |
| **Goodhart's law** | The moment the score becomes the target, it stops measuring. → the score is **evidence, not a target** (Metron guard). |

**What the skill DOES deliver (the honest, still-powerful reframe):** the abstract
becomes **tractable, transparent, and calibrated**, with the **irreducible
residual of human judgment surfaced as a first-class output** (the J-leaves,
their confidence, and the `inconclusive → escalate HITL` verdict). "Energy /
vibration / frequency" is **evocative inspiration** (hence *Prisma*), not the
mechanism. The mechanism is 50-year-old prior art: **MCDA / AHP / MAUT value-trees**
+ decomposed-rubric LLM-as-judge + fuzzy [0,1] membership. See `PRIOR-ART.md`.

**Capability ≠ validation (SAGE v10.7 — ratified; do NOT overclaim).** Shipping/using this
skill advances the *tool's capability*; it does **not** validate the originating thesis.
Maturity rises **only** through external evidence — **E2** (a non-author-authored benchmark
with real margin to disagree) + **E3** (naive-agent inter-rater **κ ≥ 0.60**). Status (2026-07-09):
**E2 = not done**; **E3 = partially advanced, NOT closed** — `scripts/e3_kappa.py` (a reusable,
tested Fleiss'/Cohen's-κ harness) now exists and *two lean pilots* ran (`E3-PILOT.md`): a same-model
pilot scored **κ = 0.96** (self-consistency) and a within-Anthropic **cross-model** pilot (Opus 4.8 ·
Sonnet 5 · Fable 5) scored **κ = 1.0** — but that perfect agreement, *even on items the fixture designed
to split raters*, is **empirical evidence of same-vendor correlation** (`convergence-engine §4.7.5`),
NOT a pass. Both used **correlated** raters → genuine E3 still needs **cross-VENDOR (GPT/Gemini) / human**
raters + larger n + non-author constructs. So: the
defensible claim is **bounded, per structural class** (additive-decomposable
constructs only — Step 5b); **Tier-Professional is BLOCKED** until E2/E3; there is **no definitive
public name** yet. A better *method* is not a validation.

## The seam — deterministic skeleton × probabilistic muscle

The one thing that must never happen: the model doing the arithmetic in its head
and calling it a "measurement". Split the labour:

| Layer | Who | Does | Nature |
|---|---|---|---|
| **Probabilistic muscle** | You (the LLM) | author the tree · type each leaf D/T/J · write methods + anchors · **estimate** J-leaf graded values + confidence | `f > 0` (judgment lives here — where value is created) |
| **Deterministic skeleton** | `scripts/aggregate_spec.py` | weighted roll-up · confidence propagation · analytic sensitivity · residual + **inconclusive** detection · band | `f = 0` (repeatable, amnesia-proof, no arithmetic-in-head) |

You produce a **measurement-spec** (JSON). The script consumes it and returns the
number. The number is only as honest as the spec — which is why the steps below
are guard-railed.

**The one-sentence measurement answer** (rubric C2 — *"how would I measure this
tomorrow morning?"*): *"write the tree into the spec JSON and run `python3 scripts/aggregate_spec.py`
— score, confidence, sensitivity and the inconclusive verdict come back computed, never
estimated in my head."* Every construct decomposed here MUST have an equivalent
one-sentence answer before its spec is written; a leaf that cannot say how it would be
measured is not yet a measurable leaf.

## When NOT to use (skip — anti-over-engineering)

- The criterion is **already concrete** (`coverage ≥ 80%`, `all checks SUCCESS`) → just measure it; no tree needed.
- A **single** deterministic gate decides it → don't build a 4-branch tree for a one-liner.
- The decision is **trivial / reversible / low-stakes** → a one-line judgment is fine; reserve this for criteria that will be *reused* or *auto-gated*.

---

## Procedure (steps 0–8)

### 0 · CONTEXT-LOCK  *(hard gate — this is the cure for the root bug)*
Bind the construct to its context **before** decomposing. Reuse
`anti-theater-grounding-protocol` Layer 2 (2.1 context · 2.2 scope · 2.3
priority-focus · 2.4 motivation · 2.5 targets/stakeholder). "Professional for a
customer one-pager" ≠ "professional for an internal scratch note" — the tree and
weights differ. **Refuse to proceed on a context-free construct** — the script
enforces this: no `meta.context_lock` ⇒ `SpecError`. A context-free score is the
guess this skill exists to kill. The construct is also **instance-bound** — see the
individuation discipline in Step 1 (Q1): measure *this case*, not a generic average.

### 1 · DECOMPOSE → value-tree (a DAG) — by RQE (recursive-question elicitation)
Don't free-associate the tree — **elicit** it. Ask, of the construct and then recursively of
each node, a fixed question-taxonomy until every branch bottoms out at a measurable leaf (D/T)
or a stated-why-not-D/T judgment leaf (J). Each **answer becomes the next node's question**:

| # | Question (ask of the construct, then recurse into each answer) |
|---|---|
| Q1 | **WHAT is it?** → *individuate the specific object, then predicate* (see below) |
| Q2 | **by what CRITERIA is it good here?** → positive criteria branches |
| Q3 | **WHEN-NOT — what would make it FAIL?** → the via-negativa branch (→ each leaf's `anchors.negative`; some constructs are grounded best by their negation) |
| Q4 | **NECESSARY vs SUFFICIENT?** → a necessary-but-absent condition is a **veto-gate** (Step 6), NOT a tree leaf |
| Q5 | **CONTEXT / SCOPE / OBJECTIVE?** → locked in Step 0; re-check each sub-node inherits it |
| Q6 | **EVIDENCE / INSTRUMENT / METHOD?** → forces the node toward D/T, exposes a genuine J |
| Q7 | **GRADIENT?** → graded [0,1], not boolean (Step 3) |

RQE is a documented **protocol, not a new engine** — it *produces* the tree the other steps
score. It composes GQM · 5-Whys · construct-validity/nomological-network · AHP · Kelly
Repertory-Grid · means-end laddering (cite-only — `PRIOR-ART.md`). Termination is the leaf
gate below (D/T, or J-with-"why-not-D/T") + depth-cap + materiality-prune.

**Individuation — idiographic, not nomothetic (Q1 is instance-specific ON PURPOSE).**
A **generic** "what makes *something* viable?" yields only a population **average** (nomothetic,
Windelband 1894); you almost never want the average — you want *this case* (idiographic). So
bind Q1 to the instance: "what makes **Tese B** viable?" → decompose the *specific* object into
its **real parts** → then ask "what makes each part good?" per part (**decompose-object-then-
predicate**). Individuation **surfaces the part-level divergence a generic average would bury**
(see `examples/thesis-b-individuated.json`: the specific parts diverge → engine fires
`conflict:what`, refusing the comfortable mean). Modes: recursive · sequential · parallel.

Guards (non-negotiable):
- **depth-cap 3** (root→leaf) — over-decomposition is analysis-paralysis.
- **materiality-prune** — drop a branch whose global flow `< 0.05`; it can't move the answer.
- **shared sub-concept = one node with two parents** (a DAG, not a duplicated subtree).
- **no cycles** (the script rejects them) — recursion must bottom out.
- **deepen by sensitivity** — only split further the branches near a band boundary; leave settled branches shallow.

### 2 · LEAF-TYPING D / T / J  *(the anti-"everything-is-J" gate)*
Every leaf gets exactly one type, and **J is last resort**:
- **D — deterministic-measurable**: a number a tool/script computes (coverage %, diff size, CVE count → mapped to [0,1]).
- **T — typeable/observable**: a categorical fact you can classify/inventory (headings present? bots converged? migration present?).
- **J — bounded-calibrated judgment**: only after you can state **"why there is no D or T method"**. A J-leaf is a *decomposed-rubric LLM-as-judge* call, not a vibe.
- **Every leaf — including D and T — carries a `method` and `positive`+`negative` anchors.** The script **refuses an anchorless leaf** (`SpecError`) — an anchorless leaf is disguised guessing.

### 3 · GRADE fuzzy [0,1]
Each leaf value is a **graded membership** in [0,1] (Zadeh), not a boolean.
"82% coverage" → `0.82` against its anchors, not a hard pass/fail. J-leaves also
carry a **confidence** in [0,1] (how sure the judge is), separate from the value.
De-bias the judge: **order-swap** the rubric criteria / compared items to blunt
position, verbosity, and self-preference bias.

### 4 · WEIGHTS (transparent + elicited)
Assign sibling weights and **state the elicitation method** (swing-weighting /
direct-ratio / AHP pairwise). Weights encode the value judgment (Hume) — making
them explicit is the point. The script normalizes siblings to sum 1.

### 5 · AGGREGATE → call the script
Never roll up in your head. Write the spec to JSON and run:
```bash
python3 scripts/aggregate_spec.py --spec my-spec.json          # JSON out
python3 scripts/aggregate_spec.py --spec my-spec.json --md      # markdown table
```
You get: `score` · `band` (HIGH ≥.85 / MEDIUM ≥.65 / LOW) · `aggregate_confidence`
· `leaf_flows` (global weights, Σ=1) · `contributions` · `sensitivity`
(analytic Δ-to-flip per leaf) · `residual` · `inconclusive`.

### 5b · CLASS-ROUTE → is an additive tree even VALID here? (structural-fit gate)
The weighted-sum engine is a valid model **only for an additive construct**. Declare the
construct's `meta.structural_form` (+ optional `meta.h35_diagnostics`) and run the routing layer:
```bash
python3 scripts/structural_route.py my-spec.json
```
It cross-checks your **declared** form against the form its diagnostics **derive**, and routes
per the **SAGE v10.7 engine-anchored class matrix**:

| structural_form | routed verdict |
|---|---|
| additive / atomic (+ diagnostics) | **per_gates** — score stands; gate normally |
| relational · gestalt | **BLOCKED** — an additive tree structurally CANNOT represent it (`score → null`) |
| normative · dispositional · temporal | **ASSISTIVE (band-capped)** — advisory + human review |
| additive/atomic WITHOUT diagnostics | **ASSISTIVE (unverified)** — fail-closed |
| declared ≠ derived | **REVIEW** — the two channels disagree |

The demo: `examples/fair-relational.json` scores **1.0 / HIGH** via `aggregate_spec` but
**BLOCKED** via `structural_route` — because the additive tree can't see the *relation* a high
number hides. ⚠️ **Honest limit (shipped, not hidden):** a *consistent* liar who declares
"additive" and lies on every diagnostic still passes — `scripts/break_suite.py` **confirms** this
false-negative (A1). That boundary is **irreducible without external verification (E2)**; the
router closes evasion-by-omission (A2) and declared/derived conflict, not A1.

### 6 · GUARDS (built into the script + your reading)
- **Goodhart** — the score is **evidence, not a target** (Metron §5). Never tune the tree so a favored item "passes".
- **construct-validity** — is the tree measuring the construct, or something adjacent? Report coverage-by-anchors.
- **inconclusive is a first-class verdict** — the script raises `inconclusive.flag` on ANY of: `low_confidence` (agg-conf < 0.60) · `judgment_dominated` (Σ J-leaf flow ≥ 0.50) · `conflict:<branch>` (a material branch whose children's weighted-value stdev ≥ 0.25). **Threshold provenance (declared, per the number-source rule)**: these three are **uncalibrated heuristic defaults** — chosen by judgment, NOT measured against a labeled set and NOT pinned from an external reference. They are **operator-tunable parameters** (override per decision criticality: stricter for irreversible, looser for exploration). If a calibration set ever exists (held-out anchors with known outcomes), re-derive them from it and delete this paragraph — an uncalibrated number that pretends to be measured is worse than one that declares itself. (Rubric anchor: `docs/rubrics/v0.1/decompose-abstract-to-measurable.md` C1) **On inconclusive → abstain + escalate HITL** (`convergence-engine` DEFER regime). A high J-share is not a bug to hide — it is the true statement "this needs human judgment".
- **non-compensatory veto-gate** — weighted-sum is *compensatory* by nature, so a **hard blocker** (unresolved critical CVE · secret leak · irreversible-prod · any absolute no-go) must be a **deterministic pre-gate that vetoes to LOW / no-go**, NOT a tree leaf — else a high sibling averages the blocker away (the `conflict` detector only catches it when siblings *disagree* AND the branch is material). The tree grades the *negotiable* qualities; absolute blockers gate **before** it.

### 7 · VALIDATE against held-out anchors
Calibrate the tree against **held-out exemplars you did NOT use to set weights**
(positive / negative / **boundary** cases). A tree that only passes its own
tuning examples is **not validated → treat as inconclusive** (Goodhart on the
calibration set). Prefer an independent re-typing of a sample (verifier ≠
generator — e.g. `maos:validation-auditor`). Honesty nod: the **inconclusive
thresholds themselves** (`conflict 0.25` / `residual 0.50` / `conf 0.60`) are
heuristic defaults that carry injected judgment — they are overridable per-spec
and warrant the same held-out validation as the tree.

### 8 · PERSIST the measurement-spec (versioned)
Write the spec (tree + weights + methods + anchors + thresholds) to a versioned
file so the **next amnesic agent re-runs it, does not re-derive it**. The spec IS
the reproducible artifact; the score is just its latest evaluation.

---

## Composition-map (cite-only — this skill re-derives none of it)

| Borrowed capability | Source (do not rebuild) |
|---|---|
| band boundaries (HIGH .85 / MED .65) | `~/.claude/rules/auto-self-harness.md` §1.2 autonomy_score |
| Goodhart guard · score=evidence · residual | `~/.claude/rules/agentic-observability-protocol.md` (Metron) §4/§5 |
| REFINE/SELECT/**DEFER** · verifier>generator · economic-stop | `skills/convergence-engine/SKILL.md` |
| per-leaf measurement + evidence capture | `maos:data-validator` |
| independent re-typing (verifier≠generator) | `maos:validation-auditor` |
| CONTEXT-LOCK (Layer 2) + reality gate (Layer 5) | `~/.claude/rules/anti-theater-grounding-protocol.md` |
| leaf grounding limit (why J can't fully vanish) | Harnad symbol-grounding (see `PRIOR-ART.md`) |
| structural-form class matrix (additive/relational/gestalt/normative/…) | SAGE v10.7 → `scripts/structural_route.py` + `PRIOR-ART.md` |
| RQE elicitation (GQM · 5-Whys · Repertory-Grid · laddering) + nomothetic↔idiographic | Step 1 + `PRIOR-ART.md` |

## I/O contract (see `templates/measurement-spec.schema.json`)

**Spec (in):** `meta.construct`, **`meta.context_lock`** (required — Step 0),
optional `thresholds`, and `nodes[]`. Each node: `id`, optional `label`,
`parents:[{id,weight>0}]` (root has none), `kind:"branch"|"leaf"`. Each **leaf**
adds: `leaf_type:"D"|"T"|"J"`, `value` ∈ [0,1], `confidence` ∈ [0,1], optional
`raw`/`method`, and **`anchors:{positive, negative}`** (required).

**Result (out):** `score`, `band`, `aggregate_confidence`, `leaf_flows`,
`contributions[]`, `sensitivity[{pivot,delta_to_flip,flips_to}]`,
`residual{j_weight,judgment_dominated}`, `inconclusive{flag,reasons[]}` where
reasons ∈ `low_confidence | judgment_dominated | conflict:<branch>`. Exit codes:
`0` ok · `2` unreadable spec · `3` spec **refused** (`SpecError` — context-free,
anchorless, cyclic, or too deep).

See `examples/`: `pr-healthy` (conclusive HIGH) · `doc-professional` (judgment-dominated →
inconclusive) · `quality-conflict` (conflicting branch → inconclusive) · **`fair-relational`**
(additive engine says HIGH but `structural_route` **BLOCKS** — the class-matrix demo) ·
**`thesis-b-individuated`** (§13 individuation → `conflict:what`, MEDIUM — refuses the average).
`structural_route.py` additionally emits `route{status,allowed_use}` · `context_signature` ·
`loss_vector`, and may override `band` to **BLOCKED / REVIEW / ASSISTIVE**.

## Anti-patterns (do NOT)

1. ❌ **Score a context-free construct** — skipping Step 0. (The script refuses it; don't route around by faking a context_lock.)
2. ❌ **Type everything J** — the disguised-guess this skill exists to kill. J requires a stated "why not D/T" + anchors.
3. ❌ **Roll up in your head** — always call the script; arithmetic-in-head is not a measurement.
4. ❌ **Fabricate a precise number over a real residual** — if `judgment_dominated` / `low_confidence` / `conflict` fires, report *inconclusive + escalate*, never a false-precise score (anti-theater R3/R4).
5. ❌ **Tune the tree so a favored item passes** — Goodhart; the calibration set is held-out, and a tree that only fits its tuning examples is inconclusive.
6. ❌ **Over-decompose** — depth-cap 3, materiality-prune, deepen only near band boundaries. A 30-leaf tree for a reversible call is over-engineering.
7. ❌ **Believe the strong thesis** — say "tractable + calibrated + bounded residual", never "abstract fully reduced to native math".
8. ❌ **Score a non-additive construct with the additive tree** — run `structural_route.py` first; relational/gestalt are **BLOCKED**, not "score anyway". A high additive number on a relational construct (see `fair-relational`) is a *false* measure, not a good one.
9. ❌ **Overclaim validation** — "capability shipped" ≠ "thesis validated". Maturity is gated on E2/E3 (SAGE v10.7); never imply Tier-Professional or a definitive public name.
