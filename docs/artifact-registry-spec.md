# Artifact Registry — dedup-memory for Anima (naming) & Forge (creation)

> **Bin**: `bin/artifact-registry` (`record` + `lookup`) · **Ledger**: `${ARTIFACT_REGISTRY_DIR:-~/.claude/audit}/artifact-registry.jsonl` (machine-local, gitignored — a working dedup-memory, NOT a repo artifact) · **Siblings**: `dogfood-ledger` (same JSONL + record/query bin pattern) · `anima` (consumer) · `agentic-tool-forge` (consumer).

## Why (the gap it closes)

Anima (the namer) already does a **live namespace collision-check** (Grep the family) and Forge (the creator) a **live DRY / PR-state probe** at decision-time. But **neither keeps a persistent log of its own past decisions** — so a *synonym* for something already named/created slips through a one-shot namespace grep:

> A namespace `Grep` for `session-method-audit` returns nothing — yet `praxis-audit` already exists for that exact intent. The grep matched the *slug*; it could not match the *purpose*.

The artifact-registry is that missing **decision-memory**: every **name** (Anima) and every **create** (Forge) is recorded once, and before deciding, the consumer does a **purpose-level lookup** that catches synonyms a slug-grep cannot.

## The two verbs

### `lookup` — call BEFORE naming/forging
```
artifact-registry lookup [--purpose "<intent>"] [--slug <slug>] [--type <t>] [--json]
```
- Matches on **exact slug** (strongest signal) **and** **fuzzy purpose** — token-overlap over `purpose + slug + aliases`, dropping tokens ≤2 chars.
- **Verdict**: `DUP-RISK` iff exact-slug OR ≥2 shared meaningful purpose-tokens; else `CLEAR`.
- `--json` → `{verdict, matches:[{kind,slug,type,purpose,by,location,ref,overlap,exact}]}` for agent consumers.
- Always exits `0` (the verdict IS the output); consumers read `.verdict`.

### `record` — call AFTER a decision
```
artifact-registry record --kind name|create --slug <slug> \
  [--purpose "<intent>"] [--type <t>] [--by anima|forge] [--alias <a>]... \
  [--location <loc>] [--rationale "<t>"] [--ref <ref>] [--session <sid>] [--dry-run]
```
- `--kind name` = a name Anima decided · `--kind create` = a tool Forge made. Two kinds, **one** ledger → Anima can see what Forge created and vice-versa (dedup across *both*).
- **Idempotent**: identical `(kind, slug, purpose)` → no-op.
- **Atomic append** under a POSIX `mkdir`-lock (multi-session safe).
- `--alias` records rejected runner-ups / synonyms → improves future purpose-matching.

## Event schema (JSONL line)
```json
{"ts":"…Z","kind":"name|create","slug":"…","type":"skill|command|agent|…","by":"anima|forge",
 "purpose":"…","aliases":["…"],"location":"…","project":"…","rationale":"…","ref":"…","session":"…"}
```
`ts · kind · slug · type · by · location · project` always present; the rest are populated only when supplied.

## Consumer wiring (the DRY loop)
- **Anima** — §5 (before deciding): `lookup --purpose`; DoD (after deciding): `record --kind name`.
- **Forge** — step-1 DRY-probe: `lookup --purpose`; step-8 (after a successful write): `record --kind create`.
- **No double-record**: Anima records the `name`, Forge records the `create` — distinct kinds for the same slug are the two faces of one artifact, not a duplicate.

## Bounds & non-goals
- **Machine-local working-memory** (like the CEL ledger + `dogfood-cycles.jsonl`) — NOT a committed governance record; per-machine, gitignored, rebuildable.
- **Advisory, not a gate**: `DUP-RISK` informs the decider; it never hard-blocks (a deliberate near-name/variant is still the decider's call, per `naming-authority`).
- **Not a namespace scanner** — it records *decisions*, complementing (not replacing) Anima's live `Grep` and Forge's live PR-probe. Both layers run.

## Portability
POSIX Bash 3.2 + `jq` only (no associative arrays / no `${var^^}`). No org-specific content — Layer-Purity clean, promotion-eligible. Exit codes ([C06]): `0` success · `1` usage/validation · `2` setup (jq missing).
