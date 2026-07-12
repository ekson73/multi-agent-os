---
name: continuation-broadcast-protocol
description: SSOT for postflight P3.6 BROADCAST — the bounded, structured, idempotent continuation back-pointer MARKER injected into work artifacts (commit trailer · PR body · caller-named docs) as additional discovery sinks of the ONE canonical continuation seed/ticket. Structured back-pointer, never a free-form TODO (reconciled with exit-hygiene by ADR-010).
version: 1.0.0
---

# Continuation-Broadcast Protocol (SSOT) — postflight P3.6

> **Version**: 1.0.0 (2026-07-10)
> **Scope**: AAIF cross-vendor. The single source of truth for **P3.6 BROADCAST**, the postflight
> phase that makes the tracked continuation (the P2.5 ticket + the P3 seed) **discoverable at the
> point of future contact** — by stamping a bounded, structured, idempotent **back-pointer marker**
> into selected work artifacts.
> **Position**: runs **after P3 HANDOFF** (it needs the seed + the P2.5 continuation ticket key as
> input) and is **opt-in** (`--broadcast`) on `postflight`; it is **default-ON** only in the
> `signoff` verb. Emitting nothing when there is no pending continuation is correct behavior.
> **Executor**: `bin/continuation-broadcast.sh` (deterministic; `--dry-run` default).
> **Reconciliation with exit-hygiene**: `docs/adrs/ADR-010-continuation-broadcast.md`.
> **Cross-link slug**: `continuation-broadcast-protocol`

## Purpose

The continuation **seed** (P3) and **ticket** (P2.5) are the SSOT of "there is pending work, here
is how to resume it." But a fresh amnesic agent (or a different mind) who later lands on **a
commit, a PR, or a doc** has no reason to know the seed/ticket exist. The pending work is
**tracked but not discoverable** from where the next agent actually arrives.

BROADCAST closes that gap: it injects a **discovery marker** — a structured back-pointer to the
canonical seed/ticket — into the artifacts a next agent will encounter, so *"what is not seen is
not remembered"* (the locus master principle) does not swallow the continuation.

## The marker is a back-pointer, NOT a breadcrumb TODO (the decisive distinction)

`protocols/exit-hygiene.md` forbids free-form "fix next session" TODOs and "one more TODO"
incremental disorder. The marker is the **opposite** on every axis — it is structured (not prose),
a verified back-pointer (not a promise, not a content-duplicate), byte-idempotent (never
accumulates), bounded (one block per artifact; decision-records refused), and a noop when there is
no verifiable pendency. It is exit-hygiene's own *"registered with traceability"* (Axiom 4 + the
Delegation gate) surfaced where the next agent will find it. **The full reconciliation table lives
in `docs/adrs/ADR-010-continuation-broadcast.md` (the decision record) — it is not duplicated here.**

## The marker shape (single source → identical across sinks)

Built once by the executor from `--ticket` + `--seed` (+ `--session`), so every sink carries the
same payload.

**Block form** (PR body, caller-named docs) — sentinel-delimited for idempotent upsert:

```markdown
<!-- MAOS-CONTINUE:START -->
<!-- MAOS-CONTINUE {"ticket":"<KEY>","seed":"<repo-rel-path>","session":"<id>"} -->
> 🔁 **Continuation pending** — resume at **<KEY>** (seed: `<repo-rel-path>`). A fresh amnesic agent: run `/maos:preflight`, then continue from the ticket/seed. _(structured back-pointer, not a TODO — see ADR-010. If **<KEY>** is already resolved/closed this marker is STALE — delete this block.)_
<!-- MAOS-CONTINUE:END -->
```

- **Line 1/4** — `MAOS-CONTINUE:START` / `:END` sentinels, matched as **whole lines**: the
  idempotency anchors (upsert replaces the region between them; if absent, the block is appended
  once). The payload carries **no timestamp** → the block is byte-idempotent (re-apply = no-op).
- **Line 2** — the machine-readable JSON payload (greppable + parseable): `ticket`, `seed`
  (repo-relative), `session`.
- **Line 3** — the human mirror (one line; the operator/next-agent reads it at a glance) — including
  the **self-declared stale** instruction so a reader can retire a resolved marker on sight.

**Trailer form** (the exit commit) — a git-trailer-parseable single line the executor prints for
the caller to append to the closing commit message:

```
Continue-Here: <KEY> · seed:<repo-rel-path>
```

`git log --format='%(trailers:key=Continue-Here)'` / `git interpret-trailers` surface it.

## The three sinks (by `--scope`)

| Sink | `--scope` | How | Safety |
|---|---|---|---|
| **commit-trailer** | conservative (default) + all | executor prints `Continue-Here: …`; the caller appends it to the **exit commit** message | text-only; no file mutation; git-native |
| **pr-body** | conservative (default) + all | `--pr <N>` → `gh pr view` → **idempotent upsert** of the block → `gh pr edit --body-file` | capability-detected (no `gh` ⇒ skip-with-note); byte-idempotent; **fail-closed** on a malformed existing marker (body left untouched); never clobbers |
| **file** | **all only** | caller-named `--file <path>` (repeatable) → **idempotent upsert** of the block | opt-in; **ADR/decision records + symlinks REFUSED** (case-insensitive); unknown file ⇒ skip; fail-closed on malformed marker; never globs/discovers (caller decides *cabível*) |

