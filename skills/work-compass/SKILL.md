---
name: work-compass
description: |
  Aggregate the operator's scattered work — Jira/GitHub issues, Claude sessions, git
  worktrees/branches, and open PRs — into ONE navigable N-Tree across the 7 CPT domains,
  detect stale/orphan/pending items via transparent heuristics, and route node actions to
  existing tools (preflight/postflight/auto-pilot/recap/quiesce/auto-orchestrator) with
  operator review-before-submit. The visual elevation of the Cowork Process Topology
  Compass API. Use when the operator says "show my work landscape", "what's scattered/
  stale/orphan", "unified view of all my work", "where is everything", "qual meu panorama
  de trabalho", "o que está parado/órfão". Read-only by default; every write/pause/stop/
  delete is operator-gated (prints a command, never executes). Capability-detected
  (git/gh/acli optional), stdlib-only, cross-vendor (AAIF).
prompt_version: "1.0.0"
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

## The 7 CPT domains (grouping)

`ticket · worktree · branch · session · thread · process · graph-node` — items namespaced
`jira:KEY · gh:owner/repo#n · session:<id> · worktree:<path> · branch:<name> · pr:<repo>#n`.

## Detector heuristics (≤6, transparent — CANDIDATES, never auto-actioned)

1. **branch-no-PR** — feature branch with no open PR.
2. **PR-no-ticket** — PR whose title/refs cite no tracker ticket.
3. **ticket-no-session** — open ticket no Claude session references.
4. **>Nd-no-update** — any item not updated in N days (default 7 → status `stale`).
5. **worktree-no-branch** — worktree on a detached/unknown branch.
6. **session-orphan** — session whose branch no longer exists.

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

## Deferred (Phase-2/3 — gated on ≥2 dogfood cycles)

Static HTML view (reuse maos-concierge `dashboard.html` zero-dep pattern) · drag-drop +
admin panel · Linear/GitLab/ClickUp/Trello/Asana/Monday adapters (stub interface only,
capability-detected, build-on-demand) · ML-suggested rules/automations.

## Adapter-stub interface (documented, NOT built)

A new provider plugs in by adding a `collect_<provider>() -> (list[item], diag|None)`
function that capability-detects its CLI/MCP and normalizes into `item(id, domain, title,
...)` with a namespaced id. No other change required. Build only on real need (YAGNI).

## Sunset (DUED — qualitative, not counter-based)

Deprecate when: a native host surface unifies cross-domain work (E1) · the producers it
composes expose a joint API making aggregation redundant (E6) · operator retraction (E4)
· ≥3 false-positive heuristic contexts (E5 → refine, not auto-deprecate).

## Refs

- `~/.claude/scripts/inventory-sessions.py` (sessions/branches producer — composed)
- `~/.claude/rules/cowork-process-topology-protocol.md` §9/§9.5 (Compass API + consumer-contract)
- `statusmap/README.md` (ASCII house-style reused)
- `skills/{preflight,postflight,morning-briefing}/SKILL.md` (siblings)
- `~/.claude/rules/{reuse-and-elevate-protocol,over-engineering-circuit-breaker,eko-system-default-mode-laws}.md`

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-06-13 | Phase-1 bootstrap — aggregator + ASCII/mermaid N-Tree renderer + 6-heuristic detector + read-only delegation-router. Composes inventory-sessions.py + gh + acli + git; reimplements none. 34 stdlib tests; dogfooded on real data (4364 items, 5/7 domains). CPT §9.5 consumer registered. HTML/adapters/ML deferred. |
