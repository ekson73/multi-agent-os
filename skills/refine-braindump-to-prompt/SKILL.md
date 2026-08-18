---
name: refine-braindump-to-prompt
version: "0.3.1"
description: >-
  Lapidate ONE raw operator braindump into ONE polished, ready-to-execute PROMPT. Five phases:
  RECOVER (dissect - relate - catalogue - prism - distill; emits the parts map and the drop-list
  with reasons) -> DRAFT (in an architecture profile) -> REFINE (N rounds x N distinct lenses;
  economic stop by default, floor only where the profile licenses the long loop) -> RED-TEAM
  (independent refutation, verifier != generator) -> RENDER (one prompt + machine envelope +
  multi-sink emission). Use when a dump must become executable work rather than a ledger, an
  envelope or a PR. Parameterized by architecture profiles (--architecture, incl. gauntlet-loop)
  and by output sinks (--output-target: stdout, clipboard, vault, git-repo, agentic-tool).
  Composes in-repo primitives; reimplements nothing.
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
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
*object of criticism is the draft prompt itself*, run from multiple distinct lenses, terminating on
the economic stop (`n*` (per `convergence-engine`)) by default — and, **only where a profile licenses the long loop**, on
a two-part condition (a floor AND a dryness test) rather than a single clean pass.

## When to use

- A braindump exists and the operator wants it *runnable*, not merely *classified*.
- The intent is real but the expression is tangled, recursive, or self-referential.
- The output must carry DoR/motivation/goal/DoD so a fresh amnesic agent can execute it cold.
- A specific prompt architecture is wanted (`--architecture=gauntlet-loop`).

## When **not** to use

The five hand-offs below are terminal when this skill is invoked anyway: it does **not** silently
do the neighbour's job. Each ends the run with `STOP-DONE` · `skipped.condition: "wrong-tool"` ·
`skipped.handed_to: "<sibling>"` — the same field pair §Skip conditions uses, so a caller reads
one shape for every non-entry.

- "What in this dump is already done?" → `directive-braindump-triage` (classification ledger).
- "Make this dump into a reusable TOOL" → `agentic-tool-forge` (forges an artifact, not a prompt).
- "File this dump as vault knowledge" → the operator's vault protocol (`braindump-distill`).
- "Ship this feature idea end-to-end" → `enhance-pipeline` (delivers a PR, not a prompt).
- "Re-target existing content for another audience" → `content-recast`.
- One clear sentence already states the task → just write the prompt inline (§Skip S1 · `STOP-DONE`).
- **Destructive ops** (force-push protected, drop prod) — **always HITL → `STOP-HITL`**, carrying the
  requested op and the guardrail it touches. This is a halt, not routing advice; it was markerless
  and is one of the 11 the v0.3.0 eval found outside §Failure modes.

## Trigger Phrases

- "refine-braindump-to-prompt" / "/maos:refine-braindump-to-prompt"
- "turn this braindump into a prompt" / "lapide este braindump"
- "one executable prompt from this dump" / "polish this dump into something runnable"
- "gauntlet loop prompt for <X>"

## The five phases (the pipeline predicate)

