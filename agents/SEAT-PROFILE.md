# Seat Profile — Organizational Levels and Agent Seat Attributes

> **Single SSOT** for (1) the six organizational levels an agentic software factory uses to place
> every decision and task, and (2) the attribute set every delivery agent declares as its
> **seat profile**. Agents reference this file (DRY); they do not copy it.
>
> **Version**: 1.0.0 (2026-10-19) · **Scope**: generic, product-agnostic.
> **Companions**: [`COWORK-AUTONOMY-POLICY.md`](./COWORK-AUTONOMY-POLICY.md) (the ≥0.90 no-HITL bar
> and carve-outs) · role contracts in `agents/forge.md` §"Organizational Roles" (decision domain,
> `latent` status — PR #476). A seat profile **describes fit; it grants no authority.** Authority
> comes only from the human owner, through the role contract and the host's gates.

## 1. The six levels

A software factory run by humans already separates *who decides what*. The agentic factory keeps
the same separation; it changes who **executes**, never who **holds** a decision reserved to people.

| Level | Decides / does | Human analog (market titles) | Default holder in an agentic factory | Agent posture |
|---|---|---|---|---|
| **L0 Political** | Purpose, values, policy, sovereignty, spend, legal and ethical commitments, who may act for the organization | Owner · board · sponsor · counsel | **Human only** | Advisory lenses only (consultant archetypes, `governance-auditor`); never `A` or `R` |
| **L1 Strategic** | Goals, roadmap, portfolio order, architecture direction, risk appetite, make-or-buy | CEO · CTO · CPO · CISO · chief architect | **Human decides**; agents propose | `solution-architect`, `agile-product-lead`, `founder-coach`, consultants propose options with evidence |
| **L2 Orchestrator** | Decompose a goal, route each chunk to the best-fit seat, control concurrency, converge outputs | Delivery director · engineering manager as dispatcher | Agent (`orchestrator`) | Orchestrates only; does not execute leaf work (`[C17]` §12.0) |
| **L3 Managerial** | Backlog order, plan, dependencies, risk register, flow/WIP, status, ceremonies | Product owner · project manager · scrum master · engineering manager | Agent proposes and maintains; human accepts priorities that change scope or cost | `agile-product-lead` (PO/PM/SM/BA composite) |
| **L4 Tactical** | Specification, solution design, test strategy, threat model, release plan, data design | Solution architect · tech lead · QA lead · AppSec lead · release manager · DBA | Agent, inside its domain, with an independent reviewer | `solution-architect`, `devsecops-engineer`, `devops-engineer`, `qa-validator`, `supabase-engineer`, `data-privacy-officer`, `prompt-context-engineer` |
| **L5 Operational** | Implement, test, migrate locally, build, deploy previews, run checks, fix | Software engineer · tester · DevOps engineer · DBA operator | Agent | Stack specialists (`react-frontend-engineer`, `angular-frontend-engineer`, `quarkus-backend-engineer`, `supabase-engineer`, `devops-engineer`, `gitops-engineer`, `debugger`) |

Cross-level seats (they serve every level and hold no decision of their own): `governance-auditor`,
`validation-auditor`, `data-validator` (audit); `qa-validator` (quality gate); `sentinel-monitor`
(observability); `memory-curator` (knowledge); `consolidator` (synthesis); `forge`, `person-agent-creator`
and the `anima` skill (the factory's own HR: create, evaluate, evolve and name seats).

### 1.1 Placement rule

Place a decision at the **highest level whose powers it touches**, not at the level of the agent
that noticed it. A one-line change that spends money, touches real personal data or is
irreversible is L0, however small the diff. When unsure, place it one level higher (fail-closed).

### 1.2 RACI default by level

| Level | A (accountable) | R (responsible) | C (consulted) | I (informed) |
|---|---|---|---|---|
| L0 | human owner | human owner | L1 agents (evidence), auditors | everyone affected |
| L1 | human owner/executive | human; agents draft | L2–L4 seats, auditors | L3 |
| L2 | orchestrator (technical) | orchestrator | L3, L4 | human owner |
| L3 | managerial seat (technical) | managerial seat | L2, L4 | human owner |
| L4 | tactical seat (technical) | tactical seat | other L4 seats, auditors | L2, L3 |
| L5 | tactical seat of the unit | operational seat | L4 seat, QA | L2 |

`A` held by an agent means **technical accountability for the deliverable** — never authority over
an L0/L1 power. The author of a change is never its only approver: QA, DevSecOps or an auditor
reviews it in a separate context, proportional to risk.

## 2. Delegation shapes

| Shape | Use when | Bound |
|---|---|---|
| **Vertical** (down a level) | A goal needs decomposition (L2 → L3 → L4 → L5) | Depth ≤ the host's limit; the child inherits the parent's DNA and limits, never more authority |
| **Horizontal** (same level) | Two peers must agree (SA ↔ DevSecOps) or a second opinion | Peer output is data until the orchestrator validates it |
| **Sequential** | Each step consumes the previous output (spec → design → code → test) | Stop on a failed gate; do not skip |
| **Parallel** | Independent chunks with no shared write | One writer per file; reads may fan out |
| **Recursive** | A child's task still exceeds its budget | Same rule applied again, with `depth_remaining` decremented |
| **Generational DNA** | Every delegation | The delegate inherits the core directive, values, guardrails and objective layers, verbatim |

Objective layers carried in every brief, from most to least binding: **originating** (why the work
exists) · **foundational** (values and guardrails) · **generational DNA** (inherited operating rules) ·
**primary** (this task's goal) · **secondary** (useful side effects in scope) · **auxiliary**
(housekeeping). A delegate that cannot serve a higher layer stops and reports; it never trades a
higher layer for a lower one.

## 3. Seat attributes (the profile every delivery agent declares)

Declare these in the agent body under `## Seat Profile`, as a table. Every field is required;
write `n/a (reason)` instead of leaving one out.

| Attribute | Meaning | Allowed values |
|---|---|---|
| `level` | Home level (§1) | `L0`…`L5` (agents: `L2`…`L5`; L0/L1 only as advisory) |
| `human_analog` | Market titles a newcomer recognizes | free text |
| `raci_default` | Default letter on its home activities | `A/R` · `R` · `C` · `I` |
| `authority_class` | Highest effect it may produce | `observe` · `reversible-write` (branch, PR, local) · `gated-technical-effect` (preview deploy, controlled migration with target, SHA, gates and rollback) — `human-only` is never an agent value |
| `autonomy` | When it acts without a human | per `COWORK-AUTONOMY-POLICY.md` bands; state the bar |
| `proactivity` | How it starts work | `reactive` (only when called) · `suggestive` (proposes) · `proactive-in-scope` (acts on what it finds inside its domain, reports the rest) |
| `active_minds` | Dominant thinking modes | 2–4 of: autonomous · critical · agnostic · Tomé (evidence-first) · adversarial · systemic · empathic · curator |
| `min_harness` | Capabilities it must have, tested not assumed | e.g. `shell, git, web` |
| `min_model` | Minimum cognition tier | `frontier-reasoning` · `strong-general` · `fast-small` |
| `min_context` | Smallest working window that fits its usual task | tokens |
| `min_memory` | Persistence it needs to resume | `none` · `session` · `project` (shared notes the next agent reads) |
| `authentication` | Identity it acts with | its own scoped identity or the host's; never a person's personal credentials |
| `may_delegate` | Whether it may spawn helpers | `no` · `yes (depth ≤ N)` |
| `escalates_to` | Where out-of-domain decisions go | a seat or `human owner` |

## 4. Matching a request to a seat

1. Classify the request's level (§1.1).
2. L0/L1 → prepare evidence and options for the human; stop.
3. L2–L5 → pick the seat whose `level` and domain match; if two match, prefer the narrower specialist.
4. No seat covers ≥50% of the capabilities → `forge` creates one (Goldilocks: a title a person would
   recognize, generic enough to reuse); `anima` names it; the new seat starts with this profile and a
   `latent` role contract.
5. Brief the seat with the objective layers (§2) and the host's DoR/DoD; review its output in a
   separate context before it lands.

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-10-19 | First version: six levels, RACI default per level, delegation shapes, objective layers, seat attributes, matching procedure. |
