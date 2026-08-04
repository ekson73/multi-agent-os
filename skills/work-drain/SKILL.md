---
name: work-drain
description: |
  Given one or more <object-targets> (a sprint, a backlog query, open PRs, tracker issues,
  a filter), DISCOVER every matching item across trackers, DERIVE a work-register from them,
  ORDER it (Eisenhower x dependency-DAG), and DRAIN it item-by-item to quiescence —
  autonomously, unattended, resumable. Level-triggered by design: every pass RE-DERIVES the
  register from the trackers (the source of truth) instead of replaying a stored queue, so a
  mid-drain interruption resumes correctly and a re-run is a no-op once empty. Thin conductor:
  delegates discovery to work-compass, prioritization to pulse, and EACH item's actual work to
  quiesce --scope ticket:<id> — reimplements no loop, no PDCA, no merge gate. Soul-name: Antlia
  (the bilge-pump: drains a hold to empty, load by load).
  Triggers: "work-drain", "drain the sprint", "drain the backlog", "work through my tickets",
  "clear the sprint", "item by item until empty", "drenar o sprint", "drenar o backlog",
  "trabalhe nos tickets um por um", "esvaziar a fila".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
---

# Work-Drain — *Antlia*

> **Identity**: *Antlia* — Ancient Greek **ἀντλία**, a ship's bilge and by extension the pump
> that empties it; Latinized by Lacaille (1752) as a constellation honoring the air-pump, and
> shortened to one word by John Herschel (1844). A bilge-pump does exactly this skill's job:
> it drains a hold **to empty**, **load by load**, and it is **safe to restart** — you re-read
> the water level, you never replay a log of past strokes.
> **Cross-link slug**: `[[work-drain]]`

## Purpose

Bridge the gap between a **tracker** (where work is declared) and the **loop family** (which
knows how to finish one item). Nothing in the family builds a work-register from external
sources: `gap-loop` drives a *self-derived* gap-register, `quiesce` drives *one* scope,
`chief-of-staff` reports to a human read-only. `work-drain` is the conductor that turns
"a sprint" into an ordered sequence of `quiesce` invocations and runs it to empty.

## When to use

- A sprint / backlog / label / filter has N open items and the operator wants them worked
  through unattended, not triaged into a report.
- Resuming an interrupted drain — re-invoke; it re-derives and continues.
- Draining a set of open PRs awaiting convergence.

## When **not** to use

- **ONE** known item → `/maos:quiesce --scope ticket:<KEY>` directly (this skill would be ceremony).
- Operator wants to *decide* what to focus on, not have it executed → `/maos:chief-of-staff` (read-only).
- Gaps you derive yourself rather than read from a tracker → `/maos:gap-loop`.
- Session-wide cleanup with no external register → `/maos:quiesce` bare.

## Level-triggered by design (the load-bearing invariant)

Kubernetes controllers are **level-triggered**: each reconciliation re-reads desired and actual
state and computes the correction, rather than reacting to the event that woke it. A missed,
duplicated, delayed or reordered event is therefore recoverable. `work-drain` adopts this
directly:

| Edge-triggered (rejected) | Level-triggered (this skill) |
|---|---|
| Build a queue once, pop items, trust the queue | **Re-derive the register from the trackers every pass** |
| Interruption loses position | Interruption is free — the next pass re-reads the world |
| Stale queue drifts from reality | Register cannot drift; the tracker *is* the state |
| Needs a durable local queue file | Needs **no local queue** — no file to corrupt or desync |

**Consequences (binding):**
- The register is **derived, never stored** as the source of truth. A cached copy is a *hint*
  for ordering within a pass; it is discarded at the start of the next pass.
- **Idempotent-resume is inherent**, not bolted on: a re-run after a crash re-derives, sees the
  already-closed items are gone from the query, and continues with what remains.
- **Re-running on an empty sprint is a no-op** — the correct end state, not a failure.
- Never trust the search index as authoritative: it lags. Confirm each item's real state with
  a direct `get` before acting on it.

## Parameters

