---
name: postflight
description: |
  Use at the END of a session/action — especially before the operator compacts or
  clears the conversation — to close the workspace out cleanly and hand the work off.
  Responsibilities: (P1 SWEEP) a boy-scout exit-hygiene sweep that persists/fixes
  loose ends across git, docs, ADRs, changelogs, memories, rules and tickets; (P2 DEBRIEF)
  calculate the session map (objectives N-Tree, gaps, pendings, undecided, next actions
  by Eisenhower); (P2.5 TICKET-SYNC) reconcile the backlog with the session — bounded
  gap->ticket triage + an idempotent continuation ticket — delegated to a capability-detected
  ticketing primitive; (P3 HANDOFF) emit an ai-agnostic continuation seed (carrying the DNA
  Geracional) a fresh amnesic agent can resume from; (P3.5 SPAWN, optional, default-ON) launch
  a fresh, pre-seeded `claude` continuation session so the work continues across the
  compact/clear boundary; (P3.6 BROADCAST, opt-in) inject a bounded, structured, idempotent
  continuation **back-pointer marker** (to the P2.5 ticket + P3 seed) into work artifacts
  (commit trailer · PR body · caller-named docs) so a fresh amnesic agent that lands on the
  artifact discovers the pending work — a structured back-pointer, never a free-form TODO
  (reconciled with exit-hygiene by ADR-010). The end-of-session counterpart to the `preflight` skill. Reads
  whatever governance is present at invocation (CLAUDE/AGENTS/CONTRIBUTING/README/protocols/
  memories) and adapts.
version: 0.8.0
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
  - sync the backlog
  - file the loose ends as tickets
