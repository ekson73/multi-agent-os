---
name: red-team
version: "0.1.0"
description: |
  Decide WHEN an adversarial red-team is MANDATORY for an action, and HOW deep — then
  route to the right existing primitive (build nothing new). Soul-name Elenchus (Socratic
  ἔλεγχος — refutation by cross-examination). Red-teaming = adversarial verification BY
  CONSTRUCTION: an INDEPENDENT verifier (≠ the author/generator, rewarded for BREAKING the
  artifact) — independence is constitutive, distinct from ordinary review. The trigger is a
  deterministic hard-trigger predicate (secrets · production regulated personal data ·
  irreversible high-blast · unattended side-effect · auth/crypto/access-control/guardrail
  change · self-edit of a binding rule · cross-org/disclosure · untrusted-input-steered
  side-effect · aggregate campaign · fail-open flip) OR self-scored criticality HIGH — the
  trip-wires OVERRIDE the score, never a magic %. Composes bin/convergence-guard (master
  condition), perspective-trio (triplet-D adversarial), cascade-resolver (role-5), converge
  (devil_advocate). Use when deciding "does this action need a red-team, and how much",
  before a merge / irreversible / high-autonomy effect.
  Triggers: "should this be red-teamed", "red-team this", "is an adversarial review
  mandatory here", "do we need an independent break-it check", "how deep should the
  red-team be", "adversarial verification gate".
allowed-tools: Task, Read, Bash, Grep, Glob
---

# Red-Team

> **Soul-name Elenchus** (ἔλεγχος — Socratic refutation by cross-examination; display-only. Canonical system-name = `red-team`.)

A thin **decision-procedure + orchestrator**. Red-Team answers two questions and routes — it **builds nothing new**, exactly as `convergence-engine` composes primitives:

1. **WHEN is an adversarial red-team MANDATORY for this action?** (the trigger predicate)
2. **HOW deep, and by which existing primitive?** (route to `convergence-guard` / `perspective-trio` / `cascade-resolver` / `converge`)

> **Principle**: red-teaming = **adversarial verification BY CONSTRUCTION** — an **INDEPENDENT** verifier (≠ the author/generator) **rewarded for breaking** the artifact. Independence is *constitutive*: an author reviewing its own output is not a red-team (self-critique paradox — same-source critique on clean output *degrades* it). Master condition (borrowed from `convergence-engine`): `verifier_accuracy > generator_accuracy AND verifier independent` — gated deterministically by `bin/convergence-guard`.

## §0 — BEING > Rules (foundational)

This gate serves delivery, not ceremony. A red-team that obstructs shipping a **clean, already-verified, low-risk, reversible** output is theater — skip it via the deterministic Step-0 floor and log why. But the gate is **not optional when a hard-trigger fires**: safety-critical trip-wires exist precisely because a self-assessed "this is fine" is where breaks hide.

## Purpose

Turn "should we red-team this?" from a vibe into a **deterministic, logged, self-exemption-resistant decision** — mandatory on hard-triggers *or* HIGH criticality, skipped-with-reasons on trivial reversible work — then run it by composing the repo's adversarial primitives at the right depth.

## When to use

- Before a **merge / irreversible / high-autonomy / unattended** effect, to decide if an independent break-it check is required first.
- When an action touches **secrets · production personal data · auth/crypto/access-control/a guardrail · a binding governance rule · an external/customer-facing surface · an untrusted-input-steered side-effect**.
- When a cowork/autonomous agent operates at high autonomy and must **ratchet verification up** before landing.

## When NOT to use

- Trivial, reversible, no-side-effect changes (typo, whitespace, docs-only with no semantic security/governance change) → Step-0 floor.
- The **same artifact-state** already got an equivalently-independent adversarial review (idempotency — do not re-red-team unchanged content).
- Validating a *rule's* self-consistency (→ `rule-quality-tests`) or measuring run-level reliability (→ observability). Red-Team is a *pre-action gate*, not a QA scorer.

## The trigger predicate (the decision procedure)

