# harness-mcp-sync — failure-class threat model (PDCA round 11)

Scope: `bin/harness-mcp-sync`. This round fixes **classes of failure**, not single findings.
Each class lists every instance found by auditing the executor, with the regression
test that pins it (`bin/tests/harness-mcp-sync.test.sh`, block "PDCA round 11").
Negative control: the new block fails 22 assertions against `8bd0c74` and passes on
this head.

## C-A — git environment trust

**Threat.** The git-safety gate decides whether a secret may be written to a config
file (a tracked or untracked file inside a git work tree is refused). The executor runs
`git` as a subprocess, so every inherited `GIT_*` variable and every global/system config
file can move the probe to another repository, another index or another work tree. The
gate then answers "not in a repo" for a file that *is* tracked, and a secret lands in
version control. Source: CodeRabbit Major 4107215664.

| Instance | Fix | Test |
|---|---|---|
| `_git()` (ls-files / check-ignore probes used by build_plan, doctor, verify) | `env=_git_env()`: drop every `GIT_*` variable, set `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null` | C-A unit, 9 variables |
| `rev-parse --is-inside-work-tree` | same env | C-A unit |
| end-to-end apply of a secret server under `GIT_DIR=<bogus>` | refused, file untouched, non-zero exit | C-A e2e |

Covered variables: `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY`,
`GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_COMMON_DIR`, `GIT_CEILING_DIRECTORIES`,
`GIT_CONFIG_COUNT/KEY_n/VALUE_n`, `GIT_CONFIG_GLOBAL`. The scrub is by prefix, so a
variable git adds later is also dropped. `core.fsmonitor=false`, `core.hooksPath=/dev/null`
and `stdin=DEVNULL` (earlier rounds) remain.

**Stated trade-off.** Ignoring the global config also ignores a global
`core.excludesFile`. A file ignored only by the operator's global excludes is therefore
classified `untracked`, and a secret write to it is refused. This is stricter, not looser
(fail-closed). Any git error still maps to `unknown`, which also refuses secrets.

## C-B — multi-harness atomicity

**Threat.** `apply` and `restore` loop over harnesses. If the manifest is persisted only
once after the loop, a failure in the middle leaves configs already written (or restored)
while the manifest still describes the old state. The next run then either adopts
foreign entries or deletes owned ones. Source: Codex P1 4107275318; apply audited for
the same shape.

| Instance | Fix | Test |
|---|---|---|
| restore: manifest reconciled after the loop | reconcile and `save_manifest` per restored harness | C-B restore (later payload missing) |
| restore: exception from one harness aborts the rest | per-harness try; failure is reported as `refused … file left unchanged`, exit non-zero | C-B restore |
| apply: `save_manifest` fails after the config write | the write is rolled back from the backup, the manifest entry is reverted, the error re-raised | C-B apply (fault-injected) |

## C-C — config shape strictness

**Threat.** A managed path (`key_path`) whose value is an explicit `null`, a list or a
scalar was treated as "absent" and overwritten with a fresh mapping. That silently
destroys user data of an unexpected shape. Source: Codex P2 4107275343.

| Instance | Fix | Test |
|---|---|---|
| JSON `"mcpServers": null` | `map_shape_error` flags any non-mapping at any level → malformed, untouched | C-C hnj |
| YAML `extensions: null` | same | C-C hny |
| nested path, first level `null` | same (checked per level) | C-C hn2 |
| verify | reuses `map_shape_error` | covered by the same helper |

## C-D — transport alias normalization

**Threat.** The SSOT may spell a remote transport `http` while an adapter declares only
`streamable-http` (or the reverse). The adapter lookup then misses and renders a spelling
the harness does not accept, or apply and verify disagree. Source: Codex P2 4107275325.

