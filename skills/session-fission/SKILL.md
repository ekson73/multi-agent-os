---
name: session-fission
description: On-demand splitter for a tangled Claude session. Non-destructively inventories the current session's N-Tree of atomic contexts (project / ticket / task / worktree / branch), snapshots the transcript, distills each atomic context into a clean self-contained seed, and reseeds fresh focused sessions — relieving context bloat, cognitive overhead, and token exhaustion. NEVER mutates or deletes the source session. Trigger when the user says "split this session", "session fission", "this session is tangled", "encavalei assuntos", "untangle my session", "too much context in one session", "spin this off into its own session".
version: 0.1.0
---

# Session Fission Skill

## Purpose

A single Claude session often tangles unrelated work into one linear transcript: Task-A needs Task-B, Task-B needs an MCP fix (Task-B2), the boss injects Task-C, a bug forces a Task-D skill fix. By day's end the session is an **N-Tree forest collapsed into one timeline** — huge context, cognitive overhead, token exhaustion, and unfinished work spilling into backlog.

`session-fission` splits that tangled "heavy nucleus" into multiple **light, stable, atomic-context sessions** — *non-destructively*. It inventories the tangle, snapshots it safely, distills each atomic context into a clean seed, and reseeds focused sessions. The original is **archived, never mutated or deleted** (fully recoverable via native `/resume`).

## When to Use

- A session has drifted across 2+ unrelated tasks/projects/branches and feels heavy.
- `/context` shows high usage and you want to shed bloat per-topic instead of `/clear` (total) or `/compact` (lossy).
- You want each remaining thread to continue in its own focused session.
- End-of-day: convert one exhausted tangled session into a clean N-Tree of resumable seeds for tomorrow.

## Trigger Phrases

`split this session` · `session fission` · `fission this` · `this session is tangled` · `untangle my session` · `encavalei assuntos` · `dividir esta sessão` · `too much context` · `spin this off`

## Feasibility note — why fission ≠ native `/branch`

Native Claude Code session ops (validated against `code.claude.com/docs/en/sessions`):

- `/branch`, `claude --resume <id> --fork-session` **copy the WHOLE conversation** (new `.jsonl` with `forkedFrom.sessionId`, grouped under root). A fork still carries the full tangle — it does **not** relieve bloat.
- There is **no supported way to surgically delete middle messages** or split one session into N topic-grouped sessions. The transcript is an append-only `parentUuid` DAG with paired `tool_use`/`tool_result`; cutting migrated messages would orphan parent pointers and break tool-call pairing → an **unresumable** transcript.

So fission's value = **distill-and-reseed per atomic context** (the gap no native command fills), with the original preserved.

## Protocol (6 steps)

1. **Inventory (read-only).** Run `inventory.sh` to parse the current transcript and propose an N-Tree of atomic-context clusters. The MVP heuristic clusters by `{git-branch, time-gap}` (a topic boundary is inferred from `SF_GAP_SECONDS`, default 1800s, within a branch) and records `cwd` per cluster; richer `{project, ticket, task}` keying is deferred to v2. Review/adjust the clustering with the user — this is a *proposal*, not a verdict.
2. **Classify into N-Tree.** Tag each cluster + relation: sequential `→`, recursive `↻`, independent `∥`, parallel `‖`.
3. **Snapshot (safety gate — BEFORE any file op).** Run `snapshot.sh` to copy the source `.jsonl` to a backup dir + write a manifest + `gitleaks` scrub. This is the rollback anchor. The source is read-only throughout.
4. **Distill per node (the cognitive step — YOU do this, not the script).** For each cluster, read its slice of the transcript and write a clean, self-contained seed: a Ticket-as-Prompt that carries ONLY that atomic context (goal, state, files, decisions, next step). `seed.sh` emits the scaffold; you fill it with the distilled context. This is what relieves bloat — the seed is small.
5. **Reseed / spawn.** Hand each seed to a fresh focused session (see Reseed paths below). Mark the original archived/superseded — do NOT delete it.
6. **Topology + handoff.** Summarize the resulting N-Tree (Mermaid + per-seed pointers) so the user can navigate "forward / sideways / down / up-to-root" (CPT Compass). Emit an end-of-action briefing.

