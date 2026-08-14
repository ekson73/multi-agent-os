---
name: refine-braindump-to-prompt
version: "0.1.0"
description: |
  Turn ONE raw operator braindump into ONE polished, ready-to-execute PROMPT that drives
  an agent/team end-to-end with minimum HITL. Five phases: RECOVER (DoR · motivation · goal
  via goal-recovery + DoD-as-measurable via decompose-abstract-to-measurable) → DRAFT
  (first-cut prompt in the chosen architecture profile) → REFINE (bounded loop over the
  DRAFT PROMPT itself: N rounds × N distinct lenses, stop only when min-revisions AND
  consecutive-clean-rounds are both satisfied) → RED-TEAM (independent adversarial
  refutation) → RENDER (ONE prompt + machine envelope). Parameterized by prompt-architecture
  PROFILES (`--architecture`); profile #1 is `gauntlet-loop`. A thin preset that COMPOSES
  existing primitives (goal-recovery, decompose-abstract-to-measurable, convergence-engine,
  perspective-trio, cascade-resolver, red-team, council-gate, prompt-context-engineer) —
  reimplements nothing. Accepts: --architecture, --dor, --motivation, --goal, --condition,
  --principles, --min-revisions, --clean-rounds, --lenses, --max-rounds, --dry-run, --output,
  --persist, --user-lang, --agentic-lang.
  Use when the operator has a messy dump of intent and wants it lapidated into one executable
  prompt: "turn this braindump into a prompt", "lapide este braindump", "polish this dump into
  something runnable", "make an executable prompt out of this", "destrinche isto e me devolva
  um prompt".
  Triggers: "refine-braindump-to-prompt", "/refine-braindump-to-prompt", "braindump to prompt",
  "lapidar braindump", "polish braindump", "one executable prompt from this dump", "gauntlet
  loop prompt".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch
---

# Refine-Braindump-to-Prompt

> **Soul-name**: *Lapidary* — display only. The system-name `refine-braindump-to-prompt` is the
> canonical slug, the `/command` trigger, and the `--json.name`. English *lapidary* (L. *lapidarius*,
> stonecutter) carries a figurative sense attested since ~1325: **prose of notable conciseness,
> precision and refinement**. That figurative sense *is* this skill's deliverable. (Not *lapidate*
> — a different branch of the same root, meaning "to stone to death".)

Thin **braindump→prompt** preset. It does not re-implement recovery, measurement, convergence,
adversarial critique, or delegation — it sequences five phases, and **every phase lands on a
primitive that already exists in this repo**.

## Purpose

Take ONE raw, unstructured operator braindump — mixed directives, cartesian resource lists,
session-meta wrappers — and lapidate it into ONE prompt that an agent (or a team) can execute
end-to-end with minimum human-in-the-loop. The distinctive act is **REFINE**: a bounded loop whose
*object of criticism is the draft prompt itself*, run from multiple distinct lenses, terminating
only on a two-part condition (a floor AND a dryness test), never on a single clean pass.

## When to use

- A braindump exists and the operator wants it *runnable*, not merely *classified*.
- The intent is real but the expression is tangled, recursive, or self-referential.
- The output must carry DoR/motivation/goal/DoD so a fresh amnesic agent can execute it cold.
- A specific prompt architecture is wanted (`--architecture=gauntlet-loop`).

## When **not** to use

- "What in this dump is already done?" → `directive-braindump-triage` (classification ledger).
- "Make this dump into a reusable TOOL" → `agentic-tool-forge` (forges an artifact, not a prompt).
- "File this dump as vault knowledge" → the operator's vault protocol (`braindump-distill`).
- "Ship this feature idea end-to-end" → `enhance-pipeline` (delivers a PR, not a prompt).
- "Re-target existing content for another audience" → `content-recast`.
- One clear sentence already states the task → just write the prompt inline (§Skip S1).
- Destructive ops (force-push protected, drop prod) — always HITL.

## Trigger Phrases

- "refine-braindump-to-prompt" / "/refine-braindump-to-prompt"
- "turn this braindump into a prompt" / "lapide este braindump"
- "one executable prompt from this dump" / "polish this dump into something runnable"
- "gauntlet loop prompt for <X>"

## The five phases (the pipeline predicate)

