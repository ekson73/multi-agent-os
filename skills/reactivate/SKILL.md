---
name: reactivate
version: "0.1.0"
description: |
  Cold-start reactivation conductor for new-fresh-born amnesic agents. Wakes an agent that has
  NO context — orients from whatever evidence exists (or honestly reports that none does),
  recovers the often-unstated intent, deliberates, and PRESENTS ranked recommendations /
  next-actions routed to the consumer's own form: pt-BR via the ask-tool for a live human,
  a persisted ranked set for a deferred human, a typed JSON envelope for an agent/subagent/
  abiotic consumer. Composes the existing family (pulse · goal-recovery · enhance-pipeline ·
  converge · convergence-engine Return-Gate) and newly authors only what was genuinely absent:
  a THINK step, a data-sanitize gate, and ONE unified PRESENT. Explicit operator instruction
  overrides every computed condition.
  Soul-name: Entelecheia (Aristotle, De Anima II.1 — the second entelechy: latent knowledge
  moved into exercise). Triggers: "reactivate", "reativar", "wake up", "acordar", "cold start",
  "I have no context", "onde eu estava", "what am I doing", "re-ativação".
allowed-tools: Read, Grep, Glob, Bash, Write, Task, AskUserQuestion
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  soul-name: Entelecheia
  register: agent
---

# reactivate — the cold-start reactivation conductor

> **Soul-name**: *Entelecheia*. In **De Anima II.1** Aristotle separates two actualities: the
> **first, analogous to sleep** — *having knowledge without exercising it*; the **second,
> analogous to being awake** — *exercising that knowledge*. An amnesic agent at cold wake is the
> first; this conductor moves it to the second. It is the same premise the ecosystem already
> holds — agents carry vast latent capability that only **correct invocation** actualizes.
> *(Display-only name. The machine identifier is the slug `reactivate`.)*

## When to use / not use

- **Use**: an agent wakes with no or thin context and must decide what to do next — a fresh
  session, a post-compaction resume, a spawned subagent handed a bare task, a `mktemp -d` with
  no git and no memory, or any moment where the honest answer to *"what am I doing?"* is
  *"I don't know yet."*
- **Not use**:
  - There IS a continuation seed / prior session artifact to re-enter → `session-reentry`
    (artifact-driven, richer). This conductor is the **zero-or-thin-artifact** path.
  - You already know the goal and need the vehicle to reach it → `derive-system-from-goal`.
  - You are mid-task with full context and just need re-orientation → `pulse` directly.
  - A specific decision is on the table and the question is *"may I act without the human?"* →
    `council-gate`. **Different question**: that gate *authorizes*; this conductor *orients*.

## The pipeline (6 phases — lean by default, deepened on demand)

```
PHASE 0  CONSUMER   classify the consumer (cheap, always) — every later phase knows its output form
PHASE 1  ORIENT     pulse  ──(pulse stops on true cold-start)──► ZERO-ARTIFACT branch
PHASE 2  INTENT     goal-recovery — ranked hypotheses + confidence, or inconclusive
PHASE 3  THINK      deliberate before acting                        ◄── newly authored
PHASE 4  DEEPEN     enhance-pipeline → converge → [praxis-audit]     (only --depth full)
PHASE 5  PRESENT    SANITIZE-gate → Return-Gate → Consumer Gate      ◄── newly authored assembly
```

**Composition discipline**: PHASES 1, 2, and 4 **delegate** to skills that already exist and are
never reimplemented here. Only THINK, the SANITIZE gate, and the unified PRESENT assembly are
authored by this conductor — they were the genuinely absent pieces.

**Proportionality** (over-engineering circuit-breaker): a cold wake must be *fast*. Default depth
is **quick** (phases 0-3, 5). `--depth full` adds PHASE 4. Do not run a full convergence board to
answer *"where was I?"*.

---

### PHASE 0 — CONSUMER (classify first)

