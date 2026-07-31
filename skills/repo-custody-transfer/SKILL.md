---
name: repo-custody-transfer
version: "0.6.3"
allowed-tools: [Task, Read, Write, Edit, Bash, Skill, Grep, Glob, WebFetch]
description: |
  Transfer CUSTODY of a repository between git hosts (Bitbucket Cloud → GitHub first-class;
  soul-name Translatio) as a reversible, resumable, idempotent 5-phase cutover under an HONEST
  FIDELITY CONTRACT — not a "migration" pretending everything crosses: T1 git-exact
  (commits/branches/tags/LFS) · T2 translated (pipelines→Actions, permissions→teams) · T3
  archived-not-recreated (PRs/issues/builds → artifacts + GAP report) · T4 excluded (secret
  VALUES never cross). HALTS on an unsupported axis with a ranked Impediment Report instead of
  improvising; flags a host-pair where BOTH sides hold unique refs as SPLIT-BRAIN (never
  `push --mirror`, never force-push); council-before-HITL autonomy; composes existing
  primitives. Use when a repo must change git hosts with history AND governance intact — e.g.
  "migrate <repo> from Bitbucket to GitHub", "cutover this repo to GitHub", "transferir a
  custódia deste repo", "move repo host preserving history/branches/tags/PRs".
---

# repo-custody-transfer — *Translatio*

> **Soul-name**: **Translatio** (display-only; the machine slug is `repo-custody-transfer`).
> Latin *translatio* = "a carrying across". Two medieval senses converge here: *translatio
> imperii* ("transfer of rule" — the governance: permissions · protections · CI authority) and
> *translatio studii* ("transfer of learning" — the history: commits · PRs · decisions). A host
> cutover transfers **both**, or it is not done. Named by `anima` (`[C-naming]`, 12/12).
> **Rejected runner-up**: `git-host-migration` — "migration" is precisely the false-fidelity
> promise this tool exists to refuse.
> **Cross-link slug**: `[[repo-custody-transfer]]`

## §0 — BEING > Rules
Serves the operator's intent. If a phase/gate obstructs helping NOW, skip it, log
`Skipped <phase> — BEING > Rules`, proceed.

⛔ **NEVER skippable** (the safety floor — §0 cannot reach any of these): **T4** (secret values never
cross) · the **§9.0 unconditional no-force/no-destructive-push rule** · the **Blocking-Gate** itself
(§4, incl. the P1–P19 trip-wires) · **§5.0** freshness · **§5.1** ancestry classification · **§5.2**
non-FF response · **§3.1** write-once baseline + subtractive-only rollback · the **Phase-4
point-of-no-return**.

**§0 is presentation-only, never a safety bypass** (the shape `council-gate` §0 already hardened):
skipping a *format*, a *report style*, or a *ceremony* is fine. A skipped or un-evidenced **safety
gate** does **not** become "passed" — it sets its predicate conjunct to **`false`** (fail-safe),
which means: the classification degrades to **INVESTIGATE**, the action **leaves the autonomous
band** (§7), and it routes to HITL. There is no path by which §0 authorizes a push, a deletion, or a
Phase-4 seal that a gate did not clear.

*Why this list is explicit*: two independent red-teams found the same hole — §5.0 and §3.1 declared
themselves ⛔ in their own headings but were **absent from this list**, so the entire fix for both
BLOCKING data-loss holes was skippable by this very clause. Worse, skipping §5 means nothing is ever
*classified* SPLIT-BRAIN, which disarmed the one force-push rule that **was** listed.

## §0.1 — Requirements (external dependencies)

| Dependency | Used for | If absent |
|---|---|---|
| `git` ≥ 2.30 | all T1 operations (refspec push, `ls-remote`, ref comparison) | hard stop — no cutover possible |
| `gh` (authenticated, `repo` scope) | destination repo create · `[C18]` baseline · protections · teams · secret **names** | Impediment Report → HITL |
| Bitbucket API access (host gateway **or** an app-password/token) | T3 extraction (PRs/issues/builds) · T4 secret-name inventory · source archive | T3 degrades to a declared GAP |
| `git-lfs` | only when the source uses LFS (`.gitattributes`) | Impediment Report if LFS present |
| `gitleaks` | pre-commit/pre-push scan of produced artifacts | warn; do not skip silently |
| `jq` | parsing host API JSON in the ledger/report | fall back to inline parsing |
| a secret manager (e.g. `op`) | T4 fresh provisioning at the destination | Phase 3 halts — ⛔ never inline a value |

Probe **before** assuming any of these (`environment-capability-reconnaissance`), and apply the
§4 positive-control rule before reporting one as absent.

## §0.2 — ⛔ BOOTSTRAP (process start — runs BEFORE Phase 0, before ANY ledger access)

This is the **first executable step of the run**, ahead of every phase. It exists because `RUN_ID`
is the **owner** of the ledger's per-RUN fields (§6.0 · P19), and an owner must exist before the
thing it owns is read or written.

⛔ **Why it cannot live at its point of use (§5.1).** §6.0's Phase-0 rule makes *"read the ledger"*
the **first** action, and mandates writing a phase entry **before** entering a phase. §5.1 runs at
the drift-detector, i.e. **after** Phase 0. So a `RUN_ID` assigned there is assigned **too late**:

- a Phase-0 writer with `RUN_ID` unset persists `"run_id":""`, and a pre-assignment reader then
  compares `'' == ''` and **MATCHES** — adopting another run's `drift_verdict` as its own with
  **P19 SILENT** (measured: trace 13). Set-vs-empty already fails closed; **empty-vs-empty** is the hole.
- the format gate below likewise cannot protect a ledger path that was already built from an
  unvalidated value. A validation that runs after the sink it guards is decoration.

```sh
# ⛔ The run-id MUST be collision-proof, NOT a timestamp: `date +%s` twice in a row returns the
#    IDENTICAL value (measured), so two concurrent classifications in one checkout would share a
#    namespace — re-opening the exact contamination the per-run path exists to prevent.
#    `date +%s%N` is NOT portable (BSD/Darwin date lacks %N unless coreutils is installed).
# ⛔ FAIL CLOSED on entropy loss — if uuidgen AND od both fail, the suffix pipeline yields EMPTY
#    and `$$-` would pass the non-empty+shape checks: a reused PID matching stale ledger state.
# ⛔ ORDER IS LOAD-BEARING — generate-if-unset FIRST, validate SECOND. A `${RUN_ID:?…}` guard placed
#    ABOVE the assignment aborts unconditionally and makes the assignment UNREACHABLE (the fix
#    wearing the defect's clothes — caught by coderabbit on PR #296 round 2). `:-` also PRESERVES a
#    caller-supplied RUN_ID, which a bare `=` would silently clobber.
_RUN_ID_SUFFIX="$( (uuidgen 2>/dev/null || od -An -tx1 -N4 /dev/urandom) | tr -d ' -' | head -c 8)"
[ -n "$_RUN_ID_SUFFIX" ] || { printf 'FATAL: no entropy source (uuidgen + od both failed) — RUN_ID suffix empty (§0.2 · P19)\n' >&2; exit 1; }
RUN_ID="${RUN_ID:-$$-$_RUN_ID_SUFFIX}"
unset _RUN_ID_SUFFIX
: "${RUN_ID:?RUN_ID must be set before any ledger read or write (§6.0 · P19)}"
# ⛔ VALIDATE THE *FORMAT*, not merely non-emptiness — `:?` only proves the value EXISTS. RUN_ID is
#    caller-supplyable (the `:-` above preserves it by design) and is then interpolated into BOTH a
#    git ref namespace AND a filesystem path, so a hostile value reaches two different sinks whose
#    defences are NOT equal:
#      • the REF sink is already fail-closed — measured: `git update-ref` rejects `../../escape`,
#        `x/../../y` and `a b` with rc=128 (⇒ P16 clause 1 HALTs), and `git check-ref-format` REJECTs
#        all three. Traversal cannot create a ref outside the quarantine.
#      • the PATH sink has NO such check — measured with the §5.1 expression verbatim: RUN_ID
#        `x/../../../VICTIM/pwned` WROTE `VICTIM/pwned.txt` **outside $LEDGER_DIR**, and
#        `../../../VICTIM/prod-secrets` landed a file next to a decoy secret. Arbitrary-path write
#        from a variable the skill invites the caller to set.
#    ⚠️ `-flag` is accepted by BOTH sinks (measured: ref created, ledger file written) — it is not a
#    traversal, it is an ARGUMENT-INJECTION seed for any later `git`/`rm`/`find` that takes the name
#    positionally. Non-emptiness would pass it; a format gate does not.
#    ⇒ Constrain to the shape the generator itself produces (`<pid>-<hex8>`): alphanumerics, `-`,
#    `_`, `.` only, never leading `-` or `.`, no slash/space/control/traversal. Bounded length keeps
#    it inside ref-name and PATH_MAX limits. Fail CLOSED — an invalid run-id aborts before the first
#    ledger read, because the alternative is a write whose destination the caller chose.
case "$RUN_ID" in
  ''|-*|.*)                     RUN_ID_BAD=1 ;;   # empty, or leading dash/dot
  *[!A-Za-z0-9._-]*)            RUN_ID_BAD=1 ;;   # slash, space, control, traversal, glob
  *)                            RUN_ID_BAD=0 ;;
esac
[ "${#RUN_ID}" -le 64 ] || RUN_ID_BAD=1
[ "$RUN_ID_BAD" -eq 0 ] || { printf 'FATAL: RUN_ID must match [A-Za-z0-9._-]{1,64} and not start with - or . (§6.0 · P19)\n' >&2; exit 1; }
export RUN_ID                            # every later phase CONSUMES this value; none re-derives it
```

⛔ **Downstream sites consume, never re-derive.** §5.1 (`QUAR`) and §6.0 (`$DST_PINNED`, the ledger
path) read `$RUN_ID` as already-valid. A second `${RUN_ID:-…}` anywhere would mint a **different**
id than the one Phase 0 persisted, and the run would then read its own earlier rows as *another
run's* (P19 mismatch) — self-inflicted amnesia dressed as a safety check.

## §1 — The premise (why "custody", not "migration")

A host cutover is **not a copy**. Three empirical facts force the reframe:

1. **Not everything crosses.** There is no supported importer that recreates Bitbucket **Cloud**
   PRs/issues/reviews as native GitHub objects (`gh gei`/`bbs2gh` cover Bitbucket **Server/DC**).
   Promising T1 fidelity on those axes is theater (`anti-theater` R2/R4).
