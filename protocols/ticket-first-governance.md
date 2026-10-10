# Ticket-first governance

Scope: provider- and runtime-agnostic traceability for actionable work. This protocol
owns the start/resume decision; [postflight ticket-sync](../skills/postflight/references/ticket-sync-protocol.md)
owns end-of-session triage and the capability ladder. Provider schemas remain owned
by the configured ticketing primitive (including its existing 17-field body schema).

## Start and resume

1. Every actionable task must have a canonical ticket **before implementation**.
   Read-only discovery may determine scope and routing first. Questions and incidental
   observations need no new ticket; actionable residuals must be tracked.
2. Perform **search-before-create**, including closed tickets, PR links and pending-ticket
   records in the same authorized domain. Reuse/enrich the matching ticket. Independent
   tasks need an identifiable item; related small items may use the existing postflight
   batch ticket with individual acceptance criteria and status. Never drop actionable
   work merely to satisfy a ticket-count cap.
3. Resolve the configured provider, project/team, domain and **visibility** from current
   governance; verify write authority before publication. If already authorized, create
   without an additional ceremonial confirmation. Missing routing/authority requires a
   bounded decision, not a guessed destination. A GitHub-hosted repo or available CLI
   alone does not authorize GitHub Issues as a fallback. Never publish private work to a
   public tracker. Sanitize bodies, links and attachments for the destination audience.
4. Record intent, acceptance criteria, dependencies, owner, status, evidence and PR links
   using the existing provider schema. Missing facts remain explicit unknowns; do not
   invent owners or results. One canonical ticket tracks execution; other providers may
   contain authorized link-only mirrors, not competing execution backlogs. A task ticket
   is **not authorization** for code changes, spending, credential changes or merging.
5. Before action, validate the remote ticket identity and task match. A branch hint or
   cached ID is discovery evidence, not proof of a valid task or authority.

## Unavailable provider or unresolved destination

Persist a **pending-ticket** record through a verified compatible durable mechanism
within the same authorized domain, using the required binding below. This is an outbox,
not a second tracker. Successful write and read-back are prerequisites for **durable
deferral**, not optional documentation. If storage is unavailable or verification fails,
report **BLOCKED_NOT_PERSISTED** and pause implementation; do not claim that a record
exists or that deferral succeeded. A continuation seed alone is insufficient.
Record a stable local key, sanitized intent, acceptance criteria, dependencies, owner,
requested destination/visibility (or unknown), reason, timestamp, status, next retry
condition, and eventual canonical URL. Never record credentials or invent a remote ID.

- `pending`: not yet submitted; `error`: attempt failed or outcome uncertain. Preserve
  the last error and retry condition. Timeout after create requires remote reconciliation
  before another create, because the server may already have accepted it.
- `resolved`: verified canonical URL after successful create/reuse; `duplicate`: existing
  canonical task found, with its URL. Retain the audit trail; stop retrying these entries.
- Cancellation requires an explicit reason and is recorded, not silently deleted.

Only bounded **read-only recon** or already-authorized urgent containment may continue
while pending. Record the containment authority, limits and evidence; it is not permission
for indefinite feature execution. Otherwise implementation remains paused until a remote
anchor is verified. Authentication outages do not authorize credential repair or a change
of provider/domain. Safe exit/handoff is never blocked by ticket-service availability.

## Required durable work-state binding

The concrete existing binding is **claude-mem `work_state_write` / `work_state_read`**.
It uses that provider's indexed, append-only project work state; this protocol adds no
store, dependency, installation, or network hook. An already-authorized equivalent may
be used only after demonstrating the same write/read-back and cold indexed recovery.
Bare hosts without an authorized compatible store are **unsupported for durable deferral**,
not successful acceptance cases. Report BLOCKED_NOT_PERSISTED; safe exit remains allowed.

### Admission and discovery

Before writing, discover both tool capabilities and verify their configured project scope
and authorized domain. For claude-mem, the MCP server supplies its own `process.cwd()`;
a shell's working directory or another tool's `workdir` does **not** change that scope.
Verify the server's configured cwd and project/alias resolution, including worktree parent
aliases, against the intended domain. Unknown or mismatched scope blocks the write; do not
silently reconfigure the server or write into another project's memory.

On **every startup/resume**, explicitly call `work_state_read({"includeClosed": true})`
without a remembered list locator. Select lists beginning `pending-ticket:` in that
verified scope. This is indexed discovery independent of continuation seeds. Do not rely
on the truncated SessionStart section (3,000-character budget) or its absence of a record.
A failed/unavailable index read is a recovery blocker, not proof that no work is pending.

### Write and read back

