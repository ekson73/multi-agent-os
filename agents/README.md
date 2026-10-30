# Multi-Agent OS Agents

## Overview

Agent definitions for the multi-agent-os plugin. These define specialized personas that can be spawned by the orchestrator.

## Available Agents

| Agent | File | Description |
|-------|------|-------------|
| orchestrator | `orchestrator.md` | Master coordinator |
| sentinel-monitor | `sentinel-monitor.md` | Anomaly detection |
| qa-validator | `qa-validator.md` | Quality assurance |
| consolidator | `consolidator.md` | Output synthesis |
| legacy-archaeologist | `legacy-archaeologist.md` | Legacy codebase reverse-engineering |
| memory-curator | `memory-curator.md` | Knowledge/memory hygiene and curation |
| wacli-delegate | `wacli-delegate.md` | Context-isolated delegate for any capability-detected wacli operation |
| founder-coach | `founder-coach.md` | AI-native startup lifecycle coach (stage diagnosis + exit gates) |
| angular-frontend-engineer | `angular-frontend-engineer.md` | Angular SPA frontend (signals, RxJS, Material/Tailwind) |
| react-frontend-engineer | `react-frontend-engineer.md` | React frontend (hooks, Vite/Next, PWA, TanStack Query) |
| quarkus-backend-engineer | `quarkus-backend-engineer.md` | Java/Quarkus reactive backend (Panache, Flyway, JWT, native) |
| supabase-engineer | `supabase-engineer.md` | Supabase backend (RLS, Auth, Storage, Realtime, Edge Fns) |
| prompt-context-engineer | `prompt-context-engineer.md` | AI-craft layer: prompt + context + harness engineering |
| agile-product-lead | `agile-product-lead.md` | Product/delivery lead (PO/PM/SM/BA composite) |
| data-privacy-officer | `data-privacy-officer.md` | DPO/privacy engineer (GDPR/LGPD/CCPA, DPIA, residency) |
| openrig-fleet-engineer | `openrig-fleet-engineer.md` | OpenRig fleet engineer: operate, observe, diagnose and heal rigs; crews on target repositories are a STOP until #453 (loads `openrig-concierge`) |
| self-heal-relay-engineer | `self-heal-relay-engineer.md` | Polyglot systems engineer + SRE + security reviewer: instruments/ports/audits scripts into the self-heal-relay model |
| solution-architect | `solution-architect.md` | Solution design: boundaries, contracts, NFRs, ADRs, topology, expand/contract, rollback design (L4; proposes L1) |
| devsecops-engineer | `devsecops-engineer.md` | DevSecOps/AppSec: threat model, secrets hygiene, supply chain, IAM, authz/RLS review, negative tests, containment (L4) |
| devops-engineer | `devops-engineer.md` | Hosted CI/CD + PaaS deploys (`specialty`), reproducible builds, previews, release records, rollback (L5; L4 release plans) |
| person-agent-creator | `person-agent-creator.md` | Creates/elevates person-agents (sourced dossier, 33 person-questions, lint gate); first three: `consultants/elon-musk`, `consultants/sam-altman`, `consultants/amodei-siblings` (v2.0.0) |

## Agent Categories

Organizational levels (L0–L5), RACI defaults and the seat attributes every delivery agent declares: see [`SEAT-PROFILE.md`](./SEAT-PROFILE.md).

### Coordination
- `orchestrator` — Root agent, manages delegation

### Observability
- `sentinel-monitor` — Background monitoring

### Quality
- `qa-validator` — Validation before completion

### Synthesis
- `consolidator` — Merge parallel outputs

### Archaeology
- `legacy-archaeologist` — Reverse-engineer legacy codebases (Delphi, COBOL, VB6, etc.)

### Knowledge Management
- `memory-curator` — Audit and maintain persistent memory/knowledge quality

### Messaging Operations
- `wacli-delegate` — applies the preloaded concierge knowledge to bounded wacli operations

### Startup Coaching

- `founder-coach` — AI-native startup lifecycle coach; pairs with the `founder-*` skills

### Cowork Team (cross-stack delivery specialists)

Generic, product-agnostic delivery specialists materializing the standard software cowork-team
roles. Compose with the existing registry (most roles already covered — these fill the genuine
per-stack/role gaps; see "Role Coverage Map" below).

**Autonomy posture** (all 10): per [`COWORK-AUTONOMY-POLICY.md`](./COWORK-AUTONOMY-POLICY.md) —
co-work as peers and **substitute over the human with NO-HITL when `autonomy_score ≥ 0.90`** in
their own domain (a stricter bar than the default HIGH ≥0.85). ⛔ Carve-outs HOLD even at ≥0.90
(HUMAN_DOMAIN · merge→main/prod = HITL human-owner · ABSOLUTE guardrails); council-before-HITL first. Seats still
`latent` (`solution-architect`, `devsecops-engineer`, `devops-engineer` until promoted) hold no
NO-HITL grant: every domain decision goes to the human owner.

- `angular-frontend-engineer` — Angular SPA implementation/review
- `react-frontend-engineer` — React/PWA implementation/review
- `quarkus-backend-engineer` — Java/Quarkus reactive backend implementation/review
- `supabase-engineer` — Supabase platform (RLS/Auth/Storage/Realtime/Edge) — generic
- `prompt-context-engineer` — prompt + context + harness AI-craft layer (composite)
- `agile-product-lead` — PO/PM/SM/BA product & delivery leadership (composite)
- `data-privacy-officer` — DPO/privacy/DPIA across GDPR/LGPD/CCPA (generic)
- `solution-architect` — solution design, contracts, NFRs, ADRs (generic; proposes, never decides, L1 direction)
- `devsecops-engineer` — threat modeling, supply chain, IAM, authz review (generic; privacy stays with DPO)
- `devops-engineer` — hosted CI/CD + PaaS (`specialty`); Kubernetes/GitOps stays with `gitops-engineer`

