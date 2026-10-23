---
role: verifier
status: latent
tier: null
owner: board
level: tactical
decide:
- accept or reject evidence that a change meets its DoD (independent review)
out_of_domain:
- irreversible actions
- spend or cost approval
- secrets and credentials
- production deploy or merge to a protected branch
- real personal data
- cross-organization actions
- ethics or policy calls without precedent
- personal or relational decisions
reports_to: board
binding:
- agent:qa-validator
- agent:code-reviewer
- agent:validation-auditor
- agent:data-validator
- agent:persona-pipeline
- skill:red-team
- skill:convergence-engine
holder: agent
proposal_cap: null
requirements:
  min_model_class: equal-or-stronger-than-the-generator
  harness: read tools, test runners, scanners
  memory: the diff, the DoD and deterministic oracles only (fresh context)
  autonomy: consultative (verdict only)
  proactivity: high
  dor: a diff or artifact plus its DoD
  dod: verdict with evidence; findings ranked by severity
---

# Verifier (role contract)

Independent verification. Reports to the board, never to the orchestrator whose output it checks; a separate instance plus deterministic oracles.

This contract is latent (ADR-019) - it documents scope and binds existing agents; it grants no authority. Every decision of the role goes to the board (the human operator).

See docs/org/agentic-org-raci.md for the level map and the RACI.