```text
RECOVER   := DISSECT   open the dump; type every part for what it IS
                        (halt: a part that cannot be typed — "I don't know what this is")
           + RELATE    map how the parts constrain each other
                        (halt: a cycle, a dangling dependency, an unresolvable reference)
           + CATALOGUE emit parts table + relation map  <- REQUIRED OUTPUTS, not incidental
           + PRISM     DoD-as-measurable, on abstract criteria only
           + DISTILL   drop session-meta; emit the drop-list WITH REASONS
           + recover{DoR, motivation, goal}
           + derive recurring mechanism IFF the goal recurs
DRAFT     := select architecture profile + render first-cut prompt
REFINE    := loop{ critique draft from N distinct lenses -> correct }
             until (revisions >= min_revisions) AND (clean_rounds >= clean_rounds_required)
             capped by the economic stop
RED-TEAM  := independent adversarial refutation of the DRAFT (verifier != generator)
RENDER    := emit ONE prompt + machine envelope + persist decision
```

A phase is COMPLETE when its primitive returns a structured artifact the next phase consumes.
The pipeline is DONE when RENDER emits the prompt, or — under `--dry-run` — the plan for it.

## One hard boundary — COMPREHEND before TRANSFORM (binding)

The pipeline has **one hard boundary and one soft one**. They are not equal, and treating them as
equal is itself an error:

```text
COMPREHEND (lossless)               ‖ HARD ‖   TRANSFORM (lossy — i.e. DECIDING)
dissect -> type -> relate -> catalogue         distill  ~soft~  shape
                    + prism                    (drop-list)      (DRAFT->REFINE->RED-TEAM->RENDER)
                    RECOVER                            RECOVER  |  the rest
```

The sharpest cut in the whole pipeline is **lossless ↔ lossy**, and the criterion under it is:

> **A decision destroys an alternative. A recognition does not.**

Deciding is not a fourth stage sitting beside distill and shape — it is **what makes that side
lossy**. Distilling *is* deciding what to discard; shaping *is* deciding what form. Comprehension
recognizes and can be redone; transformation decides and kills the branches it did not take.

| | Receives | Goal | Anything lost? | Reversible? |
|---|---|---|---|---|
| dissect · type · **relate** · catalogue | an opaque whole | see, name + connect the parts | **no** — all kept, now legible | yes |
| distill | a legible mixture | keep only what carries constraint | yes — an alternative dies | no |
| shape | a solid | reveal form | yes — an alternative dies | no |

**Relate is not cataloguing.** A catalogue is a *list*; relations make it a *graph*. You can hold a
complete inventory and still not understand the thing, because understanding a system means knowing
its **dependencies**, not its contents. Measured on the originating dogfood: typing the parts found
five of them; the decisive insight — that the loop-spec *operationalizes* the DoD — was an **edge**,
not a node, and it became this skill's core predicate.

> **Inherited, not invented.** The ancestor protocol `braindump-distill` (*Alambique*) has emitted an
> interdependency map per run since its first row (22 in its ledger). This skill shipped without one.
> `RELATE` closes that composition gap — the discipline existed upstream and was silently dropped.

### The lossless movement is a PREDICATE, not a list

`dissect · identify · relate · prism · catalogue` is an **instance**, not a definition. A fixed list
caps a fresh agent at whatever its author happened to think of. The membership test does not:

> An operation belongs to the lossless movement **iff**
> **(a)** it discards nothing;
> **(b)** after it you can answer a question you could not before;
> **(c)** it can halt on *"I cannot do this to this input"*, **or** it emits an artifact.

Extend by the test, never by taste. `(c)` is where the two-axis classification lands: an operation
that halts is a **gate**; one that emits is an **artifact**; one that does neither is ceremony.

**Watch for straddlers.** *Separate* is a member in the sense **distinguish** (lossless) and belongs
on the lossy side in the sense **set aside** — one word, both sides of the hard boundary. A list
cannot catch that; only the test can. When a candidate operation is ambiguous, resolve it by asking
(a): *does this instance discard anything?*

**Escalation, not exhaustion:** run the members the input actually needs. A dump with no abstract
criterion does not need `prism`; one with three independent parts barely needs `relate`. Membership
says what *may* enter, not what *must* run.

