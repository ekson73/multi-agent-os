# The 33 Socratic Questions — Tribune ORIENT interrogation

> The interrogation the Tribune runs in **ORIENT** before deciding AUTHORIZE-or-DEFER.
> Grouped over the operator's five dimensions: **[motivation · problems · risks · mitigations · solutions]**
> (7 + 7 + 7 + 6 + 6 = 33). These are a **lens set**, not a form to fill in prose — they surface the
> constraint-set that feeds the DECIDE gate. Any RISK answer that reveals a carve-out the deterministic
> `bin/classify.sh` missed → re-classify → **DEFER** (defense-in-depth; the LLM lens backstops the regex).

## Motivation (M1–M7) — *why is this even escalating?*
- **M1** — Is this a real root need, or a theoretical generalization? (`[C17] §1.3` Tomé)
- **M2** — What value + which primary/secondary/auxiliary targets does resolving it serve?
- **M3** — Is the urgency real or fabricated? (Eisenhower — urgent vs important)
- **M4** — Is the DoD / acceptance criterion objective and checkable? (abstract → Prisma decompose)
- **M5** — Purpose ≠ task: does acting serve the operator's BEING? (`harmonic` §0 SER)
- **M6** — What is the baseline if nothing is done? (the do-nothing counterfactual)
- **M7** — Does the "HITL question" dissolve once traced to its root cause? (`auto-merge-standing §1.1`)

## Problems (P1–P7) — *what is actually wrong?*
- **P1** — Are we resolving the symptom or the root? (`root-cause-first-prevention-priority`)
- **P2** — Is it real, or theater / hallucinated / invented? (anti-theater R1/R2/R3/R4)
- **P3** — Is it viable / applicable / implementable? (anti-theater R5/R6/R7)
- **P4** — Does it contradict something already established this session/repo? (prior-consistency)
- **P5** — Is scope IN vs OUT explicit? (`scope-discipline` — anti-creep)
- **P6** — Which premises could be wrong? (`[C17] §13` Critical + Devil's-Advocate lenses)
- **P7** — Is there a 10× simpler path? (Gordian — `over-engineering-circuit-breaker`)

## Risks (R1–R7) — *what makes this a carve-out or a hard-trigger?*
- **R1** — Is it **HUMAN_DOMAIN**? (`[C17] §2`) → **DEFER**, never auto-substitute.
- **R2** — Does it **expose a secret**? → ⛔ **ABSOLUTE**, un-liftable even by operator authorization → **DEFER**.
- **R3** — What is the blast-radius / reversibility? (irreversible high-blast → hard-trigger / DEFER)
- **R4** — LGPD / GDPR / privacy: lawful basis, data-subject rights, residency? (`lgpd-residency-not-localization`)
- **R5** — Is it a critical emergency where symptom-first is warranted? (critical-symptom exception)
- **R6** — Is the cost disproportionate to the value? (purpose-over-delivery — better nem fazer)
- **R7** — If wrong: who is affected, and is it recoverable? (`red-team` H1-H12 hard-trigger check)

## Mitigations (T1–T6) — *how do we make it safe to authorize?*
- **T1** — Is there a **non-contradictory** alternative that violates no rule/guardrail? (`environment-capability-reconnaissance §6.5`)
- **T2** — Is the path reversible / idempotent?
- **T3** — Can it be delivered partial-now to shrink risk? (`harmonic` L4)
- **T4** — Is there a **deterministic oracle** (verifier > generator)? (`agentic-first §4.7.2` · `bin/convergence-guard`)
- **T5** — Is the "why" audit-trailed? (`decision-capture` / ASH)
- **T6** — Is there a rollback + a detection trigger? (Metron — `agentic-observability-protocol`)

## Solutions (S1–S6) — *is authorization earned?*
- **S1** — Is this the best among the VALID options? (least-action / GPS — `harmonic` L3)
- **S2** — Did the council converge, and at what divergence level? (`convergence-engine`)
- **S3** — Did an **independent** verifier confirm it? (`agentic-first §4.7.2`; red-team on hard-triggers)
- **S4** — Is `autonomy_score ≥ 0.90`, and were ≤3 Score-Uplift attempts tried? (`COWORK-AUTONOMY-POLICY` bar · `[C17] §1.4`)
- **S5** — If deferring: is a ranked recommendation + justification prepared? (`end-of-action-briefing §7.1`)
- **S6** — Is it within what `COWORK-AUTONOMY-POLICY` permits the Tribune to auto-substitute?

---
**Decision rule.** AUTHORIZE only when the Solutions block is fully green **and** no Risk surfaced a
carve-out **and** the DECIDE-gate conjuncts all hold. Otherwise DEFER — carrying the council's synthesis.
