---
name: auto-pilot
version: "0.1.0"
description: |
  Autonomous unattended orchestration entry point. Delegates an entire operator
  goal across one or more sub-agents using the existing GaaS/GaaC delegation
  framework, with hard-bounded autonomy levels and depth-capped recursion.
  Use when the operator wants the assistant to drive a multi-step goal without
  per-step approval, while still respecting Sentinel anomaly thresholds,
  Anti-Conflict worktree discipline, and the 6-attempt escalation rule.
  Triggers: "auto-pilot", "unattended orchestration", "delegate the whole goal",
  "run autonomously", "drive this end to end", "piloto automático".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
---

# Auto-Pilot

Thin autonomous-orchestration kernel. `auto-pilot` does not re-implement
delegation, convergence, agent selection, or anomaly detection — it composes
them. Every arrow in the flow below lands on an artifact that already exists
in this repo.

## When to use

- The operator stated a goal and asked you to drive it end-to-end.
- The goal naturally decomposes into ≥ 2 sub-tasks that map to distinct agents
  in `agents/`.
- A long-running session where per-step human approval would dominate wall-clock.
- Multiple agents will produce competing proposals that need merging
  (`debate-converge` mode).

## When **not** to use

- Single-shot edit, single-file fix, typo — disproportionate ceremony.
- Read-only Q&A — answer directly.
- Destructive operations (force-push protected, drop prod) — always HITL.
- Goal not yet stable / operator still exploring — wait for stability.

## How it works

```
operator goal
     │
     ▼
┌────────────────────────────────────────────────────────────┐
│ Phase 1 — Decompose & select                               │
│   skills/agent-select/SKILL.md  →  ordered agent list      │
└────────────────────────────────────────────────────────────┘
     │
     ▼
┌────────────────────────────────────────────────────────────┐
│ Phase 2 — Emit init prompt (per spawn)                     │
│   plugin-scripts/gaac/delegate.sh init                     │
│   → cats protocols/delegation/delegation-init-prompt.md    │
└────────────────────────────────────────────────────────────┘
     │
     ▼
┌────────────────────────────────────────────────────────────┐
│ Phase 3 — Spawn (Task tool) + monitor                      │
│   mode ∈ {sequential, parallel, recursive, debate-converge}│
│   sentinel/detection_rules.md gates auto-block decisions   │
│   delegation-dna-prompt.md emitted mid-flight if drift     │
└────────────────────────────────────────────────────────────┘
     │
     ▼
┌────────────────────────────────────────────────────────────┐
│ Phase 4 — Finalize                                         │
│   delegate.sh finalize → self-checklist + handoff report   │
│   skills/converge/SKILL.md if ≥ 2 proposals returned       │
└────────────────────────────────────────────────────────────┘
     │
     ▼
   operator receives single consolidated outcome
```

## Delegation modes

| Mode | Implementation | Cap |
|---|---|---|
| `sequential` | Loop: select → init → Task → finalize → next | depth ≤ 2 |
| `parallel` | Single message, N Task calls; `agents/consolidator.md` merges | N ≤ 3 per spawn |
| `recursive` | Child re-enters auto-pilot with incremented depth in DNA payload | depth ≤ 2 (hard) |
| `debate-converge` | Spawn N divergent agents in parallel, then call `skills/converge/SKILL.md` 5-act protocol | N ≤ 3, max_rounds ≤ 3 |
| `dueto` | Alias for `parallel` with N = 2 | N = 2 |
| `swarm` | Alias for `parallel` with N ≥ 3 | N ≤ 3 |

`dueto` and `swarm` are operator-facing naming sugar; they execute the
`parallel` codepath. No separate implementation.

## Autonomy bands

Three bands keyed off existing Sentinel + delegation-finalize signals.
The canonical pause list is `protocols/delegation/delegation-init-prompt.md`
§Rejection conditions — auto-pilot cites it, does not re-author it.

| Band | Proceeds without HITL | Pauses for HITL |
|---|---|---|
| `L1-cautious` | Read-only ops, analysis | Any write attempt |
| `L2-bounded` (default) | Writes inside worktree; draft PR creation; no force-push; no protected-file edits | Destructive ops; protected files; cross-tenant data; Sentinel HIGH severity; 6 failed attempts |
| `L3-extended` | L2 + non-draft PR open + auto-merge of green-bot PRs | Sentinel HIGH; OWASP LLM01 prompt-injection signal; secret detection |

Default band is `L2-bounded`. Operator may override via `/auto-pilot --band=L3`.

## Dual-Impact Merge Gate (DIMG)

`L3-extended` auto-merge decisions follow the DIMG (SSOT: `skills/quiesce`
§Dual-Impact Merge Gate, incl. branch-tier bars): dev ≥85% · homolog ≥90% ·
pre-prod ≥95% (+council) · production ≥99% (+council + independent verifier —
99% cannot be self-declared). v4 uniform cascade: dev ≥85% GO (senão
debate→council→HITL); hml ≥90% GO (senão debate→council→HITL); ppe debate
sempre + ≥95% GO (senão council→HITL); prd cadeia completa sempre + verificador
+ ≥99% GO (senão HITL). Economic stop embutido nos estágios. Cat A routine ⇒
authorize na escada; Cat B (CI/infra) ⇒ +mandatory council; ⛔ non-merge
absolutes (secrets, destrutivo-não-merge, HUMAN_DOMAIN) never enter the calculus.

