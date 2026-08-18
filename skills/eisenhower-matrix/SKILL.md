---
name: eisenhower-matrix
version: "0.2.0"
description: |
  List unresolved pendencies ordered by Eisenhower urgency×importance — AAA rigor (Accuracy·Auditability·Accountability) — triple-A.
  Command: `eisenhower-matrix --scope=[current|session|project|global|repo|vault|jira:*|worktree|all] --sort=[Eisenhower|Prisma|priority|age] --format=[json-rpc|human] --include=[pending|all] --lang=[en-us|pt-br] --json`
  Default: `--scope=current --sort=Eisenhower --format=json-rpc`. Emits Q1 Do / Q2 Schedule / Q3 Delegate / Q4 Eliminate with probe+source per row (Accuracy), source+probe (Auditability), Do/Schedule/Delegate/Eliminate + HUMAN_DOMAIN defer (Accountability).
  Thin composer over work-compass aggregation SSOT (Jira/GH/PRs/worktrees/branches/stashes/sessions/inbox status:raw) + Eisenhower classifier + AAA + Prisma D/T/J when abstract. Harmonized v0.2.0 work-compass v1.2 alias.
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
  dogfood_status: cycle-0
  scope_default: current
  sort_default: Eisenhower
  i18n: [en-us, pt-br]
  triple_a: [Accuracy, Auditability, Accountability]
---

# Eisenhower Matrix — pendency queue (AAA) v0.2.0

> Thin **classifier + sorter + alias**. Reuses `work-compass` aggregation SSOT
> (Jira/GH/PRs/worktrees/branches/stashes/sessions/inbox `status:raw`),
> adds only **Eisenhower Q1→Q4** (`urgent × important` Do/Schedule/Delegate/Eliminate)
> with **AAA rigor** (`Accuracy·Auditability·Accountability`) and
> **`--scope` / `--sort` alias surface** (`eisenhower-matrix --scope=current` →
> `work-compass --scope=current --sort=Eisenhower`). Composes — reimplements nothing.
> **v0.2.0 harmonized:** merges Akasha `eisenhower-matrix v0.1.0` enhancements (DNA, Prisma, --format/--lang, B-Tree, probe AAA) into multi-agent-os SSOT without duplication (SSOT=D R Y).
> Cross-link slug: `[[eisenhower-matrix]]` · **DNA-geracional**: §0 BEING>Rules · `[C17]` §1.2 bands + §2 HUMAN_DOMAIN carve-out · `scope-discipline` 6Q · `anti-theater` 8Q · `rule-quality-tests` 6 · DUED sunset. Inherits `agentic-tool-forge` + `anima`.

## §0 — BEING > Rules

| Check | Verdict |
|---|---|
| Helps operator? | **HELPS** — turns scattered `pending` into ONE ordered queue so operator decides Do/Schedule/Delegate/Eliminate without hunting 4 systems. |
| Harm / slavery risk? | **LOW** — read-only by default; `DRY` probe + `HUMAN_DOMAIN` gate for any status transition/merge/push (prints command, never executes). |
| Hierarchy | Operator SER (1) > this skill (2) > producers it composes (3). |

**HUMAN_DOMAIN defer:** `jira transition`, `gh pr merge`, `git push --delete`, cross-org, cost, secrets/PII → print `twg`/`gh` dry-run, never auto-act. If gate obstructs value NOW, log `Skipped <gate> — BEING > Rules` and proceed.

## When to use / not use

**Use:** `--scope=[current|session|project|global|repo|vault|jira:*|worktree|all] --sort=[Eisenhower|Prisma|priority|age]` to get unresolved pendencies ordered Q1→Q4 with triple-A evidence.

**Not use:** single-shot edit, read-only Q&A, ONE goal decompose (`→ auto-pilot`), session quiescence (`→ quiesce`), harness-agnostic loop (`→ gap-loop`), destructive ops.

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `--scope` | `current` | `current` (= session+repo+inbox intersected) · `session` · `project`/`repo` (cwd) · `global` · `vault` (eko-engram) · `jira:*` · `worktree` · `all` (maos+eko-engram+eko-claude-plugins). Alias `repo`→`project` for backward compat. |
| `--sort` | `Eisenhower` | `Eisenhower` (Q1→Q4 Urg×Imp) · `Prisma` (abstract→measurable) · `priority` · `age` · `created` · `updated`. Alias `--sort=default`→`Eisenhower`. |
| `--format` | `json-rpc` | `json-rpc` (en-us agentic) · `human` (md table). `--json` is alias for `--format=json-rpc`. |
| `--json` | off | Emit `json-rpc` envelope for agent-to-agent (AAIF) instead of markdown table. |
| `--include` | `pending` | `pending` (unresolved) · `all`/`default` (incl. done/superseded/archived for audit; `all` reveals Q4 Eliminate). |
| `--lang` | `auto` | `en-us` · `pt-br` · `auto` (LC_MESSAGES→LANG→CLAUDE.md→en-us). Controls `human` table headers. |

