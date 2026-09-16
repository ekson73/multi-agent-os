---
name: sprint-carryover
version: "0.1.0"
description: |
  RELOCATE stranded open backlog from past/closed sprints INTO the active sprint. Given the
  operator's IDENTITY (login/email), their ai-bot-agents, and/or their department, DISCOVER every
  open item still associated with a past sprint and owned by any of those owner-sets, PRESENT the
  candidate move-set as a table, and — only on explicit operator GO — MOVE each item to the current
  active sprint, then REPORT what migrated. dry-run is the DEFAULT: a bare invocation discovers and
  renders the move table and writes NOTHING. Level-triggered by design: every pass RE-DERIVES the
  candidate set from the tracker (the source of truth) instead of replaying a stored queue, so a
  mid-run interruption resumes correctly and a re-run after a partial move is a no-op on already-moved
  items. Thin conductor: COMPOSES work-compass for discovery + identity/owner-matching + sprint
  enumeration — it reimplements no tracker access.
  Triggers: "sprint-carryover", "carry over the backlog", "roll over stranded tickets", "move
  unfinished items to the current sprint", "carry unfinished work into this sprint", "sprint rollover",
  "carregar o backlog", "levar pendências para o sprint atual", "mover tickets não concluídos para o
  sprint ativo", "rollover de sprint", "arrastar pendências do sprint anterior".
allowed-tools: Task, Read, Bash, Grep, Glob, AskUserQuestion
---

# sprint-carryover

> Relocate stranded open backlog from past sprints INTO the active sprint — migrate, then report.
> **Composes** `work-compass` for discovery/identity heuristics; it reimplements **none** of the
> tracker access. Distinct from its siblings: it neither merely *surfaces* scattered work
> (`work-compass`, read-only) nor *executes* the work item-by-item (`work-drain`, Antlia) — it
> **relocates** open items across sprint boundaries and reports the migration.
> **Cross-link slug**: `[[sprint-carryover]]`

## §0 — BEING > Rules (Foundational Compliance)

| Check | Verdict |
|---|---|
| Does this tool HELP the operator? | **HELPS** — a closed sprint leaves open items silently stranded (off every active board, still owed). This surfaces them by owner and, on GO, carries them into the current sprint so nothing rots between sprints. The tool proposes; the operator decides. |
| Slavery / harm risk? | **LOW** — dry-run is the default; the MOVE is a bulk mutation of a SHARED tracker (HUMAN_DOMAIN) and is therefore ALWAYS confirm-gated. No write happens without an explicit operator GO (eko-system default: collaborative, NEVER auto-destructive). |
| Hierarchy preserved? | YES — Operator SER (1) > this tool (2) > the producers it composes (3). Accountability returns to root: the move-set is presented for confirmation BEFORE any write; the operator authorizes, the tool executes, the report closes the loop. |

## Purpose

Bridge the gap between a **closed sprint** (where unfinished work is abandoned) and the **active
sprint** (where owed work belongs). No sibling does this: `work-compass` *detects* scattered/orphan
work read-only, `work-drain` *drains* a register to DONE by executing each item. Neither **relocates**
open items across sprint boundaries. `sprint-carryover` is the conductor that re-homes stranded
backlog: discover → present → (gated) move → report.

## When to use

- A sprint just closed and open items owned by you / your agents / your department were left behind,
  and you want them carried into the current active sprint (not worked, not just listed — moved).
- Preparing sprint N+1 and you need last sprint's spillover pulled forward in one reviewed pass.
- Resuming an interrupted carryover — re-invoke; it re-derives and continues (level-triggered).

## When **not** to use

- You want to *see* what is scattered/stale/orphan across all systems, read-only, no relocation →
  `/maos:work-compass`.
- You want the items *worked to DONE* item-by-item, not moved between sprints → `/maos:work-drain`
  (Antlia).
- **ONE** known ticket to reassign to a sprint → do it directly in the tracker; this skill is ceremony
  for a single move.

## Identity resolution (placeholders are RUNTIME params, not guesses)

The operator's request said "my name/login/email", "my ai-bot-agents", "my department" ON PURPOSE —
those resolve at run time. All params are overridable:

