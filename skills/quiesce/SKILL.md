---
name: quiesce
version: "0.1.0"
description: |
  Drive the current work session to QUIESCENCE — a steady state with no pending
  work: no open ticket/gap/fix/failure/PR, every PR green, every PR comment
  answered, agentic convergence reached. Thin preset that composes the native
  /goal outer condition-loop with a pluggable inner driver (default auto-pilot);
  PDCA-converges the session's open PRs and auto-files tracking tickets for
  out-of-radar gaps. Reimplements nothing — sibling to auto-pilot (which
  decomposes ONE goal). Accepts override flags: --scope, --condition, --driver,
  --auto-merge[-reason], --auto-fix, --self-fix, --autonomy-threshold, --max-pdca.
  Use when the operator wants the session left clean/green/converged with nothing
  pending: "quiesce", "drive this session to green", "converge all open PRs",
  "zero-open loop", "leave nothing pending", "sessao limpa/convergente".
  Triggers: "quiesce", "session quiescence", "drive to green", "converge open PRs",
  "zero-open", "clean session loop".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
---

# Quiesce

Thin **session-quiescence** preset. `quiesce` does not re-implement
orchestration, delegation, convergence, or anomaly detection — it composes the
native `/goal` condition-loop with a pluggable inner driver. Every behavior
below lands on a primitive that already exists in this repo (or a host built-in).

## Purpose

Drive the current work session to a QUIESCENT steady state — no open
ticket/gap/fix/failure/PR, every PR green and answered, agentic convergence
reached — by wrapping the native `/goal` condition-loop around a pluggable inner
work driver, and codifying the operator's recurring "converge the whole session"
invocation as one reusable, override-friendly, token-economic command.

## When to use

- The operator wants the session driven to a clean/green/converged steady state.
- One or more open PRs of this session need PDCA convergence before merge.
- Out-of-radar items (gaps/failures/warnings) should be captured as tickets, not lost.
- A long unattended run where per-step approval would dominate wall-clock.

## When **not** to use

- Single-shot edit / single-file fix / typo — disproportionate ceremony.
- Read-only Q&A — answer directly.
- ONE specific goal needs decompose+delegate across agents -> use `auto-pilot`.
- Destructive ops (force-push protected, drop prod) — always HITL.
- Goal not yet stable / operator still exploring — wait for stability.

## Trigger Phrases

Canonical invocations that should activate this skill:

- "quiesce" / "/quiesce"
- "session quiescence" / "drive this session to green" / "sessao limpa/convergente"
- "converge all open PRs" / "converge open PRs"
- "zero-open loop" / "leave nothing pending" / "clean session loop"

## Quiescence predicate (default `--condition`)

```text
QUIESCENCE := NOT(unaddressed in-scope TICKET or GAP or pending FIX or FAILURE or open PR)
              AND every PR green (all required checks pass)
              AND every PR comment answered
              AND agentic convergence reached
```

Agentic convergence = all bot reviewers + CI (e.g. CodeRabbit, Amazon Q, Qodo,
gitleaks) GREEN or resolved — see `CONTRIBUTING.md` (Bot review convergence) and
`.claude/rules/pr-reviewer-communication.md`.

> **Non-blocking tickets**: a tracking ticket filed for an out-of-radar / out-of-scope /
> deferred item does NOT block quiescence — capturing-and-deferring IS the resolution
> (Boy-Scout "don't lose it"). Only *unaddressed in-scope* obligations keep the loop
> open; otherwise filing tickets would make QUIESCENCE unreachable.

## How it works

```text
operator invokes /quiesce
        |
        v
  resolve flags -> defaults unless overridden
        |
        v
/goal --goal-aware --scope=<scope> --condition='<predicate>'   (OUTER loop — host built-in)
        |  each iteration v
        v
<inner driver: default skills/auto-pilot>                      (INNER work driver)
        |-- PDCA-loop each OPEN PR of <scope> (steelman -> critique -> fix -> re-review)
        |-- out-of-radar item -> file a tracking ticket (per CONTRIBUTING tracker) + cross-link
        \-- emit exactly ONE STOP marker as the last line of the turn
        |
        v
  /goal Stop-hook evaluator reads the marker -> CONTINUE or terminate at QUIESCENCE
```

