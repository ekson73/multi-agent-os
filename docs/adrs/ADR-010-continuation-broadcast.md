# ADR-010 — Continuation-Broadcast: a structured back-pointer marker (not a breadcrumb TODO)

- **Status:** Accepted (built in this change — `bin/continuation-broadcast.sh` + postflight P3.6 + the `signoff` verb)
- **Date:** 2026-07-10
- **Deciders:** operator (Emilson) + Claude (Opus 4.8)
- **Origin:** operator `/enhance /deep-research Ultrathink` 2026-07-10 — "gerar handoff-prompt de continuidade … injetar o prompt de continuidade **onde for cabível** (tickets, docs, ADRs, changelogs, PRs, commits) para quando algum new-fresh-born-amnesic-agentic se deparar com o problema saber que tem pendências a serem continuadas."
- **Naming:** system-slug `continuation-broadcast` (COMP/machine register — descriptive-canonical, no soul-name per Anima §3.4). The operator-facing sign-off verb is Anima-named **`signoff`** (surfaces `/maos:signoff`; rejected runner-up `disembark` — best flight-family resonance but less self-describing to an amnesic agent than the literal operator gesture "sign-off/encerramento"). Operator may override (`[C-naming]`).

## Context

The operator's close-out ask has a **discovery** requirement that the existing machinery did not
satisfy. `postflight` already, at session end:

- **P2.5 TICKET-SYNC** files a bounded **continuation ticket** (the backlog anchor), and
- **P3 HANDOFF** emits an ai-agnostic **continuation seed** (the resume packet),

so the pending work is **tracked** (`ticket-sync-protocol.md` + `continuation-seed-contract.md`).
But a fresh amnesic agent — or a *different* mind days later — who later opens **a commit, a PR,
or a doc** has **no reason to know the seed/ticket exist**. The continuation is tracked, yet
**not discoverable from where the next agent actually arrives**. Per the locus master principle,
*"what is not seen is not remembered."*

The obvious fix — "leave a note where they'll find it" — collides head-on with
`protocols/exit-hygiene.md`, whose anti-patterns explicitly forbid *"Fix next session"* notes and
*"accepting incremental disorder — it's just one more TODO"* (entropy is exponential; one TODO
becomes five becomes tech-debt). And `postflight` anti-pattern #2 restates it. So a naive
free-form breadcrumb is **prohibited by our own governance**. This ADR resolves the tension.

| Prior-art (what exists) | Why it does NOT close the discovery gap |
|---|---|
| `continuation-seed-contract` (P3 seed) | the **payload**, but lands only in the seed file + clipboard + spawned session — not in the artifacts a next agent lands on |
| `ticket-sync-protocol` (P2.5 continuation ticket) | the backlog **anchor**, but a next agent reading a commit/PR/doc isn't looking at the backlog |
| `exit-hygiene` Delegation gate | *requires* "registered with traceability" — but doesn't say **where** the trace should be discoverable |
| free-form "TODO next session" | **forbidden** by exit-hygiene (unbounded, unstructured, accumulates) |

## Decision

Add **P3.6 BROADCAST**: inject a **bounded, structured, idempotent back-pointer MARKER** — a
*discovery pointer* to the ONE canonical continuation seed/ticket — into selected work artifacts.
Executor: `bin/continuation-broadcast.sh` (deterministic, `--dry-run` default). Full shape/sinks/
guardrails: `skills/postflight/references/continuation-broadcast-protocol.md`.

**The reconciliation claim (the crux):** a structured back-pointer marker is **NOT** the breadcrumb
TODO exit-hygiene forbids — it is exit-hygiene's *own* **"registered with traceability"** (Axiom 4
proactive-resolution + the Delegation gate) **surfaced at the point of future contact**. It differs
from a forbidden TODO on every axis exit-hygiene cares about:

| exit-hygiene's objection to TODOs | how the marker answers it |
|---|---|
| unstructured prose | **structured** — sentinel-delimited (`MAOS-CONTINUE:START/END`, matched as whole lines) + a machine-readable JSON payload |
| a promise with no backing | a **back-pointer** to a **verified** referent — the executor confirms the seed file **exists** before emitting (an unfound `--seed` is dropped); the ticket is caller-registered by P2.5. The marker never points at a phantom. |
| accumulates ("one more TODO") | **byte-idempotent** — a re-run *upserts* (replaces the one sentinel region) and the block carries **no timestamp**, so a re-apply on unchanged inputs is a true no-op (identical bytes); a marker never accumulates nor churns |
| unbounded, anywhere | **bounded** — one block per artifact; **ADR/decision records refused** (case-insensitive, incl. MADR `decisions/`); symlinks refused; only caller-named files under `--scope all` |
| duplicates the work description | **pointer only** — names the seed/ticket; duplicates no content (DRY) |
| left even on finished work | **nothing-verifiable-to-point-at ⇒ noop**; and the block's human line **self-declares stale** ("if `<KEY>` is resolved/closed, delete this block") so a reader can retire it on sight |

**Scope gate** (honoring *"onde for cabível"* without weaponizing it):

- **`conservative` (default)** = **commit-trailer + PR-body** — the two places a continuation
  naturally belongs, both of which already carry session state (exit-hygiene-safe).