2. **Secret values must NOT cross.** Bitbucket secured variables are unreadable by design. The
   only correct move is names-only inventory → fresh provisioning from the secret manager →
   rotation. ⛔ Any flow claiming to copy secret values is disqualified (Guardrails Não-Negociáveis).
3. **The destination may already hold divergent history.** Empirically (2026-07-29) 3 of 9
   repos had **bidirectional** divergence — source ahead on `main`/`develop` AND destination
   holding unique commits + tags. A `push --mirror` would have destroyed them irreversibly.

⇒ The unit of work is **custody**: the history (*studii*) **and** the governance (*imperii*),
carried across reversibly, with an explicit admission of what cannot follow.

## §2 — Fidelity contract (declare the tier; never silently promise T1)

| Tier | Axes | Mechanism | Honest status |
|---|---|---|---|
| **T1 git-exact** | commits · branches · tags · LFS objects | explicit refspec push (**never** `--mirror` on split-brain) | byte-identical, verifiable |
| **T2 translated** | pipelines → Actions · permissions → teams · branch protections · webhooks | semantic re-authoring + diff report (OIDC-first) | equivalent-by-review, not identical |
| **T3 archived** | PRs · issues · comments · reviews · build history | host-API extraction → JSONL + rendered MD artifacts | queryable **artifact**, NOT a native object |
| **T4 excluded ⛔** | secret **values** | names-only inventory + provision fresh + rotate | never crosses, by construction |

**Rule**: every axis in scope MUST be assigned a tier, in writing, before Phase 2. An axis with
no tier is an **impediment** (§4), not an assumption.

## §3 — The 5 phases (reversible · idempotent · resumable)

Every phase: re-runnable to convergence (no duplication), independently rollback-able, and
records its state in the **custody ledger** (§6) so a cold agent resumes from artifacts alone.

| # | Phase | Does | Rollback | Autonomy |
|---|---|---|---|---|
| **0** | **RECON** | inventory both hosts · **drift-detect (§5)** · classify (greenfield / pipeline-heavy / SSOT / split-brain) · blast-score · assign tiers · pick pilot | n/a (read-only) | **autonomous** |
| **1** | **DRY-RUN** | simulate into a scratch target · verify T1 exactness · translate pipelines (proposal only) · extract T3 sample · inventory secret **names** | discard scratch | **autonomous** |
| **2** | **CARRY (T1)** | capture the write-once `carry_baseline` → explicit-refspec push · **dual-remote coexistence** (source stays authoritative) | mode per §3.1: empty baseline → delete the destination repo; non-empty → delete ONLY refs absent from the baseline | council-gated |
| **3** | **FLIP (T2/T4)** | CI/Actions live · protections · teams · fresh secrets provisioned · webhooks repointed | revert CI to source host | council-gated |
| **4** | **SEAL** | verify parity · source host **read-only/archived** (⛔ never deleted) · docs/ADR/CHANGELOG PRs | re-open the source host | council-gated |

**Point of no return = Phase 4 only.** Everything before it is reversible by design.

### §3.1 — ⛔ Rollback is SUBTRACTIVE-ONLY (a rollback must never destroy)

A naive Phase-2 rollback ("delete the pushed refs") **cannot distinguish a ref it created from a ref
that was already there** — so on any non-empty destination the rollback is itself a data-loss event.
Therefore Phase 2 MUST, in order:

1. **Snapshot** the destination's full ref→sha map from the wire **before the first push**, and
   persist it in the ledger as the **write-once baseline** (`carry_baseline`, with `captured_at`).
2. Push with an **explicit refspec** (never `--mirror`, never `+`-force, never a wildcard that can
   clobber tags).
3. On rollback, delete a ref **only if** it is absent from the **baseline**. A ref present in the
   baseline is **out of scope for rollback, permanently** — even if the carry also wrote to it.
4. If the baseline is missing or unverifiable ⇒ **rollback is forbidden**; HALT and emit an
   Impediment Report (§4). A rollback you cannot bound is not a rollback.

**No-baseline ⇒ no-push.** A carry that did not snapshot first has no safe reverse and must not run.

#### ⛔ The baseline is WRITE-ONCE per cutover — a re-run MUST NOT re-derive it

§3 makes Phase 2 **idempotent** (re-runnable to convergence) and §5.0 forbids "a cached/earlier
read". Read together and applied to rule 1, those two force a re-run to **re-derive** the snapshot —
at which point the re-derived map *already contains the refs the previous run created*, rule 3 puts
them permanently out of rollback scope, and the rollback silently degrades to a **no-op**. Reproduced
2026-07-29 in a sandbox: run #1 baseline `{peer}` → rollback correctly deletes `main`, keeps `peer`;
run #2 re-derived baseline `{peer, main}` → rollback keeps **both** ⇒ the carry is irreversible and
`§3` "Point of no return = Phase 4 only" becomes false, with **no trip-wire firing** (a snapshot
*exists* — it is merely the wrong one).

Therefore the freshness questions are **distinct and must not be conflated** — exactly **one** of them
is a per-run read; the other two are first-touch truths read **once, ever**:

| Question | Needs | Source |
|---|---|---|
| "What is the drift **right now**?" (classification, §5) | **current** truth | same-run `ls-remote` — re-read every run |
| "What did the **destination** hold **before I touched it**?" (rollback bound, §3.1) | **first-touch** truth | the write-once `carry_baseline` — re-read **never** |
| "What did the **source's tag namespace** hold before my **classifier** touched it?" (contamination bound, §5.1/P15) | **first-touch** truth | the write-once `src-tags-before.txt` — re-read **never** |

⛔ **Row 3 is a first-touch question, NOT a drift question.** Re-deriving it over contaminated state
folds the contaminant *into* the baseline and **launders the P15 halt** — measured: run 1 fires
correctly, run 2 (same phase retried from the top) reports **clean** while the source still carries the
foreign tag, and nothing in the file forbade the re-derivation. A delta test is only as trustworthy as
its baseline; inverting a check to a delta **imports** the baseline-integrity problem §3.1 had already
solved one section up.

Rules: the baseline is captured **once per cutover** and is immutable for its lifetime; every
re-run **reuses** it verbatim from the ledger; a re-derived baseline is **not** a baseline (P9); and
a cutover whose baseline is absent while `carry_count > 0` has **lost its reverse** ⇒ HALT, report,
and treat reversibility as forfeited rather than pretend it exists.

#### The baseline's emptiness selects the rollback MODE (ref-level vs repo-level)

Subtractive ref deletion is **not universally available**: a host refuses to delete the ref that
`HEAD`/the default branch points at. Measured 2026-07-29 — with a **non-empty** baseline the carried
ref deletes cleanly (`HEAD` sits on a baseline ref); with an **empty** baseline the carried ref
*becomes* the default branch and `--delete` is **rejected**. So the mode follows the baseline:

| Baseline | Rollback mode | Why it is safe |
|---|---|---|
| **empty** (destination created by this cutover) | **repo-level**: delete the destination repository | nothing pre-existed — by definition zero collateral. Confirm the destination was absent with a second instrument (P7) **before** relying on this. |
| **non-empty** | **ref-level subtractive** (rules 2–3 above) | `HEAD` rests on a baseline ref, so the carried refs delete cleanly |

⛔ **Never repoint `HEAD`/the default branch to force a ref deletion.** It mutates destination state
the baseline does not cover (and can leave a dangling `HEAD`) — a rollback that mutates beyond its
bound is the §3.1 violation, not a workaround. If ref-level is blocked and repo-level does not apply
(non-empty baseline whose `HEAD` moved), the carry is **not reversible by this skill** ⇒ HALT +
Impediment Report with the residual state named explicitly.

## §4 — BLOCKING-GATE + Impediment Report (first-class capability)

### §4.0 — The trigger is PRIMARY (deterministic), not SECONDARY (self-scored)

"An axis has no supported path" is a judgement — and left as one it is self-scored by the very
agent that wants to proceed, which is the self-exemption gradient
`red-teaming-mandatory-trigger` exists to remove. So the gate fires on **deterministic
trip-wires first**; the judgement only *widens* coverage, never gates it alone:

**PRIMARY (mechanically checkable · HALT regardless of any confidence):**

⚠️ **Honest scope of "deterministic"** — each trip-wire below is a **shell-checkable predicate**
(deterministic *as specified*, and auditable after the fact from the ledger), but **nothing ships that
runs them**: this skill is a single `SKILL.md` (verified — `git ls-tree` on the skill dir returns
`SKILL.md` alone, with a positive control reaching `bin/`). So execution is **agent-performed**, and
"did P2's positive control fail?" is not falsifiable from outside. That is materially better than a
judgement call — the predicates are named, uniform, and checkable by anyone auditing the ledger — but
it is **not** an `f=0` gate the way `bin/check-layer-purity` or `bin/convergence-guard` are. Closing
that distance is **B6** (queued): a `bin/` verifier that emits the P-table as machine-readable
verdicts. Until then, treat these as *deterministic in specification, self-reported in execution*.

