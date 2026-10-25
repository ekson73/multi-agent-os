---
name: ratchet-loop
version: "0.1.0"
description: |
  Round-scored productivity loop (HOTL — Human Out The Loop within an inviolable HITL floor)
  that drives ONE round of six phases over an intent tree, BOTH directions: RECOVER (backward,
  leaf→project) → MEASURE (4 counters, at source) → DECIDE (forward, project→leaf, smallest
  node set that moves a counter) → EXECUTE (one worker per resource boundary) → VERIFY
  (evaluator verdict AND conductor re-measurement) → INTROSPECT (two gates: Repair on a
  refuted premise, Evolution on a measured gain). A round that moves none of the four counters
  is BUSY, not virtuous, and says so. Net-new is only three things: the bidirectional round
  contract, the 4-counter gate (incl. refuted-premises, which nothing else counts), and a
  FALSIFIABLE introspection trigger with a same-round all-surface repair obligation. Thin
  preset: composes work-compass, pulse, eisenhower-matrix, ooda-loop, gap-loop, quiesce,
  convergence-engine, decision-capture, agentic-session-harness, corpus-firing-audit,
  praxis-audit, rule-quality-tests, dogfood-ledger, ttl-policy, status-map, audit,
  agentic-tool-pipeline, agentic-tool-trainer — reimplements nothing.
  Triggers: "ratchet-loop", "ciclo virtuoso", "virtuous cycle", "HOTL cycle",
  "retro-fed productivity round", "meta-cognitive round", "did this round move anything".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: orchestration-convergence
  cross_link_slug: ratchet-loop
  dogfood_status: pending-first-cycle
---

# Ratchet-Loop

Thin **round-scored productivity-loop** preset. A ratchet turns one way and cannot slip
back: each round must click forward **at least one measured tooth**, and a correction made
in one round must not un-correct in the next. That is the whole contract.

`ratchet-loop` does not re-implement tree building, prioritization, delivery, convergence,
decision logging, rule validation, corpus auditing, promotion counting, or tool genesis. It
**composes** the eighteen assets named in §Composition and contributes only what none of
them holds: a **bidirectional round** over one intent tree, a **four-counter gate** that
calls an unproductive round unproductive, and a **falsifiable introspection trigger**.

> **Honesty clause, load-bearing.** The word *virtuous* is a claim, not a property. This
> skill is named for the **mechanism** (a ratchet that clicks or does not) and keeps the
> operator's vocabulary in its triggers, so the identity never asserts the outcome the
> counters exist to test. A round that moves no counter is reported **BUSY**.

## §0 — BEING > Rules (foundational)

This skill serves the operator's intent. If a phase or gate obstructs delivering value NOW,
skip it, log `Skipped <phase> — BEING > Rules`, and proceed. Gates are for quality, never
ritual. The §HITL floor is the one thing §0 does **not** unlock.

## Purpose

Drive productive work in **rounds** that feed the next round, under HOTL autonomy, so that:

- intent is **recovered**, never assumed (the leaf knows why the project wants it);
- "productive" is **measured**, never asserted (four counters, at source);
- a wrong belief is **repaired everywhere it was repeated**, in the round that refuted it;
- a measured win is **generalized into a rule** with its cause attached;
- the loop **stops**, on a declared predicate, instead of running forever.

## When to use

- A multi-round push where the operator is out of the loop by design and expects the wheel
  to get better each turn, not merely to keep spinning.
- Work has been *busy* — items moved, nothing landed — and you need the round itself scored.
- A premise you acted on was refuted at source and the same claim is sitting in several
  places (a broadcast, a saved lesson, a ledger, a report).

## When **not** to use

- ONE goal's gaps need driving to convergence → `gap-loop`.
- ONE delivery pass needs driving to a measurable DoD → `ooda-loop`.
- The SESSION needs emptying to steady state → `quiesce`.
- You only need the work landscape, or only a priority order → `work-compass` / `pulse` /
  `eisenhower-matrix`.
- A single task, one shot, no next round → just do it. A round is overhead you have not earned.

## Trigger Phrases

- "ratchet-loop" / "/ratchet-loop"
- "ciclo virtuoso" / "virtuous cycle" / "HOTL cycle" / "retro-fed productivity round"
- "did this round move anything" / "score this round" / "meta-cognitive round"

## A round — the six phases