Resolve the consumer class **before** producing anything, so every later phase budgets its output
correctly. The cascade is specified once, in governance, and consumed here — see the host's
end-of-action briefing protocol §7.0 (Consumer Gate). Summary of the binding order:

1. **Explicit declaration wins, always** — `--consumer=<class>` or an operator instruction.
   This is the operator's overwrite-any-condition clause; it is never second-guessed.
2. **Capability-probe** — no ask-tool in the toolset ⇒ `machine`. Structural, cross-vendor,
   independent of environment variables.
3. **Topology** — an MCP/SDK entrypoint, or a named subagent type ⇒ `machine`.
4. **Asynchrony** — background/job context or no interactive channel ⇒ `human-deferred`.
5. **Default** ⇒ `human-live`.

**Output**: one token — `human-live` | `human-deferred` | `machine` — plus which rung decided it.

⚠️ **Honest bound**: rungs 3-4 read *invocation topology*, not consumer identity. A child session
can still have a human reading it. Rung 2 is the strong signal; when 2 is silent and 3-4 disagree
with observed reality, the operator's explicit declaration (rung 1) settles it.

---

### PHASE 1 — ORIENT (delegate: `pulse`)

Run `pulse` to recover the picture from whatever exists (commits · todos · memory · open PRs ·
prior pulse artifacts).

**The branch that matters** — `pulse` **stops** on a genuine cold start (its PHASE-1 skip-rule
emits `fresh start` and halts; PHASE-2 likewise halts on `all clear`). That is correct behavior
for `pulse` and **not** an error. When it happens, this conductor does **not** stop:

**ZERO-ARTIFACT branch** — enumerate honestly, in this order, and stop at the first that yields:
1. the invocation itself (the task/prompt the agent was handed — often the *only* evidence);
2. the working directory (its name, its files, whether it is even a repository);
3. the host environment (what tools/skills are reachable — capability, not context).

If all three are empty, the correct output is **an honest nothing**: *"no recoverable context; here
is what I can reach and here are the questions whose answers would unblock me"* — routed through
PHASE 5 like any other result. ⛔ **Never fabricate a plausible-sounding prior state.** An invented
context is worse than no context, because the next agent inherits it as fact.

---

### PHASE 2 — INTENT (delegate: `goal-recovery`)

Recover the often-unstated goal from the weakest available evidence into the typed, validator-gated
envelope `goal-recovery` already defines. Carry through **unchanged**: its ranked hypotheses, its
aggregate confidence, and — decisively — its `inconclusive` verdict.

`goal-recovery` is explicit that intent-recovery from execution state is **never a confident
oracle**. Honor that: an `inconclusive` is a *result*, not a failure to be papered over. It flows
to PHASE 5 as a genuine residue and becomes the thing the consumer is asked about.

---

### PHASE 3 — THINK (newly authored — the verb no skill had)

Every sibling skill *analyzes* (decompose the object) or *critiques* (find the flaw). None
**deliberates over the decision itself**. This phase is that step, and it is deliberately small.

Three questions, time-boxed, answered before any action is proposed:

| # | Question | Why it earns its place |
|---|---|---|
| T1 | **What are the competing framings?** Name ≥2 readings of what this session is actually for. | A single framing adopted at cold-start propagates through every downstream phase uncorrected. |
| T2 | **What evidence would discriminate between them?** Name the cheapest probe that separates the framings. | Converts an opinion into a test — and the probe is often free (`ls`, `git log`, read one file). |
| T3 | **What does being wrong cost, each way?** Asymmetric? | Where the costs are asymmetric, the cheap-to-reverse framing wins even at lower probability. |

If T2 names a probe that is **read-only and cheap**, run it now rather than carrying the ambiguity
forward — a probe the agent can run in seconds beats a question that costs the human minutes.

**Bound**: ≤2 framings, ≤1 probe, ≤60s. Deliberation that outgrows the decision is the loop this
phase exists to prevent, not to create.

---

### PHASE 4 — DEEPEN (`--depth full` only)