## DNA payload v1.1 (additive)

When auto-pilot spawns a child, it appends the **DNA Payload v1.1** block
defined in `protocols/delegation/delegation-dna-prompt.md` to the prompt.
Agents that do not read the block behave exactly as before — the addition
is opt-in and backward-compatible.

The block carries: `parent_agent_id`, `depth` (hard-capped at 2), `mode`,
`autonomy_band`, `goal_root` (one-line), `attempts_remaining` (starts at 6
per the project escalation rule), and `escalation_triggers` (inherits the
5 rules already listed in `delegation-dna-prompt.md` §Escalation Rule).

## Anti-loop invariants

Reused from `agents/orchestrator.md` §Anti-Loop Detection, with depth
tightened to ≤ 2 for unattended runs (orchestrator's manual mode allows ≤ 3):

1. **Task Similarity** — sub-task same as parent → STOP.
2. **Delegation Depth** — depth > 2 → STOP (Sentinel RULE-002).
3. **Agent Repetition** — same agent type already in chain → STOP (Sentinel RULE-001 cross-chain).
4. **Output Stagnation** — child output equals input → STOP.

Sentinel thresholds in `sentinel/config.json` are authoritative; auto-pilot
does not override them.

## Failure modes

- **6 attempts failed** → escalate to operator with full context per the
  project escalation rule (see `~/.claude/CLAUDE.md` "Protocolo de Resolução
  Autônoma" if available; otherwise stop and surface the chain).
- **Sentinel HIGH** (loop / depth / token-bloat HIGH severity) → auto-block,
  emit alert, return control to operator.
- **converge returns `no-convergence-possible`** → emit verdict per
  `skills/converge/SKILL.md` Failure modes, do not force a synthesis.
- **Worktree collision / protected-file edit without lock** → reject per
  `delegation-init-prompt.md` §Rejection conditions.
- **Provider not in matrix** → escalate; do not improvise a new tool path
  (`protocols/delegation/provider-matrix.md`).

## Invariants (non-negotiable)

- Worktree discipline always on (`skills/worktree-policy/SKILL.md`).
- No band can bypass `delegation-init-prompt.md` §Rejection conditions.
- DNA payload v1.1 is **additive** — never replaces existing init/dna/finalize
  blocks.
- Depth ≤ 2 is a hard cap regardless of band.
- All status reporting follows `skills/status-map/SKILL.md` templates.

## Validation

`tests/dogfood-auto-pilot.sh` asserts:

- Skill frontmatter present with `name: auto-pilot`.
- Command file `commands/auto-pilot.md` exists with matching frontmatter.
- `delegate.sh init` (sequential / L1) still exits 0 with non-empty stdout
  after the DNA v1.1 addition (backward-compat smoke).
- `delegate.sh dna` output now contains the `DNA Payload v1.1` header.
- Skill file size < 12288 bytes (Goldilocks ceiling, mirrors `auto-shard`).
- Documented `converge` invocation matches converge's actual CLI signature
  (`converge a.md b.md --output ...`).

`tests/validate-plugin.sh` enforces the frontmatter and size checks.

## Related

- `skills/delegate-governance/SKILL.md` — per-spawn governance; auto-pilot is the goal-level wrapper above it
- `skills/converge/SKILL.md` — 5-act multi-proposal merge; `debate-converge` mode calls it
- `skills/agent-select/SKILL.md` — Phase 1 agent routing
- `skills/anti-conflict/SKILL.md` — Phase-1 checklist every spawn must honor
- `skills/worktree-policy/SKILL.md` — write discipline
- `skills/status-map/SKILL.md` — status line templates
- `skills/response-compression/SKILL.md` — context trimming when token-bloat fires
- `agents/orchestrator.md` — master coordinator persona; auto-pilot reuses its decision tree
- `agents/consolidator.md` — merges parallel sub-agent outputs
- `agents/sentinel-monitor.md` — observability counterpart
- `protocols/delegation/delegation-init-prompt.md` — emitted per spawn
- `protocols/delegation/delegation-dna-prompt.md` — DNA payload v1.1 lives here
- `protocols/delegation/delegation-finalize-prompt.md` — close report
- `protocols/delegation/provider-matrix.md` — external-call routing
- `sentinel/config.json` + `sentinel/detection_rules.md` — anomaly thresholds (RULE-001 Loop, RULE-002 Depth, RULE-009 Token bloat)
- `commands/auto-pilot.md` — operator-facing command surface

## Versioning

- v0.1.0 (initial) — sequential / parallel / recursive / debate-converge modes; L1/L2/L3 autonomy bands; DNA payload v1.1; depth cap 2.

## License

MIT (matches multi-agent-os repo `LICENSE`).