| Instance | Fix | Test |
|---|---|---|
| `render_entry` (all styles; used by apply and verify) | `canonical_transport()`: if the transport is `http`/`streamable-http` and not declared, use the declared alias | C-D htsh, hthp |
| both declared | unchanged | C-D htbo ×2 |
| verify agrees with apply | same function | C-D verify assertions |

## Out of scope (not changed this round)

Registry authorship (trusted, reviewed data), the operator's own shell, and a local
attacker with write access to `$HOME` are outside this model, as in earlier rounds.

---

# Round 12 — redesign: write-ahead intent journal (config + manifest atomicity)

**Why a redesign.** Round 11 left six findings. Four of them (CodeRabbit 4107828365,
4107828370; Codex 4107841820, and the C-B class itself) share one root cause: each
mutation writes **two files in sequence** (the harness config, then `manifest.json`)
with **no durable record of intent**. Any fault between the two writes, or during a
rollback, leaves the pair inconsistent, and a later run cannot tell what happened.
Point fixes (try/except around each save) keep moving the window instead of closing it.
The fix is a write-ahead log: record intent durably first, mutate second, and make every
later run able to finish or undo an interrupted one.

## J1 — Artifacts

| Artifact | Location | Content | Invariant |
|---|---|---|---|
| lock | `<state>/lock` | empty; `fcntl.flock` | exclusive for apply/restore/reconcile; shared for verify/doctor/plan |
| journal | `<state>/journal/<run-id>.json`, 0600, dir 0700 | see J2 | written by atomic replace + `fsync(file)` + `fsync(dir)` on **every** state change |
| closed journals | `<state>/journal/done/<run-id>.json` | same, final state | audit trail; never read for decisions |
| backups | `<state>/backups/<run-id>/<hid>/` | payload + `meta.json` (existing) | fsync'd before the journal references them; **never deleted by reconcile** |

`run-id` = the existing backup timestamp, so a journal and its backups share one name.
All three live in the private state dir, which is already checked link-free and 0700.

## J2 — Journal schema

```json
{"schema": 1, "run_id": "20260925T...Z", "op": "apply|restore", "state": "open|closed",
 "salt_id": "<HMAC(salt, b'salt-id')[:16]>",
 "entries": [{"hid": "...", "path": "/abs/config",
              "pre": {"hash": "<hmac>|null", "mode": "0o600|null", "exists": true},
              "post": {"hash": "<hmac>|null", "mode": "0o600|null", "exists": true},
              "backup": "backups/<run-id>/<hid>",
              "mf_before": {...} | null, "mf_after": {...} | null,
              "state": "pending|config-written|rolling-back|manifest-committed|rolled-back|conflict|conflict-resolved",
              "error": "<exception class name only>|null",
              "mac": "<HMAC(salt, canonical(entry without mac))>"}],
 "journal_mac": "<HMAC(salt, canonical({run_id, salt_id, op, [entry macs in order]}))>"}
```

- File hashes are `HMAC-SHA256(salt, bytes)` with the existing state salt. Plain SHA-256
  of a file that holds a secret would let anyone who reads the journal confirm a guessed
  secret; with the salt they cannot. The journal holds no config bytes and no secrets.
- `mf_before` / `mf_after` are this path's manifest entry (already salted hashes).
  Rollback restores **this path's entry only**, never the whole manifest, so harnesses
  committed earlier in the same run are not disturbed.
- Each entry `mac` covers the entry as currently written and is recomputed on every
  state change; `journal_mac` is recomputed on every journal rewrite. Deleting, reordering
  or swapping an entry therefore breaks the journal loudly instead of silently.
- A permission-only repair (Codex 4107841802) is an entry with `pre.hash == post.hash` and
  a different `mode`.

## J3 — Commit protocol (per harness, in order)