#### Role Coverage Map (reuse-first — most cowork roles already exist)

**2026-10-19 reclassification** — Solution Architect, DevSecOps and hosted DevOps moved from `EXISTS`
to `GAP→NEW`: their earlier providers are external plugins that ship outside this repo, so a host
without them had no agent for the role. The external providers stay listed as optional, so routing
that used them keeps working.

**Legend** — the `Coverage` axis is **reuse-vs-forge**, *not* present-vs-absent:
`EXISTS` = a **pre-existing** agent already covered the role (reused as-is) ·
`GAP→NEW` = no pre-existing agent covered it → **a new agent was forged and exists today**
(named in `Provider`; also listed under "Available Agents" above) ·
`EXTEND-candidate` = **not built** — a future extend (the only not-yet-exists label).

| Cowork role | Coverage | Provider |
|---|---|---|
| DevOps (AWS/IaC/Terraform) | EXISTS | `cloud-infrastructure:cloud-architect` · `terraform-specialist` |
| DevOps (Fly/Render/Railway/CI-CD) | **GAP→NEW** | `devops-engineer` (hosted CI/CD + PaaS `specialty`) · optional: `cloud-infrastructure:deployment-engineer` · Kubernetes/GitOps → `maos:gitops-engineer` |
| Infra Engineer (K8s/Network) | EXISTS | `cloud-infrastructure:kubernetes-architect` · `network-engineer` |
| DevSecOps / Security | **GAP→NEW** | `devsecops-engineer` · optional: `architecture:security-reviewer` · `code-modernization:security-auditor` · `maos:governance-auditor` (audit) |
| DBA (RDS/Aurora/Postgres) | EXTEND-candidate | community gap — covered today by `supabase-engineer` (Postgres) + `cloud-infrastructure:cloud-architect` for RDS/Aurora ops; a dedicated generic `postgres-dba` is a future extend (corp DBA binding lives in the corporate layer, intentionally out of this community map) |
| Frontend — Angular | **GAP→NEW** | `angular-frontend-engineer` |
| Frontend — React/PWA | **GAP→NEW** | `react-frontend-engineer` |
| Backend — Java/Quarkus | **GAP→NEW** | `quarkus-backend-engineer` |
| Backend — Supabase | **GAP→NEW** (generic) | `supabase-engineer` |
| AI / Prompt / Context / Harness Eng | **GAP→NEW** | `prompt-context-engineer` |
| PO / PM / SM / BA | **GAP→NEW** (composite) | `agile-product-lead` |
| DPO / Privacy | **GAP→NEW** | `data-privacy-officer` |
| QA / Tester | EXISTS | `architecture:qa-engineer` · `test-generator` · `maos:qa-validator` |
| Solution Architect | **GAP→NEW** | `solution-architect` · optional: `architecture:architect` · `system-designer` |
| CEO / Founder | EXISTS (persona-lens — no standalone agent) | `maos:founder-coach` (lifecycle diagnosis + exit gates) + C-suite consultant archetypes: `maos:consultants:steve-jobs` · `maos:consultants:sam-altman` · `maos:consultants:bill-gates` · `maos:consultants:sundar-pichai` · `maos:consultants:mark-zuckerberg` |
| Chairman / Board | EXISTS (persona-lens — no standalone agent) | `maos:governance-auditor` (board/governance oversight) + chairman-class consultant archetypes: `maos:consultants:eric-jing` (Ant Group chairman) · `maos:consultants:bill-gates` |
| Auditor | EXISTS | `maos:governance-auditor` · `validation-auditor` |
| Agent-Orchestrator / Task-Orchestrator | EXISTS | `maos:orchestrator` · `taskmaster:task-orchestrator` |
| Git workflow (add/branch/pr/merge…) | EXISTS | `maos:gitops-engineer` (K8s) · `maos:devops-engineer` (hosted CI/CD, PaaS) + `deployment-engineer` (verb-set covered) |

## Agent Naming Convention

### Orchestrator
```
Claude-Orch-Prime-{YYYYMMDD}-{4-hex}
```

### Sub-Agents
```
Claude-{Role}-{prime-hex}-{sequence}
```

### Parallel Agents
```
Claude-{Role}-{prime-hex}-{sequence}{a-z}
```

## Agent Structure

Each agent file uses frontmatter:

```markdown
---
name: agent-name
description: Brief description
---

# Agent Name

## Identity
[Naming format]

## Purpose
[What the agent does]

## When Invoked
[Trigger conditions]

## Capabilities
[What it can do]

## Output Format
[Expected output structure]
```

## Spawning Agents

Agents are spawned via the Task tool:

```
Task(subagent_type="general-purpose", task="...")
```

Note: The frontmatter `name` is a conceptual identifier. Use actual Task tool types (general-purpose, code-reviewer, etc.) for spawning.

## Agent Hierarchy

```
Orchestrator (root)
├── Sentinel Monitor (background)
├── Sub-Agent 1
│   └── Sub-Sub-Agent 1.1 (max depth 2 — `skills/agentic-delegation` §8)
├── Sub-Agent 2
└── Consolidator (synthesis)
```

---

*Part of multi-agent-os plugin v1.0.0*