## Safety guarantees (requirements ↔ mechanism)

| Requirement | Mechanism |
|---|---|
| on-demand | this skill + `/maos:session-fission` command |
| non-interfering | scripts are **read-only on the source transcript**; reseeds are additive; out-of-scope sessions untouched |
| snapshot before manipulating files | step 3 `snapshot.sh` copies source + manifest + gitleaks **before** any archive |
| rollback | source never mutated; backup retained; native `/resume <original>` always recovers |
| idempotent | re-running yields the same clustering; `snapshot.sh` skips duplicate SHA; seed files overwrite-safe |

## Commands (helper scripts — deterministic mechanics)

```bash
# 1. Inventory current (or given) transcript → atomic-context N-Tree (JSON, read-only)
bash ${CLAUDE_PLUGIN_ROOT}/plugin-scripts/session-fission/inventory.sh [transcript.jsonl]

# 2. Snapshot the source transcript (rollback anchor) BEFORE any archive op
bash ${CLAUDE_PLUGIN_ROOT}/plugin-scripts/session-fission/snapshot.sh <transcript.jsonl> [backup_dir]

# 3. Emit a Ticket-as-Prompt seed scaffold for one cluster (you then fill the distilled context)
bash ${CLAUDE_PLUGIN_ROOT}/plugin-scripts/session-fission/seed.sh <cluster_id> [label] [seed_dir]
```

Transcript auto-detect: with no arg, `inventory.sh` picks the most-recent `.jsonl` in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<encoded-cwd>/` (Claude Code exposes no `CLAUDE_SESSION_ID` env var, so auto-detect = most-recent; pass the path explicitly to be exact).

## Distillation guidance (the cognitive step)

For each cluster, the seed must let a fresh amnesic agent resume with ZERO prior context. Fill the scaffold's fields: **context** (state of the world), **objective**, **tasks/subtasks/steps**, **files touched**, **decisions made**, **open question / next step**, **acceptance criteria**, **cross-links** (ticket, branch, worktree). Keep it minimal-sufficient — the whole point is a *light* nucleus.

## Reseed paths

- **Option E (reuse — preferred):** hand the seed to `ccpanes-fork-session` / `launch_task` (new instance), or `claude -n <name>` seeded from the seed file (`Read the seed at <path> and execute it`). Use `context-save` for the snapshot substrate if available.
- **Option D (native primitives):** `/branch <name>` per atomic context, then `/compact <retain only Task-X>` to shed the rest. Cheaper but `/compact` is lossy; use when full distillation isn't worth it.
- **Never Option B:** do not attempt to trim/delete the migrated messages from the live transcript — unsafe and unsupported.

## Integration (CPT + ecosystem)

- **CPT** (`cowork-process-topology-protocol`): the N-Tree + per-seed pointers ARE a CPT topology; emit `topology.md` + `manifest.yaml` so morning-briefing/auto-orchestrator can navigate via the Compass `--scope` API.
- **morning-briefing:** the resulting seeds surface as next-action / in-flight items.
- **auto-orchestrator:** may invoke `/maos:session-fission` as a pre-step before working a backlog.
- **(v3 roadmap):** sentinel anomaly rule "session exceeds N atomic contexts ⇒ recommend fission" + statusmap dashboard node.

## Anti-patterns

- ❌ Deleting the original session (Option A delete) — archive-not-delete; deletion breaks rollback.
- ❌ Surgically trimming the live transcript (Option B) — produces an unresumable session.
- ❌ Reseeding with the full tangle copied in — defeats the purpose; the seed must be the distilled atomic context only.
- ❌ Skipping the snapshot before archiving — snapshot is the rollback anchor; never skip.
- ❌ Treating `inventory.sh` clustering as authoritative — it's a heuristic proposal; confirm with the user.

## Examples

```
/maos:session-fission                 # dry-run: inventory current session, propose N-Tree
/maos:session-fission --apply         # inventory + snapshot + emit seed scaffolds for confirmed clusters
/maos:session-fission ~/.claude/projects/<enc>/<uuid>.jsonl   # explicit transcript
```

---

*Part of multi-agent-os · session-fission v0.1.0 (MVP, non-destructive) · pairs with Cowork Process Topology Protocol*