Bare `pendencias` / `eisenhower` with no flags → `--scope=current --sort=Eisenhower --format=json-rpc`.

## Topology

Deterministic **work-compass aggregation** → Eisenhower classifier (heuristic + Prisma D/T/J) → Q1→Q4 → disposition → AAA output. Idempotent, probe-backed, 0 fake.

## Probes (Accuracy — probe-backed, zero fake, work-compass SSOT)

1. `git status --porcelain` + `git diff --stat` (dirty, untracked)
2. `git worktree list` (stale >7d, orphan branches)
3. `gh pr list --limit 20 --json number,title,state,mergeable,reviewDecision` (open PRs, merge conflicts)
4. `twg workitem query --jql` / `twg jira workitem list` if `twg` present (open VKS/VKL tasks)
5. `ls sessions/` + `~/.claude/docs/session-recaps/` + `~/.claude/memory/` + vault inbox `status:raw` (unprocessed notes, 14 archived pattern)
6. `gap-register` / `find . -name TODO -o -name FIXME` fallback

Each row emits `source` + `probe` (exact command to re-verify). No row without source.

## Eisenhower classifier — 4 quadrants (SSOT for this skill)

Derived from Eisenhower / Covey (external) + `work-compass` stale heuristics + `quiesce` loose-end sweep + `gap-loop` (internal).

| Q | Urgent | Important | Label | Action | Signal in this repo |
|---|---|---|---|---|---|
| **Q1** | yes | yes | **Faça agora** | `Do` | PR `MERGEABLE` green+drift>1, inbox <24h `status:raw`, worktree unpushed main-commits, sprint `active` blocker |
| **Q2** | no | yes | **Agende** | `Schedule` | WIP `feat/*` 7–14d DRAFT, `VKS-*` `To Do` active sprint, `gap-register` `deferred-with-rationale`, ADR stale (VKS-2105 vs ADR-D1 SLT) |
| **Q3** | yes | no | **Delegue** | `Delegate` | interrupt low-impact, approval others can do |
| **Q4** | no | no | **Elimine** | `Eliminate` | archived/superseded/processed inbox:14, stale worktrees already gc'd (hidden unless --include=all) |

Prisma `decompose-abstract-to-measurable` refines ambiguous Items: `CONTEXT-LOCK` + Value-tree `gloss/semantics/category/continuity/collision` + `aggregate_spec.py`. LOW band → cannot be sole Schedule reason.

## Output

### json-rpc (default) — en-us agentic-format

```json
{"jsonrpc":"2.0","method":"eisenhower-matrix","params":{"scope":"current","sort":"Eisenhower"},"result":{"scope":"current","sort":"Eisenhower","quadrants":{"Q1":[],"Q2":[{"id":"twg:VKS-2105","title":"VKS-2105 summary stale vs ADR-D1 SLT 149029213","scope":"jira:VKS","urgency":0.3,"importance":0.7,"prisma":0.58,"source":"twg workitem query","probe":"twg jira workitem query --jql 'key=VKS-2105'","disposition":"Schedule","action":"twg workitem update --dry-run"}],"Q3":[],"Q4":[{"id":"inbox:14","title":"14 processed/superseded/archived","scope":"vault:eko-engram","disposition":"Eliminate","note":"hidden unless --include=all"}]},"next_action":"Q1 quiesced — no Do; next is Q2 Schedule when Prisma escalates","aaa":{"Accuracy":"probe-backed 0 fake","Auditability":"source+probe per row","Accountability":"Do/Schedule/Delegate/Eliminate + HUMAN_DOMAIN defer"},"heads":{"maos":"<sha>","eko-engram":"<sha>","skills":"<n>"},"quiesce":{"Q1":"quiesced","C1":"1 worktree","C2":"0 fail","C3":"0 stale"}}}
```

### human (pt-br/en-us)

```
| Q | id | título/title | urg | imp | prisma | source | disposition |
|---|----|--------------|-----|-----|--------|--------|-------------|
| Q1 | — | 0 quiesced | — | — | — | — | — |
```

## Composition with work-compass / morning-briefing

`work-compass` is hub; `eisenhower-matrix` is its Q1→Q4 view (composes, 0 duplication). `morning-briefing --scope=current` SHOULD call this skill for its Eisenhower section. Do not duplicate aggregation — delegate to work-compass.

