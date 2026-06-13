---
name: ticket-sync-protocol
description: SSOT for postflight P2.5 TICKET-SYNC — end-of-session backlog reconciliation (gap→ticket triage, continuation ticket, enrichment) that composes a capability-detected ticketing primitive
version: 1.0.0
---

# Ticket-Sync Protocol (SSOT) — postflight P2.5

> **Version**: 1.0.0 (2026-06-13)
> **Scope**: AAIF cross-vendor. The single source of truth for **P2.5 TICKET-SYNC**, the
> postflight phase that reconciles the **backlog** (tickets/issues) with the **reality of the
> session** at exit — so the "treasure map" (tickets) never diverges from what actually
> happened.
> **Position**: runs **between P2 DEBRIEF and P3 HANDOFF** — it needs the DEBRIEF atoms
> (gaps · pendings · undecided · unasked-Qs · out-of-scope items) as input, and must finish
> **before** the seed/spawn so the continuation ticket can be named in the seed.
> **Cross-link slug**: `ticket-sync-protocol`

## Purpose

An amnesic agent **will not remember** to file the loose ends it surfaced, nor to leave a
trackable breadcrumb for the next session. P2.5 mechanizes that (per the harmonic
"mechanize-don't-memorize" discipline): at exit, the session's loose ends become **bounded,
de-duplicated, audit-trailed tickets**, and a single **continuation ticket** anchors the
next session.

It **orchestrates a native ticketing primitive — it does not reinvent one** (per the
anti-over-engineering principle: no custom ticket schema, no custom state machine — the
**tracker is the state**). All creation/update/close is **delegated** to a
capability-detected ticketing tool (see "Capability ladder"); P2.5 only decides *what* to
file and *how much*, never *how* to talk to a provider.

## The three sub-steps

### (a) Gap → ticket triage (bounded autonomous)

For each atom the P2 DEBRIEF surfaced (`gaps` · `pendings` · `undecided` · `unasked_questions`
· out-of-scope TODOs):

```text
ATOM
 → anti-theater filter   (real + actionable + useful? — drop theater/vanity/already-done)
 → dedup                 (delegate: ticketing primitive `auto` op = search → create-if-absent → else link+enrich)
 → Eisenhower classify   (Q1 urgent+important · Q2 important · Q3 urgent · Q4 neither)
 → act per quadrant      (table below) under the cap
```

| Quadrant | Action |
|---|---|
| **Q1** (urgent + important) | Create a ticket **now** (highest salience); link to the session + parent. |
| **Q2** (important, not urgent) | Create a ticket (backlog); link to session/parent. |
| **Q3** (urgent, not important) | Create a ticket **+ flag for delegation/dispatch** (route to a specialist later). |
| **Q4** (neither) | Do **not** spend a ticket. Fold into the **batch housekeeping ticket** (below) **or** drop with a one-line audit note. |

**Caps (anti-ticket-spam — hard):**

- **≤ 3 individual tickets per cycle.** The 4th+ qualifying atom does **not** get its own
  ticket — it rolls into a **single batch housekeeping ticket** (one ticket whose body is a
  bullet-list of the remaining items). This bounds blast-radius while losing nothing.
- **Autonomy is bounded**: file autonomously within the cap; escalate to the operator
  (HITL) only for **HUMAN_DOMAIN** atoms (secrets · PII · irreversibles · cross-org · cost)
  or when the **provider is unknown** (no routing class resolvable). Never auto-write a
  HUMAN_DOMAIN atom into a ticket body — strip + escalate.

### (b) Continuation ticket (idempotent)

Create **one** continuation ticket so the next session is anchored on the backlog, not only
in the seed file:

- **Idempotent — search-before-create.** Delegate the `auto` op (search → create-if-absent
  → else link+enrich). A 2nd postflight run on the same source session **reuses + enriches**
  the existing continuation ticket; it never creates a duplicate.
- **Body = a mirror of the continuation seed** (the same resume-spine the seed carries:
  who-you-are · mission · inherited-state · guardrails · DoD · DAG · refs). The seed (P3) and
  the continuation ticket are two registers of the *same* handoff — keep them consistent
  (render both from the P2/P3 state, do not maintain in parallel).
- **Linkage is provider-relative** (governance-discovered, never assumed): **"relates-to"
  link + bidirectional comments** by default; promote to **child-of-parent** only when the
  provider's hierarchy supports it (e.g. an epic/parent ticket the session anchors to).
