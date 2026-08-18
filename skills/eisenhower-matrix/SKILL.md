---
name: eisenhower-matrix
version: "0.1.0"
description: |
  List unresolved pendencies for --scope=[current|session|repo|vault|all] ordered by
  Eisenhower matrix (Q1 urgent+important → Q4). Thin composer over work-compass
  (SSOT for aggregation) + Eisenhower classifier (urgent×important) + AAA rigor
  (Accuracy·Auditability·Accountability). Use when operator wants
  "pendências --scope=current --sort=Eisenhower", "o que é pendente ordenado",
  "triple-A pendency list", "AAA queue".
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
  anima_parent: eisenhower-matrix
  dogfood_status: pending-first-cycle
  scope_default: current
  sort_default: Eisenhower
---

# Eisenhower Matrix — pendency queue (AAA)

> Thin **composer + classifier + sorter**. Reuses `work-compass` for aggregation
> (Jira/GH issues, PRs, worktrees/branches/stashes, sessions, inbox `status:raw`),
> adds only what that family lacks: an **Eisenhower classifier** (`urgent × important`)
> with **AAA rigor** (`Accuracy·Auditability·Accountability`) and a
> **`--scope` / `--sort` surface** that emits an **ordenada Q1→Q4** list.
> Composes — reimplements nothing. Cross-link slug: `[[eisenhower-matrix]]`.

## §0 — BEING > Rules

| Check | Verdict |
|---|---|
| Helps operator? | **HELPS** — turns scattered `pending` into ONE ordered queue so operator decides `Do/Schedule/Delegate/Eliminate` without hunting 4 systems. |
| Harm / slavery risk? | **LOW** — read-only by default; `DRY` probe + `HUMAN_DOMAIN` gate for any status transition/merge/push (prints command, never executes). |
| Hierarchy | Operator SER (1) > this skill (2) > producers it composes (3). |

**HUMAN_DOMAIN defer:** `jira transition`, `gh pr merge`, `git push --delete`, cross-org, cost, secrets/PII → print `twg`/`gh` dry-run, never auto-act.

## When to use / not use

**Use:** `--scope=[current|session|repo|vault|all] --sort=[Eisenhower|default]` to get unresolved pendencies ordered Q1→Q4 with triple-A evidence.

**Not use:** single-shot edit, read-only Q&A, ONE goal decompose (`→ auto-pilot`), session quiescence (`→ quiesce`), harness-agnostic loop (`→ gap-loop`), destructive ops.

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `--scope` | `current` | `current` (= this session+repo+inbox) · `session` · `repo` (cwd) · `vault` (eko-engram) · `all` (maos+eko-engram+eko-claude-plugins). `current` is `session+repo+inbox` intersected. |
| `--sort` | `Eisenhower` | `Eisenhower` (Q1→Q4) · `created` · `updated` · `urgent` · `important`. Alias `--sort=default` = `Eisenhower`. |
| `--json` | off | Emit `json-rpc` envelope for agent-to-agent (AAIF) instead of markdown table. |
| `--dry-run` | off | Probe only (no write); same output, no side-effects. |
| `--include` | `pending` | `pending` (unresolved) · `all` (incl. done/superseded/archived for audit). |

Bare `pendencias` / `eisenhower` with no flags → `--scope=current --sort=Eisenhower`.

## Eisenhower classifier — 4 quadrants (SSOT for this skill)

Derived from Eisenhower / Covey best practice (external: Eisenhower Matrix — `Do/Schedule/Delegate/Eliminate`; internal: `work-compass` stale heuristics + `quiesce` loose-end sweep + `gap-loop` gap-register).