A **round** is one turn of the wheel. The tree is walked **backward** to recover intent,
then **forward** to decide work. Same tree, two directions, once per round — not a cycle per
node (see §Decisions, D1).

```text
PHASE 1 · RECOVER (backward)   leaf→root: subagents ← ai-session ← steps ← tasks
                               ← [DoR, DoD, Goals, Targets, Deliverables, Expectables]
                               ← motivations/intentions ← project.
                               Output: the measured intention chain + 5why & 5w2h on the
                               node actually in work.                        [CONDUCTOR]

PHASE 2 · MEASURE              the four counters, AT SOURCE. A counter that cannot be
                               measured is emitted `NOT VERIFIED` — never estimated and
                               presented as fact.                            [DELEGATED]

PHASE 3 · DECIDE (forward)     root→leaf: pick the SMALLEST node set that moves at least
                               one counter; Eisenhower over that set.
                               Never delegated — the chooser must hold the whole tree.
                                                                             [CONDUCTOR]

PHASE 4 · EXECUTE              one worker per RESOURCE BOUNDARY (repo · tracker · token).
                               The conductor does not execute.               [DELEGATED]

PHASE 5 · VERIFY               evaluator verdict AND conductor re-measurement at source.
                               A worker's claim is a claim; it is never the acceptance.
                                                                             [CONDUCTOR]

PHASE 6 · INTROSPECT           two gates, below.                             [CONDUCTOR]
```

### Phase 6 — the two gates (they are two mechanisms, not one; see D2)

| Gate | Trigger (falsifiable) | Obligation |
|---|---|---|
| **REPAIR** | a premise this round **refuted at source** | fix **every** surface that repeats it — broadcast, saved lesson, ledger, report, asset — in the **same round**. A refuted premise left standing anywhere becomes the next round's input. |
| **EVOLUTION** | something worked with a **measured** gain | generalize it into a rule with the **measured cause pasted in** (§How a rule enters this asset), then route promotion through `dogfood-ledger` and expiry through `ttl-policy`. |

Nothing fires either gate but those two triggers. "It felt better" is not a trigger; neither
is "no findings this round".

## The four counters (the discriminator between virtuous and busy)

| # | Counter | Direction | Measured from |
|---|---|---|---|
| C1 | **items accepted per round** | up | the work ledger's terminal states (`audit` for the trail) |
| C2 | **premises refuted per round** | up early, down late | this skill's own round record — **net-new**, nothing else counts it |
| C3 | **orphan rate** (live items with no ticket) | down | `work-compass` stale/orphan detection |
| C4 | **fixed-overhead bytes per session** | down | `status-map` / `audit` readout of session shape |

**The gate**: a round that moves **none** of C1–C4 is reported `BUSY` with the counters
beside it. Two such rounds in a row is an exit condition (§Exit), not a reason to try harder.

C2 is deliberately non-monotone: early rounds *should* refute more (the corpus is being
corrected); late rounds refuting a lot means the corpus is being re-broken, which is a
Repair-gate finding about the loop itself, not progress.

## Persistence — five sinks per round, none of them new

| Sink | Carries | Owner |
|---|---|---|
| work ledger | the items | host work-ledger primitive |
| session ledger | phase + resumable next intent | host session-ledger primitive |
| conductor memory | the lessons | host memory primitive |
| host steering | local facts (install-specific, machine-specific) | host steering files |
| **this asset** | the mechanics | `skills/ratchet-loop/SKILL.md` |

A round that writes nowhere did not happen. A round that invents a sixth sink is over-engineered.

## Quality gates (every round passes all five)

| Gate | Test |
|---|---|
| **SOTA** | reuse the state of the art; inventing where an asset exists is a FAIL |
| **SSOT** | one canonical home per fact; a second home is a FAIL |
| **DRY** | compose, never reimplement (§Composition is the proof) |
| **ANTI-THEATER** | no claim without a measured cause; an unmeasurable claim ships labelled `NOT VERIFIED` |
| **ANTI-OVER-ENG** | the smallest mechanism that delivers; a phase nobody needed this round is logged skipped |

## Exit

Stop and ask when **any** of these holds:

```text
CONVERGED   every open node terminal AND no counter moving
     OR     24 rounds
     OR     12 hours
     OR     two consecutive rounds with ZERO acceptances
```

Reaching a cap is **not** success; it is a stop with a reason. Say which clause fired.

