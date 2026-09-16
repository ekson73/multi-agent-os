---
name: sprint-carryover
version: "0.1.0"
description: |
  RELOCATE stranded open backlog from past/closed sprints INTO the active sprint. Given the
  operator's IDENTITY, their ai-bot-agents, and/or their department, DISCOVER open items still on a
  past sprint owned by any of those owner-sets, PRESENT the candidate move-set as a table, and — only
  on explicit operator GO — MOVE each to the active sprint, then REPORT what migrated. dry-run is the
  DEFAULT: a bare invocation discovers, renders the table, and writes NOTHING. Level-triggered: each
  pass re-derives the candidate set from the tracker, so a re-run after a partial move is a no-op.
  Thin conductor: COMPOSES work-compass for the discovery fan-out + the operator's own open items;
  sprint/owner enrichment beyond that seed is this skill's own tracker-native query.
  Triggers: "sprint-carryover", "carry over the backlog", "roll over stranded tickets", "move
  unfinished items to the current sprint", "sprint rollover", "carregar o backlog", "levar pendências
  para o sprint atual", "rollover de sprint".
allowed-tools: Task, Read, Bash, Grep, Glob, AskUserQuestion
---

# sprint-carryover

> Relocate stranded open backlog from past sprints INTO the active sprint — migrate, then report.
> **Composes** `work-compass` as the deterministic **fast-path** for the discovery **fan-out** +
> identity seed **when its fields are present** — its collector output is a *starting point*, not a
> ceiling. Sprint-field enrichment, other-owner/department/label/component matching, and pagination
> are layered on top via a tracker-native query, and the skill **extends/escalates** wherever
> work-compass does not reach (see `## Hybrid execution & forward-compatibility`). Distinct from its
> siblings: it neither merely *surfaces* scattered work (`work-compass`, read-only) nor *executes* the
> work item-by-item (`work-drain`, Antlia) — it **relocates** open items across sprint boundaries and
> reports the migration.
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
| `--agents-file` | — | path to a file listing bot logins (one per line); takes precedence over `--agents` when both are supplied |
| `--department` | — | area label(s): `devops` · `dev-fe` · `dev-be` · `ba` · `sa` (maps to tracker component/team/label — tracker-specific) |
| `--project` | `auto` | tracker project key/board; `auto` = infer from repo remote or a single accessible project, else HITL |
| `--active-sprint` | `auto` | the current/active sprint; `auto` = the tracker's `state=active` sprint on the board; ambiguous ⇒ HITL |
| `--scope` | `identity` | which owner-sets to include (union): any combination of `identity`,`agents`,`department` |
| `--apply` | **off** | WRITE the moves. Absent = dry-run (the default): discover + render the move table, write NOTHING. With `--apply`, skip the interactive confirm and move directly (still subject to the per-item phase-5 re-check). |
| `--json` | off | machine envelope (see below). |

> If identity / project / active-sprint cannot be resolved after probing → **declare the assumption
> and DEFER-HITL with the best-computed candidates**. Do not silently guess; do not move anything.

> **Scope rule (no magic):** supplying `--department`/`--agents` WITHOUT naming that set in `--scope`
> is a **no-op for that set** — the pipeline only includes owner-sets named in `--scope` (default
> `identity`). To act on a department, name it: `--department dev-be --scope department` (or
> `--scope identity,department`). Same for `--agents` (`--scope agents`).

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
2. DISCOVER (compose work-compass) use work-compass as the deterministic fast-path for the discovery
            FAN-OUT + the operator's own open items (identity seed) WHEN its fields are present. Its
            collector output is a STARTING POINT, not a ceiling: where a needed field is absent today
            (sprint, other-owner/department/label/component) or where a collector caps its result set,
            THIS skill enriches on top with a tracker-native sprint-aware query — enumerate
            PAST/CLOSED sprints; for each, list items in an ACTIONABLE (non-terminal) state for THAT
            provider (Jira statusCategory != Done; GitHub open/not-closed; Linear state.type in
            {backlog,unstarted,started} i.e. exclude both completed AND canceled) — i.e. exclude EVERY
            provider-terminal state (done/closed/resolved/canceled/merged/…) via the provider's own
            state taxonomy, extensible to new providers/states; filter owner in union(scope) via
            tracker clauses (JQL sprint/assignee/component; `gh` label/assignee filters) — and
            PAGINATE past any collector limit or explicitly report truncation (never silently cap).
            capability-detect at run time: a new provider/field/MCP endpoint is ABSORBED, not rejected.
            level-triggered: re-derived from the tracker each run — no stored queue.
3. BUILD    the candidate move-set; de-dupe; EXCLUDE anything already in the active sprint, any item
            in a provider-terminal state (done/closed/resolved/canceled/merged/… per that provider's
            taxonomy), or out of scope. confirm each item's real state via a direct `get` (the index lags).
