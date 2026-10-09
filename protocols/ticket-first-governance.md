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
within the same authorized domain, using the optional adapter below. This is an outbox,
not a second tracker. If no compatible durable mechanism is available, pause
implementation and report that exact gap; a continuation seed alone is insufficient.
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

## Optional durable work-state adapter (documentation-only)

This is a **documentation-only adapter** contract, not an installed storage implementation.
Use an existing authorized durable work-state tool only after verifying that it can write,
read back, and recover indexed records after resume. Do not assume a particular tool or
create a new network hook. Its opaque locator identifies data, never a command to execute.

Minimum record contract (field names may map to the existing tool's schema):

| Field | Type / requirement |
|---|---|
| `local_id` | Stable string identifying the local record; never a remote ticket key. |
| `intent`, `acceptance_criteria`, `dependencies` | Sanitized string or list; dependencies explicitly empty if none. |
| `owner`, `destination`, `visibility` | String; explicit `unknown` when unresolved. |
| `status` | `pending`, `error`, `resolved`, `duplicate`, or `cancelled`. |
| `reason`, `updated_at`, `retry_condition` | Strings; timestamp records the actual write; errors include last failure without secrets. |
| `canonical_url` | Null until verified; required URL for `resolved` or `duplicate`. |

Write the record using the existing tool, then **read back** by its opaque locator and
verify required fields before reporting persistence. Carry that locator as plain text in
existing seed `params.context`, with a read/reconcile instruction in `resume_instructions`
and `bootstrap_order`. Example context: `Pending-ticket outbox: <opaque locator>; load via
<configured work-state reader> within the current authorized domain before implementation.`
The resuming agent must resolve and read it; missing access or a failed read is an explicit
implementation blocker, not evidence that no pending work exists.

The [continuation seed contract](../skills/postflight/references/continuation-seed-contract.md)
remains unchanged: `tickets_created` deferred entries have no key and contain only the
existing `{deferred: true, eisenhower, link, reason}` audit shape. Put no local record fields
or fake ID there. Keep `refs.ticket` as `none` until there is an actual verified remote
anchor. The outbox pointer is **not read by the SessionStart hook**; that hook reads only
its existing ticket-anchor signals. Rich handoff producers must preserve the locator;
subset/fallback seeds do not promise it. If a fallback loses the locator, rediscover it
through the configured work-state index or block pending recovery. Do not claim durable
recovery merely because a seed or a hook exists.

## Rehydration and reconciliation

At startup/resume, read the AGENTS pointer, then load this protocol on demand **before
starting actionable work**. Discover pending records through the continuation/work-state
index, not remembered paths. Before implementation and at postflight, retry when the stated
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
