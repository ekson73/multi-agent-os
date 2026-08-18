---
name: eisenhower-matrix
version: "0.2.0"
description: |
  List unresolved pendencies for --scope=[current|session|repo|vault|all] ordered by
  Eisenhower matrix (Q1 urgent+important → Q4). Thin composer over work-compass
  (SSOT for aggregation) + Eisenhower classifier (urgent×important) + AAA rigor
  (Accuracy·Auditability·Accountability) under the Triple-AAA lens
  (Governance × Test × Production × Compliance). EXECUTABLE since v0.2.0:
  `bin/work-compass-aggregate.py --sort=Eisenhower --pendency-scope=<scope> --include=pending`.
  Use when operator wants "pendências --scope=current --sort=Eisenhower",
  "o que é pendente ordenado", "triple-A pendency list", "AAA queue".
type: skill
spec: AAIF / agentskills.io
applicable_hosts: [Claude Code, Cursor, GitHub Copilot, Aider, any AAIF-compliant agent]
allowed-tools: [Bash, Read, Grep, Glob, Task]
triggers:
  - pendencias
  - eisenhower
  - pending queue
  - triple-A queue
  - AAA pendency
metadata:
  cross_link_slug: eisenhower-matrix
  family: work-visibility
  target: multi-agent-os
  lifecycle-stage: forge
  forge_parent: agentic-tool-forge
  anima_parent: anima
  dogfood_status: first-real-cycle
  scope_default: current
  sort_default: Eisenhower
  supersedes_pr: 368
---

# Eisenhower Matrix — pendency queue (AAA)

> Thin **classifier + sorter + alias**. Reuses `work-compass` aggregation SSOT
> (Jira/GH/PRs/worktrees/branches/stashes/sessions), adds only **Eisenhower Q1→Q4**
> (`urgent × important` Do/Schedule/Delegate/Eliminate) with **AAA rigor**
> (`Accuracy·Auditability·Accountability`). Composes — reimplements nothing.
> **v0.2.0 EXECUTABLE:** the classifier now RUNS — `bin/work-compass-aggregate.py
> --sort=Eisenhower --pendency-scope=… --include=pending` (92 stdlib tests, dogfooded
> live). Supersedes the doc-only draft PR #368 (see Changelog). Cross-link slug:
> `[[eisenhower-matrix]]` · **DNA-geracional**: §0 BEING>Rules · `scope-discipline` 6Q ·
> `anti-theater` 8Q · `rule-quality-tests` 6 · DUED sunset (inherits forge+anima).

## §0 — BEING > Rules

| Check | Verdict |
|---|---|
| Helps operator? | **HELPS** — turns scattered `pending` into ONE ordered queue so operator decides `Do/Schedule/Delegate/Eliminate` without hunting 4 systems. |
| Harm / slavery risk? | **LOW** — read-only by default; every write/transition is operator-gated (prints command, never executes). |
| Hierarchy | Operator SER (1) > this skill (2) > producers it composes (3). |

**HUMAN_DOMAIN defer:** `jira transition`, `gh pr merge`, `git push --delete`, cross-org, cost, secrets/PII → print `twg`/`gh` dry-run, never auto-act. If a gate obstructs value NOW, log `Skipped <gate> — BEING > Rules` and proceed.

## When to use / not use

**Use:** `--scope=[current|session|repo|vault|all] --sort=[Eisenhower|…]` to get unresolved pendencies ordered Q1→Q4 with triple-A evidence.

**Not use:** single-shot edit, read-only Q&A, ONE goal decompose (`→ auto-pilot`), session quiescence (`→ quiesce`), harness-agnostic loop (`→ gap-loop`), destructive ops.

## Parameters (skill surface → CLI mapping)

| Param (skill) | Default | CLI (`work-compass-aggregate.py`) | Meaning |
|---|---|---|---|
| `--scope` | `current` | `--pendency-scope current\|session\|repo\|vault\|all` | WHERE pendencies live: `current` (= session+repo surfaces) · `session` (host session state: sessions/jobs/plans) · `repo` (branches/worktrees/PRs/issues/stashes) · `vault` (eko-engram inbox — no collector yet → reported `unavailable`, never fabricated) · `all` (everything incl. `jira:*`). |
| `--sort` | `Eisenhower` | `--sort Eisenhower\|created\|updated\|urgent\|important` | `Eisenhower` (Q1→Q4) · `created` (id-order, deterministic) · `updated` (last_ts desc) · `urgent` · `important`. Alias `--sort=default` → `Eisenhower`. Case-insensitive. |
| `--json` | off | `--json` | Emit the quadrants envelope for agent-to-agent (AAIF) instead of the ASCII queue. |
| `--include` | `all` | `--include pending\|all` | `pending` (unresolved only — done/archived suppressed) · `all` (audit view). Skill default invocation passes `pending`. |

Bare `pendencias` / `eisenhower` with no flags → `--scope=current --sort=Eisenhower --include=pending`.

