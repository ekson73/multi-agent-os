# ADR-013: Memory-CRUD Gateway — One Canonical Owner of Memory Mutations ("Others Ask IT")

- **Status**: Accepted (design) — implementation pending (the build is the next phase; this ADR is the phase gate "own spec")
- **Date**: 2026-07-15
- **Deciders**: Operator (DevSecOps / AI-eng, standing "continue" directive on the memory-architecture roadmap) + Claude (Fable 5)
- **Scope**: MAOS (community, MIT, AAIF cross-vendor). Completes the memory-hygiene trio with ADR-012 (sleep-time sweep — the *detector*) and the Mnemosyne agent (the *judge*): this gateway is the *executor*. Companion to ADR-011 (artifact-registry) + ADR-009 (session-reentry).

## Context

In a multi-agent ecosystem, **every agent reads and writes the shared memory corpus directly** — raw `Read`/`Write`/`Edit` against markdown files. That is the root of the entropy classes the sweep (ADR-012) detects after the fact: duplicate topics, orphan files, index drift, caps tripped by uncoordinated appends, and concurrent-writer clobbering. Detection is necessary but reactive; the structural fix is **ownership**: exactly ONE canonical tool owns memory mutations, and every other agent must *ask it* — the operator's directive verbatim: *"build-all-in-one-unique-tools-2-CRUD-memories (others must ask it for)"*.

The design floor is already decided by prior art (do not re-litigate):

- **Native-first, no heavy stores** (memory-JIT tooling ADR, 2026-06-24): graph/vector DBs (mem0, Letta, Zep/Graphiti, neo4j) REJECTED as *runtimes* — they add always-on MCP-token cost, the exact problem being fought. **Absorb their ideas** instead: mem0's *narrow CRUD API* + dedup-on-write; Letta's *tiering*.
- **Store = git-backed markdown graph** (memory-architecture roadmap §4.3): `[[wikilinks]]` + frontmatter, greppable, versionable, human-inspectable. The link-graph already exists (~118 distinct link-targets) — the gateway *navigates* it, it does not replace it.
- **`episodic-memory` MCP stays** (~102 always-on tokens, installed): it is the *conversation-recall* substrate. The gateway **fronts** it for semantic search rather than re-implementing embeddings.
- **ADR-012 safety bounds are inherited verbatim** (read-only out-of-session · tiering-never-deletion · proposals-only for governance · concurrency-safe · guardrail files out of reach).

## Decision

Build the gateway as a **deterministic CLI primitive + thin skill wrapper** in this repo — `bin/memory-gateway` + `skills/memory-gateway/SKILL.md` — NOT as a new MCP server (a new server would add always-on schema tokens; a bin script costs zero until invoked — the same economics that made ADR-012 a script).

### The narrow API (mem0-absorbed; everything else is out)

| Verb | Contract | Notes |
|---|---|---|
| `create <topic-slug> [--type {user,feedback,project,reference}]` | New topic file with valid frontmatter + index line, **dedup-checked first** (title/slug match against corpus → refuse with pointer on collision) | stdin = body; the dedup-on-write is the mem0 absorb |
| `read <slug>` | Print one topic file (index-resolved) | the R that keeps others from raw-globbing |
| `update <slug>` | Append/patch a topic file; **never silently overwrites** (concurrent-writer probe first) | stdin = delta |
| `archive <slug>` | Move to the archive tier + update index — **the only "delete"**; content is never destroyed | tiering-never-deletion made structural |
| `search <query>` | Structural grep over corpus + (when available) `episodic-memory` semantic recall, merged | fronts the installed MCP; degrades to grep-only |
| `neighborhood <seed-slug> [--depth N] [--budget N]` | Walk the `[[wikilink]]` graph from a seed, emit the connected slice within a token budget | the retrieve-by-neighborhood primitive; `--depth` default 1, range 1–3; values >3 are **clamped to 3 with a stderr diagnostic** (same policy as `morning-briefing --depth`, anti-bloat) |
| `index` | Regenerate/re-tier the index from the corpus (one line per entry; detail stays in topic files) | the canonical cap response — tiering, mechanized |

`create`/`update`/`archive`/`index` are the **mutating** verbs; `read`/`search`/`neighborhood` are read-only.

### I/O contract (JSON envelope + exit codes)

