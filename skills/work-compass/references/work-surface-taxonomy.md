---
name: work-surface-taxonomy
description: SSOT catalog of the ~37 non-theater work-surface types (identifiers that carry knowledge/instruction/task/decision) across 6 categories, each tagged EXEC/STALE + current work-compass coverage — the blind-spot roadmap
version: 1.0.0
---

# Work-Surface Taxonomy (SSOT)

> **Version**: 1.0.0 (2026-07-10)
> **Scope**: AAIF cross-vendor. The single source of truth for *what kinds of surface can hold running or stale work*.
> **Consumer**: `skills/work-compass` — the aggregator scans a subset of these surfaces and detects stale/orphan/pending items; this catalog defines the full landscape + which surfaces are covered vs. blind-spots. Feeds the CPT §9.5 Compass-consumer contract.
> **Parent SSOT**: `~/.claude/rules/cowork-process-topology-protocol.md` §9/§9.5 (the topology + Compass API this taxonomy is downstream of). External, user-scope — reference only.
> **Cross-link slug**: `work-surface-taxonomy`

## Purpose

A "work-surface" is any identifier that **carries knowledge / instruction / task / decision** and **feeds into work** — work already done, being done, or to be done. Each surface has two orthogonal state potentials:

- 🔄 **EXEC** — it can be *actively executing right now* (a running process/session/pipeline).
- 💤 **STALE** — it can *silently rot* (abandoned, orphaned, forgotten, past its freshness).

> Repo master principle (from work-compass): *"O que não é visto não é lembrado"* — what is not surfaced is not remembered, by humans **and** amnesic agents. This catalog exists so a fresh agent never re-derives the landscape, and so every blind-spot is a tracked, closeable gap rather than an invisible one.

The catalog is **reconstructed faithfully from the operator's OODA enumeration** (the operator's list is the source of truth) and **grounded against the on-disk stores confirmed by live recon** (79 plans · 81 background jobs · Codex `session_index.jsonl` · git worktrees/stashes). It is **non-theater**: every row is a surface that genuinely holds work-carrying content, not a decorative category.

**Coverage legend** (work-compass, as of v1.1.0):
- ✅ **covered** — scanned by a `collect_*` collector since v1.0.
- 🆕 **added-v1.1** — new collector this upgrade.
- ⬜ **blind-spot** — real surface, not yet scanned (deferred; YAGNI/Gordian — build on demand).

## Layer purity

This taxonomy is **provider-neutral**: it names *kinds of surface*, never a specific vendor/org/tracker as the surface itself. Vendors appear only as *examples* of a kind (e.g. "Jira / Linear" exemplify the *external-tracker* kind). A `work-compass` collector may target one concrete provider (capability-detected), but the taxonomy row is the neutral kind.

## Category 1 — Trackers (external work-tracking systems)

| # | Surface | Carries | 🔄/💤 | work-compass |
|---|---|---|---|---|
| 1 | Issue tracker — Jira workitem | task · acceptance · decision | 🔄💤 | ✅ covered (`collect_jira`, acli) |
| 2 | Issue tracker — Linear issue | task · acceptance | 🔄💤 | ⬜ blind-spot (adapter stub) |
| 3 | Issue tracker — GitHub Issue | task · discussion | 🔄💤 | ✅ covered (`collect_github`) |
| 4 | Issue tracker — Bitbucket issue | task | 🔄💤 | ⬜ blind-spot |
| 5 | Knowledge page — Confluence page | decision · spec | 💤 | ⬜ blind-spot |
| 6 | Doc surface — Google Drive doc | decision · spec | 💤 | ⬜ blind-spot |
| 7 | Board card — Trello / Asana / Monday | task | 🔄💤 | ⬜ blind-spot |

## Category 2 — Git / VCS artifacts

| # | Surface | Carries | 🔄/💤 | work-compass |
|---|---|---|---|---|
| 8 | Branch | in-flight change-set | 🔄💤 | ✅ covered (`git branch -vv`) |
| 9 | Worktree | isolated workspace | 🔄💤 | ✅ covered (`git worktree list`) |
| 10 | Pull Request | change + review + decision | 🔄💤 | ✅ covered (`gh pr list`) |
| 11 | Commit (local, unpushed) | done work not yet shared | 💤 | ⬜ blind-spot |
| 12 | **Uncommitted WIP inside a worktree** | in-progress edits (loss-risk) | 🔄💤 | 🆕 added-v1.1 (`_tree_state` porcelain → H7) |
| 13 | **Git stash** | forgotten shelved WIP | 💤 | 🆕 added-v1.1 (`collect_stashes` → H8) |
| 14 | Tag / release | published milestone | 💤 | ⬜ blind-spot |
| 15 | Git note | out-of-band annotation | 💤 | ⬜ blind-spot |

## Category 3 — Agentic session / process (running or resumable)

