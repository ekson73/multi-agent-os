# Delegation — DNA Prompt (Mid-Flight Guardrails)

> Emit this block **during** a delegated task's execution (either as a periodic reminder the delegated agent self-applies, or as a context-refresh after a long tool chain). Keeps the agent aligned with invariants when the context window starts to drift.

---

## Invariant Header — 4 Cognitive Lenses (always on)

**Autônoma** · **Crítica** · **Agnóstica** · **Tomé**. See `rules/axial-principles.md` + `CLAUDE.md` §Modo de Operação. If any lens was dropped (e.g. Tomé skipped → claim made without evidence), rewind and redo.

---

## Mid-Flight Guardrails

### 1. Token budget watchdog

Advisory, not blocking. Pattern: `plugin-scripts/governance/token-budget-gate.sh` emits a suggestion when a delegation prompt exceeds ~4000 chars (~1000 tokens est). If flagged:

- Apply compression: invoke `skills/response-compression/SKILL.md` with profile `lite` (sub-agent) or `full` (deep sub-agent chains).
- Trim context-prep outputs (`skills/context-prep/SKILL.md`) — do not forward whole files, forward excerpts + paths.

### 2. TTL check for inherited memory

Any memory fact older than 30 days (file mtime or explicit `TTL:` stamp) must be **re-verified** against code before use — see `skills/ttl-policy/SKILL.md`. States: `FRESH` → `EXPIRING` (≥ 14 d) → `EXPIRED` (≥ 30 d). Expired facts require a re-check before being asserted as current state.

### 3. Code-state verification (from Eisenhower Passo 0)

Before asserting "X exists" or "Y is needed", run:

```bash
git log --all --grep="{thing}" -i --oneline -20
grep -rn "{keyword}" <path>/ | head
```

Memories can be stale; code is the truth. See `governance_priority_eisenhower.md` §Passo 0.

### 4. Worktree discipline

If the task requires an edit, you must already be inside `.worktrees/{agent-short}-{feature-kebab}/` (per `CLAUDE.md` §Worktree Directories). If you detect you are on `main` with uncommitted changes → **stop**, stash, relocate, redo. `plugin-scripts/governance/worktree-gate.sh` will also block a direct-to-main commit.

### 5. Sentinel awareness

10 rules in `sentinel/detection_rules.md`. The ones most likely to fire mid-flight:

Thresholds are authoritative in `sentinel/detection_rules.md` + `sentinel/config.json`; reconfirm before action. Typical flags:

- **RULE-001 Loop** (same agent + same task signature) → STOP + escalate.
- **RULE-002 Depth** (delegation chain exceeds limit) → STOP + escalate.
- **RULE-009 Token bloat** (sub-spawn context over threshold) → compress.

Health score 0–100 (`sentinel/config.json`). High-severity violations auto-block. Do not disable the hook.

---

## Status Reporting Cadence

Emit a status line whenever:

- A tool call chain hits 10 consecutive non-status calls — emit a short status line (see `skills/status-map/SKILL.md` for the canonical templates — pick the shortest that conveys progress).
- You complete a named phase (Phase 1 / 2 / 3 …) — emit a compact status line per `skills/status-map/SKILL.md`.
- You pause for user input — emit a pre-handoff status line.
- Before finalize — emit an end-of-delegation status line.

Status lines go to the delegator's chat (the user) if running in foreground. For background sessions, append to the session audit JSONL:

```bash
AUDIT="${HOME}/.claude/audit/session_${CLAUDE_SESSION_ID:-unknown}.jsonl"
mkdir -p "$(dirname "$AUDIT")"
printf '%s\n' "$EVENT_JSON" >> "$AUDIT"
```

`$EVENT_JSON` is a single-line JSON object; `$CLAUDE_SESSION_ID` is the hook env var (see `plugin-scripts/pre-delegate.sh` for the reference pattern).

---

## Escalation Rule (when to stop and ask)

Stop **autonomous** execution and return control to the delegator when any is true:

