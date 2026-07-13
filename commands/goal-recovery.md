---
name: goal-recovery
description: Recover a session's real INTENT from its own live/context state — motivations, DoR, context, scope, and the objective tree {originating, primary, secondary, auxiliary} — into ONE typed, validator-gated handoff-as-prompt envelope whose `goal` is consumed downstream as {{goal}}. The direction-inverted twin of postflight; uncertainty-aware (ranked hypotheses + confidence + inconclusive->HITL).
---

# /goal-recovery Command

Thin wrapper that invokes `skills/goal-recovery/SKILL.md`. The skill holds all logic
(the Skopos recon-first inference ladder, the RECON->SYNTHESIZE->HYPOTHESIZE->EMIT pipeline,
the uncertainty-aware discipline, the deterministic-envelope / probabilistic-content boundary,
the composition wiring, the override flags, and the STOP-marker grammar). This file is the
command surface only.

The output contract lives in `skills/goal-recovery/templates/handoff-as-prompt.schema.json`;
the validator in `skills/goal-recovery/bin/validate_envelope.py`.

## Usage

```text
/goal-recovery "<optional hint>"
               [--scope=this.session|branch|ticket:<id>|session:<id>]   (default this.session)
               [--conf-inconclusive=0.60]     (below => inconclusive.flag=true -> HITL)
               [--ladder=postflight_seed,ticket,ash_journal,...]        (restrict inference sources)
               [--output=json|summary]        (default json — the envelope)
               [--dry-run]                    (recover + print; do NOT hand off to a driver)
```

Sibling routing: use `/postflight` to EMIT a continuation-seed at session END (the forward
direction); use `/preflight` to anchor to a KNOWN ticket; use `goal-recovery` to RECOVER an
UNSTATED intent from context. `ooda-loop` calls this as its Observe step.

## Examples

```text
/goal-recovery                                   # recover this session's intent -> handoff-as-prompt
/goal-recovery --scope=ticket:VKS-1234           # recover from a ticket anchor
/goal-recovery --output=summary                  # human recap instead of the JSON envelope
/goal-recovery --conf-inconclusive=0.75 --dry-run
```

## Related

- `skills/goal-recovery/SKILL.md` — full skill logic
- `skills/goal-recovery/templates/handoff-as-prompt.schema.json` — the output contract
- `skills/postflight/SKILL.md` — the forward-direction twin (EMITs the seed this RECOVERs)
- `commands/ooda-loop.md` — the conductor that consumes this as its Observe step
