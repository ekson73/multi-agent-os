---
name: chief-of-staff
version: "0.1.0"
description: |
  Operator-facing work-focus conductor — the human twin of the agent-facing reactivate/Entelecheia.
  ONE front-door answering "what should I focus on now? who asked me for what, by when? any loose
  ends?" GATHERS all scattered work (delegates work-compass), PRIORITIZES it (delegates pulse's
  Eisenhower 2x2; optionally ops-strategist's 4-lens if present), SURFACES a people-ask view
  (who / when / by-when) over existing tracker fields, and PRESENTS one operator briefing. Composes
  the existing family; reimplements nothing. Read-only by default; on-demand only (MAOS stays sole
  conductor). Soul-name: Oikonomos (the classical household steward). Triggers: "chief of staff",
  "keep me on track", "keep me focused", "what should I focus on", "my priorities", "what's on my
  plate", "who asked me for what", "o que devo focar", "me mantenha no foco", "minhas prioridades",
  "second brain".
allowed-tools: Read, Grep, Glob, Task, AskUserQuestion
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  soul-name: Oikonomos
  register: agent
  audience: operator-facing (human)
---

# chief-of-staff — the operator work-focus conductor

> **Soul-name**: *Oikonomos* (Greek *οἰκονόμος*). In Xenophon's *Oeconomicus* the oikonomos is the
> **steward of the household** — the one entrusted to keep the principal's whole estate of affairs in
> order so the principal is free to act. This is the majordomo / chief-of-staff / right-hand: it does
> not do the work, it keeps *you* pointed at the work that matters. It resonates with this operator's
> own **Eko-System** — *oikos* is the same root. *(Display-only name. The machine identifier is the
> slug `chief-of-staff`.)*
>
> **Twin** (the incoming agent-facing sibling, landing in PR #280 — may not be installed in this repo
> version yet): `reactivate`/**Entelecheia** orients a fresh amnesic **agent** at cold-wake. `chief-of-staff`/
> **Oikonomos** keeps the **operator** (human) on focus across live work. Same premise — correct
> orientation over scattered state — pointed at the two different consumers.

## When to use / not use

- **Use**: you (the operator) want a single "keep-me-on-track" pass — *what matters now, what did boss/
  cowork ask me and by when, what am I letting slip* — assembled across all your backlogs at once.
- **Not use**:
  - You want to LEARN / route the MAOS **framework** itself (which tool/protocol) → `maos-concierge`
    (framework-facing). This is **work-item-facing**.
  - You just need the raw aggregated N-Tree of everything, no prioritization/briefing → `work-compass`
    directly (this routes TO it and adds the prioritize + people-ask + brief layer).
  - You are mid-task in ONE session and need re-orientation → `pulse` directly.
  - A fresh **agent** woke with no context → `reactivate` (the agent-facing twin — incoming in PR #280;
    once merged).
  - You have a raw brain-dump to sort into tickets → `directive-braindump-triage`.

## The pipeline (5 phases — lean by default, deepened on demand)

```
PHASE 0  FRAME       classify the ask (daily catch-up? · drift/what-am-I-slipping? · who-owes-me? · full)
PHASE 1  GATHER      work-compass ── ONE N-Tree of ALL scattered work (7 CPT domains), stale/orphan/pending
PHASE 2  PRIORITIZE  pulse (Eisenhower 2x2, maos-resident) ──[--depth full]──► + ops-strategist 4-lens IF present
PHASE 3  SURFACE     people-ask view (who · when · by-when) + tag/categorize      ◄── newly authored (the gap)
PHASE 4  BRIEF       morning-briefing 7-section SitRep contract (state·done·in-flight·blockers·awaiting·risks·next)
PHASE 5  PRESENT     ONE operator briefing → next-action · Eisenhower quadrants · who-asked/by-when · loose-ends
```

**Composition discipline**: PHASES 1, 2, and 4 **delegate** to skills that already exist and are never
reimplemented here. Only PHASE 3 (people-ask projection + tag/categorize) and the PHASE-5 unified operator
assembly are authored by this conductor — they were the genuinely absent pieces.

**Proportionality** (over-engineering circuit-breaker): default depth is **quick** (0-1-2-3-5; PHASE 4
folds its contract into PHASE 5 without a separate pass). `--depth full` adds the ops-strategist 4-lens
brain + the full SitRep. Do not convene a strategy board to answer *"what's next?"*.

---

### PHASE 0 — FRAME (classify the ask, cheap)

One token sets the depth + which lens dominates: `catch-up` (default — full landscape + next-action) ·
`drift` (what am I slipping / loose-ends first) · `who-owes-me` (people-ask view first) · `full` (adds
ops-strategist). `--mode` overrides. Explicit operator instruction always wins.

### PHASE 1 — GATHER (delegate: `work-compass`)

Delegate to `work-compass` to aggregate ALL scattered work (Jira/Linear/GitHub/sessions/git) into ONE
N-Tree across the 7 CPT domains (ticket · worktree · branch · session · thread · process · graph-node),
with stale/orphan/pending flags. **Read-only** — `work-compass` already prints, never executes.
Re-use its output whole; do not re-aggregate.

### PHASE 2 — PRIORITIZE (delegate: `pulse` core · `ops-strategist` optional)

- **Core (maos-resident, always available)**: delegate to `pulse` — Eisenhower 2x2 classification, routing
  each item ∈ {now · delegate · defer-trigger · backlog · drop}. This is the community-portable prioritizer.
- **Richer (optional, user-scope)**: IF the user has `ops-strategist` (a user-scope agent — its 4-lens
  TPM+CoS+SRE+Agentic Eisenhower over 7 sources), `--depth full` may route to it for a deeper read.
  ⚠️ **Layer-purity**: `ops-strategist` is NOT a hard dependency — this skill is community-resident and
  MUST run fully on the maos-resident core alone. Probe for it; use it only if present.

**This conductor never computes its own Eisenhower.** It routes to `pulse` (or `ops-strategist`) — there
are already ≥2 prioritizers; a third would be entropy (anti-over-eng).

### PHASE 3 — SURFACE (newly authored — the people-ask view + tag/categorize)

The genuine gap: no tool projects *"who asked ME for what, and by when?"* as a first-class view. Build it
as a **read projection over the fields PHASE-1 already surfaced** — NOT a new store, NOT a fresh tracker
query (route-never-reimplement: `work-compass` is the tracker-access layer; pass it `--with-provenance`
so its N-Tree carries these native fields, then project — never re-fetch here):

| Field | Native source `work-compass` surfaces |
|---|---|
| `asked_by` (who asked) | Jira `reporter` · GitHub issue `author` · Linear `creator` · a memory `[[slug]]` note |
| `asked_at` (when) | issue `created` timestamp |
| `due` (by-when) | Jira `duedate` · GitHub milestone due · Linear `dueDate` · sprint end |

- **Projection**: over the PHASE-1 items, surface those where `asked_by ≠ operator` (a boss/cowork ask),
  sorted by `due` ascending, flagging overdue + due-soon.
- **`tag`/`categorize`** (the missing verbs): for an item lacking native provenance (a brain-dump, a loose
  note), the operator may attach `asked_by · asked_at · due · tags[] · category`. In this phase these are
  **PRINTED as a suggested command for approval** (e.g. the Jira/Linear edit, or a one-line memory tag) —
  never auto-written. No new store: native fields first, a light `[[slug]]` memory tag only for items with
  no native home.
- ⛔ **Never fabricate** a `due` or an `asked_by` that isn't in the source. An invented deadline is worse
  than none (anti-theater). "no due found" is a valid, correct value.

### PHASE 4 — BRIEF (contract: `morning-briefing`)

Adopt the `morning-briefing` 7-section SitRep contract as the briefing shape — state · done · in-flight ·
blockers · decisions-awaiting · risks · next-action — populated from PHASES 1-3. At quick depth this is a
formatting contract folded into PHASE 5; at `--depth full` it is a full `morning-briefing` pass.

### PHASE 5 — PRESENT (one operator briefing — read-only, review-before-act)

Assemble ONE scannable operator briefing (per the host's end-of-action briefing protocol §7 — executive,
recommended-first, risk-tagged):

1. **▶ NEXT ACTION** — the single highest-priority item + why (from PHASE 2's `now` quadrant).
2. **Eisenhower quadrants** — Q1/Q2/Q3/Q4 counts + top items (from `pulse`/`ops-strategist`, NOT recomputed).
3. **⏰ Who asked you / by when** — the PHASE-3 people-ask view, overdue-first.
4. **🧹 Loose ends** — stale/orphan/pending from PHASE-1 + any un-dispositioned item, per the host's
   loose-end-triage-queue (Taxis) no-silent-drop discipline: each gets a disposition suggestion.
5. **Compass footer** — one routing command per actionable node (delegate to the owning tool).

⛔ **SANITIZE** (unconditional): never echo a secret · credential · token · personal identifier into the
briefing — reference by name/location. **Read-only**: any write/notify/schedule is PRINTED for the operator
to run/approve, never executed by this skill.

---

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `--mode` | `catch-up` | `catch-up` · `drift` · `who-owes-me` · `full`. **Explicit operator instruction wins.** |
| `--depth` | `quick` | `quick` (0-1-2-3-5) · `full` (adds ops-strategist 4-lens IF present + full morning-briefing). |
| `--scope` | `all` | Which backlogs to gather — `all` · `jira` · `github` · `linear` · `sessions` (passthrough to work-compass). |
| `--who` | — | Filter the people-ask view to asks from one person. |
| `--lang` | `auto` | `pt` · `en` · `auto` (pt-BR for the operator, en-US for a machine consumer). |
| `--json` | off | Emit a typed briefing envelope for an agent consumer instead of prose. |

## Invariants (non-negotiable)

1. **Explicit operator instruction overrides every computed condition** — mode, depth, scope, language.
2. **Route-never-reimplement** — GATHER=work-compass, PRIORITIZE=pulse/ops-strategist, BRIEF=morning-briefing.
   This conductor authors ONLY the people-ask projection + tag/categorize + the unified assembly.
3. **Layer-purity** — runs fully on the maos-resident core (`work-compass`+`pulse`+`morning-briefing`);
   `ops-strategist` is an OPTIONAL user-scope enhancement, never a hard dependency.
4. **Read-only by default** — writes / notify / schedule are PRINTED for approval, never executed.
5. **On-demand only** — no hooks, no always-on runtime. MAOS stays the sole conductor (proactive firing /
   calendar-ingest / notify-channel are a SEPARATE, operator-confirmed later phase — they touch settings).
6. **Never fabricate** a `due`/`asked_by`/priority — "not found" is a valid value; SANITIZE is unconditional.
7. **Never computes its own Eisenhower** — always routes to an existing prioritizer (anti-over-eng).
8. **Bounded** — quick depth by default; do not convene ops-strategist to answer "what's next?".

## Anti-patterns

1. ❌ **Re-aggregating** — walking Jira/GitHub yourself instead of delegating `work-compass`.
2. ❌ **A 5th Eisenhower generator** — computing priority here instead of routing to `pulse`/`ops-strategist`.
3. ❌ **Hard-depending on `ops-strategist`** — it is user-scope; a community skill must not require it (Invariant 3).
4. ❌ **Auto-executing a write/notify/schedule** — this front-door prints for approval; it never acts silently.
5. ❌ **Installing an always-on hook** — that is a SEPARATE operator-confirmed phase, not this on-demand skill.
6. ❌ **Fabricating a deadline / who-asked** — an invented due date is worse than none (anti-theater).
7. ❌ **Framework-routing** — teaching which MAOS tool to use is `maos-concierge`'s job, not this.

## Quality tests (6 self-validity)

1. **Self-application** — this conductor was itself designed by gathering the existing landscape (a recon),
   prioritizing the one genuine gap over the redundant, and presenting a single routed recommendation. ✅
2. **Non-contradiction** — composes `work-compass`/`pulse`/`morning-briefing` without overriding any;
   distinct from `maos-concierge` (framework), `reactivate` (agent-facing twin), `ops-strategist` (the
   optional brain it routes to). ✅
3. **Survival** — applied to itself it advocates route-don't-reimplement + read-only; it does exactly that. ✅
4. **Bounded-responsibility** — quick default · route-only core · read-only · on-demand · qualitative sunset. ✅
5. **Explicit-exception** — operator override (Invariant 1) · the not-use routing list · optional-ops-strategist. ✅
6. **Utility-sunset** — below. ✅

## Sunset (qualitative, not counter-based)

Deprecate when ANY: the host ships a native operator work-focus dashboard that subsumes this · `ops-strategist`
is promoted community-resident AND grows a front-door making this redundant · the concierge/conductor family
absorbs it into a unified entry · operator retraction · ≥3 false-fires (fired on a non-work-focus intent).

## Refs

- Composed (never reimplemented): `skills/work-compass` (GATHER) · `skills/pulse` (Eisenhower core) ·
  `skills/morning-briefing` (SitRep contract).
- Optional (user-scope, probed-not-required): `ops-strategist` (the 4-lens TPM+CoS+SRE+Agentic brain).
- Siblings (distinct): `skills/maos-concierge` (framework-facing) · `skills/reactivate` (Entelecheia,
  incoming PR #280 —
  agent-facing twin) · `skills/session-reentry` (Anamnesis) · `skills/directive-braindump-triage`.
- Governance: the host's end-of-action briefing protocol §7 (PRESENT format) · Cowork-Process-Topology §9
  (the 7 CPT domains work-compass renders) · loose-end-triage-queue / Taxis (the no-silent-drop discipline
  behind PHASE-5 loose-ends) · layer-precedence-policy (the Layer-purity of Invariant 3).
- Named by `skills/anima` per the host's naming authority; recorded in `bin/artifact-registry`.
- Grounding: Xenophon, *Oeconomicus* (the oikonomos as household steward); Greek *οἰκονόμος* (LSJ).
