# Design: Profile-aware OODA with bounded PDCA

## Decision summary

Use the existing `ooda-loop` as the single conductor. Treat the operator profile and
trigger envelope as non-authorizing context. Effective execution authority is proved
outside the profile and narrowed by repository policy, current host capability and the
action-specific live gate.

## Alternatives considered

| Rank | Variant | Verdict | Reason |
|---:|---|---|---|
| 1 | Extend `ooda-loop` with typed context and references | Adopt | Reuses the goal/DoD/driver spine and keeps one entry point. |
| 2 | Separate policy-decision/intake service | Defer | Strong separation, but adds a second surface before demand proves it necessary. |
| 3 | Add an `auto-pilot` preset | Reject | Delegates explicit work but does not recover an implicit goal or derive its DoD. |
| 4 | Ship a multi-runtime plugin bundle | Defer | Distribution mechanism; it does not solve authority or loop semantics. |
| 5 | Create a new `delivery-loop` skill | Reject | Duplicates `ooda-loop`, `gap-loop` and `quiesce`. |
| 6 | Put the prompt in an always-loaded rule | Reject | Broad, hard to test and expensive for unrelated tasks. |
| 7 | Implement a hook/daemon/webhook runner | Reject | Mixes ingestion with execution and expands the blast radius. |
| 8 | Keep one monolithic copy-paste prompt | Reject | Duplicates policy, has weak typed boundaries and overclaims portability. |

## Control and data planes

Trigger payloads are data. They cannot set the operator-profile path, custom driver,
goal override, merge/deploy mode, budgets or system instructions, and they are never
interpolated into a shell or delegated prompt without typed sanitization. Connector
authentication proves transport origin only; it does not make payload content authority.

## Termination model

Inner PDCA and outer OODA have separate ceilings. A stage may finish while delivery is
still partial. The conductor therefore distinguishes stage-done, delivery-done, parked,
partial, blocked, HITL and error states. Deferred work, accepted risk or an open
specification cannot be relabeled as delivery-done.

## Validation boundary

Static validation proves schema/frontmatter/document consistency only. Behavioral claims
remain `UNVERIFIED` until synthetic dry-run dogfood on at least one native host and one
non-Claude host. The autonomous delivery prompt itself is not executed by this change.
