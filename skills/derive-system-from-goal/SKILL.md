---
name: derive-system-from-goal
version: "0.1.0"
description: |
  Given a goal, derive the MINIMAL RECURRING SYSTEM (the vehicle) that conducts to it — BEFORE pursuing it.
  The third envelope of the ooda-loop typed set, at ORIENT-b: handoff-as-prompt says WHERE I AM,
  dod-as-prompt (Prisma) says WHEN TO STOP, this says WHAT TO DO EACH ROUND. Without it a driver
  improvises its action every round — the failure the law names: "isso nao e uma meta, e simplesmente
  uma sequencia de acoes". Emits a `system-as-prompt` envelope (implementation-intention trigger->action
  + cadence + a Metron-admissible adherence signal + a revision trigger that falsifies the VEHICLE, not
  the driver). Thin deriver — reimplements NOTHING: no execution loop (that is gap-loop/quiesce), no
  convergence gate, no verifier (verifier != generator stays the driver's invariant). Law:
  akasha `rules/derive-system-from-goal.md` [C22]; soul-name Hodos (ho-dos, "a method, system; a way" —
  the root of methodos = meta + hodos, so "method" IS "goal + the way").
dogfood_status: pending-first-cycle
---

# derive-system-from-goal (soul-name: *Hodos*) — the vehicle deriver

> **The law this executes**: akasha `~/.claude/rules/derive-system-from-goal.md` (`[C22]`) — *dada a meta, construa o sistema ANTES de persegui-la; **meta sem sistema é intenção sem ação**.* The law's fire-point is `anti-theater-grounding-protocol` **Layer-5 R9**; this skill is R9's operational *how*.
> **Position**: `ooda-loop` **ORIENT-b**. Boyd's ORIENT is synthesis — **Prisma gives the destination's coordinates** (`dod-as-prompt`), **Hodos gives the route** (`system-as-prompt`). Both are ORIENT; neither drives.

## When to use / not use
- **Use**: a goal is **given** (or self-imposed) and the next move would otherwise be *"start doing things toward it"*. R9 fired.
- **Not use**: (a) **trivial action** — its system IS the single step; deriving one is ceremony (Gordian floor). (b) **The operator's personal goals** — `[C17]` §2 HUMAN_DOMAIN: available *on request*, **never** auto-prescribed. (c) **Driving** — that is `gap-loop`/`quiesce`. (d) **Measuring done-ness** — that is Prisma.

## Parameters
| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<goal>"` (positional) | — | the goal to build a vehicle for. Omit when `--from-handoff` supplies it. |
| `--from-handoff` | *(none)* | path to a validated `handoff-as-prompt` — sources `for_goal` + `context_lock` typed (no re-inference). |
| `--from-dod` | *(none)* | path to a validated `dod-as-prompt` — the destination's coordinates; the route is derived toward *these leaves*, not a vibe. |
| `--output` | `text` | `text` \| `json` (emit the `system-as-prompt` envelope). **Convention mirrors the family** — `--output`, not `--format`/`--kind`. |
| `--dry-run` | off | derive + print, do not write the envelope file. |

## The algorithm (3 rules + the guard — each a gate, not a vibe)

```text
P0  CONTEXT-LOCK   inherit from --from-handoff (context/purpose/stakeholder/targets).
                   | absent -> SpecError. "Minimal" is meaningless without whose day it fits in.
                   v
P1  MINIMAL        propose the single recurring ACTION so small refusing it is practically impossible.
                   | GATE: state `why_minimal` — the concrete cost + why it cannot reasonably be refused
                   |   in THIS context_lock. "it is small" unfalsifiable -> theater (anti-theater R2) -> re-derive.
                   | GATE: if the action enumerates sub-steps it is NOT minimal -> decompose further.
                   | {ts:511} "tao facil que seja praticamente impossivel voce dizer nao"  (Fogg / Lally 2010)
                   v
P2  CONSISTENCY    bind it to a concrete recurring TRIGGER (if-then) + a CADENCE relative to that trigger.
                   | GATE: "when I feel like it" is not a trigger. Deterministic cue where one exists.
                   | {ts:518} "melhor 10 min de caminhada por dia do que 3 horas"  (Gollwitzer & Sheeran d=0.65)
                   v
P3  SIGNAL         derive the Metron-ADMISSIBLE adherence signal (NOT a run-count — that is blacklisted):
                   |   "does the mechanism still FIRE — AND does firing still MOVE the goal?"
                   | decision-gated (no-fire => rebuild) + outcome-anchored (the system's purpose IS the goal)
                   v
REV REVISION       derive the falsifier: adherence-high + goal-movement-absent after N => the VEHICLE is wrong.
                   | this is the guard the source video LACKS and the answer to Eliason (see Caveats).
                   v
    EMIT           system-as-prompt envelope -> validate -> ooda-loop DECIDE gate (which routes; never authors)
```

**The homework question, verbatim** (`{ts:604-617}`) — it *is* the algorithm's intent: *"Pensa na meta que você mais queria alcançar… Agora pega e **esquece essa meta** e pergunte para você mesmo: qual é o **menor sistema** que vai te levar até essa meta?"*

## The typed triple (the wiring — no invented interface)
| Envelope | Produced by | Consumed as |
|---|---|---|
| `handoff-as-prompt` | `goal-recovery` (OBSERVE) | driver `--state-source=handoff:<file>` |
| `dod-as-prompt` | Prisma (ORIENT-a) | driver `--condition=<termination_predicate>` |
| **`system-as-prompt`** | **THIS (ORIENT-b)** | **`minimal_system.action`** → driver **positional `"<instructions>"`** — *"extra free-text appended to the goal"* (`gap-loop` SKILL.md:194). Only the `.action` **string** is passed; `minimal_system` itself is an object (trigger/action/why_minimal/cadence) whose other fields govern the derivation, not the driver call. ⚠️ **No flag for "the recurring action" exists** and inventing one would be interface fabrication (anti-theater R4). The recurring step rides the existing surface. |

Validator-gated like its siblings (`skills/goal-recovery/bin/validate_envelope.py`). The triple is **revisable, not frozen** — REV exists precisely to revise it.

## Composition (DRY — reimplements nothing)
| Concern | Owned by (cited, not rebuilt) |
|---|---|
| recover the goal | `skills/goal-recovery` |
| measure the destination | `skills/decompose-abstract-to-measurable` (Prisma) |
| **derive the route** | **THIS** |
| gate / route | `skills/ooda-loop` DECIDE (`COWORK-AUTONOMY-POLICY` bands + `[C17]` §2 + `anti-theater` 9Q) |
| **drive** | `skills/gap-loop` / `skills/quiesce` |
| **verify** (`verifier != generator`) | the driver's own audit — `maos:persona-pipeline` / `perspective-trio`. **NEVER re-implemented here** (Huang et al. 2310.01798). |
| measure over time | `agentic-observability-protocol` (Metron) |

**The anti-duplication test this skill must keep passing**: it contains **no loop**, **no convergence gate**, **no verifier**. If any appears here, it has become `gap-loop`/`ooda-loop` re-implemented → **cut it** (Gordian).

## Caveats (honest — deleting these makes this marketing)
| ⚠️ | The honest statement |
|---|---|
| **The source video is n=1** | An **anecdote** (a youtuber citing a youtuber) — the **weakest evidence** behind this skill. Adoption is **selective** by the operator's own instruction (*"leitura é obrigatória, a adoção é seletiva"*): the **three rules** map onto real research; the raw thesis *"systems > goals"* is **NOT adopted**. |
| **What IS evidence-backed** | Gollwitzer & Sheeran 2006 implementation intentions (**d=0.65**, 94 tests, 8,000+ participants; 2024: 642 tests) → P2 · Fogg *Tiny Habits* / Lally 2010 (~66d median) → P1 · Michie BCT self-monitoring → P3. |
| **The Eliason counter** | *"Systems without goals is a path to mediocrity."* Answered by the operator's own formulation — *goals stay valid, as **direction***. We adopt the **complement**, never the substitution. **REV is the guard the video lacks.** |
| **The Metron tension — narrow, real** | *"Track the system, not the goal's number"* **does not contradict** Metron — it is its §1 verbatim (*"Measure-to-Inform, Manage-to-Outcome"*). **BUT** §5 gate-2 demands outcome-anchored and the **vanity blacklist bans activity metrics** ⇒ *"count how many times we ran it"* is **blacklisted**. Surviving formulation: **system = managed object; goal's number = informing signal**; admissible signal = *fires + still moves*. |
| **No cadence substrate exists** | `cadence` is a **predicate string** consumed per-round — **not a scheduled job, not an adherence ledger**. The only `launchd` here is machine-health; `bin/dogfood-mark`/`tally` is a maturity **cycle-counter** (collapses time; no `should` denominator; subject is a *tool*). Its **format** is reusable if longitudinal tracking is ever built. It is not one today. |

## Anti-patterns (do NOT)
1. ❌ **Ship a plan as a "system"** — a multi-step plan is not minimal (P1 gate). A system is one recurring step.
2. ❌ **`why_minimal` as unfalsifiable prose** ("it's small") — state the cost + why it can't be refused, else it is R2 theater.
3. ❌ **A wish as a trigger** ("when I have time") — P2 needs a concrete recurring cue.
4. ❌ **Activity-count as the signal** — Metron vanity blacklist. Use *fires + moves*.
5. ❌ **Blame the driver** when adherence is high and nothing moved — REV falsifies the **vehicle**.
6. ❌ **Grow a loop/gate/verifier in here** — that is `ooda-loop`/`gap-loop` re-implemented → cut (Gordian).
7. ❌ **Invent a driver flag** for the recurring action — none exists; use the positional (anti-theater R4).
8. ❌ **Auto-derive a system for the operator's personal goals** — HUMAN_DOMAIN; on request only.
9. ❌ **Ceremony on a trivial action** — its system IS the single step (Gordian floor).

## Quality Tests (6/6 self-validity)
1. **Self-Application** — this skill's own goal ("close the vehicle gap") has a system: R9 fires → derive → envelope → ORIENT-b → driver. ✅
2. **Non-Contradiction** — composes goal-recovery/Prisma/ooda-loop/gap-loop/Metron without duplicating; the Metron tension is **resolved explicitly** (§Caveats), not glossed. ✅
3. **Survival** — applied to itself it demands a minimal recurring vehicle; it *is* one step in an existing loop, not a new loop. ✅
4. **Bounded-Responsibility** — derives only (no loop/gate/verifier) · Gordian floor · HUMAN_DOMAIN carve-out · law's §8 DUED. ✅
5. **Explicit-Exception** — the 4 not-use cases + `[C17]` §0 SER. ✅
6. **Utility-Sunset** — inherits the law's DUED: retire when `ooda-loop` ORIENT absorbs system-construction natively (E6), or agents internalize build-the-vehicle-first (E3, ≥10 zero-regret). ✅

## Refs
- **Law (SSOT)**: akasha `~/.claude/rules/derive-system-from-goal.md` (`[C22]`) · fire-point `anti-theater-grounding-protocol` Layer-5 **R9**.
- **Siblings**: `skills/ooda-loop` (the conductor — ORIENT-b is here) · `skills/goal-recovery` (+ its `bin/validate_envelope.py`) · `skills/decompose-abstract-to-measurable` (Prisma — ORIENT-a) · `skills/gap-loop` · `skills/quiesce`.
- **Sources**: transcript `~/Downloads/transcricao_pessoas_inteligentes_sistemas.md` (Lucas Yano 2026-07-05, read in full — `{ts:411,451,511,518,554,604-617}`) · `~/Downloads/framework_12_etapas.csv`.
- **Evidence**: Gollwitzer & Sheeran (2006) · Fogg *Tiny Habits* · Lally et al. (2010) · Michie BCT taxonomy · Nat Eliason (the counter) · Huang et al. 2310.01798 (why the verifier stays independent, and elsewhere).
- **Etymology**: μέθοδος = μετά + ὁδός; ὁδός + μέτρον = ὁδόμετρον (odometer) — *Hodos* the road, *Metron* the measure.
- **Naming**: `[[anima]]` per `[C-naming]` — 12/12 + 4/4, conf 0.97. Registered: `bin/artifact-registry` (`name` + `create`). Rejected: `minimum-viable-system` (taken — SYSTEMology) · `poros` (pt-BR fluency).
- Cross-link: `[[derive-system-from-goal]]` · soul-name *Hodos* (ὁδός).
