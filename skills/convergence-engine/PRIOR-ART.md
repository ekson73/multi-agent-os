# Prior Art Survey — Iterative Multi-Agent Quality Convergence

**Survey date:** 2026-06-02
**Scope:** academic iterative-refinement / self-correction literature + OSS multi-agent convergence frameworks + this repo's existing primitives.
**Methodology:** primary-source verification of the research anchors; composed-primitive provenance traced to in-repo artifacts (anti-NIH discipline — this skill is a *composition*, not a new engine).

## What this skill IS (and is not)

This skill is a **router + bounds** over existing primitives, behind a small set of non-negotiable rules (master condition, economic stop, deterministic-stopping, multi-axis diversity). It builds **no new engine** — every regime lands on an artifact that already exists in this repo. The novelty is the **synthesis discipline**, not new machinery.

## Research anchors (verified)

| Anchor | Claim adopted | What we took |
|---|---|---|
| **Madaan et al. 2023 — Self-Refine** (arXiv 2303.17651) | Iterative self-feedback improves output; gains plateau ~3 iterations | The REFINE regime + the ~3-round practical optimum (economic stop) |
| **Huang et al. 2024 — "LLMs Cannot Self-Correct Reasoning Yet"** (arXiv 2310.01798) | Same-model self-critique on clean output *degrades* it without an external signal | The **master condition** (verifier > generator, independent) + the self-critique-paradox guard (selectivity gate) |
| **Shinn et al. 2023 — Reflexion** (arXiv 2303.11366) | Verbal reinforcement from an evaluator lifts subsequent attempts | The cascade-resolver score-uplift loop pattern |
| **Gou et al. 2023 — CRITIC** (arXiv 2305.11738) | Tool-interactive critiquing (external oracle) beats unaided self-critique | "Prefer a deterministic oracle where one exists" (`f=0` verifier) |
| **Du et al. 2024 — Multiagent Debate** (arXiv 2305.14325, ICML) | Multiple independent agents debating improves factuality/reasoning | The multi-axis diversity `r`-lever + SELECT-regime debate→converge |
| **Generation–Verification gap** (folklore + best-of-N literature) | Verifying a candidate is easier than generating it | The SELECT regime works at `gen 40–70%` because the verifier carries the load |
| **"Self-Critique Paradox"** (Snorkel, 2025 write-up) | Engaging self-critique on already-good output is corrosive; engage *selectively* | The selectivity gate (loop-or-skip) + depth-scaling |

## Composed-primitive provenance (in-repo)

| Regime / function | Primitive | In-repo path | Borrowed property |
|---|---|---|---|
| SELECT synthesis | `converge` | `skills/converge/SKILL.md` | 5-act steelman→critique→compare→synthesize→reject-log; audit-not-persuasion |
| Breadth (parallel diverse) | `perspective-trio` | `agents/perspective-trio.md` | 3 orthogonal lenses + diversity guard |
| Score-uplift loop | `cascade-resolver` | `agents/cascade-resolver.md` | 12-role matrix + 8 termination conditions (= economic stop) + keep-best |
| Depth verify | `persona-pipeline` | `agents/persona-pipeline.md` | 6-stage board + risk-scaled depth + `certainty` computation |
| Autonomous drive | `auto-pilot` | `skills/auto-pilot/SKILL.md` | thin-kernel-composes pattern + autonomy bands |
| Merge-gate | `CONTRIBUTING.md` + `pr-review` | repo infra | bot-convergence + G1-G8 deterministic reads |

## Negative results (verified absent — the gap this skill fills)

- No existing in-repo artifact encodes the **three-regime switch** (REFINE/SELECT/DEFER by verifiability) — `converge` is SELECT-only; `cascade-resolver` is REFINE-only; neither routes.
- No existing artifact states the **verifier > generator master condition** as a gate.
- No existing artifact ties stopping to a **closed-form economic `n*`** vs a flat round cap.
- No existing artifact names the **self-critique paradox selectivity gate** (loop-or-skip on clean output).

These four are the genuinely-new content; everything else is composition.

## Decision matrix used to design this skill

| Approach | Effort | Risk | Verdict |
|---|---|---|---|
| Enhance `converge` to absorb all regimes | Medium | Medium (overloads a focused SELECT-synthesis skill) | Rejected — identity creep |
| New executable orchestrator composing existing primitives | Medium | Low | **Adopted** — clean separation; converge stays focused |
| Doctrine doc only (no executable surface) | Low | Low | Rejected — operator chose an executable form |
| Re-implement critique/scoring inside the skill | High | High (NIH; correlates critics) | Rejected — violates master condition + DRY |

## Maintenance protocol

Re-validate **quarterly** against:
- New releases of the research anchors (newer self-correction / verifier-asymmetry results may shift cutoffs).
- New entrants in the multi-agent-convergence space reaching feature parity.
- Drift in the composed primitives (`converge` / `cascade-resolver` / `perspective-trio` / `persona-pipeline` version bumps) — keep the Composition map current.

If a composed primitive is deprecated or superseded, update the Composition map in `SKILL.md` and this file in the same PR; never leave a dangling primitive reference.

## Sources cited

- https://arxiv.org/abs/2303.17651 (Self-Refine — Madaan et al. 2023)
- https://arxiv.org/abs/2310.01798 (LLMs Cannot Self-Correct Reasoning Yet — Huang et al. 2024)
- https://arxiv.org/abs/2303.11366 (Reflexion — Shinn et al. 2023)
- https://arxiv.org/abs/2305.11738 (CRITIC — Gou et al. 2023)
- https://arxiv.org/abs/2305.14325 (Multiagent Debate — Du et al. 2024, ICML)
- `skills/converge/PRIOR-ART.md` (the SELECT-regime primitive's own 20+-artifact survey)
