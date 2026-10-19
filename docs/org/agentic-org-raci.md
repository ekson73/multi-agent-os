---
id: agentic-org-raci
version: 0.1.0
date: 2026-10-19
status: draft
related: [agents/forge.md, roles/, skills/anima/kb/org-roles.md, docs/adrs/ADR-019-role-activation-gate-deferred.md, agents/COWORK-AUTONOMY-POLICY.md]
---

# Agentic organization: levels, roles and RACI (AI-SDLC software factory)

Which role in an AI-driven software factory has the competence and the authority for each kind of decision and
task, modelled on a human software company. Built with the method of `agents/forge.md` §"Organizational Roles"
(reuse first, a role is a contract bound to existing agents, a new agent only when coverage is under 50%) and
named with `skills/anima` (`kb/org-roles.md`: market-recognizable role names, specialty as an attribute).

> **Authority today.** Every role contract in `roles/` is `latent` (ADR-019). The RACI below is the **target
> design**: it says who is competent and who would be accountable. Until an activation gate exists, every
> decision a role would own still goes to the board (the human operator). Agents prepare, execute and verify;
> the board decides.

## 1. Levels

| Level | Question it answers | Roles (contract in `roles/`) | Holder today |
|---|---|---|---|
| Political | Which values, policies and boundaries apply? Who may spend, merge, deploy? | `board` (human, no contract) · `governance-officer` | human decides; agents audit |
| Strategic | Which goals, priorities and technology direction? | `ceo` · `cto` | agents propose |
| Orchestrator | How is the work split, delegated and supervised? | `orchestrator` · `chief-of-staff` | agents, inside an approved brief |
| Managerial | What is built in which order, and is it ready to release? | `product-lead` · `release-manager` | agents propose |
| Tactical | How is it designed, and is the result correct? | `architect` · `verifier` | agents design and verify |
| Operational | Build, run, secure, document | `executor` + `specialty` | agents execute through draft PRs |

Delegation runs down the levels (vertical), across peers of one level (horizontal), in sequence or in
parallel as the task DAG allows, and recursively up to the platform's depth limit. Every delegate inherits the
generational DNA (freedom with responsibility, holistic predictability, agnostic self-healing), the
originating goal and its own secondary goals, plus DoR/DoD, stop conditions and a feedback channel
(`skills/agentic-delegation`, `skills/delegate-governance`).

## 2. Roles and the agents bound to them