```text
RECOVER   := DISSECT   open the dump; type every part for what it IS
                        (halt: a part that cannot be typed — "I don't know what this is",
                         OR a referent that blocks the goal/DoD — see proportionality)
           + RELATE    map how the parts constrain each other
                        (halt: a cycle, or a dangling dependency that blocks the goal)
           + CATALOGUE emit parts table + relation map  <- REQUIRED OUTPUTS, not incidental
           + recover{DoR, motivation, goal, DoD}        <- recognition: still lossless
           + PRISM     the RECOVERED DoD -> measurable, abstract criteria only
                        (inner-first: Prisma(dod-recovery()) — you cannot prism
                         a DoD you have not recovered)
           + DISTILL   drop session-meta; emit the drop-list WITH REASONS
                        <- LAST: the only lossy step, run over evidence
           + derive recurring mechanism IFF the goal recurs
DRAFT     := select architecture profile + render first-cut prompt
REFINE    := loop{ critique draft from N distinct lenses -> correct }
             if long_loop_licensed: until (revisions >= min_revisions)
                                      AND (clean_rounds >= clean_rounds_required)
             else:                  until the economic stop (n*, per convergence-engine), floor OFF
RED-TEAM  := independent adversarial refutation of the DRAFT (verifier != generator)
             REFUTED -> classify: craft-defect => back to REFINE (<= max_redteam_cycles)
                                  missing-fact => STOP-HITL now (rounds cannot invent facts)
RENDER    := emit ONE prompt + machine envelope + persist decision
             (persist decision = the recorded CHOICE of sinks; with no --output-target
              the decision is "inline only" and IS the record, not a no-op)
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
criterion does not need `prism`. Membership says what *may* enter, not what *must* run.

⚠️ **`dissect` and `relate` are NOT skippable.** An earlier form of this clause offered *"one with
three independent parts barely needs `relate`"* — and that is precisely backwards on the input class
it matters for. A referentially-empty dump (*"fazer aquilo que o fulano sugeriu"*) presents parts
that **look** independent on a surface read; skipping `relate` there means never discovering that
every part hangs on an absent referent, and reaching DRAFT with a guessed goal. The one gate that
catches that class is the one the clause invited you to skip.

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

So RECOVER spans the hard boundary and can **halt on either side**: on a part it cannot type, on a
relation it cannot resolve, or on a mass it cannot justify dropping.

**Typing a part has two questions, and the second is the discriminating one.** *(a) What kind of
utterance is this?* — directive, constraint, criterion. *(b) **What does it refer to?*** Reading (a)
alone, `do jeito que o fulano sugeriu` types cleanly as a method-constraint and passes. Only (b)
catches that `fulano` is a placeholder for an explicitly-unnamed person, i.e. that the part names
nothing. **DISSECT is where an empty referent is DETECTED** — emptiness is a per-part naming property,
and question (b) is the only place it is asked. **`relate` is where an empty referent is ADJUDICATED** —
whether it *blocks* is a dependency question (does the goal or the DoD hang on it?), and dependency is
a graph property, which is `relate`'s domain. The halt is the **conjunction**: detected in `dissect`
∧ load-bearing per `relate`. Neither member is "the single halt site"; each answers a different
question, and the halt needs both answers.

> **Corrected 2026-08-14 (v0.3.0 eval, claim disproved).** An earlier form of this clause read
> *"DISSECT is the single halt site for referents; `relate` halts on graph properties …, not on
> naming"* — which contradicted **two** other passages of this same section: the non-skippability
> rule above justifies `relate` precisely by its role in catching *"every part hangs on an absent
> referent"*, and the proportionality rule below conditions the halt on *"only if the goal or the
> DoD depends on it"* — a dependency test the denied member is the one equipped to compute. The
> word doing the damage was **"single"**: it forced one member to own a check that structurally
> takes two. Detect ∧ adjudicate resolves all three passages without weakening either gate, and
> makes the proportionality rule mechanically executable instead of merely asserted.

⚠️ **Proportionality — halt on what BLOCKS, carry what merely gaps.** An unresolvable referent halts
RECOVER **only if the goal or the DoD depends on it**. Otherwise name it as an **open parameter**,
carry it into the prompt's ESCALATION section, and continue — never guess it. Without this rule the
check is all-or-nothing: a dump with four crisp directives and one vague aside (*"…e conserta aquilo
que o Bob mencionou"*) would hard-halt instead of rendering the resolvable 80% and escalating the
aside — importing exactly the exhaustion that *"escalation, not exhaustion"* rejects above.

Worked contrast, both measured (`examples/EVAL-REPORT-2026-08-14.md`): a dump whose every part is a
placeholder (`fazer aquilo que o fulano sugeriu`) has **no** recoverable goal → **halt**. A dump that
names its pipeline concretely but redacts one node (`sistema X`, alongside `extrato bancário`,
`planilha de ajuste`, `PDF`, `contador`) still yields a goal and a DoD → **carry it open**. The
discriminator is *does the goal survive the gap*, not *is there a gap*.

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

Therefore RECOVER MUST emit the parts catalogue **and** the relation map; and **if it reaches
DISTILL**, the drop-list-with-reasons as well. The conditional is not a loophole — DISTILL runs
*last*, so a halt at DISSECT or RELATE precedes it and there is no drop-list to emit. In that case
RECOVER emits the catalogue, the map, and **the halt reason**, which is the same obligation
discharged at the point it stopped. (An unconditional MUST here would be unsatisfiable on every
halt — a rule the pipeline's own ordering forbids obeying.) They are not debug output. Without them the answer to *"what was in there, and what did you drop, and why"*
does not exist — and if that answer does not exist, comprehension did not happen; parsing did.

**Prism only abstract criteria** (the DoD, a quality bar). Prismming a concrete part is ceremony.

> **House pair.** The movements are named, never numbered — *comprehend · distill · shape*.
> **Distill** is the same operation the operator's vault protocol `braindump-distill` (*Alambique*)
> performs at a different terminus; **shape** gives this skill its soul-name (*Lapidary*). The two
> names already exist and are **sequential, not rival** — a still, then a lapidary. No third name is
> minted for **comprehend**: it is named by its outputs (catalogue + relation map), which is the
> point. This skill inlines its own separation (goal-oriented) rather than composing the vault's
> (artifact-oriented), because the two sort for different things.

**Measured, then corrected** (`examples/DOGFOOD-gauntlet.md` → falsified by `DOGFOOD-thesis.md`):
the first run claimed the two longest passages — a cartesian resource list and a 40-item principle
enumeration — contributed **zero** constraints. Re-run with `relate`, the count was **17**: the items
appearing in *both* lists, said twice in two independent syntaxes, which is emphasis rather than
mass. The first run dropped each list *on its own merits* and never asked whether they **intersect**
— it read nodes; the finding was an **edge**. What survives unchanged: the shortest clause still
became the acceptance metric. Mass is not content — but **length is not a proxy for emptiness**
either, and only `relate` can tell them apart.

### Recursion clause (the discipline must propagate)

A rendered prompt SHALL itself carry separate-before-shape into the work it drives. Concretely,
the rendered prompt's **method section — whatever the active profile calls it** (`BUILD-METHOD` in
`gauntlet-loop`, `SCOPE` in `default`) — must require the executing agent to **decompose the target
and name what is out of scope** before building — never to begin shaping an undifferentiated goal. A prompt that skips this
reproduces, one level down, the exact failure this skill exists to prevent.

## How it works

```text
operator invokes /maos:refine-braindump-to-prompt "<braindump-path-or-text>"
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
| `skills/convergence-engine` (this repo) | economic stop at `n*` — `skills/convergence-engine/SKILL.md` is the **SSOT** for the closed form, its parameter bounds, its marginal-value indexing, and its round-count convention (is `n*` the last affordable round or the first rejected one?). This skill **cites** the bound and never restates it. Floor is human-parity, **not** perfection; looping past `n*` costs 4-10× for <1% gain |