- **stdout** — exactly ONE JSON object per execution, minimum shape `{"status": "ok"|"refused"|"error", "verb": "<verb>", "slug": "<slug|null>", "data": {…}|null, "reason": {"code": "<CODE>", "message": "<text>"}|null}`. `reason` is required when `status != "ok"` (e.g. `DEDUP_COLLISION` with a pointer to the existing topic, `CONCURRENT_WRITER`, `BOUNDARY`).
- **stderr** — human diagnostics only, never JSON (deterministic parsing for wrappers; same split as `bin/artifact-registry`).
- **Exit codes** (`[C06]`, aligned with the repo's CLI-mutator family `bin/artifact-registry`, precedent PR #223): `0` success (incl. idempotent no-op) · `1` usage/validation **or refused** — the refusal detail lives in the JSON envelope, not in a third exit semantic · `2` setup/environment (e.g. `jq` missing). Note: `bin/memory-curator-sweep.sh`'s `2 = findings present` is that read-only *detector*'s own contract and is not inherited here.

### Structural guarantees (what "ask IT" buys)

1. **Dedup-on-write** — the collision is refused *before* it exists, instead of swept up after (shifts ADR-012's dup-title check left).
2. **Index coherence** — every create/archive updates the index in the same operation; orphan-file and dangling-ref become impossible *through the gateway*.
3. **Concurrency safety** — mutating verbs probe for concurrent writers (fresh peer sessions / VCS index locks) and defer or refuse; never clobber.
4. **Audit** — every mutation appends one JSONL line to a gateway ledger (who/verb/slug/when), the same pattern as the artifact-registry (ADR-011) and dogfood ledgers.
5. **Boundary** — the gateway operates ONLY inside the corpus root it is pointed at; refs escaping the boundary are refused (ADR-012's path-traversal guard, applied to writes).

### Adoption path (advisory-first — WARN before BLOCK)

Phase A (this spec's build): the gateway exists; agents are *directed* to it by rule/skill guidance — raw writes still possible. Phase B (own decision, evidence-gated): a `PreToolUse` hook WARNs on raw `Write`/`Edit` into a gateway-managed corpus. Phase C (operator-ratified only): WARN→BLOCK. Jumping straight to BLOCK would break every existing flow, including the memory auto-commit hook — the accessibility-ramp discipline (WARN-mode default) applies.

### The trio (division of labor)

```
ADR-012 sweep (deterministic detector)  →  work-queue JSON
Mnemosyne v2 (probabilistic judge)      →  curation report + staged proposals
THIS gateway (deterministic executor)   →  the ONLY hands that mutate the corpus
```

The sweep finds; the agent decides; the gateway acts. Each layer is independently testable, and the mutating surface is exactly one auditable tool.

## Alternatives rejected

- **A new MCP memory server** — rejected: adds always-on tool-schema tokens to every session (the memory-JIT ADR's central anti-pattern). A bin primitive costs zero until invoked and works cross-vendor (AAIF).
- **Adopt mem0/Letta/Zep as the gateway** — rejected per the standing absorb-not-adopt verdict: heavy runtimes, lock-in, always-on cost. Their *ideas* (narrow API, dedup-on-write, tiering) are absorbed above.
- **Hard-block raw writes from day 1** — rejected: breaks the auto-commit memory hook + every existing agent flow; violates the WARN-mode-default ramp discipline. Advisory-first, evidence-gated escalation.
- **Full CRUD with hard `delete`** — rejected: tiering-never-deletion is a non-negotiable ADR-012 bound; `archive` is the only removal verb.
- **Re-implement semantic search** — rejected: `episodic-memory` (sqlite-vec) is installed and KEPT by the memory-JIT ADR; the gateway fronts it and degrades to structural grep when absent.

## Consequences

- Memory mutations gain a single auditable owner; the entropy classes ADR-012 detects post-hoc become structurally impossible *through the gateway* (dup, orphan, index drift).
- One new bin primitive + one skill to maintain; zero new servers, zero always-on token cost.
- Raw-write bypass remains possible until Phase B/C — accepted: the sweep (ADR-012) is the detection net under the advisory phase; the two mechanisms cover each other.
- The gateway becomes the natural executor for Mnemosyne v2's staged proposals (the in-session gated apply lands as gateway verbs).

## Definition of Done (for the build phase — NOT this ADR)

- `bin/memory-gateway` implementing the 7-verb narrow API (POSIX bash 3.2 + jq; the §"I/O contract" envelope + exit-code semantics).
- Test suite: fixture corpus covering every verb, dedup-refusal, concurrent-writer refusal, boundary refusal, archive-not-delete, index regeneration; read-only guarantee for the read verbs.
- `skills/memory-gateway/SKILL.md` wrapper (agent-facing contract + examples).
- ≥2 ratified dogfood cycles (`dogfood-mark`) on a real corpus before any promotion or Phase-B hook.

## Provenance

🤖 agent-created — Claude (Fable 5), session 9bf1da6c, `/maos:ooda-loop continue` iteration 3, 2026-07-15. Composes: operator directive ("one canonical memory-CRUD tool, others must ask IT") · memory-architecture roadmap §4.2/§6 Phase-3 · memory-JIT tooling ADR 2026-06-24 (native-first; absorb-not-adopt) · federated-memory architecture (mem0 ABSORB verdict) · ADR-012 (safety bounds, inherited verbatim) · ADR-011 (ledger pattern). Dedup-checked via `artifact-registry lookup` (CLEAR).
