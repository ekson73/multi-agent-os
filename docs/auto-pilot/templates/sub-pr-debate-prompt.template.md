# Sub-PR Debate-Prompt — Template

> Copy-paste into the body of a sub-PR. Sub-PRs exist ONLY to handle divergences too big for the master-PR thread. **Rationale gate REQUIRED before opening** — see methodology §4.

---

## 🚪 Rationale gate (mandatory pre-open check)

| Gate | Check | Result |
|---|---|---|
| **Gate A — Size** | Master-PR has > 30 substantive comments AND this divergence cluster represents ≥ 25% of thread volume | `<YES/NO>` |
| **Gate B — Structure** | Divergence is axiom-level — proposals here operate from incompatible foundational assumptions vs master | `<YES/NO>` |

**If NEITHER gate triggers** → CLOSE this draft; resolve inline in master-PR instead (anti-fragmentation discipline per scope-discipline 6Q Q3 "WHY now?").

**If EITHER gate triggers** → proceed; document which gate + evidence in §"Rationale" below.

## 🔗 Master-PR cross-link

- **Master-PR**: `<link to master-PR>` (e.g., `ekson73/multi-agent-os#123`)
- **Goal of this sub-PR**: `<one-sentence statement of the divergence to be resolved>`
- **Merge order**: this sub-PR merges **before** master (sub-PR verdict feeds master ACT 4)

## 🎯 Divergence focus

`<2-3 sentence explanation of the specific divergence — what proposals disagree, where the incompatibility lies>`

### Rationale (which gate fired + evidence)

`<concrete evidence — comment counts · divergence volume · axiom-level structure>`

## 📋 Inputs (subset of master-PR proposals + new perspectives if any)

| ID | Proposal (from master) | Stance in this divergence |
|---|---|---|
| `<A>` | `<title>` | `<position in divergence>` |
| `<B>` | `<title>` | `<position in divergence>` |
| `<C>` (optional new sub-proposal) | `<title>` | `<position>` |

## 🧠 Cognitive perspectives (subset of master's 8, OR new ones identified per methodology §5)

- `<Lens 1>` — `<focus for THIS divergence>`
- `<Lens 2>` — `<focus for THIS divergence>`
- `<...>` — `<add up to 4 lenses; sub-PR should NOT replicate all 8 to avoid bloat>`

## 🛑 Stop conditions (inherited from master, with sub-specific caps)

| # | Condition | Action |
|---|---|---|
| S1 | Sub-divergence resolved | Emit verdict comment in sub-PR; post summary to master-PR |
| S2 | Sub-PR max 2 rounds (tighter than master's 3) | `no-convergence-possible-sub`; escalate to master |
| S3 | Wall-clock > 2h (tighter than master's 6h) | Pause + flag |
| S4 | Diminishing returns | Partial verdict |
| S5 | Axiom-level inside the sub | Escalate to operator |

## 📤 Output (this sub-PR's deliverable)

- [ ] Verdict comment on sub-PR (PASS / no-convergence-possible-sub)
- [ ] Summary comment posted in master-PR linking back to this sub-PR
- [ ] If PASS — sub-PR's ADR fragment ready for master's final synthesis
- [ ] If no-convergence — both sub-positions documented for operator decision
- [ ] HITL merge gate per your project's governance policy (operator approves merge BEFORE master)

## 📜 Rules of engagement

Inherits master-PR rules (no leading questions · cite source text · prompt-injection guard · parity · `[C07]` HITL merge gate). Sub-PR adds:

- **No new perspectives without justification** — sub-PR should resolve the divergence, not expand the debate surface.
- **No new sub-sub-PRs** — depth cap at 2 (master → sub). If sub-PR itself diverges, escalate to operator.
- **Sub-PR comment volume cap** ≈ 15 substantive comments before triggering S2 (early stop).

## 🔗 Cross-references

- Methodology: [`docs/auto-pilot/GIT-PR-AS-DEBATE-PROMPT.md`](../GIT-PR-AS-DEBATE-PROMPT.md)
- Master-plan: [`docs/auto-pilot/MASTER-PLAN.md`](../MASTER-PLAN.md)
- Master-PR template: [`templates/master-pr-debate-prompt.template.md`](./master-pr-debate-prompt.template.md)

---

*Template version: v0.1.0 (2026-05-17). License: MIT.*
