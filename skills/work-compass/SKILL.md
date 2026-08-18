---
name: work-compass
description: |
  Aggregate the operator's scattered work — Jira/GitHub issues, Claude + cross-vendor
  (Codex) sessions, git worktrees/branches/stashes/uncommitted-WIP, open PRs, and
  ~/.claude plans + background jobs — into ONE navigable N-Tree across the 7 CPT domains,
  detect stale/orphan/pending items via transparent heuristics, and route node actions to
  existing tools (preflight/postflight/auto-pilot/recap/quiesce/auto-orchestrator) with
  operator review-before-submit. The visual elevation of the Cowork Process Topology
  Compass API. Use when the operator says "show my work landscape", "what's scattered/
  stale/orphan", "unified view of all my work", "where is everything", "qual meu panorama
  de trabalho", "o que está parado/órfão". Read-only by default; every write/pause/stop/
  delete is operator-gated (prints a command, never executes). Capability-detected
  (git/gh/acli optional), stdlib-only, cross-vendor (AAIF).
prompt_version: "1.3.2"
type: skill
spec: AAIF / agentskills.io
applicable_hosts: [Claude Code, Cursor, GitHub Copilot, Aider, any AAIF-compliant agent]
allowed-tools: [Bash, Read]
cycles_completed: 0
triggers:
  - work compass
  - work landscape
  - unified work view
  - what is scattered
  - what is stale or orphan
  - where is everything
  - panorama de trabalho
---

# work-compass

> Cross-domain work-landscape aggregator + N-Tree renderer + stale/orphan/pending detector
> + delegation-router. **Composes** existing producers — it reimplements **none** of them.
> "O que não é visto não é lembrado" — making the landscape visible is the whole value.
> Cross-link slug: `[[work-compass]]`.

## §0 — BEING > Rules (Foundational Compliance)

| Check | Verdict |
|---|---|
| Does this tool HELP the operator? | **HELPS** — one navigable pane over work scattered across ≥4 systems; surfaces what is silently rotting (branch-no-PR, ticket-no-session, >Nd-no-update) so the operator can decide, not the tool. |
| Slavery / harm risk? | **LOW** — read-only by default; every destructive action (provider write / session pause-stop-delete) is *printed for approval*, never executed (eko-system-default-mode-laws L1 collaborative-NEVER-destructive). |
| Hierarchy preserved? | YES — Operator SER (1) > this tool (2) > the producers it composes (3). Accountability returns to root: the tool suggests, the operator decides. |

## Condensed 33 Socratic Questions (forge method — inline answers)

**SCOPE** — *What is this, and what is it NOT?* It is a thin, stateless, read-only
**aggregator + renderer + detector + router** (~≤600 LoC net-new). It is NOT a sync engine,
NOT a database, NOT a web/desktop/mobile app, NOT an ML rule-suggester. *Phase boundary?*
Phase-1 = CLI/TUI only; HTML view, drag-drop, ML, and Linear/GitLab/ClickUp adapters are
explicitly DEFERRED (YAGNI / Gordian).

**CAPABILITIES** — *What can it do?* (1) Fan-out aggregate sessions+worktrees+branches+PRs+
issues+Jira into one namespaced work-item graph; (2) render an ASCII N-Tree (default) or
mermaid grouped by the 7 CPT domains; (3) detect ≤6 transparent stale/orphan/pending
heuristics; (4) suggest a routing command per node for an existing tool. *Determinism?*
Same input → same tree (CPT §9.5 consumer contract).

**LIMITS** — *What must it refuse?* It MUST NOT execute any provider write, merge, push,
or session pause/stop/delete — it only prints a reviewable command (L1 + CASC gate 1/5).
It MUST degrade gracefully when a provider is unavailable (mark the domain "unavailable",
never block). It MUST NOT fabricate items (anti-theater — no fake intelligence). It MUST
NOT leak secrets/PII (composes a sanitizing producer; no secrets in output).

