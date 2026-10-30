---
role: governance-officer
status: latent
tier: null
owner: board
level: political
decide:
- policy-compliance findings on governance text, naming and standards (recommendation only)
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
- agent:governance-auditor
- agent:validation-auditor
- skill:red-team
- skill:council-gate
- skill:rule-quality-tests
holder: agent
proposal_cap: null
requirements:
  min_model_class: frontier-reasoning
  harness: read-only tools, web search
  memory: project memory + governance corpus read access
  autonomy: consultative
  proactivity: high (audits on every governance change)
  dor: a governance artifact or policy change exists with its diff
  dod: findings with evidence pointers; HUMAN_DOMAIN items routed to board
---

# Governance Officer (role contract)

Political-level guardian of policy, standards and the Two-Worlds boundary. It audits and recommends; the board decides. As a verifier it reports to the board, never to the orchestrator.

This contract is latent (ADR-019) - it documents scope and binds existing agents; it grants no authority. Every decision of the role goes to the board (the human operator).

See docs/org/agentic-org-raci.md for the level map and the RACI.