## Composition (the wiring it emits)

The resolved control flags are applied **per-driver** (translated for `auto-pilot`,
native for `auto-orchestrator`) — never silently dropped. `auto-pilot`'s own surface
is only `--mode`/`--band`/`--max-depth`, so its controls are translated (see table):

```text
/goal --goal-aware --scope=<scope> --condition='<condition>' --action:{
  <driver-invocation>      # resolved per the table below (flags translated, not dropped)
    "<instructions>; honor: auto-merge=<auto-merge> (reason "<reason>"),
     auto-fix=<auto-fix>, self-fix=<self-fix>, max-pdca=<n>;
     PDCA-loop each OPEN PR of <scope> as a converge-prompt;
     for any out-of-radar item (gap/pending/failure/warning/error) file a
     tracking ticket (per CONTRIBUTING.md) + cross-link; keep created tickets updated."
}
```

`<driver>` resolves from `--driver`:

| `--driver` | Resolves to | How resolved flags are applied |
|---|---|---|
| `auto-pilot` (default) | `/auto-pilot "<goal+controls>" --band=<L1\|L2\|L3>` | auto-pilot's surface is `--mode`/`--band`/`--max-depth` only, so `--autonomy-threshold` -> `--band` (>=0.85 L3, >=0.65 L2, else L1) and `--auto-merge`/`--auto-fix`/`--self-fix`/`--max-pdca` are carried in the goal text (honored by its PDCA + merge gate). In-repo (portable). |
| `auto-orchestrator` | `/auto-orchestrator --goal-aware --scope=... --auto-merge=... --auto-fix=... --self-fix=... --autonomy-threshold=...` | controls passed as native flags; only if installed |
| `<custom>` | any host orchestrator the operator names | operator maps the flags |

> The operator's original `/goal ... /auto-orchestrator ...` pattern is reproduced
> exactly via `--driver=auto-orchestrator`. The default stays in-repo for portability.

## Override parameters

| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<instructions>"` (positional) | empty | extra free-text appended to the driver action |
| `--scope` | `this.session` | `this.session` \| `repo` \| `branch` \| `ticket:<id>` \| `pr:<n>` |
| `--condition` | *(quiescence predicate above)* | override the termination predicate string |
| `--driver` | `auto-pilot` | `auto-pilot` \| `auto-orchestrator` \| `<custom>` |
| `--auto-merge` | `authorized` | `authorized` \| `hold` \| `off` |
| `--auto-merge-reason` | *(operator invocation)* | required-non-empty when `authorized`; invoking `/quiesce --auto-merge=authorized` IS the authorization |
| `--auto-fix` | `enabled` | `enabled` \| `disabled` |
| `--self-fix` | `enabled` | `enabled` \| `disabled` |
| `--autonomy-threshold` | `0.85` (HIGH) | `0.0`-`1.0` — maps to auto-pilot band (>=0.85->L3, >=0.65->L2, else L1) |
| `--max-pdca` | `6` | int — per-PR PDCA iteration cap |

## STOP-marker grammar (paired with `--goal-aware`, not re-authored)

Emit exactly ONE terminal marker as the last line of each turn. The HTML-comment
prefix is low-collision; the `/goal` Stop-hook evaluator reads it:

```text
<!--ORCH-STATUS: STOP-DONE -->     quiescence reached — nothing pending
<!--ORCH-STATUS: STOP-HITL -->     HITL escalation required (also prepend above any action block)
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (subagent / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      iteration done; work remains; evaluator decides next turn
```

## Relationship to siblings

