---
name: session-reentry
description: Re-enter a dormant/foreign session (soul-name Anamnesis) — reconstruct its intent-hierarchy from persisted artifacts + re-onboard any mind progressively. The RECEIVING dual of /postflight.
---

# /session-reentry Command

Thin wrapper that invokes `skills/session-reentry/SKILL.md`. The skill holds all
logic (3-phase INGEST→RECONSTRUCT→RE-ATTUNE composing existing primitives, the
dormancy score, progressive-disclosure pedagogy, single-CTA output contract,
faithfulness guard). This file is the command surface only.

The **RECEIVING dual of `/postflight`**: where postflight *emits* a handoff-seed at
end-of-work, `/session-reentry` *reconstructs and re-onboards* at start-of-re-entry —
for a mind (the operator, another human, or another agent) opening a DORMANT or
FOREIGN thread days/weeks later. Soul-name **Anamnesis** (Plato ἀνάμνησις, *the
un-forgetting* — the dual of the amnesia every fresh agent wakes into).

> **M1 walking-skeleton** — text-only, composes existing primitives. M2 any-mind
> register · M3 audio · M4 graphic + rule cross-refs are deferred to issue #234.

## Usage

```text
/session-reentry [--session <id|path>] [--mind self|human|agent] \
                 [--depth L1|L2|L3|full] [--media text|audio-voice|graphic] \
                 [--scope current|down|sideways|up|forward]
```

All flags optional — bare `/session-reentry` re-enters the current session at L2.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--session <id\|path>` | current | target dormant/foreign thread |
| `--mind self\|human\|agent` | `self` | audience register (thin in M1; full in M2) |
| `--depth L1\|L2\|L3\|full` | `L2` | progressive layer (expand-on-demand) |
| `--media text\|audio-voice\|graphic` | `text` | delivery modality (audio/graphic = M3/M4) |
| `--scope current\|down\|sideways\|up\|forward` | `current` | CPT Compass verb (§9) |

## Examples

```text
/session-reentry
/session-reentry --session 9f606dc6 --depth full
/session-reentry --mind agent --scope forward
```

## Related

`skills/session-reentry/SKILL.md` (logic) · `docs/adrs/ADR-009-session-reentry-anamnesis.md`
(design) · `/postflight` (the SENDING dual) · `skills/morning-briefing` · `skills/work-compass`
· `skills/postflight` (composed primitives) · build tracker
[ekson73/multi-agent-os#234](https://github.com/ekson73/multi-agent-os/issues/234).
