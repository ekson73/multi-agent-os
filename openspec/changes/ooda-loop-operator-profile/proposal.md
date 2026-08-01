# Change: Make ooda-loop profile-aware without laundering authority

## Why

The existing `ooda-loop` can recover a goal, derive a measurable Definition of Done and
drive convergence, but it does not have a portable contract for work that arrives from
chat, tickets, webhooks, prototypes or a nontechnical business operator. A monolithic
"run forever" prompt would duplicate existing primitives, invite prompt injection and
blur the line between a trigger, contextual preference and operational authorization.

## What Changes

- Extend the existing `ooda-loop`; do not create a second delivery-loop engine.
- Add a sanitized `operator-profile` contract that can narrow context and explanation
  style but cannot grant authority.
- Separate untrusted trigger data from control-plane flags and normalize replay-safe
  intake metadata before OODA.
- Make outer OODA and inner PDCA budgets, no-progress exits and completion levels
  explicit.
- Route technical uncertainty through proportionate deterministic checks or independent
  convergence before asking a nontechnical operator.
- Preserve immediate hard stops for secrets, personal data, access changes, cost, legal
  effects, external communication and destructive or irreversible effects.
- Publish a concise vendor-neutral prompt projection and an evidence-qualified runtime
  adapter matrix.

## Impact

- **Affected capability**: `ooda-loop` orchestration and its command/Agent Skills surface.
- **Compatibility**: additive behavioral contract; frontmatter is tightened to the Agent
  Skills standard. Runtime behavior remains unverified until a synthetic host dogfood.
- **External effects**: none. This change does not execute the loop, connect a trigger,
  access credentials, deploy, merge or authorize production work.