- **`all` (opt-in)** = the above **plus caller-named `--file` targets** (docs, CHANGELOG
  `[Unreleased]`) — broader amnesia-coverage on demand. **The caller (agent), not the script,
  decides which files are *cabível*** — the script only *enforces* safety (idempotent · ADR-refused
  · sanitized · dry-run-default). Judgment stays with the agent; safety with the deterministic layer.

**ADR / decision records are refused.** A decision record is immutable and is not a transient
worklist — a continuation marker does not belong in it (the anti-theater-honest reading of *cabível*:
an ADR is not an *appropriate* place). The executor refuses, **case-insensitively**, any path under
`adrs/`, `adr/`, or `decisions/`, any `ADR-*.md`/`adr-*.md` basename, and any MADR numbered basename
(`0001-*.md`). It also **refuses symlink targets** (a symlinked name could otherwise redirect the
write past the refusal). This is best-effort-by-path, not a semantic guarantee — see the residual
below.

**Corruption-safe by construction.** The in-file upsert is **fail-closed**: it acts only on a
*well-formed* single sentinel region (exactly one correctly-ordered `START…END` pair, whole-line
matched). Any malformed state — a dangling `START`, a duplicated or out-of-order sentinel (e.g. a
hand-edited or merge-mangled PR body) — makes the executor **refuse and leave the artifact
untouched** rather than risk a mass-delete-to-EOF or a duplicated block. Regression-locked by the
test suite.

**Opt-in, backward-compatible.** BROADCAST is **off by default on `postflight`** (existing behavior
unchanged) — enabled via `--broadcast[=conservative|all]`. It is **default-ON only in the new
`signoff` verb**, whose whole purpose is the operator's "close out + leave breadcrumbs" gesture.

## Consequences

**Positive**
- The tracked continuation becomes **discoverable** where the next agent lands (commit/PR/optionally docs) — the operator's core ask, without violating exit-hygiene.
- Deterministic + byte-idempotent + dry-run-default + kill-switch (`MAOS_BROADCAST=0`) + **fail-closed on malformed input** → safe to compose into the autonomous close-out; verified by `bin/tests/continuation-broadcast.test.sh` (20 assertions incl. idempotency, the malformed-sentinel fail-closed, payload-injection, symlink, and unbacked-seed regressions).
- DRY: reuses the P3 seed + P2.5 ticket (points at them; reinvents neither).

**Negative / mitigations**
- A marker is one more thing in a commit/PR. *Mitigation:* one bounded block, byte-idempotent (no accumulation, no churn), and only when a **verified** pendency exists (noop otherwise).
- **Stale-marker in a durable `--scope all` doc is the sharpest residual.** commit-trailer and PR-body staleness is self-limiting (immutable history / PRs close), but a marker left in a *durable doc* after the continuation resolves would read as a live pendency. *Mitigations shipped:* the block's human line **self-declares stale + instructs its own removal** once `<KEY>` is closed, and `--scope all` is **opt-in / experimental** for durable docs (the safe default is `conservative` = commit-trailer + PR-body). *Deferred (tracked, not built here):* a `--retract` that removes markers when the continuation closes — the mechanical complement to the self-declaration.
- **`--scope all` semantic-appropriateness rests on agent discretion; only decision-records are mechanically excluded.** The deterministic layer prevents *accumulation / immutable-doc mutation / secrets / malformed-corruption* — it does **not** judge *wrong-file*. *Mitigation:* `conservative` is the defensible default; `all` is the deliberate opt-in whose file choice is the agent's (audited) judgment, bounded by ADR-refusal + caller-named-only + dry-run-default.

## Rejected alternatives

- **(a) Free-form "TODO: continue X next session" breadcrumb** — the naive fix; **forbidden** by
  exit-hygiene (unbounded, unstructured, accumulating). Rejected outright.
- **(b) Ticket/seed only (status quo — no marker)** — leaves the continuation tracked but
  **undiscoverable** from the artifacts a next agent lands on (the exact gap). Rejected: it is the
  problem.
- **(c) Broadcast into every artifact by default, including ADRs** — maximal discovery but
  weaponizes *"cabível"* into entropy + mutates immutable decision records. Rejected: `conservative`
  default + ADR-refusal is the safe middle.
- **(d) A new standalone marker file (`CONTINUATION.md`)** — a single well-known file. Rejected:
  it re-introduces a discovery problem (the next agent must know to open it) and duplicates the
  seed; the marker-at-point-of-contact + the existing seed/ticket already cover it (Gordian: no new
  artifact where existing sinks + a pointer suffice).

## Related

- `skills/postflight/references/continuation-broadcast-protocol.md` — the marker SSOT (shape/sinks/guardrails).
- `bin/continuation-broadcast.sh` + `bin/tests/continuation-broadcast.test.sh` — executor + tests.
- `skills/postflight/SKILL.md` **P3.6 BROADCAST** — the phase that invokes it (opt-in).
- `commands/signoff.md` + `skills/signoff/SKILL.md` — the sign-off verb (broadcast default-ON).
- `protocols/exit-hygiene.md` — the anti-breadcrumb rule reconciled here.
- `skills/postflight/references/{continuation-seed-contract.md,ticket-sync-protocol.md}` — the SSOT the marker points at.
- `skills/postflight/references/close-out-hunt-checklist.md` — the P2 hunt that determines whether a pendency (hence a broadcast) exists.