| Tool | Scope | Drives |
|---|---|---|
| `quiesce` (this) | the SESSION | termination predicate over ALL open items -> steady state |
| `auto-pilot` | ONE operator goal | decompose -> select -> spawn -> converge |
| `converge` | N proposals | 5-act merge (invoked inside PDCA when a PR has competing proposals) |

`quiesce` MAY invoke `auto-pilot` for sub-goals; it never re-implements delegation,
convergence, or anomaly detection.

## Auto-merge

`--auto-merge=authorized` lets the driver queue GitHub native auto-merge **only**
when all gates pass (mergeable + green + all-comments-answered + agentic convergence
+ autonomy >= `--autonomy-threshold` + non-empty reason) and no refusal applies
(target is a protected deploy branch, CI/infra files touched, native auto-merge
disabled on the repo, or operator cancel). Otherwise use `hold` (operator merges)
or `off`. Always `--squash --delete-branch`. Fire-and-forget — no local merge
queue across turns (amnesic-safe; delegates the merge contract to GitHub).

## Protocol Rules (anti-loop invariants + bounds)

- `--max-pdca` (default 6) caps per-PR PDCA iterations; diminishing returns -> escalate.
- Worktree discipline always on (`skills/worktree-policy/SKILL.md`); never commit to main.
- Delegation depth <= 2; Sentinel HIGH auto-blocks (`sentinel/config.json` authoritative).
- 6-attempt escalation rule (different approach each attempt).
- Exactly ONE STOP marker per turn (the `/goal` evaluator contract).
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected,
  prod/irreversible, cross-org) ALWAYS halt the loop -> HITL.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: validate the loop on its own artifacts before declaring done.
- **Persist-over-fail**: write-ahead-checkpoint each obligation (task/ticket/note)
  BEFORE executing, so a mid-session collapse is recoverable.
- **DRY / KISS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **No self-destructive decisions** — nothing that boomerangs on a future session.
- **Boy-Scout** — leave every repo cleaner than found: no stale branches/worktrees,
  no loose ends, no unanswered comments.

## Examples

```text
/quiesce
/quiesce "prioritize the auth PRs first"
/quiesce --scope=pr:42 --auto-merge=hold
/quiesce --condition='NOT open PR AND every PR green' --max-pdca=3
/quiesce --driver=auto-orchestrator --auto-merge=authorized --auto-merge-reason="nightly convergence"
```

## Validation

- `tests/validate-plugin.sh` enforces (generically, for all skills): `skills/quiesce/`
  contains `SKILL.md` with valid frontmatter.
- Skill file kept < 12288 bytes — a Goldilocks *guideline* mirrored from `auto-pilot`
  (the script hard-codes that ceiling only for `auto-pilot`, not as a quiesce-specific gate).
- `commands/quiesce.md` carries matching `name: quiesce` frontmatter.
- Satisfies the 10-item checklist in `skills/skill-writer/SKILL.md`.

## Related

- `commands/quiesce.md` — operator-facing command surface
- `skills/auto-pilot/SKILL.md` — single-goal delegation kernel (default driver, sibling)
- `skills/converge/SKILL.md` — 5-act proposal merge (used inside PDCA)
- `skills/worktree-policy/SKILL.md` — write discipline every iteration honors
- `skills/status-map/SKILL.md` — status reporting templates
- `sentinel/config.json` + `sentinel/detection_rules.md` — anomaly thresholds
- `CONTRIBUTING.md` — PR convergence + tracker conventions
- `agents/orchestrator.md` — master coordinator persona

## Versioning

- v0.1.0 (initial) — quiescence predicate; `/goal` + pluggable-driver composition
  (default `auto-pilot`); override flags incl. `--driver`; PDCA-converge open PRs +
  auto-file tracking tickets; STOP-marker grammar reuse; depth/PDCA bounds; DNA Geracional.

## License

MIT (matches multi-agent-os repo `LICENSE`).
