# PRIOR-ART — decompose-abstract-to-measurable (Prisma)

> Why this skill is honest engineering, not mysticism. The originating thesis
> ("everything is energy/frequency → every abstract fully reduces to native math")
> is, unknowingly, a **re-derivation of a 50-year-old decision-science method** —
> whose *core is real and validated* and whose *strong form is known to be false*.
> This file records both, so no future agent mistakes the decoration for the
> mechanism.

## 1 · The mechanism is real — and old (cited by name)

| Prior art | Author(s) / origin | What the skill borrows |
|---|---|---|
| **MAUT** — Multi-Attribute Utility Theory | Keeney & Raiffa, 1976 | the value-tree itself: decompose a goal into weighted attributes, aggregate to a utility in [0,1] |
| **AHP** — Analytic Hierarchy Process | Thomas Saaty, 1980 | hierarchical criteria → sub-criteria → alternatives; pairwise weight elicitation |
| **MCDA / MCDM** — Multi-Criteria Decision Analysis | field, 1970s– | weighted-sum aggregation, sensitivity analysis, materiality |
| **Fuzzy set membership** | Lotfi Zadeh, 1965 | leaf grades are graded membership in [0,1], not booleans |
| **Decomposed-rubric LLM-as-judge** | G-Eval (Liu 2023) · FLASK (Ye 2023) · Prometheus (Kim 2023) | J-leaves: score a criterion against an explicit rubric + anchors, with confidence + order-swap de-biasing |
| **Rubrics-as-rewards / checklist rewards** | 2024–2025 RLHF/eval line | anchors as the reward signal; per-criterion decomposition beats a monolithic "rate 1–10" |
| **Swing-weighting / direct-ratio elicitation** | decision-analysis practice | making the value weights explicit + traceable (Step 4) |

**The operator's "N-Tree of calculable leaves" IS a MAUT/AHP value-tree.** The
engineering core is therefore real, standard, and validated in decision science,
software quality models (e.g. ISO/IEC 25010 quality trees), and modern LLM
evaluation. That is why the skill works.

## 2 · The strong thesis is false — four independent limiters

The claim that the abstract reduces *fully and without loss* to native math fails
against four separate, well-established results. The skill does not defeat them —
it **manages** them and surfaces the residue.

| # | Limiter | Author / origin | Consequence encoded in the skill |
|---|---|---|---|
| 1 | **Is–ought gap** | David Hume, 1739 | a *value* is never entailed by *facts* alone → the weights + J-leaves are the injected value, made **explicit** (Step 4), not eliminated |
| 2 | **Open-question argument** | G.E. Moore, 1903 | "good" is not identical to any natural property → no finite fact-set *defines* it; the tree *operationalizes* a context-bound proxy, not the concept itself |
| 3 | **Symbol-grounding problem** | Stevan Harnad, 1990 | a symbol ("beautiful") has no context-free numeric ground → **Step 0 CONTEXT-LOCK** is mandatory; grounding is always relative to purpose + audience |
| 4 | **Construct validity** | Cronbach & Meehl, 1955 (psychometrics) | a measure can be *reliable* yet *invalid* — repeatable but measuring the wrong thing → anchors + held-out validation (Step 7) manage, never fully close, this |
| + | **Goodhart's law** | Charles Goodhart, 1975 | once the proxy is the target it stops measuring → the score is **evidence, not a target** (Metron guard, Step 6) |

## 3 · The honest reframe (what the skill actually claims)

> The abstract becomes **tractable, transparent, and calibrated**, with the
> **irreducible residual of human judgment surfaced as a first-class output**.

Concretely, an amnesic agent goes from *"I'll guess 'this looks professional →
0.8'"* to a reproducible spec where every 0.8 is traceable to a weighted, anchored
leaf — and where, when judgment genuinely dominates or conflicts, the tool says
**"inconclusive → escalate"** instead of manufacturing false precision. That is a
large, real capability gain. It is *not* proof that "good" is a number.

## 4 · "Energy / vibration / frequency"

Honored as **evocative inspiration**, not mechanism — which is exactly why the
soul-name is **Prisma**: a prism performs a *real* physical frequency
decomposition (splitting white light into measurable component wavelengths),
grounding the operator's "frequency" intuition in optics rather than metaphysics.
No claim in this skill depends on energy/vibration being literally true; strip the
metaphor and the MCDA + rubric + fuzzy machinery stands on its own.

## 5 · Where each piece is composed from (no re-derivation)

- band boundaries (HIGH .85 / MED .65) ← `auto-self-harness.md` §1.2 autonomy_score
- Goodhart guard / score=evidence / residual ← `agentic-observability-protocol.md` (Metron) §4/§5
- REFINE/SELECT/**DEFER** + verifier>generator + economic-stop ← `skills/convergence-engine`
- per-leaf measurement + evidence ← `maos:data-validator`; independent re-typing ← `maos:validation-auditor`
- CONTEXT-LOCK + reality gate ← `anti-theater-grounding-protocol.md` Layer 2 / Layer 5

## 6 · Provenance

Forged 2026-07-08 from a `/deep-research` + MoA-council session on the operator's
"everything-is-calculable" thesis. Full honest-verdict + seam doctrine persisted
in akasha memory: `dna_abstract_to_measurable_decomposition_2026_07_08.md` and
`reference_abstract_to_measurable_prior_art_2026_07_08.md`.
