---
name: session-fission
description: On-demand, non-destructive splitter for a tangled Claude session — inventories the N-Tree of atomic contexts, snapshots the transcript, and reseeds clean focused sessions. Original is archived, never mutated or deleted.
---

# /session-fission Command

> Surfaces as `/maos:session-fission` under the plugin namespace (see `.claude-plugin/plugin.json` `command_namespace`).

## Usage

```
/maos:session-fission [transcript.jsonl] [--apply]
```

| Arg / flag | Meaning |
|---|---|
| `[transcript.jsonl]` | Optional explicit transcript path. Omit to auto-detect the most-recent session in the current project dir. |
| `--apply` | Run the safe write steps (snapshot + emit seed scaffolds). **Default is dry-run** (inventory + N-Tree proposal only). |

## What it does

This command invokes the **`session-fission` skill**. Follow that skill's 6-step protocol:

1. **Inventory** (read-only) — `plugin-scripts/session-fission/inventory.sh` proposes an atomic-context N-Tree.
2. **Classify** the N-Tree (sequential / recursive / independent / parallel) and confirm with the user.
3. **Snapshot** (`--apply`) — `plugin-scripts/session-fission/snapshot.sh` backs up the source + manifest + gitleaks (rollback anchor).
4. **Distill** each cluster into a clean Ticket-as-Prompt seed (`seed.sh` scaffolds; the agent fills the distilled context).
5. **Reseed** focused sessions (ccpanes/`launch_task`, `claude -n`, or native `/branch`+`/compact`); archive the original (never delete).
6. **Topology + briefing** — emit the resulting N-Tree + per-seed pointers (CPT Compass-navigable).

## Safety

- Read-only on the source transcript; never trims/deletes it (surgical mid-delete is unsafe — see skill).
- Snapshot precedes any archive op; rollback = native `/resume <original>` + retained backup.
- Idempotent; dry-run by default.

## See also

- Skill: `skills/session-fission/SKILL.md`
- Spec: `docs/specs/session-fission-spec.md`
- Cowork Process Topology Protocol (Compass navigation of the resulting N-Tree)