| Step | Action | Durable after the step |
|---|---|---|
| S0 | take exclusive lock; **reconcile** any open journal (J5) | lock held |
| S1 | create journal (`state: open`, no entries) | journal file |
| S2 | write backup payload + meta (fsync file + dir) | backup |
| S3 | append entry `pending` (pre, post, backup, mf_before, mf_after) | intent |
| S3b | re-run `config_changed` **immediately** before the write; changed → entry `rolled-back`, refuse "config changed since plan" | |
| S4 | write config (atomic replace, fsync file + **dir**) | new config |
| S5 | entry → `config-written` | |
| S6 | parse-back validation; on failure → rollback (J4) | |
| S7 | write manifest with `mf_after` for this path (atomic, fsync file + dir) | new manifest |
| S8 | entry → `manifest-committed` | |
| S9 | after all harnesses: journal `closed`, move to `done/` | |

`atomic_write` gains the missing `fsync` of the parent directory; without it the rename
itself is not durable across power loss.

## J4 — In-process rollback (a step raises)

1. **First** entry → `rolling-back` (durable). Then restore the config: if `pre.exists`
   write the backup payload with `pre.mode` (only after its HMAC equals `pre.hash`), else
   unlink the file and fsync the directory. Both are retry-safe: the unlink tolerates
   `ENOENT`, and restoring bytes and mode that are already in place is a no-op. Then set the manifest entry to `mf_before`.
   Then entry → `rolled-back`. `rolling-back` is what makes a failed rollback
   distinguishable from "crash after S7": reconcile never rolls it forward.
2. **The original error is always the reported error.** If the rollback itself fails
   (e.g. ENOSPC, CodeRabbit 4107828365): the entry stays in its last durable state, the
   journal stays `open`, the backup is kept, and the output names **both** errors plus the
   backup path and "the next apply/restore reconciles this run". Exit non-zero.
3. The remaining harnesses of the run are **not** attempted after a failed rollback
   (state is not known-good); harnesses already `manifest-committed` stay committed.

## J5 — Reconcile (start of every apply/restore, under the exclusive lock)

For each open journal, for each entry not in a final state, observe `H` = HMAC of the
config now (or `absent`) and `M` = the manifest entry now:

`O` is the observed triple `(exists, hash, mode)`; `pre`/`post` are the recorded triples.
Matching compares all three fields, so a permission-only entry (same hash, different
mode) and a pre-absent file are both decided exactly.

| Entry state | Observation | Decision |
|---|---|---|
| `pending` | `O == pre` | nothing was written → `rolled-back` (manifest entry set to `mf_before`) |
| `pending` | `O == post` | crash after S4, before S5 → handle as `config-written` |
| `config-written` | `O == post`, `M == mf_after` | crash after S7, before S8 → **roll forward**: `manifest-committed` |
| `config-written` | `O == post`, `M != mf_after` | **roll back** (J4 step 1, starting with `rolling-back`) |
| `config-written` | `O == pre` | impossible without a rollback, which always passes through `rolling-back` → `conflict` |
| `rolling-back` | `O == post` or `O == pre` | **retry the rollback**, never roll forward (validation may have failed) |
| `manifest-committed` | `M != mf_after` | re-assert `mf_after` (idempotent) |
| any non-final | backup payload HMAC != `pre.hash` when a rollback needs it | `conflict` (a data problem; retrying cannot help) — report backup path and `resolve` |
| any non-final | `O` ∉ {pre, post} (incl. deleted after write) | **foreign change** → touch nothing, entry `conflict`, journal stays open, exit non-zero, print backup path and the `resolve` command |

Roll forward happens in exactly one case: the entry reached `config-written` (which is
only recorded after S5, and S6 validation precedes S7) and both writes landed; only the
bookkeeping is missing. Every other interrupted state rolls back. Every action is idempotent: re-running reconcile after a crash inside reconcile
reaches the same state (restore to `pre` then comparing `H == pre` is a no-op; setting a
manifest entry to a value it already has is a no-op). A journal closes only when every
entry is final and not `conflict`.