| Flag | Default | Meaning |
|---|---|---|
| `<object-targets>` (positional) | *(required)* | What to drain: `sprint:current` · `sprint:<name>` · `jql:"<query>"` · `label:<x>` · `prs:open` · `issues:<repo>` · a comma-separated mix |
| `--owner` | `currentUser()` | Whose items; `any` widens (bounded by `--max-items`) |
| `--filter` | `open` | `open` \| `pending` \| `all` — maps to the tracker's not-Done predicate |
| `--sort` | `eisenhower` | `eisenhower` \| `dependency` \| `updated` \| `manual` (dependency-DAG always breaks ties) |
| `--tracker` | `auto` | `auto` \| `jira` \| `linear` \| `github` — `auto` probes which surfaces are live |
| `--max-items` | `20` | Hard cap per drain (bounded blast-radius; the rest is reported, not silently dropped) |
| `--max-attempts` | `2` | Per-item attempt cap before quarantine (poison-item guard) |
| `--auto-merge` | `hold` | `authorized` \| `hold` \| `off` — forwarded to `quiesce` |
| `--auto-merge-reason` | — | required-non-empty when `authorized`; passing it IS the authorization |
| `--autonomy-threshold` | `0.85` | forwarded to `quiesce` |
| `--max-pdca` | `6` | forwarded to `quiesce` |
| `--dry-run` | off | Derive + order + print the register; drain nothing |

> `--auto-merge` defaults to **`hold`**, not `authorized`. A conductor that merges by default
> across N items multiplies blast-radius by N. The operator authorizes explicitly, per drain.

## How it works

```text
PASS (repeat until the register derives empty):

  1. DERIVE   re-read the trackers -> raw item set        (level-triggered; no stored queue)
              confirm each item's real state via direct `get` (the index lags)
  2. ORDER    Eisenhower quadrant (delegate: pulse) x dependency-DAG topological sort
              cross-domain shape when unclear (delegate: work-compass)
  3. SELECT   the next item whose dependencies are all satisfied
              skip quarantined items (see Poison-item guard)
  4. DRAIN    /maos:quiesce --scope ticket:<id> [forwarded flags]
  5. VERIFY   re-read the item; did it actually close?
              closed -> continue | unchanged -> count an attempt | error -> quarantine check
  6. LOOP     back to 1 — the register is re-derived, never popped
```

Step 6 is the whole design. There is no "next item pointer" to lose.

## Composition (what it delegates — it reimplements none of these)

