# Eisenhower + Dependency Prioritization Method

> **Purpose**: Standardized method for organizing DevOps tasks across projects.
> **Created**: 2026-03-22 by Antigravity (Google/Gemini-2.5-Pro)
> **Agent**: Any AI agent (agent-agnostic, open-source method)

## Core Rule

> **ALWAYS reorder the N-Tree BEFORE executing.**
> Every session must start by re-evaluating Eisenhower × blockers/blocked.
> Never assume the previous order is still correct.

## Method: Eisenhower × Dependency Resolution

### Step 1: Inventory Sources

Scan ALL relevant locations for tasks, gaps, and pending items:

```yaml
sources:
  - docs/audit/gap-analysis.md          # Gap findings (F-NNN)
  - AGENTS.md → "Known Issues"          # Documented issues
  - vek-devops-backlog/backlog/         # Backlog tasks (TASK-NNN)
  - docs/plan/*.md                      # Migration/implementation plans
  - memory/projects/*.md                # Project context
  - conversation history                # In-flight work
```

### Step 2: Classify (Eisenhower)

```text
🔴 Q1 URGENT+IMPORTANT: Security risks, production blockers, active issues
🟡 Q2 IMPORTANT+NOT URGENT: Architecture, hardening, pipeline improvements
🟠 Q3 URGENT+NOT IMPORTANT: Quick wins, cleanup, hygiene (<30min each)
🔵 Q4 NOT URGENT+NOT IMPORTANT: Strategic/long-term, backlog, research
```

### Step 3: Map Dependencies

```text
For each Q1/Q2 item, identify:
  - blocks: [what it blocks]
  - blocked_by: [what blocks it]
  - critical_path: true/false (on the path to production go-live)
```

### Step 4: Calculate Execution Order

```python
priority = (eisenhower_quadrant * 100) + (blocks_count * 10) - (effort_hours)
# Q1 items first, then by number of items they unblock, then by lowest effort
```

### Step 5: Execute

- Always do Q3 quick wins in batches (all <5min items together)
- Q1 items in dependency order (unblock first)
- Q2 items scheduled between Q1 batches
- Q4 items only when Q1+Q2 are clear

## Pre-Task Requirements (Mandatory)

Every task — regardless of quadrant — MUST include:

1. **Delegate to best resource**: For every task/question/problem, identify the best available resource (agent, sub-agent, role, tool, MCP, skill, persona) and delegate. Never do a job when a better-qualified resource exists
2. **Best practices by default**: Always use industry best practices. Deviations require explicit justification (`@reason`, `@impact`)
3. **Reorder N-Tree**: Re-evaluate Eisenhower × blockers before executing
4. **Analyze `.gitignore`**: Verify new/modified files are properly covered
5. **Check dependency chain**: Understand what the change affects downstream
6. **Verify secret exposure**: No plaintext credentials in committed files or git history
7. **Phase-end self-assessment**: At end of each phase, generate a performance report (errors, gaps, opportunities, feed-back, 360° evaluation) and save to DevOps backlog SSOT

## Governance SSOT

| What | Where |
| ---- | ----- |
| Eisenhower method (open-source) | `multi-agent-os/docs/insights/eisenhower-dependency-prioritization.md` |
| Multi-agent governance | `multi-agent-os/docs/insights/multi-agent-backlog-governance.md` |
| Domain backlog (Vek) | `vek-devops-backlog/backlog/MASTER-PLAN-execution-order.md` |
| Pre-flight checklist | `k8s-eks-prd-002/AGENTS.md → Pre-Flight Checklist` |
| Phase reports | `vek-devops-backlog/reports/PHASE-NNN-*.md` |
