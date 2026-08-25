---
name: preflight
description: |
  Use at the start of a session or before starting an action/task in any git repo to
  get the workspace into a correct, healthy, isolated, ticket-anchored state BEFORE
  touching code: (R0) anchor the session to its ticket on the N-Tree + classify the
  session type, (R1) detect the right branch without interfering with other
  agents/sessions/worktrees, (R2) safely heal the current branch from origin, and
  (R3) create a git worktree the moment you are about to create/update files. Reads
  whatever governance is present at invocation (CLAUDE/AGENTS/CONTRIBUTING/README/
  protocols/memories) and adapts.
version: 1.2.0
triggers:
  - preflight
  - run preflight
  - bootstrap my workspace
  - which branch should I be on
  - sync my branch from origin
  - heal my branch
  - start of session checks
  - prepare a worktree before editing
  - which ticket does this session belong to
  - classify this session
  - walk the ticket N-Tree
  - preflight ticket
metadata:
  version: "1.2.0"
  scope: AAIF cross-vendor
  family: worktree-lifecycle
  lifecycle-stage: operate
  cross_link_slug: preflight
  dogfood_status: in-progress
  pairs-with: postflight   # reciprocal of postflight's `pairs-with: preflight`
  # id/type/status/owner/dogfooding_validation deliberately OMITTED (issue #390): that block
  # predates and is non-conformant with ADR-005 (docs/adrs/ADR-005-dogfood-cycle-ledger.md),
  # which supersedes per-skill dogfood tracking with a canonical ledger; it is also unconsumed
  # by any repo tooling and inconsistent in shape even among its 4 adopters. See PR for evidence.
allowed-tools: Read, Glob, Grep, Bash
---

# Preflight Skill

## Purpose

A **preflight check** for agentic work, like an aviation preflight or an HTTP CORS
preflight: a small set of *readiness* steps run **before** the real action, each with a
go/no-go (proceed-or-DEFER) decision. It readies the git workspace so an agent never
works on the wrong branch, on stale state, or unisolated in a shared checkout.

## When to Use

- At the **start of a session** (the bundled SessionStart hook runs the deterministic ticket-**anchor**
  + coarse `mode` hint automatically; the full R0 N-Tree walk / classification / create-proposal stays
  **on-demand** via `/maos:preflight ticket`. R1 heal + R2 branch-detect also run in the hook).
- At the **start of an action/task**, before you begin substantive work.
- **Before creating or updating any file/directory** (R3 — lazily isolate the mutation).
- When you are unsure which branch you should be on, or whether your branch is stale.
- When you need to know **which ticket** the session belongs to, **where** it sits on the
  ticket N-Tree, or **what kind** of session this is (R0 — on-demand via `/maos:preflight ticket`).

## Trigger Phrases

"preflight" · "bootstrap my workspace" · "which branch should I be on" · "heal/sync my
branch from origin" · "prepare a worktree before editing" · "which ticket does this session
belong to" · "classify this session" · "walk the ticket N-Tree"

## Core Rule

```
ANCHOR (R0) → ORIENT (R1) → HEAL (R2) → ISOLATE-ON-MUTATION (R3)
Each step is SAFE-or-DEFER. Never clobber concurrent work. Never block on a no-op.
R0 is ZERO-network at the hook layer; the agentic N-Tree walk + create-proposal are HITL-gated.
```

## The Responsibilities (R0–R3, + optional R1.5)

