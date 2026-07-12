---
name: continuation-seed-contract
description: Field-by-field SSOT contract for the session.continuation continuation-seed envelope (worktree-lifecycle family)
version: 1.2.0
---

# Continuation-Seed Contract (SSOT)

> **Version**: 1.2.0 (2026-07-10)
> **Scope**: AAIF cross-vendor. The single source of truth for the shape, semantics, and
> hygiene rules of the `session.continuation` seed emitted/consumed across the
> `worktree-lifecycle` family.
> **Template**: [`../templates/continuation-seed.template.json`](../templates/continuation-seed.template.json)
> **Consumers**: see "Consumer registry" below.
> **Cross-link slug**: `continuation-seed-contract`

## Purpose

The continuation seed is a **minimal-sufficient, ai-agnostic resume packet** for a *fresh,
amnesic* agent: a gifted agent with **no cross-session recall**. The seed must therefore be
**self-contained** — a consumer must be able to resume the work from the seed alone, with
ZERO dependence on conversational memory, prior transcript, or "you remember when we…".
Anything the next agent needs is either IN the seed or REACHABLE from a ref the seed names.

Repo master principle (verbatim, from the locus grammar SSOT): *"what is not seen is not
remembered; what is computed and seen is remembered, by humans **and** agents."* The seed is
that principle applied to the session boundary.

## Envelope

JSON-RPC 2.0 **notification** shape (fire-and-forget — the producer does not await a reply):

```json
{"jsonrpc":"2.0","method":"session.continuation","params":{ ... },"data":{"layer":"community", ...}}
```

