# work-compass — Capability Spec (lightweight, OpenSpec-style stub)

> Phase-1 as-built behavioral contract. Lightweight stub — NOT full SpecDD ceremony.
> Source of truth = `skills/work-compass/SKILL.md` + `bin/work-compass-aggregate.py`.

## Purpose

Aggregate the operator's cross-domain work items (Jira/GitHub issues, Claude + cross-vendor
Codex sessions, git worktrees/branches/stashes/uncommitted-WIP, open PRs, ~/.claude plans +
background jobs) into ONE deterministic, navigable N-Tree across the 7 CPT domains; detect
stale/orphan/pending items via transparent heuristics; and route a node to a SUGGESTED
command for an existing tool — read-only, review-before-submit.

## Requirements

### Requirement: Cross-domain aggregation by composition
The system SHALL aggregate work items by composing existing producers (inventory-sessions.py,
gh CLI, acli, native git) and SHALL NOT reimplement their logic.

#### Scenario: a provider is unavailable
- WHEN a provider CLI is absent or unauthenticated
- THEN its domain is marked "unavailable" in `meta.unavailable` AND aggregation continues
  (never blocks, never fabricates items).

#### Scenario: id namespacing
- WHEN items from multiple providers are normalized
- THEN every id is provider-namespaced (`jira:KEY`, `gh:owner/repo#n`, `session:<id>`,
  `worktree:<path>`, `branch:<name>`, `pr:<repo>#n`, and v1.1 `codex-session:<id>`,
  `job:<id>`, `plan:<file>`, `stash:<ref>`) so cross-provider collisions cannot occur.

### Requirement: Registry-driven collector extension
Collectors SHALL be registered in a single `COLLECTORS` list; adding a surface SHALL require
one registry entry (which auto-generates its `--no-<name>` skip flag) plus one
`collect_<provider>()` function — no other change.

#### Scenario: every collector disabled
- WHEN all `--no-<name>` flags are set
- THEN aggregation returns zero items and zero diagnostics, without error.

### Requirement: Deterministic rendering
The renderer SHALL produce identical output for identical input (CPT §9.5 consumer contract).

#### Scenario: same input twice
- WHEN the same work-item graph is rendered twice
- THEN the ASCII and mermaid outputs are byte-identical.

### Requirement: Transparent stale/orphan/pending detection
The system SHALL flag candidates via ≤10 transparent heuristics (branch-no-PR, PR-no-ticket,
ticket-no-session, >Nd-no-update, worktree-no-branch, session-orphan, and v1.1
worktree-dirty-wip, stash-forgotten, plan-orphan/plan-stale, job-orphan/job-stale) and SHALL
surface them as CANDIDATES, never auto-actioning.

#### Scenario: a linked, fresh item
- WHEN a branch has an open PR, a PR cites a ticket, and a session references the branch+ticket
- THEN none of branch-no-PR / PR-no-ticket / session-orphan are raised (no false positives).

#### Scenario: a fresh plan / job / stash / clean worktree
- WHEN a plan/job/stash was updated within the staleness window, or a worktree is CLEAN
- THEN none of plan-*/job-*/stash-forgotten/worktree-dirty-wip are raised (no false positives).

### Requirement: Extended local scanners — metadata-only, sovereign-safe
The v1.1 local scanners (plans, background jobs, git stashes, worktree WIP) and the Codex
cross-vendor scanner SHALL emit metadata only (path · title · status · mtime · counts) and
SHALL NEVER emit file contents. Any store-glob SHALL exclude the `~/openclaw/` sovereign tree.

#### Scenario: openclaw exclusion
- WHEN a scanned path resolves inside `~/openclaw/`
- THEN it is skipped (never read or enumerated).

#### Scenario: absent store
- WHEN a store dir (`~/.claude/plans`, `~/.claude/jobs`, `~/.codex/session_index.jsonl`) is absent
- THEN a diagnostic is appended and aggregation continues (never raises).

### Requirement: Read-only delegation routing
The router SHALL return a SUGGESTED command with `execute: false` and SHALL NEVER execute a
provider write, merge, push, or session pause/stop/delete.

#### Scenario: destructive action requested
- WHEN `--action pause|stop|delete` is passed
- THEN the output carries an explicit DESTRUCTIVE warning AND `execute` remains false (the
  operator must run the printed command).

### Requirement: Safety — no secrets in output
The system SHALL NOT emit secrets/PII (it composes a sanitizing producer for session data).

#### Scenario: JSON dump of real data
- WHEN the graph is emitted as JSON over real data
- THEN no secret-like token (API key, JWT, PAT, vault/secret-manager token) appears in the output.

## Validation

73 stdlib tests (`bin/tests/test_work_compass.py`) + a dogfood run on real data
(5288 items full-run / 176 local-only, 6/7 domains, deterministic, read-only verified,
0 secret-like hits). The ~37-surface landscape + coverage is catalogued in
`skills/work-compass/references/work-surface-taxonomy.md`.

## Deferred (out of scope this capability)

Cross-vendor beyond Codex (Cursor/Copilot/Gemini/Aider) · `--depth/--breadth/--height`
traversal modifiers · Linear/GitLab/ClickUp + Confluence/Drive + Slack/email + CI-pipelines/
deployments (+ 26 blind-spots in the taxonomy) · static HTML view · ML-suggested rules.
Registry-driven adapter-stub interface documented in SKILL.md; build-on-demand only (YAGNI).