## HITL floor — inviolable, even under HOTL

HOTL covers the technical and the reversible. It does **not** cover:

```text
credential · spend · irreversible · production data / PII · peer configuration
```

These escalate as **recommended options with the measurement attached** — never
self-authorized, and `§0 BEING > Rules` does not unlock them (see D7).

## How a rule enters this asset

A rule may be written here **only** with a cause measured at source.

1. **Measured cause** (a command and its output, a file read, an API answer) → may be written
   as fact.
2. **Cause inferred from tool output** → it is a **hypothesis**. It ships labelled
   `HYPOTHESIS`, or it does not ship. Truncated or partial output is inference, not measurement.
3. A rule whose cause is later refuted at source fires the **Repair gate**: correct this
   asset *and* every other surface repeating it, same round.

This rule exists because it was **broken**, which is the only reason worth writing one down.
In a round before this asset existed, the conductor stated a fixed-overhead figure of ~40k
tokens; a delegated measurement returned ~18k. In the same round it reported a gateway as
down while that gateway was answering. Both claims were inferences from partial tool output,
presented as measurements. An asset that teaches a wrong cause is worse than no asset,
because nobody re-measures what the asset already "knows".

## Composition — what I do **NOT** reimplement (line by line)

Eighteen assets exist and cover the parts below. Each row names the owner; this skill emits
the invocation and never inlines the logic. **Without this table the skill is over-engineered.**

| Part of a round | Covered by (do NOT reimplement) | So `ratchet-loop` does not… |
|---|---|---|
| P1 — build the N-Tree of live work | `work-compass` | write a tree walker |
| P1 — refresh state, re-orient, route pending | `pulse` | write a recap/re-orientation pass |
| P3 — urgent × important classification | `eisenhower-matrix` | write a prioritizer |
| P4 — drive ONE node's delivery to a measurable DoD | `ooda-loop` | write a delivery loop |
| P4 — drive a gap-shaped node to convergence (MoE resolve + independent audit) | `gap-loop` | write a per-gap resolve/validate loop |
| P4 — drive the whole session to "nothing pending" | `quiesce` | write a session steady-state driver |
| P3/P5 — result-quality regime + economic stop (plateau, keep-best) | `convergence-engine` | write a scorer or a stop rule |
| P5 — per-decision audit trail with spec-alignment | `decision-capture` | write a decision log |
| P5 — session journal, transcript trace, cross-session walkthrough | `agentic-session-harness` | write session observability |
| P6 Repair — is a standing rule firing, dormant, or theater? | `corpus-firing-audit` | write a corpus scanner |
| P6 Repair — did **this round's own methods** fire or perform? | `praxis-audit` | write a self-method audit |
| P6 Evolution — is the candidate rule self-valid (6 tests)? | `rule-quality-tests` | write rule-validity tests |
| P6 Evolution — has the generalization earned promotion (≥2 real cycles)? | `dogfood-ledger` | count its own cycles |
| P6 Evolution — when does the rule expire / go stale? | `ttl-policy` | write a freshness policy |
| C1 — accepted items, and the trail behind them | host work ledger + `audit` | write an item store |
| C3 — orphan rate (live items with no ticket) | `work-compass` | write orphan heuristics |
| C4 — fixed-overhead bytes per session | `status-map` / `audit` | write a token accountant |
| a round needs a **new** agentic-tool | `agentic-tool-pipeline` (→ `agentic-tool-forge` + `anima` + `converge` + `decision-capture`) | author tools inline or name them itself |
| a round found an existing tool weak | `agentic-tool-trainer` | re-train inline |

### Net-new — exactly three things

| # | Net-new | Why nothing above holds it |
|---|---|---|
| **N1** | the **bidirectional round contract** (backward recover → forward decide over the SAME tree, once per round) | `work-compass` builds the tree; `pulse` refreshes it; neither contracts a two-direction round, and `gap-loop`'s RECAP enumerates a flat register, not an intent hierarchy |
| **N2** | the **4-counter productivity gate**, including C2 (**premises refuted**) | `gap-loop` scores *result quality* (`autonomy_score`); `convergence-engine` scores *verifiability*. Neither asks "did the wheel turn", and nothing in the corpus counts refuted premises |
| **N3** | the **falsifiable introspection trigger** + same-round **all-surface** repair obligation | `praxis-audit`/`corpus-firing-audit` audit on demand; neither is *triggered* by a refuted premise nor obliges fixing every surface that repeats it within the round |

