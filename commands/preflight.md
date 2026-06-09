---
name: preflight
description: Orient + heal + isolate the git workspace before work (branch detect, safe heal from origin, lazy worktree)
---

# /preflight Command

Run the **preflight** readiness checks for agentic work: orient on the right branch
(without interfering with other worktrees), safely heal the current branch from origin,
and lazily isolate file mutations in a worktree. Thin entry point over the
[`preflight` skill](../skills/preflight/SKILL.md).

## Usage

```
/preflight [action]
```

## Actions

| Action | Description |
|--------|-------------|
| *(none)* / `check` | R1+R2: detect branch/upstream/divergence/worktree-locks (read-only) + safe-heal from origin. |
| `detect` | R1 only — read-only branch/upstream/ahead-behind/locked-elsewhere/tree-state report. |
| `heal` | R2 only — safe heal from origin (`fetch`→classify→ff-only \| rebase-autostash \| DEFER). |
| `worktree <intent>` | R3 — derive a branch + worktree from `<intent>` (per discovered conventions) and create it. |

## Behavior (safe-or-DEFER)

- **Never interferes**: a branch checked out in another worktree is git-locked → reported, never switched to.
- **Never clobbers**: dirty tree / detached / mid-rebase / mid-merge / held `.git/index.lock` → **DEFER** (reports, does not act).
- **Lazy isolation**: a worktree is created only when you are about to create/update files (R3), not preemptively.
- **Governance-aware**: reads `CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories` present at invocation and adapts the branch/worktree conventions.

## Examples

```
/preflight                      # full R1+R2 readiness report + safe heal
/preflight detect               # read-only branch situation
/preflight heal                 # safe pull/heal from origin only
/preflight worktree readme-fix  # create .worktrees/<slug> -b <type>/<scope> for the work
```

## Output

```
🧭 preflight
─────────────────────────────────────────────────
branch    feature/x    upstream  origin/main
ahead 0   behind 3     tree      CLEAN
locked-elsewhere: main          (do NOT switch — other worktree)
heal      HEALED_FF a1b2c3d
─────────────────────────────────────────────────
Ready. (R3 isolates automatically when you create/update files.)
```

## Environment

| Var | Effect |
|-----|--------|
| `PREFLIGHT_NO_AUTOHEAL=1` | SessionStart hook reports R1 only; does not auto-pull. |
| `PREFLIGHT_EDIT_GATE=block` | The Edit/Write safety-net hard-blocks main-checkout edits (default `warn`). |
| `PREFLIGHT_EDIT_GATE=off` | Disable the Edit/Write safety-net. |

## Integration

- Skill: [`skills/preflight/SKILL.md`](../skills/preflight/SKILL.md) (the orchestrator).
- Hooks: `plugin-scripts/governance/preflight-session.sh` (SessionStart), `preflight-edit-gate.sh` (PreToolUse:Edit\|Write\|MultiEdit).
- Composes: `/maos:worktree create`, `lib/worktree-utils.sh`, `.worktrees/sessions.json`.
- Complements: `worktree-policy` (policy), `worktree-gate.sh` (Bash gate), `anti-conflict` (locks).
