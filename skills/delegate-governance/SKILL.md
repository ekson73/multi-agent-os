---
name: delegate-governance
description: Emit the correct governance prompt (init / dna / finalize) before, during, and after delegating to a sub-agent. Use when delegating work, spawning sub-agents, running parallel agents, or planning a multi-agent task. Covers cross-provider (Jira / Linear / Bitbucket / GitHub / GitLab) and AI-provider agnostic.
version: 1.0.0
---

# Delegate Governance (GaaS / GaaC)

Unified entry point for the delegation framework. Routes to one of three invariant meta-prompts + a provider selection matrix, so delegator and delegated agents stop re-inventing governance per call.

## When to use this skill

- Before a `Task` tool call that spawns a sub-agent.
- When the user says: "delegar", "delegate", "spawn subagent", "sub-agent", "parallel agents", "before delegating", "after delegation", "finalize task", "cleanup delegation".
- When resuming a paused delegation chain after a compaction / new session.
- When a sub-agent needs to spawn a sub-sub-agent and must inherit the DNA block.

## When **not** to use

- Single-agent work with no sub-delegation — use `skills/worktree-policy/SKILL.md` + `skills/anti-conflict/SKILL.md` directly.
- Read-only analysis with no writes — skip the worktree/lock overhead.
- Micro-fixes (typos, single-line renames) — disproportionate ceremony.

## How it works

```
invoke skill  or  bash plugin-scripts/gaac/delegate.sh <phase> [flags]
                              ↓
        ┌─────────────────────┼──────────────────────┐
delegation-init          delegation-dna         delegation-finalize
  -prompt.md              -prompt.md               -prompt.md
(emit at start)         (emit mid-flight)         (emit at close)
                              ↓
             all three cite  provider-matrix.md
```

File locations:
- `protocols/delegation/delegation-init-prompt.md`
- `protocols/delegation/delegation-dna-prompt.md`
- `protocols/delegation/delegation-finalize-prompt.md`
- `protocols/delegation/provider-matrix.md`

CLI emitter: `plugin-scripts/gaac/delegate.sh <init|dna|finalize> [--ticket KEY] [--provider auto|jira|linear|github|bitbucket|gitlab]`

## Instructions for the delegator

1. **Before spawning a sub-agent**:
   - Run `plugin-scripts/gaac/delegate.sh init --ticket=$TICKET` — its stdout is the prompt prefix for the sub-agent. The header lines (detected ticket / VCS providers, worktree, agent-hex) are authoritative; do not second-guess them.
   - Concat your task-specific body after the init block.
2. **Mid-flight** (optional but recommended for long chains):
   - Send the dna prompt via `delegate.sh dna` as a context refresh if the sub-agent drifted or the chain has > 5 tool calls.
3. **After the sub-agent returns**:
   - Send `delegate.sh finalize` to yourself — it is a self-checklist for cleanup + handoff + learning codification.

## Instructions for the delegated agent

1. Echo the first line of init's dynamic header back (`TICKET=... VCS_PROVIDER=... ...`) to confirm inheritance.
2. Apply the 4 cognitive lenses (Autônoma / Crítica / Agnóstica / Tomé) throughout. See `rules/axial-principles.md`.
3. When recursively delegating, include the "DNA Heritage Block" from `delegation-dna-prompt.md` — otherwise the sub-sub-agent operates blind.
4. On finish, produce the "Delegation Report" block from `delegation-finalize-prompt.md` §Phase 8.

## Provider selection (decision-free at call time)

For every external call (ticket, VCS, secrets, observability) look up the operation row in `protocols/delegation/provider-matrix.md`. Use the primary tool; on failure, walk the fallback list in order. **Do not** improvise a new path.

## Validation

`tests/validate-plugin.sh` asserts:
- Four files under `protocols/delegation/` exist.
- Each `delegation-*-prompt.md` stays under 1500 tokens (word count × 1.3).
- `plugin-scripts/gaac/delegate.sh` exists and is executable.
- `delegate.sh init | dna | finalize` each exit 0 with non-empty stdout.
- This SKILL.md has the expected frontmatter (`name: delegate-governance`).

## Related

- `skills/anti-conflict/SKILL.md` — Phase-1 checklist source
- `skills/worktree-policy/SKILL.md` — worktree rules
- `skills/context-prep/SKILL.md` — minimal context for sub-agents
- `skills/hierarchical-merge/SKILL.md` — branches → parent, not main
- `skills/audit/SKILL.md` — audit event schema
- `protocols/agent-delegation.md` — decision tree (who is the best agent?)
- `agents/orchestrator.md` — master coordinator
- `docs/gaas-architecture-manifesto.md` — conceptual frame