Everything else delegates. The proof is runnable: grep a round's trace and only invocations
of the rows above plus native read/measure tools should appear.

## Relationship to siblings

| Tool | Scope | Drives | Scored on |
|---|---|---|---|
| `ratchet-loop` (this) | a **round** of productive work | 6 phases, both tree directions | 4 productivity counters (did the wheel turn) |
| `gap-loop` | ONE goal as a gap-register | 5 phases, self-driven | gap disposition + derived `autonomy_score` (is the result good) |
| `ooda-loop` | ONE delivery pass | outer OODA + inner PDCA | a measurable DoD |
| `quiesce` | the SESSION | termination predicate over all open items | nothing pending |
| `auto-pilot` | ONE goal | decompose → spawn → converge | goal met |
| `convergence-engine` | result quality | REFINE / SELECT / DEFER | verifiability + economic stop |

`ratchet-loop` **invokes** these inside Phase 4 and never re-expresses them. Rule of thumb:
*one goal's gaps* → `gap-loop`; *one delivery* → `ooda-loop`; *empty the session* → `quiesce`;
*a wheel that must get better each turn, and prove it* → this preset.

## STOP-marker grammar (reused — emit exactly ONE as the last line of each turn)

```text
<!--ORCH-STATUS: STOP-DONE -->     CONVERGED — every open node terminal, no counter moving
<!--ORCH-STATUS: STOP-HITL -->     HITL floor hit, OR an exit cap fired (round/time/zero-acceptance)
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (worker / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      round closed; counters moved; next round opens
```

## Protocol Rules (bounds)

- **Source before assertion**: a command and its output, or the label `NOT VERIFIED`.
- **Measured cause**: a cause inferred from tool output is a `HYPOTHESIS` and ships labelled.
- Phase 3 is **never** delegated; Phase 4 is **never** executed by the conductor.
- Phase 5 requires conductor re-measurement; a worker's claim is never the acceptance.
- One worker per **resource boundary** (repo · tracker · token) — never two on one boundary.
- Worktree discipline always on (`skills/worktree-policy`); never commit to main.
- Delegation depth ≤ 2; parallel ≤ 3.
- Report only at a real milestone; `artifacts` is a key→pointer map, never prose.
- A refusal **with a one-line reason** is a legitimate answer.
- Never mutate a credential, a gate, an allowlist, or peer configuration. Never buy anything.
- Exactly ONE STOP marker per turn.

## DNA Geracional (inherited by every spawned worker)

Pass the verbatim DNA Heritage Block (`protocols/delegation/delegation-dna-prompt.md`) in
every Phase-4 worker prompt, carrying: the five quality gates, the source-before-assertion
rule, the measured-cause rule, the HITL floor, and the item's own acceptance condition.
Continuity across compact/clear rides the existing `postflight` P3 seed — not re-authored here.

## Quality Tests (6/6 self-validity — `rule-quality-tests`)

1. **Self-Application** — this skill was forged *by the pipeline it names*: `agentic-tool-pipeline`
   Stage-0 classified the spec as a bare INTENT → `agentic-tool-forge`; Stage-1 EXPAND measured
   the corpus (18 assets present; no asset carrying "virtuous cycle" / "retro-fed" / "meta-cognitive"
   / "HOTL" as its subject — the two grep hits were a council **lens** name and an agent persona
   line, not a duplicate); Stage-2/3 converged **type = skill** and rejected command/rule/agent;
   `anima` named it (agent register) — `ratchet-loop`, rejecting `virtuous-cycle`. ✅
2. **Non-Contradiction** — it orders the corpus's loops without duplicating them; its own
   §Composition table is the test, and `gap-loop`/`ooda-loop`/`quiesce` keep their scopes. ✅
3. **Survival** — applied to itself it demands composition + measured cause + a counter that
   moved; it is a thin preset whose only net-new rows are the three in §Net-new. ✅
4. **Bounded-Responsibility** — four exit clauses · HITL floor · depth ≤ 2 · conducts and
   delegates, never both · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING > Rules escape (which does **not** unlock the HITL floor)
   + `NOT VERIFIED` + `HYPOTHESIS` labels + refusal-with-reason. ✅