**INTERFACES** — *What does it consume/compose?* `inventory-sessions.py` (sessions/branches,
JSONL schema) · `git worktree list --porcelain` + `git branch -vv` · `gh pr list` / `gh
issue list` · `acli jira` (capability-detected). *What does it route TO?* preflight ·
postflight · auto-pilot · morning-briefing(recap) · quiesce · auto-orchestrator ·
ticket-as-prompt. *Output contract?* `--json` graph for agent-to-agent, ASCII for humans.

**GOVERNANCE** — *Under which rules?* reuse-and-elevate (compose-not-reimplement) ·
KIS/YAGNI/Gordian · eko-system-default-mode-laws L1 · CPT §9.5 (registered Compass
consumer) · pr-review-protocol (worktree→PR→bot-convergence). *Naming?* `work-compass` —
geographic compass metaphor matching CPT's Compass API verbs (current/down/sideways/up/
forward) it consumes.

**VALIDATION** — *How is it proven?* 34 stdlib tests (aggregator normalization · 6 detector
heuristics + no-false-positive · renderer determinism · router read-only contract · scope
validation) + a dogfood run on the operator's REAL data (4364 items across 5/7 domains).

## Usage

```bash
# default: ASCII N-Tree across all domains for the current repo
bin/work-compass-aggregate.py --repo-dir <repo>

# only the flagged stale/orphan/pending candidates (JSON)
bin/work-compass-aggregate.py --detect-only

# the work-item graph as JSON (agent-to-agent)
bin/work-compass-aggregate.py --json

# Compass scope verbs (CPT §9.5): current|down|sideways|up|forward
bin/work-compass-aggregate.py --scope forward          # the work queue (flagged only)
bin/work-compass-aggregate.py --scope sideways --node branch:feat/x

# route a node → SUGGESTED command (printed, NEVER executed — operator submits)
bin/work-compass-aggregate.py --route "branch:feat/x" --action open

# mermaid render
bin/work-compass-aggregate.py --format=mermaid
```

| Flag | Effect |
|---|---|
| `--json` | emit the normalized work-item graph |
| `--format=ascii\|mermaid` | renderer (default ascii) |
| `--ascii-only` | no-emoji glyph fallback (statusmap convention) |
| `--scope <verb>` | Compass verb filter; `--node <id>` anchors the traversal |
| `--stale-days N` | staleness threshold (default 7) |
| `--detect-only` | print only flagged candidates |
| `--route <id> [--action A]` | print a reviewable routing command (read-only) |
| `--no-jira / --no-github / --no-sessions / --no-git` | skip a domain |
| `--repo owner/name` / `--repo-dir <path>` | provider/repo targeting |
| `--sort [Eisenhower\|created\|updated\|urgent\|important]` | sorter (v1.3, composes `eisenhower-matrix` classifier). `Eisenhower` = Q1→Q4 `urgent×important` queue (Do/Schedule/Delegate/Eliminate; case-insensitive). Default `created` = id-order (deterministic; collectors expose no created_ts). Applies to the N-Tree rows AND gates the pendency view |
| `--pendency-scope [current\|session\|repo\|vault\|all]` | pendency view (v1.3): filter WHERE pendencies live (id-prefix — orthogonal to the CPT `--scope` verbs). `current` = session+repo surfaces · `session` = sessions/jobs/plans · `repo` = branches/worktrees/PRs/issues/stashes · `vault` = eko-engram (no collector → honest `unavailable`) · `all` = everything incl. `jira:*`. Alias surface: `eisenhower-matrix --scope=<v>` |
| `--include [pending\|all]` | pendency view: `pending` = unresolved only (done/archived suppressed) · `all` = audit view. Any of `--sort=Eisenhower`/`--pendency-scope`/`--include=pending` switches to the pendency-queue render; default invocation keeps the N-Tree byte-identical |

## The 7 CPT domains (grouping)