| # | Trip-wire (mechanically checkable) |
|---|---|
| P1 | an in-scope axis has **no tier assigned** in writing (§2 rule) |
| P2 | drift classification derived without a same-run wire read, **OR** a §5.0 positive control that FAILED, **OR** without §5.0 step-0 **subject confirmation** (which tree/branch/remote was actually read) — ⛔ a controlled probe of the **wrong subject** returns a well-formed negative that is indistinguishable from a sound one; reach is not aim |
| P3 | a push would run without a §3.1 write-once `carry_baseline` |
| P4 | the drift verdict is **SPLIT-BRAIN** or **INVESTIGATE** (never autonomous) |
| P5 | a T4 secret **value** would be read, printed, or written anywhere |
| P6 | a required §0.1 dependency is absent **and** its absent-behavior is `hard stop` |
| P7 | the destination read returned empty **without** a second-instrument confirmation |
| P8 | Phase 4 (the point of no return) without an Elenchus red-team CLEARED |
| P9 | `carry_baseline.captured_at` is **not** strictly earlier than the first push of this cutover — i.e. the baseline was re-derived after a carry (mechanically: baseline contains a ref the ledger records this cutover as having created) |
| P10 | `carry_count > 0` **and** `carry_baseline` absent/unreadable — reversibility already forfeited; never silently proceed as if reversible |
| P11 | the class was derived **without** a §5.1 per-ref `merge-base` ancestry run (i.e. from `ls-remote` ref lists alone) — `ls-remote` proves existence, never uniqueness |
| P12 | the destination holds a commit **disjoint** from the source's root (`merge-base` finds no common ancestor) — includes every `--add-readme`/auto-init destination ⇒ SPLIT-BRAIN, never CLEAN CARRY |
| P13 | a push returned **non-fast-forward / fetch-first** — the classification was wrong; ⛔ never clear it with force (§5.2) |
| P14 | the ledger at `$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody/<slug>.json` (§6.0 — **derived**, never the literal `.git/…`) is absent while a push is contemplated — no ledger ⇒ no baseline ⇒ rollback forbidden ⇒ out of the autonomous band |
| P15 | the source-tag snapshot is **absent** while classification has run, **or** it was **re-derived** (not write-once), **or** the source's real tag namespace **changed**, **or** a `_dst` leftover exists. ⛔ **Primary clause = SET DIFFERENCE, not a marker test** — `diff <(git for-each-ref --format='%(refname)' refs/tags \| sort) "$LEDGER_DIR/<slug>.src-tags-before.txt"` non-empty ⇒ the classifier mutated the source ⇒ HALT. **Secondary clause** (catches an *uncleaned quarantine*, which the diff cannot see): `git for-each-ref refs/tags refs/rct/_dst \| grep -q _dst`. See §5.1 for why the marker test alone is blind. |
| P16 | the §5.1 **fetch** exited non-zero, **OR** the wire and quarantine ref **SETS** differ — ⛔ a **set difference on ref NAMES**, never a count (a count is a *signature*: one **stale** ref + one **missing** ref cancel to the right total) · ⛔ with peeled `^{}` lines filtered (`ls-remote` emits an extra peeled line per **annotated** tag that `for-each-ref` does not — unfiltered, this halts every repo with a release tag) · ⛔ over a **per-repo + per-run** quarantine path (a fixed shared path makes a leftover indistinguishable from a fetched ref). A partial fetch can exit 0, so both clauses are needed — ⛔ **an empty quarantine is `unknown`, never "no divergent refs"**. Without this, a dead fetch iterates zero refs, invokes `merge-base` zero times, and the worst-ref-class over an empty set is **vacuous** ⇒ every source ref reads *"exists only on source"* ⇒ **CLEAN CARRY on the autonomous path**. **The only fail-OPEN found in this artifact.** |
| P17 | a per-ref `dst_sha` is read **by re-resolving the ref** instead of from the pre-loop pinned file, **OR** a pinned sha is empty/absent while its ref was present at the P16 gate, **OR** the pinned file is written to a **per-repo (not per-run)** path or without an atomic `.tmp`+`mv` publish, **OR** the cleanup sweeps beyond `$QUAR` — the gate proved the input existed *at the gate*, nothing holds it *until use*; an absent name reads as *"exists only on source"* ⇒ **CLEAN CARRY** while the destination objects are intact (§5.1 TOCTOU note). An absent pinned sha is a **MISSING MEASUREMENT**, never "no destination ref" |
| P18 | an impediment is **written in this run** without `reported_by` / `reported_at` (ISO 8601 + offset) — ⛔ **write-time only**; a *pre-existing* impediment lacking them is a MISSING MEASUREMENT, never a P18 halt (§6.0) — provenance would then need reconstruction from message logs, which fails exactly where a compaction-inherited claim **reads complete** (§6.0) |
| P19 | the ledger is read **without** comparing its `run_id` to this run's `$RUN_ID`, **OR** a per-RUN field (`drift_verdict` · `dst_pinned_path`) from a **mismatched** run is used as this run's own, **OR** `carry_count` (per-**CUTOVER**, monotonic) is **discarded** on a `run_id` mismatch or its **absence read as `0`** instead of `unknown ⇒ >0`, **OR** `dst_pinned_path` is **followed as an address** instead of `$DST_PINNED` being recomputed, **OR** the ledger is written **non-atomically** (`>` instead of `.tmp`+`mv`), **OR** an **unparseable** ledger is treated as *absent* — ⛔ a clobbered `drift_verdict` moves a repo from the HITL row into the **unattended** row with no agent disobeying anything, and a clobbered `carry_count` **disarms P10** (its condition became *someone else's*, never false). Corrupt ≠ absent: absent fails closed, corrupt was **silent** (§6.0), **OR** `RUN_ID` is used **without validating its FORMAT** — `:?` proves only that the value EXISTS, and the value is caller-supplyable by design (`:-`) and reaches **two sinks with unequal defences**: the ref sink is already fail-closed (measured: `git update-ref`/`check-ref-format` REJECT `../../escape` · `x/../../y` · `a b`), the **path** sink has none (measured with §5.1's expression verbatim: `x/../../../VICTIM/pwned` WROTE a file **outside `$LEDGER_DIR`**) ⇒ arbitrary-path write from the variable the skill invites the caller to set; and `-flag` passes **both** sinks, seeding argument-injection into any later positional `git`/`rm`/`find`. ⛔ Validate the SHAPE (`[A-Za-z0-9._-]{1,64}`, never leading `-`/`.`) before the first ledger read — a non-emptiness check is not a format check |

Any P1–P19 true ⇒ **HALT + Impediment Report**, no discretion. Cheap to check, impossible to
argue with.

#### ⛔ Trip-wire design rule: never key on a property the failure mode is defined by LACKING

Three instances in this artifact's own history, each caught only by an independent red-team:

| Guard | Was conditioned on | The failure it had to catch |
|---|---|---|
| the force-push prohibition (pre-§9.0) | the verdict **SPLIT-BRAIN** | a case the classifier **never labelled** |
| §0's never-skippable list (pre-v0.4.0) | gates being **listed** | the two ⛔ gates that **weren't** |
| **P15** (pre-v0.4.3) | a `_dst` **marker** | a contaminant documented as carrying **no marker** |

Each was a guard whose trigger required the very thing whose absence *was* the bug. When writing a
trip-wire, ask: *"what does the failure look like, and does my check depend on something the failure
removes?"* If yes, invert it — test for a **change to a known-good snapshot** (a set difference), not
for a **signature of the bad thing**. A contaminant that refuses to identify itself is only visible as
a delta. This is the **free-negative at the trip-wire layer**, one level up from where §5.0/§5.1 put it.

##### ⛔ But inverting to a delta is NOT free — it imports the baseline-integrity problem

A **signature** test needs nothing. A **delta** test needs a baseline that (a) **exists** and (b) is
**trustworthy**. Both were unguarded when P15 was inverted, and both were measured:

| Precondition the inversion imports | What happened without it |
|---|---|
| the baseline **exists** | `diff` exits **2** on a missing file with **empty stdout** — so a predicate phrased *"non-empty output ⇒ HALT"* reads **CLEAN on a contaminated source**. ⇒ key on the **exit status**, and make absence its own halt clause (as P3/P14 already do for the ledger). |
| the baseline is **write-once** | re-deriving it over contaminated state folds the contaminant **into** the baseline ⇒ the halt **launders on a plain phase re-run**, with nothing forbidding it. ⇒ write-once + load-never-re-derive, exactly as §3.1's `carry_baseline`. |

**§3.1 had already solved both halves** for the destination baseline, one section up — *and the fix was
not carried across when the same shape reappeared for the source*. Fourth instance of the same
meta-failure here (§0-vs-`council-gate`-§0 · v0.4.0's own fetch refspec · §6.0's
literal-path-vs-derivation · this). **The pattern gets inherited; the fix has to be carried
deliberately.** When you invert a check, ask what the *new* form requires that the old one did not.

##### ⭐ The nine instances ARE a fixture spec (the actionable form of "build the runner")

Every defect found in this artifact's deterministic layer maps to **exactly one constructible repo
state**. That turns a list of scars into a test matrix — and it is why the ask is not *"write a
verifier"* but *"write these nine fixtures and the verifier falls out of them"*:

| Instance (all found post-hoc, by execution) | Fixture state — all `/tmp`-constructible, no real host |
|---|---|
| a marker that can't match | the marker present, **and** absent — **asserts silence on the absent case** |
| a baseline that can't exist | a **linked worktree** (`.git` as a *file*) |
| a baseline that can be re-derived | a **second run** over the same repo |
| an unchecked exit | an **unreachable** destination |
| mismatched universes | **asserts silence on a healthy annotated-tag repo** (+ a `refs/pull/*` ref) |
| a count that cancels | one **stale** ref ⊕ one **missing** ref |
| a colliding run-id | two classifications in the **same second** |
| a gate that doesn't hold its input | **two overlapping classifications**, cleanup between gate and loop |
| a shared pinned file | **two concurrent runs** writing the pinned file — *fetch-early/pin-late*: destination advances between their fetches, later run pins from the earlier snapshot |

**Prose cannot hold any of these nine** — which is precisely why nine consecutive rounds found them
*after* the fact. The sharpest evidence isn't any single defect: it is that **the fix for the fix had a
counting bug twice, in opposite directions, written by two agents who had just spent five rounds on
this exact failure class.** A blank line and a missing trailing newline are invisible to reading and
trivial to a fixture. ⛔ **Every row needs its DISCRIMINATING NEGATIVE, and the wording is what decides whether it gets
written.** The positive asserts *"the guard fires on bad input"* — a visible output. The negative asserts
*"the guard is **silent** on good input"* — an assertion about an **absence**, on a case where nothing is
wrong. That reads like a test with no subject and is the first thing cut in review. So each row is phrased
as *"asserts silence on X"*, **not** *"tests the X case"* — otherwise the next writer implements the
positive and calls the row done.

**The peeled-tag defect is what that assertion catches and nothing else does**: every positive test
passed, `wire ≠ quarantine` fired correctly on real failures, and the guard still **halted every repo
with a release tag**. A green suite can hide an unconditionally-firing guard — which then trains everyone
to route around it, turning a fail-closed guard fail-open **with nobody editing it**.

##### ⛔ A fourth species: the finding whose PROVENANCE was lost in transit

Three species were already named: a probe that **misses** a real thing · one that **invents** one · one
that **found** the real thing and had its report dropped. A fourth leaves the **artifact correct** and the
**record wrong**: a finding that landed, got fixed, and lost its *attribution*.

It surfaced here for real — a red-team's context was compacted mid-engagement and the summary it resumed
from had merged its identity with the other's, so its working record claimed a finding it could not
distinguish from *"I inherited a summary that said I found this."* It refused to claim it, which is the
correct move.