6. **Utility-Sunset** — §DUED below. ✅

`dogfood_status: pending-first-cycle` — **zero real cycles run**. Promotion is `dogfood-ledger`'s
call after ≥2, not this file's.

## §DUED Sunset (qualitative, not counter-based)

Deprecate when ANY: `gap-loop` absorbs the bidirectional round + counter gate (then this preset
is the duplicate) · the host ships a native round-scored productivity loop · the four counters
stop discriminating (every round moves all four, or none ever does) · operator retraction ·
≥3 rounds where the Repair gate fired on this asset's own mechanics. Dormant-by-design otherwise.

## Decisions — the seven corrections baked into v0.1.0

Recorded as decisions, not preferences. Each is a correction applied to the originating request
during Stage-2/3 of the pipeline.

| # | Correction | Reason |
|---|---|---|
| **D1** | the cycle is **per round**, not per node | a cycle at every node of a 7-level tree in both directions is combinatorial and fails the request's own ANTI-OVER-ENG gate |
| **D2** | `fix·heal·repair` and `evolve·improve·enhance·expand` are **two** mechanisms | Repair restores a refuted truth; Evolution generalizes a measured gain. One gate would fire on the wrong trigger |
| **D3** | introspection needs a **falsifiable** trigger | the trigger is *a premise refuted at source*; without falsifiability, introspection runs every round and means nothing |
| **D4** | added an **exit condition** | the request had none; a loop that cannot stop works against the operator's stated motivation |
| **D5** | added a **metric** (the 4 counters) | the request had none; without them "virtuous" is theater, so the asset would assert the thing it cannot show |
| **D6** | declared the **non-reimplementation table** | 18 assets already cover most parts; an untabled preset is an SSOT/DRY violation wearing a new name |
| **D7** | HOTL does **not** cover credential · spend · irreversible · prod/PII · peer config | autonomy over the reversible is not authority over the irreversible; §0 does not unlock this floor |

## §Refs

- Loops & recovery: `skills/gap-loop` · `skills/ooda-loop` · `skills/quiesce` · `skills/auto-pilot`
- Tree, priority, state: `skills/work-compass` · `skills/pulse` · `skills/eisenhower-matrix` · `skills/status-map`
- Convergence & quality: `skills/convergence-engine` · `skills/converge` · `skills/audit`
- Memory of decisions: `skills/decision-capture` · `skills/agentic-session-harness`
- Corpus & rule hygiene: `skills/corpus-firing-audit` · `skills/praxis-audit` · `skills/rule-quality-tests` · `skills/ttl-policy` · `skills/dogfood-ledger`
- Tool lifecycle: `skills/agentic-tool-pipeline` · `skills/agentic-tool-forge` · `skills/agentic-tool-trainer` · `skills/anima`
- Governance: `skills/worktree-policy` · `skills/anti-conflict` · `protocols/delegation/delegation-dna-prompt.md` · `CONTRIBUTING.md`
- Cross-link slug: `[[ratchet-loop]]`

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-10-25 | Bootstrap — the **round-scored productivity loop** (HOTL within an inviolable HITL floor). Net-new = the bidirectional 6-phase round contract (N1), the 4-counter productivity gate incl. refuted-premises (N2), and the falsifiable introspection trigger with same-round all-surface repair (N3); everything else delegates per §Composition's 19 rows over 18 existing assets. Forged through `agentic-tool-pipeline` (Stage-0 → INTENT → `agentic-tool-forge`; Stage-1 measured no duplicate; Stage-2/3 converged type=skill, rejecting command [a wrapper only — YAGNI at v0.1.0], rule [no phases, no delegation], agent [would duplicate existing conductor personas and imply authority the HITL floor denies]). Named via `anima` agent-register: `ratchet-loop` — a ratchet clicks forward and cannot slip; rejected `virtuous-cycle` (asserts the outcome the counters exist to test, and aligns with no family), `hotl-loop` (names the autonomy mode, not the mechanism; dates with the mode), `cvp-hotl` (acronym, gloss-dependent). Operator vocabulary ("ciclo virtuoso", "virtuous cycle", "HOTL") kept in `description` triggers so discoverability survives the rename. Seven corrections recorded as D1–D7. `dogfood_status: pending-first-cycle` — zero real cycles. |

## License

MIT (matches multi-agent-os repo `LICENSE`).