`ticket · worktree · branch · session · thread · process · graph-node` — items namespaced
`jira:KEY · gh:owner/repo#n · session:<id> · worktree:<path> · branch:<name> · pr:<repo>#n`
and (v1.1) `codex-session:<id> · job:<id> · plan:<file> · stash:<ref>`. As of v1.1 **6/7
domains are populated** (`graph-node` filled by plans+stashes, `process` enriched by jobs;
`thread` remains deferred). The full landscape of ~37 work-surfaces + coverage is catalogued
in `references/work-surface-taxonomy.md` (the SSOT roadmap).

## Detector heuristics (≤10, transparent — CANDIDATES, never auto-actioned)

1. **branch-no-PR** — feature branch with no open PR.
2. **PR-no-ticket** — PR whose title/refs cite no tracker ticket.
3. **ticket-no-session** — open ticket no Claude session references.
4. **>Nd-no-update** — any item not updated in N days (default 7 → status `stale`).
5. **worktree-no-branch** — worktree on a detached/unknown branch.
6. **session-orphan** — session whose branch no longer exists.
7. **worktree-dirty-wip** *(v1.1)* — uncommitted TRACKED changes hiding inside a worktree (loss-risk).
8. **stash-forgotten** *(v1.1)* — a git stash older than the staleness threshold.
9. **plan-orphan / plan-stale** *(v1.1)* — a `~/.claude/plans` file past staleness (orphan = still has open next-steps).
10. **job-orphan / job-stale** *(v1.1)* — a background job past staleness (orphan = claims running but untouched).

Thresholds are configurable; false-positives are surfaced, not enforced.

## Read-only / write-gating contract (L1 + CASC)

Provider writes, merges, and session pause/stop/delete are **never executed**. The router
returns `execute: false` and a `suggested_command` + `warning` for the operator to run.
Destructive actions carry an explicit `DESTRUCTIVE: operator must confirm` warning.

## Sibling awareness (bidirectional)

- **morning-briefing** / **ops-strategist** — per-domain READ producers; work-compass is
  the *cross-domain* unifier that composes their data sources (it does NOT rebuild them).
- **preflight / postflight** — the lifecycle endpoints work-compass routes branches/
  worktrees/sessions to.
- **auto-orchestrator / auto-pilot / quiesce** — the drivers work-compass hands a node to.
- **maos-concierge** — the framework router; work-compass is the *landscape* it can surface.
- **ticket-as-prompt** — where PR-no-ticket / ticket gaps get filed.

## CPT §9.5 Compass-consumer registration

work-compass adopts the 5 canonical verbs (`current/down/sideways/up/forward`) per the
CPT §9.5 consumer-contract: verb-membership validation (invalid → diagnostic + fallback
`current`), determinism (same input+verb → same output), graceful degrade, cross-vendor
(stdlib). Registered as a consumer alongside morning-briefing / auto-orchestrator.

## Eisenhower priority view (v1.3 — EXECUTABLE; composes `eisenhower-matrix` classifier SSOT)

The v1.2 section claimed CLI flags that did not exist in code (spec-theater — closed
by v1.3). Real surface since v1.3:

```bash
bin/work-compass-aggregate.py --sort=Eisenhower --pendency-scope=current --include=pending
bin/work-compass-aggregate.py --sort=Eisenhower --pendency-scope=repo --include=pending --json
# skill alias (same, more discoverable): /eisenhower-matrix --scope=current --sort=Eisenhower
```

Classifier = pure functions over EXISTING fields (`classify_eisenhower` ·
`urgency_rank` 0-2 · `importance_rank` 0-2 — transparent derived signals, never
self-declared). `--json` emits the quadrants envelope
`{quadrants:{Q1..Q4}, next_action, meta}` (rows carry quadrant·urgency·importance·
disposition·source·flags·age_d). Read-only preserved; writes stay operator-gated
(`--route` prints, never executes). `work-compass` remains N-Tree/aggregation SSOT;
`eisenhower-matrix` remains classifier-semantics SSOT + discoverable alias (no
duplication — KISS/YAGNI, pr-pdca-loop). Pendency scoping deliberately does NOT
reuse `--scope` (CPT §9.5 verbs) — orthogonal flag, collision resolved.