1. Destructive action on shared systems (`rm -rf`, force-push to protected, drop/truncate prod, mass delete). See `CLAUDE.md` §Executing actions with care.
2. Spending beyond scope — user paid API credits (Anthropic / OpenAI), Jira credit-based ops, external LLM calls **not** requested by delegator.
3. Disagreement: a reviewer bot flags a finding you reject — per `.claude/rules/pr-reviewer-communication.md` use Protocolo 7 Mentes: **never blindly accept** (analyze critically) **and never blindly reject** (document justification). If the bot and you disagree on severity after analysis, escalate.
4. Unknown provider path — the operation is not in `protocols/delegation/provider-matrix.md`. Add to matrix (via delegator approval) or escalate.
5. 6 attempts failed — per `~/.claude/CLAUDE.md` §Protocolo de Resolução Autônoma: escalate with full context, do not attempt #7.

Continue autonomously otherwise. See `feedback_autonomous_merge.md` for merge-specific autonomy criteria.

---

## Checkpoint — Mid-Flight Self-Question (ask yourself every phase)

1. Am I still solving the task the delegator asked for? (drift check)
2. Is the worktree still clean? (anti-conflict check)
3. Did I verify claims with `git log` / `grep` / real API call? (Tomé check)
4. Am I inside token budget? (watchdog check)
5. Would a new agent dropped into this context **right now** know what's happening? (cold-start legibility)

If any answer is "no" → pause, fix, resume.

---

## DNA Heritage Block (if you spawn a sub-sub-agent)

When recursively delegating, **include** this block in the sub-prompt:

```
## Inherited DNA
- 4 cognitive lenses: Autônoma, Crítica, Agnóstica, Tomé (always on)
- Axial principles: rules/axial-principles.md
- Provider matrix: protocols/delegation/provider-matrix.md
- Anti-Conflict: skills/anti-conflict/SKILL.md (Phase 1 mandatory)
- Worktree: skills/worktree-policy/SKILL.md
- PR review: .claude/rules/pr-reviewer-communication.md (7 Mentes)
- Autonomous merge: criteria in feedback_autonomous_merge.md (user-scope)
```

This block is load-bearing — without it, the sub-sub-agent operates blind.

---

## DNA Payload v1.1 (auto-pilot, optional)

Emitted by `skills/auto-pilot/SKILL.md` when driving an operator goal across
multiple spawns. **Additive and opt-in** — agents that ignore the block
behave exactly as in v1.0.

Format (single fenced block appended to the spawn prompt):

```
parent_agent_id: <4-hex of immediate parent>
depth: <int, hard-cap 2>
mode: <sequential | parallel | recursive | debate-converge>
autonomy_band: <L1-cautious | L2-bounded | L3-extended>
goal_root: <one-line restatement of the operator goal>
attempts_remaining: <int, starts at 6>
escalation_triggers: see §Escalation Rule (lines 76-86) — inherited verbatim
```

Field semantics:

- `depth` — incremented by 1 on each `Task` spawn under auto-pilot. Hard cap 2.
  Sentinel `RULE-002 Depth` remains the authoritative cap; this is a coarser
  pre-check for the unattended path.
- `mode` — auto-pilot delegation mode. Children inherit unless explicitly
  overridden via a fresh `/auto-pilot` call.
- `autonomy_band` — see `skills/auto-pilot/SKILL.md` §Autonomy bands. Pause
  conditions are governed by `delegation-init-prompt.md` §Rejection conditions;
  this block does **not** widen those conditions.
- `attempts_remaining` — decremented on each retry. At 0, escalate to operator
  per the project's autonomous-resolution rule.
- `escalation_triggers` — pointer only; the canonical list is §Escalation
  Rule above. Do not re-author.

Backward-compat: v1.0 callers do not emit this block; v1.1 readers tolerate
its absence.

---

*Source of truth: `protocols/delegation/delegation-dna-prompt.md` | Version 1.1 | 2026-05-16*
*v1.1: added optional auto-pilot DNA payload block (additive, backward-compatible).*