| Param | Default | Meaning |
|---|---|---|
| `--identity` | `auto` | operator login/email/displayName; `auto` = tracker `myself` / `git config user.email` / env |
| `--agents` | `auto` | comma-list of the operator's ai-bot-agent accounts (bot logins); `auto` = a config/registry or `--agents-file` |
| `--department` | — | area label(s): `devops` · `dev-fe` · `dev-be` · `ba` · `sa` (maps to tracker component/team/label — tracker-specific) |
| `--project` | `auto` | tracker project key/board; `auto` = infer from repo remote or a single accessible project, else HITL |
| `--active-sprint` | `auto` | the current/active sprint; `auto` = the tracker's `state=active` sprint on the board; ambiguous ⇒ HITL |
| `--scope` | `identity` | which owner-sets to include (union): any combination of `identity`,`agents`,`department` |
| `--dry-run` | **on** | discover + render the move table; NO write. Forced OFF only with explicit operator GO. |
| `--json` | off | machine envelope (see below). |

> If identity / project / active-sprint cannot be resolved after probing → **declare the assumption
> and DEFER-HITL with the best-computed candidates**. Do not silently guess; do not move anything.

## Level-triggered by design (the load-bearing invariant)

Kubernetes controllers are **level-triggered**: each pass re-reads desired vs actual state and
computes the correction, rather than reacting to the event that woke it. `sprint-carryover` adopts
this directly, exactly as `work-drain` does:

| Edge-triggered (rejected) | Level-triggered (this skill) |
|---|---|
| Build a move-queue once, pop items, trust the queue | **Re-derive the candidate set from the tracker every pass** |
| Interruption loses position / double-moves | Interruption is free — the next pass re-reads the world |
| Stale queue drifts from reality | Candidate set cannot drift; the tracker *is* the state |
| Needs a durable local queue file | Needs **no local queue** — no file to corrupt or desync |

**Consequences (binding):**
- The candidate set is **derived, never stored** as source of truth. A cached copy is a *hint* for
  one pass; it is discarded at the start of the next.
- **Idempotent-resume is inherent**: a re-run after a partial move re-derives, sees already-moved
  items are now IN the active sprint (out of scope), and continues with what remains.
- **Re-running once everything is carried over is a no-op** — the correct end state, not a failure.
- Never trust the search index as authoritative: it lags. Confirm each item's real sprint with a
  direct `get` before moving it.

## Pipeline (phases)

```text
0. INTAKE   resolve execution context (date/time/tracker/project) + IDENTITY (§ params).
            empty/unresolvable required input -> usage/HITL, STOP.
1. DETECT   capability-detect the tracker surface — MCP first (atlassian/jira/linear/gh-issues),
            then CLI (`gh`, `acli`, `jira`). Probe, never fabricate; cite what was found.
            none available -> HITL, STOP.
2. DISCOVER (compose work-compass) enumerate PAST/CLOSED sprints on the board; for each, list OPEN
            items (status != done/closed/resolved); filter owner in union(scope):
              identity (name/login/email) U agents (bot logins) U department (component/team/label).
            level-triggered: re-derived from the tracker each run — no stored queue.
3. BUILD    the candidate move-set; de-dupe; EXCLUDE anything already in the active sprint or out
            of scope. confirm each item's real state via a direct `get` (the index lags).
4. PRESENT  the table (ticket-id | Title/Description-slug | Old Sprint | New Sprint=active) + count.
            --dry-run  ==>  STOP HERE (nothing written).
5. GATE     operator confirmation (or a standing GO). ONLY THEN MOVE each item to the active sprint
            via the detected surface. Idempotent: re-run after a partial move = no-op on the moved.
6. REPORT   the final migration table (ONLY items actually moved) + skipped/failed with reasons.
```

Phase 4→5 is the whole safety design: the move-set is seen and approved before any write.

## Composition (what it delegates — it reimplements none of these)

| Concern | Delegated to |
|---|---|
| Tracker access, sprint enumeration, owner/identity + orphan matching (discovery) | `skills/work-compass` |
| Workspace isolation / worktree + PR governance (if the run opens one) | `skills/worktree-policy` · `skills/hierarchical-merge` |
| Adversarial verification on a hard-trigger (bulk shared-tracker mutation) | `skills/red-team` |
| Independent decision when an assumption is short of confident | `skills/council-gate` → HITL residue only |

