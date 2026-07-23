---
name: memory-gateway
description: Use when creating, updating, superseding, archiving, reading, searching, or walking the persistent memory corpus. The ONE crash-safe writer to memory — route every memory mutation through it instead of editing topic files directly, so identity-dedup, atomic forgetting (supersede archives the old fact in the same op), and write-ahead crash recovery are guaranteed.
version: 1.0.0
author: MAOS (ADR-013 / EKO-116)
---

# Memory Gateway

## Purpose

`bin/memory-gateway` is the **single front-door** to the persistent memory corpus. It replaces ad-hoc `Edit`/`Write` on topic files, which silently allow three failure modes the gateway makes structurally impossible:

1. **Identity collision** — two facts written to the same canonical identity. The gateway dedups on `(type, normalize(name))`.
2. **Failure that never happens** — a superseded fact left live next to its replacement. The gateway's `update --supersede` **archives the old fact in the same operation** (the E6 mutation-hook).
3. **Torn corpus after a crash** — a mutation interrupted mid-write. The gateway uses a 5-stage write-ahead log and **completes any pending transaction before serving any verb**.

**Ownership rule:** the gateway *owns* corpus mutation. Other agents/skills do **not** write topic files directly — **they ask IT**. This is the deterministic skeleton; your judgment is the probabilistic muscle that decides *what* to remember.

## When to Use

Invoke the gateway whenever you would otherwise hand-edit memory:

- persisting a new lesson/fact/preference → `create`
- appending to an existing topic → `update <slug>`
- replacing a fact with a newer version (and retiring the old one) → `update --supersede`
- retiring a topic without destroying it → `archive`
- retrieving a topic → `read`
- finding topics by content → `search`
- exploring linked topics → `neighborhood`
- regenerating the index after out-of-band changes → `index`

## Identity & Slugs

- Canonical key = `(type, normalize(name))`; `type ∈ {user, feedback, project, reference}`.
- `normalize` = lowercase + non-alphanumeric runs → `-` + trimmed. So `"My Profile"`, `"my-profile"`, `"MY  PROFILE"` are the **same** identity.
- Slug = `<type>/<normalize(name)>` → `user/profile`. Type-qualified, so `user/profile` and `project/profile` are **distinct** addresses that never collide.
- `archive` is the ONLY removal verb; content is **never destroyed** — it is tiered into `<corpus>/.archive/…` and stays retrievable via `read <slug> --archived`. Purge/true-erasure is out of scope by design.

## The 7-Verb Contract

```bash
memory-gateway --corpus <dir> <verb> [args]     # or export MEMORY_GATEWAY_CORPUS=<dir>

create <name> --type T [--description D]                        # body on stdin
read <slug> [--archived]
update <slug>                                                   # append; delta on stdin
update --supersede --type T --name N [--supersedes <slug>] [--description D]   # new body on stdin
archive <slug>
search <query>
neighborhood <seed-slug> [--depth N] [--budget N]              # depth 1..3; >3 clamped
index
```

Supersession resolution (`update --supersede`):
- `--supersedes <slug>` given → **authoritative**: archives exactly that topic.
- omitted → matches the new fact's `(type, name)` against the **active** corpus only:
  - **0 matches** → plain create (nothing to forget).
  - **exactly 1** → archive-the-superseded + reindex + audit, all in the same atomic op.
  - **≥2 candidates** → **refuses** (`SUPERSEDE_AMBIGUOUS`) naming the candidates — never guesses which to archive.

## Output & Exit Codes

Exactly **one JSON envelope on stdout** per execution (human diagnostics go to **stderr only** — parse stdout deterministically):

```json
{"status":"ok|refused|error","verb":"<verb>","slug":"<slug|null>","data":{…}|null,"reason":{"code":"…","message":"…"}|null}
```

- `reason` is present iff `status != "ok"`. Refusal codes: `DEDUP_COLLISION`, `CONCURRENT_WRITER`, `BOUNDARY`, `SUPERSEDE_AMBIGUOUS`, `NOT_FOUND`, `USAGE`, `UNKNOWN_VERB`.
- **Exit codes** ([C06]): `0` success (incl. idempotent no-op) · `1` refused / usage-or-validation (detail is in the JSON, not a distinct code) · `2` setup (jq missing, corpus root absent).

## Examples

```bash
# remember a new preference (dedup-checked on identity)
printf 'Prefer squash-merge with --delete-branch.\n' \
  | memory-gateway --corpus ~/mem create "merge preference" --type user --description "git merge default"

# supersede it with a newer version — the old one is archived in the SAME op
printf 'Prefer squash-merge; keep the branch for release PRs.\n' \
  | memory-gateway --corpus ~/mem update --supersede --type user --name "merge preference"

# read the current fact; then list every archived version
memory-gateway --corpus ~/mem read user/merge-preference
memory-gateway --corpus ~/mem read user/merge-preference --archived

# find + walk
memory-gateway --corpus ~/mem search "squash"
memory-gateway --corpus ~/mem neighborhood user/merge-preference --depth 2
```

## Guarantees (why you can trust it)

- **Atomic forgetting** — supersede archives the superseded topic in the same operation; the corpus never shows a fact next to its own replacement.
- **Crash-safe** — a 5-stage WAL over an exclusive corpus lock; the next invocation completes any interrupted supersession *before* serving a verb, so reads never observe a half-applied state. `archive`/`create`/append use atomic temp→rename + fsync (any partial state is a benign orphan healed by `index`).
- **Concurrency-safe** — a mutating verb that cannot take the corpus lock **refuses** (`CONCURRENT_WRITER`) rather than clobber a peer's in-flight write.
- **Boundary-safe** — slugs that escape the corpus root (`..`, absolute) are refused (`BOUNDARY`).
- **Auditable** — every mutation appends one JSONL line (`verb`/`slug`/`ts`/`corpus`) to `${MEMORY_GATEWAY_DIR:-~/.claude/audit}/memory-gateway.jsonl`.

## Advisory Posture

This skill is **advisory-first**: it tells you *to route memory through the gateway* and *how*. It does not hard-block direct edits. If a direct edit is genuinely necessary (migration, repair), run `memory-gateway --corpus <dir> index` afterward to reconcile the index, and prefer the gateway for anything that mutates identity or supersedes a fact.

## References

- Spec: `docs/adrs/ADR-013-memory-crud-gateway.md`
- Implementation: `bin/memory-gateway`
- Tests: `tests/test-memory-gateway.sh`
- Sibling read-only pre-scan: `bin/memory-curator-sweep.sh` (ADR-012)