**`conservative` (the default)** = commit-trailer + PR-body — the exit-hygiene-safe set (the two
places a continuation naturally belongs and that already carry session state). **`all`** = the
above **plus** the caller-named `--file` targets (docs, CHANGELOG `[Unreleased]`, …) for broader
amnesia-coverage — honoring the operator's *"onde for cabível"* while the caller (not the script)
decides which files are appropriate.

## Guardrails (deterministic; the executor enforces)

1. **`--dry-run` is the DEFAULT** — mutation requires `--apply`. A preview writes nothing.
2. **Kill-switch** — `MAOS_BROADCAST=0` ⇒ noop (deterministic opt-out).
3. **Byte-idempotent upsert, fail-closed** — a 2nd run replaces the one sentinel region (never
   accumulates) and the block has no timestamp (a re-apply on unchanged inputs is a true no-op). The
   upsert acts **only** on a well-formed single `START…END` pair (whole-line matched, correctly
   ordered); any malformed state (dangling/duplicate/out-of-order sentinel) makes it **refuse and
   leave the artifact untouched** — it can never mass-delete-to-EOF or duplicate a block.
4. **ADR / decision-record refusal** — refused **case-insensitively**: any `adrs/` · `adr/` ·
   `decisions/` path, any `ADR-*.md`/`adr-*.md` basename, any MADR `0001-*.md` basename. **Symlink
   targets are also refused** (a symlinked name could redirect the write past the refusal). A
   decision record is immutable, not a transient worklist.
5. **Caller-named only** — the executor never globs/discovers files; the agent decides which
   artifacts are *cabível* (judgment stays with the agent, safety with the script).
6. **Sanitization + injection-refusal** — the payload is **metadata-only** (ticket key · repo-relative
   seed path · session id): a secret-shaped payload is refused, and a payload carrying a sentinel/
   comment marker or a newline is refused (it could otherwise restructure the block). Absolute/`$HOME`
   seed paths are relativized (no machine-path leak).
7. **Verified referent, else noop** — the marker points only at a **verified** referent: an unfound
   `--seed` is dropped, and with no named ticket + no existing seed the run is a noop (BROADCAST
   never emits an unbacked marker; no pendency ⇒ nothing broadcast).
8. **Audit-trail** — one line per **applied** sink to `~/.claude/jobs/continuation-broadcasts.log`
   (dry-runs write nothing).

## When to broadcast (and when NOT)

- **Broadcast** when P2.5 produced a continuation ticket AND/OR P3 produced a seed AND a genuine
  pendency remains (the hunt found a gap/pending/undecided/risk the next agent must pick up).
- **Do NOT broadcast** a clean, fully-closed session (nothing pending) — there is nothing to point
  at, and a marker on finished work is noise (the nothing-to-point-at noop enforces this).

## Anti-patterns (do NOT)

1. ❌ **Free-form marker** — writing prose "TODO next session" instead of the structured back-pointer
   block (defeats the whole exit-hygiene reconciliation; the executor only emits the structured form).
2. ❌ **Blind file injection** — stamping a marker into an ADR or mid-content of a doc (ADRs are
   refused; the executor only upserts the sentinel region or appends one bounded block).
3. ❌ **Duplicating the seed/ticket content** into the marker — the marker is a *pointer*; the seed
   is the payload (no content duplication — DRY).
4. ❌ **Broadcasting with no pendency** — a marker on a fully-closed session is noise.
5. ❌ **Non-idempotent placement** — appending a new block each run (the sentinel upsert exists
   precisely to prevent accumulation — entropy is exponential).
6. ❌ **Marker payload with a secret / file body** — metadata-only (sanitization refuses it).

## Related artifacts

- `bin/continuation-broadcast.sh` — the deterministic executor (this protocol's implementation).
- `bin/tests/continuation-broadcast.test.sh` — the safety-contract test suite (idempotency,
  dry-run-default, ADR-refusal, kill-switch, sanitization).
- `skills/postflight/SKILL.md` — **P3.6 BROADCAST** invokes this protocol (opt-in `--broadcast`).
- `skills/postflight/references/continuation-seed-contract.md` — the seed the marker points at.
- `skills/postflight/references/ticket-sync-protocol.md` — the P2.5 continuation ticket the marker points at.
- `protocols/exit-hygiene.md` — the anti-breadcrumb rule this marker is reconciled with.
- `docs/adrs/ADR-010-continuation-broadcast.md` — the reconciliation decision record.
- `commands/signoff.md` / `skills/signoff/SKILL.md` — the sign-off verb that turns `--broadcast` ON by default.

## License

MIT (matches the multi-agent-os repo `LICENSE`).