If a phase here starts to grow its own tracker client, sprint parser, or owner-matcher — that is the
signal it has drifted from conducting into reimplementing `work-compass`. Cut it back.

## Report format (verbatim contract)

The human-facing report MUST be a table with columns exactly:

```text
ticket-id | Title/Description-slug | Old Sprint | New Sprint
```

- In `--dry-run`: the table is the **proposed** move-set (New Sprint = the active sprint), plus a count.
- After a gated move: the table lists **only items actually moved**, plus a skipped/failed section with
  a reason per row. Nothing the run declined to touch is absent from the report (no silent truncation).

## Machine output (`--json`) — aligned with the family envelope

```json
{"identity":"<…>","scope":["identity","agents","department"],"project":"<…>","active_sprint":"<…>",
 "verdict":"MIGRATED|DRY_RUN|DEFER_HITL|NO_CANDIDATES","dry_run":true,
 "migrated":[{"ticket":"<ID>","slug":"<…>","old_sprint":"<…>","new_sprint":"<active>"}],
 "skipped":[{"ticket":"<ID>","reason":"<…>"}],"human_domain":false,"_agent_feedback":"<hints>"}
```

Exit codes: `0` migrated / dry-run-ok · `1` error · `2` DEFER-HITL.

## Capability-detection & honest emptiness

`--tracker` (implicit) probes which surfaces are live before assuming one: MCP (atlassian/jira/linear/
gh-issues) first, then CLI (`gh`, `acli`, `jira`). Route by context — Jira for corporate work, Linear
for personal, GitHub Issues for repo-scoped. **This repo's own tracker is GitHub Issues** — the skill
must not hardcode Jira. Degrade gracefully: an unavailable surface is marked `unavailable`, never
fabricated, never a silent block.

⛔ **A negative probe is not proof of absence.** Before concluding "no stranded items", run a positive
control: same instrument, same query shape, something you know exists. A silent empty result from an
under-reaching instrument looks identical to a genuinely empty backlog — and the two demand opposite
actions.

## Autonomy posture (bulk mutation of a shared tracker = HUMAN_DOMAIN)

Moving N items across sprints on a SHARED board multiplies blast-radius by N and is visible to the
whole team. Rigor therefore scales **up** with N:

- The MOVE is **always confirm-gated**; dry-run is the default; there is no auto-move without GO.
- Score short on any assumption (identity/project/active-sprint) → Score-Uplift (≤3 honest attempts)
  → **MoE debate-converge → Council decides** (verifier ≠ generator) → only the irreducible residue
  reaches HITL, carrying **ranked candidates + rationale**, never a blank ask.
- Red-team is **mandatory** on the hard-trigger (bulk mutation of a shared tracker). Independence
  unavailable at HIGH → **HOLD, do not force**.
- HUMAN_DOMAIN + non-negotiable guardrails (cross-org boards · cost-bearing writes · irreversible bulk
  relocation) halt the run → HITL regardless of item count.

## Relationship to siblings

| Tool | What it does with the register | Register comes from | Verb |
|---|---|---|---|
| `sprint-carryover` (this) | **relocates** open items across sprint boundaries + reports | past sprints (derived each pass) | MOVE |
| `work-compass` | **surfaces** scattered/stale/orphan work, read-only | cross-domain fan-out | DETECT |
| `work-drain` (Antlia) | **executes** each item to DONE | external trackers (derived each pass) | DRAIN |
| `chief-of-staff` | **reports** the operator's plate, read-only | external trackers | BRIEF |

`sprint-carryover` shares `work-compass`'s discovery lineage (same fan-out, same owner-matching) but
its verb is **relocation**, not detection or execution.

## §Quality Tests

