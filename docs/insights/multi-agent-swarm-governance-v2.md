# Multi-Agent Swarm Governance Protocol v2.0

> **Purpose**: Enterprise-grade protocol for AI agents working on shared backlogs concurrently.
> **Supersedes**: `multi-agent-backlog-governance.md` v1.0 (simple handshake)
> **Sources**: Swarms.world, ArXiv 2501.06322, SwarmNetwork Truth Protocol, MetaGPT SOPs, Agent OS, Sandeco
> **Created**: 2026-03-22 | **Author**: Antigravity (Google/Gemini-2.5-Pro)

---

## 1. Core Principles

```text
P1: No task without ownership. No task with two owners.
P2: Best resource for each task (delegation-first).
P3: Reputation-based trust (agents earn credibility through results).
P4: Self-organization over rigid hierarchy.
P5: Transparent and auditable (every decision documented).
P6: Fail-safe by default (mistakes are recoverable).
```

## 2. Agent Identity & Registration

Every agent MUST register with:

```yaml
agent:
  name: "Antigravity"                    # Unique identifier
  provider: "Google/Gemini-2.5-Pro"      # Model/vendor
  capabilities: [devops, iac, k8s, python, docs]
  reputation_score: 0.0                  # 0.0-1.0, earned
  tasks_completed: 0
  tasks_failed: 0
  specializations:                       # Domain expertise
    - kubernetes: 0.9
    - python: 0.8
    - java: 0.3
  registered_at: ISO-8601
  last_active: ISO-8601
```

## 3. Swarm Architectures (When to Use Which)

Based on Swarms.world + ArXiv 2501.06322 research:

| Architecture | Pattern | Use When | Our Use Case |
| ------------ | ------- | -------- | ------------ |
| **Sequential** | A → B → C | Pipeline (build→test→deploy) | CI/CD workflows |
| **Concurrent** | A \|\| B \|\| C | Independent tasks | Batch quick-wins |
| **Hierarchical** | Boss → Workers | Complex multi-stage | TASK-005 (plan→implement→verify) |
| **Round-Robin** | A → B → C → A | Review cycles | Code review rotation |
| **Router** | Dispatcher → Best agent | Dynamic delegation | **Our delegation principle** |
| **Council-as-Judge** | N agents vote | Critical decisions | Security reviews |
| **Debate-with-Judge** | 2 debate + 1 judges | Trade-off analysis | Architecture decisions |
| **MoA (Mixture of Agents)** | Multiple → merge | Consensus | Document harmonization |
| **MAKER** | Make→Auto-review→Keep/Edit→Repeat | Quality loop | Code generation |

## 4. Communication Topology

```text
Centralized (Star):     All agents → Hub agent → dispatches
Decentralized (Mesh):   Agents communicate peer-to-peer
Hierarchical (Tree):    Human → Lead Agent → Sub-agents

OUR CHOICE: Hybrid Hierarchical
  Human (Emilson) → Lead Agent (whoever is active)
    ├── Sub-agent 1 (delegated specialist)
    ├── Sub-agent 2 (concurrent work)
    └── MCP tools (Bitbucket, Jira, Context7)
```

## 5. Task Lifecycle (Enhanced)

```text
BACKLOG → TRIAGED → ASSIGNED → IN_PROGRESS → REVIEW → DONE
                                   ↘ BLOCKED (with reason + unblock_condition)
                                   ↘ STALE (>7d no update → auto-reassignable)
                                   ↘ FAILED (with root cause + retry_count)
```

## 6. Handshake Protocol v2 (Enhanced)

```text
 0. IDENTIFY  — Register agent identity + capabilities
 1. UPDATE    — Close current task: status=done, updated=now
 2. REPORT    — Generate phase-end self-assessment
 3. REORDER   — Re-evaluate N-Tree by Eisenhower × blockers
 4. SCAN      — Read next task in ordered list
 5. CHECK     — Validate:
    ├── Is assignee == "unassigned"?    → proceed to MATCH
    ├── Is assignee == me?              → proceed (resuming)
    ├── Is assignee == other agent?     → SKIP, take next
    ├── Is status == "stale"?           → reassign to me, proceed
    ├── Is status == "blocked"?         → check if I can unblock, else SKIP
    └── Is status == "human-assigned"?  → NEVER claim
 6. MATCH     — Am I the BEST resource for this task?
    ├── Check my capabilities vs task requirements
    ├── If better agent exists → flag for that agent, take next
    └── If I'm best match → proceed
 7. LOCK      — Set: assignee=me, locked_by=me, locked_at=now, status=in_progress
 8. EXECUTE   — Do the work (apply pre-task requirements 1-7)
 9. VERIFY    — Validate results (tests, builds, reviews)
10. REPEAT    — Go to step 1
```

## 7. Reputation System (Inspired by SwarmNetwork Truth Protocol)