| # | Surface | Carries | 🔄/💤 | work-compass |
|---|---|---|---|---|
| 16 | Claude Code session | goal · transcript · decisions | 🔄💤 | ✅ covered (`inventory-sessions.py`) |
| 17 | **Cross-vendor session** (Codex/Cursor/Copilot/Gemini/Aider) | goal · transcript | 🔄💤 | 🆕 added-v1.1 (**Codex** via `session_index.jsonl`; others ⬜ stub) |
| 18 | Subagent (spawned Task/Agent) | delegated task + result | 🔄 | ⬜ blind-spot |
| 19 | **Background job** (`~/.claude/jobs/`) | detached long-running task | 🔄💤 | 🆕 added-v1.1 (`collect_bg_jobs` → H10) |
| 20 | OS process (long-running) | live execution | 🔄 | ⬜ blind-spot |
| 21 | tmux / screen session | live shell context | 🔄💤 | ⬜ blind-spot |
| 22 | Scheduled task (cron / ScheduleWakeup) | deferred future work | 🔄💤 | ⬜ blind-spot |
| 23 | Loop (Ralph / goal / quiesce loop) | iterated driver | 🔄 | ⬜ blind-spot |
| 24 | Thread (cross-session slug) | continuity across sessions | 🔄💤 | ⬜ blind-spot (CPT `thread` domain — deferred) |
| 25 | CPT topology node (process graph) | orchestration position | 🔄💤 | ⬜ blind-spot (CPT `graph-node` topology events) |

## Category 4 — Agentic persistence (durable knowledge/instruction on disk)

| # | Surface | Carries | 🔄/💤 | work-compass |
|---|---|---|---|---|
| 26 | **Plan** (`~/.claude/plans/*.md`) | roadmap · next-steps · decisions | 💤 | 🆕 added-v1.1 (`collect_plans` → H9) |
| 27 | Memory file (`projects/*/memory` + MEMORY.md) | durable lesson/fact | 💤 | ⬜ blind-spot |
| 28 | Session report (`.claude/sessions/`) | handoff record | 💤 | ⬜ blind-spot |
| 29 | Rule (auto-loaded governance) | binding instruction | 💤 | ⬜ blind-spot (see `corpus-firing-audit`) |
| 30 | TODO / TaskList item | pending step | 🔄💤 | ⬜ blind-spot |
| 31 | Continuation seed / handoff file | resume instruction | 💤 | ⬜ blind-spot |
| 32 | CPT session journal (JSONL events) | FIFO event log | 🔄💤 | ⬜ blind-spot |

## Category 5 — Omnichannel (inbound work carrying instruction/decision)

| # | Surface | Carries | 🔄/💤 | work-compass |
|---|---|---|---|---|
| 33 | Chat message/thread — Slack | request · decision | 🔄💤 | ⬜ blind-spot |
| 34 | Email — Gmail / Outlook | request · decision | 💤 | ⬜ blind-spot |
| 35 | Chat — Discord / other | request | 🔄💤 | ⬜ blind-spot |

## Category 6 — CI/CD

| # | Surface | Carries | 🔄/💤 | work-compass |
|---|---|---|---|---|
| 36 | Pipeline / workflow run (GH Actions / Bitbucket Pipelines) | build+test verdict | 🔄💤 | ⬜ blind-spot |
| 37 | Deployment + canary monitor | live release state | 🔄💤 | ⬜ blind-spot |

## Coverage summary (v1.1.0)

- **Covered (✅ + 🆕): 11 / 37** surfaces — Jira · GitHub Issues · PRs · branches · worktrees · Claude sessions (v1.0) + WIP-dirty · stashes · Codex sessions · background jobs · plans (v1.1).
- **CPT domains live: 6 / 7** — `ticket · branch · session · process · graph-node · worktree` populated; `thread` deferred.
- **Blind-spots: 26 / 37** — tracked here as a roadmap; each is buildable on real demand via the `collect_<provider>()` adapter-stub interface (SKILL.md §"Adapter-stub interface"). Build-on-demand (YAGNI / Gordian) — the catalog makes the gap *visible*, not mandatory to fill.

## Refs

- `skills/work-compass/SKILL.md` (consumer — the aggregator + detector)
- `~/.claude/rules/cowork-process-topology-protocol.md` §9/§9.5 (parent topology SSOT + Compass API)
- `skills/preflight/references/session-type-taxonomy.md` (sibling taxonomy — session *types*, this one = work *surfaces*)
- Cross-link slug: `work-surface-taxonomy`

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-07-10 | Bootstrap — 37 non-theater work-surface types across 6 categories (trackers · git/VCS · agentic session/process · agentic persistence · omnichannel · CI/CD), each tagged 🔄EXEC/💤STALE + work-compass coverage (✅ v1.0 · 🆕 v1.1 · ⬜ blind-spot). Reconstructed from the operator's OODA enumeration; grounded against confirmed on-disk stores. Coverage: 11/37 surfaces, 6/7 CPT domains. Provider-neutral (layer-pure). Consumer: work-compass; parent: CPT §9.5. |