4. PRESENT  the table (ticket-id | Title/Description-slug | Old Sprint | New Sprint=active) + count.
            NO --apply (default dry-run)  ==>  render table, then ASK the operator "apply these N
            moves to the active sprint for real? [y/N]" via AskUserQuestion. NO / no answer => STOP
            (nothing written), verdict DRY_RUN. YES => proceed to phase 5.
            --apply given  ==>  skip the prompt, proceed directly to phase 5 (per-item re-check still runs).
5. GATE     operator GO — either the interactive "apply? [y/N]" YES from phase 4, or an explicit
            `--apply`. ONLY THEN MOVE each item to the active sprint
            via the detected surface. Immediately before EACH move, a direct `get` MUST re-evaluate
            the FULL candidate predicate (owner in union(scope) · department · labels · components ·
            still on its OLD/past sprint · actionable non-terminal status, canceled/terminal excluded)
            AND verify the destination is still the resolved active sprint — the phase-3 check may be
            stale after the approval pause (a ticket may have completed, been canceled, reassigned, or
            lost its department/label/component during a long review). Any candidate that no longer
            satisfies EVERY predicate, or whose destination changed, is skipped + reported, never moved.
            Idempotent: re-run after a partial move = no-op on the moved.
6. REPORT   the final migration table (ONLY items actually moved) + skipped/failed with reasons.
```

Phase 4→5 is the whole safety design: the move-set is seen and approved before any write.

## Hybrid execution & forward-compatibility

This tool is a **hybrid orchestrator** — deterministic (capability probes, tracker-native queries,
level-triggered re-derivation), probabilistic (owner-set / department resolution, ambiguity handling),
and non-deterministic/adaptive (an AI agent reading whatever surface is live at run time). Its reach
is defined by **what is available now**, not fixed at authoring time:

- **Capability-detected, not hardcoded.** The skill uses whatever capability is present — `work-compass`
  fields, tracker-native JQL / `gh` clauses, MCP tools, and **providers/fields/endpoints that do not
  exist yet**. A new provider, a new sprint/owner/label/component field, or a new MCP endpoint is
  ABSORBED via run-time capability-detection, not rejected because it was not configured when the skill
  was written.
- **Graceful escalation when a capability is absent today.** A needed capability that is missing now is
  handled by a fixed ladder — **enrich via a native query → provision/adapt the query shape →
  DEFER-HITL** — rather than refusing the work or hard-capping the tool to today's surface. `work-compass`
  is the deterministic fast-path where its fields reach; the skill layers its own enrichment where they
  do not, and will prefer a native field the moment a provider begins exposing it.
- **Anti-theater is preserved, and is the exact boundary.** Declaring a TARGET capability with graceful
  degradation ("*when* the tracker exposes sprint/owner, use it; if not, enrich/paginate/provision/
  DEFER-HITL") is honest and non-capping. Asserting a capability as a PRESENT FACT that is not verified
  ("this moves tickets now" / "this field exists here") is theater and is forbidden. A missing
  capability is always **detected + reported + routed**, NEVER fabricated, and no field/move is ever
  claimed to have happened that did not.

Net: the skill uses `work-compass` where it reaches and transparently extends/escalates where it does
not — **forward-compatible with capabilities not yet present**, while never claiming a present-tense
capability it cannot verify.

## Composition (what it delegates — and what it does NOT)

| Concern | Delegated to |
|---|---|
| Discovery **fan-out** + the operator's own open items (identity seed) | `skills/work-compass` |
| Workspace isolation / worktree + PR governance (if the run opens one) | `skills/worktree-policy` · `skills/hierarchical-merge` |
| Adversarial verification on a hard-trigger (bulk shared-tracker mutation) | `skills/red-team` |
| Independent decision when an assumption is short of confident | `skills/council-gate` → HITL residue only |

**NOT delegated (this skill's own tracker-native query, layered on top):** where `work-compass`'s
collector reaches — the operator's own open items via the discovery fan-out — it is the deterministic
fast-path. Where it does not reach TODAY (no sprint field, no other-owner/department/label/component
in its Jira collector's `assignee=currentUser() AND statusCategory!=Done` seed; a `gh` collector with
a fixed limit and no overflow signal), this skill enriches on top: sprint enumeration,
owner/department/label/component matching, actionable-state filtering, and pagination via
tracker-native clauses. This skill still does **not** rebuild `work-compass`'s fan-out or its
tracker-access plumbing — it layers the sprint-aware clauses on top and is forward-compatible: if
`work-compass` (or a future provider) later exposes those fields natively, the skill uses them via
capability-detection rather than duplicating the enrichment (see `## Hybrid execution &
forward-compatibility`).

## Report format (verbatim contract)

The human-facing report MUST be a table with columns exactly:

```text
ticket-id | Title/Description-slug | Old Sprint | New Sprint
```

- In dry-run (the default, no `--apply`): the table is the **proposed** move-set (New Sprint = the active sprint), plus a count.
- After a gated move: the table lists **only items actually moved**, plus a skipped/failed section with
  a reason per row. Nothing the run declined to touch is absent from the report (no silent truncation).

## Machine output (`--json`) — aligned with the family envelope

```json
{"identity":"<…>","scope":["identity","agents","department"],"project":"<…>","active_sprint":"<…>",
 "verdict":"MIGRATED|DRY_RUN|DEFER_HITL|NO_CANDIDATES","dry_run":true,
 "proposed":[{"ticket":"<ID>","slug":"<…>","old_sprint":"<…>","new_sprint":"<active>"}],
 "migrated":[{"ticket":"<ID>","slug":"<…>","old_sprint":"<…>","new_sprint":"<active>"}],
 "skipped":[{"ticket":"<ID>","reason":"<…>"}],
 "failed":[{"ticket":"<ID>","error":"<…>"}],
 "human_domain":true,"_agent_feedback":"<hints>"}
