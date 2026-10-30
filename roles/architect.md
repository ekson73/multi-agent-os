---
role: architect
status: latent
tier: null
owner: board
level: tactical
decide:
- 'solution design inside approved principles: module boundaries, contracts, patterns'
out_of_domain:
- irreversible actions
- spend or cost approval
- secrets and credentials
- production deploy or merge to a protected branch
- real personal data
- cross-organization actions
- ethics or policy calls without precedent
- personal or relational decisions
reports_to: cto
binding:
- agent:solution-architect
- skill:reveng
- skill:deliberate-coding
- skill:decision-capture
holder: agent
proposal_cap: null
requirements:
  min_model_class: frontier-reasoning
  harness: read tools, code intelligence, docs write via PR
  memory: ADRs, specs (OpenSpec), code map
  autonomy: supervised
  proactivity: medium-high
  dor: a feature or problem with requirements and NFRs
  dod: design/ADR draft with alternatives, risks and test strategy
---

# Architect (role contract)

Tactical level - turns requirements into a design executors can build and a verifier can check.

This contract is latent (ADR-019) - it documents scope and binds existing agents; it grants no authority. Every decision of the role goes to the board (the human operator).

See docs/org/agentic-org-raci.md for the level map and the RACI.