- The resulting key/URL is written into the seed's `continuation_ticket` field (P3) and
  passed to the spawn (`--ticket <KEY>`, P3.5) so the next session is *named/anchored* by it.

### (c) Enrich related tickets

For any ticket the session **anchored to** (the R0 anchor / `refs.ticket`): enrich it with
this session's progress/deliverables (delegate `enrich`). For a ticket whose DoD is now
**verifiably met**, closure is **P1 SWEEP's** job (delegate `close` with its verify-gate) —
P2.5 does not double-close.

## Capability ladder (degrade-safe — never block)

Resolve the ticketing capability at invocation, top-down; the first present wins:

1. **A dedicated ticketing skill** is installed (user-scope) → **delegate** every op
   (`create`/`update`/`link`/`enrich`/`close`/`auto`) to it. It owns provider resolution
   (Jira/Linear), the 17-field body schema, the close verify-gate, auto-assign, and L8
   cross-links. *(Reference implementation: the user-scope `ticket-as-prompt` skill.)*
2. **No skill, but the repo is GitHub-hosted** and `gh` is present → file via `gh issue
   create` / `gh issue comment` (the native primitive for the **community** class).
3. **Neither** → **DEFER(ticket)**: record the would-be tickets in the seed's
   `tickets_created` as `{deferred: true, eisenhower, link: "none", reason}` + a one-line
   audit note, and continue. P3 HANDOFF / P3.5 SPAWN proceed **normally** — a missing tracker
   never blocks the exit.

**Routing is by repo CLASS, never by hardcoded org-name** (layer purity): governance
discovery (CLAUDE/AGENTS + the ticketing skill's own L4 routing) maps **corporate → Jira ·
personal → Linear · community → GitHub Issues**. This SSOT names **no** specific org, project
key, or cloud id — those live in the (user-scope) routing the skill composes.

## Audit trail (mandatory)

Every P2.5 action is traceable:

- Each created/enriched/deferred ticket is recorded in the seed's `tickets_created[]` —
  a filed ticket as `{key, eisenhower, link}` or a deferred one as `{deferred: true,
  eisenhower, link, reason}` (boolean discriminator; see the contract) — and surfaced in the
  postflight exit summary (`TICKETS closed N · created N + batch · continuation → KEY`).
- The continuation ticket key/URL is written to the seed's `continuation_ticket`.
- Dropped Q4 atoms get a one-line note (what + why dropped) so a "nothing filed" exit is
  never silently a "nothing surfaced" exit.

## Anti-patterns (do NOT)

1. ❌ **> 3 individual tickets in one cycle** — past the cap, roll into the batch ticket. A
   ticket per micro-observation is backlog spam.
2. ❌ **Ticket-for-theater** — filing a ticket for a non-actionable/vanity/already-done atom
   (fails the anti-theater filter). A ticket must change someone's next action.
3. ❌ **API/network calls from the deterministic PreCompact hook** — P2.5 ticket I/O is the
   **live skill's** job. The hook is a zero-network snapshot only (it must never call a
   tracker API — that belongs to the agentic phase).
4. ❌ **Duplicate continuation ticket** — always search-before-create (`auto` op); the 2nd
   run reuses + enriches, never re-creates.
5. ❌ **Hardcoding a provider / org / project key** in this community SSOT — route by class
   via governance discovery; the provider specifics live in the composed user-scope routing.
6. ❌ **Blocking the exit on a missing tracker** — no capability ⇒ DEFER(ticket), never halt
   P3/P3.5.
7. ❌ **Auto-writing a HUMAN_DOMAIN atom into a ticket** — strip + escalate; secrets/PII/cost
   never land in a ticket body.

## Related artifacts

- `skills/postflight/SKILL.md` — the orchestrator; **P2.5** invokes this protocol between
  P2 DEBRIEF and P3 HANDOFF.
- `skills/postflight/references/continuation-seed-contract.md` — the seed contract; P2.5
  populates its `continuation_ticket` · `tickets_created` · (and consumes `session_type`).
- `protocols/exit-hygiene.md` — the exit gate; P1 SWEEP owns ticket **close**, P2.5 owns
  ticket **create/enrich** for the loose ends.
- `bin/spawn-continuation.sh` — consumes the continuation ticket key (`--ticket <KEY>`, P3.5).
- A capability-detected, user-scope **ticketing skill** (reference: `ticket-as-prompt`) —
  the native-primitive map P2.5 delegates to; **DRY — reference it, never copy its op logic.**

## License

MIT (matches the multi-agent-os repo `LICENSE`).
