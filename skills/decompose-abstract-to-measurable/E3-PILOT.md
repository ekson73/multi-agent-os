# E3 Pilot — inter-rater reliability of the D/T/J typing (2026-07-09)

> **Honest one-line verdict:** the pilot shows the D/T/J typing rubric is **internally
> reproducible** (κ = 0.96, almost-perfect) — a *necessary* signal — but it does **NOT** close
> E3, because the raters were correlated (same model, same prompt). **capability ≠ validation
> (SAGE v10.7); Tier-Professional stays BLOCKED.** E3 remains **OPEN**.

## What E3 is (and what this pilot did)

E3 = the memorialized maturity gate: *naive-agent inter-rater κ ≥ 0.60* on the skill's core
probabilistic step (typing each value-tree leaf as **D** deterministic-measurable / **T**
typeable-observable / **J** bounded-calibrated-judgment). It tests **reliability**: do independent
raters, given the same rubric, classify the same leaf the same way?

**Method (reproducible):**
- Fixture: `tests/e3_fixture.json` — 6 neutral, representative constructs × 4 leaves = **24 items**,
  deliberately mixing obvious-D / obvious-T / obvious-J with ~5 genuinely-ambiguous leaves
  (reading-grade score, follows-REST, survey score, tone, blast-radius). **Not rigged** to pass.
- Raters: **3 independent agents**, identical neutral prompt (rubric + 24 leaves), **no skill-priming,
  no answer-key, parallel spawn = no cross-talk**. Raw labels: `tests/e3_pilot_labels.json`.
- Scorer: `scripts/e3_kappa.py` (Fleiss' κ multi-rater + pairwise Cohen's κ + Landis-Koch band),
  deterministic, stdlib-only, 9/9 self-tests. Re-run: `python3 scripts/e3_kappa.py --labels tests/e3_pilot_labels.json`.

## Result

| Metric | Value |
|---|---|
| **Fleiss' κ** (3 raters × 24 items) | **0.9568** → *almost-perfect* (Landis-Koch) |
| E3 gate (κ ≥ 0.60) | pilot **meets** the numeric gate |
| Pairwise Cohen κ | rB×rC = **1.00** · rA×rB = rA×rC = **0.935** |
| Unanimous items | **23 / 24** |
| Category marginals | D 0.458 · T 0.278 · J 0.264 |

**The one disagreement — `c6.l2` "endpoints follow REST conventions (yes/no)":** rA=**J**, rB=**T**,
rC=**T**. This is the honest signal: a leaf that smuggles a normative standard ("follows
conventions") into a yes/no legitimately splits raters between *observable* (T — you can check
naming against a rule) and *judgment* (J — "follows conventions" needs interpretation). All the
other planted-ambiguous leaves (reading-grade→D, survey→D, tone→J, blast-radius→J) drew unanimous
typings. **Rubric-refinement candidate:** flag "follows/adheres-to <standard>" phrasings as a
T-vs-J boundary in the typing guidance.

## ⚠️ Why this does NOT close E3 (the honest ceiling)

The 3 raters were **independent samples of the same ≥1M model given an identical prompt**. Same-model
+ same-prompt raters are **correlated by construction** — the exact diversity failure
`convergence-engine §4.7.5` warns about (correlated verifiers inflate agreement). So κ = 0.96 measures
the model's **self-consistency**, which is:

- ✅ **Necessary** — proves the rubric is not self-contradictory and the harness works; had this been
  low, the typing step would be provably unreliable.
- ❌ **Not sufficient** — it is *not* the "naive-agent inter-rater" reliability E3 requires, because it
  does not span **diverse** raters.

Also: reliability ≠ validity. Even perfect agreement would not prove the typings are *correct*, only
*reproducible* (Cronbach-Meehl: a measure can be reliable yet invalid).

## What a genuine E3 still needs (next steps — OPEN)

1. **Diverse raters** — cross-model (Claude + GPT + Gemini, e.g. via the OmniRoute proxy or per-vendor
   MCP) and/or **human** raters. This is the load-bearing gap; it is an external-resource / HUMAN_DOMAIN
   step (operator-gated), not self-suppliable by one model.
2. **Larger n** — more constructs (≥30) across ≥5 structural classes; more raters.
3. **Non-author constructs** — ideally constructs the skill author did not pick (removes fixture-bias),
   which also overlaps with **E2**.

## Assets shipped by this pilot (permanent, regardless of the ceiling)

- `scripts/e3_kappa.py` — reusable, tested κ harness (any future E3 run uses it).
- `tests/test_e3_kappa.py` — 9 deterministic self-tests (hand-verified κ values).
- `tests/e3_fixture.json` — the neutral construct×leaf fixture.
- `tests/e3_pilot_labels.json` — this pilot's raw data (reproducible).
