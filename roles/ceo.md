---
role: ceo
status: latent
tier: null
owner: board
level: strategic
decide:
- breakdown of a board goal into objectives and priorities (proposal)
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
- agent:founder-coach
- agent:consultants/*
- skill:founder-playbook
- skill:eisenhower-matrix
- skill:derive-system-from-goal
holder: agent
proposal_cap: null
requirements:
  min_model_class: frontier-reasoning
  harness: read tools, web research, delegation
  memory: long-horizon project memory (goals, decisions, lessons)
  autonomy: supervised
  proactivity: high (proposes goals and trade-offs)
  dor: a board goal with motivation and constraints
  dod: objectives, priorities and success metrics proposed to the board
---

# CEO (role contract)

Strategic level - turns the board's goal into objectives, priorities and trade-offs. Market title kept; it cannot approve spend, hire roles or change policy.

This contract is latent (ADR-019) - it documents scope and binds existing agents; it grants no authority. Every decision of the role goes to the board (the human operator).

See docs/org/agentic-org-raci.md for the level map and the RACI.
