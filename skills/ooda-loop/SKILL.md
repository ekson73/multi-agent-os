---
name: ooda-loop
version: "0.2.0"
description: |
  Run the operator's recurring goal-loop contract end-to-end as ONE preset:
  Observe (recover the session goal -> handoff-as-prompt) -> Orient (derive a MEASURABLE DoD via
  Prisma -> dod-as-prompt) -> Decide (gate on both envelopes' inconclusive->HITL) -> Act (drive to
  quiescence with the typed {goal, dod} pair via gap-loop or quiesce). Thin composer — reimplements
  nothing: it chains goal-recovery + decompose-abstract-to-measurable (Prisma) + gap-loop/quiesce,
  and inherits (never re-loosens) their invariants — chiefly gap-loop's `verifier != generator`
  independent audit. Hybrid: deterministic typed envelopes + economic stop bounding probabilistic
  MoE cognition; idempotent (re-running an already-quiescent session is a no-op).
  Triggers: "ooda-loop", "ooda --scope", "recover the goal then drive it to done", "run the goal-loop
  contract", "recover -> DoD -> converge", "observe orient decide act this session".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
metadata:
  version: "0.2.0"
  scope: AAIF cross-vendor
  family: orchestration-convergence
  cross_link_slug: ooda-loop
  dogfood_status: pending-first-cycle
---

# OODA-Loop

Thin **goal-loop conductor**. `ooda-loop` composes the three steps of the operator's recurring
contract into one override-friendly preset; every step lands on a primitive that already exists.

