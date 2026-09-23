---
name: roadmap-tree-projector
description: |
  Use when you need to SEE the whole roadmap as a dependency graph — "project the
  roadmap", "show the N-Tree", "what depends on what", "status of the graph",
  "SWOT/RACI/Eisenhower the roadmap", "projete o roadmap". Reads a durable versioned
  SSOT (orchestration/roadmap.yaml) that stores the ONE thing Jira/ADR/OpenSpec do not:
  the dependency EDGES between nodes, plus analysis LENSES. Projects the N-Tree with
  status MEASURED at the source (gh/acli/linear), never copying node content (DRY —
  nodes carry POINTERS: VKS id · PR# · ADR id · session-key). HYBRID: a deterministic
  parse+validate+topo-sort+render script + a cognitive layer that classifies ambiguous
  status and suggests missing edges. WORLD-AWARE: resolves each node's ticket-manager
  and home by its world; never writes orchestration into a client repo.
triggers:
  - project the roadmap
  - show the n-tree
  - roadmap tree
  - what depends on what
  - status of the graph
  - swot the roadmap
  - raci the roadmap
  - eisenhower the roadmap
  - projete o roadmap
version: 0.1.0
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: orchestration
  cross_link_slug: roadmap-tree-projector
  dogfood_status: self-tested
---

# Roadmap Tree Projector

## Overview

Jira / ADR / OpenSpec / Linear store the **nodes** — the content of items, PRs,
decisions, goals. **Nothing** stored the **edges** (which node depends on which),
the **computed graph status**, or the **analysis lenses** (SWOT / RACI /
Eisenhower / DoR / DoD). So every recap re-drew them in prose that dies on
context compaction — the reinvented wheel. This skill is that missing SSOT + its
projector.

It is **hybrid**:
- **Deterministic** (`scripts/project_roadmap.py`) — self-locate the SSOT, parse,
  validate, detect cycles, topo-sort, fold in measured statuses, render the
  N-Tree and any stored lens. Pure and tested (`scripts/test_project_roadmap.py`).
- **Cognitive** (this skill body, run by the agent) — classify a status the
  source reports ambiguously, propose EDGES the graph is missing, and decide
  WHICH probe/ticket-manager to call for each node given its world.

It **reuses, never copies**: a node holds a `ref:` pointer (VKS-3088, PR#351, an
ADR id, a session-key) and the projector reads live status from that source at
render time. Duplicating content here would just be a second thing to drift.

## §0 — BEING > Rules
Serves the operator's intent. If a phase/gate obstructs value NOW, skip it, log
`Skipped <phase> — BEING > Rules`, and proceed. HUMAN_DOMAIN (secrets · PII ·
irreversibles · cross-org · cost) → escalate, never auto-act.

## PRIVACY GUARD (this skill lives in a PUBLIC repo)
`orchestration/roadmap.yaml` and this skill **must not** carry PII, secrets/tokens,
sensitive client names, client decision content, or internal prod URLs — only
**abstract pointers/ids** (VKS-3088, PR#351, session-key) and mechanics. The
seed SSOT ships **generic/redacted** examples. CI (`supply-chain-sentinel`:
gitleaks + Trivy secrets) scans every commit; treat a finding as a hard stop.

## When to use
- You want the whole roadmap as a **dependency tree** with live status.
- You need to know **what blocks what** / the topological order to work in.
- You want a **lens** (SWOT / RACI / Eisenhower) rendered from stored structure
  instead of hand-drawn in prose again.

## When NOT to use
- You need the **content** of one item → read its SSOT (Jira/ADR/PR) directly.
- You are **authoring a new tool** → `agentic-tool-pipeline` / `agentic-tool-forge`.
- You need a one-off status of a single PR → `gh pr view`.

## How it works (the hybrid loop)
1. **Locate + validate** (deterministic):
   `python3 skills/roadmap-tree-projector/scripts/project_roadmap.py --check`
   — self-locates `orchestration/roadmap.yaml`, validates the schema, and
   **fails on a dependency cycle** (non-zero exit, CI-gateable).
2. **Measure status at the source** (cognitive + tools): for each node with a
   `ref`, probe the ticket-manager its **world** declares —
   `gh pr view <n> --json state,statusCheckRollup` (github),
   `acli jira workitem view --key <KEY>` (jira),
   Linear API/CLI (personal). Write the results as `id=status` lines to a status
   file. **Never** invent a status the probe did not return (anti-theater).
3. **Project** (deterministic):
   `... project_roadmap.py --status-file <file> [--lens swot|raci|eisenhower]`
   — renders the N-Tree (parents→children) with measured status folded in, plus
   the dependency-respecting topological order.
4. **Enrich** (cognitive): read the tree, then **suggest** missing edges or
   reclassify an ambiguous status — as a proposal to the operator, an EDIT to
   the SSOT only on confirmation.

## World-awareness (by design)
A node's `world` resolves BOTH where its orchestration lives AND which
ticket-manager owns its status probe:

| World | ticket-manager | orchestration home |
|---|---|---|
| personal / eko-* | Linear | `multi-agent-os`, `akasha-*` (**only** home for cross-world orchestration) |
| client | Jira | the client's Jira project — pointers only, never orchestration files |
| integrator | GitHub | that repo's issues |

**Hard rule:** cross-world orchestration metadata (this SSOT) lives in the
**personal** home only. The projector never writes a roadmap file into a client
repo — it only reads that world's status via its ticket-manager.

## Parameters (script)
| Flag | Meaning |
|---|---|
| `--roadmap <path>` | override the SSOT path (default: self-locate). |
| `--check` | validate + cycle-detect only, no render (CI gate). |
| `--lens <name>` | render a stored lens (`swot`/`raci`/`eisenhower`/…). |
| `--status-file <path>` | measured statuses (`id=status` per line) from step 2. |
| `--json` | machine envelope (topo order + nodes + edges + lens names). |

## eko-executable-scripts compliance
The projector follows `~/.kiro/steering/eko-executable-scripts.md`: self-locating
(glob+fallback), live-pinned (reads the SSOT at runtime), one idempotent
verify→render→PASS/FAIL run with non-zero exit on FAIL, native prereq handled
(PyYAML present → parse; absent → fail loud with the exact `pip install` remedy,
never a silent misparse), professional flags (`--check`/`--help`/`--lens`/
`--json`). Self-heal (`trap ... ERR` dispatching `kiro-cli chat --no-interactive
--trust-tools=fs_read,fs_write,execute_bash`) belongs in the bash wrapper the
operator runs, not inside this importable library — kept out so the tests import
a pure module.

## §Quality Tests (self-dogfood)
1. **Self-Application** — forged via `agentic-tool-forge` (research→type→name→gate);
   the type router picked **skill + command pair** (recurring hybrid workflow,
   both human-`/slash` and model-invoked).
2. **Non-Contradiction** — stores STRUCTURE (edges/lenses) that no sibling SSOT
   holds; points at Jira/ADR/PR content rather than duplicating it (DRY/SSOT).
3. **Survival** — the graph invariants are locked by `test_project_roadmap.py`
   (11 tests: validation, cycle detection, topo order, blocks-normalization).
4. **Bounded-Responsibility** — projects + proposes; edits the SSOT only on
   confirmation; never writes orchestration into a client repo.
5. **Explicit-Exception** — §0 BEING>Rules + HUMAN_DOMAIN escalation + privacy guard.
6. **Utility-Sunset** — §DUED below.

## §DUED Sunset
Deprecate when ANY: a ticket-manager natively stores cross-tool dependency edges
+ lenses (E1) · the family absorbs it into a unified orchestration entry (E6) ·
operator retraction (E4).

## §Refs
- Genesis: `skills/agentic-tool-forge` · `skills/agentic-tool-pipeline`.
- Lenses as skills (content sources for the frames): `skills/eisenhower-matrix`
  · `skills/decision-capture`.
- Executable standard: `~/.kiro/steering/eko-executable-scripts.md`.
- Governance: `skills/worktree-policy` · `skills/hierarchical-merge`.
- Cross-link slug: `[[roadmap-tree-projector]]`.

## Changelog
| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-09-23 | Bootstrap — durable roadmap SSOT (`orchestration/roadmap.yaml`) + hybrid projector (deterministic parse/validate/cycle-detect/topo-sort/render + cognitive status-classification/edge-suggestion) + world-aware status probing + `/roadmap-tree` wrapper. Forged via `agentic-tool-forge` (type=skill+command). 11 tests green. |

## License
MIT (matches multi-agent-os repo `LICENSE`).
