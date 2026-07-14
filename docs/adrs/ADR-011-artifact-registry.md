# ADR-011: Artifact-Registry — Dedup-Memory for Naming (Anima) & Creation (Forge)

- **Status**: Accepted
- **Date**: 2026-07-14
- **Deciders**: Operator (DevSecOps / AI-eng) + Claude (Opus 4.8), via HITL directive ("Anima precisa ter um registro/memory de nomeação, Forge precisa ter um registro/memory de criação → propósito: duplication aware/avoid")
- **Scope**: MAOS (community, MIT, AAIF cross-vendor). Companion to `naming-authority` (Anima's naming sovereignty) + the dogfood-ledger primitive (ADR-005, whose implementation pattern this reuses).

## Context

**Anima** (the naming skill) does a live *namespace* collision-`Grep` before deciding a name, and **Forge** (the agentic-tool creator) does a live *DRY / PR-state* probe before creating. Both are one-shot, in-the-moment checks — and **neither persists a log of its own past decisions**. So a *synonym* of something already named or created slips through a slug-grep:

> A namespace `Grep` for `session-method-audit` returns nothing — yet `praxis-audit` already exists for that exact intent. The grep matched the *slug*; it could not match the *purpose*.

A one-shot slug-grep answers "is this exact string taken?" It cannot answer "have we already named/created something for this *intent*?". That second question is what causes accidental near-duplicates across sessions (amnesic agents don't remember prior naming/creation decisions).

## Decision

Add a **single shared dedup-memory** primitive — `bin/artifact-registry` — with two verbs:

1. **`record --kind name|create --slug … --purpose … [--type …] [--aliases …] …`** — append ONE decision to an append-only JSONL ledger. Idempotent on `(kind, slug, purpose)`; atomic mkdir-lock append.
2. **`lookup --purpose … [--slug …] [--type …] [--json]`** — match on **exact slug OR fuzzy purpose** (token-overlap over `purpose + slug + aliases`, tokens ≤2 chars dropped) → verdict **`DUP-RISK`** when *either* signal fires (exact-slug **OR** ≥2 shared meaningful tokens), else **`CLEAR`**. This is what catches the synonym a slug-grep misses.

**One ledger, two kinds** → Anima sees what Forge created and vice-versa (dedup across *both*). Anima records the `name`; Forge records the `create` — two faces of one artifact, not a duplicate.

**Wired in (surgical, not new machinery):**
- **Anima** — §5 `lookup`-before-deciding (advisory) + DoD `record`-after-decision.
- **Forge** — step-1 DRY-probe `lookup` (DUP-RISK ⇒ prefer EXTEND over re-create) + step-8 `record`-after-write.

**Reuses the ADR-005 dogfood-ledger implementation pattern** (0 new machinery class): POSIX bash 3.2 + jq, ledger at `${ARTIFACT_REGISTRY_DIR:-$HOME/.claude/audit}/artifact-registry.jsonl`, mkdir-lock atomic append, `[C06]` exit codes.

## Alternatives rejected

- **No registry (status quo)** — the problem: live slug-greps miss synonyms; near-duplicates recur. This ADR exists to close that.
- **A queryable SKILL.md wrapper now** — consumers call the bin directly; a skill wrapper is future-if-recurs (YAGNI / Triple-touch).
- **A new database / graph** — over-engineering (YAGNI). Append-only JSONL + one CLI (two verbs) suffices; graph/inter-relation stays delegated to CPT.
- **Port the dogfood-ledger's `--backfill` + ratified-gate** — those are dogfood-cycle-specific (promotion gating), not needed for a naming/creation dedup-memory. Dropped (Gordian / anti-over-eng).
- **A hard block on DUP-RISK** — rejected: the registry is **advisory**, never a gate. The decider (Anima per `naming-authority`, or the operator) always owns the call; a DUP-RISK is a prompt to consider EXTEND, not a refusal.

## Consequences

- **Positive**: naming/creation become duplication-aware at the *intent* level (not just the slug level); the registry is a durable, `jq`-queryable, cross-session decision-memory; amnesic agents inherit prior naming/creation context deterministically.
- **Negative (mitigated)**: machine-local working-memory (gitignored `~/.claude/audit`) — advisory, honestly labelled (not a governance record, not a hard gate). One small primitive to maintain (kept minimal — one bin, two verbs).
- **Self-application (dogfood)**: the registry recorded its own genesis (`create artifact-registry`) + the `name` decision at merge time; the synonym→DUP-RISK behaviour was proven on the real ledger.

## References

- Bin: [`bin/artifact-registry`](../../bin/artifact-registry) · Spec: [`docs/artifact-registry-spec.md`](../artifact-registry-spec.md) · Tests: [`tests/test-artifact-registry.sh`](../../tests/test-artifact-registry.sh)
- Landed: PR #249 (`feat(bin): artifact-registry — dedup-memory for Anima naming + Forge creation`)
- Pattern reused: ADR-005 (dogfood-cycle-ledger) — same JSONL + mkdir-lock + bash 3.2 + jq lineage
- Naming sovereignty: `naming-authority` (the decider owns the call; registry is advisory)
- Consumers: `skills/anima/SKILL.md` §5 + DoD · `skills/agentic-tool-forge/SKILL.md` step-1 + step-8