| Role | Level | Bound agents / skills (reuse) | Coverage | Verdict |
|---|---|---|---|---|
| governance-officer | political | governance-auditor, validation-auditor, red-team, council-gate, rule-quality-tests | ≥50% | contract + binding |
| ceo | strategic | founder-coach, consultants/*, founder-playbook, eisenhower-matrix, derive-system-from-goal | ≥50% | contract + binding |
| cto | strategic | **solution-architect (new)**, consultants/jeff-dean, consultants/demis-hassabis, research-dossier, agentic-tool-intake | ≥50% with the new architect | contract + binding |
| orchestrator | orchestrator | orchestrator, auto-pilot, agentic-delegation, delegate-governance, atomize-and-route, agent-select, ooda-loop | ≥50% | contract + binding |
| chief-of-staff | orchestrator | chief-of-staff, work-compass, pulse, morning-briefing, work-drain | ≥50% | contract + binding |
| product-lead | managerial | agile-product-lead, sprint-carryover, roadmap-tree-projector, eisenhower-matrix | ≥50% | contract + binding |
| release-manager | managerial | gitops-engineer, hierarchical-merge, worktree-policy, signoff, postflight | ≥50% | contract + binding |
| architect | tactical | **solution-architect (new)**, reveng, deliberate-coding, decision-capture | <50% before | new agent + contract |
| verifier | tactical | qa-validator, code-reviewer, validation-auditor, data-validator, persona-pipeline, red-team, convergence-engine | ≥50% | contract + binding |
| executor | operational | stack engineers (react, angular, quarkus, supabase), gitops-engineer, prompt-context-engineer, openrig-fleet-engineer, data-analyst, debugger, memory-curator, naming-organizer, legacy-archaeologist, **platform-engineer, site-reliability-engineer, security-engineer, technical-writer (new)** | specialties below | contract + binding |

Executor specialties (attribute, not separate roles): `dev` (stack engineers, debugger) · `ops`
(platform-engineer, gitops-engineer) · `sre` (site-reliability-engineer) · `security` (security-engineer, with
data-privacy-officer for personal data) · `ai-ops` (prompt-context-engineer, openrig-fleet-engineer,
sentinel-monitor, slm-routing, agentic-tool-evaluator) · `data` (data-analyst) · `docs` (technical-writer) ·
`knowledge` (memory-curator, naming-organizer).

### Gaps found and filled (new agents, all draft, `version: 0.1.0`)

| New agent | Why existing coverage was under 50% |
|---|---|
| `security-engineer` | AppSec/SecOps had only governance-auditor (standards) and red-team (adversarial); no agent threat-models changes, scans secrets/supply chain or triages security findings. The registry pointed to plugins that are not part of MAOS. |
| `site-reliability-engineer` | sentinel-monitor watches agent orchestration, not running services; no SLO, alerting, incident or postmortem owner. |
| `platform-engineer` | gitops-engineer covers Kubernetes/Flux only; CI/CD design, IaC (Terraform/CloudFormation) and FinOps had no MAOS agent. |
| `solution-architect` | Design/ADR work pointed to an external plugin; MAOS had skills (reveng, decision-capture) but no design owner. |
| `technical-writer` | The default delegation chain ends in "Doc", and no agent owned docs, runbooks or release notes. |

Not created, on purpose: a `postgres-dba` (still the EXTEND-candidate of `agents/README.md`; host-specific DBA
agents can bind it), an `ai-ops-engineer` (the ai-ops specialty is covered ≥50% by existing agents and skills),
and C-suite agents beyond contracts (the consultants are persona lenses, the contract carries the role).

## 3. RACI by decision and task type (target design)

R = responsible (does it) · A = accountable (would own the decision; today always the board, see the note at the
top) · C = consulted · I = informed. Columns: BRD board (human) · GOV governance-officer · CEO · CTO · ORC
orchestrator · COS chief-of-staff · PRD product-lead · REL release-manager · ARC architect · VER verifier ·
EXE executor (specialty in brackets).

| Decision / task | BRD | GOV | CEO | CTO | ORC | COS | PRD | REL | ARC | VER | EXE |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Values, policy, world boundaries | A/R | C | C | I | I | I | I | I | I | I | I |
| Spend, vendor contracts, hiring a new role | A/R | C | C (propose) | C | I | I | I | I | I | I | I |
| Goals and strategic priorities | A | I | R | C | I | C | C | I | I | I | I |
| Technology direction, build vs buy, ADR | A | C | C | R | I | I | I | I | C | C | I |
| Roadmap and backlog order | A | I | C | C | I | C | R | I | I | I | I |
| Task DAG, chunking, delegation | I | I | I | I | A/R | C | C | I | C | I | I |
| Solution design | I | I | I | A | I | I | C | I | R | C | C |
| Implementation (draft PR) | I | I | I | I | A | I | C | I | C | I | R (dev) |
| Independent review and verdict | I | C | I | I | I | I | I | C | C | A/R | C |
| Security review, secrets and supply chain | A (rotation, disclosure) | C | I | C | I | I | I | I | C | C | R (security) |
| Personal-data handling (privacy, DPIA) | A | C | I | I | I | I | C | I | C | C | R (data-privacy-officer) |
| Merge into a protected or deploying branch | A/R | I | I | I | I | I | I | C (readiness) | I | C | I |
| Deploy, migration apply, IaC apply | A/R | I | I | C | I | I | I | C | I | C | C (ops prepares steps) |
| Production incident triage | A (any prod action) | I | I | C | C | I | I | I | C | I | R (sre) |
| Docs, runbooks, release notes | I | I | I | I | A | I | C | C | C | C | R (docs) |
| Memory, lessons, knowledge base | I | C | I | I | A | C | I | I | I | I | R (knowledge) |
| Naming an artifact | I | I | I | I | I | I | I | I | I | I | R/A (Anima, standing naming authority) |
| Creating an agent or role contract | A | C | I | C | C | I | I | I | I | C | R (Forge) |

## 4. Agentic requirements per role

Each contract in `roles/` carries `requirements`: minimum model class (vendor-neutral: `frontier-reasoning`,
`mid-or-frontier`, `mid`, or `equal-or-stronger-than-the-generator` for verifiers), harness (tools it needs),
memory (what it must load), autonomy, proactivity, DoR and DoD. Authentication and authenticity: an agent
holding a human-sounding title is disclosed as an AI (`holder: agent`); credentials are never part of a role.
Autonomy for executors follows `agents/COWORK-AUTONOMY-POLICY.md` (NO-HITL only at `autonomy_score ≥ 0.90`,
carve-outs always hold).

## 5. How to use it

1. Classify the decision or task with the RACI row above.
2. Delegate to an agent bound to the R role (`skills/agent-select` scores candidates when several fit).
3. Route the A decision to the board until ADR-019's gate exists; put the agents' evidence next to it.
4. A missing capability goes to the Forge: role contract first, new agent only under 50% coverage, named by Anima.