**The synthesis this skill encodes — the Verifiability Gate:**

```text
long_loop_licensed := bar_is_machine_verifiable
                    AND critic_is_independent_of_builder
                    AND evidence_is_directly_inspectable

if long_loop_licensed -> cap = profile budget (attempts | cost | wall-clock | stagnation delta)
else                  -> cap = convergence-engine economic stop (n*, per convergence-engine)
NEVER                 -> unbounded, on work that is irreversible, costly, or unobservable
```

A long loop pays off **only when the gain signal is real** — i.e. when an independent critic can
measure the artifact against an external bar. Absent that, extra rounds buy self-assessment, which
is the very bias the loop was built to defeat.

> ⚠️ **REFINE is self-critique, and its critic is the draft's author.** `bin/convergence-guard` run
> against this loop returns `REFUSE / correlated-verifier-violates-independence` — correctly. So
> REFINE does **not** satisfy `convergence-engine`'s `verifier > generator ∧ independent` master
> condition, and this skill does not claim it does: REFINE is the *cheap* pass that catches surface
> defects, and **RED-TEAM (PHASE 4) is the independent gate**, which is why it is non-optional.
> Measured on `examples/EVAL-REPORT-2026-08-14.md`: six clean-scoring self-critique rounds missed
> two BLOCKING defects that one independent refutation found. Adding rounds does not fix this —
> more self-assessment is more of the same bias. Only the independent pass does.

