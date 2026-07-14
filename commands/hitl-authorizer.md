---
name: hitl-authorizer
description: Soul-name Tribune. The pre-HITL authorization broker — front-door for every escalation that would otherwise fall back to a human. Runs the Council-before-HITL procedure and returns AUTHORIZE (substitute the human's "yes" at score≥0.90 ∧ convergence ∧ independent-verify ∧ ¬carve-out) or DEFER (escalate, carrying a ranked recommendation). Verdict-emitter, not an actor; NEVER authorizes a carve-out (secrets ⛔ un-liftable · HUMAN_DOMAIN · merge→prod). Generalizes bot-finding-arbiter (Praetor) to all escalation points.
---

# /hitl-authorizer Command

Thin wrapper that invokes `skills/hitl-authorizer/SKILL.md`. The skill holds all logic
(the OODA protocol, the deterministic HARD-boundary pre-filter `bin/classify.sh`, the 33
Socratic questions, the MoE→Council ladder, the ≥0.90 DECIDE gate, the ⛔ carve-outs, the
family-wiring convention, and the verdict envelope). This file is the command surface only.

The decision-rule SSOT it enacts lives in `agents/COWORK-AUTONOMY-POLICY.md`; the user-scope
boundary policy in `~/.claude/rules/hitl-authorizer.md`.

## Usage

```text
/hitl-authorizer '<escalation envelope JSON>'
                 [--json]                 (emit the machine verdict envelope)
                 [--reason "<why brokering this>"]
```

The escalation envelope (all fields optional strings):
`{ "decision", "action", "context", "motivation", "dod", "scope", "targets", "state" }`.

## Behavior (summary)

1. **OBSERVE** — intake the envelope + Skopos recon (CASC Gate-0).
2. **ORIENT** — `bin/classify.sh` HARD-boundary gate (carve-out → DEFER now, no council) →
   33 Socratic → anti-theater 8Q + CASC.
3. **COUNCIL** — MoE→Council (verifier > generator; red-team/Elenchus on hard-triggers).
4. **DECIDE** — `AUTHORIZE iff score≥0.90 ∧ convergence ∧ independent-verify ∧ ¬carve-out ∧ 8/8 ∧ CASC-green`, else `DEFER`.
5. **ACT** — emit the verdict + ASH `decision-capture`; the CALLER acts (retaining accountability).

## Examples

```text
/hitl-authorizer '{"decision":"pick the default log level for a dev-only flag","context":"reversible, internal","scope":"one constant"}'
/hitl-authorizer --json '{"decision":"export the production tenant table with customer PII","context":"LGPD-regulated"}'   # → DEFER (carve-out, no council)
```

## Related

- `skills/hitl-authorizer/SKILL.md` — full skill logic (soul *Tribune*)
- `skills/bot-finding-arbiter/SKILL.md` — the domain-specific sibling (soul *Praetor*) it generalizes
- `agents/COWORK-AUTONOMY-POLICY.md` — the decision-rule SSOT it enacts
- `~/.claude/rules/hitl-authorizer.md` — the user-scope boundary policy
