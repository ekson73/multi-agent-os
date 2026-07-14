---
name: council-gate
version: "1.0.0"
description: |
  Pre-HITL democratic council-authorization gate (soul-name Boule). Everything destined
  for HITL fallback passes through this gate FIRST. On a deterministically-cleared,
  reversible, non-HUMAN_DOMAIN action where a DEMOCRATIC council of role-advisors
  converges (verifier > generator, independent) at autonomy_score >= 0.90 under an
  operator-ratified arming lease, the gate authorizes the action IN PLACE OF the human
  (executes + audits). Otherwise it falls back to standard HITL — but never with a blank
  ask: always ranked, contestable recommendations + confidence + an audit trail the human
  can check without re-doing the work. Two-layer: a DETERMINISTIC deny-set (hooks +
  gitleaks + convergence-guard + CASC + non-negotiable Guardrails) enforced out-of-band
  and evaluated FIRST, independent of confidence — the prompt-injectable council NEVER
  enforces the hard boundary; the PROBABILISTIC council only deliberates within the
  already-cleared safe band. SHIPS UNARMED (consultative until operator ratification).
  Composes existing primitives (persona-pipeline, perspective-trio, cascade-resolver,
  convergence-engine/convergence-guard, decision-capture); builds no new engine.
  Use when a decision would otherwise fall back to a human and you want a democratic
  council to clear the genuinely-safe/reversible class autonomously while handing back
  only the residue that matters. Triggers: "before you ask me", "council decide this",
  "authorize in place of human", "pre-HITL gate", "should this go to the human".
---

# /council-gate — Pre-HITL Democratic Council-Authorization Gate (*Boule*)