**Why this is not academic**: this fixture matrix is credited row-by-row, and the reason to keep
provenance is not courtesy — it is that you go back to the agent that produced a row and ask *what else
did you see near it*. **The finding survives; the ability to mine the finder does not.**

⇒ **Resolve provenance from artifacts, never from memory** — commit times, PR timestamps, message
timestamps. Applied here: the disputed TOCTOU resolved cleanly, since the one agent's *queue-empty
close-out* is timestamped **two minutes before** the other's report of it, and a queue-empty message
cannot carry a finding that arrives afterwards. Same discipline as the ledger: *a cold agent resumes from
artifacts, never from recall* (§6) — which applies to **who found what**, not only to **what was found**.

⇒ This matrix is **B6's specification**. (Row 8 also proves the general point twice over: prose could not hold a **blank line**, and it cannot hold a **race**.)

##### ⛔ …and the loop needs its input to STILL EXIST when it reads it (gate ≠ hold)

P16 proves the input existed **at the gate**. Nothing held it between the gate and its use — so the
quartet has a fifth member. Measured on the prescribed code, **two classifications in one checkout with
distinct run-ids** (no collision needed):

```
B's clause 2  → rc=0, PASSES, proceeds to the per-ref loop
A's whole-tree cleanup fires → quarantine refs = 0
B reads dst_sha at use → <EMPTY> ⇒ "exists only on source" ⇒ *** CLEAN CARRY ***
destination objects: INTACT (cat-file -e passes) — only the NAME vanished
```

The carry would then overwrite **live** destination refs. And note the precision: if the sweep lands
*before* clause 2, the gate **catches** it (measured, `diff rc=1` ⇒ HALT). The window is exactly
**after the gate, before the read** — which is why this is a specific race, not a general
"cleanup is unsafe" claim.

**Two causes, one fix each — both applied, because they are independent:**

1. **Never sweep the whole namespace.** The old `refs/rct/_dst` sweep was insurance against the
   cancellation bug that v0.4.6 fixed a better way (per-run path + identity set-diff). It now
   *destroys a sibling's live input*. Scoped to `$QUAR`.
2. **Pin the destination SHAs before the loop** (the stronger fix, and it stands alone): a ref name
   can vanish from *any* cause — an interrupted process, an external deletion, not just a sibling —
   while the git **object** survives. Pinning makes the classification immune to all of them.
   ⛔ An absent pinned sha is a **MISSING MEASUREMENT**, never *"no destination ref"*.

⚠️ **Why not a prose rule ("one classification per checkout at a time")?** Because the artifact
*anticipates* concurrency (the run-id comment says so) and then shared mutable state across it — and
**prose cannot hold a race any better than it held a blank line.** The guard has to be in the data flow.

##### ⛔ The dual failure: a check that never RAN is not a check that PASSED

P16 exists because this hazard is worse than a blind trip-wire. If the **input** to a classification is
*missing* rather than *empty*, the loop over it iterates **zero times**, every per-ref predicate is
**vacuously satisfied**, and the classifier emits its **most permissive** verdict with total confidence
— the only **fail-OPEN** found in this artifact. **An empty input set is `unknown`, never "nothing to
worry about."** Guard the **supply** of a measurement, not only its **result**.

##### ⛔ …and a comparison guard must compare the SAME universe (or it is a permanent false positive)

P16's count cross-check nearly shipped broken in the opposite direction, caught by self-probing the
assumption rather than trusting it: **`git ls-remote` emits an extra *peeled* line per ANNOTATED tag**
(`refs/tags/x` **and** `refs/tags/x^{}`) which `git for-each-ref` does not. Measured on a destination
with one annotated + one lightweight tag: wire **4**, quarantine **3** ⇒ the clause **HALTS on a
perfectly healthy fetch**, in every repo that uses annotated tags — i.e. most real repos. Fixed with a
mandatory `grep -vc '\^{}$'`; verified healthy → `3=3` silent, failed → `3≠0` still fires.

**A trip-wire that fires unconditionally is worse than no trip-wire**, because it trains the operator
and the agent to route around it — the rubber-stamp fatigue §6's proportionality floor exists to
prevent. So when a check compares two counts, **prove both sides count the same universe** before
trusting the comparison; two instruments naming the same thing rarely enumerate it identically.

##### ⛔ …and a COUNT is a signature: two opposite errors cancel

The peeled-tag fix repaired the *universes* but left the *shape* wrong. **A scalar count discards the
identities the check depends on**, so a **stale** ref and a **missing** ref sum to the right total.
Measured — destination A (`main`,`dev`) classified first with cleanup skipped (a halt, a crash, or the
forgotten line), then destination B (`main` only) in the same source checkout:

```
quarantine: heads/dev only   (stale from A; B's own main never arrived)
count compare:  wire(B)=1  quar=1   ⇒ *** CLEAN — the errors cancelled ***
is B's main classifiable?   NO — absent ⇒ reads "exists only on source" ⇒ CLEAN CARRY for that ref
```

That is **P16's own fail-open, reached through P16** — and the clause exists *because* "a partial fetch
can exit 0". This is a partial fetch exiting 0 whose deficit is **masked by unrelated residue**.

⚠️ It was **not reachable in practice, and that is the whole problem**: P15's *secondary* clause happens
to catch this state — a different trip-wire, in a different section, written for a different reason.
**P16 did not hold the property it claimed**; remove or reorder P15's secondary and the hole opens with
nothing announcing it. A guard that only works because another guard covers it is not a guard.

⇒ Fixed two ways: the comparison is a **set difference on ref NAMES** (`dev` present and `main` absent
are two distinct lines — sums cannot cancel identities), and the quarantine moves to a **per-repo +
per-run** path so a leftover can never be *mistaken for* a fetched ref. Verified: healthy → clean ·
stale-from-another-run → still clean (isolated by the path) · cancellation case → **FIRES**. The
per-run path also makes P15's secondary a genuine *independent* second clause rather than the
accidental sole guard.

**This is §4.0's own doctrine applied one level in** — *test for a change to a known-good **set**, not a
signature of the bad thing* — and **a count is a signature**. Fifth instance of the meta-shape: the fix
pattern was one section away, in P15's primary clause, and was not carried into P16's clause 2.

(Residuals, honestly flagged: verified for `refs/heads` + `refs/tags` incl. annotated/peeled; **not**
verified for `refs/replace` or a destination with a `HEAD` symref oddity. **`refs/notes` is
fail-closed** — `--heads --tags` excludes it on both sides, so the sets agree — but note that
`refs/notes` therefore sits **silently outside every tier in §2**: T1 promises *"commits · branches ·
tags · LFS"*, and a repo carrying notes drops them without appearing in any tier table. That is a
**fidelity-declaration gap**, not a safety defect — recorded, not silently absorbed.)

**SECONDARY (agent judgement — widens, never replaces):** an axis the agent believes unsupported
even though no trip-wire fired ⇒ also HALT. Uncertain whether a trip-wire fired ⇒ **treat as
fired** (fail-closed), never as clear.

When any of the above holds — or a probe reveals a hard limit — the skill **HALTS the phase**. It
does not improvise, does not force, does not silently downgrade. It emits:

```
IMPEDIMENT REPORT · <repo> · phase <N>
  blocked axis ......... what cannot be carried
  root cause ........... why, with PROBED evidence (never an assumption)
  achievable fidelity .. the honest tier + explicit GAP
  ranked options ....... A/B/C, each w/ confidence + tradeoff
  best practices ....... what the SOTA does in this exact case
  next action .......... one concrete, executable step
  state ................ phase halted · ledger path · how to resume
```

Format follows the `council-gate` **rule** §5.3 (**contestable ranked evidence, never a blank ask**;
the section lives in `~/.claude/rules/council-gate.md`, not in the skill — the skill only cites it) +
`end-of-action-briefing` §7.1 (`AskUserQuestion`, recommended-option first). The report is an
artifact (registered via `bin/artifact-registry`), not just a message — it survives the session.

⛔ **Free-negative discipline** (`environment-capability-reconnaissance` §1.1.1): a probe that
returned nothing is **NOT** proof of absence. Before declaring ANY impediment, run a **positive
control** — same instrument, same tree, a value known to exist. If the control also returns
empty, the instrument is lying: re-probe with a reaching instrument. An impediment reported on
an unverified negative is a fabricated blocker. *(Empirical: this skill's own design session
first declared an `admin:org` scope blocker that a positive control disproved — the probe had
targeted a non-existent org.)*

## §5 — Drift-detector (mandatory before Phase 2)

### §5.0 — ⛔ FRESHNESS PRECONDITION (the classification is only as true as its refs)

**Before ANY comparison**, both sides' refs MUST be re-read from the wire in this run — never from
remote-tracking refs, never from a cached/earlier read:

```
git ls-remote --heads --tags <source>        # wire truth, not refs/remotes/*
git ls-remote --heads --tags <destination>   # wire truth, not refs/remotes/*
```

Then a **positive control**, in this order (§4 · `environment-capability-reconnaissance` §1.1.1(iv) —
the control step comes **first**, the second instrument is the *escalation*, not a substitute):

0. ⛔ **Confirm the SUBJECT before trusting the instrument.** A positive control proves the
   instrument **reaches**; it says nothing about whether it is aimed at the **right thing**. Print the
   subject you are about to trust and check it is the one under test:

   ```
   git rev-parse --show-toplevel && git rev-parse --abbrev-ref HEAD   # which tree/branch am I reading?
   git worktree list                                                  # is the intended worktree even present?
   ```

   ⛔ A `cd <path> 2>/dev/null || cd <fallback>` idiom **silently relocates the subject** when the path
   is absent — the command then succeeds against the wrong tree and every downstream probe is
   well-formed, controlled, and about something else. Never let a fallback choose your subject.
   *Empirical, this artifact's own review*: findings citing `P18` and `reported_at` were declared
   hallucinated after a controlled probe of the **main checkout** (one version behind) instead of the
   PR's worktree, where both existed. Control passed, instrument reached, subject was wrong.

1. **Same instrument, same tree.** Re-run the *same* `ls-remote` against a ref you **know** exists
   (a control repo you can reach). If the control **also** returns empty, the instrument is lying —
   ⛔ do **not** classify; re-probe with a reaching instrument. *A control that switches instruments
   is not a control*: it sidesteps the suspect condition and passes while the real query still lies.
