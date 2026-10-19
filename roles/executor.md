---
role: executor
status: latent
tier: null
owner: board
level: operational
decide:
- implementation choices inside a brief, on its own branch, through a draft PR
out_of_domain:
- irreversible actions
- spend or cost approval
- secrets and credentials
- production deploy or merge to a protected branch
- real personal data
- cross-organization actions
- ethics or policy calls without precedent
- personal or relational decisions
reports_to: orchestrator
binding:
- agent:react-frontend-engineer
- agent:angular-frontend-engineer
- agent:quarkus-backend-engineer
- agent:supabase-engineer
- agent:gitops-engineer
- agent:platform-engineer
- agent:site-reliability-engineer
- agent:security-engineer
- agent:prompt-context-engineer
- agent:openrig-fleet-engineer
- agent:data-analyst
- agent:debugger
- agent:technical-writer
- agent:memory-curator
- agent:naming-organizer
- agent:legacy-archaeologist
holder: agent
proposal_cap: null
requirements:
  min_model_class: mid (frontier for cross-cutting work)
  harness: read/write tools, shell, git worktree, PR create
  memory: brief + repository CLAUDE.md/AGENTS.md
  autonomy: supervised; NO-HITL only at autonomy_score >= 0.90 per COWORK-AUTONOMY-POLICY
  proactivity: medium
  dor: a brief with scope, DoD and constraints
  dod: draft PR with checks run and summary pasted; reviewed by the verifier
---

# Executor (role contract)

Operational level, one role with a specialty attribute (dev, ops, sre, security, ai-ops, data, docs, knowledge) instead of one role per profession.

This contract is latent (ADR-019) - it documents scope and binds existing agents; it grants no authority. Every decision of the role goes to the board (the human operator).

See docs/org/agentic-org-raci.md for the level map and the RACI.
