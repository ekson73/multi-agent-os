# ADR-005: Canonical Dogfood-Cycle Ledger (structured ≥2-cycle gate, replacing changelog prose)

- **Status**: Accepted
- **Date**: 2026-05-30
- **Deciders**: Operator (DevSecOps / AI-eng), via HITL directive ("multi-agent-os primeiro" + "tudo, incl. portabilidade+promoção")
- **Scope**: MAOS (community, MIT, AAIF cross-vendor). Companion to the dogfooding-mandate / ADR-017 R6 (the gate this ADR makes measurable).

## Context

The dogfooding-mandate requires **≥2 real cycles before promoting** any agentic-tool. That gate is cited across the ecosystem (ADR-017 R6, auto-pilot MASTER-PLAN, GIT-PR-AS-DEBATE-PROMPT, per-skill changelogs) **but the cycle count lives only as changelog prose** — not countable, not auditable, not durable. The operator flagged this directly: *"o cycle-count nem estava funcionando e já tive várias execuções em outras sessões"* — the cycles **already happened**, they were never **counted**. A gate without a measurement mechanism is theater.

Two existing observability systems are nearby but neither counts cycles: **ASH** (per-session walkthrough journal, lives in a product repo) and **Sentinel Protocol** (MAOS metrics/anomaly). A per-skill island ledger (a `DOGFOOD-LEDGER.md` created earlier) would fragment the count (anti-DRY/SSOT).

## Decision

Create a **single canonical dogfood-cycle counting primitive in MAOS** (the canonical agentic-OS, owner of the dogfooding-mandate):

1. **Event** — append-only JSONL `{tool, cycle_id, status, ratified, evidence[], session, project, vendor, note, ts}`.
2. **Ledger** — user-scope `${DOGFOOD_LEDGER_DIR:-~/.claude/audit}/dogfood-cycles.jsonl` (sees every project/session/vendor — **portability**).
3. **`bin/dogfood-mark`** (writer) + **`bin/dogfood-tally`** (read-only counting authority) — AAIF bash 3.2, jq-only, Layer-Purity-clean, cloned from ASH `ash-decide`/`ash-decisions` patterns.
4. **Anti-theater gate** — a cycle counts as COMPLETE only with `ratified==true` + ≥1 `evidence`. Promotion-eligible when `COMPLETE ≥ 2`.
5. **Backfill** — `--backfill` re-derives **real historical cycles from evidence** (resolving the chicken-and-egg: the gate is met by history, not by waiting, and never by inflation).
6. **Consumers, not duplicators** — ASH (`--dogfood-cycles`) + Sentinel read this ledger; per-skill island ledgers migrate here.

## Alternatives rejected

- **Per-skill island ledger** (one `DOGFOOD-LEDGER.md` per tool) — fragments the count → re-creates the theater (anti-DRY/SSOT). Migrated into this primitive instead.
- **Keep changelog-prose counting** — the status quo; unmeasurable (the problem).
- **Land in the product repo where the session-harness happens to live** — couples a cross-project governance primitive to a single MVP-scoped product repo. Cycle-maturity is canonical governance → belongs in MAOS.
- **A new database / graph** — over-engineering (YAGNI). Append-only JSONL + 2 small CLIs suffice; graph/inter-relation stays delegated to CPT + `gsd-graphify`.

## Consequences

- **Positive**: the ≥2 gate becomes structured, `jq`-countable, durable, cross-vendor, backfillable; one SSOT kills the fragmentation; amnesic agents can answer "how mature is tool X?" deterministically.
- **Negative (mitigated)**: the ledger is local-only (LGPD 5y retention = open gap, deferred to a separate ADR — flagged, not over-promised); a new primitive to maintain (kept minimal — 2 CLIs + 1 spec).
- **Self-application (dogfood)**: this primitive's **own** cycles are tracked in itself; its promotion to a canonical Layer-1 is gated by its own backfilled ≥2 — honest, not asserted.

## References

- Spec: [`docs/dogfood-cycle-ledger-spec.md`](../dogfood-cycle-ledger-spec.md)
- Gate it measures: dogfooding-mandate / ADR-017 R6
- Templates reused: ASH `bin/ash-decide` + `bin/ash-decisions` + `ash-stop-fallback.sh`
- Consumers (planned): ASH `ash-walkthrough --dogfood-cycles` · Sentinel `audit/session_index.json`
