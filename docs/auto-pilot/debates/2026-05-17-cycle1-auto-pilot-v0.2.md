# `auto-pilot` v0.2 — Debate Cycle 1 — State Document

> **What this is**: Persistent state-record for cycle 1 of the Git-PR-as-Debate-Prompt methodology (introduced in [`GIT-PR-AS-DEBATE-PROMPT.md`](../GIT-PR-AS-DEBATE-PROMPT.md), shipped via PR [#71](https://github.com/ekson73/multi-agent-os/pull/71)). This doc lives in the repo as durable evidence of the debate; the live debate happens in the master-debate-PR comments.
>
> **Cycle**: 1 · **Target**: `auto-pilot` v0.2 architecture · **Started**: 2026-05-17 · **Status**: ACT 1 (steelman) · **License**: MIT.

---

## 1. Cycle metadata

| Field | Value |
|---|---|
| **Cycle ID** | `2026-05-17-cycle1` |
| **Target** | `skills/auto-pilot/SKILL.md` v0.1.0 → v0.2 architecture |
| **Goal** | Reach unanimous convergence (≥ 0.85 consensus on top-3 axes) on which of Proposals A/B/C/D should drive v0.2, OR emit `no-convergence-possible` per `skills/converge` Failure modes |
| **Authorized by** | Operator directive 2026-05-17 via `/auto-orchestrator` ("prossiga, eu autorizo self-approve pr-merge após ciclo loop pdca e convergencia agentica ocorrida") — scope-limited per `[C07]` v2.1.0 |
| **Stop budget** | ≤ 3 rounds · ≤ 6h wall-clock · ≤ 3 HITL escalations total |
| **Methodology version** | `GIT-PR-AS-DEBATE-PROMPT.md` v0.1.0 (merged 2026-05-17 via PR #71) |

---

## 2. Scope-discipline 6Q (PRE-creation per `scope-discipline-pre-creation.md` v1.0.1)

| Q | Answer |
|---|---|
| **Q1 WHERE** | Community repo `ekson73/multi-agent-os` — open-source, AAIF-portable. Debate output lands in same repo (ADR + spec update). |
| **Q2 WHAT-exists** | `skills/auto-pilot/SKILL.md` v0.1.0 (shipped); `~/.claude/skills/auto-orchestrator/SKILL.md` v1.1.0 (user-scope, AAIF-compliant superset — see `MASTER-PLAN.md` F1 for 80% overlap diagnostic). Cycle 1 must produce v0.2 spec NOT duplicate v0.1.0. |
| **Q3 WHY-now** | Cycle 0 (methodology baseline) shipped 2026-05-17; operator authorized cycle 1; F1-F8 findings in `MASTER-PLAN.md` §4 require strategic resolution. |
| **Q4 WHO-for** | Future-amnesic AI agents (cold-start) + community contributors + operator's own next-session continuity. |
| **Q5 HOW-fits** | Sister-of `skills/converge` (5-act protocol composed); applies methodology shipped in `GIT-PR-AS-DEBATE-PROMPT.md`; output feeds `MASTER-PLAN.md` §8 decision log + ADR-001-auto-pilot-architecture.md. |
| **Q6 MIN-form** | Single state-doc (this file) + master-debate-PR body + ACT comments. NO new skills/agents/commands until convergence verdict. |

**6/6 PASS** — creation justified.

---

## 3. Proposals under debate (inlined per `GIT-PR-AS-DEBATE-PROMPT.md` §5.5 auto-containment)

From `MASTER-PLAN.md` §5 (re-stated inline per §5.5):

| ID | Proposal | Steelman summary (one-line) |
|---|---|---|
| **A** | **Status-quo refinement** | Keep v0.1.0 as-is; v0.2 adds N3 archetypes ([#67](https://github.com/ekson73/multi-agent-os/issues/67)) only; fix F2/F3/F5/F7 as patches. Stance: Conservative — minimize disruption, ship incremental value. |
| **B** | **Thin wrapper** | `auto-pilot` becomes community-facing facade that internally delegates to `auto-orchestrator` v1.1.0 (canonical engine at user-scope). Stance: Hybrid / Reuse-max — collapse overlap by composition. |
| **C** | **v0.2 tight integration** | Keep `auto-pilot` as engine BUT absorb `auto-orchestrator`'s superior features (6-factor score · goal-aware markers · companion subagents · 5-path PR) and reconcile drift. Stance: Evolutionary — best-of-both. |
| **D** | **Deprecate community auto-pilot** | Import `auto-orchestrator` into multi-agent-os as canonical entry point; rename to `auto-orchestrator` in community too. Single brand, single engine. Stance: Radical / Sole-source — eliminate drift by collapsing to one. |

---

## 4. Cognitive perspectives (8 lenses — inlined per §5.5)

| Lens | Role | Anti-bias contribution |
|---|---|---|
| **Tomé / Skeptical** (5Q) | Reality-check each claim; flag hypothetical/theoretical/future | Anti-hallucination |
| **DHH-Conservative** | Simplicity · anti-overengineering · "do we need this?" | Anti-bloat |
| **Devil's Advocate** | Steelman OPPOSITE of dominant view; anti-groupthink | Anti-groupthink |
| **Fowler-Architect** | Long-term maintainability · AAIF compatibility · layer-purity | Strategic coherence |
| **Pragmatic Builder** | Shippability · dogfood-ability · time-to-v0.2 | Anti-paralysis |
| **Empiricist** | Cite 47.8% (90%^7) · AutoGPT pivot · CrewAI manager · LangGraph state-machine | Evidence-driven |
| **SecOps / Privacy** | Blast radius · prompt-injection · data leak | Risk-grounded |
| **90/10 Visionary** | Push agentic autonomy ≥ 90% / humans ≤ 10% | Mission-aligned |

---

## 5. Round 1 status (this cycle)

- **ACT 1 — Steelman**: in progress (8 perspectives × 4 proposals = 32 steelmans; consolidated per-perspective comments)
- **ACT 2 — Critique with citations**: pending
- **ACT 3 — Compare matrix**: pending
- **Meta-critique** (Round 1): pending
- **HITL interventions used**: 0
- **Wall-clock elapsed**: ~0h (cycle just opened)

---

## 6. Convergence verdict slot (filled after ACT 4)

> **Status**: empty. Filled at convergence OR `no-convergence-possible`.

- Chosen proposal: `<TBD>`
- Consensus score: `<TBD>` (target ≥ 0.85)
- Rejected elements per proposal (parity per converge §ACT 5): `<TBD>`
- ADR-001 reference: `<TBD>`

---

## 7. Refs (auxiliary per §5.5 token-efficiency caveat)

- Master-debate-PR: `<this PR>`
- Master-plan: [`docs/auto-pilot/MASTER-PLAN.md`](../MASTER-PLAN.md)
- Methodology: [`docs/auto-pilot/GIT-PR-AS-DEBATE-PROMPT.md`](../GIT-PR-AS-DEBATE-PROMPT.md)
- Master-PR template: [`templates/master-pr-debate-prompt.template.md`](../templates/master-pr-debate-prompt.template.md)
- Sister skill: [`skills/converge/SKILL.md`](../../../skills/converge/SKILL.md)
- Companion plan: [`vek-dot-claude` plan-file (merged via PR #47)](https://github.com/ekson73/vek-dot-claude/blob/main/plans/analise-critique-valide-corrija-witty-blossom.md) §15-§17

---

## 8. Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-05-17 | Bootstrap — cycle 1 opened. ACT 1 steelmans pending; ACT 2-5 + meta-critique to follow. |