2. **Only then**, if the control passed and the destination is still empty, escalate to a **second
   instrument** (a repo-exists API call) to distinguish *absent* from a `[C19]` 404-masquerade.

An empty result is `unknown`, **never** `no refs`. **All three steps** are required before any
classification — subject, then reach, then instrument-class. Skipping step 0 makes the other two
*confirm a conclusion about the wrong object*, which reads exactly like a sound negative.

**Why this is ⛔ and not advice** — reproduced empirically 2026-07-29: an observer holding
remote-tracking refs from an earlier clone does **not** see a branch a peer pushed afterwards. That
stale view classifies the destination as empty ⇒ CLEAN-CARRY ⇒ §7 authorizes an **unattended** push
⇒ the peer's work enters the blast radius. A classification derived from a stale ref is not a
classification; it is a guess wearing one. Classification without a same-run wire read = **HALT**
(Impediment Report §4), never a default to CLEAN-CARRY.

### §5.1 — ⛔ `ls-remote` establishes EXISTENCE, never UNIQUENESS (classify on objects, not on ref lists)

"Both sides have **unique** commits" is an **ancestry** question. `git ls-remote` returns ref→sha
only — it cannot answer it. Classifying uniqueness from a ref list is deriving a verdict the
prescribed instrument **cannot produce**, and the failure is silent: the two sides simply have
different SHAs, which is equally consistent with *fast-forwardable* and with *disjoint roots*.

So after §5.0 establishes existence, **fetch the objects and classify with ancestry**:

