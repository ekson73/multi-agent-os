# Dogfood-Cycle Ledger — Spec (canonical SSOT for the ≥2-cycle gate)

> **Status**: Accepted · **Version**: 1.0.0 · **Date**: 2026-05-30 · **Scope**: MAOS (community, MIT, AAIF cross-vendor)
> **ADR**: [`ADR-005-dogfood-cycle-ledger.md`](./adrs/ADR-005-dogfood-cycle-ledger.md)

## 1. Problem (why this exists)

The **dogfooding-mandate** requires that a new agentic-tool (agent / skill / command / policy) be exercised in **≥2 real cycles before promotion** (project-scope → user-scope → toolkit → multi-agent-os). That gate is referenced everywhere (ADR-017 R6, auto-pilot MASTER-PLAN, GIT-PR-AS-DEBATE-PROMPT, per-skill changelogs) **but the count is recorded only as changelog prose** (`"cycles_completed: N"`, `"Onda N: validou Z"`). Prose is **not countable, not auditable, not durable** — an amnesic agent cannot answer *"how many real cycles does tool X have?"*. A gate with no measurement mechanism is **governance theater**.

This spec defines the single, structured, `jq`-countable **SSOT** for dogfood-cycle counting.

## 2. The event (append-only JSONL)

One JSON object per line in the ledger. Fields:

| field | type | required | meaning |
|---|---|---|---|
| `tool` | string (slug `[A-Za-z0-9._-]`) | yes | agentic-tool the cycle belongs to, e.g. `debate-converge` |
| `cycle_id` | string (slug) | yes | cycle id within that tool, e.g. `001` |
| `status` | `complete` \| `in-progress` \| `abandoned` | yes | current state of the cycle |
| `ratified` | bool | yes | the cycle reached a ratified terminal state |
| `evidence` | string[] | yes (≥1 for `complete`) | real evidence refs — `github:owner/repo/pull/N` · `session:<sid>` · `path:...` · `jira:KEY` |
| `session` | string | sparse | session id that produced/advanced the cycle |
| `project` | string | yes | project slug where it ran |
| `vendor` | string | yes | ai-vendor (`claude-code` \| `cursor` \| `copilot` \| `unknown`) |
| `note` | string (≤240) | sparse | short human note |
| `ts` | ISO-8601 UTC | yes | event timestamp |

**Append-only history**: a status transition (`in-progress` → `complete`) is a **new event**, never an in-place edit. The tally reduces by `(tool, cycle_id)` to the **latest-by-`ts`** event — so the cycle's *current* state is the last event, and the full history is preserved for audit.

## 3. Ledger location (portability)

`${DOGFOOD_LEDGER_DIR:-~/.claude/audit}/dogfood-cycles.jsonl` — **user-scope** so it sees cycles from **any project / session / vendor** (a user-scope tool like `debate-converge` runs everywhere). Does NOT touch the sibling `governance_*.jsonl` files. Override via `DOGFOOD_LEDGER_DIR` (tests, CI, multi-tenant).

> **Limitation (honest)**: `~/.claude/audit/` is local-only / not version-controlled → "permanent" is bounded by the machine. LGPD-grade long-term retention (5y) needs an out-of-band sink — **open gap**, deferred to a separate ADR. Do not over-promise durability.

## 4. Count semantics + the gate

- A cycle counts as **COMPLETE** only when its latest event is `status==complete` **and** `ratified==true`. "Rounds happened" ≠ complete; a tool defines its own ratification signal (e.g. `debate-converge` = END-handshake unanimous `RATIFIED`).
- `abandoned` never counts.
- **Promotion-eligible** when `COMPLETE ≥ gate` (default `2`; override `--gate N`).

## 5. Tooling (AAIF bash, POSIX 3.2, jq-only, Layer-Purity-clean)

| tool | role | guarantees |
|---|---|---|
| **`bin/dogfood-mark <tool> <cycle_id> [--status …] [--ratified] [--evidence …]`** | capture/writer | idempotent (no dup of identical event) · atomic append (mkdir-lock) · **anti-theater**: `complete` REQUIRES `--ratified` + ≥1 `--evidence` else refuse (exit 1) · `--dry-run` (`--backfill` is Phase 2 — see §6, not yet implemented) |
| **`bin/dogfood-tally [<tool>] [--json\|--table] [--gate N]`** | report/count — **the counting authority** | read-only (SRP) · reduces latest-per-cycle · renders gate verdict per tool |

Exit codes ([C06]): `0` success · `1` usage/validation · `2` setup.

## 6. Backfill (resolves the chicken-and-egg)

Cycles **already happened** across past sessions — they were simply never counted. The `--backfill` mode re-derives them from **real evidence** (ASH journals with `cycles_completed`/`dogfood`; tool changelogs; transcripts; prior per-skill ledgers), one event per detected cycle, each carrying its `evidence` ref. **Anti-hallucination**: no evidence ⇒ not counted. This makes the ≥2 gate satisfiable by **history**, not by waiting on the future — and never by inflation.

> **Status: Phase 2 — manifest path IMPLEMENTED; auto-scanner is Phase 2.1.**
>
> - **`bin/dogfood-mark --backfill <manifest.jsonl>` (implemented):** batch-replays an evidence-bearing JSONL manifest (one `{tool,cycle_id,status?,ratified?,evidence[]?,note?}` object per line), re-invoking `dogfood-mark` per row so the **same** validation + anti-theater gate applies — a `status=complete` row lacking `ratified`+`evidence` is **REFUSED** (never inflated). Idempotent; `--dry-run` supported; blank/`#`-comment lines skipped. Example/fixture: [`docs/dogfood-backfill-example.jsonl`](dogfood-backfill-example.jsonl).
> - **Phase 2.1 (NOT yet implemented):** auto-*deriving* a manifest by scanning ASH journals / changelogs / transcripts. That heuristic scanner is a separate, riskier effort (prose parsing) and is deliberately deferred — until it lands, curate the manifest from real evidence by hand (each row needs a concrete `evidence` ref).

## 7. Anti-patterns (do NOT)

- ❌ Two SSOTs — a per-skill island ledger AND this one (re-creates the fragmentation we are killing). Per-skill ledgers MIGRATE here; tools query via `dogfood-tally`.
- ❌ Counting `complete` without `ratified`+`evidence` (theater).
- ❌ Inflating the count via fabricated/evidence-less backfill.
- ❌ Drawing graphs/inter-relation here — delegated to CPT §9 Compass API + `gsd-graphify` (this ledger emits link-fields, it does not visualize).
- ❌ Writing from `dogfood-tally` (read-only; writes go through `dogfood-mark`).

## 8. Refs

- ADR-005 (this primitive) · dogfooding-mandate / ADR-017 R6 (the ≥2 gate it measures)
- Consumers (planned): ASH `bin/ash-walkthrough --dogfood-cycles` (reads this ledger) · Sentinel `audit/session_index.json`
- Templates reused: ASH `bin/ash-decide` (capture) + `bin/ash-decisions` (report) + `ash-stop-fallback.sh` (atomic append+lock)
- Cross-link slug: `[[dogfood-cycle-ledger]]`

## 9. Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-05-30 | Bootstrap — canonical dogfood-cycle counting primitive. Event schema + user-scope ledger + `dogfood-mark`/`dogfood-tally` + anti-theater gate + backfill contract. Replaces changelog-prose counting. |