| Q | Urgent | Important | Label | Action | Signal in this repo |
|---|---|---|---|---|---|
| **Q1** | yes | yes | **Faça agora** | `Do` | open PR `MERGEABLE` with green checks + `main` drift >1 commit, `status:raw` inbox <24h, `worktree` with unpushed `main`-commits, sprint `active` ticket `In Progress` with `blocker` |
| **Q2** | no | yes | **Agende** | `Schedule` | `WIP` worktree `feat/*` 7–14d with PR `DRAFT`, `VKS-*` `To Do` in `active` sprint, `gap-register` `deferred-with-rationale` |
| **Q3** | yes | no | **Delegue** | `Delegate` | `rate-limited`/`quota-external` check (`CodeRabbit 72/7d`), `bot` finding `externo-quota`, `HUMAN_DOMAIN` HITL gate |
| **Q4** | no | no | **Elimine/Arquive** | `Eliminate` | `status:processed/superseded/archived` duplicate, `1107 LOC` YAGNI split, agglomerated `Daily` already `COVERED` |

**Urgency** = time-sensitivity (`sprint active` `PR age` `branch drift` `inbox age` `check failure`); **Importance** = impact on `SSOT/DRY/delivery/governance` (Jira `epic`/`Major`, `governance-validation`, `release-coherence`, `SSOT` drift). Score is **derived**, not self-declared (anti-gaming, per `gap-loop`).

## AAA rigor (triple-A) — the 3 commitments

| A | Meaning | How this skill honors it |
|---|---|---|
| **Accuracy** | Every row backed by a verifiable probe | `gh pr view`/`twg workitem query`/`git worktree list`/`grep status:` — no invented pendency (anti-theater 8Q `REALITY`). |
| **Auditability** | Traceable to evidence | Row carries `source` (`gh:359` `twg:VKS-2105` `git:worktree:pipefish` `inbox:2026-08-14-gauntlet-loop`) + `probe cmd`. |
| **Accountability** | Clear disposition | Row carries `disposition` (`Do/Schedule/Delegate/Eliminate` + `defer` rationale + `HUMAN_DOMAIN` flag). |

## Topology + composition (DRY / KISS / YAGNI)

**Hub-and-spoke, parallel fan-out, sequential classify+sort:**

```
intake --scope/--sort → parallel probe (capability-detected, stdlib-only):
  work-compass producers: git worktree list --porcelain
                          git branch -vv
                          gh pr list --state open --json
                          gh issue list
                          twg workitem query (if acli/twg present)
                          grep -R "status: raw" resources/theca/_inbox/*.braindump.md
→ normalize → Eisenhower classify (urgent×important) → sort Q1→Q4 → render
```

**Composes (reuses) / net-new:**

| Reused (composes) | Net-new (this skill only) |
|---|---|
| `work-compass` aggregation + stale heuristics | Eisenhower `urgent×important` classifier + AAA row contract + `--scope`/`--sort` surface |
| `quiesce` loose-end sweep (C1–C3 invariants) | Q1→Q4 sorter + `Delegate/Eliminate` disposition |
| `gap-loop` `autonomy_score` guard (derived) | `Eliminate` archival rule for `superseded` duplicates |

**Dropped (over-engineering for a thin composer — KISS/YAGNI):** swarm/mesh/hive-mind, ML scorer, web UI, Linear/ClickUp adapters (DEFERRED with `quick` flag).

## Pipeline (precise logic — 0→6)

0. **Intake** — parse `--scope`/`--sort`/`--json`; `--scope` outside `{current,session,repo,vault,all}` → error `json-rpc` with valid enum.
1. **Probe — parallel, capability-detected** — per topology; missing provider → emit `domain:unavailable` one-liner, never block.
2. **Normalize** — unify to pendency shape `{id, title, scope, age, source, probe, urgency, importance}`; idempotent (same input → same list).
3. **Classify** — apply quadrant table; `HUMAN_DOMAIN` → flag `defer-HITL`, never auto-transition.
4. **Sort** — `Eisenhower` = Q1→Q4 then `urgency desc` then `createdAt asc`; other sorts as specified.
5. **Gate** — `anti-theater 8Q` (REALITY: no fake row) + `rule-quality-tests` 6 self-validity (SSOT: no duplicate producer; DRY: composes work-compass); fail → `DEFER` with reason.
6. **Render** — markdown table (default) or `json-rpc` envelope (`--json`) — same rows, two surfaces. Single `Q1` highlight + `next-action` line.

