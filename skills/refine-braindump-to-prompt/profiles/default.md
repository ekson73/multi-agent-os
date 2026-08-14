# Profile: `default`

Neutral architecture. Used when the braindump names no target prompt-architecture.

## DRAFT shape

The rendered prompt carries these sections, in this order. Omit a section only when the braindump
genuinely has nothing for it — never pad.

```text
GOAL          one sentence, machine-checkable where possible
CONTEXT       state-of-world the executing agent cannot infer
SCOPE         in-scope AND out-of-scope, both explicit
CONSTRAINTS   hard limits (tools, budget, permissions, guardrails)
ACCEPTANCE    binary-checkable criteria (the DoD, from decompose-abstract-to-measurable)
STOP          the terminating condition + what to do on exhaustion
DELIVERABLES  concrete artifacts + where they land
ESCALATION    what forces a human decision
```

## Lens roster (REFINE)

Default `--lenses=3`, drawn in rotation so no round repeats a lens:

| Lens | Asks |
|---|---|
| **completeness** | what would a fresh amnesic agent still have to guess? |
| **executability** | can every instruction be acted on with the tools named? |
| **falsifiability** | is ACCEPTANCE checkable, or is it a wish? |
| **scope-drift** | does anything here invite work the operator did not ask for? |
| **failure-path** | what happens when a step fails — is it written down? |

## Loop budget

Inherits the skill defaults: `--min-revisions=3`, `--clean-rounds=3`, `--max-rounds=12`.

The Verifiability Gate normally evaluates **false** for this profile (a generic prompt rarely has a
machine-verifiable external bar), so the economic stop applies: convergence is expected within
`n* ≤ 3-4` productive rounds beyond the floor.

## When this profile is wrong

If the work is buildable, observable, reversible, and has a nameable external quality bar →
use `--architecture=gauntlet-loop` instead; this profile will under-specify the critic.
