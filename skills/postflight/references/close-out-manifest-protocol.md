---
name: close-out-manifest-protocol
description: The multi-agent close-out directive — a P0 gate (every delegate delivered, fail-closed) and the P3.7 MANIFEST (one consolidated, self-locating close-out artifact with instruction tree, HITL decisions, roadmap + artifact index and a verified recovery triple), persisted durably and copied to the clipboard with read-back verification
version: 0.2.0
---

# Close-Out Manifest Protocol (SSOT) — postflight P0 GATE + P3.7 MANIFEST

> **Version**: 0.2.0 (2026-10-07) — fused with the independent `session-handover` prototype (matrix: PR #478)
> **Scope**: AAIF cross-vendor. Adds two steps to `skills/postflight/SKILL.md` for sessions that
> **delegated work** (sub-agents, teammates, background jobs): a **P0 GATE** before P1 and a
> **P3.7 MANIFEST** after P3/P3.6. A single-agent session may skip both (they are NOOP when
> there were no delegates and no ephemeral reports).
> **Executor**: `bin/close-out-manifest.sh` (`check [--strict]` · `persist` · `clip` · `anchor`).
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
- **Outcome per delegate.** Each line carries one outcome: delivered · failed · expired · cancelled,
  plus model and duration when the host exposes them (tokens/cost only if available — absence is
  written as "n/a", never estimated).
- **Partial close only by the operator.** If the operator explicitly authorises closing over a
  pending delegate, write `delegates_gate: PARTIAL` and `partial_authorized_by:` (who, when, where
  it was said). The executor then passes with `"partial":true`, and the manifest title and the
  handoff must start with `PARTIAL`. Without the authorisation line, `PARTIAL` is refused.

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
| `## Recovery` | The triple, each on its own line: `session_id:` · `link:` (an http(s) URL) · `command:` (the exact command that reopens the session; it must contain the session id). Optional `transcript_path:` — the host's transcript file; if written, it must exist. Also the `anchor` line of every repo touched (below). **Verify the command resolves** before writing it. |
| `## Self-location` | `manifest_path:` the durable path of this file, so a reader holding only the clipboard copy can find the saved one. It must exist and hold the same bytes as the file being checked (`manifest-path-mismatch`). |

Fields are read only inside their own section (`delegates_gate`/`partial_authorized_by` in Delegates gate, the triple and `transcript_path` in Recovery, `manifest_path` in Self-location), and the four content sections (Instruction tree, HITL decisions, Roadmap, Artifact index) must not be empty; `check` refuses either. A `PARTIAL` gate also needs the manifest title (first `# ` line) to start with `PARTIAL` (`partial-title`), so a partial close-out is never mistaken for a complete one.

**Content rules for the sections above** (agent-written; checked where marked):

- **Typed, not prose.** Every open item (instruction node, HITL item, roadmap step) names its
  owner, next action, deadline or trigger, and an escalation threshold as "if X then Y".
- **Verified vs. unverified.** Each fact carries "verified (command)" or "unverified"; the next
  session treats unverified facts as hypotheses.
- **HITL only for what needs a human.** Anything the agent can do alone goes to the roadmap. One
  recommended option, first; trade-off per option; where to act; at most one question per turn.
- **Paths.** Every backticked absolute path must exist (checked: `broken-link`) and must not point
  at a temp/scratch area (checked: `ephemeral-link`) unless its line says `(ephemeral)`.
- **Versions.** A newer manifest names the one it supersedes (`supersedes:`); old ones are kept.
- **Size budget.** The handoff copied to the clipboard stays within the budget the seed contract
  sets; detail lives in the linked files.

### Opt-in: `check --strict`

Off by default so the normal close-out is neither slower nor noisier. Adds three required sections:
`## After-action review` (planned · happened · why · keep/improve, facts first, no blame),
`## Resume check` (the first task of the next session: restate the handoff, compare it with the
live state — anchors, PRs, worktrees — and list divergences before acting) and `## Not done`
(what was not done by guardrail and what stayed open). None of the three may be empty. Decision candidates (ADR drafts for human
review) and lesson candidates (deduplicated against existing memory before promotion) may be
listed under `## Not done` as proposals; nothing is written automatically.

### Git anchor (`anchor`)

`bin/close-out-manifest.sh anchor --repo <dir>` prints `branch@HEAD · UTC`, every uncommitted file
by name and every worktree. It is read-only: dirty work is reported (rc 2), never staged, stashed
or discarded. Run it for every repo the session touched and paste the lines into `## Recovery`;
the next session compares them with the live state before acting.

### Durability (persist)

Reports in a scratch/temp area are copied to a durable location **before** the manifest indexes
them: `bin/close-out-manifest.sh persist --dest <durable-dir> --src <report>... --apply`
(dry-run without `--apply`). It refuses any file that the secret scan or the PII scan flags, and
it refuses to run at all if either scan cannot detect a positive control assembled at runtime
(rc 3). Each source is first copied into a private staging dir and only those staged bytes are scanned and promoted, so a change made during the scan never reaches the destination. Binary files are refused; the scan covers the raw bytes, a CRLF-normalised view and a line-joined view (a secret split across lines), and runs isolated from inherited scanner config, ignore files and in-content allow directives. A known-clean negative control must scan clean, so a scanner that errors on everything is reported as rc 3, not as a leak; any other scanner error on a source counts as a hit. All temporary data lives in one private dir (umask 077, honours `$TMPDIR`) plus the registered rename temp next to the target; one exit trap removes them on success, error and INT/TERM/HUP alike, and a cleanup that cannot remove them is reported (rc 6). The clipboard read-back streams into `cmp`, so the handoff never lands in a temp file. A changed target is kept as `<file>.bak.<UTC>` before it is replaced. A destination that is a symlink or a directory is refused (`refused-dest-not-regular`). A requested source that is missing or not a regular file, and two sources with the same basename (one destination name), are refused (rc 5), never silently skipped. The PII scan covers email, CPF (formatted, or a bare 11-digit run with valid check digits) and Brazilian phone numbers in international (`+55`) and domestic formats (area code in parentheses or followed by a space or hyphen, 8- or 9-digit number with a space or hyphen); a bare run of 10-11 digits is not matched, to avoid flagging ids and timestamps. A refused file is never copied; record it in the manifest as a HITL item. Choose the
durable dir by governance discovery (the repo's session/report path, or the seed dir).

### Check, then clipboard

1. `bin/close-out-manifest.sh check --manifest <file>` (add `--strict` if you opted in) — must exit 0.
2. `bin/close-out-manifest.sh clip --file <file>` — copies and reads back with `cmp`. rc 0 means
   verified. rc 4 means not verified (also when only one of `MAOS_CLIP_COPY` / `MAOS_CLIP_PASTE` is set: `incomplete-clip-override`): use the paste MCP (create the item from the file, read it
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
8. ❌ Writing `PARTIAL` without the operator's authorisation line, or hiding the partial flag.
9. ❌ Stating an unchecked fact without marking it "unverified".

## License

MIT (matches the multi-agent-os repo `LICENSE`).