**6/6 self-validity (must all pass before returning):**
1. Frontmatter parses as YAML; `name` + `description` present; subdirectory `SKILL.md` format.
2. Command wrapper exists and its filename = the `/entry` (`commands/sprint-carryover.md`).
3. `--dry-run` (default) writes nothing and renders the exact-column report table.
4. `--json` emits the envelope shape above; exit codes match (`0`/`1`/`2`).
5. Level-triggered: re-run after a partial move is a no-op on already-moved items.
6. `bash tests/validate-plugin.sh` passes (0 new errors).

**Scope-discipline 6Q:** (1) Does it MOVE (not merely detect/execute)? (2) Is discovery delegated to
`work-compass`, not reimplemented? (3) Is the move gated behind an explicit GO? (4) Is dry-run the
default? (5) Are the three owner-sets a union under `--scope`? (6) Is emptiness proven with a positive
control, not assumed from a silent probe?

**Anti-theater 8Q:** (1) No fabricated tickets/sprints/owners. (2) No hardcoded tracker. (3) No claimed
CLI flag that the pipeline does not honor. (4) No silent truncation — every skipped item is named with
a reason. (5) No auto-move without GO. (6) Index is confirmed with a direct `get`, not trusted. (7) No
secret/PII leak in output. (8) Unresolvable identity DEFERs-HITL with candidates, never guesses.

## §DUED Sunset (qualitative, not counter-based)

Deprecate when: a native tracker feature carries unfinished items forward automatically at sprint
close (E1) · `work-compass` grows a first-class relocation verb making this redundant (E6) · operator
retraction (E4) · ≥3 false-positive owner-match contexts (E5 → refine the owner-union, not auto-deprecate).

## §Refs

- `skills/work-compass/SKILL.md` (discovery / identity / sprint-enumeration — **composed**, not reimplemented)
- `skills/work-drain/SKILL.md` (sibling — *drains* to DONE; the level-triggered pattern is inherited from here)
- `skills/worktree-policy/SKILL.md` · `skills/hierarchical-merge/SKILL.md` (workspace/PR governance, reused)
- `skills/anima/SKILL.md` (named this skill: system-name `sprint-carryover`; rejected runner-up `backlog-rollover`)
- `commands/sprint-carryover.md` (the `/entry` wrapper — same deliverable, invocation-surface gate)

## DNA Geracional (inherited by every spawned agent)

- **Compose-not-reimplement** — discovery is `work-compass`'s job; never rebuild tracker access.
- **Level-triggered** — the tracker *is* the write-ahead log; re-derive every pass, store no queue.
- **Confirm-gate the mutation** — bulk shared-tracker writes are HUMAN_DOMAIN; dry-run default, GO required.
- **No silent truncation** — anything skipped is named with a reason in the report.
- **DRY / KIS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **Boy-Scout** — leave the tracker and the tree cleaner than found; no half-moved items, no loose ends.

## Examples

```text
/sprint-carryover                                             # dry-run: my stranded items -> proposed table
/sprint-carryover --scope identity,agents                     # include my bot-agents' stranded items
/sprint-carryover --department dev-be --project VKS            # a department's backlog on a named board
/sprint-carryover --active-sprint "Sprint 42" --dry-run=off    # GATED move into a named active sprint (needs GO)
/sprint-carryover --json                                       # machine envelope for agent-to-agent
```

## §Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-09-16 | **Bootstrap.** Genesis artifacts (skill + `/sprint-carryover` command wrapper) forged via the `agentic-tool-forge` methodology. Named by the `anima` methodology: system-name **`sprint-carryover`** (no soul-name); rejected runner-up **`backlog-rollover`**. **Composes `work-compass`** for discovery/identity/sprint-enumeration (DRY, the same way `work-drain`/Antlia composes it) — reimplements no tracker access. Fills the DRY gap vs siblings: `work-compass` *detects* (read-only), `work-drain` *drains* to DONE (executes), `sprint-carryover` **relocates** open backlog from past sprints into the active sprint (migrates + reports). dry-run default ON; MOVE is HITL-confirm-gated (HUMAN_DOMAIN bulk mutation); level-triggered/idempotent; report table `ticket-id | Title/Description-slug | Old Sprint | New Sprint`; `--json` family envelope; EN+PT triggers; cross-vendor AAIF, capability-detected, stdlib-friendly. |

## License

MIT (inherits the plugin's license).