| Concern | Delegated to |
|---|---|
| Cross-domain item discovery (ticket ↔ worktree ↔ branch ↔ PR) | `skills/work-compass` |
| Eisenhower 2×2 prioritization | `skills/pulse` (via `chief-of-staff`'s established path) |
| Actually finishing ONE item (goal-loop + PDCA + merge gate) | `skills/quiesce --scope ticket:<id>` |
| Abstract acceptance criterion → measurable | `skills/decompose-abstract-to-measurable` (Prisma) |
| Adversarial verification on a hard-trigger | `skills/red-team` (Elenchus) |
| Independent decision when score is short | `skills/council-gate` (Boule) → HITL residue only |
| Workspace isolation / exit hygiene | `skills/preflight` · `skills/postflight` |

If a phase here starts to grow its own PDCA, merge gate, or delegation machinery — that is the
signal it has drifted from conducting into reimplementing. Cut it back.

## Poison-item guard (the failure mode a naive drain hits first)

One item that always fails must never block the drain or burn the budget:

- **`--max-attempts` (default 2)** per item, per drain.
- On exceeding it: **quarantine** the item — skip it, record why, continue with the rest.
- A quarantined item is **reported, never silently dropped**: it lands in the final briefing and
  gets a tracker comment stating the attempts and the blocking reason.
- Distinguish **blocked** (a real dependency is unmet — retry next pass, it may be satisfied by
  then) from **failing** (the work itself errors — quarantine and surface it).
- If ≥half the register quarantines in one drain, **stop and escalate** — that is a systemic
  fault, not N item faults. Draining harder makes it worse.

## Bounds (anti-runaway)

- `--max-items` caps register size per drain; the overflow is **listed** in the briefing.
- `--max-attempts` caps per-item retries.
- `quiesce`'s own bounds apply per item (`--max-pdca`, depth ≤ 2, 6-attempt escalation).
- **No silent truncation, ever** — anything the drain declines to touch is named in the report.
- HUMAN_DOMAIN + non-negotiable guardrails (secrets · production PII · force-push protected ·
  prod/irreversible · cross-org) halt the drain → HITL, regardless of item count.

## Autonomy posture

Autonomy is a **multiplier**: draining N items unattended multiplies both throughput *and* the
cost of a wrong call. Rigor therefore scales **up** with N, never down.

- Per item: CASC gates + `autonomy_score` (delegated through `quiesce`).
- Score short → Score-Uplift (≤3 honest attempts) → **MoE debate-converge → Council decides**
  (verifier ≠ generator) → only the irreducible residue reaches HITL, carrying **ranked
  recommendations + rationale**. Never a blank ask.
- Red-team is **mandatory** on any hard-trigger (secrets · prod PII · irreversible ∧ blast ·
  guardrail/governance self-edit · external disclosure · fail-open flip · untrusted input
  steering a side-effecting action). Independence unavailable at HIGH → **HOLD, do not force**.

## Tracker-agnostic

`--tracker=auto` probes which surfaces are actually live before assuming one. Route by context:
Jira for corporate work, Linear for personal, GitHub Issues for repo-scoped. **This repo's own
tracker is GitHub Issues** (see `CONTRIBUTING.md`) — the skill must not hardcode Jira.

⛔ **A negative probe is not proof of absence.** Before concluding "no items", run a positive
control: same instrument, same query shape, something you know exists. A silent empty result
from an under-reaching instrument looks identical to a genuinely empty backlog — and the two
demand opposite actions.

## Relationship to siblings

| Tool | Register comes from | Scope | Drives |
|---|---|---|---|
| `work-drain` (this) | **external trackers** (derived each pass) | N items | ordered drain → `quiesce` per item |
| `quiesce` | the session / one scope | ONE scope | termination predicate → steady state |
| `gap-loop` | **self-derived** gap-register | N gaps | MoE resolve → validate → persist |
| `chief-of-staff` | external trackers | operator's plate | **reports** (read-only), does not execute |
| `auto-pilot` | one operator goal | ONE goal | decompose → spawn → converge |

`work-drain` is `chief-of-staff`'s executing counterpart: same discovery lineage, but it
*drains* instead of *briefing*.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: drain this repo's own open issues before claiming the skill works.
- **Persist-over-fail**: the tracker *is* the write-ahead log — update the item before and after,
  so a collapse is recoverable from the tracker alone.
- **DRY / KIS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **Boy-Scout** — leave every repo cleaner than found: no stale branches or worktrees, no loose
  ends, no unanswered comments.
- **No self-destructive decisions** — nothing that boomerangs onto a future session.

## Examples

```text
/maos:work-drain sprint:current
/maos:work-drain sprint:current --auto-merge=authorized --auto-merge-reason="sprint drain, operator-authorized"
/maos:work-drain jql:"project = VKS AND assignee = currentUser() AND sprint IN openSprints() AND statusCategory != Done"
/maos:work-drain issues:ekson73/multi-agent-os --tracker=github --max-items=5
/maos:work-drain prs:open --dry-run
```

## Validation

- `--dry-run` on a known sprint prints a register matching the tracker's own count.
- Interrupting mid-drain and re-invoking resumes without redoing closed items (level-triggered).
- Re-running on a drained sprint is a clean no-op.
- A deliberately-failing item quarantines after `--max-attempts` and appears in the briefing.
- Nothing the drain skipped is absent from the final report.

## Reporting

Per item and at the end — executive briefing ≤200 words: requested · executed · gaps · pending ·
questions-not-asked · questions-unanswered · decisions-not-taken. Plus:

```text
STATUS CHECKLIST
  🔴 not-started · 🟡 in-progress · 🟠 need-HITL · 🟢 agentic-done <NN%> · 🔵 human-done
  quarantined: <n> (each with reason) · overflow beyond --max-items: <n>
Autonomy pulse: X% green
```

⚠️ WIP ≤ 3 · ≤1 question per turn · deliver finished work, not question-batches · always name
harness + repo + session in the handoff.

## Related

`skills/quiesce/SKILL.md` (per-item driver) · `skills/chief-of-staff/SKILL.md` (read-only twin) ·
`skills/gap-loop/SKILL.md` (self-derived register sibling) · `skills/work-compass/SKILL.md`
(discovery) · `skills/pulse/SKILL.md` (Eisenhower) · `skills/preflight`/`postflight` ·
`commands/work-drain.md` (command surface).

## Versioning

v0.1.0 — initial. Named by the `anima` methodology (`[C-naming]`); soul-name *Antlia*
(ἀντλία, the bilge-pump). Level-triggered design grounded in the Kubernetes controller pattern.

## License

MIT (inherits the plugin's license).
