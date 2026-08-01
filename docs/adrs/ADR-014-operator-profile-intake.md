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

The profile is **context only**. An action is permitted only when an independently evidenced user
grant, repository/project policy, current host identity/capability and the action-specific live
environment gate all permit it. The profile and trigger are not terms in that intersection; they
may narrow scope or tailor explanations, but cannot grant execution authority. Missing evidence
means `unknown`, not delegated.

External triggers are normalized into a separate replay-safe envelope. Connector authentication
proves origin only. Trigger content remains data-plane input and cannot set a profile path, goal,
driver, budget, merge/deploy mode, shell text or tool argument. The adapter must verify freshness,
project/tenant binding, replay state, sensitivity and injection risk before goal recovery.

`ooda-loop` applies outer OODA to choose the next evidence-supported stage and bounded inner
PDCA through existing `gap-loop`/`quiesce` drivers. A global budget bounds both layers, including
attempts, tools, spawns, external calls, wall time, cancellation and lease validity. Two outer
cycles without measurable progress park a durable checkpoint. `STAGE_DONE` cannot be promoted to
`DELIVERY_DONE` while an applicable gap, deferred/open specification, failed check or promotion
gate remains. The skill does not force a linear delivery pipeline, run as a daemon, consume a
webhook directly, or deploy automatically.

Before ordinary HITL, agents use proportionate recon, deterministic verification and independent
council/convergence. HITL is reserved for unresolved business rules/priorities, human-only acts,
or a hard boundary. Immediate containment of a safety issue comes first.

The portable core remains Agent Skills Markdown plus JSON. A runtime adapter must prove its own
ACT capability mapping; native Skill discovery is not evidence that worktree, approval, council,
verification or promotion semantics behave end to end.

## Alternatives and meta-critique

Eight variants were compared: extend `ooda-loop`; create a separate intake/PDP service; add an
`auto-pilot` preset; ship a multi-runtime plugin bundle; create a new delivery-loop skill; install
an always-loaded rule; implement a hook/daemon runner; or retain one monolithic prompt. Extending
`ooda-loop` won because it reuses the existing goal/DoD/driver spine and adds only the missing typed
boundary. A separate PDP remains the strongest future separation if multiple live connectors prove
the need. The other variants either solve distribution instead of semantics, duplicate conductors,
increase ambient prompt cost, or combine ingestion with execution and broaden blast radius.

The chosen design is intentionally incomplete as automation: it defines a portable contract and
validators, not a background service. Static schema tests can disprove malformed inputs but cannot
prove agent obedience, connector security or runtime ACT behavior. Those claims remain unverified
until sanitized host dogfood is explicitly authorized and observed.

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
- `skills/ooda-loop/templates/trigger-envelope.schema.json`
- `skills/ooda-loop/bin/validate_intake_contract.py`
- `skills/ooda-loop/references/loop-contract.md`
- `skills/ooda-loop/references/runtime-adapters.md`
- [Agent Skills specification](https://agentskills.io/specification)
- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [NIST AI RMF Core](https://airc.nist.gov/airmf-resources/airmf/5-sec-core/)
