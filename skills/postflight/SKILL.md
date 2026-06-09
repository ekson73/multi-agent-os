---
name: postflight
description: |
  Use at the END of a session/action — especially before the operator compacts or
  clears the conversation — to close the workspace out cleanly and hand the work off.
  Three responsibilities: (P1 SWEEP) a boy-scout exit-hygiene sweep that persists/fixes
  loose ends across git, docs, ADRs, changelogs, memories, rules and tickets; (P2 DEBRIEF)
  calculate the session map (objectives N-Tree, gaps, pendings, undecided, next actions
  by Eisenhower); (P3 HANDOFF) emit an ai-agnostic continuation seed a fresh amnesic agent
  can resume from. The end-of-session counterpart to the `preflight` skill. Reads whatever
  governance is present at invocation (CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories)
  and adapts.
version: 0.1.0
triggers:
  - postflight
  - run postflight
  - wrap up this session
  - end of session
  - close the session
  - before compact
  - hand off this work
  - generate a continuation prompt
  - boy-scout sweep before i leave
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: worktree-lifecycle
  lifecycle-stage: operate
  cross_link_slug: postflight
  dogfood_status: in-progress
  id: MAOS-SKILL-postflight
  type: skill
  status: active
  owner: maos-community
  pairs-with: preflight
  dogfooding_validation:
    cycles_completed: 0
    cycles_required: 2
    promotion_eligible: false
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Task
---

# Postflight Skill

## Purpose

A **post-flight debrief** for agentic work, the mirror of `preflight`. Where a pilot's
*pre-flight check* readies the aircraft before departure, the *post-flight inspection +
debrief* happens after landing: walk the aircraft for issues, log what happened, and prep
it for the next flight. `postflight` does the same for a session — **close it out without
loose ends, debrief what happened, and leave a seed the next (amnesic) agent can fly with.**

It exists because an AI agent has no reliable cross-session memory: when the operator
compacts or clears the conversation, everything in volatile context is lost. `postflight`
turns that volatile state into durable, hand-off-able artifacts **before** the loss.

## When to Use

- At the **end of a session**, or before the operator runs `/compact` or `/clear`.
- At the **end of an action/task** that produced state worth persisting.
- When you are about to **hand off** to a fresh agent, a future session, or the operator.
- The bundled **PreCompact hook** runs a deterministic safety-net snapshot automatically
  (so a partial seed always survives, even if this skill was never invoked).

## Trigger Phrases

"postflight" · "wrap up this session" · "before compact" · "hand off this work" ·
"generate a continuation prompt" · "boy-scout sweep before I leave"

## Core Rule

```
SWEEP (P1) → DEBRIEF (P2) → HANDOFF (P3)
Each step is SAFE-or-DEFER. Never clobber. Never block. HANDOFF requires SWEEP+DEBRIEF (DoR).
The environment MUST be left better, safer, and more traceable than it was found.
```

## The Responsibilities (P1–P3)

| # | Responsibility | How (safe-or-DEFER) | Composes |
|---|---|---|---|
| **P1** | **SWEEP** — operationalize the exit-hygiene checklist: no loose ends, no banana peels | for each axis {git · docs · ADRs · changelogs · memories · rules · tickets/backlogs · worktrees/branches · stale metrics}: *survey* gaps/opportunities → classify by Eisenhower → **act** (persist/fix/version/commit/push/close) **or register** a tracked follow-up. Read-before-discard is mandatory. | `protocols/exit-hygiene.md`, `skills/sync-to-git`, `skills/quiesce`, `commands/worktree.md`, `bin/dogfood-mark` |
| **P2** | **DEBRIEF** — calculate the session map | objectives N-Tree (primary/secondary/auxiliary × sequential/parallel/recursive), work-done, gaps, pendings, undecided decisions, unasked/unanswered questions, next-actions ranked by Eisenhower (non-blocked first). | `skills/morning-briefing --mode=recap` |
| **P3** | **HANDOFF** — emit the continuation seed | a minimal-sufficient, ai-agnostic seed (structured agent-register envelope + human mirror) a fresh amnesic agent can resume from; print to screen + best-effort clipboard. DoR = P1+P2 done. | this skill (the elevation over `morning-briefing` recap) + `skills/session-fission` (seed shape) |

**SWEEP never clobbers**: a dirty tree, a divergence-with-conflict, a held `.git/index.lock`,
or an untracked file you did not create → **DEFER** (report/register, do not act). Deleting or
discarding anything requires reading it first (exit-hygiene "Read Before Discard").
**HANDOFF is gated**: never emit a seed before the sweep + debrief, or the seed lies about
the state it claims to capture.

## Governance Discovery (read at invocation — the adaptive core)

Before deciding what "clean" means or how to name/route a follow-up, **read whatever
governance the target repo exposes right now** and adapt (do NOT hardcode):