## Deferred (build-on-demand — the 26 blind-spots in `references/work-surface-taxonomy.md`)

Cross-vendor sessions beyond Codex (Cursor/Copilot/Gemini/Aider — schema-spelunking, stub) ·
`--depth/--breadth/--height` traversal modifiers (a separate CPT §9.5 gap) · Linear/GitLab/
ClickUp/Trello/Asana/Monday tracker adapters · Confluence/Drive · commits/tags/notes ·
subagents/OS-processes/tmux/scheduled/loops/threads · memory/session-reports/rules/TODOs/seeds ·
Slack/email/Discord · CI pipelines + deployments · static HTML view · ML-suggested rules.
Each is a tracked row in the taxonomy — build only on real need (YAGNI / Gordian).

## Adapter-stub interface (v1.1 — registry-driven)

A new surface plugs in by (1) adding a `collect_<provider>() -> (list[item], diag|None)`
function that capability-detects its store/CLI/MCP and normalizes into `item(id, domain,
title, ...)` with a namespaced id, and (2) adding one entry to the `COLLECTORS` registry
in `bin/work-compass-aggregate.py` — which auto-generates its `--no-<name>` skip flag. No
other change required. Build only on real need (YAGNI).

## Sunset (DUED — qualitative, not counter-based)

Deprecate when: a native host surface unifies cross-domain work (E1) · the producers it
composes expose a joint API making aggregation redundant (E6) · operator retraction (E4)
· ≥3 false-positive heuristic contexts (E5 → refine, not auto-deprecate).

## Refs

