# session-fission — Specification (MVP v0.1.0)

> Status: MVP (non-destructive) · Author: Claude Opus 4.7 · Date: 2026-05-27
> Skill: `skills/session-fission/SKILL.md` · Command: `commands/session-fission.md` · Scripts: `plugin-scripts/session-fission/`
> Related: `docs/feature-request-session-api.md`, `docs/adrs/ADR-001-session-identity.md`, `docs/session-identifiers-research.md`

## 1. Problem

A single Claude Code session interleaves unrelated work (Task-A → Task-B → MCP-fix Task-B2 → boss's Task-C → skill-fix Task-D) into one linear transcript. The result: context bloat, cognitive overhead, token exhaustion, unfinished work, and backlog spillover. We want an **on-demand**, **non-destructive** way to split that tangle into clean, atomic-context sessions.

## 2. Feasibility (validated)

Validated against `code.claude.com/docs/en/sessions` + direct inspection of a live transcript on disk.

| Capability | Native | Note |
|---|---|---|
| Resume `--continue`/`--resume`/`--from-pr`/`/resume` | ✅ | picker groups forks under root |
| Whole-session fork (`/branch`, `--fork-session`) | ✅ | **copies** the whole conversation (new `.jsonl`, `forkedFrom.sessionId`) — not a topic split |
| `/rewind`, `/clear`, `/compact [instructions]`, `/context`, `/export` | ✅ | `/compact` is lossy; `/clear` total |
| Subagent context isolation (Task tool) | ✅ | separate window, returns summary |
| Surgical mid-message delete / topic-grouped split into N sessions | ❌ | transcript = append-only `parentUuid` DAG with paired `tool_use`/`tool_result`; middle-delete ⇒ unresumable |
| `CLAUDE_SESSION_ID` env var | ❌ | per `docs/feature-request-session-api.md`; use transcript-path UUID / statusline `session_id` |

**Conclusion:** the only safe mechanism is **non-destructive distill-and-reseed**. Native forking copies the bloat; surgical trimming corrupts. Fission distills each atomic context into a light seed and reseeds, preserving the original.

## 3. Option analysis

- **A (delete original after split):** partial — keep *archive*, reject *delete* (breaks rollback).
- **B (surgical in-place trim):** REJECTED — unsafe/unsupported (DAG + tool pairing).
- **C (snapshot→distill→reseed):** ✅ core algorithm — non-destructive, idempotent.
- **D (native `/branch` + scoped `/compact`):** ✅ cheaper reseed path where distillation isn't worth it (lossy).
- **E (reuse `ccpanes-fork-session` + `context-save`):** ✅ execution substrate — don't build a new spawner.

Chosen = C (algorithm) + E (execution) + D (where cheaper); archive-not-delete from A; never B.

## 4. Algorithm (6 steps)

1. **Inventory** (read-only): `inventory.sh` → JSON N-Tree of atomic-context clusters keyed by branch/cwd + time-gap.
2. **Classify**: tag relations (sequential `→` / recursive `↻` / independent `∥` / parallel `‖`); confirm with operator.
3. **Snapshot** (before any write): `snapshot.sh` → backup copy + manifest + gitleaks (rollback anchor).
4. **Distill** (agent cognition): per cluster, write a Ticket-as-Prompt seed carrying ONLY that atomic context; `seed.sh` emits the scaffold.
5. **Reseed**: hand each seed to a fresh focused session (Option E/D); archive original (never delete).
6. **Topology + briefing**: emit N-Tree (Mermaid + per-seed pointers) for CPT Compass navigation; end-of-action briefing.

## 5. Data shapes

- `inventory.sh` → `{status, schema, source, read_only, total_lines, cluster_count, gap_seconds, clusters[{id,label,branch,cwd,msg_count,has_sidechain,first_ts,last_ts}], relations[{from,to,rel}], note}`
- `snapshot.sh` → `{status, snapshot_path, manifest_path, source_sha256, gitleaks, sanitized_utc}` + `*.manifest.yaml`
- `seed.sh` → `{status, cluster_id, seed_path}` + a `<cluster_id>.md` Ticket-as-Prompt scaffold (17-field skeleton, agent-filled)

## 6. Safety contract

- Read-only on source transcript (all 3 scripts). Reseeds are additive. Out-of-scope sessions untouched.
- Snapshot precedes any archive op. Rollback = `/resume <original>` + retained backup.
- Idempotent: same input → same clustering; `snapshot.sh` skips duplicate SHA; seeds overwrite-safe.
- gitleaks scrub on snapshot before finalize.

## 7. Layer purity

This tool is generic (community layer). No operator-personal names; backup/seed dirs configurable via env (`SESSION_FISSION_SNAPSHOT_DIR`, `SESSION_FISSION_SEED_DIR`); defaults use `$HOME`/`./`. Vek-specific wiring (Jira/walkthrough/ASH-lite) lives in `vek-ai-toolkit`, not here.

## 8. Scope

**In (v0.1.0 MVP):** skill, command, `inventory.sh`, `snapshot.sh`, `seed.sh`, this spec. No destructive ops; reseed is operator-guided (Option D/E).

**Deferred:** v2 automated spawn + CPT `topology.md`/`INDEX.yaml` emission + rollback command; v3 sentinel anomaly rule + statusmap template + morning-briefing/auto-orchestrator deep wiring.

**Out:** in-place trimming (B); reliance on `CLAUDE_SESSION_ID`; long-term retention past the native 30-day `cleanupPeriodDays` (snapshots live outside that lifecycle).

## 9. Verification

1. `bash tests/validate-plugin.sh` passes.
2. Dry-run `inventory.sh` on a real session → review N-Tree; `shasum` source before/after identical (non-interference).
3. `snapshot.sh` → backup exists + gitleaks reported; `/resume <original>` recovers untouched original (rollback).
4. A reseeded session carries only its atomic context (context ≪ original) — bloat relief.
