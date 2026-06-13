# work-compass — Capability Spec (lightweight, OpenSpec-style stub)

> Phase-1 as-built behavioral contract. Lightweight stub — NOT full SpecDD ceremony.
> Source of truth = `skills/work-compass/SKILL.md` + `bin/work-compass-aggregate.py`.

## Purpose

Aggregate the operator's cross-domain work items (Jira/GitHub issues, Claude sessions, git
worktrees/branches, open PRs) into ONE deterministic, navigable N-Tree across the 7 CPT
domains; detect stale/orphan/pending items via transparent heuristics; and route a node to
a SUGGESTED command for an existing tool — read-only, review-before-submit.

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
  `worktree:<path>`, `branch:<name>`, `pr:<repo>#n`) so cross-provider collisions cannot occur.

### Requirement: Deterministic rendering
The renderer SHALL produce identical output for identical input (CPT §9.5 consumer contract).

#### Scenario: same input twice
- WHEN the same work-item graph is rendered twice
- THEN the ASCII and mermaid outputs are byte-identical.

### Requirement: Transparent stale/orphan/pending detection
The system SHALL flag candidates via ≤6 transparent heuristics (branch-no-PR, PR-no-ticket,
ticket-no-session, >Nd-no-update, worktree-no-branch, session-orphan) and SHALL surface them
as CANDIDATES, never auto-actioning.

#### Scenario: a linked, fresh item
- WHEN a branch has an open PR, a PR cites a ticket, and a session references the branch+ticket
- THEN none of branch-no-PR / PR-no-ticket / session-orphan are raised (no false positives).

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
- THEN no secret-like token (API key, JWT, PAT, 1Password token) appears in the output.

## Validation

34 stdlib tests (`bin/tests/test_work_compass.py`) + a dogfood run on real data
(4364 items, 5/7 domains, 0 secret-like hits).

## Deferred (out of scope this capability)

Static HTML view · drag-drop/admin panel · Linear/GitLab/ClickUp adapters · ML-suggested
rules. Adapter-stub interface documented in SKILL.md; build-on-demand only (YAGNI).
