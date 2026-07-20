# ADR-012: Memory-Curator Sleep-Time Extension — Pointer-Freshness, Tiering, Scheduled Sweep (Mnemosyne v2)

- **Status**: Accepted (design) — implementation pending (the forge is the next phase; this ADR is the phase gate "own spec, destination repo")
- **Date**: 2026-07-15
- **Deciders**: Operator (DevSecOps / AI-eng, standing "continue" directive on the memory-architecture roadmap) + Claude (Fable 5)
- **Scope**: MAOS (community, MIT, AAIF cross-vendor). Extends `agents/memory-curator.md` (Mnemosyne, 2026-03-13). Companion to ADR-011 (artifact-registry dedup-memory) + ADR-009 (session-reentry / amnesic re-entry).

## Context

AI-native memory corpora (per-project memory files + an auto-loaded index + rules/docs) accumulate entropy: duplicates, stale facts, broken cross-references, unbounded index growth against hard byte-caps. The existing **`memory-curator` agent (Mnemosyne)** already owns the hygiene competencies — audit, dedup, staleness detection, cross-reference validation, index maintenance, entropy reporting — but it is **on-demand only**: someone must remember to spawn it. In an amnesic-agent ecosystem, "someone must remember" is the exact failure mode.

Two empirical scars motivate the extension (first consumer: the operator's `~/.claude` corpus, dogfood-first):

1. **The forgotten-solution recursion**: a prior agent designed and built a full memory/VCS solution, then *forgot it existed* because no pointer ever reached the always-present keystone doc — the design was 100% in non-auto-loaded files. The cure (a keystone→hub→sub-artifact pointer chain) only stays cured if something **owns pointer-freshness continuously**.
2. **The index byte-cap churn**: the auto-loaded memory index repeatedly trips its host-enforced byte-cap; the correct response each time is **tiering** (move detail to topic files, keep one line per entry), never deletion — but today that response depends on whichever session happens to hit the cap.

A one-shot lookup answers "is the corpus healthy *now*?" It cannot answer "who keeps it healthy *while nobody is looking*?" That second question is what a **sleep-time** curator answers.

## Decision

**EXTEND Mnemosyne — do not forge a new agent** (reuse-and-elevate; an artifact-registry lookup found no prior sleep-time curator, and Mnemosyne already covers ~70% of the need). Three additions:

### 1. Three new IN-SCOPE competencies for `agents/memory-curator.md`

| Competency | Description |
|---|---|
| **Pointer-Freshness** | Verify the *not-forget invariants*: every roadmap/hub doc's phase rows link to their delivered artifacts; every `[[slug]]` cross-reference resolves (bidirectionally where mandated); the keystone→hub→sub-artifact path stays connected. A delivered artifact whose hub row still says "pending" is a finding. |
| **Promote/Demote Tiering** | Route knowledge to its correct representation tier: journal entries → topic files (promotion); over-cap index lines → one-line-per-entry with detail moved to topic files (compaction-by-tiering); flag memory→rule elevation candidates and rule→doc demotion candidates **as proposals only** — never auto-elevate or auto-demote governance artifacts. |
| **Sleep-Time Operation** | Run on a schedule, out-of-session, in **read-only** mode: produce a curation report + a staged proposal queue. All mutations happen later, in-session, under the normal gates (worktree/PR for tracked files; concurrency checks for shared corpora). |

### 2. `bin/memory-curator-sweep.sh` — the deterministic pre-scan

A no-LLM script (POSIX bash 3.2 + jq, the ADR-005/ADR-011 implementation pattern) that emits a **work-queue JSON**: index size vs cap, orphan/dangling references, duplicate-candidate shingles, staleness dates past their re-validation markers, journal-accumulation counts, hub rows still marked pending whose artifacts exist. The agent consumes the queue and applies judgment only where the script flagged work — *deterministic skeleton, probabilistic muscle* (the Convergence-Engine allocation doctrine).

### 3. Scheduling = machine-local; the script is the community primitive

The sweep script ships here (community, generic). *When* it runs is per-machine configuration (launchd/cron/SessionStart-drain — the disk-health-guardian precedent), never versioned with personal paths in this repo.

## Safety bounds (non-negotiable in the implementation)

- **Read-only out-of-session.** The scheduled sweep NEVER mutates; it stages proposals.
- **Tiering, never deletion.** Detail moves to topic files; content is never destroyed to satisfy a cap.
- **Proposals-only for governance.** memory→rule elevation and rule→doc demotion require operator confirmation (auto-edit of rule corpora is disabled by design).
- **Concurrency-safe.** Before any in-session mutation on a shared corpus, probe for concurrent writers (fresh peer sessions / VCS index locks) and defer or worktree-isolate.
- **Guardrail files are out of reach.** Safety-critical/absolute-guardrail artifacts are never curated autonomously.

## Alternatives rejected

- **Forge a new sleep-time agent** — rejected: Mnemosyne covers ≥50% (reuse-and-elevate threshold); a sibling agent would be the near-duplicate ADR-011 exists to prevent.
- **A fully-autonomous curator with write access out-of-session** — rejected: unattended mutation of shared memory under concurrent writers trades a hygiene problem for a data-loss problem. Read-only sweep + in-session gated application keeps the blast radius at zero.
- **Adopt an external memory platform (mem0/Letta/Zep) for the curation layer** — rejected per the standing absorb-not-adopt verdict: absorb the *sleep-time compute* idea (Letta), keep the git-backed markdown corpus.
- **Compaction-by-summarization as the cap response** — rejected: compact-and-lose-semantics is the failure the tiering model replaces (index/map/load-on-demand, not lossy squeeze).

## Consequences

- Mnemosyne gains an unattended heartbeat: corpus entropy is *detected* on schedule instead of when a session trips over it.
- The pointer-freshness competency mechanizes the not-forget invariant — the forgotten-solution class of failure gets a standing detector.
- One new bin primitive to maintain (`memory-curator-sweep.sh`), one agent file extended, zero new agents.
- The proposal queue adds one hand-off hop (sweep → in-session application) — accepted cost; it is what keeps the sleep-time path read-only.

## Definition of Done (for the implementation phase, not this ADR)

1. `agents/memory-curator.md` v2 with the three competencies + safety bounds.
2. `bin/memory-curator-sweep.sh` + test suite (green), following the ADR-005/ADR-011 bash-3.2+jq pattern.
3. Artifact-registry `record` of the created primitive.
4. ≥2 dogfood cycles on a real corpus before recommending/promoting (dogfood-first).

## Related

- `agents/memory-curator.md` — the agent this extends (Mnemosyne).
- `docs/adrs/ADR-011-artifact-registry.md` — the dedup discipline consulted before this decision.
- `docs/adrs/ADR-009-session-reentry-anamnesis.md` — the re-entry sibling (this ADR keeps the corpus that re-entry reads healthy).
- `docs/dogfood-cycle-ledger-spec.md` / ADR-005 — the implementation pattern the sweep script reuses.
