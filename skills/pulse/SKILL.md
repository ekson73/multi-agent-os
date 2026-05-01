---
name: pulse
version: "0.1.0"
description: |
  Session re-orientation skill. Refreshes context, snapshots status, builds
  a dependency graph, classifies pending work via Eisenhower 2x2, and routes
  each item ∈ {now, delegate, defer-trigger, backlog, drop}. Vendor-neutral,
  single-session, output-budgeted. Chain-links to prior pulse artefacts when
  present. Triggers: "session pulse", "where are we", "catch up", "re-orient",
  "drift check", "status + plan", "what's next", "weekly review".
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Pulse

Vendor-neutral session re-orientation skill. Run when an agent needs to STOP, recover the picture, decide what comes next, and persist that decision so a future session (any agent, any runtime) can resume without drift. Portable across runtimes (Claude Code, Cursor, Codex, Gemini CLI, etc.).

## When to use

- Resuming a multi-session project after a break (drift risk)
- Mid-session pivot — new info forces re-prioritisation
- End-of-session — persist state for the next runner
- Workspace has many open threads (epics, ADRs, PRs, branches, todos)
- Rhythmic review (PDCA Check + Plan, weekly cadence)

NOT for: actively executing one focused task; convergence between competing AI proposals (use `/converge`).

## Instructions — the 5-phase protocol

Run phases in **strict order**. Each phase has explicit output and a skip-rule.

### PHASE 1 — Memory refresh

Read recent commits, open todos, top-level memory/changelog index, planning artefacts if any. **Output**: 3-7 bullet objectives map (primary / secondary / auxiliary). Lossy by intent — never a dump.

**Skip if** no memory + no commits + no todos + no prior pulse → emit "fresh start" + suggested first action; stop.

### PHASE 2 — Status snapshot

Per active item (open todo, unmerged branch/PR, in-progress ticket, file with unstaged changes): ⟨name | readiness gate met? | completeness distance | gaps | blocking question⟩. DoR/DoD are one example of readiness/completeness; runtimes may use other gates.

**Skip if** zero active items → emit "all clear"; stop.

### PHASE 3 — Dependency graph

One mermaid `graph LR` block. Edges = atomic dependencies between Phase 2 items. Short node IDs.

**Skip if** < 3 nodes → one-line dependency description instead.

**Cycle detection**: if a cycle is detected, emit the cycle nodes (e.g., `cycle: A → B → C → A`) and mark them `pending-quadrant-resolution`. Do not error and do not escalate yet — Phase 4 will compute quadrants for the cycle nodes and Phase 5 will apply the break-heuristic with that data.

### PHASE 4 — Eisenhower 2x2

Four-quadrant table (Urgent×Important / Not-Urgent×Important / Urgent×Not-Important / Not-Urgent×Not-Important). Cap 7 items per cell (truncate with note). Skip empty quadrants entirely.

**Skip if** no pending items survived Phase 2.

**Cycle handling (continuation from Phase 3)**: when nodes were marked `pending-quadrant-resolution`, classify them into quadrants like any other items. Their quadrants feed Phase 5's break-heuristic.

### PHASE 5 — Route + persist

Per item, route ∈ {`now`, `delegate`, `defer-trigger`, `backlog`, `drop`} with rationale. For `defer-trigger`, capture the wake-up condition explicitly.

**Conflict rule**: when two items both demand `now`, force-rank by Phase 4 quadrant; ties escalate to human (no auto-decide).

**Cycle break-heuristic (resolution from Phase 3 + 4)**: for nodes marked `pending-quadrant-resolution`, drop the cycle edge whose endpoints fall in the lowest-priority quadrants (rank: not-urgent×not-important > urgent×not-important > not-urgent×important > urgent×important). Document the dropped edge and rationale. Escalate to human only if the lowest quadrant is tied at the urgent×important level.

**Persist**: write Markdown artefact at `persist_path` (default literal `./PULSE-<ISO-date>-<slug>.md`).

**Chain rule**: if a prior pulse artefact was consumed in Phase 1, set `prev:` link in frontmatter and reference it in §7.

**Skip writes if** `dry_run=true` (overrides `persist`).

## Optional toggles

