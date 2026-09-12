# wacli operational reference

Loaded on demand by `wacli-concierge`. Current upstream truth: <https://wacli.sh> and
<https://github.com/openclaw/wacli>.

## Store layout and access

Per named account, the base contains `session.db` (device identity and keys), `wacli.db`
(chats/messages/FTS/state), `media/`, `LOCK`, and `HEARTBEAT`. Defaults: `~/.wacli` on macOS and
Windows; XDG state on Linux, with an existing Linux `~/.wacli` retained. Directories are owner-only
`0700`; files are `0600`.

- Never read, copy, merge, or write `session.db` outside wacli.
- Never write `wacli.db` outside wacli.
- Any exceptional companion SQLite query opens `wacli.db` with `sqlite3 --readonly` or a
  `file:...?mode=ro` URI, after capability-detecting that form. Prefer wacli's own JSON commands.
- `--store DIR` is a migration/debug escape hatch, not an inspection mode. It may initialize or
  migrate schema in the target. Existing directory requires verified target, restorable backup,
  and explicit approval; a foreign tool's state directory is prohibited.

## Account commands

```bash
wacli accounts add NAME
wacli accounts add NAME --no-auth
wacli accounts list
wacli accounts show NAME
wacli accounts use NAME
wacli accounts remove NAME
wacli --account NAME COMMAND
```

`--no-auth` creates the account entry and isolated store without pairing or bootstrap. Removing an
account removes its config entry, not its store directory. Names use letters, digits, `.`, `_`, and
`-`, beginning with a letter or digit.

## Pairing

Use `accounts add NAME` for named-account bootstrap. QR is time-sensitive and whitespace-sensitive;
do not relay terminal ASCII QR through chat. If QR transport fails, use `--phone "+E164"`; the
operator enters the resulting eight-character code in WhatsApp Linked Devices. Pairing success is:

1. `wacli --account NAME doctor` reports `AUTHENTICATED true`;
2. `wacli --account NAME auth status` identifies an authenticated linked session.

A bootstrap process owns the store lock while importing. During that interval, local reads may work,
but `locked_by_other_process` is expected and is not proof of failure or live connectivity.

## Doctor semantics

| Field | Means | Does not mean |
|---|---|---|
| `AUTHENTICATED true` | local store has linked-device credentials | a socket is currently connected |
| local `CONNECTED false` | default doctor made no live attempt | pairing failed |
| `--connect` + `CONNECTED false` | live probe did not connect | credentials are necessarily invalid |
| `LOCKED true` + owner PID | another process holds the write lock | the lock is stale; test process liveness first |
| `CONNECTION_STATE locked_by_other_process` | normally a follow-sync owns the lock | reads are broken |
| `MESSAGES N` | rows in the `messages` table | N listable or searchable messages |
| `LAST_SYNC` | newest stored message timestamp | follow process liveness |

`doctor --connect` requires authentication and the store lock. While follow-sync holds it, use
`HEARTBEAT` / JSON `store.last_activity_at` for activity rather than stopping the sync solely to run
a live probe.

## Count versus listable/searchable

- Revoked/delete-for-me tombstones remain rows in `messages` with `deleted_at`; list, search,
  starred, export, and FTS hide them, while direct message lookup can still address them.
- FTS indexes extractable content: body text, media caption, and document filename. Contentless rows
  cannot match a content query.
- `stored message ... without content: unhandled payload` is a bounded diagnostic since v0.17.0.
  Typical payloads include protocol, placeholder, associated-child, rich-response, and group-invite
  shapes. Upstream does not state that these rows are absent from `messages list`; do not infer it.
- Status broadcasts use `status_messages`, a separate table. They are excluded from ordinary
  message list/search/export and are not part of doctor's `MESSAGES` count.

Unresolved observation: during an active locked bootstrap, `--read-only --json chats list` returned
zero while the same command without `--read-only` returned rows. Reproduce on an idle store and
compare raw envelopes before assigning a cause. Likewise, a nonzero doctor count with an empty
unscoped message list is not fully explained by the documented exclusions; narrow by chat and
inspect `store stats` first.

## Locks and delegation

`sync --follow` holds the account-store write lock for its lifetime. Locks are per account. Do not
run two authentication or sync sessions against the same store.

While follow-sync owns a store, wacli delegates only these approved mutations to it instead of
opening a second session: `send text`, `send file`, `send sticker`, `send voice`, `send react`, and
`messages edit`. Delegation is an implementation detail; exact human consent is still required.

`--read-only` / `WACLI_READONLY=1` rejects commands intentionally writing WhatsApp or local state.
`--read-only media download --output PATH` is the documented no-lock media path. An observed
read-only discrepancy remains unresolved, so compare state rather than assuming semantic parity.

## Bounded synchronization

Use both message-count and database-size caps for long-running personal mirrors:

```bash
wacli --account NAME sync --follow --max-messages 250000 --max-db-size 2GB
```

The environment equivalents `WACLI_SYNC_MAX_MESSAGES` and `WACLI_SYNC_MAX_DB_SIZE` also bound auth
bootstrap. `sync --once` exits after its idle window. Media transfer is capped upstream at 100 MiB.
Cleanup/prune/purge is local-destructive: dry-run, review exact targets, approve, confirm, verify.

## Degraded app-state

Warnings such as mismatching LTHash, missing app-state key, websocket-not-connected, or missing
PushName concern metadata collections. On mismatch, wacli asks the primary device for one recovery
snapshot per collection; if recovery fails it continues processing ordinary message/history events.

App-state carries metadata such as starred, mute/archive/pin, mark-read, and push-name state. The
refresh flags fetch contacts/groups/channels by a different path:

```bash
wacli --account NAME sync --once --refresh-contacts --refresh-groups --refresh-channels
```

Treat history import and metadata completeness as separate health axes.

## Mutation map

Every item below uses the delegate's classified-operation contract:

- remote: all `send` variants; poll vote; message forward/edit/delete/revoke; presence typing/paused;
  chat archive/unarchive/pin/unpin/mute/unmute/mark-read/mark-unread; profile picture/about/name;
  group create/rename/topic/description/announce/lock/join/leave, participant role changes, join
  requests, invite revocation; channel join/leave; `contacts check`;
- local destructive: store/chat cleanup, group prune, message purge, contact import with clear;
- interactive/high-risk: delegate coordinates pairing/account-add with the operator and verifies
  state afterward; logout uses the approval gate.

The approval must name one account, one action, exact targets, exact payload or payload digest, and
one non-retried attempt. Changing any field invalidates it. The agent contract does not provide a
durable nonce ledger, so the parent must reconcile ambiguous outcomes and prevent cross-invocation
replay.

## Sources

- wacli docs: `overview`, `accounts`, `auth`, `sync`, `history`, `doctor`, `messages`, `send`,
  `store`, `integrations`, `chats`, `contacts`, `contacts-import-system`, `groups`, `channels`,
  `media`, `calls`, `presence`, `profile`, `spec`, `install`, `quickstart`, `release`, `docs`,
  `version`, `completion`, `help`.
- upstream changelog: v0.17.0 unhandled-payload diagnostics; v0.17.2 no-lock read-only media;
  v0.18.0 participant listing and self-send guard; v0.18.1 waveform cap.
- wacli uses `github.com/tulir/whatsmeow`; it is third-party and not affiliated with Meta.