**Trust of the journal.** The journal is a state-dir file, so the round-3 N1 lesson
applies: a path in it is honoured only if it is one of the harness's registry
`config_paths` under `$HOME` (the same allow-list restore uses). A backup ref must
resolve inside `<state>/backups/<run-id>/`. Anything else → `conflict`, nothing touched.
A journal that does not parse, whose filename is not a valid run-id, whose in-file
`run_id` differs from its filename, whose `salt_id` differs from the current salt, or
whose entry `mac` does not verify → refuse to mutate (usage error naming the file and the
`resolve` command); never guess. A backup ref must resolve inside
`<state>/backups/<validated run-id>/`, the `journal_mac` must verify, every component checked link-free **at use time**,
and its payload HMAC must equal `pre.hash` before it is written. The manifest carries the
same `salt_id`; a lost or rotated salt is detected there and refused, never silently
re-keyed. The manifest is tool-private and single-writer under the lock; a hand edit to
it between runs is overwritten toward `mf_before`/`mf_after` by design.

## J6 — Restore uses the same journal

`restore <ts>` is an `op: restore` run with its own run-id:
- S2 backs up the **current** config first (so the restore itself can be undone — the
  missing piece in CodeRabbit 4107828370 and Codex 4107841820).
- `post` = HMAC of the backup payload being restored; `mf_after` = the entry from the
  backup's manifest snapshot (or absent); `mf_before` = the current entry.
- Same steps, same rollback, same reconcile table.

## J7 — Concurrency

- apply / restore / reconcile: `LOCK_EX | LOCK_NB`. Busy → exit with "another run holds
  the lock" (usage error); never wait silently, never run in parallel.
- verify / doctor / inventory: `LOCK_SH | LOCK_NB`. (`plan` is advisory and takes no lock.) Busy → report "a mutating run is in
  progress; results would be transient" and exit non-zero.
- The existing `config_changed` re-read before each write still guards against the
  harness itself rewriting its file; reconcile's `conflict` row covers the same race
  across runs.

## J8 — verify and doctor read the journal (read-only)

- Any open journal → verify reports `interrupted <op> run <run-id>: <n> entries in state
  <s>; the next apply/restore reconciles it` and exits non-zero. doctor lists the same
  plus any `conflict` entry with its backup path.
- Neither mode ever writes the journal, the manifest or a config.
- Round-11 Codex verify gaps closed alongside: SSOT servers that should be rendered but
  have no manifest record are reported (4107841810), and a secret-bearing config that is
  git-visible (tracked / untracked / unknown) is reported (4107841816).

## J8b — Operator escape: `resolve <run-id>`

A persistent `conflict` or an unusable journal must not wedge the tool. `resolve <run-id>`
(explicit mode, exclusive lock) never touches a config or the manifest: it marks the
remaining entries `conflict-resolved`, moves the journal to `done/`, keeps all backups,
and prints each entry's backup path. `resolve` deliberately does **not** verify
`salt_id`, `mac`, `journal_mac` or parseability and does not reconcile: it acts on the
validated run-id alone (if the journal parses, mark its non-final entries; either way
move the file to `done/`). Only decision-making paths (reconcile) require full
verification, so the escape hatch works for exactly the journals it exists to clear.

**Salt recovery.** A lost or rotated salt blocks every mutation through the manifest's
`salt_id`, which `resolve` does not clear. Recovery: move `manifest.json` and `journal/`
aside, then re-run `apply --adopt` to rebuild ownership from the current configs.
Everything under `backups/` stays valid for `restore`. verify and doctor print this command whenever they
report an open journal.

## J9 — Failure points to inject (test plan)