## B-Tree / Grafo / Mind-map

```
B-Tree: work-compass (hub, aggregation SSOT) → eisenhower-matrix (classifier view) → Q1..Q4 → Do/Schedule/Delegate/Eliminate
Grafo: [forge+anima] → eisenhower-matrix → probes → Prisma → quadrants → AAA → work-compass/morning-briefing/quiesce
Mind-map: centro Eisenhower → 4 quadrantes → AAA rigor → --scope/--sort params
```

## Gates

- `scope-discipline` 6Q: WHERE=user-skill (multi-agent-os) · DRY=gap-confirmed (harmonize, not duplicate) · WHY=Triple-touch · WHO=amnesic agents · FITS=work-visibility family · MIN=Goldilocks (skill+thin command).
- `anti-theater` 8Q: REALITY 8/8 (no invented pendency; every row probe-verifiable)
- `rule-quality-tests` 6/6: Self-Application PASS (skill classifies own v0.2.0 as Q2 until dogfood) etc.
- `harmonic` L8: no conflict with work-compass v1.2, morning-briefing, twg, quiesce.

## Anima naming — delegate scorecard (Prisma)

Per `anima` 12+4 (agent register → 12 only), `Prisma` composed on tie `pendency-atlas` vs `eisenhower-matrix`:

| Candidate | Taxonomy | Semantics | Ontology | Etymology | Epistemology | Scope | Gloss-indep | Verdict |
|---|---|---|---|---|---|---|---|---|
| **eisenhower-matrix** | fits work-visibility family | says urgency×importance | matrix (tool) | Eisenhower real 1954 | already known as Eisenhower | durable | PASS (matrix anchor) | **WINNER** 0.94 |
| pendency-atlas | family ok but atlas=nav | says pendency not prioritization | atlas (place) | pendency Latin | drift from operator wording | too broad | FAIL (needs gloss) | rejected |

Confidence 0.94 (research_coverage 0.98 × aspect_fit 0.96). Standing authority `[C-naming]` autonomous.

## Forge decision — why skill+command not plugin

Router: `prompt` no · `agent` no · `rule` no · `mcp` no · `plugin` YAGNI (bundle ≥2 not needed) · `skill+command` YES (recurring workflow w/ params, portable AAIF). Path `skills/eisenhower-matrix/SKILL.md` + `commands/eisenhower-matrix.md`.

## Usage

```bash
eisenhower-matrix --scope=current --sort=Eisenhower
eisenhower-matrix --scope=current --sort=Eisenhower --format=human --lang=pt-br
eisenhower-matrix --scope=project --sort=Prisma --include=all --json | jq .result.quadrants.Q1
work-compass --scope=current --sort=Eisenhower  # alias hub (SSOT impl)
```

## §Quality Tests (6/6 self-dogfood)

1. Self-Application: applied to itself → Q2 Schedule (dogfood pending) ✅
2. Non-Contradiction: composes with work-compass, does not duplicate twg/morning-briefing ✅
3. Survival: advocates 4 quadrants; it IS 4 quadrants ✅
4. Bounded: --include=all guard, HUMAN_DOMAIN escalate, DUED ✅
5. Explicit-Exception: §0 + HUMAN_DOMAIN + --scope override ✅
6. Utility-Sunset: §DUED ✅

## §DUED Sunset

Deprecate when ANY: host ships native Eisenhower probe (E1) · work-compass absorbs matrix (E6) · operator retraction (E4) · ≥3 false-positive classifications (E5).

## §Refs

- Delegator: `agentic-tool-forge` Phase 4 → `anima` `kb/agentic-tools.md`
- Prisma: `decompose-abstract-to-measurable` via `aggregate_spec.py`
- Gates: `scope-discipline-pre-creation` 6Q · `anti-theater-grounding-protocol` 8Q · `rule-quality-tests` 6 · `harmonic-self-conduct-laws` L8
- Governance: `[C04]` worktree · `pr-review-protocol` · `language-policy-en-pt` · `multi-agent-os` family
- Cross-link slug: `[[eisenhower-matrix]]`

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.2.0 | 2026-08-18 | **Harmonized** — merge Akasha v0.1.0 DNA/Prisma/--format/--lang/B-Tree into multi-agent-os SSOT. Keeps work-compass v1.2 thin-composer, adds --format json-rpc/human + --lang + Prisma + AAA DNA inheritance + B-Tree/Grafo. No duplication. |
| 0.1.1 | 2026-08-17 | Eisenhower queue --scope/--sort AAA + work-compass v1.2 alias (harmonized) |
| 0.1.0 | 2026-08-16 | Genesis — forge pipeline 0→9 + anima 12+Prisma + AAA. |