- `persist` (default `false`) — append a one-line pointer to project memory/changelog if either exists; emit `backlog`/`defer-trigger` items as resumable prompt files at `backlog_path`. No-op if no project memory present.
- `dry_run` (default `false`) — preview to stdout, never write. Overrides `persist`.
- `consume_prior` (default `auto`) — `auto` finds the most recent `PULSE-*.md` in the workspace and chain-links it; `none` skips; or pass an explicit path.
- `persist_path` (default `./PULSE-<ISO-date>-<slug>.md`) — output artefact path. Literal default; runtimes may substitute their own path conventions.
- `backlog_path` (default `./backlog/`) — directory for emitted backlog/defer-trigger prompt files.

## Output structure

```text
§1 TL;DR (1-3 sentences — where we are, what's next)
§2 Objectives map (primary / secondary / auxiliary)
§3 Status snapshot (per-item table)
§4 Dependency graph (mermaid)
§5 Eisenhower 2x2 (table)
§6 Routing (item | route | rationale | trigger? | open question)
§7 Audit chain (sources, version, timestamp, dry_run flag, chain-link to prior pulse)
```

## Invariants (non-negotiable)

- Phase order is strict; skip-rules are the only allowed deviation
- Objectives map: max 7 bullets — graceful truncation, never silent drop
- Output budget enforced — truncate Phases 1-3 first; Phase 5 routing must always complete
- `dry_run` overrides `persist`
- Vendor-neutral — no proprietary tool names in body
- Chain-link preserved when a prior pulse was consumed
- Audit chain preserved: timestamp, version, input source list

## Failure modes

- **Empty workspace** → "fresh start" + suggested first action
- **DAG cycle detected** → Phase 3 emits cycle nodes as `pending-quadrant-resolution`; Phase 4 classifies them; Phase 5 applies break-heuristic; escalate only if lowest quadrant is tied at urgent×important
- **Output exceeds budget** → truncate Phases 1-3 first; Phase 5 routing must complete
- **Non-git workspace** → degrade: skip git inputs, proceed with todos + memory only
- **Prior pulse parse error** → start fresh, log warning in §7

## Activation examples

Natural-language invocations:

- "pulse" — defaults; preview only
- "pulse — persist" — full write
- "pulse — dry-run" — preview, no writes (overrides persist if also passed)
- "pulse — consume-prior `./PULSE-2026-04-30-slug.md`" — explicit chain-link
- "pulse — persist-path `./reports/pulse-q2.md`" — custom output path

CLI-style equivalents (when invoked from a runtime that supports flags):

```bash
pulse
pulse --persist
pulse --dry-run --persist
pulse --consume-prior ./PULSE-2026-04-30-slug.md
pulse --persist-path ./reports/pulse-q2.md
```

## Prior art (digest — full survey in `PRIOR-ART.md`)

| Primitive borrowed | Source | Adopted as |
|---|---|---|
| In-session resume + DONE/PARTIAL classify | hacktivist123/agent-session-resume (MIT) | Phase 2 status taxonomy |
| Handoff CREATE/RESUME + chain links | softaworks/agent-toolkit/session-handoff | Phase 5 chain-link |
| Eisenhower 2x2 + Do/Schedule/Delegate/Eliminate | Eisenhower / Covey / mission-control (AGPL) | Phase 4 model + 5-route taxonomy |
| OODA Observe-Orient framing | Boyd USAF / mcpmarket OODA skill | Phase 1+2 fusion rationale |
| Output budget + skip-rules | sibling `/converge` skill | Invariant + per-phase short-circuit |

**What pulse uniquely combines** (verified gaps in surveyed prior art):

1. Memory + Status + DAG + Eisenhower + chain-linked persistence in **one** SKILL.md (no surveyed artefact combines >2)
2. `defer-trigger` route as first-class taxon (most tools collapse it into "backlog")
3. `consume_prior` chain-link semantics for compounding pulses across sessions
4. Cycle break-heuristic before escalation (deterministic > error)

## Related multi-agent-os artefacts

- `skills/converge/SKILL.md` — sibling for cross-agent proposal convergence (used as the meta-PDCA tool to design pulse itself)
- `protocols/agent-delegation.md` — delegation chain integration for the `delegate` route

## Versioning

- v0.1.0 (2026-05-01) — initial release; 5-phase protocol; design converged via meta-PDCA loop using `/converge`

## License

Apache-2.0 (matches multi-agent-os repo).