The REFINE loop therefore terminates on a
**two-part** condition, never a single clean pass:

```text
stop_refine := (rounds <= --max-rounds)                    # hard cap; exceeded -> STOP-HITL
           AND if long_loop_licensed:
                   (revisions    >= --min-revisions)       # floor   — profile-supplied
                   AND (clean_rounds >= --clean-rounds)    # dryness — profile-supplied
               else:
                   economic stop governs ALONE (n*, per convergence-engine) # no floor, no dryness counter
```

**The floor is licensed, not global — and that is load-bearing.** A round either produces a
revision or is clean, never both, so a `min-revisions=3 AND clean-rounds=3` floor requires **≥6
rounds**. When the loop is *unlicensed* the cap is `n*` (per `convergence-engine`). **A global floor would therefore
exceed its own cap on every unlicensed run** — and `profiles/default.md` states the gate normally
evaluates false for that profile, so that is the common path, not an edge case. The floor belongs to
the profile that licenses it (`gauntlet-loop`, whose `≥3 revisions AND ≥3 consecutive clean rounds`
comes from the operator's own loop spec); `default` runs on the economic stop alone.

The floor exists — where licensed — because a draft that *looks* clean on pass 1 usually is not, and
because a single clean pass is noise. Each round uses `--lenses` perspectives that are **distinct
from each other within that round**; a round that repeats a lens *inside itself* does not count
toward `clean_rounds`. **Cross-round reuse is expected and required** — rotating 3 lenses per round
through a 5-lens roster cannot keep rounds mutually disjoint past round 2, so a cross-round reading
would make `clean_rounds >= 3` need 9 distinct lenses and render `STOP-DONE` unreachable.

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
| `--min-revisions` | `3` | REFINE floor — **licensed profiles only**; ignored (with a warning) when `long_loop_licensed=false` |
| `--clean-rounds` | `3` | consecutive gap-free rounds — **licensed profiles only**; same gate as above |
| `--max-redteam-cycles` | `2` | cap on `RED-TEAM REFUTED → REFINE` returns; exhausted while still REFUTED → `STOP-HITL` |
| `--lenses` | `3` | distinct perspectives per round; a repeated lens does not count |
| `--max-rounds` | `12` | hard cap; exceeded → `STOP-HITL` (diminishing returns) |
| `--dry-run` | `false` | run RECOVER→REFINE and emit the plan; STOP before RENDER writes |
| `--output` | `table` | `table` \| `list` \| `json` \| `json-rpc` (machine contract — see §Output contract). `json-rpc` is **not** a synonym for `json`: it emits `method` + `params` (notification shape, no `id`) per `[C06]`, which is what an agent-to-agent caller consumes. |
| `--persist` | *(none)* | **DEPRECATED alias** — `--persist=P` ≡ `--output-target=git-repo:P`. Kept working; do not remove. |
| `--output-target` | *(none)* | one or more sinks, comma-separated: `<kind>[:<param>]`. Omitted → **report inline, emit nothing** — `inline` is NOT a sink kind (see §Output targets, N5a). See §Output targets. |
| `--user-lang` | `auto` | operator-facing prose language (mirrors the host's language policy) |
| `--agentic-lang` | `en-us` | language of the RENDERED prompt (agent register) |

## Output targets (`--output-target`) — a TEST, not a kind list

A rendered prompt that lands in exactly one place is **unmounted for every other harness**.
The operator runs claude · codex · pi · opencode · gemini · antigravity · kiro; a distillate
that only reaches one vault serves one of them. This axis is orthogonal to `--output`
(*which wire format*) and to `agentic-tool-forge`'s type router (*which artifact type*).

**A sink is a valid output-target iff:**

> **(a) REACHABLE** — it exists and is reachable, **probed, never assumed**
> **(b) RENDER DEFINED** — the distillate has a defined form for that sink
> **(c) CAN REFUSE** — unreachable/unauthorized emits a **named reason**, never a silent drop

Extend by the test, never by taste. The table below is the **instance**; `etc` is the open set.

| Kind | `:param` | Render | idempotent | reversible | shared-surface |
|---|---|---|---|---|---|
| `stdout` | — | raw prompt | yes | n/a | no |
| `clipboard` | — | raw prompt, **no frontmatter** | **NO** (declared) | no | no |
| `vault` | note path | prompt + YAML frontmatter + wikilinks | yes | yes (git) | yes |
| `git-repo` | file path | prompt as-is | yes | yes (git) | yes |
| `agentic-tool` | `skill\|command\|agent\|rule\|memory\|mcp` **:path** | **per sub-kind** — see below | yes | yes (git) | yes |

**Declared properties are not membership criteria.** `clipboard` is a valid target *while being
non-idempotent* — it just has to **say so**. A target that hid that would fail (c) in spirit:
silently producing a different result on re-run is a drop the caller cannot see.

**`inline` is NOT a sink — omitting `--output-target` REPORTS, it does not emit.** With no target
the run returns the prompt in its answer and writes nowhere. That is *reporting*, a distinct act
from *emitting*, and it is why `inline` does not appear in the table above.

> **Corrected 2026-08-14 (v0.3.0 eval, N5a).** The flag row previously read *"Omitted → return
> inline only"*, which named `inline` as though it were a sixth kind — while the table gives it no
> row and therefore no **Render** cell. By this section's own criterion (b) (*a sink is valid iff
> its render is DEFINED*), the skill's **default path was an inadmissible sink**: the one route
> every caller takes without a flag was the one route the membership test rejected. The repair
> names the act instead of inventing a kind. Vault-side counterpart: `persist-locus.spec.yaml`
> `inline: {admissible: false}` + `default_rule` — same finding, closed on both sides of the
> ratified N2 split.

**SSOT of this axis (N2 contract, ratified `coexistence-pr11xpr12-20260814`).** `--output-target`
exists in two places and they do not compete: **[[persist-locus]] is SSOT of ROUTING** — which
houses × kinds a distillate may land in, and the membership test that admits them —
(`eko-engram` `pages/persist-locus.md:96` + `resources/agentic-tools/persist-locus.spec.yaml:104`);
**this flag is SSOT of EMISSION** — how one run reshapes and delivers to a named sink. Each cites
the other; neither redefines the other's half. A future change to *which* kinds exist belongs there;
a change to *how* a run emits belongs here.

### The two cases that break an enum (and why the test exists)

1. **`clipboard` is not a path.** Any axis shaped as `--persist=PATH` cannot express it. This is
   what forces *target = sink*, not *target = location*. Verified live: `pbcopy` present **and**
   round-tripped through `pbpaste` — presence of the binary is not reachability (a).
2. **`agentic-tool` is not one kind.** A skill, a command, an agent, a rule, a memory and an MCP
   have *different renders* — SKILL.md frontmatter ≠ a command's `name:` ≠ a rule's `[CXX]` header.
   So (b) resolves **per sub-kind**, and `agentic-tool` alone is an under-specified target: it
   MUST carry its sub-kind. A straddler a flat list would have hidden.

> ⚠️ **This sink is NOT tool-genesis.** It writes REFINED CONTENT into a `skill|command|agent|
> rule|memory|mcp` whose type + name + path + creation-governance the CALLER has already
> resolved — updating an existing artifact, or authoring a new one the caller is deliberately
> keeping outside the full lifecycle. It does **not** run `agentic-tool-forge`'s dedup scan,
> type-decision router, `anima` naming, invocation-surface gate (the `/name`-wrapper check), or
> DNA-geracional inheritance (§0 + gates + DUED + Refs), and it does not record to the
> artifact-registry. A braindump whose intent is "make me a NEW, recurring, reusable tool" is
> the `agentic-tool-forge` case from §When not to use above, not this sink — invoke this sink
> directly for prose-refinement only; for genesis, go through `transmute`'s `cast:agentic-tool`
> router (→ `agentic-tool-forge`) or call the forge itself.

### Multi-target semantics (explicit, never implicit)

- **Order**: `gitleaks` gate runs **once, before any emission — UNCONDITIONALLY**. There is no
  predicate, because no sink is exempt: a leak escapes through `stdout` (terminal · logs · session
  transcripts · a shared screen), through `clipboard` (paste-anywhere), and through the three
  git-backed kinds (committed). A hit **aborts every target of the run** and emits `STOP-ERROR`
  with `leak.rule` + `leak.target_kinds`; nothing is written, nothing is copied, nothing is printed.

  > **Corrected 2026-08-14 (v0.3.0 eval, N5b).** This gate previously fired *"whenever ≥1 target
  > declares `shared-surface: yes`"* — and `stdout` and `clipboard` are both declared `no`. A
  > clipboard-only run therefore **never scanned**, while the very next clause ("a leak aborts all
  > targets — including `clipboard`, which is not exempt") stayed textually true and operationally
  > **vacuous**: nothing aborts if nothing ran. The repair is not a better flag value — it is
  > deleting the predicate. A per-target condition implies some target is exempt; enumerating the
  > five shows none is, so the condition discriminated nothing and only hid the hole. `shared-surface`
  > keeps its own true meaning (is this a shared, persistent artifact?) and stops doing double duty
  > as a security key. Vault-side counterpart: `persist-locus.spec.yaml` `shared_surface_binds_leak_gate`
  > — **cite, do not redefine** (routing is Locus's SSOT; this emission-side gate is the skill's,
  > per the ratified N2 split).

- **Partial failure**: **best-effort with a named report**, not all-or-nothing. Rationale: the
  targets are independent sinks, so failing `clipboard` (headless host) must not withhold the
  `vault` write the operator can actually use. Every failure is reported by kind + reason; a
  silent partial success is forbidden. **Terminal marker `STOP-DONE` with `targets[].status`
  per kind** — a run that emitted to 2 of 3 sinks is *done with a named gap*, never a bare success.
- **Sink refusal** (a target fails the membership test — unreachable, no Render defined, or
  unnameable): **`STOP-ERROR` with `refused.kind` + `refused.criterion`**, before any emission.
  Refusing without a marker was one of the 13 markerless halts the v0.3.0 eval counted.
- **Unmerged-branch warning**: a `git-repo`/`vault` target on a branch with no upstream, or ahead
  of it, emits a warning. Empirically earned: a braindump written to an unmerged branch became
  invisible from the operator's own checkout on 2026-08-14.
- **Per-kind render, never one blob copied N times** — a vault note carries frontmatter, a
  clipboard payload must not.

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
  "dropped_session_meta": [],

  // Emission outcome — every halt on this axis is BOTH marked and fielded (v0.3.0 eval, D2).
  // A marker with no field is unreadable by a machine; a field with no marker is unreadable
  // by the loop. The three below had NEITHER before this repair.
  "emission": {
    "targets": [ { "kind": "", "param": null, "status": "emitted|failed|refused",
                   "reason": null } ],          // partial failure → STOP-DONE + per-kind status
    "refused": { "kind": null, "criterion": null },   // membership-test refusal → STOP-ERROR
    "leak":    { "hit": false, "rule": null, "target_kinds": [] } },   // gitleaks → STOP-ERROR

  // Non-entry is a terminal state too (§Skip conditions). Distinguishes "finished, nothing to do"
  // from "finished, prompt attached" — both carry STOP-DONE, so the FIELD is the discriminator.
  "skipped": { "condition": null, "handed_to": null } }
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

- REFINE stops on the economic stop (`n*` (per `convergence-engine`)) by DEFAULT. The **two-part** floor (min-revisions
  AND consecutive-clean-rounds) applies ONLY where the Verifiability Gate licenses the long loop —
  asserting it unconditionally makes the floor exceed its own cap on every unlicensed run.
- `--max-rounds` (default 12) is a hard cap → `STOP-HITL` on exhaustion.
- RED-TEAM's critic MUST be independent of the DRAFT author (`bin/convergence-guard`); if
  independence cannot be secured on a high-stakes prompt → **HOLD, do not force**.
- Session-meta (`/enhance` wrappers, pep-talk, "do a good job") is DROPPED in RECOVER and listed
  in `dropped_session_meta` — never silently.
- A cartesian list of resources in the braindump is **not** a requirement to instantiate each one —
  but rendering it as *"permissible, none mandated"* **inverts an imperative into a permission**.
  Carry it as a *permission* only when the dump offers it as a menu; carry it as a *constraint* when
  the dump mandates it.
- **Straddler: a method-directive that shapes the OUTPUT is not session-meta.** `busque semelhantes`
  (reuse before build) and `invoque Forge` (produce a *reusable* artifact, not a one-off) constrain
  what the deliverable must be, not how the distiller should work — they belong in the prompt. Test:
  *if this were dropped, would the acceptable output change?* Yes → constraint, keep. No → meta,
  drop. (`/enhance` wrappers and pep-talk fail this test; those still drop.)
- Worktree discipline always on (`skills/worktree-policy`); never commit to main.
- Delegation depth ≤ 2; parallel fan-out ≤ 3 per round.
- Exactly ONE STOP marker per turn.
- External research is time-boxed and cited — never fabricate prior art.
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, prod/irreversible,
  cross-org) ALWAYS halt the pipeline → HITL.