**The hard boundary — you cannot justify a discard you do not understand.** Distilling without
dissecting discards by heuristic — by length, by position, by vibe — and is right only by luck.
Test: *can you invert the order?* Distill before dissect → **impossible**. This boundary gets a gate.

**The soft boundary — shaping micro-separates continuously.** Every refine round discards a little
(an adjective replaced by a named bar is a discard). So distill→shape is a strong *ordering
preference*, not a wall: the first distillation differs from a refine-round drop in **scale**
(dropping most of the input mass ≠ replacing one clause), not in kind. This boundary gets no gate.

**You still cannot facet a mixture.** Shaping without a *first* distillation does not yield a rough
prompt; it yields a **polished wrapper**, because the shaping loop faithfully refines whatever mass
it is handed — including mass that was never signal.

So RECOVER spans the hard boundary and can **halt on either side**: on a part it cannot type
(*"I don't know what this is"*), on a relation it cannot resolve, or on a mass it cannot justify
dropping.

**Classify a candidate stage on two axes, not one** — *can it refuse?* (gate) crossed with
*pertinent · related · useful?* (worth having):

| | is a gate | not a gate |
|---|---|---|
| **passes** | keep as a **gate** | keep as an **artifact** — e.g. the catalogue + relation map |
| **fails** | **over-gating** — ceremony with teeth | pure ceremony — a label |

Over-gating is the dangerous quadrant: a stage that can halt *looks* rigorous, so a useless one
survives review by blocking. One axis alone cannot separate the catalogue (not-a-gate, essential)
from a certification ritual (a gate, worthless).

### The catalogue is a REQUIRED output (the absorption law)

> **The movement with a visible output absorbs the movement without one.**

Shaping is visible — you see the finished prompt. Separation is semi-visible — a drop-list exists
*if someone wrote one*. Comprehension is **invisible**: understanding leaves no artifact at all
unless forced to. So pipelines drift toward being named, and then built, for their last movement.
This is a gradient, not carelessness, and it recurs at every level.

Therefore RECOVER MUST emit **both** the parts catalogue and the drop-list-with-reasons. They are
not debug output. Without them the answer to *"what was in there, and what did you drop, and why"*
does not exist — and if that answer does not exist, comprehension did not happen; parsing did.

**Prism only abstract criteria** (the DoD, a quality bar). Prismming a concrete part is ceremony.

> **House lineage.** MOVEMENT 2 is the same operation the operator's vault protocol
> `braindump-distill` (*Alambique*) performs at a different terminus; MOVEMENT 3 gives this skill
> its soul-name (*Lapidary*). Sequential, not rival — a still, then a lapidary. No third name is
> minted for MOVEMENT 1: it is named by its outputs (catalogue + drop-list), which is the point.

> **House pair.** This skill owns MOVEMENT 2 and is soul-named for it (*Lapidary*). MOVEMENT 1 is
> the same operation the operator's vault protocol `braindump-distill` (*Alambique*) performs at a
> different terminus. The two names already exist and are **sequential, not rival** — a still, then
> a lapidary. This skill inlines its own separation (goal-oriented) rather than composing the
> vault's (artifact-oriented), because the two separations sort for different things.

**Measured, not asserted** (`examples/DOGFOOD-gauntlet.md`): on the originating braindump, the two
longest passages — a cartesian resource list and a 40-item principle enumeration — contributed
**zero** constraints to the rendered prompt, while its shortest clause became the acceptance metric.
Most of the input was mass. Separation is where the work is; shaping is where it becomes visible.

### Recursion clause (the discipline must propagate)

A rendered prompt SHALL itself carry separate-before-shape into the work it drives. Concretely,
BUILD-METHOD must require the executing agent to **decompose the target and name what is out of
scope** before building — never to begin shaping an undifferentiated goal. A prompt that skips this
reproduces, one level down, the exact failure this skill exists to prevent.

## How it works

```text
operator invokes /refine-braindump-to-prompt "<braindump-path-or-text>"
        |
        v   resolve flags -> profile defaults unless overridden
        v
  PHASE 1 RECOVER  -> {dor, motivation, goal, dod_spec, system?}
        |
        v
  PHASE 2 DRAFT    -> draft_prompt v0 (in the profile's shape)
        |
        v
  PHASE 3 REFINE   -> draft_prompt vN  (loop; see §Stopping predicate)
        |              ^                     |
        |              +-- gaps found -------+
        v
  PHASE 4 RED-TEAM -> refutation verdict (CLEAR | REFUTED -> back to REFINE)
        |
        v
  PHASE 5 RENDER   -> ONE prompt + envelope + persist
        |
        v   emit exactly ONE STOP marker as the last line of the turn
```