```text
STEP 0 — DETERMINISTIC + LOGGED skip floor (anti-fatigue):
  IF  action is comment/whitespace/docs-only
   AND no security/governance semantic change
   AND fully reversible
   AND no external side-effect
   AND no regulated-personal-data / secret touched
   AND not on an untrusted-input path
  THEN red-team N/A — LOG the reasons; STOP.

STEP 1 — PRIMARY gate (deterministic, f=0 oracle):
  IF  ANY hard-trigger H1..H12 fires (instance-level, not verb-class)
  THEN red-team MANDATORY.

STEP 2 — SECONDARY widener (self-scored):
  criticality := f(risk, impact, reversibility)   ← the {risk,impact,reversibility} triple
                 (NOT the autonomy/confidence "high" band — that is near-INVERTED:
                  high confidence usually means low-risk & low-impact)
  IF  criticality >= HIGH  THEN red-team MANDATORY.

DEPTH:
  MEDIUM & no hard-trigger        → 1 independent refuter (≠ author).
  HIGH  OR any hard-trigger       → >=2-3 orthogonal adversarial lenses; structural
                                    independence ENFORCED (convergence-guard).
  Independence unavailable @ HIGH → HOLD, do not force (fail-safe).
```

## Hard-triggers (H1–H12 — PRIMARY; any ONE ⇒ MANDATORY)

Instance-level, not verb-class (e.g. an *idempotent, sandboxed* delete is not H3; a *behavioral* auth change is H5, a cosmetic touch is not). Each tagged with one of 8 dimensions: `context · scope · impact · risk · security · autonomy · severity-criticality · privacy-data`.

| # | Hard-trigger (instance-level) | Dim |
|---|---|---|
| **H1** | Secrets / credentials / keys touched | security |
| **H2** | Production **regulated personal data** at scale (GDPR / data-protection regimes) | privacy-data |
| **H3** | **Irreversible** ∧ non-trivial blast-radius (instance reversibility × blast, not verb-class) | risk |
| **H4** | Autonomous **UNATTENDED** action with a real side-effect + **no human present** | autonomy |
| **H5** | **BEHAVIORAL** change to auth / crypto / access-control / a guardrail (not a mere touch) | security |
| **H6** | **Self-edit of a binding governance / policy rule** (fail-open there = system-wide) | scope |
| **H7** | Cross-org / external / customer-facing / **disclosure** (irreversible-as-leak) | context |
| **H8** | **No prior successful precedent** in the audit trail (external-novelty, not felt-novelty) | context |
| **H9** | **Dangerous-capability** domain (CBRN / offensive-cyber) — documented-N/A for ordinary software work | severity-criticality |
| **H10** | **Untrusted / external input steers a side-effect** (prompt-injection; OWASP-LLM01/LLM06) | security |
| **H11** | **Aggregate / rate**: N side-effecting autonomous actions in a window → red-team the **CAMPAIGN**, not each one | impact |
| **H12** | **Fail-open flip** (deny→allow / closed→open) | risk |

## The soft criticality band (SECONDARY widener)

| Band | Depth |
|---|---|
| **LOW** — reversible, low-blast, no trigger | none (Step-0 or routine) |
| **MEDIUM** | **1 independent refuter** (≠ author) |
| **HIGH** | **≥2–3 orthogonal adversarial lenses**, independence enforced |

> ⚠ **This band is the `{risk, impact, reversibility}` criticality triple — NOT the (near-inverted) autonomy/confidence band.** A self-assessed "I'm highly confident" typically means *low* risk & impact — the **opposite** of what should trigger a deeper red-team. Never route depth off confidence; route it off criticality.

## The honest answer to "from what X% / rate?"

**Deliberately NOT a magic number.** A numeric threshold is Goodhart-gameable and invites under-scoring. Red-team is mandatory when **ANY hard-trigger fires (deterministic, PRIMARY)** OR **criticality is HIGH (self-scored, SECONDARY)** — and the **trip-wires OVERRIDE the score**. This mirrors how safety regimes work: mandatory-DPIA hard-triggers under **GDPR Art. 35(3)**, and a **DO-178C** "catastrophic" DAL bypasses any computed budget — the trip-wire wins over the number.

## How the red-team runs (compose primitives — build nothing new)

1. **Gate the master condition first** — deterministically, before any lens runs:
   `bin/convergence-guard --generator <author-axis> --verifier <independent-axis> [--oracle available|none --oracle-result pass|fail|na]`
   → exit `0` ALLOW · `3` REFUSE. **Every REFUSE is fail-CLOSED — never proceed on it**, whatever the cause: (a) same brand/axis as author, or a clean deterministic oracle already passed a high-confidence output → **swap to a cross-axis/cross-brand verifier, or DEFER to HITL**; (b) missing / invalid / ambiguous inputs → **fix the inputs and re-gate** (never bypass the gate to "unblock"). A REFUSE is the safe default — treat an un-parsed/ambiguous result exactly as REFUSE. This is what makes the verifier *independent + stronger* rather than a rubber stamp.