## Failure modes

- **Empty / unreadable braindump** → `STOP-ERROR` before RECOVER (nothing to lapidate).
- **RECOVER cannot find a goal** → `STOP-HITL` carrying **ranked resolution-paths** — the specific
  referents that must be resolved for a goal to exist — never candidate goals. On a referentially
  empty dump any content-level hypothesis *is* the guess this clause forbids; the only honest
  payload is the list of questions whose answers would produce a goal.
- **`decompose-abstract-to-measurable` returns `human_review: true` / `allowed_use: assistive_only`**
  (from `structural_route.py`) → carry the verdict into the prompt as an explicit tier; a DoD the
  primitive itself says needs human review must not pass silently. This is a **second, independent**
  refusal signal — `aggregate_spec.py` can return `inconclusive.flag: false` on the same DoD that
  the router caps. Reading only the flag misses it.
- **DoD not measurable after `decompose-abstract-to-measurable`** (`inconclusive.flag`) →
  `STOP-HITL`; a prompt with an unmeasurable stop-condition is the failure this skill exists to prevent.
- **RED-TEAM returns REFUTED** → classify before looping. A **craft defect** (unclear,
  unfalsifiable, under-scoped) returns to REFINE, bounded by `--max-redteam-cycles` (default 2). A
  **missing fact about the operator's world** (an unnamed system, an unknown schedule, an unmeasured
  tolerance) → **`STOP-HITL` immediately**: no number of refine rounds can manufacture a fact the
  dump does not contain. **Precedence**: this outranks the economic stop — the stop caps iteration
  *within* REFINE and never governs the RED-TEAM return path. Without that precedence the two
  collide structurally on any unlicensed run (stop caps REFINE at `n*` (per `convergence-engine`); a refutation at round
  4 demands a round 5 that is over-cap by construction).