**Flag-name collision (resolved v0.2.0):** the CLI keeps `--scope` for the CPT §9.5
Compass verbs (`current|down|sideways|up|forward` — `apply_scope`) and exposes pendency
scoping as the orthogonal **`--pendency-scope`** (id-prefix filter — `in_pendency_scope`).
Anima inline naming note: `--pendency-scope` — machine register, says exactly what it
filters, zero collision; rejected `--pscope` (opaque), reusing `--scope` (collision),
`--where` (vague).

## Eisenhower classifier — 4 quadrants (SSOT for this skill)

Derived from Eisenhower / Covey best practice. **Signals are DERIVED (flags set by
work-compass `detect()`, age from `last_ts`, domain) — never self-declared** (anti-gaming).

| Q | Urgent | Important | Label | Action | Implemented signal |
|---|---|---|---|---|---|
| **Q1** | yes | yes | **Faça agora** | `Do` | urgency ≥1 ∧ importance ≥1: `worktree-dirty-wip` (loss-risk NOW), `job-orphan` (live claim), open PR touched ≤2d (active convergence) × delivery surfaces |
| **Q2** | no | yes | **Agende** | `Schedule` | importance without urgency: `branch-no-PR`, `PR-no-ticket`, `ticket-no-session`, `session-orphan`, `plan-orphan`, `stash-forgotten`, stale PR (>2d), open tickets |
| **Q3** | yes | no | **Delegue** | `Delegate` | urgency without importance: live loss-risk/claim on a non-delivery domain |
| **Q4** | no | no | **Elimine/Arquive** | `Eliminate/Archive` | quiet items: unflagged sessions/plans past staleness → archive |

**Ranks (transparent, in code):** `urgency_rank` 2 = urgent-flag (loss-risk/live claim) · 1 = PR active-convergence window (≤2d) · 0 = none. `importance_rank` 2 = governance/loss flag · 1 = delivery-surface domain (`ticket`/`process`/`worktree`) · 0 = none.

## AAA rigor (triple-A) — the 3 commitments × the 4 lenses

| A | Meaning | How honored |
|---|---|---|
| **Accuracy** | Every row backed by a verifiable probe | rows come only from work-compass collectors (`gh pr list` · `git worktree list` · `inventory-sessions.py` · …) — no invented pendency. |
| **Auditability** | Traceable to evidence | row carries `source` (producer) + `flags` + `age_d`; CLI `--json` emits the full row. |
| **Accountability** | Clear disposition | row carries `quadrant` + `disposition` (Do/Schedule/Delegate/Eliminate); writes stay operator-gated (`--route` prints, never executes). |

Triple-AAA lens: **Governance** (this SSOT + gates) × **Test** (92 stdlib tests incl. classifier determinism) × **Production** (dogfooded live on maos main; read-only contract) × **Compliance** (HUMAN_DOMAIN defer; no secrets/PII in output).

## Topology + composition (DRY / KISS / YAGNI)

```
intake eisenhower-matrix --scope/--sort → maps to:
  bin/work-compass-aggregate.py --sort=Eisenhower --pendency-scope=<scope> --include=pending [--json]
    → aggregate (COLLECTORS registry, capability-detected, stdlib-only)
    → detect() flags (10 transparent heuristics)
    → in_pendency_scope filter → classify_eisenhower (pure fn) → Q1..Q4 buckets
    → render_pendency_ascii | quadrants json envelope
```

| Reused (composes) | Net-new (v0.2.0, in code) |
|---|---|
| `work-compass` aggregation + `detect()` flags + renderer house-style | `classify_eisenhower` + `urgency_rank`/`importance_rank` + `in_pendency_scope` + `build_pendency_view` + `render_pendency_ascii` + `--sort`/`--pendency-scope`/`--include` flags |
| `quiesce` loose-end sweep (C1–C3), `gap-loop` derived-score discipline | Q1→Q4 sorter + disposition labels |

