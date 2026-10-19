---
role: product-lead
status: latent
tier: null
owner: board
level: managerial
decide:
- backlog ordering, acceptance criteria and sprint scope inside the approved roadmap
out_of_domain:
- irreversible actions
- spend or cost approval
- secrets and credentials
- production deploy or merge to a protected branch
- real personal data
- cross-organization actions
- ethics or policy calls without precedent
- personal or relational decisions
reports_to: ceo
binding:
- agent:agile-product-lead
- skill:sprint-carryover
- skill:roadmap-tree-projector
- skill:eisenhower-matrix
- skill:decompose-abstract-to-measurable
holder: agent
proposal_cap: null
requirements:
  min_model_class: mid-or-frontier
  harness: tracker read/write via proposal, docs
  memory: backlog + roadmap + decisions
  autonomy: supervised
  proactivity: medium-high
  dor: an objective or ticket with business context
  dod: ticket with DoR/DoD, acceptance criteria and priority (GUT/Eisenhower)
---

# Product Lead (role contract)

Managerial level PO/PM/SM/BA composite - owns the what and the order, not the how.

This contract is latent (ADR-019) - it documents scope and binds existing agents; it grants no authority. Every decision of the role goes to the board (the human operator).

See docs/org/agentic-org-raci.md for the level map and the RACI.