Apply: before S2 · after S2 · after S3 · inside S4 (before rename) · after S4 · after S5 ·
S6 fails · rollback fails (ENOSPC) · inside S7 · after S7 · after S8 · before S9.
Restore: the same points. Reconcile: crash inside reconcile then reconcile again
(idempotency) · foreign change · tampered journal path · unparseable journal.
Added from the red-team: crash after S1 (empty journal closes) · pre-absent file at every
point (rollback unlinks) · permission-only entry at every point · S6 failure with rollback
succeeding vs failing (the `rolling-back` case) · S3b config-changed · ENOSPC during
journal writes (S3/S5/S8) · crash during the `done/` move · salt lost then reconcile ·
tampered backup payload / symlinked backup component · swapped pre/post hashes (MAC) ·
filename/run_id mismatch · lock-busy for every locked mode · restore whose target parent
dir is gone · `resolve` on a conflict. Each test asserts the three observable facts:
config bytes (and mode), manifest entry, journal state.

## J10 — Out of scope, stated

A crash while `atomic_write` has created its temp file leaves a `.hms-*` file in the
config directory; the config itself is unchanged. doctor reports such files; nothing
deletes them automatically. The design does not defend against an attacker who can write
the state dir *and* forge the salt; that attacker can already rewrite the manifest.
Deleting a whole journal file needs no salt and is not detectable from the journal; it
is caught one layer up, because the config then disagrees with its manifest entry and
verify reports content drift.

## J11 — Independent red-team of this design (kimi, 2026-09-25) and disposition

Verdict **FAIL** (1 blocker, 7 majors). All folded above before any code:

| # | Finding | Disposition |
|---|---|---|
| 1 BLOCKER | failed rollback looked like "crash after S7" → roll forward of an invalid config | `rolling-back` state (J4, J5) |
| 2 MAJOR | pre-absent config wedged as `conflict` | triples with `exists`; rollback unlinks (J2, J4, J5) |
| 3 MAJOR | salt loss silently re-keys every hash | `salt_id` in journal and manifest; mismatch refused (J2, J5) |
| 4 MAJOR | backup payload restored unverified | HMAC == `pre.hash` + link-free at use time (J4, J5) |
| 5 MAJOR | permission-only entry ambiguous | observe `(exists, hash, mode)` (J5) |
| 6 MAJOR | persistent conflict wedges the tool | `resolve <run-id>` (J8b) |
| 7 MAJOR | journal hashes unauthenticated | per-entry `mac` (J2, J5) |
| 8 MAJOR | `error` field could hold secrets | exception class name only (J2) |
| 9 MINOR | manifest hand edits silently reverted | documented: tool-private, single-writer (J5) |
| 10 MINOR | wider harness-self-write window | S3b re-check right before S4 (J3) |
| 11 MINOR | test-matrix gaps | added (J9) |
| 12 MINOR | run-id trust / collision | filename == body, containment from validated id (J5); a new run-id that already has a backups dir is re-drawn |
| 13 NIT | unbounded growth of `done/` and backups | deferred to a follow-up issue (opt-in prune); never-delete stays the default |
| 14 NIT | inventory unlocked | `LOCK_SH` (J7) |
| 15 NIT | plan lock makes scripting flaky | plan takes no lock (J7) |

### J11b — Delta red-team (kimi, same session) and disposition

Findings 1–8: all **CLOSED** by the text above. New findings from the fixes:

| # | Finding | Disposition |
|---|---|---|
| N1 MAJOR | per-entry MAC does not protect the entry *set* (delete the `rolling-back` entry) | `journal_mac` over run_id, salt_id, op and the ordered entry macs (J2, J5) |
| N2 MAJOR | `resolve` would refuse the very journals it must clear | `resolve` skips verification, acts on the run-id only (J8b) |
| N3 MINOR | pre-absent rollback retry fails on ENOENT | unlink tolerates ENOENT; identical restore is a no-op (J4) |
| N4 MINOR | bad backup payload during retry → retries forever | `conflict` row (J5) |
| N5 NIT | MAC freshness unstated | recomputed on every state change / rewrite (J2) |
| N6 NIT | salt-loss recovery undocumented | documented (J8b) |

Economic stop (Convergence Engine, ≤3 rounds): the remaining items are pinned by
J9 tests rather than a third design round; the implementation PR gets its own review.