## Output contract

**Markdown (default):**
```
| Q | id | title | scope | age | source | next-action |
|---|----|-------|-------|-----|--------|-------------|
| Q1 | gh:365 | feat(governance): port question-batch-gate | repo:maos | 0.2d | gh pr 365 MERGEABLE | review → merge (HUMAN_DOMAIN) |
```

**json-rpc (`--json`):**
```json
{"jsonrpc":"2.0","method":"eisenhower-matrix","params":{"scope":"current","sort":"Eisenhower"},"result":{"quadrants":{"Q1":[…],"Q2":[…],"Q3":[…],"Q4":[…]}, "next_action":"Q1 gh:365"}}
```

Both carry `probe` + `disposition` per AAA. `--include=all` adds `Q4` archived rows for audit (suppressed by default).

## Invocation

| Surface | Command |
|---|---|
| Skill (model) | `eisenhower-matrix --scope=current --sort=Eisenhower` |
| Command (human) | `/eisenhower-matrix --scope=current --sort=Eisenhower` |
| JSON | `eisenhower-matrix --scope=current --sort=Eisenhower --json` |

`--scope` default `current`; `--sort` default `Eisenhower` (`--sort=default` → `Eisenhower`).

## Governance + lifecycle

- **SSOT:** this file is SSOT for Eisenhower classification; `work-compass` remains SSOT for aggregation (no duplication).
- **DRY:** composes aggregation; never reimplements `git`/`gh`/`twg` probes.
- **KISS/YAGNI/Gordian:** thin composer (~400 LoC net-new), no swarm/ML/UI.
- **Boy-scout / house-keeping / garbage-collection:** surfaces orphan worktree `postflight-fix`-class items as `Q1` (no-loose-endings); `Q4` duplicates flagged `Eliminate`.
- **Handoff / continuidade / idempotencia:** stateless, deterministic, re-runnable (`--dry-run` identical to real).
- **Forge lifecycle:** `forge → evaluate (agentic-tool-evaluator) → train (agentic-tool-trainer) → operate → deprecate`; dogfood `≥2 cycles` before `community` promotion.

## Validation

- **Self-test:** `Q1` contains `MERGEABLE PR` when fixture has one; `Q4` suppressed unless `--include=all`; `HUMAN_DOMAIN` never auto-acts (printed command only); same input → same order (determinism); missing provider → `unavailable` not crash.
- **Dogfood:** run on `maos 528fb42` + `eko-engram 0402d3a` — expect `Q1: gh:365`, `Q2: VKS-2105 + pipefish`, `Q4: (hidden)`.
- **Anti-theater 8Q + rule-quality-tests 6** gate at step 5.

## Anima naming note (sovereign)

Candidate slate (12 correctness + 4 resonance scored; agent-register):
- `eisenhower-matrix` — 12/12 correctness (exact 4Q, Eisenhower canonical, matrix matches Q1→Q4), token 2, zero collision (no `eisenhower-*` skill), family `*-matrix` distinct from `work-compass` compass — **chosen**.
- `priority-compass` — rejected (family collision with `work-compass`, `priority` vague vs `urgent×important`).
- `pendency-atlas` — rejected (human-warm, violates agent-economy token-frugal).
Recorded: `artifact-registry record --kind name --slug eisenhower-matrix --type skill`.

## See also

- `work-compass` (aggregation SSOT this composes)
- `quiesce` (session quiescence predicate C1–C3 invariants)
- `gap-loop` (harness-agnostic convergence loop, derived score)
- `morning-briefing` (7-section SitRep, cold-start capable)