> **Provenance / lineage**: distills the operator's hand-invoked contract
> `{ ooda --scope=this.session --goal==$(goal-recovery ... --type handoff-as-prompt) --dod==$(Prisma ...
> --type dod-as-prompt); /quiesce --dod={{dod}} --goal={{goal}}; }` into a reusable tool. The operator
> literally frames it as OODA — Observe/Orient/Decide/Act maps exactly onto recover/measure/gate/drive.
> Named via `anima` (agent-register): `ooda-loop` (Boyd 1976; the operator's own `ooda` verb; cited SOTA
> Raghavan & Schneier IEEE S&P 2025). Rejected `conductor` (near-collides with the family's `orchestrator`);
> rejected `goal-loop` (`goal` vendor-reserved) / `goal-pilot` (collides `auto-pilot`). Authored by Claude
> Opus 4.8 (1M) under operator `/enhance` directive 2026-07-12; reviewed by @ekson73.

## §0 — BEING > Rules (foundational)
Serves the operator's intent. If a step/gate obstructs driving the goal NOW, skip it, log
`Skipped <step> — BEING > Rules`, proceed. HUMAN_DOMAIN (secrets · production PII · irreversibles ·
force-push protected · cross-org · destructive) is a HARD gate -> HITL, never self-authorize. The
`verifier != generator` invariant (inherited from gap-loop) is NON-negotiable — never re-loosened here.

## Purpose
Take a session whose goal may be UNSTATED and drive it to a measured DONE — recover the goal (typed,
uncertainty-aware), turn it into a measurable DoD, then converge — with the improvement signal driven
by an INDEPENDENT verifier against that DoD (not the generator grading itself), an economic stop, and
idempotent typed contracts. The reusable form of the operator's manual `ooda ...; /quiesce ...` pattern.

## When to use
- The operator wants "recover what this session is doing, then drive it to done" in one move.
- A session's goal is implicit AND needs a measured, converged steady state (not just decomposition).
- The full contract is wanted: recover -> measurable DoD -> drive-to-quiescence, with audit + HITL gates.

## When **not** to use
- The goal is explicit AND you just need decompose+delegate -> `auto-pilot`.
- You already have a typed goal + DoD and only need the drive loop -> `gap-loop` / `quiesce` directly.
- Single-shot edit / read-only Q&A -> answer directly.
- Merging N proposals -> `converge`. Result-quality routing only -> `convergence-engine`.
- Destructive ops -> always HITL.

## Trigger Phrases
- "ooda-loop" / "ooda --scope=..." / "run the goal-loop contract"
- "recover the goal then drive it to done" / "recover -> DoD -> converge" / "observe orient decide act this session"

## The OODA map (the 4 acts — each lands on a primitive)

```text
OBSERVE   goal-recovery --scope=<scope>  ->  handoff-as-prompt envelope   (recover the intent; ladder + uncertainty)
            | inconclusive.flag=true (low confidence / no anchor) -> STOP-HITL with ranked hypotheses
            v
ORIENT    invoke Prisma (decompose-abstract-to-measurable) on the recovered goal
            construct := "is {{goal}} DONE and healthy?"; context_lock <- handoff (context/objectives/scope)
            ->  bin/render_dod_as_prompt.py PROJECTS the Prisma spec -> dod-as-prompt envelope
                (deterministic: acceptance <- material D/T leaves; kpis; termination_predicate; self-gated)
            | Prisma STRUCTURAL gate (scripts/structural_route.py, fail-closed): a value-tree validly
            |   represents only ADDITIVE/atomic constructs. status=additive_unverified OR relational/gestalt
            |   -> the aggregate score is assistive-only (human_review) -> treat as inconclusive -> STOP-HITL
            |   (do NOT auto-drive on a capped score). status=additive-verified -> proceed to the roll-up.
            | Prisma roll-up (scripts/aggregate_spec.py) inconclusive.flag=true (judgment-dominated / conflict:<branch> / low-conf) -> STOP-HITL
            v
DECIDE    gate: both envelopes valid + not-inconclusive + NOT HUMAN_DOMAIN + autonomy_score >= threshold?
            | any red -> HITL (with the computed envelopes attached, never a blank ask)
            | resolve --driver (auto: quiesce if host /goal + session scope, else gap-loop)
            v
ACT       drive with the typed {goal, dod} pair:
            handoff-as-prompt  -> the driver's state-source (goal + objectives seed the gap-register)
            dod-as-prompt.termination_predicate -> the driver's --condition (DoD leaves = the stop test)
            improvement signal := the DoD checks, evaluated by an INDEPENDENT verifier (gap-loop VALIDATE,
            verifier != generator) — NEVER the generator's self-grade (Huang et al. 2310.01798).
            emit exactly ONE STOP marker per turn.
```

## The typed pair (the wiring — how the envelopes flow into the driver)
| Envelope | Produced by | Consumed as |
|---|---|---|
| `handoff-as-prompt` | goal-recovery (OBSERVE) | driver `--state-source=handoff:<file>` — goal + objectives seed the gap-register / session scope |
| `dod-as-prompt` | Prisma via ooda-loop (ORIENT) | driver `--condition=<termination_predicate>` — the DoD leaves are the termination test; the loop re-scores progress against the value-tree each round (Prisma re-run on current state) |

Both are validator-gated (`goal-recovery/bin/validate_envelope.py`) before ACT. A mid-run goal revision
(handoff hypotheses) or DoD re-score (Prisma re-eval) is allowed — the pair is revisable, not frozen.

## Composition (DRY — every step is an existing primitive)
| Step | Composes (reimplements nothing) |
|---|---|
| OBSERVE | `skills/goal-recovery` (-> handoff-as-prompt; Skopos recon-first inference ladder) |
| ORIENT | `skills/decompose-abstract-to-measurable` (Prisma value-tree; `scripts/structural_route.py` form-gate + `scripts/aggregate_spec.py` roll-up) THEN `bin/render_dod_as_prompt.py` (deterministic PROJECTION: spec -> dod-as-prompt, acceptance/kpis/termination_predicate, self-gated against `validate_envelope.py`) |
| DECIDE | `agents/COWORK-AUTONOMY-POLICY.md` bands + `[C17]` §2 HUMAN_DOMAIN + `anti-theater` 8Q gate |
| ACT (default) | `skills/gap-loop` (harness-agnostic 5-phase loop; MoE RESOLVE + independent VALIDATE + derived score) |
| ACT (session) | `skills/quiesce` (`/goal`-driven session quiescence; PR-green + comments-answered) |
| verify (both) | `maos:persona-pipeline`/`perspective-trio` inside the driver (verifier != generator master condition) |

## Override parameters
| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<instructions>"` (positional) | empty | extra free-text appended to the driver action |
| `--scope` | `this.session` | `this.session` \| `branch` \| `ticket:<id>` \| `session:<id>` — passed to OBSERVE + the driver |
| `--driver` | `auto` | `auto` (quiesce if host `/goal` + session scope, else gap-loop) \| `gap-loop` \| `quiesce` \| `<custom>` |
| `--conf-inconclusive` | `0.60` | `0.0`-`1.0` — goal-recovery HITL gate (below => STOP-HITL before ORIENT) |
| `--autonomy-threshold` | `0.85` | `0.0`-`1.0` — DECIDE gate + passed to the driver |
| `--max-iterations` | `6` | int — ACT loop cap (passed to gap-loop `--max-iterations` / quiesce `--max-pdca`) |
| `--auto-merge` | `hold` | `authorized` \| `hold` \| `off` — passed to the driver (conservative default; parity with gap-loop EKO-66) |
| `--auto-merge-reason` | *(none)* | required-non-empty when `--auto-merge=authorized` (auditability, `auto-merge-standing-authorization` G8) |
| `--output` | `text` | `text` \| `json` (emit the run envelope, below) |
| `--dry-run` | off | run OBSERVE+ORIENT+DECIDE, print the {goal, dod} pair + chosen driver + predicate, but do NOT drive ACT |
| `--only` | *(full run)* | `observe` \| `orient` \| `decide` — run OBSERVE..stage and STOP, emitting that stage's envelope. **`--only=orient` = the `dod-recovery` operation** (recover/ingest the goal -> derive + emit the measurable DoD via Prisma + `bin/render_dod_as_prompt.py`; no DECIDE, no ACT). Distinct from `--dry-run` (which runs through DECIDE). |
| `--for-goal` | *(recover via OBSERVE)* | explicit goal string — skip OBSERVE, derive the DoD for THIS goal directly (the common `--only=orient` case: the goal is known, you want its measurable DoD). |

## Output contract (`--output=json`)
```json
{"stage":"OBSERVE|ORIENT|DECIDE|ACT",
 "status":"ok|hitl|error",
 "stop_marker":"STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE",
 "handoff":{"goal":"<...>","confidence":0.0,"inconclusive":{"flag":false}},
 "dod":{"for_goal":"<...>","termination_predicate":"<...>","evaluation":{"band":"HIGH|MEDIUM|LOW"}},
 "driver":"gap-loop|quiesce","autonomy_score":0.0}
```
Exit: `0` STOP-DONE · `1` STOP-ERROR · `2` STOP-HITL (data/authority gap).

## STOP-marker grammar (reused — emit exactly ONE as the last line of each turn)
```text
<!--ORCH-STATUS: STOP-DONE -->     DoD satisfied — termination_predicate met, verifier-confirmed, score >= threshold
<!--ORCH-STATUS: STOP-HITL -->     goal OR DoD inconclusive, OR HARD gate (HUMAN_DOMAIN) — envelopes attached
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (validator / subagent / network)
<!--ORCH-STATUS: CONTINUE -->      round done; DoD not yet met OR score < threshold; next round opens
```

## Relationship to siblings
| Tool | Scope | Drives | Recovers goal? | Derives DoD? |
|---|---|---|---|---|
| `ooda-loop` (this) | a session's WHOLE contract | recover -> measure -> converge | **YES** (goal-recovery) | **YES** (Prisma) |
| `gap-loop` | a goal as a gap-register | declarative self-scored 5-phase loop | no (ingests a goal) | no (ingests a condition) |
| `quiesce` | the SESSION | `/goal` termination over all open items | no | no |
| `auto-pilot` | ONE explicit goal | decompose -> select -> spawn -> converge | no | no |
| `enhance-pipeline` | ONE feature | EXPAND -> FILTER -> HARMONIZE -> DELIVER | no | no |

`ooda-loop` is the ENTRY that produces the typed {goal, dod} the loop tools were missing an author for;
gap-loop/quiesce are its ACT drivers. It never re-implements recovery, measurement, MoE, or the loop.

## Protocol Rules (anti-loop + integrity invariants)
- `verifier != generator` (gap-loop VALIDATE) is inherited and NEVER re-loosened — the improvement signal reads the DoD checks, not the generator's self-grade.
- Both envelopes MUST pass `validate_envelope.py` before ACT; either `inconclusive.flag=true` => HITL (never drive on a fabricated goal or an unscoreable DoD).
- `--max-iterations` (default 6) caps ACT rounds; then park-state + escalate.
- Worktree discipline always on; never commit to main. Delegation depth <= 2. Exactly ONE STOP marker per turn.
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, prod/irreversible, cross-org) -> HARD gate -> HITL.
- Idempotent: an already-quiescent session (DoD already met) drives to STOP-DONE as a no-op (write-ahead checkpoint; inherited from gap-loop/quiesce).

