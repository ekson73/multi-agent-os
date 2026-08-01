# ADR-014: Operator-Profile Intake Is Context, Not Authority

- **Status**: Accepted
- **Date**: 2026-08-01
- **Scope**: MAOS `ooda-loop` and its Agent Skills-compatible consumers

## Context

Autonomous delivery work often starts from a message, ticket, prototype, webhook or another
external signal. A business owner may deliberately delegate routine engineering while needing
only business-rule or human-only questions. Without an explicit contract, an agent can either
over-escalate technical choices to a nontechnical owner or, worse, mistake a profile or trigger
for authorization.

## Decision

Extend the existing `ooda-loop` conductor with an optional, portable
`operator-profile` JSON input. The profile declares explanation language, technical delegation,
business-question domains, signal taxonomy, lifecycle bounds and a non-waivable baseline of hard
stops. It is validated before use.

The profile is **context only**. An action is permitted only when the current host identity and
capability, repository/project policy, declared delegation, and action-specific live environment
gate all permit it. Missing evidence means `unknown`, not delegated.

`ooda-loop` applies outer OODA to choose the next evidence-supported stage and bounded inner
PDCA through existing `gap-loop`/`quiesce` drivers. It does not force a linear delivery pipeline,
run as a daemon, consume a webhook directly, or deploy automatically.

Before ordinary HITL, agents use proportionate recon, deterministic verification and independent
council/convergence. HITL is reserved for unresolved business rules/priorities, human-only acts,
or a hard boundary. Immediate containment of a safety issue comes first.

The portable core remains Agent Skills Markdown plus JSON. A runtime adapter must prove its own
capability mapping; names of runtimes in documentation are not evidence of native integration.

## Consequences

- **Positive**: technical delegation is explicit without turning a business owner into an
  architecture approver; agents receive a predictable, vendor-neutral escalation contract.
- **Positive**: Discord, Slack, Jira, Linear, chat and webhooks remain signals until independently
  authorized, reducing indirect prompt-injection and privilege-escalation risk.
- **Positive**: the existing conductor, council and convergence tools are extended rather than
  duplicated.
- **Negative**: consumer repositories must maintain a sanitized profile and supply local runtime
  adapters when their host does not natively load Agent Skills.

## References

- `skills/ooda-loop/SKILL.md`
- `skills/ooda-loop/templates/operator-profile.schema.json`
- `skills/ooda-loop/references/loop-contract.md`
- `skills/ooda-loop/references/runtime-adapters.md`
- [Agent Skills specification](https://agentskills.io/specification)
- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [NIST AI RMF Core](https://airc.nist.gov/airmf-resources/airmf/5-sec-core/)
