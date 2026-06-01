---
name: dogfood-ledger
description: Count real dogfood cycles per agentic-tool (the ≥2-cycle promotion gate authority). Use to mark a dogfood cycle (in-progress / complete+ratified+evidence) or to tally how many real cycles a tool has before promotion. Replaces changelog-prose cycle counting with a structured, jq-countable, auditable ledger. Triggers - "how many dogfood cycles does X have", "mark this cycle complete", "is X promotion-eligible", "count cycles".
version: 1.0.0
author: MAOS Community
---

# dogfood-ledger

> Thin ergonomic wrapper over the AAIF bash CLIs `bin/dogfood-mark` + `bin/dogfood-tally`.
> The engine is vendor-neutral bash (works in Cursor / Copilot / Codex / Gemini too).
> **Spec**: `docs/dogfood-cycle-ledger-spec.md` · **ADR**: `docs/adrs/ADR-005-dogfood-cycle-ledger.md`

## Purpose

The dogfooding-mandate gates promotion on **≥2 real cycles**, but the count was only changelog prose — unmeasurable = theater. This skill makes it real: one user-scope, append-only, `jq`-countable ledger at `~/.claude/audit/dogfood-cycles.jsonl`, fed by any session/project/vendor. `bin/dogfood-mark` is the writer; `bin/dogfood-tally` is the read-only counting authority.

## When to Use

Use when you need to record or count dogfood cycles for the ≥2-cycle promotion gate.

**Count cycles for a tool (the gate authority):**
```bash
bin/dogfood-tally debate-converge          # table: COMPLETE / IN-PROGRESS / ABANDONED + gate verdict
bin/dogfood-tally                           # all tools
bin/dogfood-tally debate-converge --json    # machine-readable (+ .eligible)
```

**Mark a cycle:**
```bash
# open / advance (in-progress)
bin/dogfood-mark debate-converge 001 --status in-progress --evidence session:<sid>

# close it (COMPLETE requires --ratified AND >=1 --evidence — anti-theater)
bin/dogfood-mark debate-converge 001 --status complete --ratified \
  --evidence github:ekson73/multi-agent-os/pull/97 --evidence session:<sid>
```

**Backfill real historical cycles** (cycles that already happened, never counted) — **Phase 2, planned (not yet implemented)**:
```bash
bin/dogfood-mark --backfill --dry-run       # (planned) show detected cycles + evidence
bin/dogfood-mark --backfill                  # (planned) register them (evidence-based, anti-hallucination)
```
Until `--backfill` lands, record historical cycles with direct evidence-based `dogfood-mark` calls.

## Trigger Phrases

- "how many dogfood cycles does X have"
- "mark this cycle complete" / "mark cycle in-progress"
- "is X promotion-eligible" / "did X meet the ≥2-cycle gate"
- "count cycles" / "tally dogfood cycles"

## Protocol Rules

- A cycle is **COMPLETE** only with `ratified==true` + ≥1 evidence ref. "Rounds happened" ≠ complete.
- The ledger is the **single SSOT** — do NOT keep per-skill island counters (they migrate here).
- `dogfood-tally` is read-only; all writes go through `dogfood-mark`.
- Local-only ledger → LGPD long-term retention is an out-of-band gap (do not over-promise permanence).

## Composition

- **ASH** `bin/ash-walkthrough --dogfood-cycles` (vkl) reads this same ledger (consumer, not a 2nd SSOT).
- **CPT** §9 Compass API + `gsd-graphify` consume the link-fields for inter-relation/graph (this skill does not visualize).
