# Hub routing-eval (S8) — measure the MoE gating-network, don't assume it

> **What:** the (k) "hub-ROUTING eval (6 task families × risk)" from
> `protocols/moe-hub-architecture.md` + ADR-006's gap roadmap (story **S8**).
> **Why eval-first:** it runs *before* the gap-fill worktrees so the
> "~70% coverage" claim is **calibrated, not taken on faith** — *if it measured
> high, half the plan would fall.*

## Run

```bash
cd mcp-tools/maos-mcp-hub
python -m evals.routing_eval                 # prints the JSON report
python -m evals.routing_eval --out r.json    # also writes it
python -m pytest tests/test_routing_eval.py  # the DoD-gate tests
```

## What it measures (two blocks, both falsifiable)

### 1. `routing_gating` — exercises the REAL gating-seam

It imports the shipped `lib/gateway/policy.py::PolicyResolver` (PR #180) — **never
a reimplementation** — and feeds it a golden corpus of **6 task-families × 3 risk
levels** (`fixtures/routing_cases.yaml`, derived from the final-report §4
cheat-sheet, all real tool-ids):

| Logged field | Meaning |
|---|---|
| `coverage_allow.rate` | clean stacks → every intended tool ALLOWED (zero false-denies) |
| `injection.blocked_rate` | a conflicting tool injected into each stack → DENIED (the teeth) |
| `injection.reason_correct_rate` | the seam named the **correct** colliding tool |
| `gating_off.unsafe_passthrough` | with `policy=None`, every conflict SLIPS → the seam's measured value |
| `risk_gating_enforced` | **`false`** — honest: the seam is risk-agnostic (risk gating is WT4/S2) |

### 2. `architecture_coverage` — calibrates the "~70%" claim

From the architecture doc's **own (a)–(m) status column**
(`fixtures/artifact_coverage.yaml`), under three explicit counting rules because
the claim is sensitive to how `PARTIAL` is weighted:

| Rule | Meaning |
|---|---|
| `strict`   | BUILT only |
| `weighted` | BUILT=1, PARTIAL=0.5, GAP=0 (hybrids = midpoint) |
| `lenient`  | any non-GAP counts |

## The measured verdict (this snapshot)

```text
seam_teeth_real     : true     (18/18 injections blocked, 18/18 correct reason)
weighted_coverage   : 0.5769   (strict 0.2308 · lenient 0.9231)
claim_70pct         : BELOW_CLAIM (claim OPTIMISTIC)
half_the_plan_falls : false  →  the gap-fill waves (WT1+) remain justified
```

**Read:** the gating substrate is genuinely real (teeth proven), **but** coverage
is **~58% weighted** by the doc's own status column — not 70%. So WT0 does **not**
greenlight cutting the plan. (The OODA-RECON itself flagged "~70% is an estimate,
not a measurement — calibrate via the eval"; this is that calibration.)

## DoD-gate

Every acceptance here is a **logged JSON field** or a **golden-fixture invariant
asserted in a test** — never a prose-judged `THEN`. The fixtures are guarded:
every id is a real `conflicts.yaml` node, every stack is internally
conflict-free, and every injection has a real conflict edge to exactly its
expected member(s).

## Relationship to `agentic-tool-evaluator`

`agentic-tool-evaluator` evaluates a **single** agentic-tool's behaviour. This
harness evaluates the **hub's routing** (the gating-network), which that skill
lists as a GAP. They are complementary; this is the routing half.