| # | Responsibility | How (read-only / safe) | Lib |
|---|---|---|---|
| **R0** | **Anchor** the session to its ticket on the N-Tree + **classify** the session type | (a) deterministic hook anchors the ticket (seed `refs.ticket` › branch › last-commit via `locus --density anchor`, ZERO network) → coarse `mode`; (b) skill walks the N-Tree (parent-chain to epic/root + siblings) via capability-detected MCP; (c) classifies `session_type=<mode>/<work>`; (d) if no ticket → HITL create-proposal (delegates to `ticket-as-prompt`) | `bin/locus.sh` + `references/session-type-taxonomy.md` |
| **R1** | Detect the right branch **without interfering** with other agents/sessions/worktrees | branch + upstream + ahead/behind + branches **locked by other worktrees** (`git worktree list --porcelain`) + tree-state | `lib/git-branch-detect.sh` |
| **R1.5** | **Peer-aware** non-interference (optional, capability-detected) | detect OTHER live sessions writing the **SAME checkout** (host session-activity signal, self-excluded, freshness-windowed); peers active → R2 **DEFERs**; off-host → `UNKNOWN` (report-only) | `lib/peer-session-detect.sh` |
| **R2** | **Heal** the current branch from origin | `fetch` → classify {up-to-date / ff-ready / diverged / dirty / detached / mid-op / busy / **peers-active**} → act: `ff-only` \| `rebase --autostash` \| **DEFER** | `lib/git-safe-sync.sh` |
| **R3** | **Isolate** file mutations in a worktree | only when about to create/update files; compose `/maos:worktree create` (or `git worktree add .worktrees/<slug> -b <type>/<scope>`) | `commands/worktree.md` |

**Non-interference (R1) is structural**: a branch checked out in another worktree is
git-locked — preflight reports it and never switches to it. **Healing (R2) never
clobbers**: a dirty tree, detached/mid-rebase/mid-merge HEAD, a diverged-with-conflict,
or a held `.git/index.lock` all → **DEFER** (report, do not act). **Isolation (R3) is
lazy**: a worktree is created when mutation is imminent, not preemptively.

**Cross-session layer (R1.5, v1.1.0)** — R1's worktree-locks cover peers in a *different*
checkout (git-locked branch); R1.5 closes the complementary gap: **two sessions in the SAME
checkout on the SAME branch** — which `.git/index.lock` only catches at the instant of a write.
It is **optional + capability-detected + graceful**: when a peer is actively writing this
checkout, R2 DEFERs (`heal=DEFERRED peers-active(<n>)`); when no session signal resolves
(off-host / dir unresolved), it reports `peers=unknown` and never over-defers (git-native
protections remain). **Never blocks.** Env seams: `MAOS_PEER_SESSION_DIR` (explicit session-dir
override / portability seam), `MAOS_PEER_FRESH_SECS` (live window, default 90),
`MAOS_SELF_SESSION_ID` (exclude self). Honest limit: a peer that started in a *subdir* (cwd ≠
toplevel) may be missed — a miss means fewer defers, never a false block; use the override seam
for precision.

## R0 — Ticket Anchor + Session Classification (the treasure-map step)

Tickets/backlogs are the project's map — *where on it am I?* R0 answers that, in two layers:
a deterministic hook (always, zero-network) + an agentic skill walk (on-demand / `/maos:preflight ticket`).

### R0.a — Anchor (deterministic, ZERO network — the hook does this automatically)

The SessionStart hook resolves the ticket from the strongest local signal, in precedence:

1. **seed `refs.ticket`** — a continuation handoff explicitly named the ticket (→ `mode=continuation-candidate`).
2. **branch** — `[A-Z]{2,}-[0-9]+` in the branch name (via `locus --density anchor`).
3. **last commit** — the same pattern in the last commit subject.

It emits `ticket=KEY (source=seed|branch|commit, mode=…)` into the SessionStart additionalContext +
stderr. **Zero network** (no `gh`, no `curl`), **<2s**, **always exit 0**. Opt-out: `PREFLIGHT_NO_TICKET_ANCHOR=1`.
No anchor → a nudge to run the agentic walk (R0.b) or proceed (a ticket may be proposed at postflight).

### R0.b — N-Tree walk (agentic, capability-detected — on `/maos:preflight ticket`)

Confirm the anchor, then walk the ticket **N-Tree** to situate the session:

- **Up** to the parent chain (story → epic → root) and **sideways** to siblings, via whatever
  tracker MCP is present (capability-detected — never hardcode a provider). Jira: parent-chain +
  `JQL` siblings; Linear/GH: equivalents. **No tracker MCP available → DEFER(ntree)** (report the
  anchor only; never block).
- **Flag the session's node** on the tree so the operator sees exactly where this work lives.
- Layer-pure: the *mechanism* is governance-discovered; this skill composes the user-scope
  `ticket-as-prompt` skill for any provider-specific read/enrich.

### R0.c — Classify `session_type=<mode>/<work>`

Resolve the session type per `references/session-type-taxonomy.md` (the SSOT): two orthogonal
axes — `mode` {continuation·fresh·debate·converge} × `work` {feat·enhance·fix·hotfix·debug·gap·
refactor·harmonize·chore·docs·test}. Tier-A computed signals (seed/branch/issue-type/`#seq`) beat
Tier-B self-report (prompt verbs). Ambiguous → emit the **top-2 with evidence**, never fabricate one.
The result is carried into the continuation seed (`session_type`) at postflight → read back by the
next session's R0.

### R0.d — No-ticket flow (HITL-gated — never auto-creates)

When R0.a finds no anchor AND R0.b confirms none exists on the tree, present a **structured HITL
proposal** (via `AskUserQuestion`), do NOT auto-create:

1. **Create as draft** — delegate to `ticket-as-prompt`, which capability-detects the tracker and
   routes by class (examples, non-normative: corporate / personal / community trackers), to open a
   ticket whose body is a self-contained Ticket-as-Prompt.
2. **Link to an existing ticket** — operator names the node; the session anchors to it.
3. **Proceed without a documented ticket** — record the decision; postflight P2.5 may still propose one.

Ticket *creation* is always delegated to `ticket-as-prompt` + capability-detected; absent that skill →
DEFER(ticket) (report, never block).

## Governance Discovery (read at invocation — the adaptive core)

Before deriving any name or convention, **read whatever governance the target repo
exposes right now** and adapt to it (do NOT hardcode):

