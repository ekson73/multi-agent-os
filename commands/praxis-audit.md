---
name: praxis-audit
description: Self-referential session-method audit — did THIS session's own tools/methods FIRE or was it theater? RECON → RECAP → AUDIT → RESEARCH → COUNCIL → FIX. Composes corpus-firing-audit + enhance-pipeline + convergence-engine (+ council seats) + gap-loop — reimplements nothing.
---

# /praxis-audit Command

Thin wrapper that invokes `skills/praxis-audit/SKILL.md`. The skill holds all logic
(the phases — a RECON pre-step + RECAP→FIX, the retargeted firing/theater lens,
verifier>generator COUNCIL, idempotency contract, STOP-marker grammar, bounds). This
file is the command surface only.

> **Invocation / namespace**: this plugin sets `command_namespace.prefix_required=true`,
> so the canonical form is **`/maos:praxis-audit`** — the bare `/praxis-audit` used below is
> the short form and may require the `maos:` prefix on hosts that enforce it (the CHANGELOG
> announces `/maos:praxis-audit`).

## Usage

```text
/praxis-audit ["<focus>"] [--scope=…] [--source=…] [--dry-run] \
              [--auto-merge=…] [--auto-merge-reason="…"] \
              [--autonomy-threshold=…] [--max-iterations=…] [--output=text|json]
```

All flags are optional — invoking bare `/praxis-audit` audits the current session
(`--scope=this.session`) with FIX defaulting to STAGE-only (`--auto-merge=hold`, EKO-66).

## Flags

| Flag | Default | Allowed values |
|---|---|---|
| `"<focus>"` (positional) | empty | extra free-text narrowing the audit focus |
| `--scope` | `this.session` | `this.session`, `session:<id>`, `branch`, `ticket:<id>` |
| `--source` | `auto` | `auto` (capability-detect), `ash`, `transcript`, `remember`, `commits`, `topology` |
| `--dry-run` | off | run RECON+RECAP+AUDIT+RESEARCH+COUNCIL, print findings + fix-plan, drive NO FIX |
| `--auto-merge` | `hold` | `authorized`, `hold`, `off` (FIX phase; conservative default per EKO-66) |
| `--auto-merge-reason` | *(none)* | non-empty string; **required when `--auto-merge=authorized`** |
| `--autonomy-threshold` | `0.85` | `0.0`–`1.0` (FIX score gate; bands SSOT `agents/COWORK-AUTONOMY-POLICY.md`) |
| `--max-iterations` | `6` | integer — FIX loop cap (passed to gap-loop) |
| `--output` | `text` | `text`, `json` (emit the run envelope) |

See `skills/praxis-audit/SKILL.md` (The phases + Override parameters + Composition)
for the meaning of each value and how the phases land on existing primitives.

## Examples

```text
/praxis-audit --dry-run
/praxis-audit "focus on the council + verifier != generator gates"
/praxis-audit --scope=session:7342e91f --source=ash
/praxis-audit --auto-merge=authorized --auto-merge-reason="method-fixes, green CI"
/praxis-audit --autonomy-threshold=0.9 --max-iterations=4 --output=json
```

## Workflow (delegates to the skill)

1. **RECON** (read-only) — read any prior praxis-audit ledger (idempotency); capability-detect the session's enacted-tool-use sources.
2. **RECAP** — enumerate the methods/tools THIS session actually enacted -> praxis-register (M1..Mn), kind-tagged.
3. **AUDIT** — per method: FIRED-WELL / THEATER / INCONSISTENT / MISFIRE / GAP (retargeted corpus-firing-audit lens, kind-aware, evidence-cited) + Eisenhower-ranked cure (sharpen-fire-point > add-passive-rule).
4. **RESEARCH** — internal + external better-method search (enhance-pipeline EXPAND).
5. **COUNCIL** — convergence-engine dispatches perspective-trio + persona-pipeline + red-team -> converge; a finding survives only if an INDEPENDENT seat confirms it (verifier>generator; red-team-the-verdict).
6. **FIX** (only mutating phase) — gap-loop drives confirmed method-fixes to convergence + independently validates + persists (worktree-disciplined; skipped under `--dry-run`). Regenerate the ledger.
7. Emit exactly ONE `<!--ORCH-STATUS: … -->` STOP marker per turn.

## Anti-loop / autonomy bounds

Inherited from the skill — read-only through COUNCIL; FIX gated (`--auto-merge=hold` default + `--dry-run`);
`--max-iterations` cap (6); depth <= 2; Sentinel HIGH auto-blocks; `verifier != generator` never re-loosened;
HUMAN_DOMAIN + non-negotiable guardrails always halt -> HITL. See `skills/praxis-audit/SKILL.md` (Protocol Rules).

## Related

`skills/praxis-audit/SKILL.md` (logic) · `skills/corpus-firing-audit/SKILL.md` (the retargeted lens, audit sibling) ·
`skills/ooda-loop/SKILL.md` (goal-side conductor, the *what*) · `skills/gap-loop/SKILL.md` (FIX driver) ·
`skills/convergence-engine/SKILL.md` (COUNCIL master condition) · `skills/enhance-pipeline/SKILL.md` (RESEARCH).