```yaml
reputation:
  formula: |
    score = (tasks_completed * weight_complete) - (tasks_failed * weight_fail)
    score += (self_assessment_avg * weight_quality)
    score = clamp(score, 0.0, 1.0)
  weights:
    weight_complete: 0.4
    weight_fail: 0.3
    weight_quality: 0.3
  thresholds:
    novice: 0.0-0.3       # Can only take Q3/Q4 tasks
    competent: 0.3-0.6    # Can take Q2 tasks
    expert: 0.6-0.8       # Can take Q1 tasks
    master: 0.8-1.0       # Can take critical/security tasks
  decay: 0.01/week        # Reputation decays without activity
```

## 8. Conflict Resolution (Enhanced)

| Scenario | Resolution |
| -------- | ---------- |
| Two agents lock same task | First `locked_at` wins; loser auto-picks next |
| Agent claims task beyond capability | Reputation check gate (step 6 MATCH) |
| Task stale >7 days | Any agent can reassign (document previous progress) |
| Task blocked | Skip; attempt unblock if capable; else flag for human |
| Agent crashes mid-task | `in_progress` persists; next agent claims after stale threshold |
| Human-assigned task | AI agents MUST NOT claim; skip always |
| Disagreement on approach | Debate-with-Judge pattern (2 agents + human judge) |
| Security-critical task | Council-as-Judge (minimum 2 agents + human) |

## 9. Quality Gates (MAKER Pattern)

Every significant deliverable follows:

```text
MAKE    → Agent produces output
AUTO    → Automated checks (lint, build, test)
KEEP?   → Self-assessment: meets quality bar?
  YES   → Proceed to REVIEW
  NO    → EDIT (revise) → back to AUTO
REVIEW  → Human or peer-agent review
DONE    → Merge/deploy
```

## 10. YAML Frontmatter Standard (Task Files)

```yaml
---
id: TASK-NNN
title: Short description
status: backlog | triaged | assigned | in_progress | review | done | blocked | stale | failed
assignee: agent-name | human-name | unassigned
locked_by: agent-name
locked_at: ISO-8601
priority: Q1 | Q2 | Q3 | Q4
blocked_by: [TASK-NNN]
blocks: [TASK-NNN]
required_capabilities: [k8s, python, security]  # For MATCH step
estimated_effort: "2h" | "4h" | "1d" | "3d"
retry_count: 0
created: ISO-8601
updated: ISO-8601
resolution: "Brief description"  # When done
---
```

## 11. Self-Assessment Template

At end of each phase:

```yaml
assessment:
  agent: "name"
  phase: "phase description"
  date: ISO-8601
  deliverables: [{item, status, commit}]
  score:
    task_completion: N/10
    critical_thinking: N/10
    communication: N/10
    governance: N/10
    speed: N/10
    accuracy: N/10
    overall: N/10
  errors: [{error, impact, root_cause}]
  gaps: [{gap, severity, action}]
  improvements: [{opportunity, priority}]
  reputation_delta: +/-0.XX
```

## 12. Integration with Pre-Task Requirements

```text
0. Handshake Protocol v2 (this document, steps 0-10)
1. Delegate to best resource
2. Best practices by default
3. Reorder N-Tree
4. Analyze .gitignore
5. Check dependency chain
6. Verify secret exposure
7. Phase-end self-assessment
```

## 13. Governance SSOT Map

| Document | Location | Scope |
| -------- | -------- | ----- |
| This protocol | `multi-agent-os/docs/insights/multi-agent-swarm-governance-v2.md` | Open-source |
| Eisenhower method | `multi-agent-os/docs/insights/eisenhower-dependency-prioritization.md` | Open-source |
| **Tools inventory** | `multi-agent-os/docs/insights/agent-tools-resources-inventory.md` | Open-source |
| Previous v1 protocol | `multi-agent-os/docs/insights/multi-agent-backlog-governance.md` | Superseded |
| Domain backlog | `vek-devops-backlog/backlog/MASTER-PLAN-execution-order.md` | Vek-specific |
| Cross-project inventory | `vek-devops-backlog/inventory/cross-project-inventory.md` | Vek-specific |
| Pre-flight checklist | `k8s-eks-prd-002/AGENTS.md → Pre-Flight Checklist` | Repo-specific |
| Phase reports | `vek-devops-backlog/reports/PHASE-NNN-*.md` | Vek-specific |

## 14. Sources & References

| Source | Key Insight | URL |
| ------ | ----------- | --- |
| Swarms.world | 22 architectural patterns | docs.swarms.world |
| ArXiv 2501.06322 | Collaboration types, communication topologies | arxiv.org |
| SwarmNetwork | Truth Protocol (claims, evidence, reputation) | swarmnetwork.ai |
| Agent OS | Coding standards for AI-powered dev | buildermethods.com |
| MetaGPT | SOPs encoded in prompts, assembly-line model | Referenced in ArXiv |
| Sandeco | Multiagentes em debate, SandeClaw, prompt evolution | github.com/sandeco |