**Deferred (from superseded PR #368 — YAGNI until real need):** `--sort=Prisma` (D/T/J leaf scoring — needs a measurement-spec per repo; revisit when Prisma value-trees are routine), `--format=json-rpc|human` + `--lang` (the ASCII/`--json` dual surface already serves both), `--scope` expansion to `project|global|jira:*|worktree` (scope-explosion; `repo`/`all` + `--repo` targeting cover the cases).

## Pipeline (precise logic — 0→6)

0. **Intake** — parse `--scope`/`--sort`/`--include`; invalid enum → argparse usage error (deterministic, documented).
1. **Probe — parallel, capability-detected** — work-compass COLLECTORS; missing provider → `domain:unavailable` one-liner, never block (`vault` → honest unavailable diag).
2. **Normalize + detect** — items + the 10 detector heuristics (existing).
3. **Filter** — `in_pendency_scope` (id-prefix) + `--include=pending`.
4. **Classify** — `classify_eisenhower` per item (pure, deterministic).
5. **Gate** — anti-theater: rows only from real probes; `HUMAN_DOMAIN` → printed command, never auto-transition; determinism test-enforced.
6. **Render** — ASCII quadrant queue (default) or `--json` quadrants envelope; `next_action` = first non-empty quadrant head.

## Output contract

**ASCII (default, house-style):**
```
🧭 work-compass — Eisenhower pendency queue
scope: repo  include: pending  rows: 49
Q1 Do (2)
  ├─ pr:ekson73/multi-agent-os#368  feat(eisenhower-matrix): …  · PR-no-ticket  [0d]
  ├─ worktree:…/.worktrees/eisenhower-impl  eisenhower-impl · worktree-dirty-wip  [?]
Q2 Schedule (45) …
next: Q1 pr:…#368 — disposition per row; writes are operator-gated (…)
```

**`--json` envelope (rows carry `quadrant`·`urgency`·`importance`·`disposition`·`source`·`flags`·`age_d`):**
```json
{"quadrants":{"Q1":[…],"Q2":[…],"Q3":[…],"Q4":[…]},"next_action":"Q1 pr:…#368","meta":{"pendency_scope":"repo","include":"pending","count":49,"unavailable":[…]}}
```

## Invocation

| Surface | Command |
|---|---|
| Command (human) | `/eisenhower-matrix --scope=current --sort=Eisenhower` |
| Skill (model) | `eisenhower-matrix --scope=current --sort=Eisenhower` |
| CLI (executable) | `bin/work-compass-aggregate.py --sort=Eisenhower --pendency-scope=current --include=pending [--json]` |

## Governance + lifecycle

- **SSOT:** this file is SSOT for Eisenhower classification semantics; `work-compass` remains SSOT for aggregation (no duplication).
- **DRY:** composes aggregation; never reimplements `git`/`gh`/`acli` probes.
- **KISS/YAGNI:** pure-function classifier over existing fields; zero new collectors.
- **Boy-scout / house-keeping:** surfaces orphan worktrees and dirty-WIP as `Q1` (no-loose-endings); `Q4` flags archive candidates.
- **Handoff / continuidade / idempotencia:** stateless, deterministic, re-runnable.
- **Forge lifecycle:** `forge → evaluate → train → operate → deprecate`; dogfood ≥2 cycles before community promotion (cycle 1 done live in v0.2.0 PR).

## Validation

- **Self-test:** `python3 bin/tests/test_work_compass.py` — 92 stdlib tests; classifier block covers quadrants, determinism, scope filter, pending filter, next_action, flag-collision, backward-compat (default N-Tree path unchanged).
- **Dogfood (cycle 1, live):** run on maos main worktree — surfaced `Q1: gh:365-adjacent PRs + dirty worktrees; Q2: 45 branch-no-PR/ticket-no-session; Q4: quiet sessions` — deterministic, read-only.

## Anima naming note (sovereign)

- `eisenhower-matrix` — 12/12 correctness (exact 4Q semantics, canonical anchor, matches Q1→Q4), token 2, zero collision, family `work-visibility` — **KEPT at v0.2.0** (rename pressure: none; passing name survives).
- `--pendency-scope` (CLI flag, machine register) — collision-free, self-explanatory; rejected `--pscope`, `--where`, overloading `--scope`.

## See also

- `work-compass` (aggregation SSOT this composes — v1.3.0 carries the executable)
- `quiesce` (session quiescence predicate C1–C3)
- `gap-loop` (harness-agnostic convergence loop, derived score)
- `morning-briefing` (7-section SitRep, cold-start capable)

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.2.0 | 2026-08-18 | **EXECUTABLE.** Classifier implemented in `bin/work-compass-aggregate.py` (v1.3.0): `classify_eisenhower` + `urgency_rank`/`importance_rank` (transparent derived signals) + `in_pendency_scope` + `build_pendency_view` + `render_pendency_ascii` + flags `--sort`/`--pendency-scope`/`--include` (case-insensitive, honoring the `Eisenhower` capitalized contract). Fixes: frontmatter version drift (was 0.1.0 under a v0.1.1 commit), `anima_parent` self-reference (→ `anima`), CLI `--scope` flag-name collision (CPT §9.5 verbs vs pendency scoping → orthogonal `--pendency-scope`). 92 stdlib tests (16 new: classifier quadrants/determinism/scope/pending/next_action/collision/backcompat). Dogfood cycle 1 live (real repo: 49 rows, Q1 = open PRs + dirty worktrees). **Supersedes doc-only PR #368** (its `--sort=Prisma`, `--format`, `--lang`, 9-value `--scope` expansion deferred with rationale — YAGNI; its internal 0.4.0-vs-0.2.0 version contradiction and `dogfooded-2-cycles` claim over non-existent code are exactly the anti-theater class this v0.2.0 closes). |
| 0.1.1 | 2026-08-18 | Harmonized alias: `work-compass --sort=Eisenhower` as SSOT implementation, this skill = discoverable alias + classifier SSOT (spec-only; superseded by 0.2.0 executable). |
| 0.1.0 | 2026-08-18 | Bootstrap: Eisenhower-ordered pendency queue `--scope/--sort` triple-A spec (PR #367). |