## Composition (the wiring it emits)

Every phase prefers an **in-repo / host primitive**. Optional enhancements are invoked only
*if installed* — never a hard dependency.

| Phase | In-repo primitive (ALWAYS) | Optional enhancement (IF installed) |
|---|---|---|
| **1 RECOVER** | `skills/goal-recovery` (source: `braindump`) · `skills/decompose-abstract-to-measurable` (DoD → measurable) · `skills/derive-system-from-goal` (only if the goal recurs) | `directive-braindump-triage` (user-scope — pre-classify already-done atoms) |
| **2 DRAFT** | `agents/prompt-context-engineer` (the prompt-craft seat) · the selected `profiles/<arch>.md` | — |
| **3 REFINE** | `skills/convergence-engine` (REFINE regime + economic stop) · `agents/perspective-trio` (horizontal lens diversity) · `agents/cascade-resolver` (sequential *diverse* re-attempts) | `agents/persona-pipeline` (6-stage board on high-stakes) |
| **4 RED-TEAM** | `skills/red-team` · `bin/convergence-guard` (deterministic independence enforcement) | `skills/council-gate` (fires only if the prompt would authorise a HUMAN_DOMAIN action) |
| **5 RENDER** | `Write` + `skills/worktree-policy` (write discipline) | `persist-locus` (vault-scope — measures the persist target) |

> **Anti-NIH discipline**: this skill EMITS invocations of the above; it never inlines their
> logic. A missing optional primitive degrades gracefully with a one-line diagnostic.

## Stopping predicate (the doctrinal core)

Three sources disagree about when an agentic loop may stop, and the disagreement is load-bearing:

| Source | Stopping rule |
|---|---|
| Shumer's aim-prompt (and skills derived from it) | *"loop until utterly perfect — you are the brake"* → **none** |
| Osmani, *Loop Engineering* | clear stopping rules are the **5th mandatory component** (cost · attempts · wall-clock · gain-stagnation) |
| `skills/convergence-engine` (this repo) | economic stop `n* ≤ 3-4`; floor is human-parity, **not** perfection; looping past `n*` costs 4-10× for <1% gain |

**The synthesis this skill encodes — the Verifiability Gate:**

```text
long_loop_licensed := bar_is_machine_verifiable
                    AND critic_is_independent_of_builder
                    AND evidence_is_directly_inspectable

if long_loop_licensed -> cap = profile budget (attempts | cost | wall-clock | stagnation delta)
else                  -> cap = convergence-engine economic stop (n* <= 3-4)
NEVER                 -> unbounded, on work that is irreversible, costly, or unobservable
```

A long loop pays off **only when the gain signal is real** — i.e. when an independent critic can
measure the artifact against an external bar. Absent that, extra rounds buy self-assessment, which
is the very bias the loop was built to defeat. The REFINE loop therefore terminates on a
**two-part** condition, never a single clean pass:

```text
stop_refine := (revisions >= --min-revisions)          # floor: 3 by default
           AND (clean_rounds >= --clean-rounds)        # dryness: 3 consecutive, by default
           AND (rounds <= --max-rounds)                # hard cap; exceeded -> STOP-HITL
```

The floor exists because a draft that *looks* clean on pass 1 usually is not; the dryness test
exists because a single clean pass is noise. Each round uses `--lenses` **distinct** perspectives
(default 3); a round that reuses a lens does not count toward `clean_rounds`.

## Architecture profiles

`profiles/<name>.md` supplies the DRAFT shape, the lens roster, and the loop budget. The engine is
profile-agnostic; adding an architecture is adding a file, never a new skill.

| Profile | Shape | Use when |
|---|---|---|
| `default` | goal · constraints · acceptance · stop-condition · deliverables | any braindump with no named target architecture |
| `gauntlet-loop` | task · build-method · quality-bar, fan-out builders + blind critic, extreme reference | the work is buildable, observable, reversible, and has a nameable external bar |