2. **Run the adversary at the routed depth** — the verifier is framed to **break** the artifact (find the bypass, the injection, the fail-open, the missed case), not to approve it.

| Depth / function | Primitive (compose) | Path |
|---|---|---|
| Master-condition gate (verifier > generator + independence) | `convergence-guard` | `bin/convergence-guard` |
| **1 independent refuter** (MEDIUM) | `cascade-resolver` — role 5 **Adversarial Red-team** (+ role 6 **Compliance-Checker** if regulatory) | `agents/cascade-resolver.md` |
| **≥2–3 orthogonal adversarial lenses** (HIGH / any hard-trigger) | `perspective-trio` — **triplet D** (First-principles / Pattern-matching / **Adversarial-redteam**; auto-picked for security/compliance) | `agents/perspective-trio.md` |
| Synthesis + **reject-log** across refutations | `converge` — `devil_advocate: on` | `skills/converge/SKILL.md` |
| Regime routing / economic stop around the loop | `convergence-engine` | `skills/convergence-engine/SKILL.md` |

On a confirmed break → **HOLD**, fix at root, re-gate. At HIGH with **no independent verifier available → HOLD, do not force** (fail-safe; never land an un-refuted high-criticality change).

## Anti-fatigue & anti-gaming guards

- **Deterministic + LOGGED Step-0 floor** — don't red-team a typo; but the skip is *recorded with its reasons*, never silent.
- **Idempotency** — a red-team already passed on the **same artifact-state** is credited (hash/compare); unchanged content is not re-red-teamed (parallels `convergence-guard`'s clean-oracle-pass selectivity gate).
- **Credit an equivalent independent review** — a human PR reviewer (≠ author) who actively tried to break it counts; don't duplicate.
- **Self-exemption guard** — the hard-triggers H1–H12 are **PRIMARY and deterministic**, so an agent **cannot under-score its OWN action's criticality (Step 2) to dodge** a mandatory red-team: Step 1 fires independent of the self-score. The generator is never the sole criticality judge on the trip-wire axis (fox-guarding-henhouse).

## Skip conditions

- Step-0 floor satisfied (trivial · docs-only · reversible · no side-effect · no secret/personal-data · no untrusted-input path) — logged.
- Idempotency credit: this exact artifact-state already got an equivalently-independent adversarial review.
- No hard-trigger AND criticality < MEDIUM (routine low-stakes reversible work).
- Operator de-scoping — the **AGENT can NEVER self-exempt** from a hard-trigger (that is the self-exemption guard; a hard-trigger always overrides an *agent's* self-assessed skip). Only a **human operator** may authorize proceeding without the red-team, and only via an **explicit, logged, scope-limited HITL exception** (this one action — never a standing waiver), and **never** for the ⛔ ABSOLUTE (secrets exposure). "Mandatory" means the agent has no discretion to skip; a human's audited exception is a separate, bounded decision — not an agent bypass.

## Anti-patterns (do NOT)

1. ❌ **Self-review as red-team** — the author/generator critiquing its own artifact (violates independence; the self-critique paradox degrades clean output).
2. ❌ **Same-axis / same-brand verifier** — correlated blind-spots can't catch the generator's errors (`convergence-guard` REFUSES this).
3. ❌ **Under-score your own action** to dodge Step 2 (defeated by PRIMARY hard-triggers).
4. ❌ **Red-team theater** — running the ceremony but ignoring the refutation / not acting on a found break.
5. ❌ **Red-teaming a typo** — over-reviewing a clean reversible docs-only change (Step-0 floor exists to stop this).
6. ❌ **Forcing a landing at HIGH** with no independent verifier available (must **HOLD, not force**).
7. ❌ **Reinventing** convergence/critique machinery inside this skill (it composes; builds nothing).
8. ❌ **Confidence as a red-team trigger** — high confidence is near-inverted from criticality; route depth off `{risk, impact, reversibility}`.

## Quality tests (6/6 self-validity)

1. **Self-Application** — forged via the forge pipeline (research→type→gate); it red-teams even its own high-stakes routing by requiring an independent verifier, never self-approval. ✅
2. **Non-Contradiction** — composes `convergence-guard` / `perspective-trio` / `cascade-resolver` / `converge` without duplicating them; consistent with the `convergence-engine` master condition + selectivity gate. ✅
3. **Survival** — applied to itself it demands an independent adversarial check; it IS that gate and does not exempt itself (self-exemption guard). ✅
4. **Bounded-Responsibility** — Step-0 skip floor · depth ladder caps (1 / ≤3 lenses) · idempotency · HOLD-not-force · §DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules escape + Step-0 floor + idempotency credit + operator HITL (never waives the ⛔ secrets ABSOLUTE). ✅
6. **Utility-Sunset** — §DUED below. ✅

## §DUED Sunset (qualitative, not counter-based)

Deprecate when ANY: the host provides a native mandatory-adversarial-verification gate that supersedes this (E1) · absorbed into `convergence-engine` as a first-class REFUTE regime (E6) · operator retraction (E4) · ≥3 false-mandatory fires that red-teamed genuinely trivial changes (E5 → refine the Step-0 floor, not deprecate). Dormant-by-design otherwise.

## Examples (invocation prompts — not a CLI)

- **A behavioral guardrail change (H5)** — *"about to merge an access-control change; is a red-team required?"* → MANDATORY → `convergence-guard` gates an independent verifier → `perspective-trio` triplet-D hunts the bypass → break found → HOLD + fix + re-gate.
- **A docs typo (Step-0)** — *"red-team this README fix?"* → floor: docs-only, reversible, no side-effect, no secret → **red-team N/A** (logged) → proceed.
- **An unattended batch of 40 config writes (H4 + H11)** — red-team the **CAMPAIGN** (not each write) at HIGH depth; no independent verifier available → **HOLD, do not force**.

## Prior art & anchors

- **Composed primitives**: `bin/convergence-guard` (master condition) · `agents/perspective-trio.md` (triplet D adversarial) · `agents/cascade-resolver.md` (role 5 / role 6) · `skills/converge/SKILL.md` (devil_advocate + reject-log) · `skills/convergence-engine/SKILL.md` (verifier>generator + selectivity gate).
- **External anchors**: NIST AI 600-1 (Generative AI Profile — includes GAI red-teaming guidance) · the NIST AI Risk Management Framework (AI RMF, AI 100-1) · MITRE ATLAS (adversarial-ML threat matrix) · OWASP Top 10 for LLM Applications (LLM01 Prompt Injection, LLM06) + OWASP GenAI Red Teaming Guide · DO-178C Design Assurance Levels (DAL A–E — catastrophic trip-wires bypass computed budget) · IEC 61508 Safety Integrity Levels (SIL) · GDPR Art. 35(3) (mandatory-DPIA hard-triggers) · Socratic *elenchus* (refutation by cross-examination). *Not cited as a trigger standard: CVSS (a severity scale, not a red-team-trigger standard); an earlier US AI executive order (historical, not current law).*

## Related multi-agent-os artifacts

- `skills/convergence-engine/SKILL.md` — the regime router this gate feeds into (its verifier>generator master condition is the constitutive independence rule).
- `agents/perspective-trio.md` · `agents/cascade-resolver.md` — the adversarial-lens primitives (triplet D / role 5–6).
- `skills/converge/SKILL.md` — synthesis + reject-log across refutations.
- `skills/bot-finding-arbiter` — sibling adversarial-adjudication skill (a reviewer bot's finding is one refutation source).
- `agents/COWORK-AUTONOMY-POLICY.md` — the cowork agents invoke this gate under high autonomy (the mandatory-red-team clause).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-07-13 | Bootstrap — forged via the agentic-tool-forge methodology. Thin decision-procedure + orchestrator: Step-0/1/2 trigger predicate + depth ladder · 12 instance-level hard-triggers (8-dimension-tagged) · soft criticality band (with the confidence≠criticality warning) · composition of `convergence-guard` / `perspective-trio` (triplet-D) / `cascade-resolver` (role-5) / `converge` (devil_advocate) — builds nothing new · anti-fatigue Step-0 floor + idempotency + self-exemption guard · HOLD-not-force fail-safe. 6/6 self-validity + Goldilocks (atomic: WHEN+HOW-deep to red-team; generic: zero org binding). |

## License

MIT (matches multi-agent-os repo `LICENSE`).
