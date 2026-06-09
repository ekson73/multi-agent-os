---
name: postflight
description: Close the session out cleanly + hand it off (exit-hygiene sweep, debrief, ai-agnostic continuation seed)
---

# /postflight Command

Run the **postflight** end-of-session debrief: a boy-scout exit-hygiene **sweep** (no loose
ends), a session **debrief** (objectives + gaps + next-actions), and a **handoff** seed a
fresh amnesic agent can resume from. The end-of-session counterpart to `/preflight`. Thin
entry point over the [`postflight` skill](../skills/postflight/SKILL.md).

## Usage

```
/postflight [action]
```

## Actions

| Action | Description |
|--------|-------------|
| *(none)* / `full` | P1+P2+P3: sweep → debrief → emit + clipboard the continuation seed. |
| `sweep` | P1 only — exit-hygiene sweep (git close-out + docs/ADRs/changelogs/memories/rules persist + ticket close-or-register), classified by Eisenhower, safe-or-DEFER. |
| `debrief` | P2 only — calculate the session map (objectives N-Tree + Eisenhower next-actions + gaps/pendings/undecided) via `morning-briefing --mode=recap`. No mutations. |
| `seed` | P3 only — emit the ai-agnostic continuation seed (agent-register envelope + human mirror) + clipboard. Requires P1+P2 (DoR). |

## Behavior (safe-or-DEFER)

- **Never clobbers**: dirty tree / divergence-with-conflict / held `.git/index.lock` / untracked-you-did-not-create → **DEFER** (report/register, do not act). Read-before-discard is mandatory.
- **Handoff is gated**: the seed is emitted only after the sweep + debrief, so it never misreports the state it claims to capture.
- **Governance-aware**: reads `CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories` present at invocation and adapts the exit + close + handoff conventions.
- **Leave it better**: the environment must be cleaner, safer, more traceable than it was found (exit-hygiene).

## Examples

```
/postflight                  # full: sweep + debrief + seed (+ clipboard) — run before /compact
/postflight sweep            # exit-hygiene close-out only (git + docs + tickets)
/postflight debrief          # session map (recap) only, no mutations
/postflight seed             # emit the continuation seed (after a sweep+debrief)
```

## Output

```
🛬 postflight
─────────────────────────────────────────────────
SWEEP    pushed feat/x · PR #42 → green · pruned 1 stale ref · changelog bumped
DEBRIEF  objectives 2/3 done · 1 gap · 1 undecided · 3 next-actions (Q1×1, Q2×2)
HANDOFF  🌱 continuation seed → printed + copied to clipboard
─────────────────────────────────────────────────
Next agent: /maos:preflight, then start at the first non-blocked next-action.
```

## Environment

| Var | Effect |
|-----|--------|
| `POSTFLIGHT_NO_AUTOSNAPSHOT=1` | The PreCompact hook skips its deterministic snapshot (manual `/postflight` still works). |
| `POSTFLIGHT_SNAPSHOT_PRS=1` | The PreCompact hook also fetches open-PR state via `gh` (network; default off = fast/offline-safe). |
| `POSTFLIGHT_SEED_DIR=<path>` | Override where the PreCompact hook writes the seed snapshot (default `${CLAUDE_PROJECT_DIR}/.maos/`). |

## Integration

- Skill: [`skills/postflight/SKILL.md`](../skills/postflight/SKILL.md) (the orchestrator).
- Hook: `plugin-scripts/governance/postflight-precompact.sh` (PreCompact — deterministic seed snapshot; never blocks).
- Composes: `protocols/exit-hygiene.md`, `skills/{sync-to-git,quiesce,morning-briefing,session-fission}`, `commands/worktree.md`, `bin/dogfood-mark`.
- Counterpart: `/preflight` (start-of-session) — together: `preflight → work → postflight`.