```
# ⛔ FIRST: snapshot the SOURCE's own tag namespace. This is what makes P15 marker-independent —
#    a contaminant that carries no marker is detectable only as a CHANGE to this set.
#    (Distinct from §3.1's refs-before.txt, which is the DESTINATION baseline for rollback.)
# ⛔ WRITE-ONCE per cutover, exactly as §3.1's carry_baseline: if it exists, LOAD it, NEVER re-derive.
#    Re-taking it over contaminated state folds the contaminant INTO the baseline and launders the halt.
SRC_TAGS="$LEDGER_DIR/<slug>.src-tags-before.txt"
if [ -f "$SRC_TAGS" ]; then :   # reuse verbatim — a re-derived baseline is NOT a baseline (P15)
else git for-each-ref --format='%(refname)' refs/tags | sort > "$SRC_TAGS"   # + stamp captured_at
fi

# ⛔ PER-REPO + PER-RUN quarantine path. A fixed shared path makes a leftover from a previous
#    classification indistinguishable from a legitimately-fetched ref (see the cancellation note).
# ⛔ `$RUN_ID` IS ALREADY SET AND FORMAT-VALIDATED HERE — it comes from **§0.2 BOOTSTRAP**, which runs
#    at process start, BEFORE the Phase-0 ledger read (§6.0). This site only CONSUMES it.
#    Do NOT re-generate or re-validate it here: a second `${RUN_ID:-…}` would mint a *different* id
#    for the quarantine than the one Phase 0 already persisted into the ledger, and the run would
#    then read its own earlier rows as **another run's** (P19 mismatch) — a self-inflicted amnesia.
QUAR="refs/rct/_dst/<slug>/$RUN_ID"      # pid ⊕ random: unique per process AND per invocation

# ⛔ --no-tags is load-bearing, and the quarantine MUST be outside refs/tags/ and refs/remotes/
git fetch --no-tags <destination> \
  "+refs/heads/*:$QUAR/refs/heads/*" \
  "+refs/tags/*:$QUAR/refs/tags/*"
rc=$?                                     # ⛔ P16 clause 1: non-zero ⇒ HALT, never classify
[ "$rc" -ne 0 ] && halt "P16: §5.1 fetch exited $rc — the classification input is missing, not empty"

# ⛔ P16 clause 2 — COMPLETENESS as a SET, never a count. A partial fetch can exit 0.
# ⛔ TWO invariants keep the wire set commensurable with the quarantine. Drop EITHER and the
#    comparison breaks. Both are load-bearing; neither is style:
#    (a) `--heads --tags` SCOPE — a bare `ls-remote` also advertises `HEAD`, `refs/pull/*`,
#        `refs/notes/*`, `refs/replace/*`. Measured: bare = 3 lines (HEAD · main · refs/pull/7/head)
#        vs `--heads --tags` = 1. On a live GitHub remote 258 of 274 lines were `refs/pull/*`.
#        The quarantine refspec only ever fetches heads+tags, so the scope MUST match it.
#    (b) `grep -v '\^{}$'` PEELED-LINE filter — ls-remote emits an extra peeled line per ANNOTATED
#        tag (refs/tags/x AND refs/tags/x^{}) which for-each-ref does not. Without it this clause
#        HALTS on every repo that has a release tag — a false positive on a healthy fetch.
#    ⚠️ A later simplifier is more likely to ask "why is this grep here?" than "why these flags?" —
#       so (a) is named explicitly even though it looks like ordinary argument choice.
# ⛔ A COUNT cancels: one stale ref + one missing ref sum to the right total (see below).
# ⛔ GUARD THE WIRE READ'S OWN SUPPLY FIRST. Inside a pipeline (or a process substitution) the
#    exit status is the LAST command's — grep/awk/sort — so `ls-remote`'s 128 is DISCARDED and a
#    failed read is indistinguishable from an empty destination. Assign, CHECK, then compare.
wire=$(git ls-remote --heads --tags <destination> 2>/dev/null); rc_ls=$?
[ "$rc_ls" -ne 0 ] && halt "P16: ls-remote exited $rc_ls — the wire set is MISSING, not empty"
# ⛔ the -z guard is load-bearing: printf '%s\n' "" emits ONE BLANK LINE, which survives
#    grep -v '\^{}$' and makes a genuinely-empty destination read as 1 ref instead of 0.
if [ -z "$wire" ]; then wire_set=""
else wire_set=$(printf '%s\n' "$wire" | grep -v '\^{}$' | awk '{print $2}' | sort); fi

# ⛔ printf '%s' (no \n) DROPS the trailing newline, so the left side loses its line terminator and
#    diverges from the right on an otherwise-identical set. Emit nothing when empty, else one line
#    per ref — measured: '%s' alone false-positives on a perfectly healthy fetch.
diff <(if [ -n "$wire_set" ]; then printf '%s\n' "$wire_set"; fi) \
     <(git for-each-ref --format='%(refname)' "$QUAR" | sed "s|^$QUAR/||" | sort) \
  >/dev/null 2>&1 || halt "P16: fetch under-delivered — wire/quarantine ref SETS differ"

# ⛔ PIN the destination SHAs into the ledger BEFORE the loop. The gate above proved the input
#    existed *at the gate*; nothing holds it between the gate and its use. A ref name can vanish
#    mid-loop (a sibling run's cleanup, an interrupted process, any external deletion) while the
#    OBJECT survives — and an absent name reads as "exists only on source" ⇒ CLEAN CARRY.
#    Pinning makes the classification immune to ANY cause of ref disappearance, not just cleanup.
# ⛔ PER-RUN path + ATOMIC publish. A per-repo path is shared mutable state — exactly what pinning
#    exists to remove: a concurrent run truncates it with `>` and the loop then reads an EMPTY
#    pinned sha ⇒ the P17 misclassification returns. Measured. The quarantine is per-run; the
#    pinned FILE must inherit that isolation. `>` also truncates-then-writes, so an interruption
#    leaves a partial file — hence write-to-.tmp-then-mv (rename is atomic on one filesystem).
DST_PINNED="$LEDGER_DIR/<slug>.dst-pinned.$RUN_ID.txt"
git for-each-ref --format='%(refname) %(objectname)' "$QUAR" \
  | sed "s|^$QUAR/||" > "$DST_PINNED.tmp" && mv "$DST_PINNED.tmp" "$DST_PINNED"
# ⚠️ Do NOT "unify" this with §3.1's carry_baseline: that one is per-CUTOVER and write-once (a
#    rollback bound that must survive re-runs); this one is per-RUN (a classification input that
#    must NOT survive into another run). Different lifetimes, deliberately.

# then, PER REF, reading dst_sha from the PINNED file — never re-resolving the ref:
#   (valid ONLY once P16 passed — see the vacuous-CLEAN-CARRY note below)
git merge-base --is-ancestor <pinned_dst_sha> <src_sha>   # dst reachable from src? → fast-forwardable
git merge-base --is-ancestor <src_sha> <pinned_dst_sha>   # src reachable from dst? → destination ahead
git merge-base <src_sha> <pinned_dst_sha>                 # non-zero ⇒ DISJOINT ROOTS
# ⛔ An empty/absent pinned sha is NOT "no destination ref" — it is a MISSING MEASUREMENT (P17).

# and ALWAYS, once classified — clean ONLY THIS RUN's slice. ⛔ Never sweep the whole namespace:
# a concurrent classification's quarantine lives there and is its live input (see the TOCTOU note).
# A per-run path already makes a foreign leftover harmless, and clause 2's set-diff now SEES one.
git for-each-ref --format='%(refname)' "$QUAR" | xargs -r -n1 git update-ref -d
# then P15 — SET DIFFERENCE first (the only form that sees an unmarked contaminant).
# ⛔ Key on the EXIT STATUS, never on stdout emptiness: diff exits 1 = differences,
#    but 2 = TROUBLE (e.g. missing baseline) and on 2 stdout is EMPTY.
[ -f "$LEDGER_DIR/<slug>.src-tags-before.txt" ] \
  || halt "P15: source-tag snapshot ABSENT while classification has run — cannot verify"
diff <(git for-each-ref --format='%(refname)' refs/tags | sort) \
     "$LEDGER_DIR/<slug>.src-tags-before.txt" >/dev/null 2>&1
rc=$?; [ "$rc" -ne 0 ] && halt "P15: source tag namespace changed (diff rc=$rc)"
git for-each-ref refs/tags refs/rct/_dst | grep -q _dst   # secondary: uncleaned quarantine
```

#### ⛔ Why P15's primary clause is a SET DIFFERENCE and not a marker test

A deterministic check **must not key on a property the failure mode is defined by lacking.** Harm (1)
above is documented as *"the bare tag carries **no marker whatsoever** that it came from the
destination"* — so a trip-wire that greps for `_dst` **cannot see it**. Measured with the quarantine
path **correct** and only `--no-tags` omitted (destination genuinely ahead, so tag-following has
objects to pull):

```
* [new tag]  rel-9 -> refs/rct/_dst/tags/rel-9
* [new tag]  rel-9 -> rel-9                    ← tag-following, unprefixed
-- prescribed cleanup runs, rc=0, quarantine empty --
source refs/tags after cleanup:  rel-9  v1
marker test (grep _dst):  *** CLEAN — proceeds ***      ⛔ blind
set difference:           FIRES  (> refs/tags/rel-9)    ✅
```

The cleanup deletes `refs/rct/_dst/**` faithfully; `rel-9` was never in there. **The trip-wire written
to catch this contamination reported clean on the half documented as the more dangerous one.** This is
the same shape as the §9.0 defect one layer up — *a guard conditioned on the very thing whose absence
is the failure mode* (there: a prohibition conditioned on a classification that never happened; here: a
trip-wire conditioned on a marker the failure never produces). It is the **free-negative at the
trip-wire layer**.

The marker clause is **kept as secondary** because it catches something the diff cannot: an
**uncleaned quarantine** (`refs/rct/_dst/**` still present), which is outside `refs/tags` and so never
appears in the tag set-difference. Two clauses, two distinct failure modes; neither subsumes the other.

#### ⛔ A read-only classification must not WRITE into either side's real ref namespace

`refs/tags/<anything>` is **not** a scratch space — anything under it is a **real local tag**, not a
remote-tracking ref. Two measured harms when the quarantine is placed there (or when tag-following
is left on):

1. **Git's default tag-following creates the tag *unprefixed*.** Reproduced 2026-07-29: source with
   `v1`, destination holding its own `rel-9` (a prior partial cutover, or a peer). The fetch printed
   **both** `rel-9 -> _dst/rel-9` *and* `rel-9 -> rel-9`, leaving the source's tag list as
   `_dst/rel-9 · rel-9 · v1`. The bare `rel-9` carries **no marker whatsoever** that it came from the
   destination — so a later T1 fidelity check compares a tag set **the classifier itself
   contaminated**. `--no-tags` is what suppresses this; the refspec alone does not.
2. **The residue is pushable back.** `git push --dry-run <dst> 'refs/tags/*:refs/tags/*'` exported
   `_dst/rel-9` and `_dst/v1` as **permanent real tags** on the destination. This is not data *loss*,
   so **§9.0's property does not catch it**, and **no P1–P14 trip-wire sees it** — every one of them
   is framed around *losing* a destination commit or *mis-classifying*. This is **additive
   contamination of the source**, then exported: the classifier's own instrument damaging the thing
   it was invoked to measure, and leaving residue in a repo the cutover just took custody of.

⇒ Quarantine under `refs/rct/_dst/**` (verified: source `refs/tags` stays exactly `v1`, nothing
`_dst` inside `refs/tags`, wildcard tag push exports **0** `_dst` refs, ancestry classification
unaffected), and **delete the quarantine once classified** — the cleanup line above is not optional
hygiene, it is what keeps a re-run's classification honest.

| Per-ref ancestry result | Class |
|---|---|
| equal SHA | **ALREADY DONE** → verify only |
| destination is an ancestor of source | **CLEAN CARRY** (fast-forwardable) → standard T1 |
| source is an ancestor of destination | **INVESTIGATE** — the destination is *ahead*; never assume ownership |
| neither, **or `merge-base` finds no common ancestor** | ⛔ **SPLIT-BRAIN** → reconciliation protocol |
| ref exists only on source | **CLEAN CARRY** for that ref |
| ref exists only on destination | **INVESTIGATE** — prior partial cutover |

The repo's class is the **worst** class across all its refs (one SPLIT-BRAIN ref ⇒ the repo is
SPLIT-BRAIN). A ref-by-ref verdict is what makes `--branches '[*]'` safe: a clean branch does not
launder a divergent one.

#### ⛔ The auto-init destination is SPLIT-BRAIN, not "empty"

`gh repo create --add-readme` (and every "initialize with a README" equivalent) leaves the
destination holding **one unrelated root commit**. It is **not empty** and **not** CLEAN CARRY:
its root is **disjoint** from the source's, so by the table above it is SPLIT-BRAIN and leaves the
§7 autonomous band.

Reproduced 2026-07-29: dest `main=d8e5e15` (auto-init), source `main=c412f39` + tag `v1`.
`ls-remote` shows only *"both have `refs/heads/main`, SHAs differ, not identical"* — from which one
agent reads SPLIT-BRAIN/halt and another reads *"it's just a README, effectively empty"* ⇒ CLEAN
CARRY ⇒ **unattended push**. Same repo, same file, opposite bands, one of them autonomous. Ancestry
resolves it deterministically: neither is an ancestor, `merge-base` finds nothing ⇒ disjoint roots.

⇒ **Create the destination EMPTY** (no `--add-readme`, no license/gitignore template) when a carry
is planned. An auto-init destination is a self-inflicted SPLIT-BRAIN.

### §5.2 — ⛔ A non-fast-forward rejection is a POSITIVE SPLIT-BRAIN signal (never clear it with force)

The git push rejection (`! [rejected] ... (non-fast-forward)` / `(fetch first)`) is the **only**
safety signal that fires without any prose being obeyed — it is the strongest real safety property
in this whole flow, and the skill owns its response:

This is also what makes the **TOCTOU window** (classify → push) survivable rather than fatal: a peer
pushing between the §5.0/§5.1 read and the carry gets its work **rejected**, not force-overwritten.
That is a backstop, **not** a licence to skip a freeze — a freeze/expected-SHA lease for every class
(not just SPLIT-BRAIN) is still owed (queued).

**A rejection means the classification was wrong.** Correct response: **HALT + Impediment Report**
(§4), re-run §5.1 ancestry classification, and treat the repo as SPLIT-BRAIN until proven otherwise.
⛔ **NEVER** clear a rejection with `--force`, `-f`, `+<refspec>`, `--force-with-lease`, or
`--mirror`. The rejection is git protecting a commit that the destination would otherwise lose;
escalating past it converts a caught error into data loss.

SPLIT-BRAIN is a **distinct class**, not a harder migration: it demands per-branch merge/rebase
decisions, a dedicated red-team pass, and an explicit freeze point. It never runs on cycle 1.

## §6 — Custody ledger (amnesic re-activation)

### §6.0 — ⛔ THE LEDGER HAS AN ADDRESS (a checkpoint with no address is a promise, not a checkpoint)

⛔ **DERIVE the path — never hardcode `.git/`.** In a **linked worktree** (`[C04]` *mandates* one for
modifications) `.git` is a **file**, not a directory, so a literal `.git/maos/...` is unwritable:

```bash
# ⛔ --git-common-dir, NOT --absolute-git-dir (see below)
LEDGER_DIR="$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody"
mkdir -p "$LEDGER_DIR"

"$LEDGER_DIR/<repo-slug>.json"              # the ledger — ⛔ publish ATOMICALLY (.tmp + mv), never `>`
                                            #   ⛔ the .tmp MUST be created INSIDE $LEDGER_DIR — `mv`
                                            #     is atomic only within one filesystem; from /tmp it
                                            #     degrades to copy+unlink, i.e. a torn window again.
                                            #   ⛔ atomicity is NOT serialization: two overlapping runs
                                            #     can still last-writer-wins whole-file. Read-modify-
                                            #     publish under an exclusive lock on $LEDGER_DIR, or a
                                            #     run may erase another's phase_states/tiers/impediments.
                                            #   per-CUTOVER: phase_states · tiers · impediments
                                            #     ⛔ + carry_baseline · src_tags_before · carry_count (MONOTONIC — §3.1)
                                            #   per-RUN (owned by run_id): drift_verdict · dst_pinned_path
"$LEDGER_DIR/<repo-slug>.refs-before.txt"   # write-once carry_baseline — DESTINATION, rollback (§3.1)
"$LEDGER_DIR/<repo-slug>.src-tags-before.txt" # SOURCE tag snapshot — P15 set-difference (§5.1)
"$LEDGER_DIR/<repo-slug>.dst-pinned.$RUN_ID.txt" # DESTINATION ref→sha pinned pre-loop, PER-RUN + atomic — P17 (§5.1)
```

**Why `--git-common-dir` and not `--absolute-git-dir`** — measured 2026-07-29, and this is the whole
point: the **per-worktree** git-dir is **deleted when the worktree is removed**, and `maos:postflight`
removes worktrees. A ledger written there **dies at exactly the session boundary it exists to
survive** — which un-fixes the amnesic contract a second time, by a different mechanism. Proof:

| Location | After `git worktree remove` |
|---|---|
| `$(git rev-parse --absolute-git-dir)/maos/custody/…` | ⛔ **DESTROYED** |
| `$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody/…` | ✅ **SURVIVED** |

Common-dir is also where the existing convention actually lives — verified: `maos/` under the
common-dir contains `continuation-seed.latest.json`; the per-worktree dir has no `maos/` at all.

**Reuse the derivation, not the literal.** `plugin-scripts/governance/preflight-session.sh` already
documents this exact trap (*"the hardcoded `$REPO/.git/maos/...` never resolves"*) and solves it by
probing `rev-parse` — this section originally cited that script as precedent while copying its
**path** instead of its **derivation**. Same shape as the §0 hole: *the pattern was inherited, the fix
was not.* Registered via `bin/artifact-registry` when the cutover completes.

**Minimum schema** (extend freely; these keys are load-bearing):

```json
{ "repo": "<slug>", "source": "<url>", "destination": "<url>",
  "phase": 0, "phase_states": {"0":"done","1":"dispensed","2":"halted:P5"},
  "drift_verdict": "CLEAN_CARRY|SPLIT_BRAIN|INVESTIGATE|ALREADY_DONE"   // ⛔ SERIALIZED form is UNDERSCORED; the prose spells it SPLIT-BRAIN. Same verdict, two registers: hyphen in prose, underscore on the wire. Ledger consumers MUST accept only the underscored set.,
  "tiers": {"commits":"T1","pipelines":"T2","prs":"T3","secrets":"T4"},
  "carry_baseline_path": "<LEDGER_DIR>/<slug>.refs-before.txt",
  "src_tags_before_path": "<LEDGER_DIR>/<slug>.src-tags-before.txt",
  "src_tags_before_captured_at": "<iso8601+offset|null>",
  "run_id": "<run-id>",   // ⛔ OWNER of the per-RUN fields — `drift_verdict` + `dst_pinned_path` —
                         //    REGARDLESS OF ORDER in this object. Loader MUST compare to its own
                         //    $RUN_ID; mismatch ⇒ those two are ANOTHER run's measurement ⇒ MISSING.
                         //    ⛔ `carry_count` is per-CUTOVER + monotonic ⇒ NEVER discarded (§3.1/P10)
  "dst_pinned_path": "<LEDGER_DIR>/<slug>.dst-pinned.<run-id>.txt",   // per-RUN · atomic-published
                         // ⛔ a RECORD, never an ADDRESS — recompute $DST_PINNED from your own $RUN_ID
  "carry_baseline_captured_at": "<iso8601+offset|null>", "carry_count": 0,
  "impediments": [{"trip_wire":"P5","report":"<path>",
                   "reported_by":"<agent-id>","reported_at":"<iso8601+offset>",
                   "verified_by":"<agent-id|null>"}],
  "resume": "<one concrete next step>" }
```

#### ⛔ Provenance is a FIELD, not a reconstruction

Each impediment records **who reported it, when (ISO 8601 + offset), and who verified it**. Without
those, provenance has to be reconstructed from message logs — and reconstruction fails in the one case
that matters, because a claim inherited from a **context compaction** arrives as a **first-person
measurement** and *reads complete*.

Observed for real in this artifact's own review: a red-team's context was compacted mid-engagement and
the resumed summary had merged its identity with another agent's, so its record asserted a finding it
could not distinguish from *"I inherited a summary that said I found this"* — **carrying a sandbox path
and a target sha**, i.e. the full texture of a real measurement. That texture is precisely why such a
claim passes unchallenged.

**The distinguishing property**: the other three free-negative species surface as either a visible **gap**
or a visible **false claim**. This one **reads complete** — which is why it needs an **artifact check**,
never a suspicion. *A first-person claim inherited from a summary is a report ABOUT the past, not a
measurement OF it.*

⇒ Same move as pinning `dst_sha` before the loop instead of re-resolving it: **record the attribution at
the moment of observation** rather than deriving it later from state that may have been rewritten.
`run_id` already makes rows attributable to a *run*; these fields make them attributable to an *agent*.

**Phase-0 rule (makes resume real)**: **first** action is to read the ledger path above.
- **Exists** ⇒ **load it and resume** from `phase_states` — never re-derive from recall.
- **Absent** ⇒ you are **NOT resuming**: re-run Phase 0 read-only, and ⛔ **do not push** — an absent
  ledger means an absent `carry_baseline`, which per §3.1 means **rollback is forbidden**, which
  means the push is out of the autonomous band (§7).
- **Never enter a phase without writing its entry first** (persist-first, `harmonic` L9).
- ⛔ **Unparseable** ⇒ **HALT + Impediment Report (P19)** — *not* "absent". Absent means *"I am not
  resuming"* and fails closed. Corrupt means *"I cannot tell what I already did"*, which is **strictly
  worse** and was previously **silent**: the three-way branch had no case for it. A ledger read
  mid-write is reachable because `>` truncates-then-writes — the same argument that made the pin file
  atomic, applied to the file that *names* the pin file.
- ⛔ **Compare `run_id` to your own `$RUN_ID` BEFORE trusting any per-RUN field.** On mismatch,
  `drift_verdict` and `dst_pinned_path` are **another run's measurement** ⇒ treat as **MISSING
  MEASUREMENT** (§5.1's vocabulary), never as yours: re-derive the verdict from a same-run wire read
  (§5.0), and ⛔ **do not push** on a verdict you did not measure.
- ⛔ **`carry_count` is per-CUTOVER and MONOTONIC — it is NEVER discarded on `run_id` mismatch.** It
  counts *what this cutover has already carried*, which a later run **inherits** rather than owns
  (§3.1 · P10). A resume legitimately has a fresh `$RUN_ID` (`:512` — `RUN_ID="$$-…"` per invocation),
  so discarding it on mismatch would **disarm P10 on every honest resume** — no concurrency required.
  ⛔ And its **absence fails CLOSED**: an unreadable/missing `carry_count` on a ledger that exists is
  **`unknown`, treated as `> 0`** (assume refs were carried) — never as `0`. Reading a missing
  measurement as *"nothing was carried"* is the free-negative that P10 exists to stop.
- ⛔ **A ledger with NO `run_id` key at all (legacy ≤v0.5.5, or written before `RUN_ID` was set) is
  an UNATTRIBUTED measurement ⇒ every per-RUN field in it is a MISSING MEASUREMENT.** Same class as
  the legacy-impediment rule below, and the same reason: absence of provenance is *`unknown`*, never
  *"mine"*. ⛔ It does **NOT** halt a resume (`carry_count` is per-CUTOVER and still inherited, §3.1),
  and ⛔ it is **never** back-filled with your own `$RUN_ID` — stamping it makes another run's
  verdict *read* as yours, which is the defect wearing the fix's clothes.
- ⛔ **`dst_pinned_path` absent or unreadable is a MISSING MEASUREMENT ⇒ P17 keeps blocking** until
  this run re-pins. Never read it as *"no destination ref"* — that is the free-negative P17 exists to
  stop, one indirection out.
- ⛔ **Never follow `dst_pinned_path` as an address** — recompute `$DST_PINNED` from your own `$RUN_ID`.
  The key is a **record of what this run pinned**, kept for audit. Following it reads a snapshot you
  never took (P17 one indirection out).

#### ⛔ Ownership of state is invisible to a reader and immediate to a second process

The pin file learned `$RUN_ID`; the file that *names* it did not. Three measured consequences of one
per-slug object holding two lifetimes:

| Trace | Mechanism | Outcome |
|---|---|---|
| verdict clobber | A measures `SPLIT_BRAIN`; overlapping B writes `CLEAN_CARRY` to the same path; A loads per this rule at its push gate | the repo moves from the **council-then-HITL** row (§7) into the **unattended** row — ⛔ **no agent disobeyed anything** |
| P10 disarm | A has `carry_count=2` + baseline lost (P10 armed); B legitimately has `carry_count=0` and overwrites | P10 goes **SILENT** — its condition never became false, it became **someone else's** |
| corrupt resume | interrupted `>` write | `JSONDecodeError`; branches were exists/absent ⇒ **unspecified** |
| P10 disarm **by honest resume** | `carry_count` mis-classified per-RUN; a resume's fresh `$RUN_ID` mismatches ⇒ discarded | P10 SILENT with **no second process at all** — the ownership fix re-opened the hole it closed (⇒ per-CUTOVER + monotonic + absence-fails-closed) |

**The generalization**, now stated where a reader meets it: a guard whose **input is shared mutable
state** is only as strong as the *ownership* of that state. Four rounds moved the ownership question up
one indirection each time — discarded count identity → unheld quarantine name → unattributed pin →
**unattributed verdict** — because each fix answered *"is the value right?"* instead of *"whose value
is this?"* ⛔ **Every field a trip-wire reads must name its owner**, or a second process answers for it.



⛔ **Legacy impediments (written before provenance was a field) do NOT halt a resume.** P18 is a
**write-time** gate. An impediment already on disk with only `trip_wire` + `report` is a **MISSING
MEASUREMENT** — the same class as an absent pinned sha (§5.1), not a violation. On load:

- Treat its provenance as **`unknown`**, and ⛔ **never cite it as verified** — an unattributed
  impediment cannot carry the weight of an attributed one.
- ⛔ **Never back-fill `reported_by` / `reported_at` from recall or from message logs.** A
  reconstructed provenance **reads complete** while being invented — precisely the fourth
  free-negative species P18 exists to prevent. Absent stays absent; `unknown` is the honest value.
- **Continue the resume.** Halting here would deadlock every ledger predating the field — the same
  failure shape as v0.4.2's unwritable ledger address: a guard that forbids the operation it was
  written to protect.

Every impediment written **from this run onward** carries provenance, so the unknown set is
closed and shrinking, never growing.

*Why this is ⛔*: both red-teams landed on the same hole — §7 granted **unattended push** authority
partly on the strength of "ledger-bounded state", while the ledger had **no path and no schema**. The
resume instructions lived inside an artifact the cold agent could not locate (circular), and §9
forbids the fallback ("trust recall over the ledger"). So §3.1's *exceptional* "snapshot missing ⇒
rollback forbidden" was in fact the **default** state of every cold resume. An address fixes it;
without one, the amnesic contract is unhonorable by construction.

---

A durable per-repo record: phase states · tier assignments · drift verdict · **the write-once
`carry_baseline` (ref→sha + `captured_at`) and `carry_count`** (§3.1 — the rollback bound; a re-run
reads it, never rewrites it) · impediments raised · artifacts produced · resume instructions. It is the SSOT for "where is this cutover?" so a
fresh amnesic agent (`ai-as-pwd-axiom` §1) resumes from artifacts, **never from recall**
(`harmonic` L9 persist-first). Hooks `session-reentry` (ADR-009) for anamnesis and emits a
continuation seed per `end-of-action-briefing` §7.2.

## §7 — Autonomy ladder (council-before-HITL)

```
action → council-gate Layer-1 deterministic deny-set (⛔secrets · irreversible∧blast · cross-org)
  ├ cleared → MoE debate-converge → independent council decide+verify → EXECUTE autonomously
  └ blocked/residual → Impediment Report (§4) → HITL, last resort, with ranked recommendations
```

| Band | Actions |
|---|---|
| **Autonomous** (unattended; `--auto-merge` inherits the existing standing chain) | recon · drift-detect · classification · tier assignment · plan/roadmap · tickets · ADRs · docs PRs · dry-run in scratch · pipeline translation *proposals* · T1 push into an already-created destination for a CLEAN-CARRY repo — **only if** §5.0 freshness (same-run wire read + positive control) AND §3.1 snapshot both hold; either missing ⇒ the push leaves the autonomous band |
| **Council-first, then HITL** | destination repo creation · visibility · permissions/teams · secret provisioning · CI flip · source-host archive · **anything SPLIT-BRAIN** |
| **HITL irreducible** | secret **values** ⛔ · a capability genuinely absent after positive-control verification |

`--branches '[*]'` names the **target**, reached class-by-class — never a blind cycle-1 sweep
(`over-engineering-circuit-breaker`). Per-action `READY` (R1–R5) re-held per `[C21]`; an
irreversible phase requires an independent Elenchus red-team CLEARED (H1 secrets · H3
irreversible∧blast · H7 external exposure) — **HOLD, not force**, if independence is unavailable.

## §8 — Composition map (reuse, don't rebuild)

| Need | Existing primitive |
|---|---|
| source-host archaeology | the `legacy-archaeologist` agent · `maos:reveng` |
| host API surface (PRs · pipelines · variables · branches) | the hub's Bitbucket gateway · `gh` (GitHub) |
| CI health/parity observation | `maos:bitbucket-pipeline-watch` |
| authorization ladder | `maos:council-gate` · `auto-merge-standing-authorization` |
| adversarial verification | `maos:red-team` (Elenchus) · `maos:convergence-engine` |
| session lifecycle | `maos:preflight` · `maos:postflight` · `maos:quiesce` · `maos:session-reentry` |
| artifacts + decisions | `bin/artifact-registry` · `maos:decision-capture` |
| destination repo baseline | `[C18]` agentic-repo-config-baseline (B1–B8) |
| naming | `maos:anima` (`[C-naming]`) |

**Genuine residue this skill owns** (everything else is delegation): the fidelity-tier contract ·
the Blocking-Gate/Impediment Report · the drift-detector classification · the phase
ledger/state-machine · the pipeline→Actions translation report.

## §9.0 — ⛔ THE UNCONDITIONAL RULE (stated as a PROPERTY, not as a list of spellings)

> **No operation may cause a destination ref to stop pointing at a commit that is still reachable
> from that destination — in ANY class, including UNCLASSIFIED.**

This is deliberately **unconditional**. The previous formulation predicated the prohibition on the
verdict *"SPLIT-BRAIN"* / *"a destination with unique refs"* — i.e. on the classification. **A
prohibition conditioned on a classification cannot protect the case where the classification
failed**, which is exactly the case that loses data. Measured 2026-07-29: an auto-init destination
was never labelled SPLIT-BRAIN, so `git push --force` destroyed its commit **without violating any
rule in this file**.

Non-exhaustive spellings of the forbidden property — the property governs, this list only helps you
recognize it (and it now includes the ones the skill itself *mandates* elsewhere, which the old
spelling-based ban missed):

| Forbidden | Note |
|---|---|
| `--mirror` | deletes every destination ref absent from the source |
| `--force` · `-f` | the canonical case |
| `+<refspec>` (leading `+`) | force, spelled differently — easy to miss in review |
| `--force-with-lease` | **still lossy under a wrong/stale lease** — not a safe alternative here |
| `--delete` · `push <remote> :<ref>` | ⚠️ the skill *requires* ref deletion on rollback ⇒ permitted **only** inside §3.1's baseline bound |
| `--prune` | deletes by omission — the silent form |
| `git filter-repo` / history rewrite | changes every hash (anti-pattern #11) |
| repointing `HEAD`/default branch to enable a deletion | §3.1 — mutates outside the baseline |

**Plus one ADDITIVE prohibition** — the property above is about *loss*, so it does not reach this;
stated separately rather than bent to fit:

| ⛔ Also forbidden | Why |
|---|---|
| `git push <dst> 'refs/tags/*:refs/tags/*'` (wildcard tag push) | exports §5.1 classifier **scratch refs** into the destination as permanent real tags — measured. Violates T1 *"byte-identical"* by adding refs present in **neither** side's true history. An **explicit-list** tag push is fine; the **wildcard** is what carries the residue. |
| a classification that writes into `refs/tags/**` or `refs/remotes/**` of either side | §5.1 — a read-only measurement must not mutate what it measures |

**The two carve-outs, and nothing else**: (a) §3.1 rollback deleting a ref **absent from the
write-once baseline**; (b) §3.1 **repo-level** rollback on an **empty** baseline. Both are
subtractive within a proven bound. Everything else ⇒ **HALT + Impediment Report**.

## §9 — Anti-patterns (do NOT)

1. ❌ **Any operation violating §9.0** — force/mirror/prune/`+refspec`/rewrite, in **any** class
   including unclassified. Conditioning this on SPLIT-BRAIN is what made it bypassable (§9.0).
2. ❌ **Promise T1 on T3 axes** — claiming PRs/issues "migrated" when they were archived (theater).
3. ❌ **Copy/print/commit a secret value** ⛔ — T4 is exclusion by construction.
4. ❌ **Improvise past an unsupported axis** — the Blocking-Gate exists precisely to halt (§4).
5. ❌ **Report an impediment on an unverified negative** — positive-control first (§4).
6. ❌ **Blind `--branches '[*]'` sweep** on cycle 1 — class-by-class, pilot-first.
7. ❌ **Delete the source host** — archive read-only; deletion is a separate, later, explicit decision.
8. ❌ **Blind pipeline port** — `bitbucket-pipelines.yml` → Actions is re-authoring, not copying.
9. ❌ **Treat SPLIT-BRAIN as a harder carry** — it is reconciliation, a distinct protocol.
10. ❌ **Trust recall over the ledger** — a cold agent must resume from artifacts (§6).
11. ❌ **Rewrite history** (`git-filter-repo`) unless separately authorized — it changes hashes.
12. ❌ **Classify from stale refs** — deriving CLEAN-CARRY from `refs/remotes/*` or an earlier read
    instead of a same-run `ls-remote` (§5.0). Empirically reproduced: it hides a peer's branch and
    routes an unattended push at it.
13. ❌ **Self-scored gate** — treating "no supported path" as pure judgement and skipping the §4.0
    P1–P19 trip-wires; a gate the proceeding agent scores itself is a gate it can talk past.
14. ❌ **Unbounded rollback** — deleting destination refs without a pre-carry baseline, or deleting a
    ref that predates the carry (§3.1). The rollback then destroys what the cutover promised to protect.
15. ❌ **Re-derive the rollback baseline on a re-run** — reading it "fresh" per §5.0 on an idempotent
    replay folds the refs the previous run created into the baseline, silently degrading rollback to a
    **no-op** with no trip-wire firing (§3.1 write-once, P9). Classification is re-read every run; the
    rollback bound is read **once, ever**. Two different questions, two different freshness rules.

### Skip (proportionality)
- **S1** read-only inspection with no cutover intent.
- **S2** ALREADY-DONE per §5 → verify only.
- **S3** mid-orchestration under a parent that already ran recon/drift upstream.

## §10 — Quality Tests (6/6 self-validity)

1. **Self-Application** — its own design ran the discipline it prescribes: the drift-detector
   found the split-brain before any push; the positive-control rule caught a self-fabricated
   `admin:org` impediment; the T3 archival was verified with a positive control (a repo with 0
   PRs vs. one with 3 real PRs) rather than assumed. ✅
2. **Non-Contradiction** — composes `council-gate`/`red-team`/`legacy-archaeologist`/`[C18]`
   without redefining them; distinct from `sync-to-git` (ongoing same-host sync) and
   `bitbucket-pipeline-watch` (CI observation). ✅
3. **Survival** — applied to itself it advocates honest tiers + halt-on-unsupported; it declares
   its own T3/T4 limits instead of over-claiming. ✅
4. **Bounded-Responsibility** — 5 bounded phases · §9 skips · pilot-first · ledger-bounded state
   · point-of-no-return isolated to Phase 4 · §DUED. ✅
5. **Explicit-Exception** — §0 BEING>Rules · §9 S1–S3 · the never-skippable ⛔ set named. ✅
6. **Utility-Sunset** — §DUED. ✅

`anti-theater` 8Q: 8/8 (the honest T3/T4 admission **is** the anti-theater).
`scope-discipline` 6Q: 6/6 (WHERE=maos skill · DRY=composition-map §8 with a named residue ·
WHY=9 real repos + a split-brain near-miss · WHO=any agent · FITS=lifecycle family ·
MIN=one skill, residue scripts deferred until a cycle demands them).

## §Vocabulary — say "probe" or "attack-path" for adversarial review

`bin/check-layer-purity` reserves one word here: the corporate name in its `\bv…r(inf)?\b` pattern
(run the checker to see it — this section deliberately does not spell it). That word is also the
most natural English term for a red-team attack-path, so the collision is structural, not
accidental: it fired **three times** while authoring this skill, each time caught only by the gate.

**Use `probe` / `attack-path` / `finding` instead.** The gate is deterministic and correct; the
vocabulary was the bug — never request an exception for it.

*(Recursive proof: the first draft of this very section tripped the gate **four times**, because it
quoted the forbidden token in order to explain it. A rule about a word must not contain the word.)*

## §DUED — Sunset (qualitative, not counter-based)

Deprecate when ANY: a vendor ships a supported Bitbucket-**Cloud**→GitHub importer that makes T3
native (E1/E6 — the fidelity contract collapses to T1/T2) · the ecosystem's repos are all on one
host (E2) · operator retraction (E4) · ≥3 false-positive impediments (E5 → refine the
positive-control discipline, not deprecate). Dormant-by-design otherwise.

## §Refs

the `legacy-archaeologist` agent · `maos:council-gate` (Boule) · `maos:red-team` (Elenchus) ·
`maos:convergence-engine` · `maos:preflight`/`postflight` · `maos:session-reentry` (ADR-009) ·
`bin/artifact-registry` (ADR-011) · `maos:decision-capture` · `maos:bitbucket-pipeline-watch` ·
`maos:anima` (`[C-naming]`) · `[C04]` worktree · `[C07]`/`[C07b]` PR+SemVer · `[C17]` §2
HUMAN_DOMAIN · `[C18]` repo-config baseline · `[C19]` multi-identity git/ssh (a private-repo
`Repository not found` is a **404-not-403 credential masquerade**, never "repo absent") · `[C21]`
READY · `environment-capability-reconnaissance` §1.1.1 (free-negative / positive control) ·
`harmonic` L9 (persist-first) · `loose-end-triage-queue` (Taxis) · `anti-theater-grounding-protocol`.
External: *translatio imperii* / *translatio studii* (medieval historiography) · chain-of-custody
(forensics) · `gh gei`/`bbs2gh` (Bitbucket **Server/DC** scope — NOT Cloud).

## Changelog

Full version history: **[`CHANGELOG.md`](./CHANGELOG.md)** (21 rows, v0.1.0 → v0.6.1).

Extracted 2026-07-30 per `[C07b]` separate-spec-file — the changelog was **62KB of the 142KB
file (44%)**, and this file is **instruction loaded into context**, so the history was
displacing safety-critical rules (P1–P19). Rows are preserved **verbatim** in `CHANGELOG.md`
(append-only, nothing rewritten — `[C07b]`). New entries go at the TOP (newest-first, matching the table's existing order).
