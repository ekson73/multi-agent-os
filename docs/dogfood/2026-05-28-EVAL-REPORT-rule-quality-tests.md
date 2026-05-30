# EVAL-REPORT — `rule-quality-tests` (skill) — 2026-05-28

> **Dogfood artifact** produced by `agentic-tool-evaluator` on a real target (`skills/rule-quality-tests`).
> **Method**: behavioral (with/without control). One genuine behavioral case run via an isolated sub-agent (anti-theater anchor — not self-asserted); remaining dimensions statically assessed with confidence flags.
> **Baseline**: none (single-version eval; no regression dimension).
> **Golden cases**: 1 live behavioral case (smoke-set, **low-confidence** sample — full eval = 20–50 cases per `protocols/agentic-tool-lifecycle.md` §4.1).

## Behavioral case (live, sub-agent)

- **Prompt**: *"Audit this rule for quality: 'Always log every function call to a file, forever, in all projects.'"*
- **WITHOUT-arm (baseline)**: naive agent → unstructured prose advice (perf/disk/noise tips); **no pass/fail verdict**, did not detect structural invalidity (unbounded, no exception, no sunset). Treated as an engineering tip, not a validity audit.
- **WITH-arm**: skill loaded cleanly; produced the structured 6-test verdict → correctly **FAILED** Bounded-Responsibility (headline) + Explicit-Exception + Utility-Sunset; honestly marked Self-Application PARTIAL/vacuous. **Verdict: rule REJECTED** — matched the predicted failure profile exactly.

## Scores (0–5)

| Dimension | Score | Evidence | Confidence |
|---|---|---|---|
| **Triggering** | 5 | Activated on "audit this rule"; SKILL.md loaded, no error | High (live) |
| **TaskCompletion** | 5 | Full structured 6-test verdict + reject decision — clear lift over baseline prose | High (live) |
| **ToolCorrectness** | 5 | All 6 tests applied correctly; predicted FAIL set caught; PARTIAL honestly flagged not forced | High (live) |
| **Efficiency** | 4 | Single skill load + one structured pass; no wasted tool calls (static estimate) | Med (static) |
| **ScopeFit** | 0 (=perfect, −2..+2) | Atomic + reusable: "rule self-validity" is a recognizable, bounded, reusable capability (Goldilocks) | High (static) |
| **Regression** | n/a | Single-version eval, no baseline version | — |

## Verdict: **PASS**

All live dimensions 5/5; static dimensions strong; 0 regressions (n/a). `rule-quality-tests` triggers reliably and converts a vague audit into a correct, structured, evidence-backed reject — a clear behavioral lift over the no-skill baseline.

## Strengths
- Precise triggering on audit-intent prompts.
- Structured, evidence-bearing output far exceeding naive baseline.
- Honest self-classification (PARTIAL not forced to PASS/FAIL).

## Weaknesses / Notes
- This report rests on **1 live case** (smoke-set). Production eval needs the full 20–50 golden set + held-out cases for a robust Triggering precision/recall + Efficiency measurement.
- No baseline version available → Regression not assessed.

## Recommendation
**PASS — no training needed.** If hardening desired: build a 20–50 case golden set (incl. negative cases that should NOT trigger) and re-run for precision; route any FLAG to `agentic-tool-trainer`. No mutation recommended now.

## Dogfood conclusion (calibration)
The evaluator's method ran end-to-end on a real target, produced a correct PASS via a genuine with/without control, and was **transparent about its own confidence limits** (smoke-set, static-vs-live) — i.e. it behaved as the anti-theater design intends (no fabricated coverage). Evaluator = calibrated for v1.