1. `Read`/`Glob` for `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `README.md`,
   `protocols/*` (esp. `exit-hygiene.md`), `docs/*`, and any `memory`/`MEMORY.md` present.
2. Extract: the exit-gate checklist, the changelog/versioning convention, the
   ticket/issue provider + close-criteria, the branch/PR/worktree workflow, the
   memory-persistence path.
3. Apply *those* conventions in P1's act/register decisions. If none are found, fall back
   to the exit-hygiene defaults below.

## Algorithm

```
0. Governance discovery (above) — derive the repo's exit + handoff conventions.
1. P1 SWEEP:
   - git: status clean? worktrees only main? stale branches? unpushed commits? uncommitted
     edits in main checkout? → commit-via-worktree / push / prune / remove (compose sync-to-git,
     worktree); open PR or DEFER per workflow. Drive open PRs toward green (compose quiesce).
   - docs/ADRs/changelogs: versions reflect this session's changes? cross-refs consistent?
     stale version strings? → fix NOW (P1, never "next session").
   - memories/rules: durable lessons worth persisting? → persist per the repo's memory path.
   - tickets/backlog: any verifiably-DONE ticket (DoD met + PR merged + deliverables) → close
     with an audit comment; out-of-scope items → register a tracked follow-up (ticket/issue/TODO).
   - Classify every surfaced item by Eisenhower; act on Q1/Q2, register Q3, note/drop Q4.
2. P2 DEBRIEF: invoke `morning-briefing --mode=recap` → objectives N-Tree + Eisenhower
   next-actions + gaps/pendings/undecided/unasked-Qs. This is the session map.
3. P3 HANDOFF: synthesize the continuation seed (below) from P1+P2 → print + clipboard.
4. Emit a concise exit summary (swept items, deferred items, seed location).
```

## The Continuation Seed (the P3 deliverable)

A **minimal-sufficient, ai-agnostic** resume packet for a *fresh, amnesic* agent (per the
amnesia premise: a gifted agent with no cross-session recall). Two registers, same content:

- **Agent register** (default — economical, machine-parseable; emit as a JSON-RPC-style
  envelope, `--lang` selectable):

```json
{"jsonrpc":"2.0","method":"session.continuation","params":{
  "goal":"<one-line mission>",
  "context":"<state-of-world the next agent needs>",
  "git":{"repo":"<name>","branch":"<b>","worktree":"<path|none>","prs":["#<n> <state>"]},
  "objectives":{"primary":["..."],"secondary":["..."],"auxiliary":["..."]},
  "done":["..."], "in_flight":["..."],
  "gaps":["..."], "pendings":["..."], "undecided":["..."], "unasked_questions":["..."],
  "next_actions":[{"task":"...","eisenhower":"Q1|Q2|Q3|Q4","blocked_by":null}],
  "governance_refs":["AGENTS.md","CONTRIBUTING.md","protocols/exit-hygiene.md"],
  "dna":"<inherited agentic principles: free-but-accountable · holistic-predictability · agnostic-self-healing>",
  "resume_instructions":"Run /maos:preflight first; then start at the first non-blocked next_action."
},"data":{"layer":"community"}}
```

- **Human mirror**: the same, rendered as a short scannable briefing for the operator.

Output: **print to screen + best-effort clipboard** (auto-detect `pbcopy`/`wl-copy`/`xclip`/
`xsel`/`clip.exe`), sanitized (never copy secrets/file-bodies — metadata only). The seed is
designed so the next agent runs `/maos:preflight` (orient) then resumes from the first
non-blocked next-action — closing the lifecycle loop `preflight → work → postflight`.

## Conditions / Invocation

| Condition | Path |
|---|---|
| operator-invoked / on-demand | `/maos:postflight` (full) or a sub-phase `sweep` / `debrief` / `seed` |
| auto-invoked before context loss / `compact` / `clear` / context>N% | the **PreCompact hook** (deterministic safety-net snapshot; the skill produces the rich seed when an agent is live) |
| mid-action checkpoint | `/maos:postflight debrief` (recap without the full sweep) |

## Examples

**Before the operator compacts:**
```
You: "I'm about to /compact — wrap this up."
postflight P1: 1 unpushed commit on feat/x → pushed; PR #42 → driven green; 1 stale ref → pruned.
postflight P2: objectives 2/3 done; 1 gap (tests for edge-case); 1 undecided (naming of Y).
postflight P3: 🌱 continuation seed → printed + copied to clipboard. Next agent: /maos:preflight then task #1.
```

**Dirty tree (DEFER — never clobber):**
```
postflight P1: branch=main tree=DIRTY → SWEEP DEFERRED (uncommitted tracked changes).
→ commit or stash via a worktree, then re-run /maos:postflight. Seed still emitted (state honestly marked DIRTY).
```

## Anti-patterns (do NOT)

1. ❌ Emit a HANDOFF seed before the SWEEP+DEBRIEF (the seed would misreport the state).
2. ❌ "Fix next session" for a known inconsistency — fix NOW (exit-hygiene).
3. ❌ Blind `rm`/`git clean`/`checkout --`/discard without reading the file first.
4. ❌ Make `git status` green as a *goal* by deleting/committing without understanding (cargo-cult hygiene).
5. ❌ Fake the agentic synthesis inside the PreCompact shell hook — the hook is a deterministic snapshot only; the rich seed is the skill's job.
6. ❌ Re-implement git sync / recap internals — compose `sync-to-git` / `quiesce` / `morning-briefing`, don't copy them.
7. ❌ Leak secrets or file-bodies into the seed/clipboard — metadata only, sanitized.

## Related Multi-Agent OS Artifacts

- `skills/preflight/SKILL.md` — the **start-of-session** counterpart (orient + heal + isolate); together they bound the session: `preflight → work → postflight`.
- `protocols/exit-hygiene.md` — the Boy-Scout exit-gate checklist P1 operationalizes (policy → this executes it).
- `skills/morning-briefing/SKILL.md` — `--mode=recap` is the P2 session-map substrate P3 elevates into an agent seed.
- `skills/sync-to-git/SKILL.md` · `skills/quiesce/SKILL.md` — git close-out + PR convergence P1 composes.
- `skills/session-fission/SKILL.md` — orthogonal: it *splits* a tangled session into N seeds; P3 emits *one* resume seed for continuity.
- `commands/worktree.md` · `bin/dogfood-mark` — worktree cleanup + dogfood-cycle ledger.
- `commands/postflight.md` → `/maos:postflight` (ergonomic entry point).
- `plugin-scripts/governance/postflight-precompact.sh` — PreCompact hook (deterministic seed snapshot; never blocks).

## License

MIT (matches the multi-agent-os repo `LICENSE`).