`--architecture=gauntlet-loop` is a **profile of this skill**, not the third-party skill of the same
concept. See `profiles/gauntlet-loop.md` for prior-art attribution and the divergence table.

## Override parameters

| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<braindump>"` (positional) | *required* | path to a braindump file, or inline text |
| `--architecture` | `default` | `default` \| `gauntlet-loop` \| `<profile-name>` (any file in `profiles/`) |
| `--dor` | `auto` | override the recovered Definition of Ready |
| `--motivation` | `auto` | override the recovered motivation |
| `--goal` | `auto` | override the recovered goal |
| `--condition` | `auto` | override the DoD/stop-condition (measurable spec) |
| `--principles` | `auto` | comma list, or `auto` = inherit the host's governance corpus by reference |
| `--min-revisions` | `3` | REFINE floor — minimum revisions regardless of apparent cleanliness |
| `--clean-rounds` | `3` | consecutive gap-free rounds required to exit REFINE |
| `--lenses` | `3` | distinct perspectives per round; a repeated lens does not count |
| `--max-rounds` | `12` | hard cap; exceeded → `STOP-HITL` (diminishing returns) |
| `--dry-run` | `false` | run RECOVER→REFINE and emit the plan; STOP before RENDER writes |
| `--output` | `table` | `table` \| `list` \| `json` (machine contract — see §Output contract) |
| `--persist` | *(none)* | path to write the rendered prompt; omitted → return inline only |
| `--user-lang` | `auto` | operator-facing prose language (mirrors the host's language policy) |
| `--agentic-lang` | `en-us` | language of the RENDERED prompt (agent register) |

## Output contract (`--output=json`)

```jsonc
{ "skill": "refine-braindump-to-prompt",
  "phase": "RECOVER|DRAFT|REFINE|RED-TEAM|RENDER|done",
  "status": "ok|error|hitl",
  "stop_marker": "STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE",
  "architecture": "default|gauntlet-loop|<profile>",
  "recovered": { "dor": "", "motivation": "", "goal": "", "condition": {} },
  "refine": { "revisions": 0, "clean_rounds": 0, "rounds": 0, "lenses_used": [] },
  "red_team": { "verdict": "CLEAR|REFUTED", "findings": [] },
  "verifiability_gate": { "machine_verifiable": false, "independent_critic": false,
                          "inspectable_evidence": false, "long_loop_licensed": false },
  "prompt": "<the rendered prompt, or null under --dry-run>",
  "dropped_session_meta": [] }
```

Exit codes: `0` = prompt rendered OR plan emitted (`--dry-run`) · `1` = error (`STOP-ERROR`) ·
`2` = HITL escalation (`STOP-HITL`). Mirrors the repo's AI-native structured-output discipline.

## STOP-marker grammar

Emit exactly ONE terminal marker as the last line of each turn — the shared `/goal` Stop-hook
evaluator reads it:

```text
<!--ORCH-STATUS: STOP-DONE -->     prompt rendered (or plan emitted under --dry-run)
<!--ORCH-STATUS: STOP-HITL -->     HITL escalation required (also prepend above any action block)
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (subagent / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      phase done; pipeline continues; evaluator decides next turn
```

## Relationship to siblings

| Tool | Input | Output |
|---|---|---|
| `refine-braindump-to-prompt` (this) | ONE braindump | ONE executable prompt |
| `enhance-pipeline` | ONE feature | a shipped PR |
| `auto-pilot` | ONE goal | decompose → delegate → converge |
| `quiesce` | the SESSION | steady state |
| `converge` | N proposals | one 5-act merge |
| `agentic-tool-forge` | ONE recurring intent | a reusable TOOL |
| `directive-braindump-triage` (user-scope) | ONE braindump | a classification ledger |

This skill MAY hand its rendered prompt to `auto-pilot`/`quiesce` for execution; it never executes
the prompt itself (the operator names the target).

## Protocol Rules (anti-loop invariants + bounds)

- REFINE stops on the **two-part** predicate; a single clean pass never terminates it.
- `--max-rounds` (default 12) is a hard cap → `STOP-HITL` on exhaustion.
- RED-TEAM's critic MUST be independent of the DRAFT author (`bin/convergence-guard`); if
  independence cannot be secured on a high-stakes prompt → **HOLD, do not force**.
- Session-meta (`/enhance` wrappers, pep-talk, "do a good job") is DROPPED in RECOVER and listed
  in `dropped_session_meta` — never silently.
- A cartesian list of resources in the braindump is **not** a requirement to instantiate each one.
- Worktree discipline always on (`skills/worktree-policy`); never commit to main.
- Delegation depth ≤ 2; parallel fan-out ≤ 3 per round.
- Exactly ONE STOP marker per turn.
- External research is time-boxed and cited — never fabricate prior art.
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, prod/irreversible,
  cross-org) ALWAYS halt the pipeline → HITL.

