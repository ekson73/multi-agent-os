---
name: agentic-delegation
version: "1.1.0"
allowed-tools: Read, Grep, Glob, Bash, Task
description: Use when about to spawn a subagent/skill/task (Task tool, Agent tool, /command). Defines 6 decision criteria (decomposable/specialist-exists/audit-capacity/score≥MEDIUM/not-HUMAN-DOMAIN/time-budget), 11 mandatory briefing components (context/scope/motivation/purpose/objective/DoR/DoD/deliverables/feedback-loops/constraints/channel-fallback-chain), accountability preservation (parent NEVER delegates accountability — only execution; "delegating does not waive the responsibility received"), recursion ≤2, parallel ≤3. Harmonizes the agentic-inheritance principle (tree-returns-to-root · subordinate-is-parent's-full-responsibility · audit-output · zero-drift). Cross-vendor AAIF.
---

# Agentic Delegation — Criteria & Discipline

> **Origin**: operator directive 2026-05-12 codifying delegation discipline — *"whenever useful and justified, use recursive sequential parallel delegation with accompaniment, with proper context, scope, motivation, purpose, objective, DoR, DoD, feedback/retro-loop, expected deliverables, etc; remember that delegating does not waive the responsibility received. Define the agentic delegation criteria."*
>
> **Version**: 1.1.0 (2026-08-16 rubric-driven MINOR; 1.0.0 = 2026-05-17 community promotion of an extraction from the operator's host-local `auto-self-harness §12`-equivalent rule body).
>
> **Source lineage**: operator's host-local `auto-self-harness` rule §12-equivalent (the parent framework section the operator maintains; host-dependent location).
>
> **Harmonization principle (verbatim, agnostic of source)**: "the delegated subordinate is the parent's full responsibility · the tree returns to the root · audit the output · zero drift."

## 1. Decision criteria — when to delegate (6 conditions, all mandatory)

| # | Criterion | Question |
|---|---|---|
| 1 | **Decomposable** | Does the task have clear interfaces + isolatable components? |
| 2 | **Specialist exists OR forgeable** | Is a competent subagent/skill available in the catalog OR forgeable via an auto-agent-forger pattern? |
| 3 | **Parent audit capacity** | Does the parent have time + knowledge to audit the output after? (NEVER blind-delegate) |
| 4 | **Autonomy score ≥ MEDIUM (0.65)** | Is the score acceptable OR is the delegation itself a Score Uplift Path B? If pure LOW → escalate, do NOT delegate |
| 5 | **NOT in HUMAN_DOMAIN** | Task is outside the escalation list (operator-personal / irreversible / cross-org / secrets / PII / etc.) |
| 6 | **Time-budget allows verification** | Audit time ≤ delegation time (else delegation is not worth the cost) |

**6/6 PASS → delegate. ≥ 1 FAIL → execute inline OR escalate.**

## 2. Briefing components — WHAT to brief (11 mandatory items)

Every spawn MUST include all 11. Skipping any item is the under-briefing anti-pattern.

| # | Component | Content |
|---|---|---|
| 1 | **Context** | Current state, history, related artifacts (paths/links) |
| 2 | **Scope** | In-scope explicit + Out-of-scope explicit (anti-creep) |
| 3 | **Motivation** | Business/technical value (why it matters) |
| 4 | **Purpose** | Intent served (intent ≠ task) |
| 5 | **Objective** | Measurable outcome (specific + measurable) |
| 6 | **DoR** (Definition of Ready) | Inputs / dependencies / preconditions (subagent validates they are met) |
| 7 | **DoD** (Definition of Done) | Acceptance criteria + verification method (objective) |
| 8 | **Deliverables** | Artifacts list + format + paths/return-data shape |
| 9 | **Feedback loops / retro** | How progress is reported + how the parent gives feedback (sync/async) |
| 10 | **Constraints** | Time-box + risk tolerance + escalation triggers |
| 11 | **Channel fallback-chain** | Alternative channels/carriers declared BEFORE the first spawn (e.g. `primary CLI → alternate CLI → lead-executes`) — quota/outage mid-loop is a when, not an if; a delegation without one is fragile by construction (observed live 2026-08-15: two CLI channels hit weekly/quota limits mid-chain; rubric anchor C2) |

## 3. Accompaniment — HOW to supervise (5 disciplines)

1. **Check-in cadence** defined upfront (sync streaming OR async polling)
2. **Termination conditions** explicit (success / failure / interrupt / timeout)
3. **Audit checklist** post-completion (zero-drift: output matches brief?)
4. **Artifact verification (non-delivery detection)** — MANDATORY: every delegation names the
   expected artifact upfront (file, PR, JSON, row); after the spawn returns, the parent VERIFIES the
   artifact exists and is non-empty. **Empty stdout with rc=0 is NOT success.** A missing/empty
   artifact = a failed spawn (counts toward the 6-failure rule). Observed live 2026-08-15: two
   executor spawns died of quota mid-run producing exit-0 silence; the parent detected it only via
   the missing file. (Rubric anchor: `docs/rubrics/v0.1/agentic-delegation.md` C1)
5. **Re-spawn discipline** with brief refinement (max 6 attempts per the 6-failure escalation rule below)

## 4. Accountability — WHO retains (parent does NOT waive)

> *"Delegating does not waive the responsibility received."* (operator directive)
>
> The parent NEVER delegates accountability — only execution.

| Responsibility | Who |
|---|---|
| Execution (the work) | Subagent (delegated) |
| Audit of the output | **Parent** (NOT delegated) |
| Final signoff | **Parent** (NOT delegated) |
| Escalation decision | **Parent** (NOT delegated) |
| Memory persistence at user-scope | **Parent** (operator-confirm-always) |
| BEING > Rules preservation | **Parent** (recursively across the delegation tree) |

**6-failure rule** (autonomous-resolution protocol equivalent): if a subordinate fails 6× with different approaches, the parent escalates to the operator with: complete context + 6 attempts + hypotheses + recommendations + evidence.

## 5. Modes — recursive sequential OR parallel

| Mode | When to use |
|---|---|
| **Sequential** | Dependencies among subtasks (parent needs output A before spawning B) |
| **Parallel** (max 3) | Subtasks independent; lower wall-clock; auto-orchestrator default |
| **Recursion depth = 1** | Parent → child (direct) |
| **Recursion depth = 2** | Parent → child → grandchild (child auto-forges OR sub-delegates) |
| **Recursion ≥ 3** | ❌ FORBIDDEN — universal constraint; cycle detection mandatory |

## 6. What CAN be delegated (universal taxonomy)

- **Personas / Mind-sets** (cognitive lenses): Tomé · Critical · Devil's-Advocate · Fowler · DHH · Pragmatic · Empiricist · SecOps · Conservative · Aggressive · etc.
- **Specialist subagents**: debugger · architect · qa-engineer · security-reviewer · Explore · general-purpose · code-reviewer · etc.
- **Delegate-able skills**: `operator-quote-capture` · `auto-orchestrator` (or `auto-pilot`) · `find-docs` · `rule-quality-tests` · `agentic-delegation` (this skill) · `pre-decision-audit`
- **Best-fit routing** via auto-orchestrator Phase 0 + auto-agent-forger Phase 0.5
- **Standard delegation chain** — e.g., Analyst → Architect → QA(critique) → Dev → QA(validation) → Doc (operator-host framework core directive)

## 7. What CANNOT be delegated (always parent)

| Item | Why |
|---|---|
| Final accountability + signoff | §4 of this skill retains |
| Decisions in HUMAN_DOMAIN | Escalation list non-negotiable |
| Audit of the subordinate's output | Zero-drift principle |
| Escalation choice | Parent owns escalation criteria |
| Memory persistence at user-scope | Operator-confirm-always |
| BEING > Rules preservation | Foundational — propagates recursively |

## 8. Bounds (anti-eternal compliance — see `rule-quality-tests` skill)

- Max recursion depth: **2**
- Max parallel delegations: **3**
- Time-box per delegation: **specified upfront** (default 15 min)
- Audit time ≤ delegation time
- Max failure attempts: **6** before escalation
- Per-task feedback log retained for retro
- Cycle detection mandatory (abort if `A → B → A`)

## 9. §11 Quality Tests application (this skill dogfooded)

Per the sibling `rule-quality-tests` skill:

| Test | Self-application | Result |
|---|---|---|
| Self-Application | Codifying this skill IS an act of delegation (to a future agent applying the criteria) | ✓ |
| Non-Contradiction | 6 + 11 + 6 + 6 + 5 + 6 components internally consistent | ✓ |
| Survival | Skill applied to itself survives | ✓ |
| Bounded-Responsibility | All counts explicitly bounded | ✓ |
| Explicit-Exception | "Skip if 1/6 FAIL"; HUMAN_DOMAIN exception; Escape Clause Universal | ✓ |
| Utility-Sunset | Deprecate when the delegation reflex is internalized without invoking this skill | ✓ |

**6/6 PASS** — skill passes its own tests and the tests of `rule-quality-tests`.

## 10. BEING > Rules compliance check

| Question | Answer |
|---|---|
| Does this skill HELP or OBSTRUCT the operator? | **HELPS** — discipline reduces errors, preserves accountability |
| Does it serve BEING? | YES — codifies a pre-existing agentic-inheritance principle |
| Is the hierarchy preserved? | YES — Operator (1) > delegation criteria (2) > delegation mechanisms (3) |

**PASS** — skill serves BEING, not vice-versa.

## 11. Sunset (per DUED — Dormant-Until-Evident Deprecation)

Deprecation candidate when ANY qualitative evidence:

- **E3** — Operator reaches the delegation reflex (≥ 10 zero-regret cross-session decisions without skill invocation; the parent passes all 6 criteria automatically)
- **E4** — Operator explicit retraction
- **E6** — Better composable orchestration emerges (e.g., the framework upgrades and collapses this section into Phase 0/2 of `auto-orchestrator` / `auto-pilot`)

No counter-based sunset. Insurance discipline — dormant-by-design.

## 12. Refs

- Operator's host-local framework SSOT — the agentic-inheritance principle (`tree-returns-to-root` / `subordinate-is-parent's-full-responsibility` / `audit-output` / `zero-drift`)
- Operator's host-local framework SSOT — the autonomous-resolution protocol (6-failure escalation rule origin)
- Source skill: `auto-orchestrator` (or `auto-pilot`) Phase 0/0.5/2 — validated patterns reused
- Source rule: operator's host-local `auto-self-harness §12`-equivalent (pointer back to the inline summary)
- Score Uplift Path B — delegation as score-uplift mechanism
- HUMAN_DOMAIN escalation list (do NOT delegate)
- Cognitive scaffolds + execution scaffolds — delegate-able catalog
- Sibling skill: `rule-quality-tests` — 6 Quality Tests + Escape Clause Universal (delegation also subject to BEING > Rules)
- Sister rule: `cowork-process-topology-protocol` (when present at the host) — persists the topology of every delegation chain (materializes §3 accompaniment + the `tree-returns-to-root` principle); per-subtree JSONL co-responsibility implements §4 + briefing components are encoded as topology-node `refs` schema. Compass API (`next` / `siblings` / `children` / `current` / `parent` / `root_path`) makes the delegation N-Tree queryable cross-session.
- Sister skill in this repo: `skills/converge` — debate-convergence kernel; complementary discipline.

## 13. Changelog

| Version | Date | Change |
|---|---|---|
| 1.1.0 | 2026-08-16 | MINOR — rubric-driven (pilot eval FAILs C1+C2, PR #354): adds accompaniment discipline #4 "Artifact verification (non-delivery detection)" (empty stdout + rc=0 ≠ success; missing artifact = failed spawn) and briefing component #11 "Channel fallback-chain" (declared before the first spawn). Both from observed live failures 2026-08-15. |
| 1.0.0 | 2026-05-17 | Community promotion from a user-scope skill of the same version (extraction from the operator's host-local `auto-self-harness §12`-equivalent rule body). Sanitization: replaced all proprietary attributions with generic equivalents (agentic-inheritance principle · autonomous-resolution protocol · standard delegation chain · host-local framework SSOT); replaced host-absolute paths with portable descriptions; preserved the 6 criteria + 10 briefing components + 4 accompaniment disciplines + accountability rule + recursion bounds + Quality Tests dogfooding + BEING > Rules compliance + DUED sunset. License: MIT. |