## DNA Geracional (inherited by every spawned agent)
- **Dogfood**: drive the loop on its OWN creation goal before declaring done (`--dry-run` on this session).
- **Persist-over-fail**: the {goal, dod} envelopes ARE the write-ahead checkpoint; a mid-run collapse is recoverable.
- **DRY / KIS / YAGNI / SSOT** — compose the three primitives; never duplicate them.
- **No self-destructive decisions**; **Boy-Scout** — leave repo + envelopes cleaner than found; STAGE-only unless authorized.

## Examples
```text
ooda-loop --scope=this.session                    # recover this session's goal -> DoD -> drive to done
ooda-loop --dry-run                               # print the recovered {goal, dod} + driver + predicate; drive nothing
ooda-loop --driver=quiesce --auto-merge=authorized --auto-merge-reason="nightly convergence, green CI"
ooda-loop --scope=ticket:VKS-1234 --autonomy-threshold=0.9 --max-iterations=4
ooda-loop --driver=gap-loop --conf-inconclusive=0.75   # stricter goal-recovery HITL gate, harness-agnostic driver
ooda-loop --only=orient --for-goal "ship the session-handoff spine"   # dod-recovery: derive+emit the measurable DoD only; drive nothing
```

## Quality Tests (6/6 self-validity — dogfooded)
1. **Self-Application** — ooda-loop could recover its OWN creation goal, derive a DoD ("2 skills + 2 schemas + extension, tests green, audit 8/8"), and drive it. PASS.
2. **Non-Contradiction** — composes (not duplicates) goal-recovery/Prisma/gap-loop/quiesce; the OODA wiring + typed-pair are net-new; inherits `verifier != generator` without loosening it. PASS.
3. **Survival** — applied to itself it advocates a recovered-goal + measurable-DoD + independent-verify loop; it is itself that. PASS.
4. **Bounded-Responsibility** — `--max-iterations`, both inconclusive->HITL gates, autonomy gate, HARD-gate escalation, STOP-marker, §DUED. PASS.
5. **Explicit-Exception** — When-not-to-use + HARD-gate HITL + §0 BEING>Rules + `--dry-run`. PASS.
6. **Utility-Sunset** — §DUED below. PASS.

