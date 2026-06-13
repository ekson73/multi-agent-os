---
name: postflight
description: Close the session out cleanly + hand it off (exit-hygiene sweep, debrief, ai-agnostic continuation seed, optional auto-spawn of the next session)
---

# /postflight Command

Run the **postflight** end-of-session debrief: a boy-scout exit-hygiene **sweep** (no loose
ends), a session **debrief** (objectives + gaps + next-actions), a **ticket-sync** (file the
loose ends as bounded tickets + an idempotent continuation ticket), a **handoff** seed a
fresh amnesic agent can resume from, and an optional **spawn** of a fresh, pre-seeded
`claude` continuation session. The end-of-session counterpart to `/preflight`. Thin
entry point over the [`postflight` skill](../skills/postflight/SKILL.md).

## Usage

```
/postflight [action] [--spawn | --no-spawn] [--no-kickoff] [--dry-run]
```

> Surfaces at runtime as `/maos:postflight` (Sandwich Namespacing per `.claude-plugin/plugin.json`).

## Actions

| Action | Description |
|--------|-------------|
| *(none)* / `full` | P1+P2+P2.5+P3: sweep → debrief → ticket-sync → emit + clipboard the continuation seed. |
| `sweep` | P1 only — exit-hygiene sweep (git close-out + docs/ADRs/changelogs/memories/rules persist + ticket **close** of verifiably-done tickets), classified by Eisenhower, safe-or-DEFER. |
| `debrief` | P2 only — calculate the session map: compose `morning-briefing` (7-section state) + synthesize the objectives N-Tree + Eisenhower next-actions + gaps/pendings/undecided on top, then render the glance-and-know **locus** + the end-of-action **scorecard** (`bin/scorecard.py`, model picked round-robin by `bin/scorecard-next-model.sh`). No mutations to tracked files. |
| `tickets` | P2.5 only — reconcile the backlog with the session: bounded gap→ticket triage (≤3 + 1 batch) + an idempotent continuation ticket + enrich the anchored ticket, delegated to a capability-detected ticketing primitive (DEFER if absent). Requires P2 (DoR). SSOT: `skills/postflight/references/ticket-sync-protocol.md`. |
| `seed` | P3 only — emit the ai-agnostic continuation seed (agent-register envelope + human mirror) + clipboard. Requires P1+P2+P2.5 (DoR). |
| `spawn` | P3.5 only — launch a fresh, named `claude` continuation session pre-seeded with the P3 seed (`bin/spawn-continuation.sh`). Requires a seed (DoR). |

> **P3.5 SPAWN** (tool 5.1) runs by default after `seed` on a `full` run (**spawn ON**); pass `--no-spawn` to opt out, `--no-kickoff` to spawn WITHOUT the initial kickoff prompt (the new session starts idle at the REPL instead of immediately resuming the seed — kickoff is ON by default and starts consuming tokens right away), `--dry-run` to preview the launch without spawning. It is high-blast (a real session burns tokens) → guarded by a kill-switch, once-per-source-session idempotency, an anti-recursion depth-cap, capability-detected graceful-noop, and seed sanitization. See the skill for the full guardrail list.

## Behavior (safe-or-DEFER)

- **Never clobbers**: dirty tree / divergence-with-conflict / held `.git/index.lock` / untracked-you-did-not-create → **DEFER** (report/register, do not act). Read-before-discard is mandatory.
- **Handoff is gated**: the seed is emitted only after the sweep + debrief, so it never misreports the state it claims to capture.
- **Governance-aware**: reads `CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories` present at invocation and adapts the exit + close + handoff conventions.
- **Leave it better**: the environment must be cleaner, safer, more traceable than it was found (exit-hygiene).

## Examples

