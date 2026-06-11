---
name: postflight
description: |
  Use at the END of a session/action — especially before the operator compacts or
  clears the conversation — to close the workspace out cleanly and hand the work off.
  Three responsibilities: (P1 SWEEP) a boy-scout exit-hygiene sweep that persists/fixes
  loose ends across git, docs, ADRs, changelogs, memories, rules and tickets; (P2 DEBRIEF)
  calculate the session map (objectives N-Tree, gaps, pendings, undecided, next actions
  by Eisenhower); (P3 HANDOFF) emit an ai-agnostic continuation seed a fresh amnesic agent
  can resume from; (P3.5 SPAWN, optional, default-ON) launch a fresh, pre-seeded `claude`
  continuation session so the work continues across the compact/clear boundary. The
  end-of-session counterpart to the `preflight` skill. Reads whatever governance is present
  at invocation (CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories) and adapts.
version: 0.6.1
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
  - spawn the continuation session
  - spawn the next session
metadata:
  version: "0.6.1"
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
SWEEP (P1) → DEBRIEF (P2) → HANDOFF (P3) → [SPAWN (P3.5, optional, default-ON)]
Each step is SAFE-or-DEFER. Never clobber. Never block. HANDOFF requires SWEEP+DEBRIEF (DoR).
SPAWN requires the P3 seed (DoR) + passes the spawn guardrails; opt out with --no-spawn.
The environment MUST be left better, safer, and more traceable than it was found.
```

## The Responsibilities (P1–P3.5)

| # | Responsibility | How (safe-or-DEFER) | Composes |
|---|---|---|---|
| **P1** | **SWEEP** — operationalize the exit-hygiene checklist: no loose ends, no banana peels | for each axis {git · docs · ADRs · changelogs · memories · rules · tickets/backlogs · worktrees/branches · stale metrics}: *survey* gaps/opportunities → classify by Eisenhower → **act** (persist/fix/version/commit/push/close) **or register** a tracked follow-up. Read-before-discard is mandatory. | `protocols/exit-hygiene.md`, `skills/sync-to-git`, `skills/quiesce`, `commands/worktree.md`, `bin/dogfood-mark` |
| **P2** | **DEBRIEF** — calculate the session map | compose `morning-briefing` (its 7-section state: done · in-flight · blockers · decisions · next-action) then **synthesize on top** the objectives N-Tree (primary/secondary/auxiliary × sequential/parallel/recursive), gaps, pendings, undecided decisions, unasked/unanswered questions, next-actions ranked by Eisenhower (non-blocked first). Then **render the glance-and-know locus** — D2 status line + D3 ntree + D4 conv — via `bin/locus.sh` (the compact projection of this debrief; grammar SSOT `references/locus-spec.md`), **and the end-of-action scorecard** — `bin/scorecard.py --model N` where `N` is chosen by `bin/scorecard-next-model.sh` (deterministic 1→7 round-robin; see "The End-of-Action Scorecard" below). | `skills/morning-briefing`, `bin/locus.sh`, `bin/scorecard.py`, `bin/scorecard-next-model.sh` |
| **P3** | **HANDOFF** — emit the continuation seed | a minimal-sufficient, ai-agnostic seed (structured agent-register envelope + human mirror) a fresh amnesic agent can resume from (the seed carries the D1 `locus` field `<status>·<anchor>·<slug>[·#seq]`); print to screen + best-effort clipboard. DoR = P1+P2 done. | this skill (the elevation over `morning-briefing` recap) + `skills/session-fission` (seed shape) |
| **P3.5** | **SPAWN** *(optional, default-ON)* — launch the next session, pre-seeded | hand the P3 seed to `bin/spawn-continuation.sh`, which launches a fresh **named** detached `claude` session (tmux/cmux) — the name IS the D1 locus (`<status> · <anchor> · <slug> · #<short>`, e.g. `🟡 · VKS-123 · payment-retry · #a1b2c3d4`; pass the ticket via `--ticket` so it anchors, keep the `--slug` to the 2-4-word work essence — locus dedupes anchor-repeated tokens; emoji-first experiment, `POSTFLIGHT_NAME_STYLE=legacy` restores the ascii `<ticket>-<slug>-#<short>`) — with the seed injected as durable system context — so the work *continues itself* across the compact/clear boundary instead of waiting on a manual paste. DoR = P3 seed. Opt out: `--no-spawn`. | `bin/spawn-continuation.sh` (consumes the P3 seed; reuses `session-fission`'s reseed idea) |

**SWEEP never clobbers**: a dirty tree, a divergence-with-conflict, a held `.git/index.lock`,
or an untracked file you did not create → **DEFER** (report/register, do not act). Deleting or
discarding anything requires reading it first (exit-hygiene "Read Before Discard").
**HANDOFF is gated**: never emit a seed before the sweep + debrief, or the seed lies about
the state it claims to capture.
**SPAWN is guarded** (a real session burns tokens — high-blast):
1. **Kill-switch** — `POSTFLIGHT_SPAWN=0` → never spawn (deterministic opt-out).
2. **Idempotency** — one continuation per source session (marker `~/.claude/jobs/<src>/.continuation-spawned`; `--force` overrides).
3. **Anti-recursion** — `POSTFLIGHT_SPAWN_DEPTH` cap (default 1): a spawned child won't auto-chain another spawn until it does real new work.
4. **Capability-detect** — no `claude`/launcher → graceful no-op + print the resume command (never errors the session).
5. **Sanitization** — refuses to inject a seed that smells like a secret (seed is metadata-only).
6. **Audit-trail** — one line per spawn under `~/.claude/jobs/continuation-spawns.log`.
7. **`--dry-run`** — preview the exact `claude …` command, launch nothing.

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
2. P2 DEBRIEF: invoke `morning-briefing` for the 7-section state, then synthesize ON TOP the
   objectives N-Tree + Eisenhower next-actions (non-blocked first) + gaps/pendings/undecided/
   unasked-Qs. (The community `morning-briefing` provides state + next-action; postflight adds
   the N-Tree + Eisenhower ranking.) This is the session map — then render it as the
   glance-and-know locus (D2+D3+D4) via `bin/locus.sh`, AND render the end-of-action
   scorecard: `N=$(bin/scorecard-next-model.sh)` (round-robin selector; honours
   `POSTFLIGHT_SCORECARD_MODEL` override) then build the params JSON from the P1/P2
   state (verdict · autonomy pulse · vitals · checklist · whats_left · tickets) and
   `printf '%s' "$params" | bin/scorecard.py --model "$N" --auto-git --repo <repo>`.
   The renderer is PURE (no side-effects); the rotation pointer lives in the selector.
3. P3 HANDOFF: synthesize the continuation seed (below) from P1+P2 → print + clipboard.
3.5 P3.5 SPAWN (default-ON; skip on --no-spawn / kill-switch / depth-cap / already-spawned):
   write the P3 seed to a file, then `bin/spawn-continuation.sh --ticket <KEY> --slug <kebab>
   --status <glyph> --seed <seedfile>` → launches the pre-seeded continuation session named
   with the D1 locus (or registers + prints the resume command if no launcher). Surfaces the
   session name + attach hint.
   SLUG QUALITY (the name is read at a glance): 2-4 kebab words, the ESSENCE of the next
   work (payment-retry · judge-round-a3). Never embed the ticket id / repo name / status —
   pass the ticket via --ticket (it becomes the anchor); locus drops anchor-duplicated
   tokens anyway (spec: references/locus-spec.md "slug quality + normalization").
4. Emit a concise exit summary (swept items, deferred items, seed location, spawned session).
```

## The Continuation Seed (the P3 deliverable)

A **minimal-sufficient, ai-agnostic** resume packet for a *fresh, amnesic* agent (per the
amnesia premise: a gifted agent with no cross-session recall). Two registers, same content:

- **Agent register** (default — economical, machine-parseable; emit as a JSON-RPC-style
  envelope, `--lang` selectable).

  **SSOT (v0.6.0)**: the full seed shape lives in
  [`templates/continuation-seed.template.json`](templates/continuation-seed.template.json)
  and its field-by-field contract in
  [`references/continuation-seed-contract.md`](references/continuation-seed-contract.md)
  (REQUIRED resume-spine: `who_you_are` · `bootstrap_order` · `inherited_state` · `mission`
  · `guardrails` · `dod` · `dag` · `refs` · `resume_instructions`; plus the optional debrief
  fields). Populate the template — do NOT re-derive the shape inline. Short excerpt:

```json
{"jsonrpc":"2.0","method":"session.continuation","params":{
  "who_you_are":"<role the resuming agent assumes>",
  "bootstrap_order":["<ordered read #1>","<ordered read #2>"],
  "inherited_state":{"verified_facts":["..."],"branches":["<b>@<sha>"],"env":["..."]},
  "mission":["<one-line mission>","<step 2>"],
  "guardrails":["..."], "dod":["..."], "dag":["<what comes after>"],
  "refs":{"git":"<repo+branch+PRs>","ticket":"<key|none>","memory":"<path|none>","session":"<id>"},
  "goal":"<one-line mission>",
  "next_actions":[{"task":"...","eisenhower":"Q1|Q2|Q3|Q4","blocked_by":null}],
  "resume_instructions":"Run /maos:preflight first; then follow bootstrap_order; then the first non-blocked next_action."
},"data":{"layer":"community","contract":"skills/postflight/references/continuation-seed-contract.md","contract_version":"1.0.0"}}
```

- **Human mirror**: the same, rendered as a short scannable briefing for the operator.

Output: **print to screen + best-effort clipboard** (auto-detect `pbcopy`/`wl-copy`/`xclip`/
`xsel`/`clip.exe`), sanitized (never copy secrets/file-bodies — metadata only). The seed is
designed so the next agent runs `/maos:preflight` (orient) then resumes from the first
non-blocked next-action — and, when **P3.5 SPAWN** fires, that next agent is *launched
already holding the seed*, closing the loop `preflight → work → postflight → (spawn) → preflight …`.

## The End-of-Action Scorecard (a P2 DEBRIEF output)

`bin/scorecard.py` renders a glanceable end-of-action **scorecard** (verdict · autonomy
pulse · vitals bars · checklist · what's-left · tickets) in one of **7 layout models**. It is
a **PURE renderer** by contract — same params → same output, no side-effects — so it consumes
a params JSON (built by the agent from the P1 SWEEP + P2 DEBRIEF state) and self-derives only
git/PR facts (`--auto-git`).

**Model selection — round-robin (interim) → dynamic (target):**

- **Now (round-robin):** `bin/scorecard-next-model.sh` is the deterministic 1→7 selector. It
  keeps the renderer pure by holding the rotation pointer **outside** it, in **user-scope**
  state (`~/.claude/jobs/.postflight-scorecard-model`) — so the operator is exposed to all 7
  models across sessions *and repos* (the exposure goal is operator-global, not per-repo). Per
  operator decision 2026-06-10 (*"deixe lançado em round-robin até eu me acostumar e decidir"*):
  rotate until a favourite emerges.
  - `scorecard-next-model.sh` → advance + print next id · `--peek` (no advance) · `--current` · `--reset`.
  - **Override:** `export POSTFLIGHT_SCORECARD_MODEL=<1..7|name>` pins a model and skips
    rotation entirely (mirrors the `POSTFLIGHT_SPAWN=0` kill-switch idiom).
- **Future (target):** replace round-robin with a **dynamic context-based selector** (factors:
  contexto · propósito · objetivo · tipo[humano|agente] · status · risco · impacto · urgência ·
  segurança · roadmap · timeline). Round-robin is the interim exposure mechanism, not the end state.

Gallery of the 7 models: `skills/postflight/scorecards/gallery.md`.

## Conditions / Invocation

| Condition | Path |
|---|---|
| operator-invoked / on-demand | `/maos:postflight` (full) or a sub-phase `sweep` / `debrief` / `seed` / `spawn` |
| auto-invoked before context loss / `compact` / `clear` / **context>N%** | a **live agent** runs the full skill (incl. P3.5 SPAWN); the deterministic **PreCompact hook** is a snapshot-only safety-net that **never spawns** (a shell hook must not launch a token-burning agentic session — anti-pattern #5/#9) |
| mid-action checkpoint | `/maos:postflight debrief` (recap without the full sweep) |
| spawn opt-out / preview | `/maos:postflight --no-spawn` · `--dry-run` · env `POSTFLIGHT_SPAWN=0` |

## Examples

**Before the operator compacts:**
```
You: "I'm about to /compact — wrap this up."
postflight P1: 1 unpushed commit on feat/x → pushed; PR #42 → driven green; 1 stale ref → pruned.
postflight P2: objectives 2/3 done; 1 gap (tests for edge-case); 1 undecided (naming of Y).
postflight P2: 📊 scorecard model 4/7 (burndown, round-robin) rendered from the debrief state.
postflight P3: 🌱 continuation seed → printed + copied to clipboard. Next agent: /maos:preflight then task #1.
postflight P3.5: 🛫 spawned TICKET-123-add-retry-#a1b2c3d4 (tmux), seed injected. Attach: tmux attach -t '…'.
```

**Spawn opted out (seed-only handoff):**
```
You: "wrap up but don't open a new session — I'll resume tomorrow."
postflight P1+P2+P3: … seed → clipboard.
postflight P3.5: SKIPPED (--no-spawn). Resume later: claude --name '…' --session-id '…' --append-system-prompt "$(cat <seed>)".
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
8. ❌ SPAWN before P1+P2+P3 — a session seeded from an un-swept, un-debriefed state inherits a seed that lies about reality.
9. ❌ Auto-fire SPAWN from the deterministic PreCompact shell hook — spawning a token-burning agentic session belongs to the live skill, never a blind snapshot hook (the hook stays a no-spawn safety-net).
10. ❌ SPAWN without the depth-cap — a default-ON spawn that re-spawns on the child's immediate exit is a runaway token-burn; the `POSTFLIGHT_SPAWN_DEPTH` cap + once-per-source idempotency marker bound it.

## Related Multi-Agent OS Artifacts

- `skills/preflight/SKILL.md` — the **start-of-session** counterpart (orient + heal + isolate); together they bound the session: `preflight → work → postflight`.
- `protocols/exit-hygiene.md` — the Boy-Scout exit-gate checklist P1 operationalizes (policy → this executes it).
- `skills/morning-briefing/SKILL.md` — its 7-section briefing is the P2 state substrate; postflight adds the N-Tree + Eisenhower synthesis that P3 elevates into an agent seed.
- `skills/postflight/references/locus-spec.md` + `bin/locus.sh` — the **locus** grammar SSOT + renderer; P2 DEBRIEF emits the glance-and-know recap (D2/D3/D4) and P3 carries D1 (`locus`) in the seed.
- `bin/scorecard.py` (pure 7-model renderer) + `bin/scorecard-next-model.sh` (round-robin selector) + `skills/postflight/scorecards/gallery.md` — the **end-of-action scorecard** P2 DEBRIEF emits; the selector holds the rotation pointer so the renderer stays pure.
- `skills/sync-to-git/SKILL.md` · `skills/quiesce/SKILL.md` — git close-out + PR convergence P1 composes.
- `skills/session-fission/SKILL.md` — orthogonal: it *splits* a tangled session into N seeds; P3 emits *one* resume seed for continuity, and P3.5 reuses its reseed-a-fresh-session idea for continuity-spawn.
- `bin/spawn-continuation.sh` — the **P3.5 SPAWN** primitive: launches the named, pre-seeded `claude` continuation session (tmux/cmux) with the 7 guardrails; consumes the P3 seed.
- `commands/worktree.md` · `bin/dogfood-mark` — worktree cleanup + dogfood-cycle ledger.
- `commands/postflight.md` → `/maos:postflight` (ergonomic entry point; surfaces `--spawn`/`--no-spawn`/`--dry-run`).
- `plugin-scripts/governance/postflight-precompact.sh` — PreCompact hook (deterministic seed snapshot; never blocks; **never spawns**).

## License

MIT (matches the multi-agent-os repo `LICENSE`).
