---
name: wacli-concierge
version: "0.1.0"
description: |
  Concierge / operator / verifier for **wacli** — the single-binary WhatsApp CLI that pairs as a
  linked WhatsApp Web device and mirrors history into local SQLite (FTS5). Use to pair or re-pair
  an account (QR **or** phone-code), run multi-account setups (`--account`), read/search a synced
  store, drive a bounded background sync, diagnose `doctor` output honestly, or interpret degraded
  app-state (LTHash) and store-lock states. Owns the operational layer the upstream `wacli` skill
  omits: named accounts, `--store` hazards, lock/delegation semantics, storage caps, and
  count-vs-listable truth. Complements — never replaces — the upstream messaging-safety skill.
  Never invents flags; capability-detects and verifies by state, never by log text.
  Modes: explain · pair · operate · diagnose · audit.
allowed-tools: Read, Glob, Grep, Bash
---

# Skill: wacli-concierge — Concierge over the wacli WhatsApp CLI

> **Domain**: `wacli` (WhatsApp Web linked-device CLI, Go + whatsmeow) · **Lens**: Tomé (verify, don't assume) · Operational · Critical
> **Named by**: Anima (`[C-naming]`) · family `*-concierge` (maos · 9router · claude-code · omniroute · opendesign · walkthrough)
> **Upstream truth**: <https://wacli.sh> (27 doc pages) · repo `github.com/openclaw/wacli` · `CHANGELOG.md`
> **Boundary**: complements the upstream `openclaw/openclaw@wacli` skill (messaging-safety + command map). This one carries the **multi-account operational layer**. Not the WhatsApp Business Cloud API (that is Meta's official API — a different tool entirely).

## §0 — BEING > Rules

Serves the operator's intent. If an *optional ceremony* step (phase ordering, formatting, non-safety documentation) blocks delivering value NOW, skip it, log `Skipped <phase> — BEING > Rules`, proceed.

**The escape clause does NOT reach these — they are never skippable:** the HUMAN_DOMAIN consent gates below · the secret/PII discipline · destructive-action confirmation (`--dry-run` before `--confirm`) · the verification rules (state-based proof, never log-text). A gate that exists to prevent harm or to stop a false claim is not ceremony. Reading a synced store is **not** HUMAN_DOMAIN.

**HUMAN_DOMAIN — escalate, never auto-act.** Two classes:

*Remote WhatsApp mutations / outward-facing signals* (a third party or WhatsApp's servers observe it):
`send text|file|sticker|voice|location|poll|status|react|select` · `poll vote` · `messages forward|edit|delete|revoke` · `presence typing|paused` · chat-state patches (`chats archive|unarchive|pin|unpin|mute|unmute|mark-read|mark-unread`) · `profile set-picture|remove-picture|set-about|set-name` · groups (`create|rename|topic|description|announce-only|locked|join|leave`, `participants add|remove|promote|demote`, `requests approve|reject`, `invite link get|revoke`) · `channels join|leave` · `contacts check` (asks WhatsApp about third-party numbers) · `auth logout` · pairing a number the operator did not name.

*Destructive local-only mutations* (WhatsApp untouched; your mirror is not): `store cleanup` · `chats cleanup` · `groups prune` · `messages purge` · `contacts import-system --clear`. Always `--dry-run` first; `--confirm` only after the operator reviewed the target list.

## Requirements (runtime probes)

| Tool | Used for |
|---|---|
| `wacli` | everything (single binary; no daemon, no plugin host) |
| `bash` | Phase 0 probes only |
| `brew` | install/upgrade path verification (optional) |
| `sqlite3` | read-only companion queries against `wacli.db` (optional) |

## Phase 0 — Capability detection (always first)

| Probe | How | If absent / wrong |
|---|---|---|
| Binary | `command -v wacli && wacli --version` | not installed → `brew install openclaw/tap/wacli` |
| Tap provenance | `brew list --formula --versions wacli`; receipt `tap` field | a `steipete/*` tap is **legacy**; Homebrew now distrusts it — canonical is `openclaw/tap` |
| Accounts | `wacli accounts list` | `No accounts configured` → single-store mode (`~/.wacli`) |
| Per-account state | `wacli --account <name> doctor` | see § Reading `doctor` honestly |
| Auth identity | `wacli --account <name> auth status` | `Authenticated as <jid>` = paired |
| Live link (optional) | `wacli --account <name> doctor --connect` | needs auth **and** the store lock |

```bash
# Store layout (per account)
#   <base>/config.yaml                 default_account + accounts.<name>.store
#   <base>/accounts/<name>/session.db   whatsmeow: device identity + keys   ← NEVER touch
#   <base>/accounts/<name>/wacli.db     wacli: chats/messages/FTS + state   ← NEVER write externally
#   <base>/accounts/<name>/{media/,LOCK,HEARTBEAT}
# <base> = ~/.wacli (macOS/Windows) | ~/.local/state/wacli (Linux XDG; legacy ~/.wacli reused)
# Permissions are owner-only by design: dir 0700, files 0600. Do not relax them.
```

**Secret + PII discipline (binding):** treat JIDs, phone numbers, display names, message text, media filenames and local media paths as sensitive (upstream `integrations.md` § Privacy). Never echo message bodies or contact lists into a shared surface (PR, ticket, chat log). Never copy `session.db`, media keys, or device keys anywhere. Report **counts and states**, not content, unless the operator asks for content.

## Landscape Decision Matrix

| Intent | Do |
|---|---|
| Pair a new number | `wacli accounts add <name>` (isolated store + auth + bootstrap). Prefer `--phone "+E164"` when QR fails |
| QR won't scan | `--phone` (8-char code path) **or** `--qr-format text` for an external renderer. Never relay ASCII QR through a chat transport |
| Two+ numbers | one named account each; `--account <name>` on every command; locks are independent |
| Keep a store warm | `wacli --account <n> sync --follow --max-db-size 2GB` (see § Bounded storage) |
| One-shot catch-up | `sync --once` (exits after `--idle-exit`, default 30s) |
| Metadata missing (names/groups) | `sync --once --refresh-contacts --refresh-groups --refresh-channels` — a **different path** than the failing app-state patches |
| Read while a follow sync runs | reads work; for media use `--read-only media download --output PATH` (takes **no lock**) |
| Send while a follow sync runs | just send — sends are **delegated** to the running follow process (no second session) |
| Older history for one chat | `history coverage` → `history fill --dry-run` → `history backfill --chat <jid>` (phone must be online) |
| "Did pairing work?" | `doctor` → `AUTHENTICATED true` + `auth status`. **Never** infer from log text |
| Search finds nothing | check § Count ≠ listable before assuming breakage |
| Is there a wacli MCP? | No. Upstream out-of-scope is explicit: "a daemon, MCP server, web UI, or GUI" |

## Named accounts (the layer upstream's skill omits)

```bash
wacli accounts add NAME [--no-auth]   # create isolated store, then auth+bootstrap
wacli accounts list | show NAME | use NAME | remove NAME
wacli --account NAME <any-command>
```

**Store-selection precedence (explicit, 5 steps):** `--store DIR` (exact; **cannot** combine with `--account`) → `--account NAME` (from `config.yaml`) → `WACLI_STORE_DIR` → `default_account` → single-store default. Account names: letters, digits, `.`, `_`, `-`; must start with a letter or digit. `accounts remove` drops the config entry, not the store dir.

## ⚠️ `--store` is a hazard, not a convenience

Upstream documents `--store DIR` as a one-off migration/debugging escape hatch. It is **not** read-only and it is **not** inert:

- Pointing `--store` at a directory belonging to **another tool** makes wacli initialize/migrate its own schema *there* — `doctor --store <foreign-dir>` created `session.db` + `LOCK` and **mutated a pre-existing `wacli.db` (102400 → 221184 bytes) with no restorable backup** (empirical, 2026-09-10, against a live Baileys credential dir of a different WhatsApp stack).
- Companion rule from upstream: never read/write `session.db`; **never write `wacli.db` from outside wacli**; do not merge account data.

**Rule:** use `--account` for anything routine. Reach for `--store` only against a store you own, and never against another program's state directory. "Just looking" is not a thing — the command migrates.

## Reading `doctor` honestly

| Field | Means | Does **not** mean |
|---|---|---|
| `AUTHENTICATED true` | the local store holds a valid linked-device session | that a live socket is open |
| `CONNECTED false` | doctor did not connect (it never does without `--connect`) | pairing failed |
| `CONNECTION_STATE locked_by_other_process` | another wacli process (usually `sync --follow`) holds the store lock | breakage; reads still work |
| `LOCKED true` + `LOCK_OWNER_PID` | that PID owns the write lock | a stale lock (check the PID is alive first) |
| `MESSAGES <n>` | rows in the `messages` table | how many are listable/searchable (see below) |
| `LAST_SYNC` | newest stored message timestamp | process liveness (that's `HEARTBEAT` / `--json store.last_activity_at`) |

**Verification rule (binding):** prove pairing/sync state from `doctor` / `auth status` **state fields**, never from stdout text. The QR prompt literally contains the words *"Linked Devices"*, so a log-text match on `/Linked/` is a guaranteed false positive.

## Count ≠ listable

`doctor`'s `MESSAGES` counts rows in the `messages` table. Some of those rows are deliberately not returned by `messages list/search/export`:

- **tombstones** (revoked / delete-for-me) are the one documented counted-but-hidden class: they live in `messages` with `deleted_at` set, stay hidden from list/search/starred/export **and FTS**, and remain visible only to a direct `messages show`.
- **FTS indexes content only** (body text, media caption, document filename), so rows stored *without* extractable content cannot match a `messages search` — a store dominated by contentless rows searches as empty.
- **`stored message … without content: unhandled payload <type>`** rows are an *intentional bounded diagnostic* since v0.17.0, not a failure. Common shapes: `protocolMessage`, `placeholderMessage`, `associatedChildMessage`, `richResponseMessage`, `groupInviteMessage`. Upstream does **not** document them as excluded from `messages list` — do not assume they are.

Separately: **status broadcasts** live in their own `status_messages` table and are excluded from `messages list/search/export`. Because they are a *separate table*, they are **not** part of `doctor`'s `MESSAGES` count either — so they cannot explain a gap between that count and list output.

**Unresolved:** an observed "`doctor` reports N messages but an unscoped `messages list` returns 0" gap is **not** fully explained by the above. Diagnose with a scoped `messages list --chat <jid>`, `store stats`, and a raw-envelope comparison on an idle store before attributing a cause.

## Locks, delegation, concurrency

- Write commands acquire the store lock. `sync --follow` holds it **for its entire run**; `--lock-wait` only turns an immediate failure into a timeout.
- **Sends are delegated:** while a follow sync runs, `send text|file|sticker|voice|react` and `messages edit` for the same store are handed to that process instead of opening a second WhatsApp session. Do not stop the sync to send.
- `--read-only` / `WACLI_READONLY=1` rejects anything that writes WhatsApp or local state; `--read-only media download --output PATH` explicitly takes **no lock** (upstream's documented way to fetch media during a follow).
- Locks are **per account store** — `--account a sync --follow` and `--account b chats list` never block each other.
- Never run two auth/sync processes against the **same** store: single-instance safety exists because concurrent sessions cause disconnects / "device replaced" behavior.

## Bounded storage (upstream warns twice; heed it)

`sync` prints one warning when storage is uncapped. Cap it:

```bash
wacli --account <n> sync --follow --max-messages 250000 --max-db-size 2GB
# env equivalents also bound the auth bootstrap sync:
export WACLI_SYNC_MAX_MESSAGES=250000 WACLI_SYNC_MAX_DB_SIZE=2GB
```

Media upload/download is capped at 100 MiB. Local pruning (never touches WhatsApp servers): `store cleanup`, `chats cleanup`, `groups prune` — all `--dry-run` first, `--confirm` only after reviewing.

## Degraded app-state (LTHash) — expected, bounded, non-fatal

Symptoms during pairing/sync:

```text
failed to sync WhatsApp app state regular_high|regular_low|regular
  … mismatching LTHash | didn't find app state key <id> | websocket not connected
failed to send available presence: can't send presence without PushName set
```

Upstream behavior: on an LTHash mismatch sync asks the primary device for the official recovery snapshot **once per collection**; if recovery also fails it prints the warning and **keeps handling normal message/history events**. App-state carries *metadata* (starred, mute/archive/pin, mark-read, push name) — its failure does not stop history import.

**Workaround for the metadata gap:** the `--refresh-*` flags fetch by a different path. Empirically took a store from 45 → 458 contacts while app-state was still failing.

## Open question (do NOT present as fact)

`wacli --read-only --json chats list` returned **0** records while the identical command **without** `--read-only` returned 221, during an active bootstrap sync on a locked store. Upstream documents `--read-only` as the agent/sandbox mode that blocks writes and takes no lock, and shows `--read-only messages search` as a supported example — so this is **unexplained**, not a diagnosed footgun. Reproduce in a controlled state (idle store, no concurrent sync, compare raw JSON envelopes) before drawing any conclusion.

## Anti-patterns (all empirically observed)

1. ❌ **Relaying an ASCII QR through a chat/agent transport.** Whitespace-run fidelity is not guaranteed end-to-end and WhatsApp rotates the code every ~20-30s. Two consecutive attempts failed with "não é possível se conectar". Hand the operator the **command** to run in their own terminal, or use `--phone`.
2. ❌ **Claiming pairing succeeded from log text.** `/Linked/` matches the static "Linked Devices" prompt. Assert only from `AUTHENTICATED true`.
3. ❌ **Reading `CONNECTED false` as failure.** `doctor` never connects without `--connect`.
4. ❌ **Treating `locked_by_other_process` as an error.** It is the expected state while a follow sync runs.
5. ❌ **Pointing `--store` at another tool's directory** (see the hazard section — real, unrecoverable mutation).
6. ❌ **Equating `doctor`'s MESSAGES with listable rows.**
7. ❌ **Trusting a `steipete/*` tap or repo reference.** Canonical: `openclaw/tap` · `github.com/openclaw/wacli`. Stale skill metadata still points at the legacy path.
8. ❌ **Hunting for a wacli MCP server.** Explicit upstream non-goal.
9. ❌ **Running an unbounded sync** on a personal number with years of history.
10. ❌ **Echoing message content, contact lists, or phone numbers** into shared surfaces.

## Invocation surface (declared)

Ships **skill-only, model-auto-triggered** by design — matching the SSOT `*-concierge` family, none of which ships a `commands/` wrapper (thin wrappers were removed house-wide). It is therefore reachable by description match / `plugin:name`, **not** as a typed `/wacli-concierge`. If a human slash entry is ever wanted, add `commands/<name>.md` in the same deliverable — a skill is never `/`-reachable by existing.

## §Quality Tests (6/6 self-validity)

1. **Self-Application** — every claim traces to an upstream doc page, the CHANGELOG, or a dated empirical observation; the one unexplained behavior is filed as an open question, not a finding. ✅
2. **Non-Contradiction** — complements the upstream `wacli` skill (messaging safety + command map) instead of restating it; defers Business Cloud API to Meta's own tooling; defers OpenClaw channel routing to OpenClaw. ✅
3. **Survival** — applied to itself it demands state-based verification and honest open questions; it does both. ✅
4. **Bounded-Responsibility** — read-first; HUMAN_DOMAIN list gates every outward/irreversible action; storage caps recommended; no reimplementation of wacli. ✅
5. **Explicit-Exception** — §0 BEING > Rules + the HUMAN_DOMAIN carve-outs + the declared invocation surface. ✅
6. **Utility-Sunset** — §DUED. ✅

## §DUED Sunset (qualitative)

Deprecate when ANY: upstream's own `wacli` skill absorbs the multi-account/lock/hazard layer (E1) · wacli ships a native MCP or daemon making CLI-shape guidance moot (E1) · operator retraction (E4) · ≥3 false-positive diagnoses traced to this skill (E5). Dormant-by-design otherwise.

## §Refs

- Upstream docs (all 27 pages read 2026-09-10): <https://wacli.sh> — `overview` · `accounts` · `auth` · `sync` · `history` · `doctor` · `messages` · `send` · `store` · `integrations` · `chats` · `contacts` · `contacts-import-system` · `groups` · `channels` · `media` · `calls` · `presence` · `profile` · `spec` · `install` · `quickstart` · `release` · `docs` · `version` · `completion` · `help`.
- `github.com/openclaw/wacli` `CHANGELOG.md` — v0.17.0 (unhandled-payload diagnostics) · v0.17.2 (`--read-only` media bypasses the follow lock) · v0.18.0 (`groups participants list`, `send --allow-self`) · v0.18.1 (waveform cap).
- Built on `github.com/tulir/whatsmeow`. Third-party; **not affiliated with WhatsApp or Meta**; linked-device pairing is subject to WhatsApp's terms.
- Complementary skill: `openclaw/openclaw@wacli` (upstream, messaging-safety scope).
- Family: `maos-concierge` · `9router-concierge` · `claude-code-concierge` · `omniroute-concierge` · `opendesign-concierge` · `walkthrough-concierge`.
- Cross-link slug: `[[wacli-concierge]]`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-09-10 | Bootstrap. Forged via `agentic-tool-forge` (type=skill, coverage of upstream skill measured at 2/10 leaves ≈ 20% < 50% ⇒ forge-new, not extend); named by `anima` (`wacli-concierge`; runner-up `wacli-ops` rejected as low-signal; bare `wacli` slug already taken upstream + 2 local installs). Grounded in all 27 wacli.sh doc pages + CHANGELOG + a same-day operational session that produced the `--store` mutation incident, the QR-relay failures, the log-text false positive, and the app-state/LTHash degradation with the `--refresh-*` workaround. |