`scope-discipline` 6Q: 6/6 (WHERE=multi-agent-os · DRY=~70% reused, composes 3 primitives · WHY=recurring hand-invoked contract, this session = a Triple-touch instance · WHO=operator+amnesic agents · FITS=orchestration-convergence sibling of gap-loop/quiesce/enhance-pipeline · MIN=1 thin conductor + 1 schema). `anti-theater` 8Q REALITY: 8/8.

## §DUED Sunset (qualitative — not counter-based)
Deprecate when ANY: a host ships a native recover->measure->converge primitive (E1) · gap-loop/quiesce absorb
a typed {goal,dod} entry making the conductor redundant (E6) · agents recover+measure goals reflexively so the
preset never fires (E3) · operator retraction (E4) · >=3 false-positive runs (E5 -> refine). Dormant-by-design otherwise.

## Related
- `commands/ooda-loop.md` — operator-facing command surface
- `templates/dod-as-prompt.schema.json` — the ORIENT output contract (wraps Prisma)
- `bin/render_dod_as_prompt.py` — the deterministic ORIENT projection (Prisma `measurement_spec` -> validator-gated `dod-as-prompt`; the `--only=orient`/`dod-recovery` renderer)
- `skills/goal-recovery/SKILL.md` (+ `templates/handoff-as-prompt.schema.json`, `bin/validate_envelope.py`) — the OBSERVE step
- `skills/decompose-abstract-to-measurable/SKILL.md` (Prisma) — the ORIENT engine (`scripts/structural_route.py` form-gate + `scripts/aggregate_spec.py` roll-up)
- `skills/gap-loop/SKILL.md` — harness-agnostic ACT driver (default; verifier != generator) · `skills/quiesce/SKILL.md` — `/goal` session ACT driver
- `skills/convergence-engine/SKILL.md` — the bounded-convergence math both drivers inherit (REFINE/SELECT/DEFER + economic stop)
- `agents/COWORK-AUTONOMY-POLICY.md` — autonomy bands (DECIDE gate)
- External grounding: Boyd OODA (1976) · GOOD arXiv:2508.15119 (uncertainty-aware goal) · RLCF 2507.18624 (judge x verifier per criterion ~ Prisma) · MoA 2406.04692 · Huang et al. 2310.01798 (verifier > generator, independent — the hard invariant) · optimal-stopping 2510.01394 (economic stop) · Raghavan & Schneier IEEE S&P 2025 (OODA)