metadata:
  version: "0.8.0"
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
SWEEP (P1) → DEBRIEF (P2) → TICKET-SYNC (P2.5) → HANDOFF (P3) → [SPAWN (P3.5, optional, default-ON)] → [BROADCAST (P3.6, opt-in)]
Each step is SAFE-or-DEFER. Never clobber. Never block. HANDOFF requires SWEEP+DEBRIEF (DoR).
DEBRIEF hunts the COMPLETE 10-item taxonomy (references/close-out-hunt-checklist.md): fails · errors ·
warnings · risks · mitigations · gaps · pendings · decisions-not-taken · unasked-Qs · unanswered-Qs.
TICKET-SYNC needs the P2 atoms + runs BEFORE the seed (so the continuation ticket lands in it);
it is bounded (<=3 tickets + 1 batch) + capability-detected + DEFER-not-block when no tracker.
SPAWN requires the P3 seed (DoR) + passes the spawn guardrails; opt out with --no-spawn.
BROADCAST is OPT-IN (--broadcast[=conservative|all]); it needs the P3 seed + the P2.5 continuation
ticket, points a structured back-pointer marker AT them (never free-form; ADR-010), is idempotent,
--dry-run by default, and NOOP when there is no pendency to point at. Default-ON only in `signoff`.
The environment MUST be left better, safer, and more traceable than it was found.
```

## The Responsibilities (P1–P3.5)

| # | Responsibility | How (safe-or-DEFER) | Composes |
|---|---|---|---|
| **P1** | **SWEEP** — operationalize the exit-hygiene checklist: no loose ends, no banana peels | for each axis {git · docs · ADRs · changelogs · memories · rules · tickets/backlogs · worktrees/branches · stale metrics}: *survey* gaps/opportunities → classify by Eisenhower → **act** (persist/fix/version/commit/push/close) **or register** a tracked follow-up. Read-before-discard is mandatory. | `protocols/exit-hygiene.md`, `skills/sync-to-git`, `skills/quiesce`, `commands/worktree.md`, `bin/reap-sessions.sh`, `bin/dogfood-mark` |
| **P2** | **DEBRIEF** — calculate the session map + run the complete close-out hunt | compose `morning-briefing` (its 7-section state: done · in-flight · blockers · decisions · next-action) then **synthesize on top** the objectives N-Tree (primary/secondary/auxiliary × sequential/parallel/recursive) + the **COMPLETE 10-item close-out HUNT** (`references/close-out-hunt-checklist.md` — fails · errors · warnings · risks+mitigations · gaps · pendings · decisions-not-taken · unasked-Qs · unanswered-Qs; each atom dispositioned fix-now / ticket / seed-field / drop-with-note — no silent drop), next-actions ranked by Eisenhower (non-blocked first). Then **render the glance-and-know locus** — D2 status line + D3 ntree + D4 conv — via `bin/locus.sh` (the compact projection of this debrief; grammar SSOT `references/locus-spec.md`), **and the end-of-action scorecard** — `bin/scorecard.py --model N` where `N` is chosen by `bin/scorecard-select-model.sh` (dynamic context-based decision table; round-robin preserved as `--mode round-robin` fallback; see "The End-of-Action Scorecard" below). | `skills/morning-briefing`, `bin/locus.sh`, `bin/scorecard.py`, `bin/scorecard-select-model.sh` |
| **P2.5** | **TICKET-SYNC** — reconcile the backlog with the session | *(a)* triage each P2 atom (gaps · pendings · undecided · unasked-Qs · out-of-scope) → anti-theater filter → dedup → Eisenhower Q1-Q4 → file under the **cap (≤3 tickets + 1 batch housekeeping ticket)**; *(b)* create/reuse the **idempotent continuation ticket** (search-before-create; body mirrors the seed; provider-relative linkage); *(c)* enrich the anchored ticket. **All ops delegated** to a capability-detected ticketing primitive (no custom state — the tracker is the state). Bounded-autonomous; HITL only for HUMAN_DOMAIN / unknown-provider. **No tracker ⇒ DEFER(ticket), never block.** | `skills/postflight/references/ticket-sync-protocol.md` (SSOT) + a capability-detected ticketing skill (ref: `ticket-as-prompt`) |
| **P3** | **HANDOFF** — emit the continuation seed | a minimal-sufficient, ai-agnostic seed (structured agent-register envelope + human mirror) a fresh amnesic agent can resume from (the seed carries the D1 `locus` field `<status>·<anchor>·<slug>[·#seq]`, the `session_type`, the `dna` block, the `continuation_ticket` from P2.5, and `tickets_created`); print to screen + best-effort clipboard. DoR = P1+P2+P2.5 done. | this skill (the elevation over `morning-briefing` recap) + `skills/session-fission` (seed shape) + `references/continuation-seed-contract.md` v1.2.0 |
| **P3.5** | **SPAWN** *(optional, default-ON)* — launch the next session, pre-seeded | hand the P3 seed to `bin/spawn-continuation.sh`, which launches a fresh **named** detached `claude` session (tmux/cmux) — the name IS the D1 locus (`<status> · <anchor> · <slug> · #<short>`, e.g. `🟡 · VKS-123 · payment-retry · #a1b2c3d4`; pass the ticket via `--ticket` so it anchors, keep the `--slug` to the 2-4-word work essence — locus dedupes anchor-repeated tokens; emoji-first experiment, `POSTFLIGHT_NAME_STYLE=legacy` restores the ascii `<ticket>-<slug>-#<short>`) — with the seed injected as durable system context — so the work *continues itself* across the compact/clear boundary instead of waiting on a manual paste — the spawn also submits a positional **kickoff prompt** (pointing at the persisted seed file) so the new session STARTS WORKING instead of idling at the REPL (opt out: `--no-kickoff` / `POSTFLIGHT_KICKOFF=0`). DoR = P3 seed. Opt out: `--no-spawn`. | `bin/spawn-continuation.sh` (consumes the P3 seed; reuses `session-fission`'s reseed idea) |
| **P3.6** | **BROADCAST** *(opt-in)* — make the tracked continuation discoverable at the point of future contact | ONLY when a pendency remains: inject a **bounded, structured, idempotent back-pointer marker** (to the P2.5 continuation ticket + P3 seed) into work artifacts via `bin/continuation-broadcast.sh` — `--scope conservative` (default) = the exit **commit trailer** (`Continue-Here: <key> · seed:<path>`) + the open **PR body** (idempotent upsert via `gh`); `--scope all` ALSO stamps **caller-named `--file` docs/changelogs** (ADRs REFUSED). The marker is a **structured back-pointer, not a free-form TODO** (reconciled with exit-hygiene by ADR-010): sentinel-delimited + machine-readable + idempotent (upsert, never accumulate) + metadata-only (sanitized) + `--dry-run` default + kill-switch (`MAOS_BROADCAST=0`). DoR = P3 seed and/or the P2.5 ticket. **NOOP when nothing pending.** OFF by default on `postflight` (`--broadcast` to enable); default-ON in `signoff`. | `bin/continuation-broadcast.sh` + `references/continuation-broadcast-protocol.md` (SSOT) + `docs/adrs/ADR-010-continuation-broadcast.md` (consumes the P3 seed + P2.5 ticket — reinvents neither) |

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
     edits in main checkout? → commit-via-worktree / push / open PR or DEFER per workflow.
     Drive open PRs toward green (compose quiesce).
   - stale/orphan worktrees + merged orphan branches → **reap** via `bin/reap-sessions.sh`
     (the executor that closes the detect→act loop; `work-compass`/`worktree-policy` only detect).
     ALWAYS survey dry-run first — `bin/reap-sessions.sh --repo-dir <main-checkout-root> --stale-days <N> --json`
     (pass the repo's **main checkout root**, not a linked worktree; the executor additionally
     resolves the true main worktree defensively even if mis-pointed) — read the `would_reap_*`
     list, then `--apply` ONLY when the SWEEP is clean-to-act
     (not a DEFER state). The reaper is itself safe-or-DEFER (dry-run default · never `--force`/`-D` ·
     never the main worktree · never uncommitted WIP · self-defers on a held `index.lock`),
     so it composes the SWEEP's never-clobber contract — never reaps a peer's live work.
   - docs/ADRs/changelogs: versions reflect this session's changes? cross-refs consistent?
     stale version strings? → fix NOW (P1, never "next session").
   - memories/rules: durable lessons worth persisting? → persist per the repo's memory path.
   - tickets/backlog: any verifiably-DONE ticket (DoD met + PR merged + deliverables) →
     **DELEGATE `close`** to the capability-detected ticketing primitive (it runs the close
     verify-gate + writes the audit comment). The *creation* of loose-end follow-ups is P2.5's
     job (not here) — P1 owns ticket **close**, P2.5 owns ticket **create/enrich**.
   - Classify every surfaced item by Eisenhower; act on Q1/Q2, register Q3, note/drop Q4.
2. P2 DEBRIEF: invoke `morning-briefing` for the 7-section state, then synthesize ON TOP the
   objectives N-Tree + Eisenhower next-actions (non-blocked first) + the **COMPLETE 10-item
   close-out HUNT** (SSOT `references/close-out-hunt-checklist.md`): survey fails · errors ·
   warnings · risks+mitigations · gaps · pendings · decisions-not-taken · unasked-Qs ·
   unanswered-Qs — each atom past the anti-theater filter, dispositioned exactly one of
   fix-now / ticket (P2.5) / seed-field (P3) / drop-with-note (Taxis no-silent-drop). Risks land
   in the seed's `risks[]` (contract v1.2.0); the hunt result also decides whether P3.6 broadcasts.
   (The community `morning-briefing` provides state + next-action; postflight adds the N-Tree +
   Eisenhower ranking + the complete hunt.) **Distil ≤5 session learnings** and append them to the
   DNA learnings log (governance-discovered path; they become the seed's `dna.session_learnings`).
   This is the session map — then render it as the
   glance-and-know locus (D2+D3+D4) via `bin/locus.sh`, AND render the end-of-action
   scorecard: distil the session's factors and select the model dynamically —
   `N=$(bin/scorecard-select-model.sh --audience <human|agent> --purpose <end-of-action|briefing|handoff> \
        --items <checklist-size> --open <open-count> --risk <low|med|high> --urgency <low|med|high>)`
   (honours `POSTFLIGHT_SCORECARD_MODEL` pin; `--mode round-robin` keeps the legacy
   rotation) — then build the params JSON from the P1/P2 state (verdict · autonomy
   pulse · vitals · checklist · whats_left · tickets) and
   `printf '%s' "$params" | bin/scorecard.py --model "$N" --auto-git --repo <repo>`.
   The renderer is PURE (no side-effects); selection policy lives in the selector.
2.5 P2.5 TICKET-SYNC (between DEBRIEF and HANDOFF — SSOT: references/ticket-sync-protocol.md):
   (a) triage the P2 atoms (gaps · pendings · undecided · unasked-Qs · out-of-scope) →
   anti-theater filter → dedup (delegate `auto` op) → Eisenhower → file under the cap
   (≤3 individual + 1 batch housekeeping ticket); (b) create/reuse the **idempotent
   continuation ticket** (delegate `auto`: search-before-create; body mirrors the seed;
   provider-relative "relates-to"/child-of linkage); (c) enrich the anchored ticket
   (delegate `enrich`). Route by repo CLASS (corporate→Jira · personal→Linear ·
   community→GH) via governance discovery — never a hardcoded org. No ticketing capability
   ⇒ DEFER(ticket) (record in `tickets_created`), then continue. Record the continuation key
   for P3.5.
3. P3 HANDOFF: synthesize the continuation seed (below) from P1+P2+P2.5 → print + clipboard.
   Populate (per contract v1.1.0): `refs.ticket` = **the P2.5 continuation ticket key** (so the
   spawned session's preflight R0 hook — which anchors off `refs.ticket` — wakes anchored on
   the *right* node; falls back to the current anchor only when no continuation ticket) ·
   `session_type` (`<mode>/<work>`) · `dna` (the 3 principles + ≤5 `session_learnings` +
   `canonical_ref`/`learnings_ref`) · `continuation_ticket` (the full P2.5 object
   `{key,url,parent,link}`) · `tickets_created` (the P2.5 audit trail).
3.5 P3.5 SPAWN (default-ON; skip on --no-spawn / kill-switch / depth-cap / already-spawned):
   write the P3 seed to a file, then `bin/spawn-continuation.sh --ticket <CONT-KEY> --slug
   <kebab> --status <glyph> --seed <seedfile>` → launches the pre-seeded continuation session
   named/anchored by the **P2.5 continuation ticket** (or registers + prints the resume
   command if no launcher / no ticket). Surfaces the session name + attach hint.
   SLUG QUALITY (the name is read at a glance): 2-4 kebab words, the ESSENCE of the next
   work (payment-retry · judge-round-a3). Never embed the ticket id / repo name / status —
   pass the ticket via --ticket (it becomes the anchor); locus drops anchor-duplicated
   tokens anyway (spec: references/locus-spec.md "slug quality + normalization").
3.6 P3.6 BROADCAST (OPT-IN — `--broadcast[=conservative|all]`; skip when off / no pendency /
   kill-switch — SSOT: references/continuation-broadcast-protocol.md + ADR-010):
   ONLY if the P2 hunt found a genuine pendency (gap/pending/undecided/risk the next agent must
   pick up) AND a P3 seed and/or a P2.5 continuation ticket exists → make it *discoverable at the
   point of future contact*. Run `bin/continuation-broadcast.sh --ticket <CONT-KEY> --seed
   <seedfile> --scope <conservative|all> [--pr <N>] [--file <path> ...] --apply` (default `--dry-run`):
   it prints the `Continue-Here: <key> · seed:<path>` **commit trailer** (append it to the closing
   commit), idempotently upserts the marker block into the **PR body** (`--pr`, needs `gh`), and —
   under `--scope all` — into **caller-named docs** (`--file`; ADRs refused). Structured back-pointer,
   never a free-form TODO; idempotent; metadata-only (sanitized); NOOP when nothing pending. OFF by
   default on postflight; default-ON in `signoff`.
4. Emit a concise exit summary (swept items, tickets closed/created/continuation, deferred
   items, seed location, spawned session, broadcast markers).
```

## The Continuation Seed (the P3 deliverable)

A **minimal-sufficient, ai-agnostic** resume packet for a *fresh, amnesic* agent (per the
amnesia premise: a gifted agent with no cross-session recall). Two registers, same content:

- **Agent register** (default — economical, machine-parseable; emit as a JSON-RPC-style
  envelope, `--lang` selectable).

  **SSOT (contract v1.2.0)**: the full seed shape lives in
  [`templates/continuation-seed.template.json`](templates/continuation-seed.template.json)
  and its field-by-field contract in
  [`references/continuation-seed-contract.md`](references/continuation-seed-contract.md)
  (REQUIRED resume-spine: `who_you_are` · `bootstrap_order` · `inherited_state` · `mission`
  · `guardrails` · `dod` · `dag` · `refs` · `resume_instructions`; plus the optional debrief
  fields and the v1.1.0 additions `session_type` · `dna` (object) · `continuation_ticket` ·
  `tickets_created` + the v1.2.0 addition `risks` (the hunt's forward-looking half)). Populate
  the template — do NOT re-derive the shape inline. Short excerpt:

```json
{"jsonrpc":"2.0","method":"session.continuation","params":{
  "who_you_are":"<role the resuming agent assumes>",
  "bootstrap_order":["<ordered read #1>","<ordered read #2>"],
  "inherited_state":{"verified_facts":["..."],"branches":["<b>@<sha>"],"env":["..."]},
  "mission":["<one-line mission>","<step 2>"],
  "guardrails":["..."], "dod":["..."], "dag":["<what comes after>"],
  "refs":{"git":"<repo+branch+PRs>","ticket":"<key|none>","memory":"<path|none>","session":"<id>"},
  "goal":"<one-line mission>",
  "session_type":"<mode>/<work>",
  "dna":{"principles":["...","...","..."],"canonical_ref":"...","session_learnings":["..."],"learnings_ref":"<path|none>"},
  "continuation_ticket":{"key":"<key|none>","url":"...","parent":"...","link":"relates-to|child-of"},
  "tickets_created":[{"key":"<key>","eisenhower":"Q1|Q2|Q3|Q4","link":"..."},{"deferred":true,"eisenhower":"Q1|Q2|Q3|Q4","link":"none","reason":"..."}],
  "risks":[{"risk":"<forward-looking hazard for the next agent>","mitigation":"<how to mitigate>","severity":"low|med|high"}],
  "next_actions":[{"task":"...","eisenhower":"Q1|Q2|Q3|Q4","blocked_by":null}],
  "resume_instructions":"Run /maos:preflight first; then follow bootstrap_order; then the first non-blocked next_action. INTERNALIZE params.dna + transcribe the 3 principles to every sub-agent you spawn."
},"data":{"layer":"community","contract":"skills/postflight/references/continuation-seed-contract.md","contract_version":"1.2.0"}}
```

- **Human mirror**: the same, rendered as a short scannable briefing for the operator.

Output: **print to screen + best-effort clipboard** (auto-detect `pbcopy`/`wl-copy`/`xclip`/
`xsel`/`clip.exe`), sanitized (never copy secrets/file-bodies — metadata only). The seed is
designed so the next agent runs `/maos:preflight` (orient) then resumes from the first
non-blocked next-action — and, when **P3.5 SPAWN** fires, that next agent is *launched
already holding the seed*, closing the loop `preflight → work → postflight → (spawn) → preflight …`.

## The End-of-Action Scorecard (a P2 DEBRIEF output)

`bin/scorecard.py` renders a glanceable end-of-action **scorecard** (verdict · autonomy
pulse · vitals bars · checklist · what's-left · tickets) in one of **8 layout models**
(Model 8 "Briefing Card" = the morning-briefing V2 layout imported as an official template,
issue #132). It is a **PURE renderer** by contract — same params → same output, no
side-effects — so it consumes a params JSON (built by the agent from the P1 SWEEP + P2
DEBRIEF state) and self-derives only git/PR facts (`--auto-git`).

**Model selection — dynamic (default) · round-robin (fallback) · pin (override):**

- **Dynamic (now the default):** `bin/scorecard-select-model.sh` maps session factors →
  model via a deterministic first-match decision table (operator green-light 2026-06-11,
  issue #132: *"mantidos como templates oficiais … usados por decisões seletivas, dinâmicas,
  automáticas, autônomas e híbridas"*). The **hybrid split**: the invoking agent
  (probabilistic) distils [contexto · escopo · propósito · objetivo · risco · segurança ·
  impacto · urgência · importância · criticidade · human/agent] into the flags
  `--audience · --purpose · --items · --open · --risk · --urgency`; the script
  (deterministic) maps flags → model (agent→M6 · briefing→M8 · handoff→M6 · high-stakes→M1 ·
  trivial→M7 · open-heavy→M5 · backlog-heavy→M4 · default→M2). `--explain` names the
  matched rule on stderr.
- **Round-robin (preserved fallback):** `--mode round-robin` delegates to
  `bin/scorecard-next-model.sh` (the 1→8 rotation engine + user-scope pointer
  `~/.claude/jobs/.postflight-scorecard-model`) — the interim exposure mechanism per
  operator decision 2026-06-10, kept selectable per boy-scout/continuity.
  - `scorecard-next-model.sh` → advance + print next id · `--peek` (no advance) · `--current` · `--reset`.
- **Pin (highest precedence, the non-deterministic opt-in):** `export
  POSTFLIGHT_SCORECARD_MODEL=<1..8|name>` pins a model in ANY mode — the agent's contextual
  judgment may overrule the table (log the reason); mirrors the `POSTFLIGHT_SPAWN=0` idiom.

Gallery of the 8 models: `skills/postflight/scorecards/gallery.md`.

## Conditions / Invocation

| Condition | Path |
|---|---|
| operator-invoked / on-demand | `/maos:postflight` (full) or a sub-phase `sweep` / `debrief` / `seed` / `spawn` / `broadcast` |
| broadcast the continuation marker (opt-in) | `/maos:postflight --broadcast[=conservative\|all]` (OFF by default here; **default-ON** in `/maos:signoff`); kill-switch `MAOS_BROADCAST=0` |
| auto-invoked before context loss / `compact` / `clear` / **context>N%** | a **live agent** runs the full skill (incl. P3.5 SPAWN); the deterministic **PreCompact hook** is a snapshot-only safety-net that **never spawns** (a shell hook must not launch a token-burning agentic session — anti-pattern #5/#9) |
| mid-action checkpoint | `/maos:postflight debrief` (recap without the full sweep) |
| spawn opt-out / preview | `/maos:postflight --no-spawn` · `--dry-run` · env `POSTFLIGHT_SPAWN=0` |

## Examples

**Before the operator compacts:**
```
You: "I'm about to /compact — wrap this up."
postflight P1: 1 unpushed commit on feat/x → pushed; PR #42 → driven green; 1 stale ref → pruned.
postflight P2: objectives 2/3 done; 1 gap (tests for edge-case); 1 undecided (naming of Y).
postflight P2: 📊 scorecard model 4/8 (burndown — rule R7 backlog-heavy, dynamic) rendered from the debrief state.
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
11. ❌ File **> 3 individual tickets** in one P2.5 cycle — past the cap, roll the rest into the **single batch housekeeping ticket**; a ticket per micro-observation is backlog spam.
12. ❌ **Ticket-for-theater** — filing a ticket for a non-actionable/vanity/already-done atom. A ticket must change someone's next action (it must pass the anti-theater filter).
13. ❌ Call a **tracker API from the deterministic PreCompact hook** — P2.5 ticket I/O belongs to the live skill; the hook is a zero-network snapshot and must never hit a tracker.
14. ❌ Create a **duplicate continuation ticket** — always `auto` (search-before-create); the 2nd run reuses + enriches the existing one, never re-creates.
15. ❌ **Partial hunt** — surveying only the 5 easy P2 atoms and leaving fails/errors/warnings/risks/mitigations implicit; run the COMPLETE 10-item hunt (`references/close-out-hunt-checklist.md`), disposition every atom (no silent drop).
16. ❌ **Free-form BROADCAST** — injecting a "TODO next session" marker instead of the structured back-pointer block (defeats the exit-hygiene reconciliation, ADR-010; the executor only emits the structured, idempotent form).
17. ❌ **BROADCAST into an ADR** or mid-content of a doc — ADRs are refused; the executor upserts the sentinel region only, into caller-named files under `--scope all`.
18. ❌ **BROADCAST with no pendency** — a marker on a fully-closed session is noise (NOOP when nothing pending); and never a **non-idempotent** placement (the sentinel upsert prevents accumulation — entropy is exponential).

## Related Multi-Agent OS Artifacts

- `skills/preflight/SKILL.md` — the **start-of-session** counterpart (orient + heal + isolate); together they bound the session: `preflight → work → postflight`.
- `protocols/exit-hygiene.md` — the Boy-Scout exit-gate checklist P1 operationalizes (policy → this executes it); P1 owns ticket **close**, P2.5 owns ticket **create/enrich**.
- `skills/postflight/references/ticket-sync-protocol.md` — the **P2.5 TICKET-SYNC** SSOT (gap→ticket triage caps · idempotent continuation ticket · capability ladder · audit trail); P2.5 delegates all ops to a capability-detected ticketing skill (ref: the user-scope `ticket-as-prompt`) — DRY, never re-implements provider/schema logic.
- `skills/morning-briefing/SKILL.md` — its 7-section briefing is the P2 state substrate; postflight adds the N-Tree + Eisenhower synthesis that P3 elevates into an agent seed.
- `skills/postflight/references/locus-spec.md` + `bin/locus.sh` — the **locus** grammar SSOT + renderer; P2 DEBRIEF emits the glance-and-know recap (D2/D3/D4) and P3 carries D1 (`locus`) in the seed.
- `bin/scorecard.py` (pure 8-model renderer; M8 "Briefing Card" = morning-briefing V2 import) + `bin/scorecard-select-model.sh` (dynamic context-based selector — issue #132) + `bin/scorecard-next-model.sh` (round-robin engine, preserved as `--mode round-robin` fallback) + `skills/postflight/scorecards/gallery.md` — the **end-of-action scorecard** P2 DEBRIEF emits; selection policy + rotation state live outside the renderer so it stays pure.
- `skills/sync-to-git/SKILL.md` · `skills/quiesce/SKILL.md` — git close-out + PR convergence P1 composes.
- `skills/session-fission/SKILL.md` — orthogonal: it *splits* a tangled session into N seeds; P3 emits *one* resume seed for continuity, and P3.5 reuses its reseed-a-fresh-session idea for continuity-spawn.
- `bin/spawn-continuation.sh` — the **P3.5 SPAWN** primitive: launches the named, pre-seeded `claude` continuation session (tmux/cmux) with the 7 guardrails; consumes the P3 seed.
- `bin/continuation-broadcast.sh` + `skills/postflight/references/continuation-broadcast-protocol.md` (SSOT) + `docs/adrs/ADR-010-continuation-broadcast.md` — the **P3.6 BROADCAST** executor + spec + reconciliation: a bounded, structured, idempotent back-pointer marker (commit trailer · PR body · caller-named docs) that makes the tracked continuation discoverable at the point of future contact (opt-in; structured back-pointer, never a free-form TODO). `bin/tests/continuation-broadcast.test.sh` is its safety-contract suite.
- `skills/postflight/references/close-out-hunt-checklist.md` — the **P2 DEBRIEF** complete 10-item HUNT SSOT (fails · errors · warnings · risks+mitigations · gaps · pendings · decisions-not-taken · unasked-Qs · unanswered-Qs) + the fix-now/ticket/seed/drop disposition rubric.
- `commands/signoff.md` + `skills/signoff/SKILL.md` — the operator-facing **sign-off / encerramento** verb (`/maos:signoff`) that composes `[quiesce →] postflight full --broadcast --spawn` under an OODA framing; the one place BROADCAST is default-ON.
- `commands/worktree.md` (surfaces `reap`) · `bin/reap-sessions.sh` (the safe executor P1 SWEEP delegates stale/orphan worktree+branch pruning to — dry-run default, never-clobber) · `bin/dogfood-mark` — worktree cleanup + dogfood-cycle ledger.
- `commands/postflight.md` → `/maos:postflight` (ergonomic entry point; surfaces `--spawn`/`--no-spawn`/`--dry-run`).
- `plugin-scripts/governance/postflight-precompact.sh` — PreCompact hook (deterministic seed snapshot; never blocks; **never spawns**).

## License

MIT (matches the multi-agent-os repo `LICENSE`).