```

- `proposed` vs `migrated`: **DRY_RUN** → the candidate move-set lives in `proposed` and `migrated`
  stays empty; **MIGRATED** → items actually written live in `migrated`. `migrated` NEVER carries a
  dry-run candidate (that would lie).
- `skipped` (out-of-scope / no-op / already in active sprint) vs `failed` (write attempted, errored —
  `{ticket,error}`) are distinct sets.
- `human_domain` is **always `true`** for this tool: every MOVE is a bulk mutation of a shared tracker.

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

⛔ **A work-compass result lacking sprint/owner fields is an UNDER-REACH, not a true empty.** When
work-compass returns only the operator's own open items with no sprint/other-owner/department field, a
"no candidates" from it alone is a positive-control failure, NOT evidence the backlog is empty. The
skill MUST then escalate — enrich via the direct sprint-aware tracker query (JQL sprint/assignee/
component clauses; `gh` label/assignee filters), or DEFER-HITL. This is capability-detection, not a
cap: the seed's reach today is a floor to build on, never a ceiling on what the skill can find.

⛔ **Pagination overflow is never a silent cap.** When a collector caps its result set with no
overflow signal, the run MUST paginate past that limit or explicitly report truncation in the
report/`_agent_feedback` — consistent with the "no silent truncation" anti-theater rule.

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
3. dry-run (default, no `--apply`) writes nothing and renders the exact-column report table.
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

- `skills/work-compass/SKILL.md` (fast-path discovery fan-out + identity seed — **composed** where its fields reach, not reimplemented; sprint enumeration is this skill's own layer on top)
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
/sprint-carryover                                                    # dry-run: propose table, then ASK "apply for real?"
/sprint-carryover --scope identity,agents                            # include my bot-agents' stranded items
/sprint-carryover --department dev-be --scope department --project VKS  # a department's backlog on a named board
/sprint-carryover --active-sprint "Sprint 42" --apply                # GATED move into a named active sprint (needs the per-item re-check)
/sprint-carryover --json                                             # machine envelope for agent-to-agent
```

## §Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-09-16 | **Bootstrap.** Genesis artifacts (skill + `/sprint-carryover` command wrapper) forged via the `agentic-tool-forge` methodology. Named by the `anima` methodology: system-name **`sprint-carryover`** (no soul-name); rejected runner-up **`backlog-rollover`**. **Composes `work-compass`** as the fast-path discovery fan-out + identity seed (DRY, the same way `work-drain`/Antlia composes it); sprint/owner/department enrichment + pagination are this skill's own tracker-native query layered on top (hybrid, forward-compatible) — reimplements no tracker access. Fills the DRY gap vs siblings: `work-compass` *detects* (read-only), `work-drain` *drains* to DONE (executes), `sprint-carryover` **relocates** open backlog from past sprints into the active sprint (migrates + reports). dry-run default ON; MOVE is HITL-confirm-gated (HUMAN_DOMAIN bulk mutation); level-triggered/idempotent; report table `ticket-id | Title/Description-slug | Old Sprint | New Sprint`; `--json` family envelope; EN+PT triggers; cross-vendor AAIF, capability-detected, stdlib-friendly. **(n++3)** Renamed the write-toggle to `--apply` (Anima; plan->apply industry pattern; replaces `--dry-run=off`); dry-run is now the implicit default (absence of `--apply`). Bare invocation now ENDS by asking the operator "apply for real? [y/N]" (AskUserQuestion); `--apply` skips the prompt and moves directly. Per-item phase-5 re-check unchanged (the real safety). |

## License

MIT (inherits the plugin's license).
