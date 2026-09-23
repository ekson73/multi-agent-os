---
name: roadmap-tree
description: Project the roadmap N-Tree from the durable SSOT (orchestration/roadmap.yaml) with status measured at the source — the dependency edges + lenses (SWOT/RACI/Eisenhower) that Jira/ADR/OpenSpec do not store. World-aware; DRY (pointers, not copied content). Invokes the roadmap-tree-projector skill.
---

# /roadmap-tree Command

Invokes the `roadmap-tree-projector` skill — projects the roadmap as a dependency
**N-Tree** with live status, from the one durable SSOT that stores the graph
**edges** and analysis **lenses** (which Jira/ADR/OpenSpec/Linear do not).

## Usage

```text
/roadmap-tree [--check] [--lens swot|raci|eisenhower] [--status-file <path>] [--json] [--roadmap <path>]
```

## What it does

1. **Locate + validate** the SSOT and fail on a dependency cycle:
   ```bash
   python3 skills/roadmap-tree-projector/scripts/project_roadmap.py --check
   ```
2. **Measure status at the source** per each node's world — GitHub (`gh`), Jira
   (`acli`), or Linear — and write `id=status` lines to a status file.
3. **Project** the tree + topological order + optional lens:
   ```bash
   python3 skills/roadmap-tree-projector/scripts/project_roadmap.py \
     --status-file <file> --lens swot
   ```
4. **Enrich** — the skill proposes missing edges / reclassifies ambiguous status;
   edits the SSOT only on your confirmation.

## Privacy

`orchestration/roadmap.yaml` lives in a **public** repo. It carries only abstract
pointers (VKS-3088, PR#351, session-key) and mechanics — **never** PII, secrets,
sensitive client names, or client decision content. CI (`supply-chain-sentinel`)
scans every commit.

## SSOT

`skills/roadmap-tree-projector/SKILL.md` (the protocol) + `orchestration/roadmap.yaml`
(the data). Cross-link: `[[roadmap-tree-projector]]`.
