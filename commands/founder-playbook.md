---
name: founder-playbook
description: Diagnose your AI-native startup's lifecycle stage (Idea/MVP/Launch/Scale) and route to the matching stage discipline, with exit-gate checks and the vendor-neutral product matrix.
---

# /founder-playbook Command

Thin wrapper that invokes `skills/founder-playbook/SKILL.md` (the router). The skill
holds all logic — stage diagnosis, exit gates, failure modes, and routing to the four
`founder-stage-*` skills; this file is the command surface only.

`founder-playbook` is a function-specific command name (not a vendor-reserved word per
`.claude-plugin/plugin.json` `vendor_reserved_audit`); under namespace-aware runtimes
it surfaces as `/maos:founder-playbook`.

## Usage

```
/founder-playbook ["<where I am / what I'm deciding>"]
```

With no argument, it runs the stage-diagnosis flow interactively. With a short context
string, it diagnoses the stage directly and routes you to the right stage skill.

## What it does

1. Runs the **stage-diagnosis flow** (Idea → MVP → Launch → Scale).
2. Reports the detected stage + the **exit gate** for it (pass/fail).
3. Names the **signature failure mode** to watch and routes you to the matching
   `founder-stage-*` skill (with its exercise prompts / emittable templates).

## Related

- Skills: `founder-playbook` (router), `founder-stage-idea`, `founder-stage-mvp`,
  `founder-stage-launch`, `founder-stage-scale`.
- Agent: `founder-coach` (delegatable coaching persona via the Task tool).

See `skills/founder-playbook/SKILL.md` for the full framework and attribution.