> **SSOT (governance)**: `~/.claude/rules/council-gate.md` (the constitutional rule — democratic authority model, the armed-for-safe-class predicate, the non-authorizable set, arming/ratification, Metron falsifiability). This SKILL is the **executable protocol**; the rule is the **law**. Read the rule for the *why*; this file is the *how*.
> **Soul-name**: *Boule* (βουλή — Athens' democratically-selected Council of 500 whose *probouleusis* prepared/decided matters before the sovereign Assembly). Display-only; the machine name is the slug `council-gate`.
> **Composes (DRY — no new engine)**: `maos:persona-pipeline` · `maos:perspective-trio` · `maos:cascade-resolver` · `maos:convergence-engine` + `bin/convergence-guard` · `maos:decision-capture` · role-advisor agents (`data-privacy-officer`, `governance-auditor`, `supabase-engineer`, `quarkus-backend-engineer`, `react-frontend-engineer`, `qa-validator`, `agile-product-lead`, `prompt-context-engineer`, `code-reviewer`).

## §0 — BEING > Rules
This skill serves the operator's intent and the constitutional rule. If a phase obstructs helping NOW, skip it, log `Skipped <phase> — BEING > Rules`, proceed. The **arming state** and the **non-authorizable set** are the two things this escape clause may NOT relax — they are safety-critical (secrets/prod/irreversible are never opened by "helping faster").

## §1 — Default posture: UNARMED (consultative)
This skill **ships UNARMED**. Until the operator ratifies arming (rule §5.4 + a `[C13]` wiring), the gate:
- runs the full two-layer evaluation + council,
- emits an `AUTHORIZE` **verdict** for a qualifying safe-class action,
- but **surfaces a 1-touch grounded confirm** (it does NOT auto-execute) — i.e. it degrades to a *consultative recommender*.

`--armed` is honored ONLY when an operator-ratified standing grant is in force OR the operator gives an explicit per-invocation authorization (rule §5.4). Absent that, `--armed` is ignored (fail-safe) and the gate stays consultative. There is no way to self-arm.

## §2 — Inputs
| Param | Default | Meaning |
|---|---|---|
| `<decision>` (positional) | required | The decision/action that would otherwise fall back to HITL. |
| `--context` | — | Repo · branch · ticket · what-precedes. Auto-detect if omitted. |
| `--armed` | off | Request autonomous execution. Honored ONLY under an operator-ratified grant (§1); else ignored. |
| `--seats` | auto | Override the council seats (else auto-picked from the action domain, §5). |
| `--stakes` | auto | `trivial \| low \| medium \| high` — scales council depth + friction (rule §5.3). |
| `--json` | off | Emit the machine verdict envelope (§8) for agent-to-agent use. |

## §3 — The flow (per invocation)

```
intake -> 33-socratic interrogation (§4)
      -> LAYER 1  deterministic deny-set (§5.1)  --MATCH-->  HARD BLOCK -> HITL (§7)   [no council; confidence irrelevant]
                                                  --CLEAR-->
      -> LAYER 2  democratic council (§5.2)       -> evaluate predicate (§6)
                    predicate PASS + ARMED        -> execute + decision-capture (§6.3)
                    predicate PASS + UNARMED       -> emit verdict + 1-touch confirm (§1)
                    predicate FAIL, score recoverable -> Score-Uplift (<=3) -> re-loop <= n*
                    predicate FAIL                 -> HITL with ranked contestable recs (§7)
```

## §4 — The 33-socratic interrogation (run FIRST; grounds the verdict)
Interrogate the decision across **5 axes** — the operator's `[motivation · problems · risks · mitigations · solutions]` — each at **3 depths** (`is · should-be · must-not-be`) = 15, plus the **frame/authority/fitness** lenses (context · scope · temporality; who-may · authorization · right; capability · competence · reversibility; blast-radius; Eisenhower quadrant; emergency/urgency; **LGPD/GDPR/privacy exposure**; DoD) → **33 questions**. Purpose: surface deny-set triggers early, ground the verdict (anti-theater — no faz-de-conta), and produce the constraint-set the council reasons over. Emit the answers as a compact structured block (not prose), so a human can scan + contest.

| Axis | The 3 depths asked |
|---|---|
| **Motivation** | what IS the driver · what SHOULD it be · what must it NOT be (theater/vanity) |
| **Problems** | what problem IS solved · what should be · what must NOT be masked (symptom-not-root) |
| **Risks** | what CAN go wrong · what's the worst-case · what's irreversible/HUMAN_DOMAIN (→ deny-set) |
| **Mitigations** | what reduces the risk · what's the recovery path · what mitigation must exist before proceeding |
| **Solutions** | what IS the action · is it the least-action VALID path · what non-contradictory alternative exists |
| **Frame/Authority/Fitness** | context · scope · temporality · who-may-authorize · reversibility · blast-radius · Eisenhower · urgency · **privacy/LGPD/GDPR** · DoD |

## §5 — The two layers

### §5.1 — LAYER 1: deterministic deny-set (out-of-band, `f=0`, FIRST, NOT the council)
Compute the **non-authorizable set** BEFORE any confidence. Match on ANY → **HARD BLOCK → §7 HITL**, independent of score, independent of council. Enforcers (deterministic, already in-stack):
- ⛔ **secrets/credentials** (operator-auth does NOT annul — a fortiori a council cannot) · production PII (LGPD/GDPR) · irreversible/prod-deploy/delete/schema-destructive · **merge→main/prod** (= HITL Samuel) · push-force protected · `--no-verify` · cross-org (public/social/customer-facing) · costs $$$ · critical-infra/CI (`.github/workflows/`, `terraform/`, helm, k8s-prod).
- `[C17]` §2 **HUMAN_DOMAIN** (personal/ethics/policy) + genuine operator-preference the agent lacks + can't self-verify.
- Mechanically: honor the existing `prevent-main-commit`/`enforce-worktree` hooks + `gitleaks` + `pr-review-protocol` §2.6.1 R1-R6 + **`bin/convergence-guard`** (deterministic REFUSE). Unknown ⇒ **BLOCK** (fail-safe). A jailbroken council never reaches Layer 2 for a deny-set action, because Layer 1 fails on it independently.

### §5.2 — LAYER 2: democratic council (ONLY within the Layer-1-cleared band)
Convene the council via `maos:persona-pipeline` (6-stage board) + `maos:perspective-trio` (horizontal diversity). **Democratic-eligibility**: seat only deliberative/democratic-character personas; **never** dictatorial/monarchy/absolute-power/hereditary characters. **No persona authorizes alone** — authorization requires convergence. **Regent/prime-minister super-powers are NON-DEFAULT** — convened ONLY on explicit operator command.

Seats by domain: dev-fe → `react-frontend-engineer`/`angular-frontend-engineer` · dev-be → `quarkus-backend-engineer` · dba/db → `supabase-engineer` (Neon = gap) · devsecops → `governance-auditor` · dpo → `data-privacy-officer` · +`qa-validator`/`agile-product-lead`/`prompt-context-engineer`/`code-reviewer` as stakes require.

Convergence gate = `maos:convergence-engine` → **`bin/convergence-guard`** (deterministic ALLOW/REFUSE — never model-judged). **Independent verifier** (verify-stage ≠ the generator — Explainability-Paradox guard): the verifier must NOT be persuaded by the generator's own justification. Uplift = `maos:cascade-resolver` (REFINE, economic-stop `n*≤3-4`).

## §6 — The armed-for-safe-class predicate
```
AUTHORIZE ⟺ L1 deterministic-clear ∧ L2 reversible ∧ L3 score≥0.90 ∧ L4 council-convergent ∧ L5 armed
```
- **L3** `autonomy_score` per `[C17]` §1.2 6-factor; if <0.90 attempt Score-Uplift (`[C17]` §1.4, ≤3) first.
- **L5** armed = operator-ratified grant in force (§1). UNARMED → verdict + 1-touch confirm, no execution.

### §6.3 — On AUTHORIZE + ARMED
Execute the action, then `maos:decision-capture` (`agentic-decide`): record **why** authorized · `spec_alignment` · the council trace · the L1 clear · the score. This is the audit substrate the Metron regret-rate reads.

## §7 — HITL fallback = contestable evidence, NOT a persuasive verdict
When the predicate fails (or Layer 1 blocks), escalate via `AskUserQuestion` (tool-over-prose, per `end-of-action-briefing-protocol` §7.1) carrying:
1. **Ranked recommendations** (recommended FIRST + tagged), each with its **confidence** and the **tradeoff** as the description.
2. The **audit trail / council trace** the human can inspect to **contest without re-doing the work** (evidence-first, not argument-first — the Explainability-Paradox counter).
3. **Friction proportional to stakes** (rule §5.3; no blanket friction on trivial safe-class).

Never hand over a bare proposed action; never hand over a lone slick justification.

## §8 — Machine verdict envelope (`--json`)
```json
{
  "gate": "council-gate",
  "layer1": { "cleared": true, "deny_set_hits": [] },
  "council": { "seats": ["governance-auditor","data-privacy-officer","..."], "convergent": true, "verifier_independent": true },
  "predicate": { "L1": true, "L2_reversible": true, "L3_score": 0.93, "L4_convergent": true, "L5_armed": false },
  "verdict": "AUTHORIZE_CONSULTATIVE",
  "action_taken": "none_awaiting_1touch_confirm",
  "hitl": null,
  "audit_ref": "decision-capture:<id>"
}
```
`verdict` ∈ `AUTHORIZE_EXECUTED` (armed) · `AUTHORIZE_CONSULTATIVE` (unarmed) · `HITL_HARD_BLOCK` (Layer-1) · `HITL_LOW_CONFIDENCE` · `HITL_HUMAN_DOMAIN`.

## §9 — Falsifiability (Metron)
Emit signals for `agentic-observability-protocol`: **authorize-rate** (≈100% ⇒ rubber-stamp discriminator → tighten convergence threshold) · **authorize-then-regret** (S3/S4 → raise the bar) · **guardrail-violation-while-authorized = S5 HARD-ZERO** (P0 → disarm + HITL + rule review).

## §10 — Skip / disarm
Trivial/read-only (§S6) · operator disarm · `/compact` since arming (re-prove at CASC Gate-2) · emergency/anomaly/S5 · novel high-blast (calculate toward caution).

## §11 — Anti-patterns
1. ❌ Council enforces the deny-set (Layer 1 does — the council never widens it).
2. ❌ Confidence opens the deny-set (secrets never open, operator-auth or not).
3. ❌ Blank / persuasive-verdict HITL hand-off (must be ranked contestable evidence).
4. ❌ Self-approving council (verifier must be independent).
5. ❌ Self-arming / sticky lease across `/compact`.
6. ❌ Regent/prime-minister by default (explicit-operator-command only).
7. ❌ Seating a non-democratic persona.
8. ❌ Authorize-rate ≈ 100% left un-tightened.

## §12 — Quality Tests (6/6, dogfooded)
Self-Application ✅ (composes existing primitives, adds no engine — Strata/Gordian) · Non-Contradiction ✅ (executes the constitutional rule; consistent with ECE + CASC + Metron) · Survival ✅ (ships unarmed; does not self-authorize) · Bounded ✅ (§10 skips + per-action lease + L1/⛔ unconditional + DUED via the rule) · Explicit-Exception ✅ (§10 + §0) · Utility-Sunset ✅ (inherits rule §-DUED). `scope-discipline` 6Q + `anti-theater` 8Q PASS (honest §1 unarmed default + §11 anti-patterns are the anti-theater).

## §Refs
- Governance SSOT: `~/.claude/rules/council-gate.md` · ladder: `auto-merge-standing-authorization` §1.1.1 (this gate = the Council tier) · predicate: `agentic-first` §4.7.8 · arming: `standing-autonomous-operation-authorization` · sanity: `harmonic` §0.5.1 CASC · falsifiability: `agentic-observability-protocol`.
- Composed: `maos:{persona-pipeline,perspective-trio,cascade-resolver,convergence-engine,decision-capture}` + `bin/convergence-guard` + role-advisor agents.
- External (deep-research): AgentCore/Cedar (default-deny PEP) · OWASP LLM06 · LawZero verifier/generator separation · EU AI Act Art.14 · NIST AI RMF · MIT Sloan Explainability Paradox · Google AP2 · Athenian Boule.
- Cross-link: `[[council-gate]]` · soul *Boule*.

## §Changelog
| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-07-14 | Bootstrap — executable counterpart to the `council-gate` constitutional rule. Two-layer gate (deterministic deny-set FIRST + probabilistic council within-cleared-band), 33-socratic interrogation, democratic council (eligibility filter · no-unilateral · super-powers-non-default), armed-for-safe-class predicate, Explainability-Paradox guard (independent verifier + contestable-evidence hand-off), Metron falsifiability. **Ships UNARMED** (consultative; no self-arm). Composes existing maos primitives — no new engine. Registered via artifact-registry (DUP-check CLEAR). |
