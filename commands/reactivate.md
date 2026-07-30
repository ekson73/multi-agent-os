---
name: reactivate
description: Cold-start reactivation conductor for new-fresh-born amnesic agents. Orients from whatever evidence exists (or honestly reports none), recovers the unstated intent, deliberates, and PRESENTS ranked recommendations routed to the consumer's own form — operator_language ask-tool for a live human, persisted ranked set for a deferred human, typed JSON envelope for an agent/abiotic consumer. Explicit operator instruction overrides every computed condition. Soul-name Entelecheia.
---

# /reactivate Command

Thin wrapper that invokes `skills/reactivate/SKILL.md`. The skill holds all logic (the 6-phase
pipeline, the consumer-classification cascade, the zero-artifact branch that carries a cold start
past `pulse`'s stop-rule, the THINK deliberation bounds, the mandatory sanitize gate, the reused
Return-Gate, the `recommendation-set` payload, and the invariants). This file is the command
surface only.

Soul-name **Entelecheia** — Aristotle, *De Anima* II.1: the *first* actuality is having knowledge
without exercising it (sleep); the *second* is exercising it (waking). This moves an agent from
the first to the second.

## Usage

```text
/reactivate ["<optional hint about what you were doing>"]
            [--consumer=human-live|human-deferred|machine|auto]   (default auto; explicit ALWAYS wins)
            [--depth=quick|full]        (default quick — phases 0-3,5; full adds the PHASE-4 chain)
            [--lang=pt|en|auto]         (default auto — human classes RESOLVE operator_language per the
                                         host language policy, never a hardcoded tag; machine is always
                                         en-US. --lang=en forces en-US human-facing output, --lang=pt pt-BR)
            [--json]                    (force the machine envelope regardless of class)
            [--no-act]                  (present only — never let the Return-Gate act, even if it clears)
```

## What it does

```text
PHASE 0  CONSUMER   classify the consumer first, so every phase knows its output form
PHASE 1  ORIENT     pulse ──(pulse stops on a true cold start)──► zero-artifact branch
PHASE 2  INTENT     goal-recovery — ranked hypotheses + confidence, or inconclusive
PHASE 3  THINK      bounded deliberation: competing framings · discriminating probe · cost of being wrong
PHASE 4  DEEPEN     enhance-pipeline → converge → [praxis-audit]        (--depth full only)
PHASE 5  PRESENT    sanitize (mandatory) → Return-Gate (rank + act-or-persist) → route by consumer
```

Composes existing skills for phases 1, 2 and 4 — reimplements none. Newly authors only the THINK
step, the data-sanitize gate, and the unified PRESENT assembly.

## Sibling routing (pick the right one)

- There **is** a continuation seed / prior session artifact to re-enter → `/session-reentry`
  (artifact-driven and richer). `/reactivate` is the **zero-or-thin-artifact** path.
- You already know the goal and need the vehicle → `/derive-system-from-goal`.
- You are mid-task with full context and just need re-orientation → `pulse` directly.
- A decision is on the table and the question is *"may I act without the human?"* →
  `/council-gate`. That gate **authorizes**; this conductor **orients**.
- Session ENDING and you need to emit a seed for the next agent → `/postflight`.

## Guarantees

- **Never fabricates context** — an honest *"no recoverable context, here is what I can reach and
  what I'd need to know"* is a valid output.
- **Never blocks** in `human-deferred` — it acts when the Return-Gate clears, else persists the
  ranked set and returns.
- **Always sanitizes** before presenting — secrets, credentials, and personal data are scrubbed
  regardless of consumer, depth, or instruction.
- **Adds no authorization** — acting authority comes only from the reused Return-Gate.
