---
name: close-out-manifest-protocol
description: The multi-agent close-out directive — a P0 gate (every delegate delivered, fail-closed) and the P3.7 MANIFEST (one consolidated, self-locating close-out artifact with instruction tree, HITL decisions, roadmap + artifact index and a verified recovery triple), persisted durably and copied to the clipboard with read-back verification
version: 0.1.0
---

# Close-Out Manifest Protocol (SSOT) — postflight P0 GATE + P3.7 MANIFEST

> **Version**: 0.1.0 (2026-10-07)
> **Scope**: AAIF cross-vendor. Adds two steps to `skills/postflight/SKILL.md` for sessions that
> **delegated work** (sub-agents, teammates, background jobs): a **P0 GATE** before P1 and a
> **P3.7 MANIFEST** after P3/P3.6. A single-agent session may skip both (they are NOOP when
> there were no delegates and no ephemeral reports).
> **Executor**: `bin/close-out-manifest.sh` (`check` · `persist` · `clip`).
> **Cross-link slug**: `close-out-manifest-protocol`

## Why

Postflight already sweeps, debriefs, tickets, seeds, spawns and broadcasts. Three things were
still left to luck when several agents worked in one session:

1. Closing while a delegate is still running — the seed then describes a state that is about to
   change (anti-pattern #1 by another door).
2. Reports written by delegates live in an ephemeral scratch area and vanish with the session.
3. The operator gets the handoff "best-effort" on the clipboard and has no single document
   that says where everything is and how to get the session back.

This protocol closes those three gaps. It **references** the existing SSOTs and does not restate
them: the hunt (`close-out-hunt-checklist.md`), the seed (`continuation-seed-contract.md`), the
ticket sync (`ticket-sync-protocol.md`) and the broadcast (`continuation-broadcast-protocol.md`).

## P0 GATE — every delegate delivered (fail-closed)

Before P1, list every delegate this session started (name or id, what it was asked, where its
report goes) and wait for each one to reach a terminal state: **delivered**, **failed** (with its
error kept) or **dropped** (with a one-line reason). Rules:

- **Fail-closed.** A delegate with unknown state counts as *not delivered*. Do not close.
- **Bounded wait.** Wait up to the delegate's own time-box (default 15 min). Past it, stop the
  delegate if the host allows; if it cannot be confirmed stopped, record it as an **orphan** and
  carry it as a risk in the seed and as a HITL item in the manifest. Never close silently over it.
- **Record the verdict** in the manifest as `delegates_gate: PASS` only when every delegate is
  terminal (delivered, failed-with-error, or dropped-with-reason). Anything else is `PENDING` or
  `ORPHAN`, and `bin/close-out-manifest.sh check` refuses it.
- **No delegates ⇒ PASS** (write `delegates_gate: PASS` with "none").

## P3.7 MANIFEST — one consolidated, self-locating artifact

After P3 (and P3.6 if on), write ONE markdown manifest. It is the operator's map and the next
mind's entry point. Required sections (exact headings, checked by the executor):

| Section | Content |
|---|---|
| `## Delegates gate` | `delegates_gate: PASS` + one line per delegate: id · ask · terminal state · report path |
| `## Instruction tree` | The operator's prompts/instructions as an N-tree (originating → derived), each node with status `[done]` · `[partial]` · `[blocked]` · `[dropped: reason]`. **Sync rule:** every node maps 1:1 to the harness todo-list (create, close or mark the matching todo); a todo with no node, or a node with no todo, is a drift to fix before closing. The P2 objectives N-Tree stays the SSOT for objectives; this tree tracks the *instructions* that produced them. |
| `## HITL decisions` | Every item only a human can decide, Eisenhower-ordered, each with 2-4 options and the **recommended option first** plus its trade-off. Sources: the hunt's decisions-not-taken and unanswered-Qs, and P0 orphans. |
| `## Roadmap` | Next steps in order (non-blocked first), linked to the continuation ticket from P2.5. |
| `## Artifact index` | Link to every artifact the session produced: seed path, tickets, PRs (number + head), commits, persisted reports, docs. One line each. |
| `## Recovery` | The triple, each on its own line: `session_id:` · `link:` · `command:` (the exact command that reopens the session, e.g. `claude --resume <id>`). **Verify the command resolves** (the session/transcript exists) before writing it. |
| `## Self-location` | `manifest_path:` the durable path of this file, so a reader holding only the clipboard copy can find the saved one. |

### Durability (persist)

Reports in a scratch/temp area are copied to a durable location **before** the manifest indexes
them: `bin/close-out-manifest.sh persist --dest <durable-dir> --src <report>... --apply`
(dry-run without `--apply`). It refuses any file that the secret scan or the PII scan flags, and
it refuses to run at all if either scan cannot detect a positive control assembled at runtime
(rc 3). A refused file is never copied; record it in the manifest as a HITL item. Choose the
durable dir by governance discovery (the repo's session/report path, or the seed dir).

### Check, then clipboard

1. `bin/close-out-manifest.sh check --manifest <file>` — must exit 0.
2. `bin/close-out-manifest.sh clip --file <file>` — copies and reads back with `cmp`. rc 0 means
   verified. rc 4 means not verified: use the paste MCP (create the item from the file, read it
   back, compare), and say in the exit summary which path succeeded. Never report "copied" on
   rc 4 without the fallback.

## Anti-patterns (do NOT)

1. ❌ Closing with a delegate in an unknown state (the gate is fail-closed).
2. ❌ Indexing a report that still lives only in a scratch area.
3. ❌ A recovery command that was never checked to resolve.
4. ❌ HITL items without a recommended option, or with the recommendation not first.
5. ❌ Reporting the clipboard as done without a read-back match.
6. ❌ Restating hunt/seed/ticket/broadcast content here instead of linking to their SSOT.
7. ❌ Names of people, secrets or personal data in the manifest — metadata only.

## License

MIT (matches the multi-agent-os repo `LICENSE`).