## Failure modes

- **Empty / unreadable braindump** → `STOP-ERROR` before RECOVER (nothing to lapidate).
- **RECOVER cannot find a goal** → `STOP-HITL` carrying the ranked hypotheses (never guess a goal).
- **DoD not measurable after `decompose-abstract-to-measurable`** (`inconclusive.flag`) →
  `STOP-HITL`; a prompt with an unmeasurable stop-condition is the failure this skill exists to prevent.
- **`--max-rounds` exhausted** → `STOP-HITL` (diminishing returns → escalate).
- **RED-TEAM independence unavailable at high stakes** → `STOP-HITL` (hold, don't force).
- **Profile not found** → `STOP-ERROR` listing available profiles.

## Skip conditions (proportionality)

- **S1** the intent is already one clear sentence → write the prompt inline; skip the pipeline.
- **S2** the operator supplied the prompt and wants only execution → hand to `auto-pilot`.
- **S3** mid-orchestration under a parent that already recovered the goal upstream.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: the skill is validated on the braindump that originated it before being declared done.
- **Persist-over-fail**: write-ahead-checkpoint each obligation BEFORE executing.
- **DRY / KIS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **Verifier ≠ generator** — the critic never inherits the builder's context.
- **Boy-Scout** — leave every repo cleaner than found.

## Examples

```text
/refine-braindump-to-prompt "~/dumps/2026-08-14-gauntlet.braindump.md"
/refine-braindump-to-prompt "<dump>" --architecture=gauntlet-loop
/refine-braindump-to-prompt "<dump>" --dry-run --output=json
/refine-braindump-to-prompt "<dump>" --min-revisions=5 --clean-rounds=2 --lenses=4
/refine-braindump-to-prompt "<dump>" --persist=./prompts/migration.prompt.md
```

## Validation

- `tests/validate-plugin.sh` enforces: `skills/refine-braindump-to-prompt/SKILL.md` exists with
  valid frontmatter; `commands/refine-braindump-to-prompt.md` carries matching `name:`.
- `--dry-run` proves composition: grep the run — only `Task`-delegation to existing skills/agents
  plus native tools; zero reimplementation.
- Dogfood gate: running the skill on its own originating braindump must yield a prompt containing
  (a) a machine-verifiable goal, (b) an independent critic, (c) an explicit stopping rule.

## Related

- `commands/refine-braindump-to-prompt.md` — operator-facing command surface
- `profiles/default.md` · `profiles/gauntlet-loop.md` — architecture profiles
- `skills/goal-recovery/SKILL.md` — PHASE 1 recovery (braindump source)
- `skills/decompose-abstract-to-measurable/SKILL.md` — PHASE 1 DoD measurement (Prisma)
- `skills/convergence-engine/SKILL.md` — PHASE 3 loop + economic stop
- `skills/red-team/SKILL.md` — PHASE 4 adversarial refutation (Elenchus)
- `skills/council-gate/SKILL.md` — HUMAN_DOMAIN gate (Boule)
- `skills/enhance-pipeline/SKILL.md` — sibling preset (feature → PR)
- `agents/prompt-context-engineer.md` — the prompt-craft seat
- `skills/worktree-policy/SKILL.md` — write discipline

## Versioning

- v0.1.0 (initial) — five-phase braindump→prompt lifecycle composing in-repo primitives;
  architecture profiles (`default`, `gauntlet-loop`); the Verifiability Gate stopping doctrine
  (synthesising Shumer's unbounded loop, Osmani's mandatory stopping rules, and this repo's
  economic stop); two-part REFINE termination (floor AND dryness); STOP-marker grammar reuse;
  depth/round bounds; `--output=json` contract.

## License

MIT (matches multi-agent-os repo `LICENSE`).