1. `Read`/`Glob` for `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `README.md`,
   `protocols/*`, `docs/*worktree*`, `skills/worktree-policy/SKILL.md`,
   `.worktrees/README.md`, and any `memory`/`MEMORY.md` present.
2. Extract: branch-naming convention (e.g. `<type>/<scope>-<id>`), worktree dir
   convention (e.g. `.worktrees/<slug>`), the valid worktree **exceptions**, the
   protected-branch set, and the PR/merge workflow.
3. Apply *those* conventions when deriving the branch + worktree in R3. If none are
   found, fall back to the C04 defaults below.

## Algorithm

```
0. Governance discovery (above) — derive the repo's conventions.
0.5 R0: anchor the ticket (seed › branch › commit, ZERO network) → coarse mode.
   On /maos:preflight ticket: walk the N-Tree (parent-chain + siblings, capability-detected),
   flag the session node, classify session_type=<mode>/<work> (taxonomy SSOT), and if no
   ticket exists → HITL create-proposal (delegate to ticket-as-prompt). DEFER if no tracker MCP.
1. R1: read-only detect — current branch, upstream, ahead/behind, tree-state,
   branches locked by other worktrees. Report; never mutate.
2. R2: if the action benefits from fresh state → safe-heal from origin
   (fetch → classify → ff-only | rebase-autostash | DEFER). Report the verdict.
3. R3: IF (and only if) the action will create/update files/directories AND you are
   in the main checkout (not already a worktree) AND it is not a C04 exception:
     - derive slug + branch from the action intent + discovered conventions
     - git worktree add .worktrees/<slug> -b <type>/<scope>[-<id>] <base-ref>
     - register in .worktrees/sessions.json (append-only)
     - cd into the worktree; proceed there.
4. Emit a concise bootstrap summary (branch, heal verdict, worktree path).
```

## Valid Exceptions (C04 — R3 is a no-op for these)

1. **READ-ONLY**: analysis without file modification.
2. **APPEND-ONLY**: `tasks.md`, `sessions.json` (add lines only).
3. **Already isolated**: you are already inside a `.worktrees/` worktree.
4. **USER EXPLICIT REQUEST**: operator directs a main-checkout edit (documented).

## Components (the bundle this skill anchors)

| Artifact | Role |
|---|---|
| `skills/preflight/SKILL.md` | this brain (governance-aware orchestrator) |
| `skills/preflight/references/session-type-taxonomy.md` | R0.c classification SSOT (mode × work axes) |
| `bin/locus.sh` `--density anchor` | R0.a ticket-anchor authority (seed › branch › commit, ZERO network) |
| `commands/preflight.md` → `/maos:preflight` | ergonomic entry point (+ `ticket` action for R0 on-demand) |
| `plugin-scripts/governance/preflight-session.sh` | SessionStart hook (R0+R1+R2, never blocks; opt-out `PREFLIGHT_NO_AUTOHEAL=1`, `PREFLIGHT_NO_TICKET_ANCHOR=1`) |
| `plugin-scripts/governance/preflight-edit-gate.sh` | PreToolUse:Edit\|Write\|MultiEdit (R3 safety-net; WARN default, `PREFLIGHT_EDIT_GATE=block\|off`) |
| `plugin-scripts/governance/lib/git-branch-detect.sh` | R1 read-only primitives |
| `plugin-scripts/governance/lib/git-safe-sync.sh` | R2 safe-heal primitives |
| `plugin-scripts/governance/lib/peer-session-detect.sh` | R1.5 optional cross-session peer detector (capability-detected; `UNKNOWN` off-host) |

## Examples

**Start of session** (automatic, via the hook — R0 anchor + R1/R2):
```
🧭 preflight: ticket=ABC-123(branch) mode=anchored; branch=feat/abc-123-x upstream=origin/main ahead=0 behind=3 tree=CLEAN; heal=HEALED_FF a1b2c3d
```

**No ticket anchor** (the hook nudges; never blocks):
```
🧭 preflight: branch=just-a-name ... ; heal=...
→ No ticket anchor detected (mode=unanchored): run /maos:preflight ticket to walk the N-Tree + classify, or proceed.
```

**On `/maos:preflight ticket`** (agentic N-Tree walk + classify):
```
R0: anchor=ABC-123 (branch) → N-Tree: ROOT epic ABC-100 › story ABC-110 › ◀THIS ABC-123 (+2 siblings)
    session_type=continuation/feat (seed→continuation; branch feat/→feat)
```

**Before editing on main**:
```
You: "update the README"
preflight (R3): main checkout detected → git worktree add .worktrees/readme -b docs/readme
              → cd .worktrees/readme → now safe to edit.
```

**Dirty tree (DEFER — never clobber)**:
```
🧭 preflight: branch=main tree=DIRTY; heal=DEFERRED dirty(uncommitted-tracked-changes)
→ commit or stash your work, then re-run /maos:preflight.
```

## Related Multi-Agent OS Artifacts

- `skills/worktree-policy/SKILL.md` — the worktree *policy* (this skill *operationalizes* it at session/action start).
- `commands/worktree.md` — the lower-level `/maos:worktree create` primitive R3 composes.
- `plugin-scripts/governance/worktree-gate.sh` — PreToolUse:Bash gate (works *with* this; preflight-edit-gate covers Edit/Write).
- `plugin-scripts/governance/lib/worktree-utils.sh` — worktree detection (reused by R1/R3).
- `skills/anti-conflict/SKILL.md` — lock-file coordination for parallel agents.
- `skills/sync-to-git/SKILL.md` — orthogonal: that *pushes* to origin; preflight R2 *pulls/heals from* origin.
- `docs/git-worktree-protocol.md` — C04 (authoritative spec).

## License

MIT (matches the multi-agent-os repo `LICENSE`).