```
/postflight                  # full: sweep + debrief + seed + spawn (default ON) — run before /compact
/postflight --no-spawn       # full, but emit/clipboard the seed only (no new session)
/postflight --dry-run        # preview the spawn command without launching
/postflight sweep            # exit-hygiene close-out only (git + docs + tickets)
/postflight debrief          # session map (recap) only, no mutations
/postflight tickets          # P2.5 backlog sync only (file loose ends + continuation ticket)
/postflight seed             # emit the continuation seed (after a sweep+debrief)
/postflight spawn            # launch the pre-seeded continuation session (after seed)
```

## Output

```
🛬 postflight
─────────────────────────────────────────────────
SWEEP    pushed feat/x · PR #42 → green · pruned 1 stale ref · changelog bumped
DEBRIEF  objectives 2/3 done · 1 gap · 1 undecided · 3 next-actions (Q1×1, Q2×2)
         📊 scorecard model 4/7 (burndown, round-robin) rendered from debrief state
TICKETS  closed 1 · created 2 + batch(3) · continuation → TICKET-456
HANDOFF  🌱 continuation seed → printed + copied to clipboard
SPAWN    🛫 TICKET-456-add-retry-#a1b2c3d4 (tmux) — attach: tmux attach -t '…' · or --no-spawn next time
─────────────────────────────────────────────────
Next agent: /maos:preflight, then start at the first non-blocked next-action.
```

## Environment

| Var | Effect |
|-----|--------|
| `POSTFLIGHT_NO_AUTOSNAPSHOT=1` | The PreCompact hook skips its deterministic snapshot (manual `/postflight` still works). |
| `POSTFLIGHT_SNAPSHOT_PRS=1` | The PreCompact hook also fetches open-PR state via `gh` (network; default off = fast/offline-safe). |
| `POSTFLIGHT_SEED_DIR=<path>` | Override where the PreCompact hook writes the seed snapshot (default: inside the repo's git dir — git-ignored, so it never dirties the working tree). |
| `POSTFLIGHT_SPAWN=0` | **P3.5 kill-switch** — never spawn a continuation session (deterministic opt-out; overrides `--spawn`). |
| `POSTFLIGHT_KICKOFF=0` | Spawn WITHOUT the initial kickoff prompt (same as `--no-kickoff`) — the session is seeded but starts idle at the REPL. Default: kickoff ON (the spawned session immediately reads its seed and resumes work). |
| `POSTFLIGHT_SCORECARD_MODEL=<1..7\|name>` | Pin the P2 scorecard layout model + skip the round-robin rotation entirely (e.g. `cockpit`, `telemetry`, `4`). Default: round-robin via `bin/scorecard-next-model.sh`. |
| `POSTFLIGHT_SCORECARD_STATE=<path>` | Override the round-robin pointer file (default: `~/.claude/jobs/.postflight-scorecard-model`). |
| `POSTFLIGHT_SPAWN_DEPTH=N` | Current auto-chain depth (default 0); `>=` the depth-cap (default 1) → P3.5 graceful no-op (anti-recursion). |
| `MAOS_SPAWN_LAUNCHER` | Force the spawn launcher: `tmux` \| `cmux` \| `print` (default: auto-detect; `print` = register + emit the resume command). |

## Integration

- Skill: [`skills/postflight/SKILL.md`](../skills/postflight/SKILL.md) (the orchestrator).
- Hook: `plugin-scripts/governance/postflight-precompact.sh` (PreCompact — deterministic seed snapshot; never blocks; never spawns).
- Composes: `protocols/exit-hygiene.md`, `skills/postflight/references/ticket-sync-protocol.md` (P2.5 SSOT) + a capability-detected ticketing skill (ref: `ticket-as-prompt`), `skills/{sync-to-git,quiesce,morning-briefing,session-fission}`, `commands/worktree.md`, `bin/dogfood-mark`, `bin/spawn-continuation.sh` (P3.5 spawn primitive), `bin/locus.sh` (P2 locus) + `bin/scorecard.py` + `bin/scorecard-next-model.sh` (P2 scorecard, round-robin).
- Counterpart: `/preflight` (start-of-session) — together the loop: `preflight → work → postflight → (spawn) → preflight …`.