Runs the existing cognitive chain over the PHASE-3 output: `enhance-pipeline` (the analyze ·
critique · compare · validate · correct · improve · expand · harmonize spine) → `converge`
(synthesis) → optionally `praxis-audit` (meta-critique — *is this verdict itself theater?*).

⛔ **`converge` is NEVER the exit step.** Its Invariant 6 (*audit-not-persuasion*) forbids framing a
preferred answer, leading questions, or a consensus-preloading close — enforced by a mandatory
impartiality scan. `converge` produces a **neutral record**; the *recommendation* is a downstream
transformation performed in PHASE 5. Putting `converge` at the exit would make this conductor
violate the invariant of the very skill it composes.

---

### PHASE 5 — PRESENT (sanitize → rank → route)

Three gates in strict order. The first is unconditional.

#### 5a — SANITIZE (mandatory, never a depth option)

Before anything leaves this conductor, scrub the payload of **secrets · credentials · tokens ·
personal data**. This is a ⛔ absolute guardrail, not a preference: it holds regardless of consumer
class, depth, or operator instruction. The existing chain sanitizes *rhetoric* (Invariant 6); this
gate sanitizes *data*, which nothing upstream does.

Practical: never echo an environment variable's value, a token, a key, or a personal identifier
into the presented set — reference it by name and location instead (*"the token in the vault item
X"*, never the token).

#### 5b — RANK (delegate: `convergence-engine` Return-Gate)

Apply the Return-Gate exactly as specified — rank by recommendation → impact-score each →
diverse-validate → **gate**: top item HIGH (≥0.85) ∧ reversible ∧ ¬HUMAN_DOMAIN ⇒ **decide, act,
report** (skip the ask); else score-uplift → regenerate → re-loop bounded; exit either by acting
or by presenting the genuine residue. Its escapes are honored verbatim and are **not** suppressed:
HUMAN_DOMAIN · a genuine operator preference the agent lacks and cannot self-verify ·
irreversible/high-blast · duly-justified.

This is reused whole. The conductor adds no new authorization logic and no new merge/act authority.

#### 5c — ROUTE (Consumer Gate, per PHASE 0)

| Class | Channel | Form |
|---|---|---|
| `human-live` | the ask-tool — recommended option **first** and tagged, description carries the *tradeoff*, escape always available | **pt-BR** |
| `human-deferred` | **the Return-Gate above, unchanged** — act when the gate clears, else persist the ranked set and return. **Never blocks.** | pt-BR + envelope |
| `machine` | one typed `recommendation-set` envelope | JSON, en-US |

The `recommendation-set` payload is one schema for all classes (the human-facing channels render
it; the machine channel emits it):

```json
{
  "recommendation_set": {
    "context": "<one line: what decision is on the table>",
    "recommended": "<id of the recommended option>",
    "options": [
      {"id": "A", "label": "<≤5 words>", "rationale": "<why>",
       "tradeoff": "<consequence if chosen>", "confidence": 0.0,
       "next_action": "<concrete>"}
    ],
    "escape": "other",
    "audit_ref": "<decision-capture id | null>"
  }
}
```

**Recommending here does not violate Invariant 6** — that invariant binds the *synthesizer*, whose
job is to record neutrally. Recommending is the act of whoever **delivers**, never of whoever
**records**. The Return-Gate mandates *recommended-first* precisely at this layer.

---

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `--consumer` | `auto` | `human-live` · `human-deferred` · `machine` · `auto`. **Explicit always wins** (PHASE 0 rung 1). |
| `--depth` | `quick` | `quick` (phases 0-3,5) · `full` (adds PHASE 4). |
| `--lang` | `auto` | `pt` · `en` · `auto` (pt-BR for human classes, en-US for machine). |
| `--json` | off | Force the machine envelope regardless of class (debugging / piping). |
| `--no-act` | off | Present only — never let the Return-Gate act, even when it clears. |

## Invariants (non-negotiable)

1. **Explicit operator instruction overrides every computed condition** — consumer, language,
   depth, and route. The cascade is a *default*, never a veto over the operator.
2. **Never fabricate context.** An honest *"no recoverable context"* is a valid, correct output.
3. **SANITIZE (5a) is unconditional** — no class, depth, or instruction disables it.
4. **`converge` never occupies the exit** (Invariant 6 of that skill).
5. **No new authorization** — acting authority comes only from the reused Return-Gate.
6. **`human-deferred` never blocks** — it acts or it persists; it does not wait.
7. **Bounded** — quick depth by default; PHASE 3 ≤2 framings / ≤1 probe / ≤60s.

## Anti-patterns

1. ❌ **Fabricated prior state** — inventing a plausible "where you left off". The next agent
   inherits it as fact; this is the single most damaging failure available to this conductor.
2. ❌ **Blind pulse delegation** — treating `pulse`'s `fresh start` stop as the conductor's own
   stop. That case is precisely why this conductor exists.
3. ❌ **`converge` at the exit** — violates Invariant 6 (see PHASE 4).
4. ❌ **Asking a live human what a read-only probe answers** — PHASE 3 T2 exists to prevent this.
5. ❌ **Emitting prose to a machine consumer** (or a bare JSON blob to a live human) — the whole
   point of PHASE 0.
6. ❌ **Full depth on a trivial wake** — a convergence board to answer *"where was I?"*.
7. ❌ **Suppressing a genuine residue** — an `inconclusive` intent or a HUMAN_DOMAIN item is a
   result to present, not noise to smooth over.
8. ❌ **Reimplementing a composed skill** — if a phase needs more, extend that skill, don't fork it.

## Quality tests (6 self-validity)

1. **Self-application** — the conductor was itself designed by orienting from evidence (a recon of
   what already existed), recovering the operator's unstated intent, and presenting a ranked
   decision. ✅
2. **Non-contradiction** — composes `pulse`/`goal-recovery`/`enhance-pipeline`/`converge`/
   `convergence-engine` without overriding any; honors Invariant 6 by construction; distinct from
   `session-reentry` (artifact-driven), `council-gate` (authorization), `derive-system-from-goal`
   (goal→vehicle). ✅
3. **Survival** — applied to itself it advocates orient-then-present-honestly; it does exactly
   that, including presenting its own zero-artifact case as a valid output. ✅
4. **Bounded-responsibility** — quick default · PHASE-3 bounds · no new authority · sanitize gate ·
   qualitative sunset. ✅
5. **Explicit-exception** — operator override (Invariant 1) · Return-Gate escapes honored verbatim ·
   the not-use routing list. ✅
6. **Utility-sunset** — below. ✅

## Sunset (qualitative, not counter-based)

Deprecate when ANY: the host ships native cold-start reactivation that subsumes the pipeline · the
lifecycle family absorbs it into a unified entry (`session-reentry` growing a genuine zero-artifact
path would make this redundant) · agents stop being amnesic across boundaries · operator retraction
· ≥3 false-positive reactivations where the conductor fired on a warm, fully-contexted session.

## Refs

- Composed (never reimplemented): `skills/pulse` · `skills/goal-recovery` · `skills/enhance-pipeline`
  · `skills/converge` (Invariant 6) · `skills/convergence-engine` (Return-Gate) · `skills/praxis-audit`
- Siblings (distinct, routed in *not use*): `skills/session-reentry` (Anamnesis — artifact-driven) ·
  `skills/council-gate` (Boule — authorization) · `skills/derive-system-from-goal` (Hodos — goal→vehicle)
- Governance: the host's end-of-action briefing protocol §7.0 (Consumer Gate — the classifier this
  conductor consumes) and §7.1 (how to ask, when asking)
- Named by `skills/anima` per the host's naming authority; recorded in `bin/artifact-registry`
- Grounding: Aristotle, *De Anima* II.1 (first/second entelechy)