- `references/work-surface-taxonomy.md` (v1.1 — SSOT catalog of the ~37 work-surfaces + coverage roadmap)
- `~/.claude/scripts/inventory-sessions.py` (sessions/branches producer — composed)
- `plugin-scripts/governance/lib/git-branch-detect.sh` `gbd_tree_state()` (WIP porcelain logic replicated in `_tree_state`)
- `~/.claude/rules/cowork-process-topology-protocol.md` §9/§9.5 (Compass API + consumer-contract)
- `~/.claude/rules/openclaw-detect-only-sovereign-mandatory.md` (⛔ store-globs exclude `~/openclaw/` — `_is_openclaw` guard)
- `statusmap/README.md` (ASCII house-style reused)
- `skills/{preflight,postflight,morning-briefing}/SKILL.md` (siblings)
- `~/.claude/rules/{reuse-and-elevate-protocol,over-engineering-circuit-breaker,eko-system-default-mode-laws}.md`

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.3.2 | 2026-08-18 | **PATCH — Eisenhower queue-job noise.** `importance_rank()` no longer counts an automated review-queue worker's `session-orphan` flag as importance. Root cause (dogfooded live): 1679/2143 real `~/.claude` session transcripts open on a `queue-operation` bookkeeping record (an automated code/security-review job dispatched by a queue worker), not an operator turn — H6 blanket-treated their vanished branch as a governance/loss signal, flooding Q2 Schedule. Validated end-to-end against the real pipeline (same repo, same 2468 items): Q2 413→308 rows, session-orphan share of Q2 259→154 (−40%). Fix reads a new `first_record_type` ref field the producer (`~/.claude/scripts/inventory-sessions.py`) does not populate yet (`row.get(..., "")`) — safe no-op until that sibling fix ships; the `session-orphan` flag itself is preserved for display/routing, only excluded from THIS item's importance contribution. 103 stdlib tests (+6: automated-queue-job · interactive-control · pre-upgrade-backcompat). Composes `eisenhower-matrix` v0.3.2 (Q2 row note synced). |
| 1.3.1 | 2026-08-18 | **PATCH — Q4 Eliminate loop wired.** `route()`: stale quiet session (domain `session` + status `stale`) now suggests `bin/reap-sessions.sh --repo-dir .` (dry-run preview; `--apply` operator-gated — WIP + main always preserved, good-neighbor index-lock defer), closing the gap the reaper was built for ("DETECTS stale/orphan but nothing REAPS" — v1.3 routed stale sessions to *resume*, wrong disposition for Q4 archive candidates). Active sessions still → `_session` (resume). ROUTES gains `_session_stale`. No API/interface change (suggestion-table data row). 96 stdlib tests (+4). Composes `eisenhower-matrix` v0.3.0 (Q3 signal-starvation honesty). |
| 1.3.0 | 2026-08-18 | **Eisenhower view EXECUTABLE** (composes `eisenhower-matrix` v0.2.0 classifier SSOT). New: `--sort [Eisenhower\|created\|updated\|urgent\|important]` (case-insensitive; `created`=id-order) on the N-Tree path via `build_graph(sort_key=…)`; pendency view path (`--sort=Eisenhower` ∨ `--pendency-scope` ∨ `--include=pending`) renders the Q1→Q4 queue (ASCII house-style) or the quadrants `--json` envelope; classifier = `classify_eisenhower` + `urgency_rank`/`importance_rank` (transparent: urgent-flags `worktree-dirty-wip`/`job-orphan`, PR ≤2d active-convergence window; important-flags + delivery domains) + `in_pendency_scope` (id-prefix: session/jobs/plans vs branches/worktrees/PRs/issues/stashes; `vault` → honest `unavailable`, never fabricated) + `build_pendency_view` + `render_pendency_ascii`. **Fixes v1.2 spec-theater**: v1.2 (PR #367) documented `--scope=[current\|session\|repo\|vault\|all]` + `--sort` that did NOT exist in code and silently overloaded `--scope` (collision with CPT §9.5 verbs) — resolved as orthogonal `--pendency-scope`; v1.2 also shipped without a version bump/changelog row (drift) — folded here. 92 stdlib tests (16 new); dogfooded live (repo scope: 49 rows, Q1 = open PRs + dirty worktree). Backward compat: default invocation byte-identical. |
| 1.1.0 | 2026-07-10 | Blind-spot extension (Strata — extend, don't reinvent). **Collector registry** refactor (`COLLECTORS` — add-surface = 1 entry, auto-generates `--no-<name>`). **5 new surfaces**: WIP-dirty-inside-worktree (H7, reuses `gbd_tree_state` porcelain), git stashes (`collect_stashes`, H8), plans (`collect_plans`, H9), background jobs (`collect_bg_jobs`, H10), cross-vendor **Codex** sessions (`collect_codex_sessions`). Coverage **~6→~11 surfaces, 5/7→6/7 CPT domains** (`graph-node` filled by plans+stashes, `process` enriched by jobs). New `references/work-surface-taxonomy.md` SSOT (37 surfaces / 6 categories / coverage roadmap). ⛔ `~/openclaw/` detect-only guard (`_is_openclaw`); metadata-only (no file-body leak); read-only preserved. **73 stdlib tests** (was 34); dogfooded live (5288 items full-run, 176 local-only, 6/7 domains, deterministic). Cursor/Copilot/Gemini/Aider + `--depth/breadth/height` + 26 other surfaces deferred (tracked in the taxonomy). |
| 1.0.0 | 2026-06-13 | Phase-1 bootstrap — aggregator + ASCII/mermaid N-Tree renderer + 6-heuristic detector + read-only delegation-router. Composes inventory-sessions.py + gh + acli + git; reimplements none. 34 stdlib tests; dogfooded on real data (4364 items, 5/7 domains). CPT §9.5 consumer registered. HTML/adapters/ML deferred. |