- `method` is always `"session.continuation"`.
- `data.layer` declares attribution (`"community"` for this repo's emissions).
- `data.contract` / `data.contract_version` SHOULD point back to this file (self-describing seed).

## Field-by-field contract (`params`)

> **REQUIRED scope**: the REQUIRED column below binds **rich seeds** (the P3 HANDOFF
> synthesis). Registered **subset producers** (snapshot/fallback — see Consumer registry)
> emit an honest subset and are exempt from the rich-seed REQUIRED set; their minimum is
> the envelope + `resume_instructions` (per the subset clause under the registry table).

| Field | Req | Semantics |
|---|---|---|
| `who_you_are` | REQUIRED | One sentence telling the resuming agent the role/identity to assume. Removes the "who am I in this work?" cold-start guess. |
| `bootstrap_order` | REQUIRED | **Ordered** array of reads/commands to execute FIRST (governance docs, key files, orienting git commands). Order matters — earlier items gate later understanding. |
| `inherited_state` | REQUIRED | **Verified facts only** (anti-theater: computed at seed-time, never asserted from memory): `verified_facts[]`, `branches[]` as `<branch>@<sha>`, `env[]` runtime facts. |
| `mission` | REQUIRED | Ordered steps of the work itself; element 0 is the one-line mission. |
| `guardrails` | REQUIRED | Binding constraints the resuming agent must not violate (e.g. "never commit secrets", "worktree-only edits", "do NOT merge"). |
| `dod` | REQUIRED | Binary-checkable Definition-of-Done checklist — each item verifiable true/false. |
| `dag` | REQUIRED | What comes AFTER this mission completes (the downstream node(s) of the work graph). May be `["none — terminal"]`. |
| `refs` | REQUIRED | Traceability object: `git` (repo + branch + PRs), `ticket` (tracker key/URL or `"none"`), `memory` (journal/memory paths or `"none"`), `session` (source session id). |
| `resume_instructions` | REQUIRED | The first command(s) to run on wake (conventionally: orient via `/maos:preflight`, then `bootstrap_order`, then first non-blocked `next_action`). |
| `goal` | OPTIONAL (legacy-compat) | One-line mission kept for consumers that predate `mission[]`. Rich seeds SHOULD include it and it MUST equal `mission[0]` in spirit when present; skeleton/fallback seeds MAY omit it (e.g. `postflight-precompact.sh` emits no `goal`). |
| `context` | OPTIONAL | Prose state-of-world supplement. |
| `git` | OPTIONAL | Quick-glance git object (`repo`/`branch`/`worktree`/`prs[]`) — convenience mirror of `refs.git` + `inherited_state.branches`. |
| `locus` | OPTIONAL | D1 locus line (`bin/locus.sh --density name`) — see `locus-spec.md`. |
| `objectives` | OPTIONAL | `{primary[], secondary[], auxiliary[]}` N-Tree from P2 DEBRIEF. |
| `done` / `in_flight` | OPTIONAL | What is finished vs. mid-flight at seed-time. |
| `gaps` / `pendings` / `undecided` / `unasked_questions` | OPTIONAL | The debrief's loose-end taxonomy. |
| `risks` | OPTIONAL | The P2 DEBRIEF **risk survey** (the hunt's forward-looking half — `close-out-hunt-checklist.md` categories 4 **risks** + 5 **mitigations**): an array of `{risk, mitigation, severity?}`. Each element is a hazard for the next agent/downstream **paired with its mitigation** (a risk without a mitigation is half-surveyed). Carried so the resuming agent inherits the hazard AND the remedy — not just the fear. `severity` ∈ `low\|med\|high` (optional). |
| `next_actions` | OPTIONAL | `[{task, eisenhower: Q1..Q4, blocked_by}]` — resume entry-points, non-blocked first. |
| `governance_refs` | OPTIONAL | Governance docs the resuming agent should honor. |
| `session_type` | OPTIONAL | The session's classification `<mode>/<work>` (e.g. `continuation/feat`), from preflight R0 / the P2 DEBRIEF. Two orthogonal axes — see `skills/preflight/references/session-type-taxonomy.md`. Lets the resuming agent (and the continuation ticket) know the *kind* of work it is continuing. |
| `dna` | OPTIONAL | Inherited agentic principles (the **DNA Geracional** that must travel into spawned sessions, not only sub-agents). Accepts **either** a **string** (back-compat: the one-line `free-but-accountable · holistic-predictability · agnostic-self-healing`) **or** an **object** `{principles: [3 items], canonical_ref, session_learnings: [≤5], learnings_ref}`. When an object, `principles` carries the 3 transcribed principles, `canonical_ref` points at the canonical DNA doc, and `session_learnings` (≤5) are this session's distilled lessons appended to a learnings log at `learnings_ref`. A consumer MUST tolerate both forms. |
| `continuation_ticket` | OPTIONAL | The P2.5 continuation ticket anchoring the next session: `{key, url, parent, link}` (`link` = the provider-relative linkage used, e.g. `"relates-to"` / `"child-of"`). Mirrors the seed onto the backlog; `key` is passed to the spawn as `--ticket`. `"none"` / absent when no ticketing capability (DEFER). |
| `tickets_created` | OPTIONAL | Audit trail of the P2.5 gap→ticket triage. Array of objects, each **either** a filed ticket `{key, eisenhower: Q1..Q4, link}` **or** a deferred entry `{deferred: true, eisenhower: Q1..Q4, link, reason}`. The boolean **`deferred`** is the discriminator — a deferred entry has **no** `key` (never a string sentinel like `key: "deferred"`). Includes the batch housekeeping ticket when the ≤3 cap rolled extra atoms into it. |

A producer MAY add extra fields; a consumer MUST ignore fields it does not understand
(forward-compatible, Postel-style). A consumer MUST NOT require an OPTIONAL field.

## Best practices

1. **Amnesia premise** — write for a reader with zero shared context. No deixis ("this",
   "the earlier plan") without an in-seed referent. The test: could a brand-new agent on a
   different machine resume from the seed + the named refs alone?
2. **Verified, not asserted** — `inherited_state` facts are computed at emission time
   (`git rev-parse`, `git status`, `gh pr view`), never recalled. A stale or guessed sha is
   worse than no sha.
3. **Sanitization (hard rule)** — the seed is **metadata-only**: no secrets, no tokens, no
   PII, no file bodies. Run a secret scan (e.g. `gitleaks detect --no-git`) on the seed file
   before persisting/injecting; consumers (e.g. the spawn fallback path) additionally apply a
   defense-in-depth secret-pattern refusal before injecting a seed into a new session.
4. **Idempotent re-read** — reading/applying the seed twice must be harmless. Bootstrap
   reads are read-only; `resume_instructions` start with an orientation step (preflight),
   never a mutation. Producers write the seed atomically (tmp → mv) so a partial file is
   never observed.
5. **Minimal-sufficient** — include what changes the next agent's behavior; drop vanity
   detail. A seed that must be skimmed is a seed that gets skipped.
6. **Dual-register** — the JSON envelope is the **agent register** (machine-parseable,
   economical). Producers SHOULD also render an optional **human-markdown mirror**: the same
   content as a short scannable briefing (the operator reads the mirror; agents parse the
   JSON). Never let the mirror drift — it is rendered FROM the JSON, not maintained in
   parallel.
7. **Traceability** — `refs` must be bidirectionally honest: if the seed names a PR/ticket,
   that PR/ticket should (where the workflow allows) point back at the session/branch.

## Consumer registry

| Consumer | Role | Notes |
|---|---|---|
| `skills/postflight/SKILL.md` **P3 HANDOFF** | Producer (rich seed) | Synthesizes the full seed from P1 SWEEP + P2 DEBRIEF; prints + clipboards it. |
| `bin/spawn-continuation.sh` | Consumer + fallback producer | Injects the P3 seed into the spawned session (`--append-system-prompt`); when no seed file is given, synthesizes a **minimal subset** of this contract from git state (see its `read_seed()`). |
| `plugin-scripts/governance/postflight-precompact.sh` | Producer (deterministic snapshot) | PreCompact safety-net: emits a **skeleton** seed (`params.kind = "deterministic-snapshot"`, git facts + `resume_instructions` only) to `$GIT_DIR/maos/continuation-seed.latest.json` — honest subset, never fakes the agentic synthesis. |
| `skills/preflight/SKILL.md` **R0 ANCHOR** | Consumer | At session start, reads the seed's `refs.ticket` + `session_type` to anchor the woken agent on the right backlog node + know the session kind — closing the loop `postflight → spawn → preflight`. Tolerates their absence (subset/legacy seeds). |

Producers that emit a **subset** (snapshot/fallback) MUST keep the envelope (`method`,
`data.layer`) and `resume_instructions`, and SHOULD declare their reduced nature
(e.g. `params.kind`, or a note inside `resume_instructions`) so a consumer never mistakes a
skeleton for the synthesized seed.

## Versioning

This contract follows **SemVer**, versioned independently of the `postflight` skill:

- **PATCH** — clarifications, typo/semantic tightening, new best-practice prose.
- **MINOR** — new OPTIONAL fields, new consumers registered.
- **MAJOR** — a REQUIRED-field addition/removal/rename, or envelope change (breaks consumers).

Producers SHOULD stamp `data.contract_version`; consumers MAY use it to branch behavior, but
MUST still tolerate unknown fields within the same MAJOR.

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.2.0 | 2026-07-10 | MINOR — 1 new OPTIONAL field `risks` (array of `{risk, mitigation, severity?}`), the seed home for the P2 DEBRIEF risk survey (the hunt's forward-looking half — `close-out-hunt-checklist.md` categories 4 "risks" + 5 "mitigations"). No REQUIRED change, no envelope break; consumers ignore it Postel-style. Producer: `skills/postflight/SKILL.md` P2/P3 (v0.8.0). |
| 1.1.0 | 2026-06-13 | MINOR — 4 new OPTIONAL fields + 1 new consumer (no REQUIRED change, no envelope break). Adds `session_type` (the `<mode>/<work>` classification from preflight R0 / P2 DEBRIEF), upgrades `dna` to accept a **string OR object** (`{principles[3], canonical_ref, session_learnings[≤5], learnings_ref}`) so the **DNA Geracional** travels into spawned sessions (back-compat string preserved), and adds `continuation_ticket` + `tickets_created` (the P2.5 TICKET-SYNC outputs). Registers `skills/preflight/SKILL.md` **R0 ANCHOR** as a Consumer of `refs.ticket` + `session_type` — closing the `postflight → spawn → preflight` loop. Producer: `skills/postflight/SKILL.md` P2.5/P3 (v0.7.0). |
| 1.0.0 | 2026-06-11 | Bootstrap — extracts the seed shape (previously inline-only in SKILL.md P3 + a synthesized fallback in `spawn-continuation.sh`) into a reusable template + this contract. Adds the REQUIRED resume-spine fields (`who_you_are`, `bootstrap_order`, `inherited_state`, `mission`, `guardrails`, `dod`, `dag`, `refs`) on top of the existing P3 envelope fields (kept, now OPTIONAL except `resume_instructions`; `goal` is OPTIONAL legacy-compat — skeleton producers omit it). |
