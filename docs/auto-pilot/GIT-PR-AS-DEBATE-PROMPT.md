# Git-PR-as-Debate-Prompt — Methodology

> **What this is**: A multi-AI cross-perspective debate methodology that uses **GitHub Pull Request comments as the conversation substrate**, leveraging bot reviewers (amazon-q · Copilot · CodeRabbit · Qodo · etc.) plus spawned cognitive perspectives, with a master-PR as root umbrella + targeted sub-PRs for individual divergence points + anti-loop stop-trigger with meta-critique.
>
> **Why PR comments**: persistent · public · attributable · markdown-rich · bot-native integration · async-friendly · diff-anchored · cross-vendor portable.
>
> **Status**: experimental pattern · cycle 0 (this is the first dogfood) · promotion gate: ≥ 2 successful cycles required before extraction as canonical agentic-tool (operator-private governance MAY add stricter criteria; community gate is minimum-2).
>
> **Version**: v0.1.0 · **Date**: 2026-05-17 · **License**: MIT.

---

## 1. Stack (compose, don't reimplement)

| Layer | Artifact | Role |
|---|---|---|
| Debate primitive | [`skills/converge/SKILL.md`](../../skills/converge/SKILL.md) v1.1.1 — 5-act protocol + Invariant 6 + reject log | Vendor-neutral N-proposal synthesis core |
| Channel | GitHub Pull Request comments (master + sub) | Persistent · public · diff-anchored substrate |
| Native participants | amazon-q-developer · GitHub Copilot · CodeRabbit · Qodo (capability-detected per [`pr-review-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/pr-review-protocol.md) §4 escape clauses) | Multi-vendor bot reviewers |
| Spawned participants | 8 cognitive perspectives — Tomé · DHH · Devil's-Advocate · Fowler · Pragmatic · Empiricist · SecOps · 90/10-Visionary (extensible) | Diverse mental models |
| Comment convention | [`.claude/rules/pr-reviewer-communication.md`](../../.claude/rules/pr-reviewer-communication.md) v1.0.0 — `@mentions` + tables + re-review timeouts | Channel hygiene |
| Sub-PR rationale | This document §4 — gate before creating any sub-PR | Anti-overload |
| Stop-trigger | This document §5 — ≤ 3 rounds · ≤ 6h wall-clock · per-round meta-critique · `no-convergence-possible` exit | Anti-loop |
| Final docs | ADR · PRD · BRD · RN · RF · RNF · CHANGELOG · master-plan delta | Per-convergence artifacts |

---

## 2. Roles (humans + AI agents as Cowork team members)

| Role | Responsibility |
|---|---|
| **Operator** (HITL) | Authorizes merges (scope-limited per `[C07]` v2.1.0); breaks tie if `no-convergence-possible`; defines goal + stop-conditions; final approval before extraction of agentic-tool |
| **Orchestrator agent** | Runs `skills/converge` 5-act per round; spawns perspectives; aggregates votes; emits per-round status + meta-critique; manages sub-PR creation per rationale gate |
| **Bot reviewers** (native) | Review per their default cadence (amazon-q on push · Copilot opt-in · CodeRabbit incremental); their conclusion (`SUCCESS`/`FAILURE`/`NEUTRAL`) feeds the votes |
| **Cognitive perspectives** (spawned) | Each lens emits structured critique per `skills/converge` §ACT 2 with citations to PR diff text; non-replaceable identifiers (Tomé · DHH · etc.) |
| **Reject-log keeper** | One designated agent (default: orchestrator) maintains the non-lossy rejection record per `skills/converge` §ACT 5 |

---

## 3. Master-PR flow (root / umbrella)

```text
┌──────────────────────────────────────────────────────────────────┐
│ STEP 0 — Operator declares goal + invokes /pr-debate (future     │
│          slash command) OR manual run of this methodology         │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 1 — Author master-plan draft (or amendment to existing)      │
│          + N≥2 proposals in PR body + cognitive perspectives list │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 2 — Open master-PR with debate-startup-prompt body           │
│          (use templates/master-pr-debate-prompt.template.md)      │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 3 — Round N (default max=3):                                  │
│   3a. Spawn N cognitive perspectives (parallel where N ≤ 3,       │
│       sequential for larger pools — Task tool constraints)         │
│   3b. Each emits ACT 1 steelman + ACT 2 critique with citations    │
│       posted as PR comments                                        │
│   3c. Bot reviewers run their default cycle                        │
│   3d. Orchestrator aggregates → ACT 3 comparison table             │
│       posted as PR comment                                          │
│   3e. Per-round meta-critique question: "is the process serving    │
│       the goal OR becoming the goal?" — answer in PR comment       │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
                       Convergence reached?
                          /          \
                       YES            NO  ──► STEP 4 OR sub-PR
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 5 — ACT 4 synthesize + ACT 5 reject log → final master-plan │
│          delta. Generate ADR/PRD/BRD/CHANGELOG as applicable.    │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 6 — HITL merge gate per [C07] v2.1.0 (operator-only).        │
│          Cleanup post-merge: worktree remove · branch -D · sync.  │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 7 — Capture memory entry (feedback_*) + cross-link issues.   │
│          IF cycle-count ≥ 2 → trigger extraction as agentic-tool. │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. Sub-PR creation rationale (gate BEFORE creating any sub-PR)

Sub-PRs exist ONLY to prevent master-PR overload. Apply BOTH gates:

| Gate | Trigger |
|---|---|
| **Gate A (size)** | Master-PR thread exceeds 30 substantive comments AND a divergence cluster represents ≥ 25% of the thread volume |
| **Gate B (structure)** | Divergence has axiom-level shape — proposals operate from incompatible foundational assumptions — that would derail master if forced inline (per `skills/converge` Failure modes "Contradictory at axiom level") |

If **NEITHER** gate triggers → resolve inline in master-PR. If **EITHER** triggers → spawn sub-PR with:
- Branch: `debate/auto-pilot-<divergence-slug>` (typed prefix `debate/` distinguishes from feature work)
- Body: use [`templates/sub-pr-debate-prompt.template.md`](./templates/sub-pr-debate-prompt.template.md)
- Cross-link both directions: sub-PR body links to master-PR; master-PR adds comment linking to sub-PR
- Merge order: sub-PRs **first**, master **last** (sub-PR verdicts feed master's ACT 4)

Anti-pattern: **eager sub-PR creation** — over-fragmenting destroys the master's role as umbrella. Always apply scope-discipline 6Q Q3 ("WHY now?") before creating each sub-PR.

---

## 5. Stop-trigger + anti-loop (mandatory)

### Stop conditions (ANY-of breaks the cycle)

| # | Condition | Action |
|---|---|---|
| S1 | **Convergence reached** — ≥ `consensus_threshold` (default 0.85 for strategic decisions) on top-3 axes | Proceed to STEP 5 |
| S2 | **Max rounds hit** — default 3 rounds × 8 perspectives = 24 critique iterations cap | Emit `no-convergence-possible` per `skills/converge` Failure modes; escalate operator |
| S3 | **Wall-clock exceeded** — default 6h total | Emit pause-state; preserve PR comments as resumable; operator decides extend OR escalate |
| S4 | **Diminishing returns** — round N+1 produces ≤ 10% new info vs round N | Stop; emit partial-convergence verdict |
| S5 | **Axiom-level contradiction** — proposals operate from incompatible foundational assumptions | Emit `no-convergence-possible` per converge §Failure modes; escalate operator |
| S6 | **Operator interrupt** | Preserve state in PR comments; honor user's stop |
| S7 | **HITL budget exhausted** — > 1 escalation per round OR > 3 total | Stop; emit operator-fatigue diagnostic |
| S8 | **Bot infrastructure degraded** below quorum — < 2 active bot reviewers (e.g., amazon-q + Copilot both down) | Skip bot vote; rely on spawned perspectives + operator only; flag in audit log |

### Meta-critique question (mandatory per round)

After each round's ACT 3 (comparison table), orchestrator emits ONE PR comment with:

```text
META-CRITIQUE — Round N

Question: Is the debate serving the goal OR becoming the goal?

Process: <1-2 sentences observing process health — e.g., "round N added 1 novel
concern (X) and rehashed 3 prior concerns; productivity declining">

Plan: <1 sentence on whether to continue / change direction / stop>

Method: <1 sentence on whether the toolkit (8 lenses · converge 5-act ·
sub-PR rationale) is fit for the divergence we're seeing, OR whether
we should add/swap perspectives>

Recommendation: continue | refine-direction | add-perspective | stop
```

### Adding new perspectives mid-cycle

Apply Dogfooding R7 (try yourself first) — operator/orchestrator must **identify the missing perspective** (not just "more agents = better"). Trigger conditions:

1. Existing 8 lenses produced overlap > 70% across rounds (echo chamber)
2. A specific blind-spot keeps surfacing in meta-critique without owner
3. External evidence (e.g., empirical research from Agent #3) suggests a missing mental model

Add max 2 new perspectives per cycle (Goldilocks discipline).

---

## 6. Layer-purity (binding)

Per [`~/.claude/rules/layer-precedence-policy.md`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/layer-precedence-policy.md) v1.0.0:

- Community ([`ekson73/multi-agent-os`](https://github.com/ekson73/multi-agent-os)) MUST NOT contain Vek-specific names · paths · acronyms · proprietary refs
- Community ⇒ corp consumption is OK; corp ⇒ community contribution NEVER
- Bot/PR-comment content in debate counts as community-bound; sanitize before incorporating any operator-quoted material with corp tokens (`VKS-*`, `vek-*`, `VKL-*`, etc.)
- Sanitize-or-strip · do not echo

---

## 7. Quality gates (every artifact emitted by debate)

| Gate | Check | Source |
|---|---|---|
| Anti-theater REALITY 8/8 | Real · ¬Theater · ¬Hallucinated · ¬Invented · Viable · Applicable · Implementable · Useful | [`anti-theater-grounding-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/anti-theater-grounding-protocol.md) |
| §11 Quality Tests 6/6 | Self-Application · Non-Contradiction · Survival · Bounded-Responsibility · Explicit-Exception · Utility-Sunset | [`auto-self-harness`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/auto-self-harness.md) `[C17]` §11 |
| §0 SER > Rules | Rule-application HELPS NOW? (skip + log se OBSTRUCTS) | `[C17]` §0 |
| Scope-discipline 6Q | Q1-Q6 PRE-creation | [`scope-discipline-pre-creation`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/scope-discipline-pre-creation.md) |
| Converge Invariant 6 | Audit-not-persuasion · neutral framing · no leading questions to next agent | `skills/converge/SKILL.md` §Invariants |
| Bot convergence | All named active bots `SUCCESS` per `pr-review-protocol` v2.0.0 §4 | [`pr-review-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/pr-review-protocol.md) |

---

## 8. Output artifacts (post-convergence)

| Artifact | When | Where |
|---|---|---|
| `ADR-NNN-<topic>.md` | per architectural decision in convergence | [`docs/auto-pilot/`](./) (this dir) |
| `PRD-<scope>.md` | if user-facing functional change | [`docs/auto-pilot/`](./) |
| `BRD-<scope>.md` | if business-context warrants | [`docs/auto-pilot/`](./) |
| `RN/RF/RNF-*.md` | requirements per dimension | [`docs/auto-pilot/`](./) |
| `MASTER-PLAN.md` update | always — append convergence ID to §8 decision log + bump version §10 | [`docs/auto-pilot/MASTER-PLAN.md`](./MASTER-PLAN.md) |
| `CHANGELOG.md` update | always — Unreleased section under target version | [`CHANGELOG.md`](../../CHANGELOG.md) repo-root |
| `skills/auto-pilot/SKILL.md` update | post-convergence v0.2+ | [`skills/auto-pilot/SKILL.md`](../../skills/auto-pilot/SKILL.md) — separate PR after debate concludes |
| Memory entry `feedback_*` | always — lessons learned per `[C17]` §3.5 quote capture filter | `~/.claude/projects/<encoded>/memory/` |

---

## 9. Extraction trigger (agentic-tool)

After ≥ 2 successful cycles (Dogfooding R1+R3+R7), extract this methodology as a reusable agentic-tool. Candidate forms (operator decides per scope-discipline 6Q Q1):

| Form | Where | Why |
|---|---|---|
| **skill** `git-pr-as-debate` | `multi-agent-os/skills/git-pr-as-debate/` | AAIF cross-vendor; invocable from any host |
| **command** `/pr-debate` | `multi-agent-os/commands/` | Slash-command UX (Claude Code primary) |
| **subagent** `auto-pr-debate-orchestrator` | `~/.claude/agents/` | Heavy orchestration delegated; preserves main context |
| **plugin bundle** | `eko-claude-plugins` OR community marketplace | Distribution + governance |

Default choice: **skill** (highest portability per AAIF) + **command** (best operator UX in Claude Code) — both pointing to the same backing logic per [`auto-orchestrator`](https://github.com/ekson73/vek-dot-claude/blob/main/skills/auto-orchestrator/SKILL.md) precedent (skill mirror of slash command).

If < 2 cycles → mark as **experimental pattern**; defer extraction. NEVER premature-promote (anti-pattern per dogfooding-mandate).

---

## 10. Refs

- Master-plan: [`docs/auto-pilot/MASTER-PLAN.md`](./MASTER-PLAN.md)
- Templates: [`templates/master-pr-debate-prompt.template.md`](./templates/master-pr-debate-prompt.template.md) · [`templates/sub-pr-debate-prompt.template.md`](./templates/sub-pr-debate-prompt.template.md)
- Sister skills: [`skills/converge`](../../skills/converge/SKILL.md) · [`skills/auto-pilot`](../../skills/auto-pilot/SKILL.md) · [`skills/agent-select`](../../skills/agent-select/SKILL.md)
- Sister rules (vek-dot-claude): [`pr-review-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/pr-review-protocol.md) · [`scope-discipline-pre-creation`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/scope-discipline-pre-creation.md) · [`anti-theater-grounding-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/anti-theater-grounding-protocol.md) · [`auto-self-harness`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/auto-self-harness.md) · [`layer-precedence-policy`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/layer-precedence-policy.md) · [`agentic-first-decision-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/agentic-first-decision-protocol.md) · [`ai-as-pwd-axiom`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/ai-as-pwd-axiom.md)
- PR comment convention: [`.claude/rules/pr-reviewer-communication.md`](../../.claude/rules/pr-reviewer-communication.md)
- Empirical refs (citation date 2026-05-17): [BabyAGI](https://github.com/yoheinakajima/babyagi) · [AutoGPT pivot](https://github.com/Significant-Gravitas/AutoGPT) · [CrewAI](https://www.crewai.com/) · [AutoGen Magentic-One](https://www.microsoft.com/en-us/research/blog/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/) · [LangGraph](https://langchain-ai.github.io/langgraph/) · [OpenHands](https://github.com/All-Hands-AI/OpenHands) · [AAIF spec](https://agentskills.io/specification)

---

## 11. Changelog

| Version | Date | Change |
|---|---|---|
| v0.1.0 | 2026-05-17 | Initial methodology — composes `skills/converge` + GitHub PR comments + bot reviewers + spawned perspectives + sub-PR rationale + stop-trigger + meta-critique + extraction trigger. PRE-DOGFOOD: this is cycle 0; promotion to canonical agentic-tool gated on ≥ 2 successful cycles (community minimum; operator-private governance MAY add stricter criteria). |