## Versioning
- v0.2.0 (2026-07-16) — **`dod-recovery` mode + the deterministic ORIENT renderer** (additive, backward-compatible).
  Adds `bin/render_dod_as_prompt.py`: the missing deterministic PROJECTION that turns a Prisma
  `measurement_spec` into a validator-gated `dod-as-prompt` envelope (acceptance <- material D/T leaves,
  J excluded; kpis; `termination_predicate` = the driver `--condition`). Correct-by-construction, then
  self-gated against `goal-recovery/bin/validate_envelope.py` (fail-closed: a refused render emits nothing,
  exit 3). Adds `--only=observe|orient|decide` (run-to-stage-and-STOP) with **`--only=orient` = the
  `dod-recovery` operation** (recover/ingest the goal -> derive+emit the DoD; no DECIDE/ACT) + `--for-goal`
  (skip OBSERVE, DoD an explicit goal). `dod-recovery` is a MODE, not a new skill — honors the earlier
  decision that a standalone `dod-recovery` skill is over-engineering. Reimplements nothing (composes
  Prisma + the SSOT validator). Closes the R4 gap: the `dod-as-prompt` wire had a schema, an example, a
  validator and 4 consumers, but no deterministic authorer.
- v0.1.0 (2026-07-12) — bootstrap. Conductor for the operator's recover->measure->converge contract:
  OBSERVE (goal-recovery) -> ORIENT (Prisma DoD) -> DECIDE (dual inconclusive->HITL + autonomy gate) ->
  ACT (typed {goal,dod} pair into gap-loop/quiesce). Inherits verifier != generator, economic stop, idempotency,
  STOP-marker from the drivers; adds only the OODA wiring + the typed-pair plumbing. Composes 3 primitives; reimplements nothing.

## License
MIT (matches multi-agent-os repo `LICENSE`).