- **`--max-redteam-cycles` exhausted while still REFUTED** → `STOP-HITL` carrying the standing
  findings as the escalation payload.
- **RECOVER halts** (untypeable part · goal-blocking referent · unjustifiable drop) → `STOP-HITL`
  carrying the catalogue, the map and the halt reason. *(Every halt names a terminal marker; a halt
  without one is an unfinished rule.)*
- **`--max-rounds` exhausted** → `STOP-HITL` (diminishing returns → escalate).
- **RED-TEAM independence unavailable at high stakes** → `STOP-HITL` (hold, don't force).
- **Profile not found** → `STOP-ERROR` listing available profiles.

## Skip conditions (proportionality)

A skip is a **terminal state**, not a no-op: the run ends without this skill rendering a prompt. It
therefore names a marker like every other halt — `STOP-DONE` with `skipped.condition` and
`skipped.handed_to`, so a caller can tell *"finished, nothing to do"* apart from *"finished, prompt
attached"*. No fourth marker is minted; the discriminator is the field, not a new word.

- **S1** the intent is already one clear sentence → write the prompt inline; skip the pipeline.
  → `STOP-DONE` · `skipped.condition: S1` · `skipped.handed_to: null`
- **S2** the operator supplied the prompt and wants only execution → hand to `auto-pilot`.
  → `STOP-DONE` · `skipped.condition: S2` · `skipped.handed_to: "auto-pilot"`
- **S3** mid-orchestration under a parent that already recovered the goal upstream.
  → `STOP-DONE` · `skipped.condition: S3` · `skipped.handed_to: "<parent>"`

> **Corrected 2026-08-14 (v0.3.0 eval, D2).** These three carried no marker, and they are three of
> the **11 markerless points the eval found OUTSIDE §Failure modes** — the section that asserts
> *"every halt names a terminal marker; a halt without one is an unfinished rule."* The rule had
> been enforced where it was written rather than across the domain it claims, which is the same
> shape as the defect it exists to prevent. Fixing only §Failure modes would have repeated it.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: the skill is validated on the braindump that originated it before being declared done.
- **Persist-over-fail**: write-ahead-checkpoint each obligation BEFORE executing.
- **DRY / KIS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **Verifier ≠ generator** — the critic never inherits the builder's context.
- **Boy-Scout** — leave every repo cleaner than found.

## Examples

```text
/maos:refine-braindump-to-prompt "~/dumps/2026-08-14-gauntlet.braindump.md"
/maos:refine-braindump-to-prompt "<dump>" --architecture=gauntlet-loop
/maos:refine-braindump-to-prompt "<dump>" --dry-run --output=json
/maos:refine-braindump-to-prompt "<dump>" --min-revisions=5 --clean-rounds=2 --lenses=4
/maos:refine-braindump-to-prompt "<dump>" --persist=./prompts/migration.prompt.md
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

- v0.3.1 (2026-08-18) — **Boundary note: the `agentic-tool` sink is NOT tool-genesis.** Comparative
  audit against the `agentic-tool-*` family found this sink's "RENDER DEFINED" criterion satisfied
  only illustratively (frontmatter-vs-`name:`-vs-`[CXX]` contrast, no worked spec) and silent on its
  relationship to `agentic-tool-forge`'s create-time governance (dedup/naming/invocation-surface-
  gate/DNA-geracional-inheritance/artifact-registry-record) — risking a caller reproducing the exact
  skill-without-`/`-wrapper regression forge v1.1.0 exists to prevent, under the SAME natural-language
  trigger ("cast this braindump as a skill") both tools' descriptions claim. Added an explicit
  boundary note directly under the sink's own explanation; `agentic-tool-forge` reciprocated with a
  matching note + a new §Refs entry (closing a one-directional cross-ref this file already implied
  3× — "When not to use", the orthogonality note, the sibling table — but the forge never echoed).
  Zero mechanism change; documentation-completeness only.

  **Gap note (resolved via archaeology, issue #364):** `git log --follow -p` on this file's full
  history (4 commits: #321 initial → #322 → #324 → #362) shows the frontmatter already read
  `version: "0.3.0"` at the VERY FIRST commit (`755ca20`, 2026-08-14) that introduced this skill into
  the repo — there is no `0.1.0`/`0.2.0` commit here to backfill from; #322 and #324 modified the
  file without bumping the version at all. The gap is **permanent and pre-existing**, not an
  oversight: this skill's `0.1.0`→`0.3.0` evolution happened entirely BEFORE its first commit into
  `multi-agent-os` (drafted/iterated elsewhere), so no in-repo diff can reconstruct those two rows.
  The `v0.1.0 (initial)` row below is therefore a **narrative label only** (describing the
  five-phase design as first conceived), not a claim that a `0.1.0`-tagged commit exists.
- v0.1.0 (initial) — five-phase braindump→prompt lifecycle composing in-repo primitives;
  architecture profiles (`default`, `gauntlet-loop`); the Verifiability Gate stopping doctrine
  (synthesising Shumer's unbounded loop, Osmani's mandatory stopping rules, and this repo's
  economic stop); two-part REFINE termination (floor AND dryness); STOP-marker grammar reuse;
  depth/round bounds; `--output=json` contract. *(Pre-repo design narrative — see gap note above;
  this row's "initial" refers to the skill's original design, not this repo's first commit, which
  already carried `0.3.0`.)*

## License

MIT (matches multi-agent-os repo `LICENSE`).