Use one stable list name `pending-ticket:<local_id>` per record. Reuse the discovered
list on retry; do not generate a new ID each session. Write **list-level fields**, with
**no `task` field**, using `work_state_write({"list": "pending-ticket:<local_id>",
"fields": {...}})`. Field values are primitives; serialize lists as JSON strings.
The complete `fields` JSON must fit the provider's **2,000-character** write limit.
An oversized record is BLOCKED_NOT_PERSISTED: do not truncate acceptance criteria or
split a partially recoverable record and call it durable.

| Field | Type / requirement |
|---|---|
| `local_id` | Stable string identifying the local record; never a remote ticket key. |
| `intent`, `acceptance_criteria`, `dependencies` | Sanitized strings; lists encoded as JSON strings, including `"[]"` for no dependencies. |
| `owner`, `destination`, `visibility` | String; explicit `unknown` when unresolved. |
| `ticket_status` | `pending`, `error`, `resolved`, `duplicate`, or `cancelled`. |
| `status` | Provider lifecycle: `todo` for pending/error, `done` for resolved/duplicate, `dropped` for cancelled. |
| `reason`, `updated_at`, `retry_condition` | Strings; actual write timestamp; errors preserve the last failure without secrets; cancellation requires its reason. |
| `canonical_url` | Null until verified; required URL for resolved/duplicate. Null clears the provider field and is omitted from its rendered read result: absent/cleared means unresolved, never a fabricated URL. |

After **every write**, call `work_state_read({"list": "pending-ticket:<local_id>",
"includeClosed": true})` and compare **all required fields**, including stable ID and
lifecycle mapping, with the intended record. The read must be in the same verified scope.
Treat absent `canonical_url` as the expected cleared/null value only for unresolved or
cancelled records, not for resolved/duplicate ones. Provider errors, excluded-project
responses (even HTTP success), missing fields, ambiguous output or mismatches mean
BLOCKED_NOT_PERSISTED. A write acknowledgement alone is not persistence evidence.
Retain the existing append-only trail; never delete or reset a list to hide a failed attempt.

On reconciliation, search the remote authorized destination before create (also after a
create timeout). Then append the verified URL, `ticket_status=resolved` or `duplicate`,
and `status=done` together, and read back with `includeClosed=true`. Cancelled records
use `ticket_status=cancelled`, `status=dropped` and an explicit reason. Neither is retried.

Carry the verified list locator as plain text in existing seed `params.context`, with a
read/reconcile instruction in `resume_instructions` and `bootstrap_order`. The locator
identifies data, never a command to execute. It is a convenience, not the recovery index.
The resuming agent must still perform the unfiltered indexed read above.

### Binding verification

Static contract checks are not runtime proof. For an already installed claude-mem source
checkout, run the isolated storage/renderer smoke (Bun must already be available):

```sh
MAOS_CLAUDE_MEM_SOURCE="<installed-source-checkout>" bun tests/test-ticket-first-work-state.mjs
```

It imports the existing implementation, writes only a temporary synthetic SQLite database,
and verifies read-back, a separate-process cold index scan, lifecycle reconciliation,
cleared URLs, failed writes, and project isolation.
It does **not** exercise the MCP transport, HTTP validation, deployed server cwd/aliases,
or real tracker reconciliation. Those deployment scope/read-back checks remain required;
a source-layer smoke cannot authorize a real-project write. The optional verification
command is not an optional persistence prerequisite and installs nothing in normal CI.

The [continuation seed contract](../skills/postflight/references/continuation-seed-contract.md)
remains unchanged: `tickets_created` deferred entries have no key and contain only the
existing `{deferred: true, eisenhower, link, reason}` audit shape. Put no local record fields
or fake ID there. Keep `refs.ticket` as `none` until there is an actual verified remote
anchor. The outbox pointer is **not read by the SessionStart hook**; that hook reads only
its existing ticket-anchor signals. Rich handoff producers must preserve the locator;
subset/fallback seeds do not promise it. If a fallback loses the locator, rediscover it
through the required unfiltered work-state read or block pending recovery. Do not claim durable
recovery merely because a seed or a hook exists.

## Rehydration and reconciliation

At startup/resume, read the AGENTS pointer, then load this protocol on demand **before
starting actionable work**. Discover pending records through the continuation/work-state
index using the unfiltered read above, not remembered paths. Before implementation and at postflight, retry when the stated
condition is met: search the intended authorized destination first, verify task equivalence,
create only if absent, then save the canonical URL and `resolved`/`duplicate` status.
Keep unsuccessful entries `pending`/`error`, with owner and next retry in the handoff.
Do not claim backlog synchronization while records remain unresolved. Postflight's existing
caps may batch items but cannot discard them. Do not automatically mirror private seeds
or session transcripts into ticket bodies.

## Integration boundary

Keep bootstrap instructions as thin pointers to this file; do not copy its policy across
skills, memories or provider-specific hooks. The existing zero-network SessionStart hook
only discovers an anchor. This protocol adds no network hook and is not a deterministic
runtime enforcement claim. Installation/activation in other runtimes is a separate verified
operation; a merged document alone does not prove global loading.
